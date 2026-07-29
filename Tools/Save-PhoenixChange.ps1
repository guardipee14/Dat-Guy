[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'feat',
        'fix',
        'refactor',
        'perf',
        'docs',
        'test',
        'build',
        'chore',
        'security'
    )]
    [string]$Type,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Summary,

    [Parameter()]
    [string]$Scope = 'phoenix',

    [Parameter()]
    [string[]]$Details = @(),

    [Parameter()]
    [switch]$Push,

    [Parameter()]
    [switch]$SkipValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Git {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$AllowFailure
    )

    $output = @(
        & git @Arguments 2>&1
    )

    $exitCode = $LASTEXITCODE

    if (
        -not $AllowFailure -and
        $exitCode -ne 0
    ) {
        throw (
            "Git command failed: git {0}`n{1}" -f
            ($Arguments -join ' '),
            ($output -join [Environment]::NewLine)
        )
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $output
    }
}

function Get-GitValue {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $result = Invoke-Git `
        -Arguments $Arguments `
        -AllowFailure

    if (
        $result.ExitCode -ne 0 -or
        $result.Output.Count -eq 0
    ) {
        return $null
    }

    return [string]$result.Output[0]
}

function Add-UniqueLines {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $existingLines = @()

    if (Test-Path -LiteralPath $Path) {
        $existingLines = @(
            Get-Content -LiteralPath $Path
        )
    }

    $updatedLines =
        [System.Collections.Generic.List[string]]::new()

    foreach ($line in $existingLines) {
        $updatedLines.Add($line)
    }

    foreach ($line in $Lines) {

        if ($updatedLines -notcontains $line) {
            $updatedLines.Add($line)
        }
    }

    Set-Content `
        -LiteralPath $Path `
        -Value $updatedLines `
        -Encoding UTF8
}

function Initialize-PhoenixGitIgnore {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $gitIgnorePath =
        Join-Path $RepositoryRoot '.gitignore'

    $legacyGitIgnorePath =
        Join-Path $RepositoryRoot '.gitignore.txt'

    if (
        -not (Test-Path -LiteralPath $gitIgnorePath) -and
        (Test-Path -LiteralPath $legacyGitIgnorePath)
    ) {
        Move-Item `
            -LiteralPath $legacyGitIgnorePath `
            -Destination $gitIgnorePath
    }

    $ignoreLines = @(
        '',
        '# Phoenix runtime and generated local data',
        '/Logs/',
        '/Cache/',
        '/Archive/',
        '/Build/MigrationBackups/',
        '/-ErrorAction',
        'ElevationProbe.*',
        '*.log',
        '*.clixml',
        '*.tmp',
        '*.bak',
        '*.zip',
        '*-output.txt',
        '',
        '# Editor and build metadata',
        '/.vs/',
        '/.vscode/',
        '/bin/',
        '/obj/',
        '*.user'
    )

    Add-UniqueLines `
        -Path $gitIgnorePath `
        -Lines $ignoreLines
}

function Initialize-PhoenixChangelog {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogPath
    )

    $needsTemplate = $true

    if (Test-Path -LiteralPath $ChangelogPath) {
        $rawContent = Get-Content `
            -LiteralPath $ChangelogPath `
            -Raw

        $needsTemplate =
            [string]::IsNullOrWhiteSpace($rawContent)
    }

    if (-not $needsTemplate) {
        return
    }

    $template = @(
        '# Changelog',
        '',
        'All notable changes to Phoenix are documented in this file.',
        '',
        '## [Unreleased]',
        ''
    )

    Set-Content `
        -LiteralPath $ChangelogPath `
        -Value $template `
        -Encoding UTF8
}

function Add-PhoenixChangelogEntry {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogPath,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Entry,

        [Parameter()]
        [string[]]$EntryDetails = @()
    )

    Initialize-PhoenixChangelog `
        -ChangelogPath $ChangelogPath

    $lines =
        [System.Collections.Generic.List[string]]::new()

    foreach (
        $line in @(
            Get-Content -LiteralPath $ChangelogPath
        )
    ) {
        $lines.Add($line)
    }

    $unreleasedIndex = -1

    for ($index = 0; $index -lt $lines.Count; $index++) {

        if ($lines[$index] -eq '## [Unreleased]') {
            $unreleasedIndex = $index
            break
        }
    }

    if ($unreleasedIndex -lt 0) {

        $lines.Insert(0, '')
        $lines.Insert(0, '## [Unreleased]')

        $unreleasedIndex = 0
    }

    $nextReleaseIndex = $lines.Count

    for (
        $index = $unreleasedIndex + 1;
        $index -lt $lines.Count;
        $index++
    ) {

        if ($lines[$index] -match '^##\s') {
            $nextReleaseIndex = $index
            break
        }
    }

    $categoryHeading = "### $Category"
    $categoryIndex = -1

    for (
        $index = $unreleasedIndex + 1;
        $index -lt $nextReleaseIndex;
        $index++
    ) {

        if ($lines[$index] -eq $categoryHeading) {
            $categoryIndex = $index
            break
        }
    }

    $bullet = "- $Entry"

    for (
        $index = $unreleasedIndex + 1;
        $index -lt $nextReleaseIndex;
        $index++
    ) {

        if ($lines[$index] -eq $bullet) {
            Write-Host 'The changelog already contains this entry.' `
                -ForegroundColor DarkYellow

            return
        }
    }

    if ($categoryIndex -lt 0) {

        $insertIndex = $unreleasedIndex + 1

        $lines.Insert($insertIndex, '')
        $lines.Insert($insertIndex + 1, $categoryHeading)
        $lines.Insert($insertIndex + 2, $bullet)

        $detailInsertIndex = $insertIndex + 3
    }
    else {

        $insertIndex = $categoryIndex + 1
        $lines.Insert($insertIndex, $bullet)

        $detailInsertIndex = $insertIndex + 1
    }

    foreach ($detail in $EntryDetails) {

        if (-not [string]::IsNullOrWhiteSpace($detail)) {
            $lines.Insert(
                $detailInsertIndex,
                "  - $detail"
            )

            $detailInsertIndex++
        }
    }

    Set-Content `
        -LiteralPath $ChangelogPath `
        -Value $lines `
        -Encoding UTF8
}

function Test-PhoenixModuleImport {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $manifestPath =
        Join-Path $RepositoryRoot 'Phoenix.psd1'

    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Phoenix manifest was not found: $manifestPath"
    }

    $powerShellPath = $null

    try {
        $powerShellPath =
            (Get-Process -Id $PID -ErrorAction Stop).Path
    }
    catch {
        $powerShellPath = $null
    }

    if ([string]::IsNullOrWhiteSpace($powerShellPath)) {

        $powerShellCommand =
            Get-Command pwsh, powershell `
                -ErrorAction SilentlyContinue |
                Select-Object -First 1

        if ($null -ne $powerShellCommand) {
            $powerShellPath = $powerShellCommand.Source
        }
    }

    if ([string]::IsNullOrWhiteSpace($powerShellPath)) {
        throw 'Unable to locate a PowerShell executable for module validation.'
    }

    $validationScriptPath =
        Join-Path `
            ([System.IO.Path]::GetTempPath()) `
            ('Phoenix-GitValidation-{0}.ps1' -f [guid]::NewGuid().ToString('N'))

    $validationScript = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
Import-Module -Name $ManifestPath -Force -ErrorAction Stop
'@

    Set-Content `
        -LiteralPath $validationScriptPath `
        -Value $validationScript `
        -Encoding UTF8

    try {

        $validationOutput = @(
            & $powerShellPath `
                -NoLogo `
                -NoProfile `
                -NonInteractive `
                -File $validationScriptPath `
                -ManifestPath $manifestPath `
                2>&1
        )

        $validationExitCode = $LASTEXITCODE
    }
    finally {

        Remove-Item `
            -LiteralPath $validationScriptPath `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if ($validationExitCode -ne 0) {

        $message = @(
            'Phoenix module import validation failed.',
            ($validationOutput -join [Environment]::NewLine)
        ) -join [Environment]::NewLine

        throw $message
    }

    Write-Host 'Phoenix module import validation passed.' `
        -ForegroundColor Green
}

function Test-ChangedPowerShellFiles {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $changedFiles =
        [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase
        )

    $trackedChanges = Invoke-Git `
        -Arguments @(
            'diff',
            '--name-only',
            '--diff-filter=ACMRTUXB'
        )

    foreach ($path in $trackedChanges.Output) {

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$changedFiles.Add([string]$path)
        }
    }

    $stagedChanges = Invoke-Git `
        -Arguments @(
            'diff',
            '--cached',
            '--name-only',
            '--diff-filter=ACMRTUXB'
        )

    foreach ($path in $stagedChanges.Output) {

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$changedFiles.Add([string]$path)
        }
    }

    $untrackedChanges = Invoke-Git `
        -Arguments @(
            'ls-files',
            '--others',
            '--exclude-standard'
        )

    foreach ($path in $untrackedChanges.Output) {

        if (-not [string]::IsNullOrWhiteSpace($path)) {
            [void]$changedFiles.Add([string]$path)
        }
    }

    $parseFailures =
        [System.Collections.Generic.List[object]]::new()

    foreach ($relativePath in $changedFiles) {

        $extension =
            [System.IO.Path]::GetExtension($relativePath)

        if ($extension -notin @('.ps1', '.psm1', '.psd1')) {
            continue
        }

        $normalizedPath =
            $relativePath.Replace('\', '/')

        # Phoenix class source and method files are compilation fragments.
        # They are intentionally not valid when parsed one at a time.
        # The assembled class module is validated by importing Phoenix.psd1
        # in a clean child PowerShell process below.
        if ($normalizedPath.StartsWith(
            'Classes/',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            continue
        }

        $fullPath =
            Join-Path $RepositoryRoot $relativePath

        if (-not (Test-Path -LiteralPath $fullPath)) {
            continue
        }

        $tokens = $null
        $parseErrors = $null

        [System.Management.Automation.Language.Parser]::ParseFile(
            $fullPath,
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null

        foreach ($parseError in @($parseErrors)) {

            $parseFailures.Add(
                [pscustomobject]@{
                    File    = $relativePath
                    Line    = $parseError.Extent.StartLineNumber
                    Message = $parseError.Message
                }
            )
        }
    }

    if ($parseFailures.Count -gt 0) {

        $parseFailures |
            Format-Table -AutoSize |
            Out-Host

        throw 'PowerShell syntax validation failed. No commit was created.'
    }

    Write-Host 'Standalone PowerShell syntax validation passed.' `
        -ForegroundColor Green

    Test-PhoenixModuleImport `
        -RepositoryRoot $RepositoryRoot
}

$gitCommand = Get-Command git `
    -ErrorAction SilentlyContinue

if ($null -eq $gitCommand) {
    throw 'Git was not found. Install Git for Windows and reopen PowerShell.'
}

$repositoryRoot = Get-GitValue `
    -Arguments @(
        'rev-parse',
        '--show-toplevel'
    )

if ([string]::IsNullOrWhiteSpace($repositoryRoot)) {
    throw 'Run this script from inside the Phoenix Git repository.'
}

$repositoryRoot = $repositoryRoot.Trim()
Push-Location $repositoryRoot

try {

    $gitUserName = Get-GitValue `
        -Arguments @(
            'config',
            '--get',
            'user.name'
        )

    $gitUserEmail = Get-GitValue `
        -Arguments @(
            'config',
            '--get',
            'user.email'
        )

    if (
        [string]::IsNullOrWhiteSpace($gitUserName) -or
        [string]::IsNullOrWhiteSpace($gitUserEmail)
    ) {
        throw @'
Git does not have an author name and email configured.
Run these commands once, using your own information:

    git config --global user.name "Your Name"
    git config --global user.email "you@example.com"
'@
    }

    Initialize-PhoenixGitIgnore `
        -RepositoryRoot $repositoryRoot

    $categoryMap = @{
        feat     = 'Added'
        fix      = 'Fixed'
        refactor = 'Changed'
        perf     = 'Changed'
        docs     = 'Changed'
        test     = 'Changed'
        build    = 'Changed'
        chore    = 'Changed'
        security = 'Security'
    }

    $changelogPath =
        Join-Path $repositoryRoot 'CHANGELOG.md'

    Add-PhoenixChangelogEntry `
        -ChangelogPath $changelogPath `
        -Category $categoryMap[$Type] `
        -Entry $Summary `
        -EntryDetails $Details

    if (-not $SkipValidation) {
        Test-ChangedPowerShellFiles `
            -RepositoryRoot $repositoryRoot
    }

    Invoke-Git `
        -Arguments @(
            'add',
            '--all'
        ) |
        Out-Null

    $stagedNames = Invoke-Git `
        -Arguments @(
            'diff',
            '--cached',
            '--name-status'
        )

    if ($stagedNames.Output.Count -eq 0) {
        Write-Host 'There are no changes to commit.' `
            -ForegroundColor Yellow

        return
    }

    Write-Host ''
    Write-Host 'Files staged for commit:' `
        -ForegroundColor Cyan

    $stagedNames.Output |
        ForEach-Object {
            Write-Host "  $_"
        }

    $commitMessage = "$Type"

    if (-not [string]::IsNullOrWhiteSpace($Scope)) {
        $commitMessage += "($Scope)"
    }

    $commitMessage += ": $Summary"

    Write-Host ''
    Write-Host "Creating commit: $commitMessage" `
        -ForegroundColor Cyan

    Invoke-Git `
        -Arguments @(
            'commit',
            '-m',
            $commitMessage
        ) |
        Select-Object -ExpandProperty Output |
        ForEach-Object {
            Write-Host $_
        }

    $commitHash = Get-GitValue `
        -Arguments @(
            'rev-parse',
            '--short',
            'HEAD'
        )

    Write-Host ''
    Write-Host (
        'Phoenix commit created successfully: {0}' -f
        $commitHash
    ) -ForegroundColor Green

    if ($Push) {

        $branch = Get-GitValue `
            -Arguments @(
                'branch',
                '--show-current'
            )

        $upstream = Get-GitValue `
            -Arguments @(
                'rev-parse',
                '--abbrev-ref',
                '--symbolic-full-name',
                '@{u}'
            )

        if ([string]::IsNullOrWhiteSpace($upstream)) {

            $origin = Get-GitValue `
                -Arguments @(
                    'remote',
                    'get-url',
                    'origin'
                )

            if ([string]::IsNullOrWhiteSpace($origin)) {
                throw 'No Git upstream or origin remote is configured.'
            }

            Invoke-Git `
                -Arguments @(
                    'push',
                    '--set-upstream',
                    'origin',
                    $branch
                ) |
                Select-Object -ExpandProperty Output |
                ForEach-Object {
                    Write-Host $_
                }
        }
        else {

            Invoke-Git `
                -Arguments @(
                    'push'
                ) |
                Select-Object -ExpandProperty Output |
                ForEach-Object {
                    Write-Host $_
                }
        }

        Write-Host 'The commit was pushed successfully.' `
            -ForegroundColor Green
    }
}
finally {
    Pop-Location
}