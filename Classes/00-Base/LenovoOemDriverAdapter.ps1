class LenovoOemDriverAdapter : PhoenixOemDriverAdapter {
    [string]$UtilityPath

    LenovoOemDriverAdapter() : base('Lenovo', @('Lenovo'), @()) {
        $this.UtilityName = 'Lenovo System Update'
        $this.UtilityUri = 'https://support.lenovo.com/solutions/ht003029'
        $candidatePaths = @()
        foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not [string]::IsNullOrWhiteSpace($root)) {
                $candidatePaths += Join-Path $root 'Lenovo\System Update\tvsu.exe'
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
            $process = Start-Process -FilePath $this.UtilityPath -ArgumentList @(
                '/CM','-search','A','-action','LIST',
                '-includerebootpackages','3','-noicon'
            ) -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) { return @() }
            return @($this.NewRecommendedUpdate())
        }
        catch { return @() }
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        if ($null -eq $Update) {
            return $this.NewFailure('A Lenovo driver update is required.', 'PHX_INVALID_DRIVER')
        }
        if (-not $this.UtilityAvailable) {
            return $this.NewFailure(
                'Lenovo System Update requires approval and installation.',
                'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            )
        }
        try {
            $process = Start-Process -FilePath $this.UtilityPath -ArgumentList @(
                '/CM','-search','A','-action','INSTALL',
                '-includerebootpackages','1,3,4','-noicon'
            ) -Wait -PassThru -ErrorAction Stop
            return $this.NewInstallResult($Update, $process.ExitCode)
        }
        catch { return $this.NewFailure($_.Exception.Message, 'PHX_DRIVER_INSTALL_FAILED') }
    }

    hidden [PhoenixOemDriverUpdate] NewRecommendedUpdate() {
        $update = [PhoenixOemDriverUpdate]::new()
        $update.Id = 'Lenovo-Recommended'
        $update.Name = 'Lenovo recommended driver updates'
        $update.Adapter = $this.Name
        $update.Manufacturer = 'Lenovo'
        $update.AvailableVersion = 'Recommended'
        $update.Source = $this.UtilityName
        $update.ReleaseNotes = 'Updates selected by Lenovo System Update.'
        $update.SupportUrl = $this.UtilityUri
        $update.Applicable = $true
        return $update
    }

    hidden [Result] NewInstallResult([PhoenixOemDriverUpdate]$Update, [int]$ExitCode) {
        $result = if ($ExitCode -in @(0,3010)) { [Result]::Success() }
            else { [Result]::Failure("Lenovo System Update exited with code $ExitCode.") }
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
