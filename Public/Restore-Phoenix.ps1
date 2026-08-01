using module '..\Classes\Phoenix.Classes.psm1'

function Restore-Phoenix {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter()]
        [ValidateSet(
            'WinGet',
            'Chocolatey',
            'Scoop',
            'PowerShell Gallery'
        )]
        [string[]]$Provider = @(
            'WinGet',
            'Chocolatey',
            'Scoop',
            'PowerShell Gallery'
        ),

        [Parameter()]
        [switch]$SkipDrivers,

        [Parameter()]
        [switch]$ScanDriversOnly,

        [Parameter()]
        [switch]$SkipPackages,

        [Parameter()]
        [PhoenixInstallMode]$Mode =
            [PhoenixInstallMode]::SilentPreferred,

        [Parameter()]
        [switch]$PreserveDownloads,

        [Parameter()]
        [switch]$ReinstallInstalled,

        [Parameter()]
        [switch]$StopOnError,

        [Parameter()]
        [switch]$Unattended
    )

    if ($SkipDrivers -and $SkipPackages) {

        [Result]$result = [Result]::Failure(
            'Restore-Phoenix cannot skip both drivers and packages.'
        )

        $result.Code = 'PHX_RESTORE_NOTHING_SELECTED'

        return $result
    }

    try {
        $context =
            Resolve-PhoenixContext `
                -ErrorAction Stop
    }
    catch {

        [Result]$result = [Result]::Failure(
            "Phoenix initialization failed: $($_.Exception.Message)"
        )

        $result.Code = 'PHX_INITIALIZATION_FAILED'

        return $result
    }

    try {
        $manifest =
            Read-PhoenixManifest `
                -LiteralPath $ManifestPath
    }
    catch {

        [Result]$result = [Result]::Failure(
            $_.Exception.Message
        )

        $result.Code = 'PHX_RESTORE_MANIFEST_INVALID'
        $result.Errors = @(
            $_.Exception.Message
        )

        return $result
    }

    [int]$manifestPackageCount =
        @($manifest.Packages).Count

    [int]$manifestDriverCount =
        @($manifest.Drivers).Count

    [string]$restoreDescription = (
        'Restore {0} package records and process drivers from schema {1}' -f
        $manifestPackageCount,
        $manifest.SchemaVersion
    )

    if (
        -not $PSCmdlet.ShouldProcess(
            $env:COMPUTERNAME,
            $restoreDescription
        )
    ) {

        [Result]$result = [Result]::Success()
        $result.Code = if ($WhatIfPreference) {
            'PHX_RESTORE_PREVIEW'
        }
        else {
            'PHX_RESTORE_SKIPPED'
        }
        $result.Message = if ($WhatIfPreference) {
            'Phoenix restore preview completed; no changes were made.'
        }
        else {
            'Phoenix restore was skipped.'
        }
        $result.Data = [pscustomobject]@{
            Stage                = 'RestorePlan'
            ManifestPath         = $manifest.Path
            SchemaVersion       = $manifest.SchemaVersion
            ManifestPackageCount = $manifestPackageCount
            ManifestDriverCount  = $manifestDriverCount
            DriversSelected      = -not [bool]$SkipDrivers
            PackagesSelected     = -not [bool]$SkipPackages
            Providers            = @($Provider)
        }

        return $result
    }

    if (
        -not (
            Test-PhoenixPrivilege `
                -RequiredPrivilege (
                    [PhoenixPrivilegeLevel]::Administrator
                )
        )
    ) {

        [hashtable]$elevationParameters = @{
            ManifestPath       = $manifest.Path
            Provider           = @($Provider)
            SkipDrivers        = [bool]$SkipDrivers
            ScanDriversOnly    = [bool]$ScanDriversOnly
            SkipPackages       = [bool]$SkipPackages
            Mode               = $Mode.ToString()
            PreserveDownloads  = [bool]$PreserveDownloads
            ReinstallInstalled = [bool]$ReinstallInstalled
            StopOnError        = [bool]$StopOnError
            Unattended         = [bool]$Unattended
            Confirm            = $false
        }

        [datetime]$elevationStartedAt = Get-Date

        $elevationResponse =
            Request-PhoenixElevation `
                -RequiredPrivilege (
                    [PhoenixPrivilegeLevel]::Administrator
                ) `
                -CommandName 'Restore-Phoenix' `
                -CommandParameters $elevationParameters `
                -Reason 'Restore Phoenix drivers and packages from a manifest' `
                -WaitForCompletion

        if (
            $null -eq $elevationResponse -or
            -not $elevationResponse.Started
        ) {

            [Result]$result = [Result]::Failure(
                'Administrator approval was cancelled or elevation failed.'
            )

            $result.Code = 'PHX_ELEVATION_FAILED'

            return $result
        }

        if (-not $elevationResponse.Completed) {

            [string]$errorMessage =
                $elevationResponse.ErrorMessage

            if ([string]::IsNullOrWhiteSpace($errorMessage)) {
                $errorMessage =
                    'The elevated Phoenix restore did not complete successfully.'
            }

            [Result]$result = [Result]::Failure(
                $errorMessage
            )

            $result.Code = 'PHX_ELEVATED_COMMAND_FAILED'

            return $result
        }

        $elevatedResults = @(
            $elevationResponse.Results
        )

        [timespan]$elapsed =
            (Get-Date) - $elevationStartedAt

        Write-Host ''
        Write-Host 'Elevated Phoenix restore completed.' `
            -ForegroundColor Green

        Write-PhoenixRestoreSummary `
            -Results $elevatedResults `
            -ManifestPath $manifest.Path `
            -ElapsedSeconds $elapsed.TotalSeconds

        return $elevatedResults
    }

    [datetime]$restoreStartedAt = Get-Date

    $results =
        [System.Collections.Generic.List[Result]]::new()

    Write-Host ''
    Write-Host 'Starting Phoenix restore...' `
        -ForegroundColor Cyan

    Write-Host (
        'Manifest: {0}' -f
        $manifest.Path
    ) -ForegroundColor DarkGray

    if (-not $SkipDrivers) {

        Write-PhoenixLog `
            -Level Info `
            -Message 'Running the Phoenix driver stage before package restoration.'

        [Result]$driverResult =
            Update-PhoenixDriver `
                -ScanOnly:$ScanDriversOnly `
                -Unattended:$Unattended

        if ($null -ne $driverResult) {
            $results.Add($driverResult)
        }

        if (
            $StopOnError -and
            $null -ne $driverResult -and
            -not $driverResult.Success
        ) {

            [timespan]$elapsed =
                (Get-Date) - $restoreStartedAt

            Write-PhoenixRestoreSummary `
                -Results $results.ToArray() `
                -ManifestPath $manifest.Path `
                -ElapsedSeconds $elapsed.TotalSeconds

            return $results.ToArray()
        }
    }

    if (-not $SkipPackages) {

        $providerMap = @{}
        $installedPackageKeys =
            [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase
            )

        foreach ($providerName in @($Provider)) {

            $resolvedProvider = @(
                $context.Providers |
                    Where-Object {
                        $_.Name -ieq $providerName
                    } |
                    Sort-Object Priority -Descending
            ) |
                Select-Object -First 1

            if ($null -eq $resolvedProvider) {
                continue
            }

            $providerMap[$resolvedProvider.Name] =
                $resolvedProvider

            if (-not $resolvedProvider.Available) {
                continue
            }

            try {

                foreach (
                    $installedPackage in
                    @($resolvedProvider.GetInstalledPackages())
                ) {

                    if (
                        $null -eq $installedPackage -or
                        [string]::IsNullOrWhiteSpace(
                            $installedPackage.Id
                        )
                    ) {
                        continue
                    }

                    [void]$installedPackageKeys.Add(
                        (
                            '{0}|{1}' -f
                            $resolvedProvider.Name,
                            $installedPackage.Id
                        )
                    )
                }
            }
            catch {
                Write-Warning (
                    "Could not query installed $providerName packages: $($_.Exception.Message)"
                )
            }
        }

        $manifestPackages = @(
            $manifest.Packages
        )

        [int]$packageCount =
            $manifestPackages.Count

        for (
            [int]$packageIndex = 0
            $packageIndex -lt $packageCount
            $packageIndex++
        ) {

            $manifestPackage =
                $manifestPackages[$packageIndex]

            [Package]$package =
                ConvertTo-PhoenixRestorePackage `
                    -InputObject $manifestPackage

            [int]$percentComplete = if ($packageCount -gt 0) {
                [Math]::Floor(
                    ($packageIndex / $packageCount) * 100
                )
            }
            else {
                100
            }

            [string]$packageLabel = if ($null -eq $package) {
                'Invalid manifest package record'
            }
            else {
                '{0} [{1}]' -f
                $package.Id,
                $package.Provider
            }

            Write-Progress `
                -Id 3 `
                -Activity 'Phoenix package restore' `
                -Status (
                    '{0}% complete - {1}' -f
                    $percentComplete,
                    $packageLabel
                ) `
                -PercentComplete $percentComplete

            Write-Host (
                '[{0,3}%] {1}' -f
                $percentComplete,
                $packageLabel
            ) -ForegroundColor Cyan

            if ($null -eq $package) {

                [Result]$invalidResult = [Result]::Failure(
                    'Manifest package record does not contain a valid package ID.'
                )

                $invalidResult.Code =
                    'PHX_RESTORE_INVALID_PACKAGE'

                $invalidResult.Data = [pscustomobject]@{
                    Stage              = 'RestorePackage'
                    Id                 = ''
                    Name               = ''
                    Provider           = ''
                    Version            = ''
                    InstallerType      = ''
                    ProviderResultCode = ''
                }

                $results.Add($invalidResult)

                if ($StopOnError) {
                    break
                }

                continue
            }

            [bool]$isRestorablePackage =
                Test-PhoenixRestorePackage `
                    -InputObject $package

            if (-not $isRestorablePackage) {

                [Result]$unrestorableResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code 'PHX_RESTORE_NOT_RESTORABLE' `
                        -Success $true `
                        -Message (
                            "Skipped '$($package.Id)' because the inventory record is not correlated with a restorable WinGet source package."
                        )

                $results.Add($unrestorableResult)
                continue
            }

            if ($Provider -inotcontains $package.Provider) {

                [Result]$filteredResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code 'PHX_RESTORE_PROVIDER_FILTERED' `
                        -Success $true `
                        -Message (
                            "Skipped '$($package.Id)' because provider '$($package.Provider)' was not selected."
                        )

                $results.Add($filteredResult)
                continue
            }

            $resolvedProvider =
                $providerMap[$package.Provider]

            if ($null -eq $resolvedProvider) {

                [Result]$providerResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code 'PHX_RESTORE_PROVIDER_NOT_FOUND' `
                        -Success $false `
                        -Message (
                            "Phoenix provider '$($package.Provider)' was not found."
                        )

                $results.Add($providerResult)

                if ($StopOnError) {
                    break
                }

                continue
            }

            if (
                -not $resolvedProvider.Available -or
                -not $resolvedProvider.SupportsInstall
            ) {

                [Result]$providerResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code 'PHX_RESTORE_PROVIDER_UNAVAILABLE' `
                        -Success $false `
                        -Message (
                            "Phoenix provider '$($package.Provider)' cannot install packages."
                        )

                $results.Add($providerResult)

                if ($StopOnError) {
                    break
                }

                continue
            }

            [string]$installedKey = (
                '{0}|{1}' -f
                $package.Provider,
                $package.Id
            )

            if (
                -not $ReinstallInstalled -and
                $installedPackageKeys.Contains($installedKey)
            ) {

                [Result]$alreadyInstalledResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code 'PHX_RESTORE_ALREADY_INSTALLED' `
                        -Success $true `
                        -Message (
                            "'$($package.Id)' is already installed through $($package.Provider)."
                        )

                $results.Add($alreadyInstalledResult)
                continue
            }

            try {

                [Result]$installResult =
                    Install-PhoenixPackage `
                        -Package $package `
                        -Provider $package.Provider `
                        -Mode $Mode `
                        -PreserveDownloads:$PreserveDownloads `
                        -Confirm:$false

                if ($null -eq $installResult) {

                    $installResult = [Result]::Failure(
                        "Phoenix returned no installation result for '$($package.Id)'."
                    )

                    $installResult.Code =
                        'PHX_INSTALL_NO_RESULT'
                }

                [string]$providerMessage =
                    $installResult.Message

                if ([string]::IsNullOrWhiteSpace($providerMessage)) {
                    $providerMessage = if ($installResult.Success) {
                        "Restored '$($package.Id)' through $($package.Provider)."
                    }
                    else {
                        "Restore installation failed for '$($package.Id)'."
                    }
                }

                [string]$restoreCode = if (
                    $installResult.Code -eq
                    'PHX_ALREADY_INSTALLED'
                ) {
                    'PHX_RESTORE_ALREADY_INSTALLED'
                }
                elseif ($installResult.Success) {
                    'PHX_RESTORE_INSTALLED'
                }
                else {
                    'PHX_RESTORE_INSTALL_FAILED'
                }

                [Result]$restorePackageResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code $restoreCode `
                        -Success $installResult.Success `
                        -Message $providerMessage `
                        -ProviderCode $installResult.Code `
                        -Warnings @($installResult.Warnings) `
                        -Errors @($installResult.Errors)

                $results.Add($restorePackageResult)

                if (
                    $installResult.Success -and
                    -not $installedPackageKeys.Contains($installedKey)
                ) {
                    [void]$installedPackageKeys.Add($installedKey)
                }

                if (
                    $StopOnError -and
                    -not $installResult.Success
                ) {
                    break
                }
            }
            catch {

                [Result]$restorePackageResult =
                    New-PhoenixRestorePackageResult `
                        -Package $package `
                        -Code 'PHX_RESTORE_INSTALL_FAILED' `
                        -Success $false `
                        -Message (
                            "Restore installation failed for '$($package.Id)': $($_.Exception.Message)"
                        ) `
                        -Errors @(
                            $_.Exception.Message
                        )

                $results.Add($restorePackageResult)

                if ($StopOnError) {
                    break
                }
            }
        }

        Write-Host (
            '[100%] Phoenix package restore stage complete.'
        ) -ForegroundColor Green

        Write-Progress `
            -Id 3 `
            -Activity 'Phoenix package restore' `
            -Completed
    }

    [timespan]$restoreElapsed =
        (Get-Date) - $restoreStartedAt

    Write-PhoenixRestoreSummary `
        -Results $results.ToArray() `
        -ManifestPath $manifest.Path `
        -ElapsedSeconds $restoreElapsed.TotalSeconds

    return $results.ToArray()
}
