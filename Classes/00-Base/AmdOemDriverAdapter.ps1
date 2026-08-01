class AmdOemDriverAdapter : PhoenixOemDriverAdapter {
    [string]$UtilityPath

    AmdOemDriverAdapter() : base('AMD', @(), @('PCI\VEN_1002')) {
        $this.UtilityName = 'AMD Software: Adrenalin Edition'
        $this.UtilityUri = 'https://www.amd.com/en/support/download/drivers.html'
        $candidatePaths = @()
        foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not [string]::IsNullOrWhiteSpace($root)) {
                $candidatePaths += Join-Path $root 'AMD\CIM\Bin64\InstallManagerApp.exe'
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
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @('-CheckForUpdates','-Silent') `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) { return @() }
            return @($this.NewRecommendedUpdate())
        }
        catch { return @() }
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        if ($null -eq $Update) {
            return $this.NewFailure('An AMD driver update is required.', 'PHX_INVALID_DRIVER')
        }
        if (-not $this.UtilityAvailable) {
            return $this.NewFailure(
                'AMD Software requires approval and installation.',
                'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            )
        }
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @('-Update','-Install','-Silent','-NoRestart') `
                -Wait -PassThru -ErrorAction Stop
            return $this.NewInstallResult($Update, $process.ExitCode)
        }
        catch { return $this.NewFailure($_.Exception.Message, 'PHX_DRIVER_INSTALL_FAILED') }
    }

    hidden [PhoenixOemDriverUpdate] NewRecommendedUpdate() {
        $update = [PhoenixOemDriverUpdate]::new()
        $update.Id = 'AMD-Recommended'
        $update.Name = 'AMD recommended driver updates'
        $update.Adapter = $this.Name
        $update.Manufacturer = 'AMD'
        $update.HardwareIds = @('PCI\VEN_1002')
        $update.AvailableVersion = 'Recommended'
        $update.Source = $this.UtilityName
        $update.ReleaseNotes = 'Updates selected by AMD Software.'
        $update.SupportUrl = $this.UtilityUri
        $update.Applicable = $true
        return $update
    }

    hidden [Result] NewInstallResult([PhoenixOemDriverUpdate]$Update, [int]$ExitCode) {
        $result = if ($ExitCode -in @(0,3010)) { [Result]::Success() }
            else { [Result]::Failure("AMD Software exited with code $ExitCode.") }
        $result.Code = if ($result.Success) { 'PHX_DRIVER_INSTALLED' }
            else { 'PHX_DRIVER_INSTALL_FAILED' }
        $result.Provider = $this.Name
        $result.Operation = 'InstallDriver'
        $result.Target = $Update.Id
        $result.HasExitCode = $true
        $result.ExitCode = $ExitCode
        $result.RebootRequired = $ExitCode -eq 3010
        $result.Data = $Update
        return $result
    }

    hidden [Result] NewFailure([string]$Message, [string]$Code) {
        $result = [Result]::Failure($Message)
        $result.Code = $Code
        $result.Provider = $this.Name
        $result.Operation = 'InstallDriver'
        return $result
    }
}
