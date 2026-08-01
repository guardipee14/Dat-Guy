class HpOemDriverAdapter : PhoenixOemDriverAdapter {
    [string]$UtilityPath

    HpOemDriverAdapter() : base(
        'HP',
        @('HP', 'Hewlett-Packard', 'Hewlett Packard Enterprise'),
        @()
    ) {
        $this.UtilityName = 'HP Image Assistant'
        $this.UtilityUri = 'https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html'
        $candidatePaths = @()
        foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not [string]::IsNullOrWhiteSpace($root)) {
                $candidatePaths += Join-Path `
                    $root `
                    'HP\HPIA\HPImageAssistant.exe'
            }
        }
        foreach ($path in $candidatePaths) {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                $this.UtilityPath = $path
                $this.UtilityAvailable = $true
                break
            }
        }
    }

    [PhoenixOemDriverUpdate[]] Scan([object]$HardwareIdentity) {
        if (-not $this.UtilityAvailable) { return @() }
        [string]$reportRoot = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ("Phoenix-HP-$([guid]::NewGuid().ToString('N'))")
        try {
            $null = New-Item -ItemType Directory -Path $reportRoot -Force
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @(
                    '/Operation:Analyze','/Action:List','/Silent',
                    "/ReportFolder:$reportRoot"
                ) `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) { return @() }
            $update = [PhoenixOemDriverUpdate]::new()
            $update.Id = 'HP-Recommended'
            $update.Name = 'HP recommended driver updates'
            $update.Adapter = $this.Name
            $update.Manufacturer = 'HP'
            $update.AvailableVersion = 'Recommended'
            $update.Source = $this.UtilityName
            $update.ReleaseNotes = @(
                Get-ChildItem -LiteralPath $reportRoot -File -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Name
            ) -join ', '
            $update.SupportUrl = $this.UtilityUri
            $update.Applicable = $true
            return @($update)
        }
        catch { return @() }
        finally {
            Remove-Item `
                -LiteralPath $reportRoot `
                -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        if ($null -eq $Update) {
            return $this.NewAdapterFailure(
                'An HP driver update is required.',
                'PHX_INVALID_DRIVER'
            )
        }
        if (-not $this.UtilityAvailable) {
            return $this.NewAdapterFailure(
                'HP Image Assistant requires approval and installation.',
                'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            )
        }
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @(
                    '/Operation:Analyze','/Action:Install','/Silent',
                    '/Noninteractive'
                ) `
                -Wait -PassThru -ErrorAction Stop
            $result = if ($process.ExitCode -eq 0) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "HP Image Assistant exited with code $($process.ExitCode)."
                )
            }
            $result.Code = if ($result.Success) {
                'PHX_DRIVER_INSTALLED'
            }
            else { 'PHX_DRIVER_INSTALL_FAILED' }
            $result.Provider = $this.Name
            $result.Operation = 'InstallDriver'
            $result.Target = $Update.Id
            $result.HasExitCode = $true
            $result.ExitCode = $process.ExitCode
            $result.Data = $Update
            return $result
        }
        catch {
            return $this.NewAdapterFailure(
                $_.Exception.Message,
                'PHX_DRIVER_INSTALL_FAILED'
            )
        }
    }

    hidden [Result] NewAdapterFailure([string]$Message, [string]$Code) {
        $result = [Result]::Failure($Message)
        $result.Code = $Code
        $result.Provider = $this.Name
        $result.Operation = 'InstallDriver'
        return $result
    }
}
