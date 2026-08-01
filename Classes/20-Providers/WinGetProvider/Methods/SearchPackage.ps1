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

