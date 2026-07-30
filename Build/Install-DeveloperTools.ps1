$taskPath =
    Join-Path `
        $PSScriptRoot `
        'Tasks\Install-PhoenixDeveloperTools.ps1'

if (-not (Test-Path -LiteralPath $taskPath)) {
    throw "Phoenix developer-tools task was not found: $taskPath"
}

. $taskPath