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

