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

    }

    ##########################################################
    ## Provider Management
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

    [Result] UpdateProvider() {

        choco upgrade chocolatey -y

        return [Result]::Success(
            "Chocolatey updated."
        )

    }

    ##########################################################
    ## Package Discovery
    ##########################################################

    [Package[]] GetInstalledPackages() {

    $packages = [System.Collections.Generic.List[Package]]::new()

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

    [Package[]] SearchPackage([string]$Name) {

    $packages = [System.Collections.Generic.List[Package]]::new()

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

    ##########################################################
    ## Package Management
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

        Write-Host (
            "Installing $($Package.Name) [$($Package.Id)] silently..."
        ) -ForegroundColor Cyan

        & $chocoExecutable `
            install `
            $Package.Id `
            --yes `
            --no-progress |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {

            return $this.NewFailure(
                "Chocolatey installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )
        }

        $Package.Installed = $true

        $result = [Result]::Success(
            "Installed $($Package.Id) silently."
        )

        $result.Code = 'PHX_INSTALLED'

        return $result
    }
    catch {

        return $this.NewFailure(
            "Chocolatey installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}

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

        Write-Host (
            "Starting the interactive installer for $($Package.Name) [$($Package.Id)]..."
        ) -ForegroundColor Yellow

        & $chocoExecutable `
            install `
            $Package.Id `
            --yes `
            --not-silent `
            --no-progress |
            Out-Host

        [int]$exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {

            return $this.NewFailure(
                "Interactive Chocolatey installation failed with exit code $exitCode.",
                'PHX_INSTALL_FAILED'
            )
        }

        $Package.Installed = $true

        $result = [Result]::Success(
            "Installed $($Package.Id) interactively."
        )

        $result.Code = 'PHX_INSTALLED_INTERACTIVE'

        return $result
    }
    catch {

        return $this.NewFailure(
            "Interactive Chocolatey installation failed: $($_.Exception.Message)",
            'PHX_INSTALL_FAILED'
        )
    }
}

    [Result] UpdatePackage([Package]$Package) {

        # TODO

        return [Result]::Success()

    }

    [Result] RemovePackage([Package]$Package) {

        # TODO

        return [Result]::Success()

    }

}