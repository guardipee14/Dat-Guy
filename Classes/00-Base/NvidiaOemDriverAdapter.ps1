class NvidiaOemDriverAdapter : PhoenixOemDriverAdapter {
    [string]$UtilityPath

    NvidiaOemDriverAdapter() : base('NVIDIA', @(), @('PCI\VEN_10DE')) {
        $this.UtilityName = 'NVIDIA App'
        $this.UtilityUri = 'https://www.nvidia.com/en-us/software/nvidia-app/'
        $candidatePaths = @()
        foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not [string]::IsNullOrWhiteSpace($root)) {
                $candidatePaths += Join-Path `
                    $root `
                    'NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe'
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
                -ArgumentList @('--check-for-updates','--silent') `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) { return @() }
            return @($this.NewRecommendedUpdate())
        }
        catch { return @() }
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        if ($null -eq $Update) {
            return $this.NewFailure('An NVIDIA driver update is required.', 'PHX_INVALID_DRIVER')
        }
        if (-not $this.UtilityAvailable) {
            return $this.NewFailure(
                'NVIDIA App requires approval and installation.',
                'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            )
        }
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @('--install-update','--silent','--no-restart') `
                -Wait -PassThru -ErrorAction Stop
            return $this.NewInstallResult($Update, $process.ExitCode)
        }
        catch { return $this.NewFailure($_.Exception.Message, 'PHX_DRIVER_INSTALL_FAILED') }
    }

    hidden [PhoenixOemDriverUpdate] NewRecommendedUpdate() {
        $update = [PhoenixOemDriverUpdate]::new()
        $update.Id = 'NVIDIA-Recommended'
        $update.Name = 'NVIDIA recommended driver updates'
        $update.Adapter = $this.Name
        $update.Manufacturer = 'NVIDIA'
        $update.HardwareIds = @('PCI\VEN_10DE')
        $update.AvailableVersion = 'Recommended'
        $update.Source = $this.UtilityName
        $update.ReleaseNotes = 'Updates selected by NVIDIA App.'
        $update.SupportUrl = $this.UtilityUri
        $update.Applicable = $true
        return $update
    }

    hidden [Result] NewInstallResult([PhoenixOemDriverUpdate]$Update, [int]$ExitCode) {
        $result = if ($ExitCode -in @(0,3010)) { [Result]::Success() }
            else { [Result]::Failure("NVIDIA App exited with code $ExitCode.") }
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
