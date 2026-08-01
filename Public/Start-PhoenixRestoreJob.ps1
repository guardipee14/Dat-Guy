using module '..\Classes\Phoenix.Classes.psm1'

function Start-PhoenixRestoreJob {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    [OutputType([PhoenixBackgroundOperation])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter()]
        [switch]$SkipDrivers,

        [Parameter()]
        [switch]$SkipPackages,

        [Parameter()]
        [ValidateSet(
            'WinGet',
            'Chocolatey',
            'Scoop',
            'PowerShell Gallery',
            'NuGet'
        )]
        [string[]]$Provider = @(
            'WinGet',
            'Chocolatey',
            'Scoop',
            'PowerShell Gallery',
            'NuGet'
        ),

        [Parameter()]
        [switch]$ReinstallInstalled,

        [Parameter()]
        [switch]$StopOnError,

        [Parameter()]
        [switch]$Unattended,

        [Parameter(DontShow)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot = (
            Split-Path `
                -Path $PSScriptRoot `
                -Parent
        ),

        [Parameter(DontShow)]
        [AllowNull()]
        [string]$WorkerPath
    )

    if ($SkipDrivers -and $SkipPackages) {
        throw (
            'Start-PhoenixRestoreJob cannot skip both drivers and packages.'
        )
    }

    [string]$resolvedManifestPath = (
        Resolve-Path `
            -LiteralPath $ManifestPath `
            -ErrorAction Stop
    ).Path

    if (-not $PSCmdlet.ShouldProcess(
        $resolvedManifestPath,
        'Start a cancellable Phoenix restore background job'
    )) {
        return
    }

    $operation =
        New-PhoenixBackgroundOperation `
            -Action 'RestoreAction' `
            -Parameters ([pscustomobject][ordered]@{
                ManifestPath       = $resolvedManifestPath
                SkipDrivers       = [bool]$SkipDrivers
                SkipPackages      = [bool]$SkipPackages
                Provider          = @($Provider)
                ReinstallInstalled = [bool]$ReinstallInstalled
                StopOnError       = [bool]$StopOnError
                Unattended        = [bool]$Unattended
            }) `
            -Component 'Restore' `
            -Description (
                'Restoring Phoenix drivers and applications from manifest...'
            ) `
            -Completion {} `
            -ProjectRoot $ProjectRoot

    try {
        $startParameters = @{
            Operation   = $operation
            ProjectRoot = $ProjectRoot
        }

        if (-not [string]::IsNullOrWhiteSpace($WorkerPath)) {
            $startParameters.WorkerPath = $WorkerPath
        }

        return (
            Start-PhoenixBackgroundOperation `
                @startParameters
        )
    }
    catch {
        $null =
            Remove-PhoenixBackgroundOperation `
                -Operation $operation

        throw
    }
}
