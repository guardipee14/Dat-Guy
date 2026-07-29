[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = 'C:\Dev\PhoenixDeploy'

$testScript = Join-Path `
    $projectRoot `
    'Test-WinGetRealCleanup.ps1'

$logPath = Join-Path `
    $projectRoot `
    'Test-WinGetRealCleanup-output.txt'

@(
    'Phoenix real WinGet test'
    "Started: $(Get-Date -Format o)"
    ''
) | Set-Content `
    -LiteralPath $logPath `
    -Encoding utf8

if (-not (Test-Path -LiteralPath $testScript)) {

    "Test script not found: $testScript" |
        Add-Content `
            -LiteralPath $logPath

    exit 1
}

try {

    & $testScript *>&1 |
        Tee-Object `
            -FilePath $logPath `
            -Append
}
catch {

    @(
        ''
        'Unhandled test exception:'
        ($_ | Format-List * -Force | Out-String)
    ) | Add-Content `
        -LiteralPath $logPath

    exit 1
}
