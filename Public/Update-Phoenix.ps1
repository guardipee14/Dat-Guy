using module '..\Classes\Phoenix.Classes.psm1'

function Update-Phoenix {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [ValidateSet(
            'WinGet',
            'Chocolatey'
        )]
        [string[]]$Provider = @(
            'WinGet',
            'Chocolatey'
        ),

        [Parameter()]
        [switch]$SkipDrivers,

        [Parameter()]
        [switch]$ScanDriversOnly,

        [Parameter()]
        [switch]$SkipPackages,

        [Parameter()]
        [switch]$PreserveDownloads,

        [Parameter()]
        [switch]$AllowMigration,

        [Parameter()]
        [switch]$ForceProtectedMigration,

        [Parameter()]
        [switch]$Unattended
    )

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

    if (
        -not $PSCmdlet.ShouldProcess(
            $env:COMPUTERNAME,
            'Update Phoenix drivers and installed packages'
        )
    ) {
        return
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
            Provider                  = @($Provider)
            SkipDrivers               = [bool]$SkipDrivers
            ScanDriversOnly           = [bool]$ScanDriversOnly
            SkipPackages              = [bool]$SkipPackages
            PreserveDownloads         = [bool]$PreserveDownloads
            AllowMigration            = [bool]$AllowMigration
            ForceProtectedMigration   = [bool]$ForceProtectedMigration
            Unattended                = [bool]$Unattended
            Confirm                   = $false
        }

        [datetime]$elevationStartedAt = Get-Date

        $elevationResponse =
            Request-PhoenixElevation `
                -RequiredPrivilege (
                    [PhoenixPrivilegeLevel]::Administrator
                ) `
                -CommandName 'Update-Phoenix' `
                -CommandParameters $elevationParameters `
                -Reason 'Update Phoenix-managed components' `
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

            if (
                [string]::IsNullOrWhiteSpace(
                    $errorMessage
                )
            ) {
                $errorMessage =
                    'The elevated Phoenix command did not complete successfully.'
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

        $driverResults = @(
    $elevatedResults |
        Where-Object {

            $stageProperty = $null

            if ($null -ne $_.Data) {
                $stageProperty =
                    $_.Data.PSObject.Properties['Stage']
            }

            $null -ne $stageProperty -and
            [string]$stageProperty.Value -eq 'Driver'
        }
)

$packageResults = @(
    $elevatedResults |
        Where-Object {

            $stageProperty = $null

            if ($null -ne $_.Data) {
                $stageProperty =
                    $_.Data.PSObject.Properties['Stage']
            }

            $null -eq $stageProperty -or
            [string]$stageProperty.Value -ne 'Driver'
        }
)

Write-Host ''
Write-Host 'Elevated Phoenix update completed.' `
    -ForegroundColor Green

if ($driverResults.Count -gt 0) {

    $completedDriverResult =
        $driverResults |
            Select-Object -Last 1

    [timespan]$driverElapsed =
        [timespan]::FromSeconds(
            [double]$completedDriverResult.Data.ElapsedSeconds
        )

    Write-Host ''
    Write-Host 'Phoenix driver summary' `
        -ForegroundColor Cyan

    Write-Host '----------------------'

    Write-Host (
        'Result            : {0}' -f
        $completedDriverResult.Code
    )

    Write-Host (
        'Mode              : {0}' -f
        $completedDriverResult.Data.Mode
    )

    Write-Host (
        'Updates available : {0}' -f
        $completedDriverResult.Data.AvailableCount
    )

    Write-Host (
        'Updates selected  : {0}' -f
        $completedDriverResult.Data.SelectedCount
    )

    Write-Host (
        'Already cached    : {0}' -f
        $completedDriverResult.Data.CachedCount
    )

    Write-Host (
        'Downloaded        : {0}' -f
        $completedDriverResult.Data.DownloadedCount
    )

    Write-Host (
        'Installed         : {0}' -f
        $completedDriverResult.Data.InstalledCount
    )

    Write-Host (
        'Partial           : {0}' -f
        $completedDriverResult.Data.PartialCount
    )

    Write-Host (
        'Skipped           : {0}' -f
        $completedDriverResult.Data.SkippedCount
    )

    Write-Host (
        'Failed            : {0}' -f
        $completedDriverResult.Data.FailedCount
    )

    Write-Host (
        'Reboot required   : {0}' -f
        $completedDriverResult.Data.RebootRequired
    )

    Write-Host (
        'Drivers detected  : {0}' -f
        $completedDriverResult.Data.DriverCount
    )

    Write-Host (
        'Present drivers   : {0}' -f
        $completedDriverResult.Data.PresentCount
    )

    Write-Host (
        'Scan exit code    : {0}' -f
        $completedDriverResult.Data.ExitCode
    )

    Write-Host (
        'Elapsed time      : {0}' -f
        $driverElapsed.ToString(
            'hh\:mm\:ss'
        )
    )
}

if ($packageResults.Count -gt 0) {

    [int]$updatedCount = 0
    [int]$migratedCount = 0
    [int]$alreadyCurrentCount = 0
    [int]$migrationRequiredCount = 0
    [int]$migrationProtectedCount = 0
    [int]$migrationSkippedCount = 0
    [int]$failedCount = 0

    foreach ($packageResult in $packageResults) {

        switch ($packageResult.Code) {

            'PHX_UPDATED' {
                $updatedCount++
            }

            'PHX_UPDATED_REBOOT_REQUIRED' {
                $updatedCount++
            }

            'PHX_UPDATED_MIGRATED' {
                $migratedCount++
            }

            'PHX_ALREADY_CURRENT' {
                $alreadyCurrentCount++
            }

            'PHX_UPDATE_MIGRATION_REQUIRED' {
                $migrationRequiredCount++
            }

            'PHX_UPDATE_MIGRATION_PROTECTED' {
                $migrationProtectedCount++
            }

            'PHX_UPDATE_MIGRATION_SKIPPED' {
                $migrationSkippedCount++
            }

            default {

                if (-not $packageResult.Success) {
                    $failedCount++
                }
            }
        }
    }

    Write-Host ''
    Write-Host 'Phoenix package summary' `
        -ForegroundColor Cyan

    Write-Host '-----------------------'

    Write-Host (
        'Packages checked : {0}' -f
        $packageResults.Count
    )

    Write-Host (
        'Updated          : {0}' -f
        $updatedCount
    )

    Write-Host (
        'Migrated         : {0}' -f
        $migratedCount
    )

    Write-Host (
        'Already current  : {0}' -f
        $alreadyCurrentCount
    )

    Write-Host (
        'Need migration   : {0}' -f
        $migrationRequiredCount
    )

    Write-Host (
        'Protected        : {0}' -f
        $migrationProtectedCount
    )

    Write-Host (
        'Migration skipped: {0}' -f
        $migrationSkippedCount
    )

    Write-Host (
        'Failed           : {0}' -f
        $failedCount
    )
}

return $elevatedResults
    }

    [datetime]$updateStartedAt = Get-Date

    Write-PhoenixLog `
        -Level Info `
        -Message 'Starting Phoenix update.'

    $results =
    [System.Collections.Generic.List[Result]]::new()

[int]$packageCount = 0

if (-not $SkipDrivers) {

    Write-PhoenixLog `
        -Level Info `
        -Message 'Running Windows Update driver workflow before package updates.'

    [Result]$driverResult =
        Update-PhoenixDriver `
            -ScanOnly:$ScanDriversOnly `
            -Unattended:$Unattended

    if ($null -ne $driverResult) {
        $results.Add($driverResult)
    }
}

    if (-not $SkipPackages) {

        $ProgressPreference = 'Continue'

        Write-Progress `
            -Id 1 `
            -Activity 'Phoenix package update' `
            -Status '0% complete - Discovering updateable packages...' `
            -PercentComplete 0

        [Package[]]$packages = @(
            Get-PhoenixPackages |
                Where-Object {

                    if ($_.Provider -notin $Provider) {
                        return $false
                    }

                    if (
                        [string]::IsNullOrWhiteSpace(
                            $_.Id
                        )
                    ) {
                        return $false
                    }

                    if ($_.Provider -eq 'Chocolatey') {

                        # Do not upgrade Chocolatey while Chocolatey is
                        # being used as the active package provider.
                        return $_.Id -ne 'chocolatey'
                    }

                    if ($_.Provider -eq 'WinGet') {

                        if ($_.Source -ne 'winget') {
                            return $false
                        }

                        if (
                            $_.Id -match
                                '^(ARP|MSIX)\\'
                        ) {
                            return $false
                        }

                        # Exclude frameworks, runtimes, and the package
                        # manager itself from bulk application updates.
                        if (
                            $_.Id -match
                                '^Microsoft\.(DotNet\.Native|UI\.Xaml|VCLibs)' -or
                            $_.Id -match
                                '^Microsoft\.WindowsAppRuntime\.' -or
                            $_.Id -eq
                                'Microsoft.AppInstaller'
                        ) {
                            return $false
                        }

                        return $true
                    }

                    return $false
                } |
                Sort-Object Provider, Id -Unique
        )

        $packageCount = $packages.Count
        [int]$packageIndex = 0

        if ($packageCount -eq 0) {

            Write-PhoenixLog `
                -Level Info `
                -Message 'No updateable packages were found.'

            Write-Progress `
                -Id 1 `
                -Activity 'Phoenix package update' `
                -Completed
        }
        else {

            Write-Progress `
                -Id 1 `
                -Activity 'Phoenix package update' `
                -Status (
                    "0% complete - Preparing $packageCount packages..."
                ) `
                -PercentComplete 0

            foreach ($package in $packages) {

                $packageIndex++

                [int]$startingPercent =
                    [Math]::Floor(
                        (
                            ($packageIndex - 1) /
                            $packageCount
                        ) * 100
                    )

                [string]$packageDisplayName =
                    $package.Name

                if (
                    [string]::IsNullOrWhiteSpace(
                        $packageDisplayName
                    )
                ) {
                    $packageDisplayName =
                        $package.Id
                }

                [datetime]$packageStartedAt =
                    Get-Date

                Write-Progress `
                    -Id 1 `
                    -Activity 'Phoenix package update' `
                    -Status (
                        "{0}% complete - [{1}/{2}] Updating {3}..." -f
                        $startingPercent,
                        $packageIndex,
                        $packageCount,
                        $packageDisplayName
                    ) `
                    -CurrentOperation (
                        "{0}: {1}" -f
                        $package.Provider,
                        $package.Id
                    ) `
                    -PercentComplete $startingPercent

                try {
                    $Host.UI.RawUI.WindowTitle = (
                        'Phoenix Update - {0}% - {1}' -f
                        $startingPercent,
                        $packageDisplayName
                    )
                }
                catch {
                    # Window titles are unavailable in some hosts.
                }

                Write-Host (
                    '[{0,3}%] [{1}/{2}] Updating {3} [{4}] using {5}...' -f
                    $startingPercent,
                    $packageIndex,
                    $packageCount,
                    $packageDisplayName,
                    $package.Id,
                    $package.Provider
                ) -ForegroundColor Cyan

                [hashtable]$updateParameters = @{
                    Package                   = $package
                    AllowMigration            = [bool]$AllowMigration
                    ForceProtectedMigration   = [bool]$ForceProtectedMigration
                    Unattended                = [bool]$Unattended
                    Confirm                   = $false
                }

                if ($PreserveDownloads) {
                    $updateParameters.PreserveDownloads =
                        $true
                }

                [Result]$packageResult =
                    Update-PhoenixPackage `
                        @updateParameters

                [timespan]$elapsed =
                    (Get-Date) - $packageStartedAt

                [int]$completedPercent =
                    [Math]::Floor(
                        (
                            $packageIndex /
                            $packageCount
                        ) * 100
                    )

                [string]$resultCode =
                    'PHX_NO_RESULT'

                if ($null -ne $packageResult) {

                    $resultCode =
                        $packageResult.Code

                    $results.Add(
                        $packageResult
                    )
                }

                Write-Progress `
                    -Id 1 `
                    -Activity 'Phoenix package update' `
                    -Status (
                        "{0}% complete - [{1}/{2}] Finished {3}" -f
                        $completedPercent,
                        $packageIndex,
                        $packageCount,
                        $packageDisplayName
                    ) `
                    -CurrentOperation (
                        "{0} - elapsed {1:mm\:ss}" -f
                        $resultCode,
                        $elapsed
                    ) `
                    -PercentComplete $completedPercent

                try {
                    $Host.UI.RawUI.WindowTitle = (
                        'Phoenix Update - {0}% - {1}' -f
                        $completedPercent,
                        $packageDisplayName
                    )
                }
                catch {
                    # Window titles are unavailable in some hosts.
                }

                Write-Host (
                    '[{0,3}%] [{1}/{2}] Finished {3}: {4} ({5:mm\:ss})' -f
                    $completedPercent,
                    $packageIndex,
                    $packageCount,
                    $packageDisplayName,
                    $resultCode,
                    $elapsed
                ) -ForegroundColor Green
            }

            Write-Progress `
                -Id 1 `
                -Activity 'Phoenix package update' `
                -Status '100% complete - Package updates finished.' `
                -PercentComplete 100

            try {
                $Host.UI.RawUI.WindowTitle =
                    'Phoenix Update - 100% Complete'
            }
            catch {
                # Window titles are unavailable in some hosts.
            }

            Write-Host ''
            Write-Host (
                '[100%] Phoenix package update complete.'
            ) -ForegroundColor Green

            Start-Sleep -Milliseconds 750

            Write-Progress `
                -Id 1 `
                -Activity 'Phoenix package update' `
                -Completed
        }
    }

    if (-not $SkipPackages) {

        [timespan]$updateElapsed =
            (Get-Date) - $updateStartedAt

        $completedResults = @(
            $results.ToArray()
        )

        $completedPackageResults = @(
            $completedResults |
                Where-Object {

                    $stageProperty = $null

                    if ($null -ne $_.Data) {
                        $stageProperty =
                            $_.Data.PSObject.Properties['Stage']
                    }

                    $null -eq $stageProperty -or
                    [string]$stageProperty.Value -ne 'Driver'
                }
        )

        [int]$updatedCount = 0
        [int]$migratedCount = 0
        [int]$alreadyCurrentCount = 0
        [int]$migrationRequiredCount = 0
        [int]$migrationProtectedCount = 0
        [int]$migrationSkippedCount = 0
        [int]$failedCount = 0

        foreach ($completedResult in $completedPackageResults) {

            switch ($completedResult.Code) {

                'PHX_UPDATED' {
                    $updatedCount++
                }

                'PHX_UPDATED_REBOOT_REQUIRED' {
                    $updatedCount++
                }

                'PHX_UPDATED_MIGRATED' {
                    $migratedCount++
                }

                'PHX_ALREADY_CURRENT' {
                    $alreadyCurrentCount++
                }

                'PHX_UPDATE_MIGRATION_REQUIRED' {
                    $migrationRequiredCount++
                }

                'PHX_UPDATE_MIGRATION_PROTECTED' {
                    $migrationProtectedCount++
                }

                'PHX_UPDATE_MIGRATION_SKIPPED' {
                    $migrationSkippedCount++
                }

                default {

                    if (-not $completedResult.Success) {
                        $failedCount++
                    }
                }
            }
        }

        [int]$noResultCount = [Math]::Max(
            0,
            $packageCount - $completedPackageResults.Count
        )

        Write-Host ''
        Write-Host 'Phoenix update summary' `
            -ForegroundColor Cyan

        Write-Host '----------------------'

        Write-Host (
            'Packages checked : {0}' -f
            $packageCount
        )

        Write-Host (
            'Updated          : {0}' -f
            $updatedCount
        )

        Write-Host (
            'Migrated         : {0}' -f
            $migratedCount
        )

        Write-Host (
            'Already current  : {0}' -f
            $alreadyCurrentCount
        )

        Write-Host (
            'Need migration   : {0}' -f
            $migrationRequiredCount
        )

        Write-Host (
            'Protected        : {0}' -f
            $migrationProtectedCount
        )

        Write-Host (
            'Migration skipped: {0}' -f
            $migrationSkippedCount
        )

        Write-Host (
            'Failed           : {0}' -f
            $failedCount
        )

        if ($noResultCount -gt 0) {

            Write-Host (
                'No result        : {0}' -f
                $noResultCount
            )
        }

        Write-Host (
            'Elapsed time     : {0}' -f
            $updateElapsed.ToString(
                'hh\:mm\:ss'
            )
        )
    }

    Write-PhoenixLog `
        -Level Success `
        -Message 'Phoenix update complete.'

    return $results.ToArray()
}
