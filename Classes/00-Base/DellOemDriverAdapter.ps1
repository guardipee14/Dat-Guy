class DellOemDriverAdapter : PhoenixOemDriverAdapter {
    [string]$UtilityPath

    DellOemDriverAdapter() : base(
        'Dell',
        @('Dell Inc.', 'Dell Computer Corporation'),
        @()
    ) {
        $this.UtilityName = 'Dell Command | Update'
        $this.UtilityUri = 'https://www.dell.com/support/kbdoc/000177325'
        $candidatePaths = @()
        foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not [string]::IsNullOrWhiteSpace($root)) {
                $candidatePaths += Join-Path `
                    $root `
                    'Dell\CommandUpdate\dcu-cli.exe'
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
        [string]$logPath = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ("Phoenix-Dell-$([guid]::NewGuid().ToString('N')).log")
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @('/scan','-silent',"-outputLog=$logPath") `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) { return @() }
            $update = [PhoenixOemDriverUpdate]::new()
            $update.Id = 'Dell-Recommended'
            $update.Name = 'Dell recommended driver updates'
            $update.Adapter = $this.Name
            $update.Manufacturer = 'Dell'
            $update.AvailableVersion = 'Recommended'
            $update.Source = $this.UtilityName
            $update.ReleaseNotes = if (Test-Path -LiteralPath $logPath) {
                (Get-Content -LiteralPath $logPath -Raw -ErrorAction SilentlyContinue)
            }
            else { '' }
            $update.SupportUrl = $this.UtilityUri
            $update.Applicable = $true
            return @($update)
        }
        catch { return @() }
        finally {
            Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
        }
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        if ($null -eq $Update) {
            return $this.NewAdapterFailure(
                'A Dell driver update is required.',
                'PHX_INVALID_DRIVER'
            )
        }
        if (-not $this.UtilityAvailable) {
            return $this.NewAdapterFailure(
                'Dell Command | Update requires approval and installation.',
                'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            )
        }
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @('/applyUpdates','-silent','-reboot=disable') `
                -Wait -PassThru -ErrorAction Stop
            $result = if ($process.ExitCode -eq 0) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Dell Command | Update exited with code $($process.ExitCode)."
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
