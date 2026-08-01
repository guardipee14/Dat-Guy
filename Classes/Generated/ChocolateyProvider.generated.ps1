#region Composite class: ChocolateyProvider

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

#endregion Composite class: ChocolateyProvider
