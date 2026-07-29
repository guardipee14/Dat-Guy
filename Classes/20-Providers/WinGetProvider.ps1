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

    ##########################################################
    ## Provider Management
    ##########################################################

    [bool] TestAvailable() {

        return $null -ne (
            Get-Command winget -ErrorAction SilentlyContinue
        )

    }

    [Result] InstallProvider() {

        return [Result]::Failure(
            "WinGet is included with Windows App Installer."
        )

    }

    [Result] UpdateProvider() {

        winget source update | Out-Null

        return [Result]::Success(
            "WinGet sources updated."
        )

    }

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

    ##########################################################
    ## Package Discovery
    ##########################################################

    [Package[]] GetInstalledPackages() {

    $packages = [System.Collections.Generic.List[Package]]::new()

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
                [string]::IsNullOrWhiteSpace($id)
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

    [Package[]] SearchPackage([string]$Name) {

    $packages = [System.Collections.Generic.List[Package]]::new()

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
                [string]::IsNullOrWhiteSpace($id)
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

    ##########################################################
    ## Package Management
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

        if ($exitCode -ne 0) {

            return $this.NewFailure(
                "Silent WinGet installation failed with exit code $exitCode.",
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
            "WinGet installation failed: $($_.Exception.Message)",
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

        if ($exitCode -ne 0) {

            return $this.NewFailure(
                "WinGet repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )
        }

        $result = [Result]::Success(
            "Repaired $($Package.Id) silently."
        )

        $result.Code = 'PHX_REPAIRED'

        return $result
    }
    catch {

        return $this.NewFailure(
            "WinGet repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}

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

        if ($exitCode -ne 0) {

            return $this.NewFailure(
                "Interactive WinGet repair failed with exit code $exitCode.",
                'PHX_REPAIR_FAILED'
            )
        }

        $result = [Result]::Success(
            "Repaired $($Package.Id) interactively."
        )

        $result.Code = 'PHX_REPAIRED_INTERACTIVE'

        return $result
    }
    catch {

        return $this.NewFailure(
            "Interactive WinGet repair failed: $($_.Exception.Message)",
            'PHX_REPAIR_FAILED'
        )
    }
}
}