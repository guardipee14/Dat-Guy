[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet(
        'Auto',
        'Desktop',
        'Console'
    )]
    [string]$Mode = 'Auto',

    [Parameter()]
    [switch]$NoElevation,

    [Parameter()]
    [switch]$NoFallback,

    [Parameter(DontShow)]
    [switch]$Elevated
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot =
    [IO.Path]::GetFullPath(
        (
            Join-Path `
                $PSScriptRoot `
                '..'
        )
    )

$moduleManifest =
    Join-Path `
        $projectRoot `
        'Phoenix.psd1'

$powerShellPath =
    (Get-Process -Id $PID).Path

$identity =
    [Security.Principal.WindowsIdentity]::GetCurrent()

$principal =
    [Security.Principal.WindowsPrincipal]::new(
        $identity
    )

[bool]$isAdministrator =
    $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

if (
    -not $isAdministrator -and
    -not $NoElevation -and
    -not $Elevated
) {

    [string]$argumentString = (
        '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA ' +
        "-File `"$PSCommandPath`" " +
        "-Mode $Mode -Elevated"
    )

    if ($NoFallback) {
        $argumentString += ' -NoFallback'
    }

    try {
        Start-Process `
            -FilePath $powerShellPath `
            -Verb RunAs `
            -WorkingDirectory $projectRoot `
            -ArgumentList $argumentString `
            -ErrorAction Stop

        return
    }
    catch {
        throw (
            'Phoenix administrator elevation was cancelled or failed: {0}' -f
            $_.Exception.Message
        )
    }
}

Set-Location -LiteralPath $projectRoot

Import-Module `
    -Name $moduleManifest `
    -Force `
    -ErrorAction Stop `
    6>$null

Open-Phoenix `
    -Mode $Mode `
    -NoFallback:$NoFallback
