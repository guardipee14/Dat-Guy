function Write-PhoenixRestoreSummary {

    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Results = @(),

        [Parameter()]
        [AllowEmptyString()]
        [string]$ManifestPath = '',

        [Parameter()]
        [double]$ElapsedSeconds = 0
    )

    $allResults = @($Results)

    $driverResults = @(
        $allResults |
            Where-Object {
                [string](
                    Get-PhoenixPropertyValue `
                        -InputObject $_.Data `
                        -Name 'Stage' `
                        -DefaultValue ''
                ) -eq 'Driver'
            }
    )

    $packageResults = @(
        $allResults |
            Where-Object {
                [string](
                    Get-PhoenixPropertyValue `
                        -InputObject $_.Data `
                        -Name 'Stage' `
                        -DefaultValue ''
                ) -eq 'RestorePackage'
            }
    )

    Write-Host ''
    Write-Host 'Phoenix restore summary' `
        -ForegroundColor Cyan

    Write-Host '-----------------------'

    if (-not [string]::IsNullOrWhiteSpace($ManifestPath)) {
        Write-Host (
            'Manifest          : {0}' -f
            $ManifestPath
        )
    }

    if ($driverResults.Count -gt 0) {

        $driverResult =
            $driverResults |
                Select-Object -Last 1

        Write-Host (
            'Driver result      : {0}' -f
            $driverResult.Code
        )

        Write-Host (
            'Drivers installed  : {0}' -f
            (Get-PhoenixPropertyValue `
                -InputObject $driverResult.Data `
                -Name 'InstalledCount' `
                -DefaultValue 0)
        )

        Write-Host (
            'Driver failures    : {0}' -f
            (Get-PhoenixPropertyValue `
                -InputObject $driverResult.Data `
                -Name 'FailedCount' `
                -DefaultValue 0)
        )

        Write-Host (
            'Reboot required    : {0}' -f
            (Get-PhoenixPropertyValue `
                -InputObject $driverResult.Data `
                -Name 'RebootRequired' `
                -DefaultValue $false)
        )
    }

    [int]$installedCount = @(
        $packageResults |
            Where-Object {
                $_.Code -eq 'PHX_RESTORE_INSTALLED'
            }
    ).Count

    [int]$alreadyInstalledCount = @(
        $packageResults |
            Where-Object {
                $_.Code -eq 'PHX_RESTORE_ALREADY_INSTALLED'
            }
    ).Count

    [int]$skippedCount = @(
        $packageResults |
            Where-Object {
                $_.Code -in @(
                    'PHX_RESTORE_SKIPPED',
                    'PHX_RESTORE_PROVIDER_FILTERED'
                )
            }
    ).Count

    [int]$failedCount = @(
        $packageResults |
            Where-Object {
                -not $_.Success
            }
    ).Count

    Write-Host (
        'Packages in result : {0}' -f
        $packageResults.Count
    )

    Write-Host (
        'Installed          : {0}' -f
        $installedCount
    )

    Write-Host (
        'Already installed  : {0}' -f
        $alreadyInstalledCount
    )

    Write-Host (
        'Skipped            : {0}' -f
        $skippedCount
    )

    Write-Host (
        'Failed             : {0}' -f
        $failedCount
    )

    [timespan]$elapsed =
        [timespan]::FromSeconds($ElapsedSeconds)

    Write-Host (
        'Elapsed time       : {0}' -f
        $elapsed.ToString('hh\:mm\:ss')
    )
}
