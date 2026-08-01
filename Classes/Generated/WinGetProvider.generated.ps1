#region Composite class: WinGetProvider

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

#endregion Composite class: WinGetProvider
