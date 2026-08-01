# -----------------------------------------------------------------
# AUTO-GENERATED FILE
# DO NOT EDIT
# -----------------------------------------------------------------

#region 00-Base\PhoenixPrivilegeLevel.ps1
enum PhoenixPrivilegeLevel {

    User = 0
    Administrator = 1
    System = 2

}
#endregion 00-Base\PhoenixPrivilegeLevel.ps1

#region 00-Base\PhoenixInstallMode.ps1
enum PhoenixInstallMode {

    SilentPreferred = 0
    SilentOnly      = 1
    InteractiveOnly = 2
}
#endregion 00-Base\PhoenixInstallMode.ps1

#region 00-Base\PhoenixProviderOperation.ps1
enum PhoenixProviderOperation {

    Search = 0
    Inventory = 1
    Install = 2
    Update = 3
    Repair = 4
    Remove = 5
    Export = 6
    Restore = 7

}
#endregion 00-Base\PhoenixProviderOperation.ps1

#region 00-Base\PhoenixProviderAvailability.ps1
enum PhoenixProviderAvailability {

    Unknown = 0
    Available = 1
    Unavailable = 2
    Degraded = 3

}
#endregion 00-Base\PhoenixProviderAvailability.ps1

#region 00-Base\Result.ps1
class Result {

    [bool]$Success

    [string]$Message

    [string]$Code

    [object]$Data

    [object[]]$Warnings

    [object[]]$Errors

    [string]$Provider

    [string]$Operation

    [string]$Target

    [bool]$HasExitCode

    [int]$ExitCode

    [bool]$RebootRequired

    [bool]$TimedOut

    [bool]$Cancelled

    [datetime]$Timestamp

    Result() {

        $this.Timestamp = Get-Date
        $this.Warnings = @()
        $this.Errors = @()
        $this.Provider = ''
        $this.Operation = ''
        $this.Target = ''

    }

    static [Result] Success() {

    $r = [Result]::new()

    $r.Success = $true

    return $r
}

static [Result] Success(
    [object]$Data
) {

    $r = [Result]::new()

    $r.Success = $true
    $r.Data = $Data

    return $r
}

    static [Result] Failure(
        [string]$Message
    ) {

        $r = [Result]::new()

        $r.Success = $false
        $r.Message = $Message

        return $r

    }

}
#endregion 00-Base\Result.ps1

#region 00-Base\PhoenixProviderCapability.ps1
class PhoenixProviderCapability {

    [string]$ProviderName
    [string]$ProviderVersion
    [PhoenixProviderAvailability]$Availability
    [bool]$Available
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [bool]$SupportsSearch
    [bool]$SupportsInventory
    [bool]$SupportsInstall
    [bool]$SupportsUpdate
    [bool]$SupportsRepair
    [bool]$SupportsRemove
    [bool]$SupportsExport
    [bool]$SupportsRestore
    [string[]]$SupportedOperations
    [string]$HealthMessage
    [datetime]$CheckedAtUtc

    PhoenixProviderCapability() {

        $this.ProviderName = ''
        $this.ProviderVersion = ''
        $this.Availability =
            [PhoenixProviderAvailability]::Unknown
        $this.Available = $false
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.SupportedOperations = @()
        $this.HealthMessage = 'Provider health has not been checked.'
        $this.CheckedAtUtc = [datetime]::UtcNow
    }

    [bool] Supports(
        [PhoenixProviderOperation]$Operation
    ) {

        if ($Operation -eq [PhoenixProviderOperation]::Search) {
            return $this.SupportsSearch
        }

        if ($Operation -eq [PhoenixProviderOperation]::Inventory) {
            return $this.SupportsInventory
        }

        if ($Operation -eq [PhoenixProviderOperation]::Install) {
            return $this.SupportsInstall
        }

        if ($Operation -eq [PhoenixProviderOperation]::Update) {
            return $this.SupportsUpdate
        }

        if ($Operation -eq [PhoenixProviderOperation]::Repair) {
            return $this.SupportsRepair
        }

        if ($Operation -eq [PhoenixProviderOperation]::Remove) {
            return $this.SupportsRemove
        }

        if ($Operation -eq [PhoenixProviderOperation]::Export) {
            return $this.SupportsExport
        }

        if ($Operation -eq [PhoenixProviderOperation]::Restore) {
            return $this.SupportsRestore
        }

        return $false
    }
}
#endregion 00-Base\PhoenixProviderCapability.ps1

#region 00-Base\PhoenixProviderResult.ps1
class PhoenixProviderResult {

    [string]$ProviderName
    [PhoenixProviderOperation]$Operation
    [string]$Target
    [bool]$Success
    [string]$Code
    [string]$Message
    [object]$Data
    [string[]]$Warnings
    [string[]]$Errors
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [bool]$RequiresRestart
    [bool]$TimedOut
    [bool]$Cancelled
    [bool]$HasExitCode
    [int]$ExitCode
    [datetime]$Timestamp

    PhoenixProviderResult() {

        $this.ProviderName = ''
        $this.Target = ''
        $this.Code = ''
        $this.Message = ''
        $this.Warnings = @()
        $this.Errors = @()
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.Timestamp = [datetime]::UtcNow
    }
}
#endregion 00-Base\PhoenixProviderResult.ps1

#region 00-Base\Package.ps1
class Package {

    [string]$Name
    [string]$Id
    [string]$Version
    [string]$Provider
    [string]$InstallerType
    [string]$Source
    [string]$Architecture

    [bool]$Installed
    [bool]$RequiresElevation

    # Mainly used by EXE and GitHub-downloaded installers.
    [string[]]$SilentArguments
    [string[]]$InteractiveArguments
    [string]$WorkingDirectory
    [string]$DownloadedFile
    [string[]]$CleanupPaths

    [bool]$PreserveDownloads

    Package() {

        $this.Installed = $false
        $this.RequiresElevation = $false

        $this.SilentArguments = @()
        $this.InteractiveArguments = @()
        $this.WorkingDirectory = ''
        $this.DownloadedFile = ''
        $this.CleanupPaths = @()

        $this.PreserveDownloads = $false
    }
}
#endregion 00-Base\Package.ps1

#region 00-Base\EXEPackageDefinition.ps1
class EXEPackageDefinition : Package {
    [string]$InstallCommand
    [string]$UninstallCommand
    [string]$QuietUninstallCommand
    [string]$RepairCommand
    [int[]]$SuccessExitCodes
    [int[]]$RebootExitCodes

    EXEPackageDefinition() {
        $this.InstallerType = 'EXE'
        $this.SuccessExitCodes = @(0)
        $this.RebootExitCodes = @(1641, 3010)
    }
}
#endregion 00-Base\EXEPackageDefinition.ps1

#region 00-Base\GitHubReleasePackageDefinition.ps1
class GitHubReleasePackageDefinition : EXEPackageDefinition {
    [string]$Repository
    [string]$ReleaseTag
    [string]$ReleaseName
    [string]$AssetName
    [string]$AssetPattern
    [string]$DownloadUri
    [string]$ChecksumUri
    [string]$SHA256
    [string]$InstalledVersion
    [string]$DetectionDisplayName
    [string]$ReleaseNotes
    [string]$ReleaseNotesUrl
    [datetime]$PublishedAtUtc

    GitHubReleasePackageDefinition() {
        $this.Provider = 'GitHub Releases'
        $this.Source = 'github.com'
    }
}
#endregion 00-Base\GitHubReleasePackageDefinition.ps1

#region 00-Base\PowerShellGalleryPackageDefinition.ps1
class PowerShellGalleryPackageDefinition : Package {
    [string]$ResourceType
    [string]$Repository
    [string]$InstalledVersion
    [string]$Description

    PowerShellGalleryPackageDefinition() {
        $this.Provider = 'PowerShell Gallery'
        $this.Source = 'PSGallery'
        $this.Repository = 'PSGallery'
        $this.RequiresElevation = $false
    }
}
#endregion 00-Base\PowerShellGalleryPackageDefinition.ps1

#region 00-Base\NuGetPackageDefinition.ps1
class NuGetPackageDefinition : Package {
    [string]$FeedUrl
    [string]$DownloadUri
    [string]$InstalledVersion
    [string]$Description
    [string]$Authors

    NuGetPackageDefinition() {
        $this.Provider = 'NuGet'
        $this.InstallerType = 'NuGet'
        $this.RequiresElevation = $false
    }
}
#endregion 00-Base\NuGetPackageDefinition.ps1

#region 00-Base\DISMPackageDefinition.ps1
class DISMPackageDefinition : Package {
    [string]$ServicingType
    [string]$State
    [string]$SourcePath

    DISMPackageDefinition() {
        $this.Provider = 'DISM'
        $this.Source = 'Online Windows Image'
        $this.RequiresElevation = $true
    }
}
#endregion 00-Base\DISMPackageDefinition.ps1

#region 00-Base\WSUSPackageDefinition.ps1
class WSUSPackageDefinition : Package {
    [string]$UpdateId
    [int]$RevisionNumber
    [string[]]$KBArticleIds
    [string]$ApprovalStatus
    [bool]$Applicable
    [bool]$Downloaded
    [bool]$Mandatory

    WSUSPackageDefinition() {
        $this.Provider = 'WSUS'
        $this.InstallerType = 'WindowsUpdate'
        $this.RequiresElevation = $true
        $this.KBArticleIds = @()
    }
}
#endregion 00-Base\WSUSPackageDefinition.ps1

#region 00-Base\Driver.ps1
class Driver {

    [string]$Name
    [string]$Manufacturer
    [string]$Version
    [string]$Class
    [string]$Provider
    [string]$InfName
    [bool]$Present

    Driver() { }

}
#endregion 00-Base\Driver.ps1

#region 00-Base\PhoenixOemDriverUpdate.ps1
class PhoenixOemDriverUpdate : Driver {
    [string]$Id
    [string]$Adapter
    [string[]]$HardwareIds
    [string]$InstalledVersion
    [string]$AvailableVersion
    [string]$Source
    [datetime]$ReleaseDate
    [string]$ReleaseNotes
    [string]$SupportUrl
    [string]$DownloadUri
    [bool]$Applicable
    [bool]$RebootRequired

    PhoenixOemDriverUpdate() {
        $this.HardwareIds = @()
        $this.Applicable = $false
    }
}
#endregion 00-Base\PhoenixOemDriverUpdate.ps1

#region 00-Base\PhoenixOemDriverAdapter.ps1
class PhoenixOemDriverAdapter {
    [string]$Name
    [string[]]$Manufacturers
    [string[]]$HardwareIdPrefixes
    [string]$UtilityName
    [string]$UtilityUri
    [bool]$RequiresUtilityApproval
    [bool]$UtilityAvailable
    [bool]$Applicable

    PhoenixOemDriverAdapter(
        [string]$Name,
        [string[]]$Manufacturers,
        [string[]]$HardwareIdPrefixes
    ) {
        $this.Name = $Name
        $this.Manufacturers = $Manufacturers
        $this.HardwareIdPrefixes = $HardwareIdPrefixes
        $this.RequiresUtilityApproval = $true
    }

    [bool] TestApplicable(
        [string]$Manufacturer,
        [string[]]$HardwareIds
    ) {
        [bool]$manufacturerMatch = $this.Manufacturers.Count -eq 0
        foreach ($candidate in $this.Manufacturers) {
            if ($Manufacturer -like "*$candidate*") {
                $manufacturerMatch = $true
                break
            }
        }
        if (-not $manufacturerMatch) { return $false }
        if ($this.HardwareIdPrefixes.Count -eq 0) { return $true }
        foreach ($hardwareId in @($HardwareIds)) {
            foreach ($prefix in $this.HardwareIdPrefixes) {
                if ($hardwareId.StartsWith(
                    $prefix,
                    [StringComparison]::OrdinalIgnoreCase
                )) { return $true }
            }
        }
        return $false
    }

    [PhoenixOemDriverUpdate[]] Scan([object]$HardwareIdentity) {
        return @()
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        $result = [Result]::Failure(
            "OEM driver installation is not implemented for $($this.Name)."
        )
        $result.Code = 'PHX_OEM_INSTALL_UNAVAILABLE'
        $result.Provider = $this.Name
        $result.Operation = 'InstallDriver'
        $result.Target = if ($null -ne $Update) { $Update.Id } else { '' }
        return $result
    }

    [object] GetStatus() {
        return [pscustomobject]@{
            Name = $this.Name
            Manufacturers = $this.Manufacturers -join ', '
            UtilityName = $this.UtilityName
            UtilityUri = $this.UtilityUri
            RequiresUtilityApproval = $this.RequiresUtilityApproval
            UtilityAvailable = $this.UtilityAvailable
            Applicable = $this.Applicable
        }
    }
}
#endregion 00-Base\PhoenixOemDriverAdapter.ps1

#region 00-Base\DellOemDriverAdapter.ps1
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
#endregion 00-Base\DellOemDriverAdapter.ps1

#region 00-Base\HpOemDriverAdapter.ps1
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
#endregion 00-Base\HpOemDriverAdapter.ps1

#region 00-Base\LenovoOemDriverAdapter.ps1
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
#endregion 00-Base\LenovoOemDriverAdapter.ps1

#region 00-Base\IntelOemDriverAdapter.ps1
class IntelOemDriverAdapter : PhoenixOemDriverAdapter {
    [string]$UtilityPath

    IntelOemDriverAdapter() : base('Intel', @(), @('PCI\VEN_8086')) {
        $this.UtilityName = 'Intel Driver & Support Assistant'
        $this.UtilityUri = 'https://www.intel.com/content/www/us/en/support/detect.html'
        $candidatePaths = @()
        foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
            if (-not [string]::IsNullOrWhiteSpace($root)) {
                $candidatePaths += Join-Path `
                    $root `
                    'Intel\Driver and Support Assistant\DSAServiceHelper.exe'
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
                -ArgumentList @('/scan','/silent') `
                -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) { return @() }
            return @($this.NewRecommendedUpdate())
        }
        catch { return @() }
    }

    [Result] Install([PhoenixOemDriverUpdate]$Update) {
        if ($null -eq $Update) {
            return $this.NewFailure('An Intel driver update is required.', 'PHX_INVALID_DRIVER')
        }
        if (-not $this.UtilityAvailable) {
            return $this.NewFailure(
                'Intel Driver & Support Assistant requires approval and installation.',
                'PHX_OEM_UTILITY_APPROVAL_REQUIRED'
            )
        }
        try {
            $process = Start-Process `
                -FilePath $this.UtilityPath `
                -ArgumentList @('/install','/silent','/norestart') `
                -Wait -PassThru -ErrorAction Stop
            return $this.NewInstallResult($Update, $process.ExitCode)
        }
        catch { return $this.NewFailure($_.Exception.Message, 'PHX_DRIVER_INSTALL_FAILED') }
    }

    hidden [PhoenixOemDriverUpdate] NewRecommendedUpdate() {
        $update = [PhoenixOemDriverUpdate]::new()
        $update.Id = 'Intel-Recommended'
        $update.Name = 'Intel recommended driver updates'
        $update.Adapter = $this.Name
        $update.Manufacturer = 'Intel'
        $update.HardwareIds = @('PCI\VEN_8086')
        $update.AvailableVersion = 'Recommended'
        $update.Source = $this.UtilityName
        $update.ReleaseNotes = 'Updates selected by Intel Driver & Support Assistant.'
        $update.SupportUrl = $this.UtilityUri
        $update.Applicable = $true
        return $update
    }

    hidden [Result] NewInstallResult([PhoenixOemDriverUpdate]$Update, [int]$ExitCode) {
        $result = if ($ExitCode -in @(0,3010)) { [Result]::Success() }
            else { [Result]::Failure("Intel Driver & Support Assistant exited with code $ExitCode.") }
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
#endregion 00-Base\IntelOemDriverAdapter.ps1

#region 00-Base\AmdOemDriverAdapter.ps1
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
#endregion 00-Base\AmdOemDriverAdapter.ps1

#region 00-Base\NvidiaOemDriverAdapter.ps1
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
#endregion 00-Base\NvidiaOemDriverAdapter.ps1

#region 10-Core\PhoenixLogger.ps1
class PhoenixLogger {

    [string]$LogDirectory
    [string]$LogFile
    [string]$MinimumLevel
    [int]$MaximumLogFiles

    hidden [bool]$RetentionApplied

    PhoenixLogger([string]$ProjectRoot) {

        $this.LogDirectory =
            Join-Path `
                $ProjectRoot `
                'Logs'

        if (-not (Test-Path -LiteralPath $this.LogDirectory)) {

            New-Item `
                -ItemType Directory `
                -Path $this.LogDirectory `
                -Force |
                Out-Null
        }

        $this.LogFile =
            Join-Path `
                $this.LogDirectory `
                (
                    'Phoenix-{0}.log' -f
                    (
                        Get-Date `
                            -Format 'yyyyMMdd-HHmmss-fff'
                    )
                )

        $this.MinimumLevel = 'Info'
        $this.MaximumLogFiles = 20
        $this.RetentionApplied = $false
    }

    [void] Configure(
        [string]$MinimumLevel,
        [int]$MaximumLogFiles
    ) {

        if (
            $this.GetLevelRank($MinimumLevel, $true) -lt 0
        ) {
            throw [ArgumentException]::new(
                "Unsupported Phoenix minimum log level '$MinimumLevel'."
            )
        }

        if ($MaximumLogFiles -lt 1) {
            throw [ArgumentOutOfRangeException]::new(
                'MaximumLogFiles',
                'MaximumLogFiles must be at least 1.'
            )
        }

        $this.MinimumLevel =
            $this.NormalizeLevel($MinimumLevel)

        $this.MaximumLogFiles = $MaximumLogFiles
    }

    [void] Write(
        [string]$Level,
        [string]$Message
    ) {

        [int]$levelRank =
            $this.GetLevelRank($Level, $false)

        if ($levelRank -lt 0) {
            throw [ArgumentException]::new(
                "Unsupported Phoenix log level '$Level'."
            )
        }

        if ([string]::IsNullOrWhiteSpace($Message)) {
            throw [ArgumentException]::new(
                'Phoenix log messages cannot be empty.'
            )
        }

        [int]$minimumRank =
            $this.GetLevelRank(
                $this.MinimumLevel,
                $true
            )

        if ($levelRank -lt $minimumRank) {
            return
        }

        [string]$normalizedLevel =
            $this.NormalizeLevel($Level)

        [string]$line = (
            '[{0}] [{1}] {2}' -f
            (
                Get-Date `
                    -Format 'yyyy-MM-dd HH:mm:ss'
            ),
            $normalizedLevel.ToUpperInvariant(),
            $Message
        )

        Add-Content `
            -LiteralPath $this.LogFile `
            -Value $line `
            -Encoding UTF8 `
            -ErrorAction Stop

        if (-not $this.RetentionApplied) {
            $this.ApplyRetention()
        }
    }

    hidden [void] ApplyRetention() {

        $this.RetentionApplied = $true

        [string]$currentLogPath =
            [IO.Path]::GetFullPath($this.LogFile)

        [object[]]$previousLogs = @(
            Get-ChildItem `
                -LiteralPath $this.LogDirectory `
                -Filter 'Phoenix-*.log' `
                -File `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -match (
                        '^Phoenix-\d{8}-\d{6}(?:-\d{3})?\.log$'
                    ) -and
                    [IO.Path]::GetFullPath($_.FullName) -ne
                        $currentLogPath
                } |
                Sort-Object `
                    -Property @(
                        @{
                            Expression = {
                                $_.LastWriteTimeUtc
                            }
                            Descending = $true
                        }
                        @{
                            Expression = {
                                $_.Name
                            }
                            Descending = $true
                        }
                    )
        )

        [int]$previousLogsToKeep =
            $this.MaximumLogFiles - 1

        [object[]]$expiredLogs = @(
            $previousLogs |
                Select-Object `
                    -Skip $previousLogsToKeep
        )

        foreach ($expiredLog in $expiredLogs) {

            try {
                Remove-Item `
                    -LiteralPath $expiredLog.FullName `
                    -Force `
                    -ErrorAction Stop
            }
            catch {
                Write-Warning (
                    "Could not remove expired Phoenix log '{0}': {1}" -f
                    $expiredLog.FullName,
                    $_.Exception.Message
                )
            }
        }
    }

    hidden [int] GetLevelRank(
        [string]$Level,
        [bool]$MinimumLevel
    ) {

        if ([string]::IsNullOrWhiteSpace($Level)) {
            return -1
        }

        switch ($Level.Trim().ToUpperInvariant()) {
            'DEBUG' {
                return 0
            }
            'VERBOSE' {
                return 1
            }
            'INFO' {
                return 2
            }
            'SUCCESS' {

                if ($MinimumLevel) {
                    return -1
                }

                return 2
            }
            'WARNING' {
                return 3
            }
            'ERROR' {
                return 4
            }
            default {
                return -1
            }
        }

        return -1
    }

    hidden [string] NormalizeLevel([string]$Level) {

        switch ($Level.Trim().ToUpperInvariant()) {
            'DEBUG' {
                return 'Debug'
            }
            'VERBOSE' {
                return 'Verbose'
            }
            'INFO' {
                return 'Info'
            }
            'SUCCESS' {
                return 'Success'
            }
            'WARNING' {
                return 'Warning'
            }
            'ERROR' {
                return 'Error'
            }
            default {
                throw [ArgumentException]::new(
                    "Unsupported Phoenix log level '$Level'."
                )
            }
        }

        return ''
    }
}
#endregion 10-Core\PhoenixLogger.ps1

#region 10-Core\PhoenixConfiguration.ps1
class PhoenixConfiguration {

    [string]$ConfigDirectory
    [string]$ConfigFile
    [hashtable]$Settings

    PhoenixConfiguration([string]$ProjectRoot) {

        $this.ConfigDirectory =
            Join-Path $ProjectRoot 'Config'

        $this.ConfigFile =
            Join-Path $this.ConfigDirectory 'Phoenix.json'

        $this.Settings = @{}
    }

    [void] Load() {

        if (Test-Path $this.ConfigFile) {

            [object]$jsonObject =
                Get-Content $this.ConfigFile -Raw |
                    ConvertFrom-Json

            $this.Settings = @{}

            foreach ($property in $jsonObject.PSObject.Properties) {
                $this.Settings[$property.Name] = $property.Value
            }
        }
    }

    [void] Save() {

        if (-not (Test-Path $this.ConfigDirectory)) {

            New-Item `
                -ItemType Directory `
                -Path $this.ConfigDirectory `
                -Force |
                Out-Null
        }

        $this.Settings |
            ConvertTo-Json -Depth 10 |
            Set-Content $this.ConfigFile
    }

    [object] Get([string]$Name) {

        return $this.Settings[$Name]
    }

    [void] Set(
        [string]$Name,
        [object]$Value
    ) {

        $this.Settings[$Name] = $Value
    }
}
#endregion 10-Core\PhoenixConfiguration.ps1

#region 10-Core\PhoenixBuild.ps1
class PhoenixBuild {

    [datetime]$StartTime
    [datetime]$EndTime

    [string]$Version
    [string]$Status

    PhoenixBuild() {

        $this.StartTime = Get-Date
        $this.Version = '0.1.0-alpha'
        $this.Status = 'Running'

    }

    [void] Finish() {

        $this.EndTime = Get-Date
        $this.Status = 'Completed'

    }

}
#endregion 10-Core\PhoenixBuild.ps1

#region 10-Core\PhoenixBackgroundOperation.ps1
enum PhoenixBackgroundOperationState {
    Created
    Queued
    Starting
    Running
    CancellationRequested
    Cancelled
    Completed
    Failed
}

class PhoenixBackgroundOperation {

    [string]$OperationId
    [string]$Action
    [object]$Parameters
    [string]$Component
    [string]$Description

    [PhoenixBackgroundOperationState]$State

    [datetime]$CreatedAtUtc
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc

    [object]$Process
    [object]$Timer

    [string]$JobDirectory
    [string]$RequestPath
    [string]$ProgressPath
    [string]$ResultPath

    [scriptblock]$Completion

    [int]$ProgressPercent
    [string]$ProgressMessage
    [string]$LastProgressKey

    [bool]$CancellationRequested
    [string]$ErrorMessage

    PhoenixBackgroundOperation(
        [string]$Action,
        [object]$Parameters,
        [string]$Component,
        [string]$Description,
        [scriptblock]$Completion
    ) {
        if ([string]::IsNullOrWhiteSpace($Action)) {
            throw 'A background operation action is required.'
        }

        if ([string]::IsNullOrWhiteSpace($Component)) {
            throw 'A background operation component is required.'
        }

        if ([string]::IsNullOrWhiteSpace($Description)) {
            throw 'A background operation description is required.'
        }

        if ($null -eq $Completion) {
            throw 'A background operation completion callback is required.'
        }

        $this.OperationId =
            [guid]::NewGuid().ToString('N')

        $this.Action = $Action
        $this.Parameters = $Parameters
        $this.Component = $Component
        $this.Description = $Description
        $this.Completion = $Completion

        $this.State =
            [PhoenixBackgroundOperationState]::Created

        $this.CreatedAtUtc =
            [datetime]::UtcNow

        $this.StartedAtUtc =
            [datetime]::MinValue

        $this.CompletedAtUtc =
            [datetime]::MinValue

        $this.Process = $null
        $this.Timer = $null

        $this.JobDirectory = ''
        $this.RequestPath = ''
        $this.ProgressPath = ''
        $this.ResultPath = ''

        $this.ProgressPercent = 0
        $this.ProgressMessage = $Description
        $this.LastProgressKey = ''

        $this.CancellationRequested = $false
        $this.ErrorMessage = ''
    }

    [void] MarkQueued() {
        $this.AssertState(
            [PhoenixBackgroundOperationState]::Created
        )

        $this.State =
            [PhoenixBackgroundOperationState]::Queued
    }

    [void] MarkStarting() {
        if (
            $this.State -ne
                [PhoenixBackgroundOperationState]::Created -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::Queued
        ) {
            throw (
                "Operation '$($this.OperationId)' cannot start " +
                "from state '$($this.State)'."
            )
        }

        $this.State =
            [PhoenixBackgroundOperationState]::Starting

        $this.StartedAtUtc =
            [datetime]::UtcNow
    }

    [void] MarkRunning() {
        $this.AssertState(
            [PhoenixBackgroundOperationState]::Starting
        )

        $this.State =
            [PhoenixBackgroundOperationState]::Running
    }

    [void] UpdateProgress(
        [int]$Percent,
        [string]$Message
    ) {
        if (
            $this.State -ne
            [PhoenixBackgroundOperationState]::Running
        ) {
            throw (
                'Progress can only be updated while an operation ' +
                'is running.'
            )
        }

        if ($Percent -lt 0) {
            $Percent = 0
        }

        if ($Percent -gt 100) {
            $Percent = 100
        }

        $this.ProgressPercent = $Percent
        $this.ProgressMessage = $Message

        $this.LastProgressKey = (
            '{0}|{1}' -f
            $Percent,
            $Message
        )
    }

    [void] RequestCancellation() {
        if (-not $this.CanCancel()) {
            return
        }

        $this.CancellationRequested = $true

        $this.State =
            [PhoenixBackgroundOperationState]::CancellationRequested
    }

    [void] MarkCancelled() {
        if (
            $this.State -ne
                [PhoenixBackgroundOperationState]::Queued -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::Running -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::Starting -and
            $this.State -ne
                [PhoenixBackgroundOperationState]::CancellationRequested
        ) {
            throw (
                "Operation '$($this.OperationId)' cannot be " +
                "cancelled from state '$($this.State)'."
            )
        }

        $this.CancellationRequested = $true

        $this.State =
            [PhoenixBackgroundOperationState]::Cancelled

        $this.CompletedAtUtc =
            [datetime]::UtcNow
    }

    [void] MarkCompleted() {
        if (
            $this.State -ne
            [PhoenixBackgroundOperationState]::Running
        ) {
            throw (
                "Operation '$($this.OperationId)' cannot complete " +
                "from state '$($this.State)'."
            )
        }

        $this.ProgressPercent = 100

        $this.State =
            [PhoenixBackgroundOperationState]::Completed

        $this.CompletedAtUtc =
            [datetime]::UtcNow
    }

    [void] MarkFailed(
        [string]$Message
    ) {
        if ($this.IsTerminal()) {
            throw (
                "Operation '$($this.OperationId)' is already in " +
                "terminal state '$($this.State)'."
            )
        }

        $this.ErrorMessage = $Message

        $this.State =
            [PhoenixBackgroundOperationState]::Failed

        $this.CompletedAtUtc =
            [datetime]::UtcNow
    }

    [bool] CanCancel() {
        return (
            $this.State -eq
                [PhoenixBackgroundOperationState]::Queued -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Starting -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Running
        )
    }

    [bool] IsTerminal() {
        return (
            $this.State -eq
                [PhoenixBackgroundOperationState]::Cancelled -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Completed -or
            $this.State -eq
                [PhoenixBackgroundOperationState]::Failed
        )
    }

    hidden [void] AssertState(
        [PhoenixBackgroundOperationState]$ExpectedState
    ) {
        if ($this.State -ne $ExpectedState) {
            throw (
                "Operation '$($this.OperationId)' expected state " +
                "'$ExpectedState' but is '$($this.State)'."
            )
        }
    }
}
#endregion 10-Core\PhoenixBackgroundOperation.ps1

#region 20-Providers\PhoenixProvider\PhoenixProvider.Header.ps1
##########################################################
## PhoenixProvider composite class header
## Generated from the validated legacy provider
##########################################################

class PhoenixProvider {

    ##########################################################
    ## Properties
    ##########################################################

[string]$Name
[string]$Version
[string]$Type
[int]$Priority
[bool]$Available
[PhoenixPrivilegeLevel]$RequiredPrivilege
[bool]$SupportsSearch
[bool]$SupportsInventory
[bool]$SupportsInstall
[bool]$SupportsUpdate
[bool]$SupportsRemove
[bool]$SupportsExport
[bool]$SupportsOfflineCache
[bool]$SupportsDependencies
[bool]$SupportsSilentInstall
[bool]$SupportsInteractiveInstall
[bool]$SupportsRepair
[bool]$SupportsSilentRepair
[bool]$SupportsInteractiveRepair
[bool]$SupportsRestore
[bool]$SupportsCleanup
[bool]$CleanupAfterInstall
[bool]$CleanupOnFailure

    ##########################################################
    ## Constructor
    ##########################################################

PhoenixProvider() {

        $this.Name      = ""
        $this.Version   = ""
        $this.Type      = ""

        $this.Priority  = 0
        $this.Available = $false

        $this.SupportsSearch       = $true
        $this.SupportsInventory    = $true
        $this.SupportsInstall      = $true
        $this.SupportsUpdate       = $true
        $this.SupportsRemove       = $true
        $this.SupportsExport       = $false
        $this.SupportsOfflineCache = $false
        $this.SupportsDependencies = $false
        $this.SupportsSilentInstall      = $false
        $this.SupportsInteractiveInstall = $false
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsRepair = $false
        $this.SupportsSilentRepair = $false
        $this.SupportsInteractiveRepair = $false
        $this.SupportsRestore = $true

        $this.SupportsCleanup = $true
        $this.CleanupAfterInstall = $true
        $this.CleanupOnFailure = $false

    }

#endregion 20-Providers\PhoenixProvider\PhoenixProvider.Header.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\GetCapability.ps1
##########################################################
## Method: GetCapability
##########################################################

[PhoenixProviderCapability] GetCapability() {

    $capability = [PhoenixProviderCapability]::new()
    $capability.ProviderName = $this.Name
    $capability.ProviderVersion = $this.Version
    $capability.Available = $this.Available
    $capability.RequiredPrivilege = $this.RequiredPrivilege
    $capability.SupportsSearch = $this.SupportsSearch
    $capability.SupportsInventory = $this.SupportsInventory
    $capability.SupportsInstall = $this.SupportsInstall
    $capability.SupportsUpdate = $this.SupportsUpdate
    $capability.SupportsRepair = $this.SupportsRepair
    $capability.SupportsRemove = $this.SupportsRemove
    $capability.SupportsExport = $this.SupportsExport
    $capability.SupportsRestore = $this.SupportsRestore
    $capability.CheckedAtUtc = [datetime]::UtcNow

    if ($this.Available) {
        $capability.Availability =
            [PhoenixProviderAvailability]::Available
        $capability.HealthMessage = 'Ready'
    }
    else {
        $capability.Availability =
            [PhoenixProviderAvailability]::Unavailable
        $capability.HealthMessage =
            'Executable or service was not detected.'
    }

    $operationNames =
        [System.Collections.Generic.List[string]]::new()

    foreach (
        $operation in @(
            [PhoenixProviderOperation]::Search
            [PhoenixProviderOperation]::Inventory
            [PhoenixProviderOperation]::Install
            [PhoenixProviderOperation]::Update
            [PhoenixProviderOperation]::Repair
            [PhoenixProviderOperation]::Remove
            [PhoenixProviderOperation]::Export
            [PhoenixProviderOperation]::Restore
        )
    ) {
        if ($this.SupportsOperation($operation)) {
            $operationNames.Add($operation.ToString())
        }
    }

    $capability.SupportedOperations =
        $operationNames.ToArray()

    return $capability
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\GetCapability.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\InstallProvider.ps1
##########################################################
## Method: InstallProvider
## Legacy source line: 74
##########################################################

[Result] InstallProvider() {

        return [Result]::Failure(
            "$($this.Name) cannot install itself."
        )

    }

#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\InstallProvider.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeData.ps1
##########################################################
## Method: NormalizeData
##########################################################

[PhoenixProviderResult] NormalizeData(
    [object]$Data,
    [PhoenixProviderOperation]$Operation,
    [string]$Target
) {

    $sourceResult = [Result]::Success($Data)

    return $this.NormalizeResult(
        $sourceResult,
        $Operation,
        $Target
    )
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeData.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeResult.ps1
##########################################################
## Method: NormalizeResult
##########################################################

[PhoenixProviderResult] NormalizeResult(
    [Result]$Result,
    [PhoenixProviderOperation]$Operation,
    [string]$Target
) {

    $normalized = [PhoenixProviderResult]::new()
    $normalized.ProviderName = $this.Name
    $normalized.Operation = $Operation
    $normalized.Target = $Target
    $normalized.RequiredPrivilege = $this.RequiredPrivilege

    if ($null -eq $Result) {
        $normalized.Success = $false
        $normalized.Code = 'PHX_PROVIDER_RESULT_MISSING'
        $normalized.Message =
            'The provider returned no result.'
        $normalized.Errors = @($normalized.Message)

        return $normalized
    }

    $normalized.Success = $Result.Success
    $normalized.Code = $Result.Code
    $normalized.Message = $Result.Message
    $normalized.Data = $Result.Data

    if ($Result.Timestamp -gt [datetime]::MinValue) {
        $normalized.Timestamp =
            $Result.Timestamp.ToUniversalTime()
    }

    $warningItems =
        [System.Collections.Generic.List[string]]::new()

    foreach ($warning in @($Result.Warnings)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$warning)) {
            $warningItems.Add([string]$warning)
        }
    }

    $errorItems =
        [System.Collections.Generic.List[string]]::new()

    foreach ($resultError in @($Result.Errors)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$resultError)) {
            $errorItems.Add([string]$resultError)
        }
    }

    if (
        -not $Result.Success -and
        $errorItems.Count -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($Result.Message)
    ) {
        $errorItems.Add($Result.Message)
    }

    $metadataCandidates =
        [System.Collections.Generic.List[object]]::new()

    $metadataCandidates.Add($Result)

    if ($null -ne $Result.Data) {
        foreach ($dataItem in @($Result.Data)) {
            if ($null -ne $dataItem) {
                $metadataCandidates.Add($dataItem)
            }
        }
    }

    foreach ($candidate in $metadataCandidates) {
        $exitCodeProperty =
            $candidate.PSObject.Properties['ExitCode']

        if (
            $null -ne $exitCodeProperty -and
            $null -ne $exitCodeProperty.Value
        ) {
            $normalized.ExitCode =
                [int]$exitCodeProperty.Value
            $normalized.HasExitCode = $true
        }

        foreach (
            $restartPropertyName in @(
                'RequiresRestart'
                'RebootRequired'
                'RestartRequired'
            )
        ) {
            $restartProperty =
                $candidate.PSObject.Properties[
                    $restartPropertyName
                ]

            if (
                $null -ne $restartProperty -and
                [bool]$restartProperty.Value
            ) {
                $normalized.RequiresRestart = $true
            }
        }

        foreach (
            $timeoutPropertyName in @(
                'TimedOut'
                'Timeout'
            )
        ) {
            $timeoutProperty =
                $candidate.PSObject.Properties[
                    $timeoutPropertyName
                ]

            if (
                $null -ne $timeoutProperty -and
                [bool]$timeoutProperty.Value
            ) {
                $normalized.TimedOut = $true
            }
        }

        foreach (
            $cancelPropertyName in @(
                'Cancelled'
                'Canceled'
            )
        ) {
            $cancelProperty =
                $candidate.PSObject.Properties[
                    $cancelPropertyName
                ]

            if (
                $null -ne $cancelProperty -and
                [bool]$cancelProperty.Value
            ) {
                $normalized.Cancelled = $true
            }
        }
    }

    $normalized.Warnings = $warningItems.ToArray()
    $normalized.Errors = $errorItems.ToArray()

    if ([string]::IsNullOrWhiteSpace($normalized.Code)) {
        [string]$operationName =
            $Operation.ToString().ToUpperInvariant()

        $normalized.Code = if ($normalized.Success) {
            "PHX_PROVIDER_$($operationName)_SUCCEEDED"
        }
        else {
            "PHX_PROVIDER_$($operationName)_FAILED"
        }
    }

    return $normalized
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\NormalizeResult.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\SupportsOperation.ps1
##########################################################
## Method: SupportsOperation
##########################################################

[bool] SupportsOperation(
    [PhoenixProviderOperation]$Operation
) {

    if ($Operation -eq [PhoenixProviderOperation]::Search) {
        return $this.SupportsSearch
    }

    if ($Operation -eq [PhoenixProviderOperation]::Inventory) {
        return $this.SupportsInventory
    }

    if ($Operation -eq [PhoenixProviderOperation]::Install) {
        return $this.SupportsInstall
    }

    if ($Operation -eq [PhoenixProviderOperation]::Update) {
        return $this.SupportsUpdate
    }

    if ($Operation -eq [PhoenixProviderOperation]::Repair) {
        return $this.SupportsRepair
    }

    if ($Operation -eq [PhoenixProviderOperation]::Remove) {
        return $this.SupportsRemove
    }

    if ($Operation -eq [PhoenixProviderOperation]::Export) {
        return $this.SupportsExport
    }

    if ($Operation -eq [PhoenixProviderOperation]::Restore) {
        return $this.SupportsRestore
    }

    return $false
}
#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\SupportsOperation.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\TestAvailable.ps1
##########################################################
## Method: TestAvailable
## Legacy source line: 68
##########################################################

[bool] TestAvailable() {

        return $false

    }

#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\TestAvailable.ps1

#region 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\UpdateProvider.ps1
##########################################################
## Method: UpdateProvider
## Legacy source line: 82
##########################################################

[Result] UpdateProvider() {

        return [Result]::Failure(
            "$($this.Name) cannot update itself."
        )

    }

#endregion 20-Providers\PhoenixProvider\Methods\10-ProviderManagement\UpdateProvider.ps1

#region 20-Providers\PhoenixProvider\Methods\20-Discovery\GetInstalledPackages.ps1
##########################################################
## Method: GetInstalledPackages
## Legacy source line: 94
##########################################################

[Package[]] GetInstalledPackages() {

        return @()

    }

#endregion 20-Providers\PhoenixProvider\Methods\20-Discovery\GetInstalledPackages.ps1

#region 20-Providers\PhoenixProvider\Methods\20-Discovery\SearchPackage.ps1
##########################################################
## Method: SearchPackage
## Legacy source line: 100
##########################################################

[Package[]] SearchPackage([string]$Name) {

        return @()

    }

#endregion 20-Providers\PhoenixProvider\Methods\20-Discovery\SearchPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\CanInstallSilently.ps1
##########################################################
## Method: CanInstallSilently
## Legacy source line: 286
##########################################################

[bool] CanInstallSilently([Package]$Package) {

        return $this.SupportsSilentInstall
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\CanInstallSilently.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackage.ps1
##########################################################
## Method: InstallPackage
## Legacy source line: 307
##########################################################

[Result] InstallPackage([Package]$Package) {

    return $this.InstallPackage(
        $Package,
        [PhoenixInstallMode]::SilentPreferred
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageCore.ps1
##########################################################
## Method: InstallPackageCore
## Legacy source line: 383
##########################################################

hidden [Result] InstallPackageCore(
    [Package]$Package,
    [PhoenixInstallMode]$Mode
) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ($Mode -eq [PhoenixInstallMode]::InteractiveOnly) {

        if (-not $this.SupportsInteractiveInstall) {

            return $this.NewFailure(
                "$($this.Name) does not support interactive installation.",
                'PHX_INTERACTIVE_UNAVAILABLE'
            )
        }

        return $this.InstallPackageInteractive(
            $Package
        )
    }

    if ($Mode -eq [PhoenixInstallMode]::SilentOnly) {

        if (-not $this.CanInstallSilently($Package)) {

            return $this.NewFailure(
                "No silent installation is available for '$($Package.Id)'.",
                'PHX_SILENT_UNAVAILABLE'
            )
        }

        return $this.InstallPackageSilent(
            $Package
        )
    }

    # SilentPreferred
    if ($this.CanInstallSilently($Package)) {

        [Result]$silentResult = $this.InstallPackageSilent(
            $Package
        )

        if ($silentResult.Success) {
            return $silentResult
        }

        # Only use interactive fallback when silent mode
        # is explicitly unavailable.
        if ($silentResult.Code -ne 'PHX_SILENT_UNAVAILABLE') {
            return $silentResult
        }
    }

    if ($this.SupportsInteractiveInstall) {

        Write-Host (
            "No silent installer is available for '$($Package.Id)'."
        ) -ForegroundColor Yellow

        Write-Host (
            'Starting the interactive installer...'
        ) -ForegroundColor Yellow

        return $this.InstallPackageInteractive(
            $Package
        )
    }

    return $this.NewFailure(
        "Neither silent nor interactive installation is available for '$($Package.Id)'.",
        'PHX_INSTALL_UNAVAILABLE'
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageCore.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageInteractive.ps1
##########################################################
## Method: InstallPackageInteractive
## Legacy source line: 299
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

        return $this.NewFailure(
            "$($this.Name) does not implement interactive installation.",
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageInteractive.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageSilent.ps1
##########################################################
## Method: InstallPackageSilent
## Legacy source line: 291
##########################################################

[Result] InstallPackageSilent([Package]$Package) {

        return $this.NewFailure(
            "$($this.Name) does not implement silent installation.",
            'PHX_SILENT_UNAVAILABLE'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageSilent.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageWithMode.ps1
##########################################################
## Method: InstallPackage
## Legacy source line: 315
##########################################################

[Result] InstallPackage(
    [Package]$Package,
    [PhoenixInstallMode]$Mode
) {

    [Result]$installResult = [Result]::Failure(
        'Package installation did not complete.'
    )

    try {

        $installResult = $this.InstallPackageCore(
            $Package,
            $Mode
        )
    }
    catch {

        $installResult = $this.NewFailure(
            "Package installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
    finally {

        [bool]$shouldCleanup = (
            $null -ne $Package -and
            $this.SupportsCleanup -and
            $this.CleanupAfterInstall -and
            (-not $Package.PreserveDownloads) -and
            (
                $installResult.Success -or
                $this.CleanupOnFailure
            )
        )

        if ($shouldCleanup) {

            [Result]$cleanupResult = $this.CleanupPackage(
                $Package
            )

            if (-not $cleanupResult.Success) {

                $installResult.Warnings = @(
                    $installResult.Warnings
                ) + @(
                    $cleanupResult.Message
                )

                if (
                    $null -ne $cleanupResult.Errors -and
                    $cleanupResult.Errors.Count -gt 0
                ) {

                    $installResult.Warnings = @(
                        $installResult.Warnings
                    ) + @(
                        $cleanupResult.Errors
                    )
                }
            }
        }
    }

    return $installResult
}

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\InstallPackageWithMode.ps1

#region 20-Providers\PhoenixProvider\Methods\30-Installation\NewFailure.ps1
##########################################################
## Method: NewFailure
## Legacy source line: 275
##########################################################

hidden [Result] NewFailure(
        [string]$Message,
        [string]$Code
    ) {

        $result = [Result]::Failure($Message)
        $result.Code = $Code

        return $result
    }

#endregion 20-Providers\PhoenixProvider\Methods\30-Installation\NewFailure.ps1

#region 20-Providers\PhoenixProvider\Methods\40-Cleanup\CleanupPackage.ps1
##########################################################
## Method: CleanupPackage
## Legacy source line: 184
##########################################################

[Result] CleanupPackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required for cleanup.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ($Package.PreserveDownloads) {

        $result = [Result]::Success(
            'Package downloads were preserved.'
        )

        $result.Code = 'PHX_CLEANUP_SKIPPED'

        return $result
    }

    $cleanupErrors =
        [System.Collections.Generic.List[string]]::new()

    [string[]]$paths = @(
        $Package.CleanupPaths
    ) |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object Length -Descending -Unique

    foreach ($path in $paths) {

        if (-not $this.IsPhoenixManagedPath($path)) {

            $cleanupErrors.Add(
                "Refused to delete a non-Phoenix path: $path"
            )

            continue
        }

        try {

            if (Test-Path -LiteralPath $path) {

                Remove-Item `
                    -LiteralPath $path `
                    -Recurse `
                    -Force `
                    -ErrorAction Stop
            }
        }
        catch {

            $cleanupErrors.Add(
                "Failed to remove '$path': $($_.Exception.Message)"
            )
        }
    }

    $Package.WorkingDirectory = ''
    $Package.DownloadedFile = ''
    $Package.CleanupPaths = @()

    if ($cleanupErrors.Count -gt 0) {

        $result = $this.NewFailure(
            'One or more cleanup operations failed.',
            'PHX_CLEANUP_FAILED'
        )

        $result.Errors = $cleanupErrors.ToArray()

        return $result
    }

    $result = [Result]::Success(
        "Cleanup completed for '$($Package.Id)'."
    )

    $result.Code = 'PHX_CLEANUP_COMPLETE'

    return $result
}

#endregion 20-Providers\PhoenixProvider\Methods\40-Cleanup\CleanupPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\40-Cleanup\IsPhoenixManagedPath.ps1
##########################################################
## Method: IsPhoenixManagedPath
## Legacy source line: 147
##########################################################

hidden [bool] IsPhoenixManagedPath(
    [string]$Path
) {

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        return $false
    }

    try {

        [string]$workingRoot = (
            [IO.Path]::GetFullPath(
                $context.WorkingRoot
            ).TrimEnd('\') + '\'
        )

        [string]$candidatePath = (
            [IO.Path]::GetFullPath($Path)
        )

        return $candidatePath.StartsWith(
            $workingRoot,
            [StringComparison]::OrdinalIgnoreCase
        )
    }
    catch {

        return $false
    }
}

#endregion 20-Providers\PhoenixProvider\Methods\40-Cleanup\IsPhoenixManagedPath.ps1

#region 20-Providers\PhoenixProvider\Methods\40-Cleanup\NewPackageWorkingDirectory.ps1
##########################################################
## Method: NewPackageWorkingDirectory
## Legacy source line: 106
##########################################################

hidden [string] NewPackageWorkingDirectory(
    [Package]$Package
) {

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        throw 'Phoenix context is unavailable.'
    }

    [string]$safePackageId = [regex]::Replace(
        $Package.Id,
        '[^a-zA-Z0-9._-]',
        '_'
    )

    [string]$directoryName = '{0}-{1}' -f `
        $safePackageId,
        [guid]::NewGuid().ToString('N')

    [string]$workingDirectory = Join-Path `
        $context.WorkingRoot `
        $directoryName

    New-Item `
        -ItemType Directory `
        -Path $workingDirectory `
        -Force |
        Out-Null

    $Package.WorkingDirectory = $workingDirectory

    $Package.CleanupPaths = @(
        $Package.CleanupPaths
    ) + @(
        $workingDirectory
    )

    return $workingDirectory
}

#endregion 20-Providers\PhoenixProvider\Methods\40-Cleanup\NewPackageWorkingDirectory.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\CanRepairSilently.ps1
##########################################################
## Method: CanRepairSilently
## Legacy source line: 473
##########################################################

[bool] CanRepairSilently([Package]$Package) {

    return $this.SupportsSilentRepair
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\CanRepairSilently.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackage.ps1
##########################################################
## Method: RepairPackage
## Legacy source line: 494
##########################################################

[Result] RepairPackage([Package]$Package) {

    return $this.RepairPackage(
        $Package,
        [PhoenixInstallMode]::SilentPreferred
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackage.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageInteractive.ps1
##########################################################
## Method: RepairPackageInteractive
## Legacy source line: 486
##########################################################

[Result] RepairPackageInteractive([Package]$Package) {

    return $this.NewFailure(
        "$($this.Name) does not implement interactive repair.",
        'PHX_INTERACTIVE_REPAIR_UNAVAILABLE'
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageInteractive.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageSilent.ps1
##########################################################
## Method: RepairPackageSilent
## Legacy source line: 478
##########################################################

[Result] RepairPackageSilent([Package]$Package) {

    return $this.NewFailure(
        "$($this.Name) does not implement silent repair.",
        'PHX_SILENT_REPAIR_UNAVAILABLE'
    )
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageSilent.ps1

#region 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageWithMode.ps1
##########################################################
## Method: RepairPackage
## Legacy source line: 502
##########################################################

[Result] RepairPackage(
    [Package]$Package,
    [PhoenixInstallMode]$Mode
) {

    [Result]$repairResult = [Result]::Failure(
        'Package repair did not complete.'
    )

    try {

        if ($null -eq $Package) {

            $repairResult = $this.NewFailure(
                'A package object is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        elseif (-not $this.SupportsRepair) {

            $repairResult = $this.NewFailure(
                "$($this.Name) does not support package repair.",
                'PHX_REPAIR_UNAVAILABLE'
            )
        }
        elseif (
            $Mode -eq
            [PhoenixInstallMode]::InteractiveOnly
        ) {

            if (-not $this.SupportsInteractiveRepair) {

                $repairResult = $this.NewFailure(
                    'Interactive repair is unavailable.',
                    'PHX_INTERACTIVE_REPAIR_UNAVAILABLE'
                )
            }
            else {

                $repairResult =
                    $this.RepairPackageInteractive(
                        $Package
                    )
            }
        }
        elseif (
            $Mode -eq
            [PhoenixInstallMode]::SilentOnly
        ) {

            if (-not $this.CanRepairSilently($Package)) {

                $repairResult = $this.NewFailure(
                    'Silent repair is unavailable.',
                    'PHX_SILENT_REPAIR_UNAVAILABLE'
                )
            }
            else {

                $repairResult =
                    $this.RepairPackageSilent(
                        $Package
                    )
            }
        }
        elseif ($this.CanRepairSilently($Package)) {

            $repairResult =
                $this.RepairPackageSilent(
                    $Package
                )

            if (
                (-not $repairResult.Success) -and
                $repairResult.Code -eq
                    'PHX_SILENT_REPAIR_UNAVAILABLE' -and
                $this.SupportsInteractiveRepair
            ) {

                $repairResult =
                    $this.RepairPackageInteractive(
                        $Package
                    )
            }
        }
        elseif ($this.SupportsInteractiveRepair) {

            $repairResult =
                $this.RepairPackageInteractive(
                    $Package
                )
        }
        else {

            $repairResult = $this.NewFailure(
                'No repair method is available.',
                'PHX_REPAIR_UNAVAILABLE'
            )
        }
    }
    catch {

        $repairResult = $this.NewFailure(
            "Package repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
    finally {

        if (
            $null -ne $Package -and
            $this.SupportsCleanup -and
            $this.CleanupAfterInstall -and
            (-not $Package.PreserveDownloads) -and
            (
                $repairResult.Success -or
                $this.CleanupOnFailure
            )
        ) {

            $cleanupResult =
                $this.CleanupPackage($Package)

            if (-not $cleanupResult.Success) {

                $repairResult.Warnings = @(
                    $repairResult.Warnings
                ) + @(
                    $cleanupResult.Message
                )
            }
        }
    }

    return $repairResult
}

#endregion 20-Providers\PhoenixProvider\Methods\50-Repair\RepairPackageWithMode.ps1

#region 20-Providers\PhoenixProvider\Methods\60-PackageManagement\RemovePackage.ps1
##########################################################
## Method: RemovePackage
## Legacy source line: 647
##########################################################

[Result] RemovePackage([Package]$Package) {

        return [Result]::Failure(
            'RemovePackage() is not implemented.'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\60-PackageManagement\RemovePackage.ps1

#region 20-Providers\PhoenixProvider\Methods\60-PackageManagement\UpdatePackage.ps1
##########################################################
## Method: UpdatePackage
## Legacy source line: 640
##########################################################

[Result] UpdatePackage([Package]$Package) {

        return [Result]::Failure(
            'UpdatePackage() is not implemented.'
        )
    }

#endregion 20-Providers\PhoenixProvider\Methods\60-PackageManagement\UpdatePackage.ps1

#region 20-Providers\PhoenixProvider\PhoenixProvider.Footer.ps1
##########################################################
## PhoenixProvider composite class footer
##########################################################

}
#endregion 20-Providers\PhoenixProvider\PhoenixProvider.Footer.ps1

#region 20-Providers\WinGetProvider\WinGetProvider.Header.ps1
##########################################################
## WinGetProvider composite class header
## Generated from the validated legacy provider
##########################################################

class WinGetProvider : PhoenixProvider {

    ##########################################################
    ## Constructor
    ##########################################################

WinGetProvider() {

        $this.Name     = "WinGet"
        $this.Version  = ""
        $this.Type     = "Package Manager"

        $this.Priority = 95

        $this.SupportsDependencies = $true

        $this.Available = $this.TestAvailable()
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true

    }

#endregion 20-Providers\WinGetProvider\WinGetProvider.Header.ps1

#region 20-Providers\WinGetProvider\Methods\GetInstalledPackages.ps1
##########################################################
## Method: GetInstalledPackages
## Legacy source line: 126
##########################################################

[Package[]] GetInstalledPackages() {

    $packages = [System.Collections.Generic.List[Package]]::new()
    $seenPackageKeys = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    if (-not $this.TestAvailable()) {
        return $packages.ToArray()
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {
            return $packages.ToArray()
        }

        [string[]]$output = @(
            & $command.Source `
                list `
                --accept-source-agreements `
                --disable-interactivity `
                2>$null
        )

        if ($LASTEXITCODE -ne 0) {
            return $packages.ToArray()
        }

        [int]$separatorIndex = -1
        [int[]]$columnStarts = @()

        for (
            [int]$lineIndex = 0
            $lineIndex -lt $output.Count
            $lineIndex++
        ) {

    [string]$currentLine = $output[$lineIndex]

        if ($currentLine -match '^\s*-{3,}\s*$') {

    $separatorIndex = $lineIndex

        if ($lineIndex -gt 0) {

        [string]$headerLine = $output[$lineIndex - 1]

        $headerMatches = [regex]::Matches(
            $headerLine,
            '(?i)\b(Name|Id|Version|Available|Match|Source)\b'
        )

        $starts = [System.Collections.Generic.List[int]]::new()

        foreach ($headerMatch in $headerMatches) {
            $starts.Add($headerMatch.Index)
        }

        $columnStarts = $starts.ToArray()
    }

    break
}
        }

        if (
            $separatorIndex -lt 0 -or
            $columnStarts.Count -lt 3
        ) {

            return $packages.ToArray()
        }

        for (
            [int]$lineIndex = $separatorIndex + 1
            $lineIndex -lt $output.Count
            $lineIndex++
        ) {

            [string]$line = $output[$lineIndex]

            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            [string[]]$columns = $this.ParseWingetTableRow(
                $line,
                $columnStarts
            )

            if ($columns.Count -lt 3) {
                continue
            }

            [string]$name = $columns[0]
            [string]$id = $columns[1]
            [string]$version = $columns[2]
            [string]$source = ''

            if ($columns.Count -ge 4) {
                $source = $columns[$columns.Count - 1]
}

            if ($columns.Count -ge 5) {
                $source = $columns[4]
            }

            if (
                [string]::IsNullOrWhiteSpace($name) -or
                [string]::IsNullOrWhiteSpace($id) -or
                -not $seenPackageKeys.Add(
                    "$id|$source"
                )
            ) {

                continue
            }

            $package = [Package]::new()

            $package.Name          = $name
            $package.Id            = $id
            $package.Version       = $version
            $package.Provider      = $this.Name
            $package.InstallerType = 'WinGet'
            $package.Source        = $source
            $package.Architecture  = ''
            $package.Installed     = $true

            $packages.Add($package)
        }
    }
    catch {

        Write-Warning (
            "WinGet GetInstalledPackages failed: $($_.Exception.Message)"
        )
    }

    return $packages.ToArray()
}

#endregion 20-Providers\WinGetProvider\Methods\GetInstalledPackages.ps1

#region 20-Providers\WinGetProvider\Methods\Helpers\ParseWingetTableRow.ps1
##########################################################
## Method: ParseWingetTableRow
## Legacy source line: 56
##########################################################

hidden [string[]] ParseWingetTableRow(
        [string]$Line,
        [int[]]$ColumnStarts
) {

    $values = [System.Collections.Generic.List[string]]::new()

    if (
        [string]::IsNullOrWhiteSpace($Line) -or
        $null -eq $ColumnStarts -or
        $ColumnStarts.Count -eq 0
    ) {

        return $values.ToArray()
    }

    for (
        [int]$columnIndex = 0
        $columnIndex -lt $ColumnStarts.Count
        $columnIndex++
    ) {

        [int]$startIndex = $ColumnStarts[$columnIndex]

        if ($Line.Length -le $startIndex) {

            $values.Add('')

            continue
        }

        if ($columnIndex -lt ($ColumnStarts.Count - 1)) {

            [int]$nextStart = $ColumnStarts[$columnIndex + 1]
            [int]$length = $nextStart - $startIndex

            if ($length -lt 0) {
                $length = 0
            }

            [int]$remainingLength = $Line.Length - $startIndex

            if ($length -gt $remainingLength) {
                $length = $remainingLength
            }

            [string]$value = $Line.Substring(
                $startIndex,
                $length
            ).Trim()

            $values.Add($value)
        }
        else {

            [string]$value = $Line.Substring(
                $startIndex
            ).Trim()

            $values.Add($value)
        }
    }

    return $values.ToArray()
}

#endregion 20-Providers\WinGetProvider\Methods\Helpers\ParseWingetTableRow.ps1

#region 20-Providers\WinGetProvider\Methods\InstallPackageInteractive.ps1
##########################################################
## Method: InstallPackageInteractive
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

    if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
        return $this.NewFailure(
            'A package with an ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {
        return $this.NewFailure(
            'WinGet is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {
        $command = Get-Command winget.exe -ErrorAction SilentlyContinue

        if ($null -eq $command) {
            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        $wingetOutput = @()

        & $command.Source `
            install `
            --id $Package.Id `
            --exact `
            --source winget `
            --interactive `
            --accept-package-agreements `
            --accept-source-agreements `
            --no-upgrade `
            2>&1 |
            Tee-Object -Variable wingetOutput |
            Out-Host

        [int]$exitCode = $LASTEXITCODE
        [bool]$alreadyInstalled =
            $exitCode -eq -1978335135
        [bool]$rebootRequired =
            $exitCode -in @(1641, 3010)

        $result = if (
            $exitCode -eq 0 -or
            $alreadyInstalled -or
            $rebootRequired
        ) {
            [Result]::Success()
        }
        else {
            [Result]::Failure(
                "Interactive WinGet installation failed with exit code $exitCode."
            )
        }

        $result.Provider = $this.Name
        $result.Operation = 'Install'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired = $rebootRequired
        $result.Data = $Package

        if ($result.Success) {
            $Package.Installed = $true
            $result.Code = if ($alreadyInstalled) {
                'PHX_ALREADY_INSTALLED'
            }
            elseif ($rebootRequired) {
                'PHX_INSTALLED_RESTART_REQUIRED'
            }
            else {
                'PHX_INSTALLED_INTERACTIVE'
            }
            $result.Message =
                "Installed '$($Package.Id)' interactively."
        }
        else {
            $result.Code = 'PHX_INSTALL_FAILED'
            $result.Errors = @(
                $wingetOutput |
                    ForEach-Object { $_.ToString() }
            )
        }

        return $result
    }
    catch {
        return $this.NewFailure(
            "Interactive WinGet installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}
#endregion 20-Providers\WinGetProvider\Methods\InstallPackageInteractive.ps1

#region 20-Providers\WinGetProvider\Methods\InstallPackageSilent.ps1
##########################################################
## Method: InstallPackageSilent
## Legacy source line: 422
##########################################################

[Result] InstallPackageSilent([Package]$Package) {

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'WinGet is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {

            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Installing $($Package.Name) silently..."
        ) -ForegroundColor Cyan

        & $command.Source `
            install `
            --id $Package.Id `
            --exact `
            --source winget `
            --silent `
            --disable-interactivity `
            --accept-package-agreements `
            --accept-source-agreements `
            --no-upgrade |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -eq -1978335135) {

            $Package.Installed = $true

            $result = [Result]::Success()
            $result.Code = 'PHX_ALREADY_INSTALLED'
            $result.Message = (
                "'$($Package.Id)' is already installed."
            )
            $result.Provider = $this.Name
            $result.Operation = 'Install'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        if ($exitCode -ne 0 -and $exitCode -notin @(1641, 3010)) {

            $result = $this.NewFailure(
                "Silent WinGet installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )
            $result.Provider = $this.Name
            $result.Operation = 'Install'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        $Package.Installed = $true

        $result = [Result]::Success()
        $result.Code = 'PHX_INSTALLED'
        $result.Message = (
            "Installed '$($Package.Id)' silently."
        )
        $result.Provider = $this.Name
        $result.Operation = 'Install'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired =
            $exitCode -in @(1641, 3010)
        $result.Data = $Package

        if ($result.RebootRequired) {
            $result.Code = 'PHX_INSTALLED_RESTART_REQUIRED'
        }

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}
#endregion 20-Providers\WinGetProvider\Methods\InstallPackageSilent.ps1

#region 20-Providers\WinGetProvider\Methods\InstallProvider.ps1
##########################################################
## Method: InstallProvider
## Legacy source line: 38
##########################################################

[Result] InstallProvider() {

        return [Result]::Failure(
            "WinGet is included with Windows App Installer."
        )

    }

#endregion 20-Providers\WinGetProvider\Methods\InstallProvider.ps1

#region 20-Providers\WinGetProvider\Methods\RemovePackage.ps1
##########################################################
## Method: RemovePackage
##########################################################

[Result] RemovePackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'WinGet is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {

            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Removing $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Yellow

        & $command.Source `
            uninstall `
            --id $Package.Id `
            --exact `
            --source winget `
            --silent `
            --disable-interactivity `
            --accept-source-agreements |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {

            $result = $this.NewFailure(
                "WinGet removal failed with exit code $exitCode.",
                'PHX_REMOVE_FAILED'
            )
            $result.Provider = $this.Name
            $result.Operation = 'Remove'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        $Package.Installed = $false

        [Result]$result = [Result]::Success(
            "Removed $($Package.Id) successfully."
        )

        $result.Code = 'PHX_REMOVED'
        $result.Provider = $this.Name
        $result.Operation = 'Remove'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.Data = $Package

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet removal failed: $($_.Exception.Message)",
            'PHX_REMOVE_FAILED'
        )
    }
}
#endregion 20-Providers\WinGetProvider\Methods\RemovePackage.ps1

#region 20-Providers\WinGetProvider\Methods\RepairPackageInteractive.ps1
##########################################################
## Method: RepairPackageInteractive
## Legacy source line: 573
##########################################################

[Result] RepairPackageInteractive([Package]$Package) {

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'WinGet is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {

            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Starting interactive repair for $($Package.Name)..."
        ) -ForegroundColor Yellow

        & $command.Source `
            repair `
            --id $Package.Id `
            --exact `
            --source winget `
            --interactive `
            --accept-package-agreements `
            --accept-source-agreements |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -and $exitCode -notin @(1641, 3010)) {

            $result = $this.NewFailure(
                "Interactive WinGet repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )
            $result.Provider = $this.Name
            $result.Operation = 'Repair'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        $result = [Result]::Success(
            "Repaired $($Package.Id) interactively."
        )

        $result.Code = 'PHX_REPAIRED_INTERACTIVE'
        $result.Provider = $this.Name
        $result.Operation = 'Repair'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired =
            $exitCode -in @(1641, 3010)
        $result.Data = $Package

        if ($result.RebootRequired) {
            $result.Code = 'PHX_REPAIRED_RESTART_REQUIRED'
        }

        return $result
    }
    catch {

        return $this.NewFailure(
            "Interactive WinGet repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}

#endregion 20-Providers\WinGetProvider\Methods\RepairPackageInteractive.ps1

#region 20-Providers\WinGetProvider\Methods\RepairPackageSilent.ps1
##########################################################
## Method: RepairPackageSilent
## Legacy source line: 507
##########################################################

[Result] RepairPackageSilent([Package]$Package) {

        if (-not $this.TestAvailable()) {

         return $this.NewFailure(
               'WinGet is unavailable.',
               'PHX_PROVIDER_UNAVAILABLE'
            )
        }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {

            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Repairing $($Package.Name) silently..."
        ) -ForegroundColor Cyan

        & $command.Source `
            repair `
            --id $Package.Id `
            --exact `
            --source winget `
            --silent `
            --disable-interactivity `
            --accept-package-agreements `
            --accept-source-agreements |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0 -and $exitCode -notin @(1641, 3010)) {

            $result = $this.NewFailure(
                "WinGet repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )
            $result.Provider = $this.Name
            $result.Operation = 'Repair'
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data = $Package

            return $result
        }

        $result = [Result]::Success(
            "Repaired $($Package.Id) silently."
        )

        $result.Code = 'PHX_REPAIRED'
        $result.Provider = $this.Name
        $result.Operation = 'Repair'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired =
            $exitCode -in @(1641, 3010)
        $result.Data = $Package

        if ($result.RebootRequired) {
            $result.Code = 'PHX_REPAIRED_RESTART_REQUIRED'
        }

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}

#endregion 20-Providers\WinGetProvider\Methods\RepairPackageSilent.ps1

#region 20-Providers\WinGetProvider\Methods\SearchPackage.ps1
##########################################################
## Method: SearchPackage
## Legacy source line: 267
##########################################################

[Package[]] SearchPackage([string]$Name) {

    $packages = [System.Collections.Generic.List[Package]]::new()
    $seenPackageIds = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $packages.ToArray()
    }

    if (-not $this.TestAvailable()) {
        return $packages.ToArray()
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {
            return $packages.ToArray()
        }

        [string[]]$output = @(
            & $command.Source `
                search `
                --query `
                $Name `
                --source `
                winget `
                --accept-source-agreements `
                --disable-interactivity `
                2>$null
        )

        if ($LASTEXITCODE -ne 0) {

            Write-Warning (
                "WinGet search exited with code $LASTEXITCODE."
            )

            return $packages.ToArray()
        }

        [int]$separatorIndex = -1
        [int[]]$columnStarts = @()

        for (
            [int]$lineIndex = 0
            $lineIndex -lt $output.Count
            $lineIndex++
        ) {

            [string]$currentLine = $output[$lineIndex]

            if ($currentLine -match '^\s*-{3,}\s*$') {

                $separatorIndex = $lineIndex

                if ($lineIndex -gt 0) {

                    [string]$headerLine = $output[$lineIndex - 1]

                    $headerMatches = [regex]::Matches(
                        $headerLine,
                        '(?i)\b(Name|Id|Version|Available|Match|Source)\b'
                    )

                    $starts =
                        [System.Collections.Generic.List[int]]::new()

                    foreach ($headerMatch in $headerMatches) {
                        $starts.Add($headerMatch.Index)
                    }

                    $columnStarts = $starts.ToArray()
                }

                break
            }
        }

        if (
            $separatorIndex -lt 0 -or
            $columnStarts.Count -lt 3
        ) {

            Write-Warning (
                'WinGet search output did not contain a recognizable table.'
            )

            return $packages.ToArray()
        }

        for (
            [int]$lineIndex = $separatorIndex + 1
            $lineIndex -lt $output.Count
            $lineIndex++
        ) {

            [string]$line = $output[$lineIndex]

            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            [string[]]$columns = $this.ParseWingetTableRow(
                $line,
                $columnStarts
            )

            if ($columns.Count -lt 3) {
                continue
            }

            [string]$name = $columns[0]
            [string]$id = $columns[1]
            [string]$version = $columns[2]
            [string]$source = 'winget'

            if (
                [string]::IsNullOrWhiteSpace($name) -or
                [string]::IsNullOrWhiteSpace($id) -or
                -not $seenPackageIds.Add($id)
            ) {

                continue
            }

            $package = [Package]::new()

            $package.Name          = $name
            $package.Id            = $id
            $package.Version       = $version
            $package.Provider      = $this.Name
            $package.InstallerType = 'WinGet'
            $package.Source        = $source
            $package.Architecture  = ''
            $package.Installed     = $false

            $packages.Add($package)
        }
    }
    catch {

        Write-Warning (
            "WinGet SearchPackage failed: $($_.Exception.Message)"
        )
    }

    return $packages.ToArray()
}

#endregion 20-Providers\WinGetProvider\Methods\SearchPackage.ps1

#region 20-Providers\WinGetProvider\Methods\TestAvailable.ps1
##########################################################
## Method: TestAvailable
## Legacy source line: 30
##########################################################

[bool] TestAvailable() {

        return $null -ne (
            Get-Command winget -ErrorAction SilentlyContinue
        )

    }

#endregion 20-Providers\WinGetProvider\Methods\TestAvailable.ps1

#region 20-Providers\WinGetProvider\Methods\UpdatePackage.ps1
##########################################################
## Method: UpdatePackage
##########################################################

[Result] UpdatePackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'WinGet is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        $command = Get-Command `
            winget.exe `
            -ErrorAction SilentlyContinue

        if ($null -eq $command) {

            return $this.NewFailure(
                'winget.exe could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Updating $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Cyan

$wingetOutput = @()

& $command.Source `
    upgrade `
    --id $Package.Id `
    --exact `
    --source winget `
    --silent `
    --disable-interactivity `
    --accept-package-agreements `
    --accept-source-agreements `
    2>&1 |
    Tee-Object -Variable wingetOutput |
    Out-Host

[int]$exitCode = $LASTEXITCODE

[string]$outputText = (
    $wingetOutput |
        ForEach-Object {
            $_.ToString()
        }
) -join [Environment]::NewLine

if (
    $outputText -match
        'install technology is different'
) {

    [Result]$result = [Result]::Failure(
        (
            "A newer version of '$($Package.Id)' was found, " +
            'but WinGet cannot upgrade it because the installer technology changed.'
        )
    )

    $result.Code = 'PHX_UPDATE_MIGRATION_REQUIRED'
    $result.Message = (
        "$($Package.Id) requires an uninstall and reinstall migration."
    )
    $result.Data = $Package
    $result.Provider = $this.Name
    $result.Operation = 'Update'
    $result.Target = $Package.Id
    $result.HasExitCode = $true
    $result.ExitCode = $exitCode
    $result.Errors = @(
        $wingetOutput |
            ForEach-Object {
                $_.ToString()
            }
    )

    return $result
}

if ($exitCode -eq -1978335189) {

    [Result]$result = [Result]::Success()

    $result.Code = 'PHX_ALREADY_CURRENT'
    $result.Message = (
        "$($Package.Id) is already current."
    )
    $result.Data = $Package
    $result.Provider = $this.Name
    $result.Operation = 'Update'
    $result.Target = $Package.Id
    $result.HasExitCode = $true
    $result.ExitCode = $exitCode

    return $result
}

if ($exitCode -ne 0 -and $exitCode -notin @(1641, 3010)) {

    [Result]$result = [Result]::Failure(
        "WinGet update failed with exit code $exitCode."
    )

    $result.Code = 'PHX_UPDATE_FAILED'
    $result.Data = $Package
    $result.Provider = $this.Name
    $result.Operation = 'Update'
    $result.Target = $Package.Id
    $result.HasExitCode = $true
    $result.ExitCode = $exitCode
    $result.Errors = @(
        $wingetOutput |
            ForEach-Object {
                $_.ToString()
            }
    )

    return $result
}

        $Package.Installed = $true

        [Result]$result = [Result]::Success()

        $result.Code = 'PHX_UPDATED'
        $result.Message = (
            "Updated $($Package.Id) successfully."
        )
        $result.Data = $Package
        $result.Provider = $this.Name
        $result.Operation = 'Update'
        $result.Target = $Package.Id
        $result.HasExitCode = $true
        $result.ExitCode = $exitCode
        $result.RebootRequired =
            $exitCode -in @(1641, 3010)

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet update failed: $($_.Exception.Message)",
            'PHX_UPDATE_FAILED'
        )
    }
}
#endregion 20-Providers\WinGetProvider\Methods\UpdatePackage.ps1

#region 20-Providers\WinGetProvider\Methods\UpdateProvider.ps1
##########################################################
## Method: UpdateProvider
## Legacy source line: 46
##########################################################

[Result] UpdateProvider() {

        winget source update | Out-Null

        return [Result]::Success(
            "WinGet sources updated."
        )

    }

#endregion 20-Providers\WinGetProvider\Methods\UpdateProvider.ps1

#region 20-Providers\WinGetProvider\WinGetProvider.Footer.ps1
##########################################################
## WinGetProvider composite class footer
##########################################################

}
#endregion 20-Providers\WinGetProvider\WinGetProvider.Footer.ps1

#region 20-Providers\ChocolateyProvider\ChocolateyProvider.Header.ps1
##########################################################
## ChocolateyProvider composite class header
## Generated from the validated legacy provider
##########################################################

class ChocolateyProvider : PhoenixProvider {

    ##########################################################
    ## Constructor
    ##########################################################

ChocolateyProvider() {

        $this.Name     = "Chocolatey"
        $this.Version  = ""
        $this.Type     = "Package Manager"

        $this.Priority = 90

        $this.SupportsDependencies = $true

        $this.Available = $this.TestAvailable()

        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true

    }

#endregion 20-Providers\ChocolateyProvider\ChocolateyProvider.Header.ps1

#region 20-Providers\ChocolateyProvider\Methods\GetInstalledPackages.ps1
##########################################################
## Method: GetInstalledPackages
## Legacy source line: 290
##########################################################

[Package[]] GetInstalledPackages() {

    $packages = [System.Collections.Generic.List[Package]]::new()
    $seenPackageIds = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    if (-not $this.TestAvailable()) {
        return $packages.ToArray()
    }

    $installRoot = $env:ChocolateyInstall

    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        $installRoot = Join-Path $env:ProgramData 'chocolatey'
    }

    $chocoExecutable = Join-Path `
        $installRoot `
        'bin\choco.exe'

    try {

        $output = @(
            & $chocoExecutable `
                list `
                --limit-output `
                --no-color `
                2>$null
        )

        if ($LASTEXITCODE -ne 0) {
            return $packages.ToArray()
        }

        foreach ($line in $output) {

            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            $parts = $line -split '\|', 2

            if ($parts.Count -lt 2) {
                continue
            }

            if (-not $seenPackageIds.Add($parts[0].Trim())) {
                continue
            }

            $package = [Package]::new()

            $package.Name          = $parts[0].Trim()
            $package.Id            = $parts[0].Trim()
            $package.Version       = $parts[1].Trim()
            $package.Provider      = $this.Name
            $package.InstallerType = 'Chocolatey'
            $package.Source        = 'Chocolatey'
            $package.Architecture  = ''
            $package.Installed     = $true

            $packages.Add($package)
        }
    }
    catch {

        return $packages.ToArray()
    }

    return $packages.ToArray()
}

#endregion 20-Providers\ChocolateyProvider\Methods\GetInstalledPackages.ps1

#region 20-Providers\ChocolateyProvider\Methods\Helpers\CompleteChocolateyResult.ps1
##########################################################
## Method: CompleteChocolateyResult
##########################################################

hidden [Result] CompleteChocolateyResult(
    [Result]$Result,
    [Package]$Package,
    [string]$Operation,
    [int]$ExitCode
) {

    $Result.Provider = $this.Name
    $Result.Operation = $Operation
    $Result.Target = if ($null -ne $Package) {
        $Package.Id
    }
    else {
        ''
    }
    $Result.HasExitCode = $true
    $Result.ExitCode = $ExitCode
    $Result.RebootRequired =
        $ExitCode -in @(1641, 3010)

    if ($null -ne $Package) {
        $Result.Data = $Package
    }

    return $Result
}
#endregion 20-Providers\ChocolateyProvider\Methods\Helpers\CompleteChocolateyResult.ps1

#region 20-Providers\ChocolateyProvider\Methods\Helpers\GetChocolateyExecutable.ps1
##########################################################
## Helper: GetChocolateyExecutable
##########################################################

hidden [string] GetChocolateyExecutable() {

    $command = Get-Command `
        choco.exe `
        -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        return $command.Source
    }

    [string]$installRoot =
        $env:ChocolateyInstall

    if ([string]::IsNullOrWhiteSpace($installRoot)) {

        $installRoot = Join-Path `
            $env:ProgramData `
            'chocolatey'
    }

    [string]$chocoExecutable = Join-Path `
        $installRoot `
        'bin\choco.exe'

    if (Test-Path -LiteralPath $chocoExecutable) {
        return $chocoExecutable
    }

    return ''
}
#endregion 20-Providers\ChocolateyProvider\Methods\Helpers\GetChocolateyExecutable.ps1

#region 20-Providers\ChocolateyProvider\Methods\InstallPackageInteractive.ps1
##########################################################
## Method: InstallPackageInteractive
## Legacy source line: 541
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    $context = Get-PhoenixContext

    if ($null -eq $context) {

        return $this.NewFailure(
            'Phoenix context is unavailable.',
            'PHX_CONTEXT_UNAVAILABLE'
        )
    }

    if (-not $context.IsAdministrator) {

        return $this.NewFailure(
            'Chocolatey package installation requires administrator privileges.',
            'PHX_ELEVATION_REQUIRED'
        )
    }

    try {

        [string]$installRoot = $env:ChocolateyInstall

        if ([string]::IsNullOrWhiteSpace($installRoot)) {

            $installRoot = Join-Path `
                $env:ProgramData `
                'chocolatey'
        }

        [string]$chocoExecutable = Join-Path `
            $installRoot `
            'bin\choco.exe'

       if (-not (Test-Path -LiteralPath $chocoExecutable)) {

    return $this.NewFailure(
        "Chocolatey executable was not found at '$chocoExecutable'.",
        'PHX_PROVIDER_UNAVAILABLE'
    )
}

# Create a unique cache directory for this package installation.
[string]$workingDirectory =
    $this.NewPackageWorkingDirectory(
        $Package
    )

[string]$cacheArgument =
    "--cache-location=$workingDirectory"

Write-Host (
    "Starting the interactive installer for $($Package.Name) [$($Package.Id)]..."
) -ForegroundColor Yellow

& $chocoExecutable `
    install `
    $Package.Id `
    --yes `
    --not-silent `
    --no-progress `
    $cacheArgument |
    Out-Host

[int]$exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1641, 3010)) {

            $result = $this.NewFailure(
                "Interactive Chocolatey installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Install',
                $exitCode
            )
        }

        $Package.Installed = $true

        $result = [Result]::Success(
            "Installed $($Package.Id) interactively."
        )

        $result.Code = 'PHX_INSTALLED_INTERACTIVE'

        if ($exitCode -in @(1641, 3010)) {
            $result.Code = 'PHX_INSTALLED_REBOOT_REQUIRED'
        }

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Install',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Interactive Chocolatey installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}

#endregion 20-Providers\ChocolateyProvider\Methods\InstallPackageInteractive.ps1

#region 20-Providers\ChocolateyProvider\Methods\InstallPackageSilent.ps1
##########################################################
## Method: InstallPackageSilent
## Legacy source line: 431
##########################################################

[Result] InstallPackageSilent([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is not available.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        [string]$installRoot = $env:ChocolateyInstall

        if ([string]::IsNullOrWhiteSpace($installRoot)) {

            $installRoot = Join-Path `
                $env:ProgramData `
                'chocolatey'
        }

        [string]$chocoExecutable = Join-Path `
            $installRoot `
            'bin\choco.exe'

        if (-not (Test-Path -LiteralPath $chocoExecutable)) {

    return $this.NewFailure(
        "Chocolatey executable was not found at '$chocoExecutable'.",
        'PHX_PROVIDER_UNAVAILABLE'
    )
}

# Create a unique cache directory for this package installation.
[string]$workingDirectory =
    $this.NewPackageWorkingDirectory(
        $Package
    )

[string]$cacheArgument =
    "--cache-location=$workingDirectory"

Write-Host (
    "Installing $($Package.Name) [$($Package.Id)] silently..."
) -ForegroundColor Cyan

& $chocoExecutable `
    install `
    $Package.Id `
    --yes `
    --no-progress `
    $cacheArgument |
    Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1641, 3010)) {

            $result = $this.NewFailure(
                "Chocolatey installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Install',
                $exitCode
            )
        }

        $Package.Installed = $true

        $result = [Result]::Success(
            "Installed $($Package.Id) silently."
        )

        $result.Code = 'PHX_INSTALLED'

        if ($exitCode -in @(1641, 3010)) {
            $result.Code = 'PHX_INSTALLED_REBOOT_REQUIRED'
        }

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Install',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Chocolatey installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}

#endregion 20-Providers\ChocolateyProvider\Methods\InstallPackageSilent.ps1

#region 20-Providers\ChocolateyProvider\Methods\InstallProvider.ps1
##########################################################
## Method: InstallProvider
## Legacy source line: 79
##########################################################

[Result] InstallProvider() {

    [Result]$result = [Result]::Failure(
        'Chocolatey installation did not complete.'
    )

    [string]$installerPath = ''

    try {

        if ($this.TestAvailable()) {

            $this.Available = $true

            $result = [Result]::Success(
                'Chocolatey is already installed.'
            )
        }
        else {

            $context = Get-PhoenixContext

            if ($null -eq $context) {

                $result = [Result]::Failure(
                    'Phoenix context is unavailable.'
                )
            }
            elseif (-not $context.IsAdministrator) {

                $result = [Result]::Failure(
                    'Chocolatey installation requires administrator privileges.'
                )
            }
            else {

                [string]$installRoot = $env:ChocolateyInstall

                if ([string]::IsNullOrWhiteSpace($installRoot)) {

                    $installRoot = Join-Path `
                        $env:ProgramData `
                        'chocolatey'
                }

                [string]$chocoExecutable = Join-Path `
                    $installRoot `
                    'bin\choco.exe'

                [int]$processId = (
                    [System.Diagnostics.Process]::GetCurrentProcess().Id
                )

                $installerPath = Join-Path `
                    $env:TEMP `
                    "Phoenix-Chocolatey-Install-$processId.ps1"

                if (
                    (Test-Path -LiteralPath $installRoot) -and
                    (-not (Test-Path -LiteralPath $chocoExecutable))
                ) {

                    [string]$timestamp = Get-Date `
                        -Format 'yyyyMMdd-HHmmss'

                    [string]$parentPath = Split-Path `
                        $installRoot `
                        -Parent

                    [string]$backupPath = Join-Path `
                        $parentPath `
                        "chocolatey.incomplete-$timestamp"

                    Write-Host `
                        'Backing up incomplete Chocolatey installation:' `
                        -ForegroundColor Yellow

                    Write-Host "  From: $installRoot"
                    Write-Host "  To:   $backupPath"

                    Move-Item `
                        -LiteralPath $installRoot `
                        -Destination $backupPath `
                        -ErrorAction Stop
                }

                Write-Host `
                    'Downloading the Chocolatey installer...' `
                    -ForegroundColor Cyan

                [Net.ServicePointManager]::SecurityProtocol = (
                    [Net.ServicePointManager]::SecurityProtocol -bor
                    [Net.SecurityProtocolType]::Tls12
                )

                $null = Invoke-WebRequest `
                    -Uri 'https://community.chocolatey.org/install.ps1' `
                    -OutFile $installerPath `
                    -ProgressAction SilentlyContinue `
                    -ErrorAction Stop

                if (-not (Test-Path -LiteralPath $installerPath)) {

                    $result = [Result]::Failure(
                        'The Chocolatey installer was not downloaded.'
                    )
                }
                else {

                    Write-Host `
                        'Installing Chocolatey...' `
                        -ForegroundColor Cyan

                    # Display installer output without returning it
                    # from this typed class method.
                    & $installerPath | Out-Host

                    [string]$machineInstallRoot = (
                        [Environment]::GetEnvironmentVariable(
                            'ChocolateyInstall',
                            'Machine'
                        )
                    )

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            $machineInstallRoot
                        )
                    ) {

                        $installRoot = $machineInstallRoot
                        $env:ChocolateyInstall = $machineInstallRoot
                    }

                    [string]$chocoBin = Join-Path `
                        $installRoot `
                        'bin'

                    $chocoExecutable = Join-Path `
                        $chocoBin `
                        'choco.exe'

                    if (
                        (Test-Path -LiteralPath $chocoBin) -and
                        (($env:Path -split ';') -notcontains $chocoBin)
                    ) {

                        $env:Path = "$chocoBin;$env:Path"
                    }

                    $this.Available = $this.TestAvailable()

                    if ($this.Available) {

                        Write-Host `
                            'Chocolatey installed successfully.' `
                            -ForegroundColor Green

                        $result = [Result]::Success(
                            'Chocolatey installed successfully.'
                        )
                    }
                    else {

                        $result = [Result]::Failure(
                            "Chocolatey installation completed, but choco.exe was not found at '$chocoExecutable'."
                        )
                    }
                }
            }
        }
    }
    catch {

        $this.Available = $false

        $result = [Result]::Failure(
            "Chocolatey installation failed: $($_.Exception.Message)"
        )
    }
    finally {

        if (
            (-not [string]::IsNullOrWhiteSpace($installerPath)) -and
            (Test-Path -LiteralPath $installerPath)
        ) {

            Remove-Item `
                -LiteralPath $installerPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    return $result
}

#endregion 20-Providers\ChocolateyProvider\Methods\InstallProvider.ps1

#region 20-Providers\ChocolateyProvider\Methods\RemovePackage.ps1
##########################################################
## Method: RemovePackage
##########################################################

[Result] RemovePackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        [string]$chocoExecutable =
            $this.GetChocolateyExecutable()

        if ([string]::IsNullOrWhiteSpace($chocoExecutable)) {

            return $this.NewFailure(
                'Chocolatey executable could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        Write-Host (
            "Removing $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Yellow

        & $chocoExecutable `
            uninstall `
            $Package.Id `
            --yes `
            --no-progress |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -eq 1605) {

            $Package.Installed = $false

            [Result]$result = [Result]::Success()
            $result.Code = 'PHX_ALREADY_REMOVED'
            $result.Message = (
                "$($Package.Id) is not installed."
            )
            $result.Data = $Package

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Remove',
                $exitCode
            )
        }

        if ($exitCode -in @(1641, 3010)) {

            $Package.Installed = $false

            [Result]$result = [Result]::Success()
            $result.Code = 'PHX_REMOVED_REBOOT_REQUIRED'
            $result.Message = (
                "Removed $($Package.Id); a reboot is required."
            )
            $result.Data = $Package

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Remove',
                $exitCode
            )
        }

        if ($exitCode -notin @(0, 1614)) {

            $result = $this.NewFailure(
                "Chocolatey removal failed with exit code $exitCode.",
                'PHX_REMOVE_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Remove',
                $exitCode
            )
        }

        $Package.Installed = $false

        [Result]$result = [Result]::Success()
        $result.Code = 'PHX_REMOVED'
        $result.Message = (
            "Removed $($Package.Id) successfully."
        )
        $result.Data = $Package

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Remove',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Chocolatey removal failed: $($_.Exception.Message)",
            'PHX_REMOVE_FAILED'
        )
    }
}
#endregion 20-Providers\ChocolateyProvider\Methods\RemovePackage.ps1

#region 20-Providers\ChocolateyProvider\Methods\RepairPackageInteractive.ps1
##########################################################
## Method: RepairPackageInteractive
##########################################################

[Result] RepairPackageInteractive(
    [Package]$Package
) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        [string]$chocoExecutable =
            $this.GetChocolateyExecutable()

        if (
            [string]::IsNullOrWhiteSpace(
                $chocoExecutable
            )
        ) {

            return $this.NewFailure(
                'Chocolatey executable could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        [string]$workingDirectory =
            $this.NewPackageWorkingDirectory(
                $Package
            )

        [string[]]$arguments = @(
            'upgrade'
            $Package.Id
            '--yes'
            '--force'
            '--not-silent'
            '--no-progress'
            '--fail-on-unfound'
            '--fail-on-not-installed'
            "--cache-location=$workingDirectory"
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $Package.Version
            )
        ) {

            $arguments +=
                "--version=$($Package.Version)"
        }

        Write-Host (
            "Starting interactive repair for $($Package.Name) [$($Package.Id)]..."
        ) -ForegroundColor Yellow

        & $chocoExecutable @arguments |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1641, 3010)) {

            $result = $this.NewFailure(
                "Interactive Chocolatey repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Repair',
                $exitCode
            )
        }

        [Result]$result = [Result]::Success(
            "Repaired $($Package.Id) interactively."
        )

        if ($exitCode -in @(1641, 3010)) {

            $result.Code =
                'PHX_REPAIRED_REBOOT_REQUIRED'
        }
        else {

            $result.Code =
                'PHX_REPAIRED_INTERACTIVE'
        }

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Repair',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Interactive Chocolatey repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}
#endregion 20-Providers\ChocolateyProvider\Methods\RepairPackageInteractive.ps1

#region 20-Providers\ChocolateyProvider\Methods\RepairPackageSilent.ps1
##########################################################
## Method: RepairPackageSilent
##########################################################

[Result] RepairPackageSilent([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        [string]$chocoExecutable =
            $this.GetChocolateyExecutable()

        if (
            [string]::IsNullOrWhiteSpace(
                $chocoExecutable
            )
        ) {

            return $this.NewFailure(
                'Chocolatey executable could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        [string]$workingDirectory =
            $this.NewPackageWorkingDirectory(
                $Package
            )

        [string[]]$arguments = @(
            'upgrade'
            $Package.Id
            '--yes'
            '--force'
            '--no-progress'
            '--fail-on-unfound'
            '--fail-on-not-installed'
            "--cache-location=$workingDirectory"
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                $Package.Version
            )
        ) {

            $arguments +=
                "--version=$($Package.Version)"
        }

        Write-Host (
            "Repairing $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Cyan

        & $chocoExecutable @arguments |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1641, 3010)) {

            $result = $this.NewFailure(
                "Chocolatey repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Repair',
                $exitCode
            )
        }

        [Result]$result = [Result]::Success(
            "Repaired $($Package.Id) silently."
        )

        if ($exitCode -in @(1641, 3010)) {

            $result.Code =
                'PHX_REPAIRED_REBOOT_REQUIRED'
        }
        else {

            $result.Code = 'PHX_REPAIRED'
        }

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Repair',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Chocolatey repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}
#endregion 20-Providers\ChocolateyProvider\Methods\RepairPackageSilent.ps1

#region 20-Providers\ChocolateyProvider\Methods\SearchPackage.ps1
##########################################################
## Method: SearchPackage
## Legacy source line: 356
##########################################################

[Package[]] SearchPackage([string]$Name) {

    $packages = [System.Collections.Generic.List[Package]]::new()
    $seenPackageIds = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $packages.ToArray()
    }

    if (-not $this.TestAvailable()) {
        return $packages.ToArray()
    }

    $installRoot = $env:ChocolateyInstall

    if ([string]::IsNullOrWhiteSpace($installRoot)) {
        $installRoot = Join-Path $env:ProgramData 'chocolatey'
    }

    $chocoExecutable = Join-Path `
        $installRoot `
        'bin\choco.exe'

    try {

        $output = @(
            & $chocoExecutable `
                search `
                $Name `
                --limit-output `
                --no-color `
                2>$null
        )

        if ($LASTEXITCODE -ne 0) {
            return $packages.ToArray()
        }

        foreach ($line in $output) {

            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            $parts = $line -split '\|', 2

            if ($parts.Count -lt 2) {
                continue
            }

            if (-not $seenPackageIds.Add($parts[0].Trim())) {
                continue
            }

            $package = [Package]::new()

            $package.Name          = $parts[0].Trim()
            $package.Id            = $parts[0].Trim()
            $package.Version       = $parts[1].Trim()
            $package.Provider      = $this.Name
            $package.InstallerType = 'Chocolatey'
            $package.Source        = 'Chocolatey'
            $package.Architecture  = ''
            $package.Installed     = $false

            $packages.Add($package)
        }
    }
    catch {

        return $packages.ToArray()
    }

    return $packages.ToArray()
}

#endregion 20-Providers\ChocolateyProvider\Methods\SearchPackage.ps1

#region 20-Providers\ChocolateyProvider\Methods\TestAvailable.ps1
##########################################################
## Method: TestAvailable
##########################################################

[bool] TestAvailable() {

    $command = Get-Command `
        choco.exe `
        -ErrorAction SilentlyContinue

    if ($null -ne $command) {

        try {

            & $command.Source --version *> $null

            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
        catch {
            return $false
        }
    }

    $installRoot = $env:ChocolateyInstall

    if ([string]::IsNullOrWhiteSpace($installRoot)) {

        $installRoot = Join-Path `
            $env:ProgramData `
            'chocolatey'
    }

    $chocoExecutable = Join-Path `
        $installRoot `
        'bin\choco.exe'

    if (-not (Test-Path -LiteralPath $chocoExecutable)) {
        return $false
    }

    try {

        & $chocoExecutable --version *> $null

        return $LASTEXITCODE -eq 0
    }
    catch {

        return $false
    }
}
#endregion 20-Providers\ChocolateyProvider\Methods\TestAvailable.ps1

#region 20-Providers\ChocolateyProvider\Methods\UpdatePackage.ps1
##########################################################
## Method: UpdatePackage
##########################################################

[Result] UpdatePackage([Package]$Package) {

    if ($null -eq $Package) {

        return $this.NewFailure(
            'A package object is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Package.Id)) {

        return $this.NewFailure(
            'The package ID is required.',
            'PHX_INVALID_PACKAGE'
        )
    }

    if (-not $this.TestAvailable()) {

        return $this.NewFailure(
            'Chocolatey is unavailable.',
            'PHX_PROVIDER_UNAVAILABLE'
        )
    }

    try {

        [string]$chocoExecutable =
            $this.GetChocolateyExecutable()

        if (
            [string]::IsNullOrWhiteSpace(
                $chocoExecutable
            )
        ) {

            return $this.NewFailure(
                'Chocolatey executable could not be located.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        [string]$workingDirectory =
            $this.NewPackageWorkingDirectory(
                $Package
            )

        [string[]]$arguments = @(
            'upgrade'
            $Package.Id
            '--yes'
            '--no-progress'
            '--fail-on-unfound'
            '--fail-on-not-installed'
            "--cache-location=$workingDirectory"
        )

        Write-Host (
            "Updating $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Cyan

        & $chocoExecutable @arguments |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -eq 2) {

            $Package.Installed = $true

            [Result]$result = [Result]::Success()

            $result.Code = 'PHX_ALREADY_CURRENT'
            $result.Message = (
                "$($Package.Id) is already current."
            )
            $result.Data = $Package

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Update',
                $exitCode
            )
        }

        if ($exitCode -in @(1641, 3010)) {

            $Package.Installed = $true

            [Result]$result = [Result]::Success()

            $result.Code =
                'PHX_UPDATED_REBOOT_REQUIRED'

            $result.Message = (
                "Updated $($Package.Id); a reboot is required."
            )
            $result.Data = $Package

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Update',
                $exitCode
            )
        }

        if ($exitCode -ne 0) {

            $result = $this.NewFailure(
                "Chocolatey update failed with exit code $exitCode.",
                'PHX_UPDATE_FAILED'
            )

            return $this.CompleteChocolateyResult(
                $result,
                $Package,
                'Update',
                $exitCode
            )
        }

        $Package.Installed = $true

        [Result]$result = [Result]::Success()

        $result.Code = 'PHX_UPDATED'
        $result.Message = (
            "Updated $($Package.Id) successfully."
        )
        $result.Data = $Package

        return $this.CompleteChocolateyResult(
            $result,
            $Package,
            'Update',
            $exitCode
        )
    }
    catch {

        return $this.NewFailure(
            "Chocolatey update failed: $($_.Exception.Message)",
            'PHX_UPDATE_FAILED'
        )
    }
}
#endregion 20-Providers\ChocolateyProvider\Methods\UpdatePackage.ps1

#region 20-Providers\ChocolateyProvider\Methods\UpdateProvider.ps1
##########################################################
## Method: UpdateProvider
## Legacy source line: 276
##########################################################

[Result] UpdateProvider() {

        choco upgrade chocolatey -y

        return [Result]::Success(
            "Chocolatey updated."
        )

    }

#endregion 20-Providers\ChocolateyProvider\Methods\UpdateProvider.ps1

#region 20-Providers\ChocolateyProvider\ChocolateyProvider.Footer.ps1
##########################################################
## ChocolateyProvider composite class footer
##########################################################

}
#endregion 20-Providers\ChocolateyProvider\ChocolateyProvider.Footer.ps1

#region 20-Providers\ScoopProvider.ps1
class ScoopProvider : PhoenixProvider {

    ScoopProvider() {
        $this.Name = 'Scoop'
        $this.Type = 'Package Manager'
        $this.Priority = 85
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentRepair = $false
        $this.SupportsInteractiveRepair = $false
        $this.SupportsExport = $true
        $this.SupportsRestore = $true
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return $null -ne (
            Get-Command scoop -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Failure(
            'Install Scoop from https://scoop.sh, then refresh Phoenix providers.'
        )
        $result.Code = 'PHX_PROVIDER_INSTALL_APPROVAL_REQUIRED'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'

        return $result
    }

    [Result] UpdateProvider() {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        return $this.InvokeScoop(
            @('update'),
            'UpdateProvider',
            'Scoop'
        )
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()

        if (-not $this.TestAvailable()) {
            return $packages.ToArray()
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source export 2>$null)

            if ($LASTEXITCODE -ne 0) {
                return $packages.ToArray()
            }

            $exportData = ($output -join [Environment]::NewLine) |
                ConvertFrom-Json -ErrorAction Stop

            foreach ($app in @($exportData.apps)) {
                if ([string]::IsNullOrWhiteSpace([string]$app.Name)) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = [string]$app.Name
                $package.Id = [string]$app.Name
                $package.Version = [string]$app.Version
                $package.Provider = $this.Name
                $package.InstallerType = 'Scoop'
                $package.Source = if (
                    [string]::IsNullOrWhiteSpace([string]$app.Source)
                ) { 'main' } else { [string]$app.Source }
                $package.Installed = $true
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        $packages = [System.Collections.Generic.List[Package]]::new()

        if (
            [string]::IsNullOrWhiteSpace($Name) -or
            -not $this.TestAvailable()
        ) {
            return $packages.ToArray()
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source search $Name 2>$null)
            $seenIds = [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )

            foreach ($line in $output) {
                if ([string]$line -notmatch '^\s*([^\s]+)\s+\(([^)]+)\)') {
                    continue
                }

                [string]$id = $Matches[1]

                if (-not $seenIds.Add($id)) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = $id
                $package.Id = $id
                $package.Version = $Matches[2]
                $package.Provider = $this.Name
                $package.InstallerType = 'Scoop'
                $package.Source = 'Scoop'
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }

        return $packages.ToArray()
    }

    [Result] InstallPackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('install', $Package.Id),
            'Install',
            $Package.Id
        )

        if ($result.Success) {
            $Package.Installed = $true
            $result.Code = 'PHX_INSTALLED'
        }

        $result.Data = $Package
        return $result
    }

    [Result] UpdatePackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('update', $Package.Id),
            'Update',
            $Package.Id
        )
        $result.Data = $Package

        if ($result.Success) {
            $result.Code = 'PHX_UPDATED'
        }

        return $result
    }

    [Result] RemovePackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('uninstall', $Package.Id),
            'Remove',
            $Package.Id
        )
        $result.Data = $Package

        if ($result.Success) {
            $Package.Installed = $false
            $result.Code = 'PHX_REMOVED'
        }

        return $result
    }

    [Result] ExportPackages() {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source export 2>&1)
            [int]$exitCode = $LASTEXITCODE
            $result = if ($exitCode -eq 0) {
                [Result]::Success($output -join [Environment]::NewLine)
            }
            else {
                [Result]::Failure('Scoop export failed.')
            }
            $result.Code = if ($result.Success) {
                'PHX_EXPORTED'
            } else { 'PHX_EXPORT_FAILED' }
            $result.Provider = $this.Name
            $result.Operation = 'Export'
            $result.Target = 'Scoop'
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode

            return $result
        }
        catch {
            return $this.NewFailure(
                "Scoop export failed: $($_.Exception.Message)",
                'PHX_EXPORT_FAILED'
            )
        }
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()

        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackage($package))
        }

        return $results.ToArray()
    }

    hidden [Result] InvokeScoop(
        [string[]]$ArgumentList,
        [string]$Operation,
        [string]$Target
    ) {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source @ArgumentList 2>&1)
            [int]$exitCode = $LASTEXITCODE
            $result = if ($exitCode -eq 0) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Scoop $Operation failed with exit code $exitCode."
                )
            }
            $result.Code = if ($result.Success) {
                "PHX_$($Operation.ToUpperInvariant())D"
            }
            else {
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            }
            $result.Message = $output -join [Environment]::NewLine
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Target
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode

            if (-not $result.Success) {
                $result.Errors = @($output)
            }

            return $result
        }
        catch {
            return $this.NewFailure(
                "Scoop $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
    }
}
#endregion 20-Providers\ScoopProvider.ps1

#region 20-Providers\MSIProvider.ps1
class MSIProvider : PhoenixProvider {

    MSIProvider() {
        $this.Name = 'MSI'
        $this.Type = 'Native Installer'
        $this.Priority = 80
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $false
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $false
        $this.SupportsRemove = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return $null -ne (
            Get-Command msiexec.exe -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Windows Installer is built into Windows.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        $seenProductCodes =
            [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )

        foreach ($registryPath in @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
            foreach ($entry in @(Get-ItemProperty $registryPath -ErrorAction SilentlyContinue)) {
                [string]$productCode = [string]$entry.PSChildName

                if (
                    $productCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$' -and
                    [string]$entry.UninstallString -match '(?i)msiexec(?:\.exe)?\s+/(?:I|X)\s*\{([0-9A-F-]{36})\}'
                ) {
                    $productCode = "{$($Matches[1])}"
                }

                if (
                    $productCode -notmatch '^\{[0-9A-Fa-f-]{36}\}$' -or
                    -not $seenProductCodes.Add($productCode) -or
                    [string]::IsNullOrWhiteSpace([string]$entry.DisplayName)
                ) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = [string]$entry.DisplayName
                $package.Id = $productCode
                $package.Version = [string]$entry.DisplayVersion
                $package.Provider = $this.Name
                $package.InstallerType = 'MSI'
                $package.Source = 'Windows Installer'
                $package.Architecture = if (
                    [string]$entry.PSPath -match 'WOW6432Node'
                ) { 'x86' } else { 'x64' }
                $package.Installed = $true
                $package.RequiresElevation = $true
                $packages.Add($package)
            }
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        return @()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Install',
            $true
        )
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Install',
            $false
        )
    }

    [Result] RepairPackageSilent([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Repair',
            $true
        )
    }

    [Result] RepairPackageInteractive([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Repair',
            $false
        )
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.NewFailure(
            'MSI updates require a newer installer definition.',
            'PHX_UPDATE_UNAVAILABLE'
        )
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.InvokeMsiPackage(
            $Package,
            'Remove',
            $true
        )
    }

    hidden [Result] InvokeMsiPackage(
        [Package]$Package,
        [string]$Operation,
        [bool]$Silent
    ) {
        if ($null -eq $Package) {
            return $this.NewFailure(
                'An MSI package definition is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        [string]$target = $Package.Id
        $arguments = [System.Collections.Generic.List[string]]::new()

        if ($Operation -eq 'Install') {
            [string]$installerPath = if (
                -not [string]::IsNullOrWhiteSpace($Package.DownloadedFile)
            ) { $Package.DownloadedFile } else { $Package.Id }

            if (
                [string]::IsNullOrWhiteSpace($installerPath) -or
                -not (Test-Path -LiteralPath $installerPath -PathType Leaf)
            ) {
                return $this.NewFailure(
                    'The local MSI installer file was not found.',
                    'PHX_INSTALLER_NOT_FOUND'
                )
            }

            $target = $installerPath
            $arguments.Add('/i')
            $arguments.Add(('"{0}"' -f $installerPath))
        }
        elseif ($Package.Id -match '^\{[0-9A-Fa-f-]{36}\}$') {
            [string]$productAction = if ($Operation -eq 'Repair') {
                '/fa'
            }
            else {
                '/x'
            }
            $arguments.Add($productAction)
            $arguments.Add($Package.Id)
        }
        else {
            return $this.NewFailure(
                'A valid MSI product code is required.',
                'PHX_INVALID_PRODUCT_CODE'
            )
        }

        [string]$uiArgument = if ($Silent) { '/qn' } else { '/passive' }
        $arguments.Add($uiArgument)
        $arguments.Add('/norestart')

        try {
            $process = Start-Process `
                -FilePath 'msiexec.exe' `
                -ArgumentList $arguments.ToArray() `
                -Wait `
                -PassThru `
                -ErrorAction Stop

            [int]$exitCode = $process.ExitCode
            [bool]$success =
                $exitCode -in @(0, 1605, 1614, 1641, 3010)
            $result = if ($success) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Windows Installer exited with code $exitCode."
                )
            }
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $target
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.RebootRequired = $exitCode -in @(1641, 3010)
            $result.Data = $Package
            $result.Code = if ($success) {
                if ($result.RebootRequired) {
                    "PHX_$($Operation.ToUpperInvariant())_RESTART_REQUIRED"
                }
                else {
                    "PHX_$($Operation.ToUpperInvariant())_SUCCEEDED"
                }
            }
            else {
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            }

            if ($success) {
                $Package.Installed = $Operation -ne 'Remove'
                $result.Message = "$Operation completed for '$target'."
            }

            return $result
        }
        catch {
            return $this.NewFailure(
                "MSI $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
    }
}
#endregion 20-Providers\MSIProvider.ps1

#region 20-Providers\EXEProvider.ps1
class EXEProvider : PhoenixProvider {
    EXEProvider() {
        $this.Name = 'EXE'
        $this.Type = 'Executable Installer'
        $this.Priority = 75
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $false
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $false
        $this.SupportsRemove = $true
        $this.SupportsRepair = $true
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsSilentRepair = $true
        $this.SupportsInteractiveRepair = $true
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return $null -ne (
            Get-Command Start-Process -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Executable installer support is built into Phoenix.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )

        foreach ($registryPath in @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
            foreach ($entry in @(
                Get-ItemProperty $registryPath -ErrorAction SilentlyContinue
            )) {
                [string]$uninstallCommand = [string]$entry.UninstallString
                [string]$quietCommand = [string]$entry.QuietUninstallString
                [string]$identity = '{0}|{1}' -f $entry.PSPath, $entry.PSChildName

                if (
                    [string]::IsNullOrWhiteSpace([string]$entry.DisplayName) -or
                    [int]$entry.WindowsInstaller -eq 1 -or
                    $uninstallCommand -match '(?i)\bmsiexec(?:\.exe)?\b' -or
                    -not $seen.Add($identity)
                ) {
                    continue
                }

                $package = [EXEPackageDefinition]::new()
                $package.Name = [string]$entry.DisplayName
                $package.Id = [string]$entry.PSChildName
                $package.Version = [string]$entry.DisplayVersion
                $package.Provider = $this.Name
                $package.Source = [string]$entry.Publisher
                $package.Architecture = if (
                    [string]$entry.PSPath -match 'WOW6432Node'
                ) { 'x86' } else { 'x64' }
                $package.Installed = $true
                $package.RequiresElevation =
                    [string]$entry.PSPath -match 'HKEY_LOCAL_MACHINE'
                $package.UninstallCommand = $uninstallCommand
                $package.QuietUninstallCommand = $quietCommand
                $package.RepairCommand = [string]$entry.ModifyPath
                $packages.Add($package)
            }
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        return @()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeInstall($Package, $true)
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InvokeInstall($Package, $false)
    }

    [Result] RepairPackageSilent([Package]$Package) {
        return $this.InvokeDefinitionCommand(
            $Package,
            'Repair',
            $this.GetDefinitionValue($Package, 'RepairCommand'),
            @()
        )
    }

    [Result] RepairPackageInteractive([Package]$Package) {
        return $this.RepairPackageSilent($Package)
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.NewFailure(
            'EXE updates require a newer declarative package definition.',
            'PHX_UPDATE_UNAVAILABLE'
        )
    }

    [Result] RemovePackage([Package]$Package) {
        [string]$command =
            $this.GetDefinitionValue($Package, 'QuietUninstallCommand')
        if ([string]::IsNullOrWhiteSpace($command)) {
            $command = $this.GetDefinitionValue($Package, 'UninstallCommand')
        }
        return $this.InvokeDefinitionCommand(
            $Package,
            'Remove',
            $command,
            @()
        )
    }

    hidden [Result] InvokeInstall([Package]$Package, [bool]$Silent) {
        if ($null -eq $Package) {
            return $this.NewFailure(
                'An EXE package definition is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        [string]$command = $this.GetDefinitionValue(
            $Package,
            'InstallCommand'
        )
        if ([string]::IsNullOrWhiteSpace($command)) {
            $command = if (
                -not [string]::IsNullOrWhiteSpace($Package.DownloadedFile)
            ) { $Package.DownloadedFile } else { $Package.Id }
        }

        if (-not (Test-Path -LiteralPath $command -PathType Leaf)) {
            return $this.NewFailure(
                'The executable installer file was not found.',
                'PHX_INSTALLER_NOT_FOUND'
            )
        }

        [string[]]$arguments = if ($Silent) {
            $Package.SilentArguments
        }
        else {
            $Package.InteractiveArguments
        }

        return $this.InvokeDefinitionCommand(
            $Package,
            'Install',
            ('"{0}"' -f $command),
            $arguments
        )
    }

    hidden [string] GetDefinitionValue(
        [Package]$Package,
        [string]$PropertyName
    ) {
        if ($null -eq $Package) {
            return ''
        }
        $property = $Package.PSObject.Properties[$PropertyName]
        if ($null -eq $property) {
            return ''
        }
        return [string]$property.Value
    }

    hidden [int[]] GetDefinitionExitCodes(
        [Package]$Package,
        [string]$PropertyName,
        [int[]]$Default
    ) {
        if ($null -ne $Package) {
            $property = $Package.PSObject.Properties[$PropertyName]
            if ($null -ne $property -and @($property.Value).Count -gt 0) {
                return [int[]]@($property.Value)
            }
        }
        return $Default
    }

    hidden [Result] InvokeDefinitionCommand(
        [Package]$Package,
        [string]$Operation,
        [string]$CommandLine,
        [string[]]$AdditionalArguments
    ) {
        if ([string]::IsNullOrWhiteSpace($CommandLine)) {
            return $this.NewFailure(
                "No $Operation command is defined for this executable package.",
                "PHX_$($Operation.ToUpperInvariant())_UNAVAILABLE"
            )
        }

        [string]$executable = ''
        [string]$registeredArguments = ''
        [string]$trimmed = $CommandLine.Trim()

        if ($trimmed -match '^"([^"]+)"\s*(.*)$') {
            $executable = $Matches[1]
            $registeredArguments = $Matches[2]
        }
        elseif ($trimmed -match '^(.*?\.exe)\s*(.*)$') {
            $executable = $Matches[1]
            $registeredArguments = $Matches[2]
        }
        else {
            $executable = $trimmed
        }

        $arguments = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace($registeredArguments)) {
            $arguments.Add($registeredArguments)
        }
        foreach ($argument in @($AdditionalArguments)) {
            if (-not [string]::IsNullOrWhiteSpace($argument)) {
                $arguments.Add($argument)
            }
        }

        try {
            $processParameters = @{
                FilePath = $executable
                ArgumentList = $arguments.ToArray()
                Wait = $true
                PassThru = $true
                ErrorAction = 'Stop'
            }
            if (
                $null -ne $Package -and
                -not [string]::IsNullOrWhiteSpace($Package.WorkingDirectory)
            ) {
                $processParameters.WorkingDirectory = $Package.WorkingDirectory
            }

            $process = Start-Process @processParameters
            [int]$exitCode = $process.ExitCode
            [int[]]$successCodes = $this.GetDefinitionExitCodes(
                $Package,
                'SuccessExitCodes',
                @(0)
            )
            [int[]]$rebootCodes = $this.GetDefinitionExitCodes(
                $Package,
                'RebootExitCodes',
                @(1641, 3010)
            )
            [bool]$rebootRequired = $exitCode -in $rebootCodes
            [bool]$success = $exitCode -in $successCodes -or $rebootRequired
            $result = if ($success) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Executable installer exited with code $exitCode."
                )
            }
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = if ($null -ne $Package) { $Package.Id } else { $executable }
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.RebootRequired = $rebootRequired
            $result.Data = $Package
            $result.Code = if ($success) {
                if ($rebootRequired) {
                    "PHX_$($Operation.ToUpperInvariant())_RESTART_REQUIRED"
                }
                else {
                    "PHX_$($Operation.ToUpperInvariant())_SUCCEEDED"
                }
            }
            else {
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            }
            if ($success) {
                $result.Message = "$Operation completed for '$($result.Target)'."
                if ($null -ne $Package) {
                    $Package.Installed = $Operation -ne 'Remove'
                }
            }
            return $result
        }
        catch {
            $result = $this.NewFailure(
                "EXE $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = if ($null -ne $Package) { $Package.Id } else { $executable }
            return $result
        }
    }
}
#endregion 20-Providers\EXEProvider.ps1

#region 20-Providers\GitHubProvider.ps1
class GitHubProvider : PhoenixProvider {
    GitHubProvider() {
        $this.Name = 'GitHub Releases'
        $this.Type = 'Release Asset'
        $this.Priority = 70
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSearch = $true
        $this.SupportsInventory = $false
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return (
            $null -ne (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'GitHub Releases support is built into Phoenix.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        return @()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return @()
        }

        $repositories = [System.Collections.Generic.List[object]]::new()
        if ($Name -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            try {
                $repositories.Add(
                    $this.InvokeGitHubApi("/repos/$Name")
                )
            }
            catch {
                return @()
            }
        }
        else {
            try {
                $encoded = [uri]::EscapeDataString("$Name in:name")
                $search = $this.InvokeGitHubApi(
                    "/search/repositories?q=$encoded&per_page=10"
                )
                foreach ($repository in @($search.items)) {
                    $repositories.Add($repository)
                }
            }
            catch {
                return @()
            }
        }

        $packages = [System.Collections.Generic.List[Package]]::new()
        foreach ($repository in $repositories) {
            try {
                $release = $this.InvokeGitHubApi(
                    "/repos/$($repository.full_name)/releases/latest"
                )
                $package = $this.NewReleasePackage($repository, $release, '')
                if ($null -ne $package) {
                    $packages.Add($package)
                }
            }
            catch {
                continue
            }
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InstallReleasePackage($Package, $true, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InstallReleasePackage($Package, $false, 'Install')
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InstallReleasePackage($Package, $true, 'Update')
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.NewFailure(
            'Remove the installed package through its MSI or EXE inventory record.',
            'PHX_REMOVE_UNAVAILABLE'
        )
    }

    hidden [object] InvokeGitHubApi([string]$Path) {
        $headers = @{
            Accept = 'application/vnd.github+json'
            'User-Agent' = 'PhoenixDeploy'
            'X-GitHub-Api-Version' = '2022-11-28'
        }
        if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
            $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)"
        }
        return Invoke-RestMethod `
            -Uri "https://api.github.com$Path" `
            -Headers $headers `
            -Method Get `
            -ErrorAction Stop
    }

    hidden [GitHubReleasePackageDefinition] NewReleasePackage(
        [object]$Repository,
        [object]$Release,
        [string]$AssetPattern
    ) {
        $asset = $this.SelectReleaseAsset(@($Release.assets), $AssetPattern)
        if ($null -eq $asset) {
            return $null
        }

        $package = [GitHubReleasePackageDefinition]::new()
        $package.Name = [string]$Repository.name
        $package.Id = [string]$Repository.full_name
        $package.Repository = [string]$Repository.full_name
        $package.ReleaseTag = [string]$Release.tag_name
        $package.ReleaseName = [string]$Release.name
        $package.Version = ([string]$Release.tag_name).TrimStart('v', 'V')
        $package.AssetName = [string]$asset.name
        $package.AssetPattern = $AssetPattern
        $package.DownloadUri = [string]$asset.browser_download_url
        $package.ReleaseNotes = [string]$Release.body
        $package.ReleaseNotesUrl = [string]$Release.html_url
        $package.PublishedAtUtc = [datetime]$Release.published_at
        $package.Architecture = $this.GetWindowsArchitecture()
        $package.InstallerType = [IO.Path]::GetExtension($package.AssetName).
            TrimStart('.').ToUpperInvariant()
        $package.DetectionDisplayName = [string]$Repository.name
        $package.InstalledVersion = $this.FindInstalledVersion(
            $package.DetectionDisplayName
        )
        $package.Installed =
            -not [string]::IsNullOrWhiteSpace($package.InstalledVersion)

        foreach ($candidate in @($Release.assets)) {
            [string]$candidateName = [string]$candidate.name
            if (
                $candidateName -ieq "$($package.AssetName).sha256" -or
                $candidateName -match '(?i)^(checksums?|sha256sums?)(\.txt)?$'
            ) {
                $package.ChecksumUri = [string]$candidate.browser_download_url
                break
            }
        }
        return $package
    }

    hidden [object] SelectReleaseAsset(
        [object[]]$Assets,
        [string]$AssetPattern
    ) {
        $supported = @(
            $Assets |
                Where-Object {
                    [string]$_.name -match '(?i)\.(msi|exe)$' -and
                    [string]$_.name -notmatch '(?i)(symbols?|debug|checksum|sha256)'
                }
        )
        if (-not [string]::IsNullOrWhiteSpace($AssetPattern)) {
            $supported = @(
                $supported |
                    Where-Object { [string]$_.name -match $AssetPattern }
            )
        }
        if ($supported.Count -eq 0) {
            return $null
        }

        [string]$architecture = $this.GetWindowsArchitecture()
        [string]$architecturePattern = switch ($architecture) {
            'arm64' { '(?i)(arm64|aarch64)' }
            'x86' { '(?i)(x86|i[3-6]86|win32)' }
            default { '(?i)(x64|amd64|win64)' }
        }
        $architectureAsset = @(
            $supported |
                Where-Object { [string]$_.name -match $architecturePattern }
        ) | Select-Object -First 1
        if ($null -ne $architectureAsset) {
            return $architectureAsset
        }
        return $supported | Select-Object -First 1
    }

    hidden [string] GetWindowsArchitecture() {
        [string]$architecture =
            [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.
                ToString().ToLowerInvariant()
        if ($architecture -eq 'x64') {
            return 'x64'
        }
        if ($architecture -eq 'arm64') {
            return 'arm64'
        }
        return 'x86'
    }

    hidden [string] FindInstalledVersion([string]$DisplayName) {
        foreach ($registryPath in @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )) {
            $match = Get-ItemProperty $registryPath -ErrorAction SilentlyContinue |
                Where-Object {
                    ([string]$_.DisplayName).IndexOf(
                        $DisplayName,
                        [StringComparison]::OrdinalIgnoreCase
                    ) -ge 0 -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.DisplayVersion)
                } |
                Select-Object -First 1
            if ($null -ne $match) {
                return [string]$match.DisplayVersion
            }
        }
        return ''
    }

    hidden [Result] InstallReleasePackage(
        [Package]$Package,
        [bool]$Silent,
        [string]$Operation
    ) {
        if ($null -eq $Package) {
            return $this.NewFailure(
                'A GitHub release package definition is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$downloadUri = $this.GetPackageValue($Package, 'DownloadUri')
        [string]$assetName = $this.GetPackageValue($Package, 'AssetName')
        if (
            [string]::IsNullOrWhiteSpace($downloadUri) -or
            [string]::IsNullOrWhiteSpace($assetName)
        ) {
            return $this.NewFailure(
                'The GitHub release asset definition is incomplete.',
                'PHX_RELEASE_ASSET_REQUIRED'
            )
        }

        [string]$downloadRoot = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ('Phoenix-GitHub-{0}' -f [guid]::NewGuid().ToString('N'))
        [string]$downloadPath = Join-Path $downloadRoot $assetName
        try {
            $null = New-Item -ItemType Directory -Path $downloadRoot -Force
            Invoke-WebRequest `
                -Uri $downloadUri `
                -OutFile $downloadPath `
                -UseBasicParsing `
                -ErrorAction Stop

            [string]$expectedHash = $this.GetPackageValue($Package, 'SHA256')
            [string]$checksumUri = $this.GetPackageValue($Package, 'ChecksumUri')
            if (
                [string]::IsNullOrWhiteSpace($expectedHash) -and
                -not [string]::IsNullOrWhiteSpace($checksumUri)
            ) {
                [string]$checksumText = Invoke-RestMethod `
                    -Uri $checksumUri `
                    -Method Get `
                    -ErrorAction Stop
                $escapedAsset = [regex]::Escape($assetName)
                if ($checksumText -match "(?im)^([0-9a-f]{64})\s+\*?$escapedAsset\s*$") {
                    $expectedHash = $Matches[1]
                }
            }
            if (-not [string]::IsNullOrWhiteSpace($expectedHash)) {
                [string]$actualHash = (Get-FileHash `
                    -LiteralPath $downloadPath `
                    -Algorithm SHA256).Hash
                if ($actualHash -ine $expectedHash) {
                    return $this.NewFailure(
                        'The downloaded GitHub release asset failed SHA-256 verification.',
                        'PHX_HASH_MISMATCH'
                    )
                }
            }

            $Package.DownloadedFile = $downloadPath
            $Package.CleanupPaths = @($downloadRoot)
            [string]$extension = [IO.Path]::GetExtension($assetName)
            [Result]$engineResult = if ($extension -ieq '.msi') {
                $engine = [MSIProvider]::new()
                if ($Silent) {
                    $engine.InstallPackageSilent($Package)
                }
                else {
                    $engine.InstallPackageInteractive($Package)
                }
            }
            elseif ($extension -ieq '.exe') {
                $engine = [EXEProvider]::new()
                if ($Silent) {
                    $engine.InstallPackageSilent($Package)
                }
                else {
                    $engine.InstallPackageInteractive($Package)
                }
            }
            else {
                $this.NewFailure(
                    "The release asset type '$extension' is not installable.",
                    'PHX_INSTALLER_TYPE_UNSUPPORTED'
                )
            }
            $engineResult.Provider = $this.Name
            $engineResult.Operation = $Operation
            $engineResult.Target = $Package.Id
            return $engineResult
        }
        catch {
            $result = $this.NewFailure(
                "GitHub release $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            return $result
        }
        finally {
            if (
                -not $Package.PreserveDownloads -and
                (Test-Path -LiteralPath $downloadRoot)
            ) {
                Remove-Item `
                    -LiteralPath $downloadRoot `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }
    }

    hidden [string] GetPackageValue(
        [Package]$Package,
        [string]$PropertyName
    ) {
        $property = $Package.PSObject.Properties[$PropertyName]
        if ($null -eq $property) {
            return ''
        }
        return [string]$property.Value
    }
}
#endregion 20-Providers\GitHubProvider.ps1

#region 20-Providers\PowerShellGalleryProvider.ps1
class PowerShellGalleryProvider : PhoenixProvider {
    PowerShellGalleryProvider() {
        $this.Name = 'PowerShell Gallery'
        $this.Type = 'PowerShell Resource'
        $this.Priority = 65
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $true
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsExport = $true
        $this.SupportsRestore = $true
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return (
            $null -ne (Get-Command Find-PSResource -ErrorAction SilentlyContinue) -or
            $null -ne (Get-Command Find-Module -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        if ($this.TestAvailable()) {
            $result = [Result]::Success()
            $result.Code = 'PHX_PROVIDER_AVAILABLE'
            $result.Message = 'A PowerShell Gallery client is already available.'
            $result.Provider = $this.Name
            $result.Operation = 'InstallProvider'
            return $result
        }
        return $this.NewFailure(
            'Install Microsoft.PowerShell.PSResourceGet or PowerShellGet to use the Gallery provider.',
            'PHX_PROVIDER_INSTALL_REQUIRED'
        )
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        if ($null -ne (Get-Command Get-InstalledPSResource -ErrorAction SilentlyContinue)) {
            foreach ($resource in @(
                Get-InstalledPSResource -ErrorAction SilentlyContinue
            )) {
                $packages.Add($this.ConvertResourceToPackage(
                    $resource,
                    [string]$resource.Type,
                    $true
                ))
            }
            return $packages.ToArray()
        }

        foreach ($module in @(
            Get-InstalledModule -ErrorAction SilentlyContinue
        )) {
            $packages.Add($this.ConvertResourceToPackage(
                $module,
                'Module',
                $true
            ))
        }
        foreach ($script in @(
            Get-InstalledScript -ErrorAction SilentlyContinue
        )) {
            $packages.Add($this.ConvertResourceToPackage(
                $script,
                'Script',
                $true
            ))
        }
        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name) -or -not $this.TestAvailable()) {
            return @()
        }

        $packages = [System.Collections.Generic.List[Package]]::new()
        $installedVersions = @{}
        foreach ($installed in @($this.GetInstalledPackages())) {
            $installedVersions["$($installed.InstallerType)|$($installed.Id)"] =
                $installed.Version
        }

        try {
            if ($null -ne (Get-Command Find-PSResource -ErrorAction SilentlyContinue)) {
                foreach ($resource in @(
                    Find-PSResource `
                        -Name $Name `
                        -Repository PSGallery `
                        -ErrorAction Stop
                )) {
                    [string]$resourceType = [string]$resource.Type
                    $package = $this.ConvertResourceToPackage(
                        $resource,
                        $resourceType,
                        $false
                    )
                    $key = "$($package.InstallerType)|$($package.Id)"
                    if ($installedVersions.ContainsKey($key)) {
                        $package.Installed = $true
                        $package.InstalledVersion =
                            [string]$installedVersions[$key]
                    }
                    $packages.Add($package)
                }
                return $packages.ToArray()
            }

            foreach ($resourceType in @('Module', 'Script')) {
                $commandName = if ($resourceType -eq 'Module') {
                    'Find-Module'
                }
                else {
                    'Find-Script'
                }
                foreach ($resource in @(
                    & $commandName `
                        -Name $Name `
                        -Repository PSGallery `
                        -ErrorAction Stop
                )) {
                    $package = $this.ConvertResourceToPackage(
                        $resource,
                        $resourceType,
                        $false
                    )
                    $key = "$($package.InstallerType)|$($package.Id)"
                    if ($installedVersions.ContainsKey($key)) {
                        $package.Installed = $true
                        $package.InstalledVersion =
                            [string]$installedVersions[$key]
                    }
                    $packages.Add($package)
                }
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Install')
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Update')
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.InvokeGalleryOperation($Package, 'Remove')
    }

    [Result] ExportPackages() {
        $inventory = $this.GetInstalledPackages()
        $result = [Result]::Success($inventory)
        $result.Code = 'PHX_EXPORTED'
        $result.Message = "Exported $($inventory.Count) PowerShell Gallery resources."
        $result.Provider = $this.Name
        $result.Operation = 'Export'
        $result.Target = 'PSGallery'
        return $result
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()
        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackageSilent($package))
        }
        return $results.ToArray()
    }

    hidden [PowerShellGalleryPackageDefinition] ConvertResourceToPackage(
        [object]$Resource,
        [string]$ResourceType,
        [bool]$Installed
    ) {
        $package = [PowerShellGalleryPackageDefinition]::new()
        $package.Name = [string]$Resource.Name
        $package.Id = [string]$Resource.Name
        $package.Version = [string]$Resource.Version
        $package.ResourceType = if (
            $ResourceType -match '(?i)script'
        ) { 'Script' } else { 'Module' }
        $package.InstallerType = "PowerShell$($package.ResourceType)"
        $package.Description = [string]$Resource.Description
        $package.Installed = $Installed
        if ($Installed) {
            $package.InstalledVersion = $package.Version
        }
        return $package
    }

    hidden [string] GetResourceType([Package]$Package) {
        if ($null -ne $Package) {
            $property = $Package.PSObject.Properties['ResourceType']
            if ($null -ne $property -and [string]$property.Value -match '(?i)script') {
                return 'Script'
            }
            if ($Package.InstallerType -match '(?i)script') {
                return 'Script'
            }
        }
        return 'Module'
    }

    hidden [Result] InvokeGalleryOperation(
        [Package]$Package,
        [string]$Operation
    ) {
        if (
            $null -eq $Package -or
            [string]::IsNullOrWhiteSpace($Package.Id)
        ) {
            return $this.NewFailure(
                'A PowerShell Gallery package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'No PowerShell Gallery client is available.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        [string]$resourceType = $this.GetResourceType($Package)
        try {
            if ($null -ne (Get-Command Install-PSResource -ErrorAction SilentlyContinue)) {
                $parameters = @{
                    Name = $Package.Id
                    Scope = 'CurrentUser'
                    ErrorAction = 'Stop'
                }
                if ($Operation -in @('Install', 'Update')) {
                    $parameters.Repository = 'PSGallery'
                    $parameters.TrustRepository = $true
                    $parameters.Quiet = $true
                    $parameters.AcceptLicense = $true
                    if (-not [string]::IsNullOrWhiteSpace($Package.Version)) {
                        $parameters.Version = $Package.Version
                    }
                }
                switch ($Operation) {
                    'Install' { Install-PSResource @parameters }
                    'Update' { Update-PSResource @parameters }
                    'Remove' { Uninstall-PSResource @parameters }
                }
            }
            else {
                $noun = if ($resourceType -eq 'Script') { 'Script' } else { 'Module' }
                $commandName = switch ($Operation) {
                    'Install' { "Install-$noun" }
                    'Update' { "Update-$noun" }
                    'Remove' { "Uninstall-$noun" }
                }
                $parameters = @{
                    Name = $Package.Id
                    ErrorAction = 'Stop'
                }
                if ($Operation -in @('Install', 'Update')) {
                    $parameters.Scope = 'CurrentUser'
                    $parameters.Force = $true
                    $parameters.AcceptLicense = $true
                }
                if (
                    $Operation -in @('Install', 'Update') -and
                    -not [string]::IsNullOrWhiteSpace($Package.Version)
                ) {
                    $parameters.RequiredVersion = $Package.Version
                }
                & $commandName @parameters
            }

            $result = [Result]::Success()
            $result.Code = switch ($Operation) {
                'Install' { 'PHX_INSTALLED' }
                'Update' { 'PHX_UPDATED' }
                'Remove' { 'PHX_REMOVED' }
            }
            $result.Message = "$Operation completed for '$($Package.Id)'."
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.Data = $Package
            $Package.Installed = $Operation -ne 'Remove'
            return $result
        }
        catch {
            $result = $this.NewFailure(
                "PowerShell Gallery $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.Data = $Package
            return $result
        }
    }
}
#endregion 20-Providers\PowerShellGalleryProvider.ps1

#region 20-Providers\NuGetProvider.ps1
class NuGetProvider : PhoenixProvider {
    NuGetProvider() {
        $this.Name = 'NuGet'
        $this.Type = 'NuGet v3 Package'
        $this.Priority = 60
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $true
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $true
        $this.SupportsExport = $true
        $this.SupportsRestore = $true
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return (
            $null -ne (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'NuGet v3 support is built into Phoenix.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        [string]$storeRoot = $this.GetStoreRoot()
        if (-not (Test-Path -LiteralPath $storeRoot -PathType Container)) {
            return @()
        }
        foreach ($idDirectory in @(
            Get-ChildItem -LiteralPath $storeRoot -Directory -ErrorAction SilentlyContinue
        )) {
            foreach ($versionDirectory in @(
                Get-ChildItem -LiteralPath $idDirectory.FullName -Directory -ErrorAction SilentlyContinue
            )) {
                $package = [NuGetPackageDefinition]::new()
                $package.Name = $idDirectory.Name
                $package.Id = $idDirectory.Name
                $package.Version = $versionDirectory.Name
                $package.InstalledVersion = $versionDirectory.Name
                $package.Source = 'Phoenix NuGet Store'
                $package.Installed = $true
                $package.WorkingDirectory = $versionDirectory.FullName
                $packages.Add($package)
            }
        }
        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return @()
        }
        $packages = [System.Collections.Generic.List[Package]]::new()
        $installedVersions = @{}
        foreach ($installed in @($this.GetInstalledPackages())) {
            $installedVersions[$installed.Id] = $installed.Version
        }

        foreach ($feed in $this.GetConfiguredFeeds()) {
            try {
                $index = Invoke-RestMethod -Uri $feed -Method Get -ErrorAction Stop
                $searchResource = @(
                    $index.resources |
                        Where-Object {
                            [string]$_.'@type' -match '^SearchQueryService'
                        }
                ) | Select-Object -First 1
                $baseResource = @(
                    $index.resources |
                        Where-Object {
                            [string]$_.'@type' -match '^PackageBaseAddress'
                        }
                ) | Select-Object -First 1
                if ($null -eq $searchResource -or $null -eq $baseResource) {
                    continue
                }
                [string]$query = [uri]::EscapeDataString($Name)
                [string]$searchUri = "$( $searchResource.'@id' )?q=$query&prerelease=false&take=20"
                $response = Invoke-RestMethod -Uri $searchUri -Method Get -ErrorAction Stop
                foreach ($item in @($response.data)) {
                    $package = [NuGetPackageDefinition]::new()
                    $package.Name = [string]$item.title
                    $package.Id = [string]$item.id
                    $package.Version = [string]$item.version
                    $package.FeedUrl = $feed
                    $package.Source = $feed
                    $package.Description = [string]$item.description
                    $package.Authors = [string]($item.authors -join ', ')
                    [string]$idLower = $package.Id.ToLowerInvariant()
                    [string]$versionLower = $package.Version.ToLowerInvariant()
                    [string]$baseAddress = ([string]$baseResource.'@id').TrimEnd('/')
                    $package.DownloadUri =
                        "$baseAddress/$idLower/$versionLower/$idLower.$versionLower.nupkg"
                    if ($installedVersions.ContainsKey($package.Id)) {
                        $package.Installed = $true
                        $package.InstalledVersion =
                            [string]$installedVersions[$package.Id]
                    }
                    $packages.Add($package)
                }
            }
            catch {
                continue
            }
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InstallNuGetPackage($Package, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.InstallNuGetPackage($Package, 'Install')
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InstallNuGetPackage($Package, 'Update')
    }

    [Result] RemovePackage([Package]$Package) {
        if (-not $this.TestPackageIdentity($Package)) {
            return $this.NewFailure(
                'A valid NuGet package ID and version are required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$storeRoot = [IO.Path]::GetFullPath($this.GetStoreRoot())
        [string]$targetPath = [IO.Path]::GetFullPath((Join-Path `
            (Join-Path $storeRoot $Package.Id) $Package.Version))
        if (-not $targetPath.StartsWith(
            $storeRoot.TrimEnd('\') + '\',
            [StringComparison]::OrdinalIgnoreCase
        )) {
            return $this.NewFailure('Unsafe NuGet store path.', 'PHX_UNSAFE_PATH')
        }
        try {
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            $result = [Result]::Success()
            $result.Code = 'PHX_REMOVED'
            $result.Message = "Removed NuGet package '$($Package.Id)' $($Package.Version)."
            $result.Provider = $this.Name
            $result.Operation = 'Remove'
            $result.Target = $Package.Id
            $result.Data = $Package
            $Package.Installed = $false
            return $result
        }
        catch {
            return $this.NewFailure(
                "NuGet removal failed: $($_.Exception.Message)",
                'PHX_REMOVE_FAILED'
            )
        }
    }

    [Result] ExportPackages() {
        $inventory = $this.GetInstalledPackages()
        $result = [Result]::Success($inventory)
        $result.Code = 'PHX_EXPORTED'
        $result.Message = "Exported $($inventory.Count) NuGet packages."
        $result.Provider = $this.Name
        $result.Operation = 'Export'
        $result.Target = $this.GetStoreRoot()
        return $result
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()
        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackageSilent($package))
        }
        return $results.ToArray()
    }

    hidden [string[]] GetConfiguredFeeds() {
        $feeds = [System.Collections.Generic.List[string]]::new()
        if (-not [string]::IsNullOrWhiteSpace($env:PHOENIX_NUGET_FEEDS)) {
            foreach ($feed in $env:PHOENIX_NUGET_FEEDS.Split(';')) {
                if (-not [string]::IsNullOrWhiteSpace($feed)) {
                    $feeds.Add($feed.Trim())
                }
            }
        }
        if (-not $feeds.Contains('https://api.nuget.org/v3/index.json')) {
            $feeds.Add('https://api.nuget.org/v3/index.json')
        }
        return $feeds.ToArray()
    }

    hidden [string] GetStoreRoot() {
        return Join-Path $env:LOCALAPPDATA 'Phoenix\NuGet'
    }

    hidden [bool] TestPackageIdentity([Package]$Package) {
        return (
            $null -ne $Package -and
            $Package.Id -match '^[A-Za-z0-9_.-]+$' -and
            $Package.Version -match '^[A-Za-z0-9_.+-]+$'
        )
    }

    hidden [string] GetPackageValue([Package]$Package, [string]$Name) {
        $property = $Package.PSObject.Properties[$Name]
        if ($null -eq $property) { return '' }
        return [string]$property.Value
    }

    hidden [Result] InstallNuGetPackage(
        [Package]$Package,
        [string]$Operation
    ) {
        if (-not $this.TestPackageIdentity($Package)) {
            return $this.NewFailure(
                'A valid NuGet package ID and version are required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$downloadUri = $this.GetPackageValue($Package, 'DownloadUri')
        if ([string]::IsNullOrWhiteSpace($downloadUri)) {
            return $this.NewFailure(
                'A NuGet package download URI is required.',
                'PHX_DOWNLOAD_REQUIRED'
            )
        }
        [string]$storeRoot = $this.GetStoreRoot()
        [string]$targetPath = Join-Path (Join-Path $storeRoot $Package.Id) $Package.Version
        [string]$tempPath = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ("Phoenix-NuGet-$([guid]::NewGuid().ToString('N')).nupkg")
        try {
            $null = New-Item -ItemType Directory -Path $targetPath -Force
            Invoke-WebRequest `
                -Uri $downloadUri `
                -OutFile $tempPath `
                -UseBasicParsing `
                -ErrorAction Stop
            $this.ExpandNuGetPackage($tempPath, $targetPath)
            $result = [Result]::Success()
            $result.Code = if ($Operation -eq 'Update') {
                'PHX_UPDATED'
            }
            else { 'PHX_INSTALLED' }
            $result.Message = "$Operation completed for NuGet package '$($Package.Id)'."
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.Data = $Package
            $Package.Installed = $true
            return $result
        }
        catch {
            return $this.NewFailure(
                "NuGet $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
        finally {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    hidden [void] ExpandNuGetPackage(
        [string]$ArchivePath,
        [string]$DestinationPath
    ) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            [string]$root = [IO.Path]::GetFullPath($DestinationPath).
                TrimEnd('\') + '\'
            foreach ($entry in $archive.Entries) {
                [string]$entryPath = [IO.Path]::GetFullPath(
                    (Join-Path $DestinationPath $entry.FullName)
                )
                if (-not $entryPath.StartsWith(
                    $root,
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                    throw 'NuGet package contains an unsafe archive path.'
                }
                if ([string]::IsNullOrEmpty($entry.Name)) {
                    $null = New-Item -ItemType Directory -Path $entryPath -Force
                    continue
                }
                $null = New-Item `
                    -ItemType Directory `
                    -Path ([IO.Path]::GetDirectoryName($entryPath)) `
                    -Force
                [IO.Compression.ZipFileExtensions]::ExtractToFile(
                    $entry,
                    $entryPath,
                    $true
                )
            }
        }
        finally {
            $archive.Dispose()
        }
    }
}
#endregion 20-Providers\NuGetProvider.ps1

#region 20-Providers\DISMProvider.ps1
class DISMProvider : PhoenixProvider {
    DISMProvider() {
        $this.Name = 'DISM'
        $this.Type = 'Online Windows Servicing'
        $this.Priority = 55
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $false
        $this.SupportsRemove = $true
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return (
            $null -ne (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) -and
            $null -ne (Get-Command Get-WindowsPackage -ErrorAction SilentlyContinue)
        )
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Online DISM servicing is built into Windows.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()
        try {
            foreach ($item in @(
                Get-WindowsCapability -Online -ErrorAction Stop |
                    Where-Object State -eq 'Installed'
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.Name, [string]$item.State, 'Capability'
                ))
            }
            foreach ($item in @(
                Get-WindowsOptionalFeature -Online -ErrorAction Stop |
                    Where-Object State -eq 'Enabled'
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.FeatureName, [string]$item.State, 'Feature'
                ))
            }
            foreach ($item in @(
                Get-WindowsPackage -Online -ErrorAction Stop |
                    Where-Object PackageState -eq 'Installed'
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.PackageName, [string]$item.PackageState, 'Package'
                ))
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            return @()
        }
        $packages = [System.Collections.Generic.List[Package]]::new()
        try {
            foreach ($item in @(
                Get-WindowsCapability -Online -Name "*$Name*" -ErrorAction Stop
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.Name, [string]$item.State, 'Capability'
                ))
            }
            foreach ($item in @(
                Get-WindowsOptionalFeature -Online -ErrorAction Stop |
                    Where-Object FeatureName -like "*$Name*"
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.FeatureName, [string]$item.State, 'Feature'
                ))
            }
            foreach ($item in @(
                Get-WindowsPackage -Online -ErrorAction Stop |
                    Where-Object PackageName -like "*$Name*"
            )) {
                $packages.Add($this.ConvertServicingItem(
                    $item.PackageName, [string]$item.PackageState, 'Package'
                ))
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InvokeServicing($Package, 'Install')
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.NewFailure(
            'DISM servicing does not provide an interactive installer mode.',
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.NewFailure(
            'Use install/enable for an applicable online servicing item.',
            'PHX_UPDATE_UNAVAILABLE'
        )
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.InvokeServicing($Package, 'Remove')
    }

    hidden [DISMPackageDefinition] ConvertServicingItem(
        [string]$Name,
        [string]$State,
        [string]$ServicingType
    ) {
        $package = [DISMPackageDefinition]::new()
        $package.Name = $Name
        $package.Id = $Name
        $package.Version = if ($Name -match '~([0-9.]+)$') {
            $Matches[1]
        }
        else { '' }
        $package.ServicingType = $ServicingType
        $package.InstallerType = "DISM$ServicingType"
        $package.State = $State
        $package.Installed = $State -in @('Installed', 'Enabled')
        return $package
    }

    hidden [string] GetServicingType([Package]$Package) {
        if ($null -eq $Package) { return '' }
        $property = $Package.PSObject.Properties['ServicingType']
        if ($null -ne $property) { return [string]$property.Value }
        if ($Package.InstallerType -match '^DISM(.+)$') {
            return $Matches[1]
        }
        return ''
    }

    hidden [string] GetSourcePath([Package]$Package) {
        if ($null -eq $Package) { return '' }
        $property = $Package.PSObject.Properties['SourcePath']
        if ($null -ne $property -and
            -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
        return $Package.DownloadedFile
    }

    hidden [Result] InvokeServicing(
        [Package]$Package,
        [string]$Operation
    ) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A DISM servicing item is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        [string]$servicingType = $this.GetServicingType($Package)
        if ($servicingType -notin @('Capability', 'Feature', 'Package')) {
            return $this.NewFailure(
                'The DISM servicing type is unsupported.',
                'PHX_SERVICING_TYPE_UNSUPPORTED'
            )
        }

        try {
            $response = switch ("$Operation|$servicingType") {
                'Install|Capability' {
                    Add-WindowsCapability -Online -Name $Package.Id -ErrorAction Stop
                }
                'Remove|Capability' {
                    Remove-WindowsCapability -Online -Name $Package.Id -ErrorAction Stop
                }
                'Install|Feature' {
                    Enable-WindowsOptionalFeature `
                        -Online -FeatureName $Package.Id -All -NoRestart -ErrorAction Stop
                }
                'Remove|Feature' {
                    Disable-WindowsOptionalFeature `
                        -Online -FeatureName $Package.Id -NoRestart -ErrorAction Stop
                }
                'Install|Package' {
                    [string]$sourcePath = $this.GetSourcePath($Package)
                    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                        throw 'A local CAB or MSU package source is required.'
                    }
                    Add-WindowsPackage `
                        -Online -PackagePath $sourcePath -NoRestart -ErrorAction Stop
                }
                'Remove|Package' {
                    Remove-WindowsPackage `
                        -Online -PackageName $Package.Id -NoRestart -ErrorAction Stop
                }
            }
            [bool]$restartNeeded =
                [string]$response.RestartNeeded -match '^(?i:yes|true)$'
            $result = [Result]::Success()
            $result.Code = if ($restartNeeded) {
                "PHX_$($Operation.ToUpperInvariant())_RESTART_REQUIRED"
            }
            elseif ($Operation -eq 'Install') { 'PHX_INSTALLED' }
            else { 'PHX_REMOVED' }
            $result.Message = "$Operation completed for online $servicingType '$($Package.Id)'."
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = 0
            $result.RebootRequired = $restartNeeded
            $result.Data = $Package
            $Package.Installed = $Operation -eq 'Install'
            return $result
        }
        catch {
            $result = $this.NewFailure(
                "DISM $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Package.Id
            $result.HasExitCode = $true
            $result.ExitCode = $_.Exception.HResult
            $result.Data = $Package
            return $result
        }
    }
}
#endregion 20-Providers\DISMProvider.ps1

#region 20-Providers\WSUSProvider.ps1
class WSUSProvider : PhoenixProvider {
    WSUSProvider() {
        $this.Name = 'WSUS'
        $this.Type = 'Managed Windows Update'
        $this.Priority = 50
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::Administrator
        $this.SupportsSearch = $true
        $this.SupportsInventory = $true
        $this.SupportsInstall = $true
        $this.SupportsUpdate = $true
        $this.SupportsRemove = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsExport = $false
        $this.SupportsRestore = $false
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return Test-Path `
            -LiteralPath (Join-Path $env:SystemRoot 'System32\wuapi.dll') `
            -PathType Leaf
    }

    [Result] InstallProvider() {
        $result = [Result]::Success()
        $result.Code = 'PHX_PROVIDER_BUILT_IN'
        $result.Message = 'Windows Update Agent is built into Windows.'
        $result.Provider = $this.Name
        $result.Operation = 'InstallProvider'
        return $result
    }

    [Result] UpdateProvider() {
        return $this.InstallProvider()
    }

    [Package[]] GetInstalledPackages() {
        return $this.SearchWindowsUpdates('IsInstalled=1', '')
    }

    [Package[]] SearchPackage([string]$Name) {
        return $this.SearchWindowsUpdates(
            'IsInstalled=0 and IsHidden=0',
            $Name
        )
    }

    [Result] InstallPackageSilent([Package]$Package) {
        return $this.InstallManagedUpdate($Package)
    }

    [Result] InstallPackageInteractive([Package]$Package) {
        return $this.NewFailure(
            'Managed update installation is unattended by Windows Update Agent.',
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

    [Result] UpdatePackage([Package]$Package) {
        return $this.InstallManagedUpdate($Package)
    }

    [Result] RemovePackage([Package]$Package) {
        return $this.NewFailure(
            'Windows Update Agent does not provide general update removal.',
            'PHX_REMOVE_UNAVAILABLE'
        )
    }

    hidden [hashtable] GetUpdatePolicy() {
        $policy = @{
            Managed = $false
            WUServer = ''
            StatusServer = ''
            Source = 'Microsoft Update'
        }
        $windowsUpdatePath =
            'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'
        $auPath = Join-Path $windowsUpdatePath 'AU'
        $settings = Get-ItemProperty `
            -LiteralPath $windowsUpdatePath `
            -ErrorAction SilentlyContinue
        $au = Get-ItemProperty `
            -LiteralPath $auPath `
            -ErrorAction SilentlyContinue
        if ($null -ne $settings) {
            $policy.WUServer = [string]$settings.WUServer
            $policy.StatusServer = [string]$settings.WUStatusServer
        }
        $policy.Managed =
            $null -ne $au -and
            [int]$au.UseWUServer -eq 1 -and
            -not [string]::IsNullOrWhiteSpace($policy.WUServer)
        if ($policy.Managed) {
            $policy.Source = $policy.WUServer
        }
        return $policy
    }

    hidden [object] NewUpdateSearcher([object]$Session) {
        $searcher = $Session.CreateUpdateSearcher()
        $policy = $this.GetUpdatePolicy()
        if ($policy.Managed) {
            $searcher.ServerSelection = 1
        }
        else {
            $searcher.ServerSelection = 2
        }
        return $searcher
    }

    hidden [Package[]] SearchWindowsUpdates(
        [string]$Criteria,
        [string]$NameFilter
    ) {
        $packages = [System.Collections.Generic.List[Package]]::new()
        if (-not $this.TestAvailable()) { return @() }
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $this.NewUpdateSearcher($session)
            $searchResult = $searcher.Search($Criteria)
            $policy = $this.GetUpdatePolicy()
            foreach ($update in @($searchResult.Updates)) {
                [string]$kbText = @($update.KBArticleIDs) -join ', '
                if (
                    -not [string]::IsNullOrWhiteSpace($NameFilter) -and
                    [string]$update.Title -notlike "*$NameFilter*" -and
                    $kbText -notlike "*$NameFilter*"
                ) { continue }

                $package = [WSUSPackageDefinition]::new()
                $package.Name = [string]$update.Title
                $package.Id = [string]$update.Identity.UpdateID
                $package.UpdateId = $package.Id
                $package.RevisionNumber = [int]$update.Identity.RevisionNumber
                $package.Version = [string]$package.RevisionNumber
                $package.KBArticleIds = [string[]]@($update.KBArticleIDs)
                $package.Source = [string]$policy.Source
                $package.ApprovalStatus = if ($update.IsMandatory) {
                    'Mandatory'
                }
                elseif ($update.AutoSelectOnWebSites) {
                    'Approved or auto-selected'
                }
                else { 'Offered by managed source' }
                $package.Applicable = -not [bool]$update.IsInstalled
                $package.Downloaded = [bool]$update.IsDownloaded
                $package.Mandatory = [bool]$update.IsMandatory
                $package.Installed = [bool]$update.IsInstalled
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }
        return $packages.ToArray()
    }

    hidden [string] GetUpdateId([Package]$Package) {
        if ($null -eq $Package) { return '' }
        $property = $Package.PSObject.Properties['UpdateId']
        if ($null -ne $property -and
            -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
        return $Package.Id
    }

    hidden [Result] InstallManagedUpdate([Package]$Package) {
        [string]$updateId = $this.GetUpdateId($Package)
        if ($updateId -notmatch '^[0-9A-Fa-f-]{36}$') {
            return $this.NewFailure(
                'A valid Windows Update identity is required.',
                'PHX_INVALID_PACKAGE'
            )
        }
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $this.NewUpdateSearcher($session)
            $searchResult = $searcher.Search(
                "UpdateID='$updateId' and IsInstalled=0 and IsHidden=0"
            )
            if ($searchResult.Updates.Count -eq 0) {
                return $this.NewFailure(
                    'The update is not applicable or is no longer offered.',
                    'PHX_UPDATE_NOT_APPLICABLE'
                )
            }
            $update = $searchResult.Updates.Item(0)
            if (-not $update.EulaAccepted) { $update.AcceptEula() }
            $collection = New-Object -ComObject Microsoft.Update.UpdateColl
            $null = $collection.Add($update)

            if (-not $update.IsDownloaded) {
                $downloader = $session.CreateUpdateDownloader()
                $downloader.Updates = $collection
                $downloadResult = $downloader.Download()
                if ([int]$downloadResult.ResultCode -notin @(2, 3)) {
                    return $this.NewUpdateFailure(
                        $Package,
                        'Download',
                        [int]$downloadResult.HResult,
                        'The managed update download failed.'
                    )
                }
            }

            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $collection
            $installResult = $installer.Install()
            [int]$resultCode = [int]$installResult.ResultCode
            [bool]$success = $resultCode -in @(2, 3)
            if (-not $success) {
                return $this.NewUpdateFailure(
                    $Package,
                    'Install',
                    [int]$installResult.HResult,
                    "Managed update installation returned result code $resultCode."
                )
            }
            $result = [Result]::Success()
            $result.Code = if ($installResult.RebootRequired) {
                'PHX_INSTALL_RESTART_REQUIRED'
            }
            else { 'PHX_INSTALLED' }
            $result.Message = "Installed managed update '$($Package.Name)'."
            $result.Provider = $this.Name
            $result.Operation = 'Install'
            $result.Target = $updateId
            $result.HasExitCode = $true
            $result.ExitCode = [int]$installResult.HResult
            $result.RebootRequired = [bool]$installResult.RebootRequired
            $result.Data = $Package
            $Package.Installed = $true
            return $result
        }
        catch {
            return $this.NewUpdateFailure(
                $Package,
                'Install',
                $_.Exception.HResult,
                $_.Exception.Message
            )
        }
    }

    hidden [Result] NewUpdateFailure(
        [Package]$Package,
        [string]$Operation,
        [int]$HResult,
        [string]$Message
    ) {
        $result = $this.NewFailure($Message, "PHX_$($Operation.ToUpperInvariant())_FAILED")
        $result.Provider = $this.Name
        $result.Operation = $Operation
        $result.Target = if ($null -ne $Package) { $Package.Id } else { '' }
        $result.HasExitCode = $true
        $result.ExitCode = $HResult
        $result.Data = $Package
        return $result
    }
}
#endregion 20-Providers\WSUSProvider.ps1

#region 30-Models\PhoenixApplication.ps1
class PhoenixApplication {

    [string]$Name
    [string]$Version
    [string]$Build
    [datetime]$StartTime

    PhoenixApplication() {

        $this.Name = "Phoenix Deploy"

        $this.Version = "0.1.0-alpha"

        $this.Build = "0001"

        $this.StartTime = Get-Date

    }

}
#endregion 30-Models\PhoenixApplication.ps1

#region 30-Models\PhoenixActivityRecord.ps1
class PhoenixActivityRecord {

    [string]$OperationId
    [string]$State
    [string]$Action
    [string]$Target
    [string]$Provider
    [string]$Description

    [int]$ProgressPercent
    [string]$ProgressMessage
    [string]$ProgressText

    [datetime]$CreatedAtUtc
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [string]$StartedText
    [string]$ElapsedText

    [bool]$IsTerminal
    [PhoenixBackgroundOperation]$Operation

    [object]$ResultData
    [string]$ResultCode
    [string]$ErrorMessage
    [string[]]$Warnings
    [string[]]$Errors
    [bool]$RequiresRestart
    [bool]$CanCancel
    [bool]$CanRetry

    PhoenixActivityRecord(
        [PhoenixBackgroundOperation]$Operation,
        [string]$Target,
        [string]$Provider
    ) {
        if ($null -eq $Operation) {
            throw 'An activity operation is required.'
        }

        $this.Operation = $Operation
        $this.OperationId = $Operation.OperationId
        $this.Action = $Operation.Action
        $this.Target = $Target
        $this.Provider = $Provider
        $this.Description = $Operation.Description
        $this.Warnings = @()
        $this.Errors = @()

        $this.UpdateLifecycle()
    }

    [void] UpdateLifecycle() {
        $this.State = $this.Operation.State.ToString()
        $this.ProgressPercent =
            $this.Operation.ProgressPercent
        $this.ProgressMessage =
            $this.Operation.ProgressMessage
        $this.ProgressText = (
            '{0}% - {1}' -f
            $this.ProgressPercent,
            $this.ProgressMessage
        )

        $this.CreatedAtUtc =
            $this.Operation.CreatedAtUtc
        $this.StartedAtUtc =
            $this.Operation.StartedAtUtc
        $this.CompletedAtUtc =
            $this.Operation.CompletedAtUtc
        $this.IsTerminal =
            $this.Operation.IsTerminal()
        $this.CanCancel =
            $this.Operation.CanCancel()
        $this.CanRetry =
            $this.IsTerminal

        [datetime]$effectiveStart = if (
            $this.StartedAtUtc -gt [datetime]::MinValue
        ) {
            $this.StartedAtUtc
        }
        else {
            $this.CreatedAtUtc
        }

        $this.StartedText =
            $effectiveStart.ToLocalTime().ToString(
                'HH:mm:ss'
            )

        [datetime]$effectiveEnd = if (
            $this.CompletedAtUtc -gt [datetime]::MinValue
        ) {
            $this.CompletedAtUtc
        }
        else {
            [datetime]::UtcNow
        }

        [timespan]$elapsed =
            $effectiveEnd - $effectiveStart

        if ($elapsed -lt [timespan]::Zero) {
            $elapsed = [timespan]::Zero
        }

        $this.ElapsedText = (
            '{0:00}:{1:00}:{2:00}' -f
            [Math]::Floor($elapsed.TotalHours),
            $elapsed.Minutes,
            $elapsed.Seconds
        )

        $this.ErrorMessage =
            $this.Operation.ErrorMessage
    }

    [void] SetResult(
        [object]$Data,
        [string]$Error
    ) {
        $this.ResultData = $Data
        $this.ErrorMessage = $Error

        $codes =
            [System.Collections.Generic.List[string]]::new()

        $warningItems =
            [System.Collections.Generic.List[string]]::new()

        $errorItems =
            [System.Collections.Generic.List[string]]::new()

        $candidates =
            [System.Collections.Generic.List[object]]::new()

        foreach ($item in @($Data)) {
            if ($null -eq $item) {
                continue
            }

            $candidates.Add($item)

            if ($null -ne $item.PSObject.Properties['Data']) {
                foreach ($nestedItem in @($item.Data)) {
                    if ($null -ne $nestedItem) {
                        $candidates.Add($nestedItem)
                    }
                }
            }
        }

        foreach ($candidate in $candidates) {
            if (
                $null -ne $candidate.PSObject.Properties['Code'] -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$candidate.Code
                )
            ) {
                [string]$code = [string]$candidate.Code

                if (-not $codes.Contains($code)) {
                    $codes.Add($code)
                }
            }

            if ($null -ne $candidate.PSObject.Properties['Warnings']) {
                foreach ($warning in @($candidate.Warnings)) {
                    if (-not [string]::IsNullOrWhiteSpace(
                        [string]$warning
                    )) {
                        $warningItems.Add([string]$warning)
                    }
                }
            }

            if ($null -ne $candidate.PSObject.Properties['Errors']) {
                foreach ($resultError in @($candidate.Errors)) {
                    if (-not [string]::IsNullOrWhiteSpace(
                        [string]$resultError
                    )) {
                        $errorItems.Add([string]$resultError)
                    }
                }
            }

            foreach (
                $restartProperty in @(
                    'RequiresRestart'
                    'RebootRequired'
                    'RestartRequired'
                )
            ) {
                if (
                    $null -ne $candidate.PSObject.Properties[
                        $restartProperty
                    ] -and
                    [bool]$candidate.$restartProperty
                ) {
                    $this.RequiresRestart = $true
                }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($Error)) {
            $errorItems.Insert(0, $Error)
        }

        $this.ResultCode = $codes -join ', '
        $this.Warnings = $warningItems.ToArray()
        $this.Errors = $errorItems.ToArray()

        if ($errorItems.Count -gt 0) {
            $this.ErrorMessage = $errorItems -join [Environment]::NewLine
        }
    }
}
#endregion 30-Models\PhoenixActivityRecord.ps1

#region 30-Models\PhoenixInventory.ps1
class PhoenixInventory {

    [datetime]$Timestamp

    [string]$ComputerName

    [string]$UserName

    [hashtable]$Hardware

    [hashtable]$Software

    [hashtable]$Drivers

    [hashtable]$Packages

    [hashtable]$Providers

    PhoenixInventory() {

        $this.Timestamp    = Get-Date
        $this.ComputerName = $env:COMPUTERNAME
        $this.UserName     = $env:USERNAME

        $this.Hardware = @{}
        $this.Software = @{}
        $this.Drivers  = @{}
        $this.Packages = @{}
        $this.Providers = @{}

    }

}
#endregion 30-Models\PhoenixInventory.ps1

#region 30-Models\PackageCandidate.ps1
class PackageCandidate {

    [Package]$Package

    [PhoenixProvider]$Provider

    [double]$Score

    [string]$Reason

}
#endregion 30-Models\PackageCandidate.ps1

#region 30-Models\PhoenixManifest.ps1
class PhoenixRestorePlanRecord {
    [string]$OperationId
    [string]$RecordType
    [string]$Id
    [string]$Name
    [string]$RequestedVersion
    [string]$InstalledVersion
    [string]$AvailableVersion
    [string]$Provider
    [string[]]$ProviderAlternatives
    [string]$PlannedAction
    [bool]$Selected
    [bool]$Eligible
    [bool]$RequiresElevation
    [bool]$Protected
    [bool]$RebootRequired
    [string[]]$DependencyIds
    [string]$Safety
    [string]$Reason
    [string]$VerificationStatus
    [string]$VerificationDetails
    [object]$ManifestRecord

    PhoenixRestorePlanRecord() {
        $this.OperationId = [guid]::NewGuid().ToString()
        $this.ProviderAlternatives = @()
        $this.DependencyIds = @()
        $this.PlannedAction = 'Blocked'
        $this.Safety = 'Not evaluated.'
    }
}

class PhoenixRestorePlan {
    [string]$PlanId
    [string]$Schema
    [string]$SchemaVersion
    [string]$ManifestId
    [string]$ManifestPath
    [datetime]$CreatedAtUtc
    [string]$ComputerName
    [PhoenixRestorePlanRecord[]]$Records
    [int]$TotalCount
    [int]$SelectedCount
    [int]$BlockedCount
    [int]$SatisfiedCount

    PhoenixRestorePlan() {
        $this.PlanId = [guid]::NewGuid().ToString()
        $this.Schema = 'PhoenixRestorePlan'
        $this.SchemaVersion = '1.0'
        $this.CreatedAtUtc = [datetime]::UtcNow
        $this.ComputerName = $env:COMPUTERNAME
        $this.Records = @()
    }

    [void] RefreshSummary() {
        $this.TotalCount = $this.Records.Count
        $this.SelectedCount = @($this.Records | Where-Object Selected).Count
        $this.BlockedCount = @(
            $this.Records | Where-Object { -not $_.Eligible }
        ).Count
        $this.SatisfiedCount = @(
            $this.Records | Where-Object PlannedAction -EQ 'AlreadySatisfied'
        ).Count
    }
}
#endregion 30-Models\PhoenixManifest.ps1

#region 30-Models\PhoenixRestoreCheckpoint.ps1
class PhoenixRestoreCheckpointRecord {
    [string]$OperationId
    [string]$RecordType
    [string]$Id
    [string]$Provider
    [string]$PlannedAction
    [string]$Status
    [int]$Attempts
    [bool]$Retryable
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [string]$ResultCode
    [string]$Error
    [bool]$RebootRequired

    PhoenixRestoreCheckpointRecord() {
        $this.Status = 'Pending'
    }
}

class PhoenixRestoreCheckpoint {
    [string]$Schema
    [string]$SchemaVersion
    [string]$SessionId
    [string]$PlanId
    [string]$ManifestId
    [string]$ManifestPath
    [string]$ManifestSha256
    [string]$ComputerName
    [string]$ComputerManufacturer
    [string]$ComputerModel
    [datetime]$CreatedAtUtc
    [datetime]$UpdatedAtUtc
    [int]$Sequence
    [string]$Status
    [bool]$RebootRequired
    [string]$PhoenixVersion
    [object]$PlanSnapshot
    [object]$VerificationSnapshot
    [PhoenixRestoreCheckpointRecord[]]$Records
    [string]$StoragePath

    PhoenixRestoreCheckpoint() {
        $this.Schema = 'PhoenixRestoreCheckpoint'
        $this.SchemaVersion = '1.0'
        $this.SessionId = [guid]::NewGuid().ToString()
        $this.CreatedAtUtc = [datetime]::UtcNow
        $this.UpdatedAtUtc = $this.CreatedAtUtc
        $this.Status = 'Planned'
        $this.Records = @()
    }
}
#endregion 30-Models\PhoenixRestoreCheckpoint.ps1

#region 30-Models\PhoenixRestoreVerification.ps1
class PhoenixRestoreVerificationRecord {
    [string]$OperationId
    [string]$RecordType
    [string]$Id
    [string]$Provider
    [string]$ExpectedVersion
    [string]$ActualVersion
    [string]$Status
    [string]$ResultCode
    [string]$Details
    [bool]$RebootRequired
}

class PhoenixRestoreVerification {
    [string]$Schema
    [string]$SchemaVersion
    [string]$SessionId
    [datetime]$StartedAtUtc
    [datetime]$CompletedAtUtc
    [string]$Status
    [PhoenixRestoreVerificationRecord[]]$Records
    [int]$VerifiedCount
    [int]$ProblemCount
    [int]$SkippedCount
    [bool]$RebootRequired

    PhoenixRestoreVerification() {
        $this.Schema = 'PhoenixRestoreVerification'
        $this.SchemaVersion = '1.0'
        $this.StartedAtUtc = [datetime]::UtcNow
        $this.Status = 'Running'
        $this.Records = @()
    }
}
#endregion 30-Models\PhoenixRestoreVerification.ps1

#region 10-Core\PhoenixContext.ps1
class PhoenixContext {

    [string]$Version
    [string]$SessionID
    [datetime]$StartTime
    [datetime]$InitializedAtUtc

    [string]$LifecycleState
    [string]$InitializationError
    [bool]$IsInitialized
    [bool]$IsResumed
    [int]$Generation

    [string]$ProjectRoot
    [string]$CacheRoot
    [string]$WorkingRoot
    [string]$CheckpointRoot
    [string]$ThemeRoot
    [string]$InstalledThemeRoot
    [string]$RecoveryRoot
    [string]$ComputerName
    [string]$UserName

    [bool]$IsAdministrator
    [PhoenixPrivilegeLevel]$PrivilegeLevel

    [PhoenixConfiguration]$Configuration
    [PhoenixLogger]$Logger
    [PhoenixBuild]$Build
    [PhoenixInventory]$Inventory
    [object]$Scheduler
    [object]$RuntimeRecovery

    [System.Collections.Generic.List[PhoenixProvider]]$Providers
    [System.Collections.Generic.List[string]]$InitializationWarnings

    PhoenixContext([string]$ProjectRoot) {

        $this.Version = '0.1.5'
        $this.SessionID = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.InitializedAtUtc = [datetime]::MinValue
        $this.LifecycleState = 'Created'
        $this.InitializationError = ''
        $this.IsInitialized = $false
        $this.IsResumed = $false
        $this.Generation = 0

        $this.ProjectRoot = [IO.Path]::GetFullPath(
            $ProjectRoot
        )

        $this.CacheRoot = Join-Path `
            $this.ProjectRoot `
            'Cache'

        $this.WorkingRoot = Join-Path `
            $this.CacheRoot `
            'Working'

        $this.CheckpointRoot = Join-Path `
            $this.ProjectRoot `
            'Checkpoints'

        $this.ThemeRoot = Join-Path `
            $this.ProjectRoot `
            'Themes'

        $this.InstalledThemeRoot = Join-Path `
            $this.ThemeRoot `
            'Installed'

        $this.RecoveryRoot = Join-Path `
            $this.CacheRoot `
            'Recovery'

        if (-not (Test-Path -LiteralPath $this.WorkingRoot)) {

            New-Item `
                -ItemType Directory `
                -Path $this.WorkingRoot `
                -Force |
                Out-Null
        }

        $this.ComputerName = $env:COMPUTERNAME
        $this.UserName = $env:USERNAME

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = [Security.Principal.WindowsPrincipal]::new(
            $identity
        )

        $this.IsAdministrator = $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        if ($this.IsAdministrator) {
            $this.PrivilegeLevel = [PhoenixPrivilegeLevel]::Administrator
        }
        else {
            $this.PrivilegeLevel = [PhoenixPrivilegeLevel]::User
        }

        $this.Configuration = [PhoenixConfiguration]::new($ProjectRoot)
        $this.Logger = [PhoenixLogger]::new($ProjectRoot)
        $this.Build = [PhoenixBuild]::new()
        $this.Inventory = [PhoenixInventory]::new()
        $this.Scheduler = $null
        $this.RuntimeRecovery = $null

        $this.Providers =
            [System.Collections.Generic.List[PhoenixProvider]]::new()

        $this.InitializationWarnings =
            [System.Collections.Generic.List[string]]::new()
    }
}
#endregion 10-Core\PhoenixContext.ps1

