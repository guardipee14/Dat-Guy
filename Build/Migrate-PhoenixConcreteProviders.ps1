[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot '..'
        )
    ).Path,

    [Parameter()]
    [ValidateSet(
        'WinGetProvider',
        'ChocolateyProvider'
    )]
    [string[]]$ProviderName = @(
        'WinGetProvider',
        'ChocolateyProvider'
    ),

    [Parameter()]
    [switch]$MigrateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$providersRoot = Join-Path `
    $ProjectRoot `
    'Classes\20-Providers'

$buildScript = Join-Path `
    $ProjectRoot `
    'Build\Build-PhoenixClasses.ps1'

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$backupRoot = Join-Path `
    $ProjectRoot `
    "Build\MigrationBackups\ConcreteProviders-$timestamp"

$markerStates = @{}
$enabledByThisRun =
    [System.Collections.Generic.List[string]]::new()

function Get-PhoenixSyntaxErrors {

    param(
        [Parameter(Mandatory)]
        [object[]]$ParseErrors
    )

    return @(
        $ParseErrors |
            Where-Object {
                $_.Message -notlike 'Unable to find type*'
            }
    )
}

function Get-PhoenixMethodRelativePath {

    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Language.FunctionMemberAst]$Method,

        [Parameter(Mandatory)]
        [hashtable]$UsedTargets
    )

    [string]$baseRelativePath = switch ($Method.Name) {

        'TestAvailable' {
            'Methods\TestAvailable.ps1'
            break
        }

        'InstallProvider' {
            'Methods\InstallProvider.ps1'
            break
        }

        'UpdateProvider' {
            'Methods\UpdateProvider.ps1'
            break
        }

        'GetInstalledPackages' {
            'Methods\GetInstalledPackages.ps1'
            break
        }

        'SearchPackage' {
            'Methods\SearchPackage.ps1'
            break
        }

        'InstallPackageSilent' {
            'Methods\InstallPackageSilent.ps1'
            break
        }

        'InstallPackageInteractive' {
            'Methods\InstallPackageInteractive.ps1'
            break
        }

        'RepairPackageSilent' {
            'Methods\RepairPackageSilent.ps1'
            break
        }

        'RepairPackageInteractive' {
            'Methods\RepairPackageInteractive.ps1'
            break
        }

        'UpdatePackage' {
            'Methods\UpdatePackage.ps1'
            break
        }

        'RemovePackage' {
            'Methods\RemovePackage.ps1'
            break
        }

        default {

            [string]$safeMethodName = [regex]::Replace(
                $Method.Name,
                '[^a-zA-Z0-9._-]',
                '_'
            )

            "Methods\Helpers\$safeMethodName.ps1"
        }
    }

    if (-not $UsedTargets.ContainsKey($baseRelativePath)) {

        $UsedTargets[$baseRelativePath] = 1

        return $baseRelativePath
    }

    [string]$directory = Split-Path `
        $baseRelativePath `
        -Parent

    [string]$fileNameWithoutExtension =
        [IO.Path]::GetFileNameWithoutExtension(
            $baseRelativePath
        )

    [int]$parameterCount =
        $Method.Parameters.Count

    [string]$candidate = Join-Path `
        $directory `
        (
            '{0}-{1}Parameters.ps1' -f
            $fileNameWithoutExtension,
            $parameterCount
        )

    [int]$duplicateIndex = 2

    while ($UsedTargets.ContainsKey($candidate)) {

        $candidate = Join-Path `
            $directory `
            (
                '{0}-{1}Parameters-{2}.ps1' -f
                $fileNameWithoutExtension,
                $parameterCount,
                $duplicateIndex
            )

        $duplicateIndex++
    }

    $UsedTargets[$candidate] = 1

    return $candidate
}

function Write-PhoenixTextFile {

    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $directory = Split-Path `
        $Path `
        -Parent

    $null = New-Item `
        -ItemType Directory `
        -Path $directory `
        -Force

    [IO.File]::WriteAllLines(
        $Path,
        $Lines,
        [Text.UTF8Encoding]::new($true)
    )
}

function Test-PhoenixCompositeProvider {

    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [Parameter(Mandatory)]
        [string]$HeaderPath,

        [Parameter(Mandatory)]
        [string[]]$MethodPaths,

        [Parameter(Mandatory)]
        [string]$FooterPath
    )

    $temporaryPath = Join-Path `
        $env:TEMP `
        (
            '{0}-composite-{1}.ps1' -f
            $ProviderName,
            [guid]::NewGuid().ToString('N')
        )

    try {

        $combinedLines =
            [System.Collections.Generic.List[string]]::new()

        foreach ($line in [IO.File]::ReadAllLines($HeaderPath)) {
            $combinedLines.Add($line)
        }

        $combinedLines.Add('')

        foreach ($methodPath in ($MethodPaths | Sort-Object)) {

            foreach ($line in [IO.File]::ReadAllLines($methodPath)) {
                $combinedLines.Add($line)
            }

            $combinedLines.Add('')
        }

        foreach ($line in [IO.File]::ReadAllLines($FooterPath)) {
            $combinedLines.Add($line)
        }

        [IO.File]::WriteAllLines(
            $temporaryPath,
            $combinedLines,
            [Text.UTF8Encoding]::new($true)
        )

        $tokens = $null
        $parseErrors = $null

        [System.Management.Automation.Language.Parser]::ParseFile(
            $temporaryPath,
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null

        $syntaxErrors = @(
            Get-PhoenixSyntaxErrors `
                -ParseErrors $parseErrors
        )

        if ($syntaxErrors.Count -gt 0) {

            Write-Host ''
            Write-Host (
                "$ProviderName composite validation failed:"
            ) -ForegroundColor Red

            $syntaxErrors |
                Select-Object `
                    @{Name = 'Line'; Expression = {
                        $_.Extent.StartLineNumber
                    }},
                    Message |
                Format-Table -AutoSize -Wrap

            throw (
                "$ProviderName composite fragments contain syntax errors."
            )
        }
    }
    finally {

        Remove-Item `
            -LiteralPath $temporaryPath `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Convert-PhoenixProviderToFragments {

    param(
        [Parameter(Mandatory)]
        [string]$ProviderName
    )

    $sourcePath = Join-Path `
        $providersRoot `
        "$ProviderName.ps1"

    $targetRoot = Join-Path `
        $providersRoot `
        $ProviderName

    $headerPath = Join-Path `
        $targetRoot `
        "$ProviderName.Header.ps1"

    $methodsRoot = Join-Path `
        $targetRoot `
        'Methods'

    $footerPath = Join-Path `
        $targetRoot `
        "$ProviderName.Footer.ps1"

    $markerPath = Join-Path `
        $targetRoot `
        '.composite-ready'

    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Legacy provider source not found: $sourcePath"
    }

    if (-not (Test-Path -LiteralPath $targetRoot)) {
        throw (
            "Provider scaffold not found: $targetRoot"
        )
    }

    $markerStates[$ProviderName] =
        Test-Path -LiteralPath $markerPath

    Write-Host ''
    Write-Host (
        "Migrating $ProviderName..."
    ) -ForegroundColor Cyan

    $tokens = $null
    $parseErrors = $null

    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $sourcePath,
        [ref]$tokens,
        [ref]$parseErrors
    )

    $syntaxErrors = @(
        Get-PhoenixSyntaxErrors `
            -ParseErrors $parseErrors
    )

    if ($syntaxErrors.Count -gt 0) {

        Write-Host ''
        Write-Host (
            "$ProviderName legacy source contains syntax errors:"
        ) -ForegroundColor Red

        $syntaxErrors |
            Select-Object `
                @{Name = 'Line'; Expression = {
                    $_.Extent.StartLineNumber
                }},
                Message |
            Format-Table -AutoSize -Wrap

        throw (
            "$ProviderName must parse cleanly before migration."
        )
    }

    $typeWarnings = @(
        $parseErrors |
            Where-Object {
                $_.Message -like 'Unable to find type*'
            }
    )

    if ($typeWarnings.Count -gt 0) {

        Write-Host (
            "Ignoring $($typeWarnings.Count) expected " +
            'standalone type-resolution warning(s).'
        ) -ForegroundColor DarkYellow
    }

    $classAst = $ast.FindAll(
        {
            param($node)

            $node -is [System.Management.Automation.Language.TypeDefinitionAst] -and
            $node.Name -eq $ProviderName
        },
        $true
    ) |
        Select-Object -First 1

    if ($null -eq $classAst) {
        throw "Class '$ProviderName' was not found in $sourcePath"
    }

    $properties = @(
        $classAst.Members |
            Where-Object {
                $_ -is [System.Management.Automation.Language.PropertyMemberAst]
            }
    )

    $constructors = @(
        $classAst.Members |
            Where-Object {
                $_ -is [System.Management.Automation.Language.FunctionMemberAst] -and
                $_.Name -eq $ProviderName
            }
    )

    $methods = @(
        $classAst.Members |
            Where-Object {
                $_ -is [System.Management.Automation.Language.FunctionMemberAst] -and
                $_.Name -ne $ProviderName
            }
    )

    if ($constructors.Count -eq 0) {
        throw "$ProviderName does not contain a constructor."
    }

    $providerBackupRoot = Join-Path `
        $backupRoot `
        $ProviderName

    $null = New-Item `
        -ItemType Directory `
        -Path $providerBackupRoot `
        -Force

    Copy-Item `
        -LiteralPath $sourcePath `
        -Destination (
            Join-Path `
                $providerBackupRoot `
                "$ProviderName.legacy.ps1"
        ) `
        -Force

    if (Test-Path -LiteralPath $targetRoot) {

        Copy-Item `
            -LiteralPath $targetRoot `
            -Destination (
                Join-Path `
                    $providerBackupRoot `
                    "$ProviderName.fragments-before"
            ) `
            -Recurse `
            -Force
    }

    if (Test-Path -LiteralPath $methodsRoot) {

        Remove-Item `
            -LiteralPath $methodsRoot `
            -Recurse `
            -Force
    }

    $null = New-Item `
        -ItemType Directory `
        -Path $methodsRoot `
        -Force

    [string[]]$baseTypeNames = @(
        $classAst.BaseTypes |
            ForEach-Object {
                $_.TypeName.FullName
            }
    )

    [string]$classDeclaration = if (
        $baseTypeNames.Count -gt 0
    ) {

        'class {0} : {1} {{' -f
            $ProviderName,
            ($baseTypeNames -join ', ')
    }
    else {

        'class {0} {{' -f
            $ProviderName
    }

    $headerLines =
        [System.Collections.Generic.List[string]]::new()

    $headerLines.Add(
        '##########################################################'
    )

    $headerLines.Add(
        "## $ProviderName composite class header"
    )

    $headerLines.Add(
        '## Generated from the validated legacy provider'
    )

    $headerLines.Add(
        '##########################################################'
    )

    $headerLines.Add('')
    $headerLines.Add($classDeclaration)
    $headerLines.Add('')

    if ($properties.Count -gt 0) {

        $headerLines.Add(
            '    ##########################################################'
        )

        $headerLines.Add(
            '    ## Properties'
        )

        $headerLines.Add(
            '    ##########################################################'
        )

        $headerLines.Add('')

        foreach ($property in $properties) {
            $headerLines.Add(
                $property.Extent.Text.TrimEnd()
            )
        }

        $headerLines.Add('')
    }

    $headerLines.Add(
        '    ##########################################################'
    )

    $headerLines.Add(
        '    ## Constructor'
    )

    $headerLines.Add(
        '    ##########################################################'
    )

    $headerLines.Add('')

    foreach ($constructor in $constructors) {

        $headerLines.Add(
            $constructor.Extent.Text.TrimEnd()
        )

        $headerLines.Add('')
    }

    Write-PhoenixTextFile `
        -Path $headerPath `
        -Lines $headerLines.ToArray()

    $usedTargets = @{}

    $methodPaths =
        [System.Collections.Generic.List[string]]::new()

    foreach ($method in $methods) {

        [string]$relativeMethodPath =
            Get-PhoenixMethodRelativePath `
                -Method $method `
                -UsedTargets $usedTargets

        $methodPath = Join-Path `
            $targetRoot `
            $relativeMethodPath

        $fragmentLines = @(
            '##########################################################'
            "## Method: $($method.Name)"
            (
                '## Legacy source line: {0}' -f
                $method.Extent.StartLineNumber
            )
            '##########################################################'
            ''
            $method.Extent.Text.TrimEnd()
            ''
        )

        Write-PhoenixTextFile `
            -Path $methodPath `
            -Lines $fragmentLines

        $methodPaths.Add($methodPath)
    }

    Write-PhoenixTextFile `
        -Path $footerPath `
        -Lines @(
            '##########################################################'
            "## $ProviderName composite class footer"
            '##########################################################'
            ''
            '}'
        )

    Test-PhoenixCompositeProvider `
        -ProviderName $ProviderName `
        -HeaderPath $headerPath `
        -MethodPaths $methodPaths.ToArray() `
        -FooterPath $footerPath

    Write-Host (
        "$ProviderName migration validated."
    ) -ForegroundColor Green

    Write-Host (
        "Methods migrated: $($methods.Count)"
    )

    return [pscustomobject]@{
        ProviderName = $ProviderName
        TargetRoot = $targetRoot
        MarkerPath = $markerPath
        MethodCount = $methods.Count
    }
}

if (-not (Test-Path -LiteralPath $buildScript)) {
    throw "Build script not found: $buildScript"
}

$null = New-Item `
    -ItemType Directory `
    -Path $backupRoot `
    -Force

$migrationResults =
    [System.Collections.Generic.List[object]]::new()

try {

    foreach ($name in $ProviderName) {

        $migrationResults.Add(
            (
                Convert-PhoenixProviderToFragments `
                    -ProviderName $name
            )
        )
    }

    if ($MigrateOnly) {

        Write-Host ''
        Write-Host (
            'Migration completed without enabling providers.'
        ) -ForegroundColor Green

        Write-Host "Backup: $backupRoot"

        return
    }

    foreach ($migrationResult in $migrationResults) {

        if (
            -not $markerStates[
                $migrationResult.ProviderName
            ]
        ) {

            Set-Content `
                -LiteralPath $migrationResult.MarkerPath `
                -Value (
                    "Enabled $(Get-Date -Format o)"
                ) `
                -Encoding utf8

            $enabledByThisRun.Add(
                $migrationResult.ProviderName
            )
        }
    }

    Write-Host ''
    Write-Host (
        'Building Phoenix with the migrated providers...'
    ) -ForegroundColor Cyan

    & $buildScript

    Write-Host ''
    Write-Host (
        'WinGetProvider and ChocolateyProvider migration completed.'
    ) -ForegroundColor Green

    Write-Host "Backup: $backupRoot"

    Write-Host ''
    Write-Host 'Active provider modes:' `
        -ForegroundColor Cyan

    $providerModes = @(
        foreach ($name in @(
            'PhoenixProvider'
            'WinGetProvider'
            'ChocolateyProvider'
        )) {

            $markerPath = Join-Path `
                $providersRoot `
                "$name\.composite-ready"

            [pscustomobject]@{
                Provider = $name
                Mode = if (
                    Test-Path -LiteralPath $markerPath
                ) {
                    'Composite'
                }
                else {
                    'Legacy'
                }
            }
        }
    )

    $providerModes |
        Format-Table -AutoSize
}
catch {

    Write-Host ''
    Write-Host (
        'Migration or composite build failed.'
    ) -ForegroundColor Red

    if ($enabledByThisRun.Count -gt 0) {

        Write-Host (
            'Restoring newly enabled providers to legacy mode...'
        ) -ForegroundColor Yellow

        foreach ($name in $enabledByThisRun) {

            $markerPath = Join-Path `
                $providersRoot `
                "$name\.composite-ready"

            Remove-Item `
                -LiteralPath $markerPath `
                -Force `
                -ErrorAction SilentlyContinue
        }

        try {

            Write-Host (
                'Rebuilding the last stable provider configuration...'
            ) -ForegroundColor Yellow

            & $buildScript
        }
        catch {

            Write-Warning (
                'The rollback build also failed. ' +
                'Use the migration backup for recovery.'
            )
        }
    }

    Write-Host "Backup: $backupRoot"

    throw
}