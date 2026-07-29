[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ProjectRoot = (
        Resolve-Path (
            Join-Path $PSScriptRoot '..'
        )
    ).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$providerName = 'PhoenixProvider'

$sourcePath = Join-Path `
    $ProjectRoot `
    'Classes\20-Providers\PhoenixProvider.ps1'

$targetRoot = Join-Path `
    $ProjectRoot `
    'Classes\20-Providers\PhoenixProvider'

$headerPath = Join-Path `
    $targetRoot `
    'PhoenixProvider.Header.ps1'

$footerPath = Join-Path `
    $targetRoot `
    'PhoenixProvider.Footer.ps1'

$methodsRoot = Join-Path `
    $targetRoot `
    'Methods'

$backupRoot = Join-Path `
    $ProjectRoot `
    (
        'Build\MigrationBackups\PhoenixProvider-{0}' -f
        (Get-Date -Format 'yyyyMMdd-HHmmss')
    )

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Legacy provider source not found: $sourcePath"
}

if (-not (Test-Path -LiteralPath $targetRoot)) {
    throw (
        "Composite provider scaffold not found: $targetRoot`n" +
        'Run New-PhoenixProviderStructure.ps1 first.'
    )
}

Write-Host ''
Write-Host 'Migrating PhoenixProvider into fragments...' `
    -ForegroundColor Cyan

Write-Host "Source: $sourcePath"
Write-Host "Target: $targetRoot"
Write-Host ''

##########################################################
## Parse the working legacy class
##########################################################

$tokens = $null
$parseErrors = $null

$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $sourcePath,
    [ref]$tokens,
    [ref]$parseErrors
)

$syntaxErrors = @(
    $parseErrors |
        Where-Object {
            $_.Message -notlike 'Unable to find type*'
        }
)

if ($syntaxErrors.Count -gt 0) {

    $syntaxErrors |
        Select-Object `
            @{Name = 'Line'; Expression = {
                $_.Extent.StartLineNumber
            }},
            Message |
        Format-Table -AutoSize -Wrap

    throw (
        'The legacy PhoenixProvider contains syntax errors.'
    )
}

$typeResolutionWarnings = @(
    $parseErrors |
        Where-Object {
            $_.Message -like 'Unable to find type*'
        }
)

if ($typeResolutionWarnings.Count -gt 0) {

    Write-Host (
        "Ignoring $($typeResolutionWarnings.Count) expected " +
        'standalone type-resolution warning(s).'
    ) -ForegroundColor DarkYellow
}

$classAst = $ast.FindAll(
    {
        param($node)

        $node -is
            [System.Management.Automation.Language.TypeDefinitionAst] -and
        $node.Name -eq 'PhoenixProvider'
    },
    $true
) |
    Select-Object -First 1

if ($null -eq $classAst) {
    throw "Class '$providerName' was not found in $sourcePath"
}

$propertyMembers = @(
    $classAst.Members |
        Where-Object {
            $_ -is
                [System.Management.Automation.Language.PropertyMemberAst]
        }
)

$constructorMembers = @(
    $classAst.Members |
        Where-Object {
            $_ -is
                [System.Management.Automation.Language.FunctionMemberAst] -and
            $_.Name -eq $providerName
        }
)

$methodMembers = @(
    $classAst.Members |
        Where-Object {
            $_ -is
                [System.Management.Automation.Language.FunctionMemberAst] -and
            $_.Name -ne $providerName
        }
)

if ($constructorMembers.Count -ne 1) {
    throw (
        "Expected one $providerName constructor, found " +
        "$($constructorMembers.Count)."
    )
}

##########################################################
## Map each method signature to its fragment file
##########################################################

$methodMap = @{
    'TestAvailable|0' =
        '10-ProviderManagement\TestAvailable.ps1'

    'InstallProvider|0' =
        '10-ProviderManagement\InstallProvider.ps1'

    'UpdateProvider|0' =
        '10-ProviderManagement\UpdateProvider.ps1'

    'GetInstalledPackages|0' =
        '20-Discovery\GetInstalledPackages.ps1'

    'SearchPackage|1' =
        '20-Discovery\SearchPackage.ps1'

    'NewFailure|2' =
        '30-Installation\NewFailure.ps1'

    'CanInstallSilently|1' =
        '30-Installation\CanInstallSilently.ps1'

    'InstallPackage|1' =
        '30-Installation\InstallPackage.ps1'

    'InstallPackage|2' =
        '30-Installation\InstallPackageWithMode.ps1'

    'InstallPackageCore|2' =
        '30-Installation\InstallPackageCore.ps1'

    'InstallPackageSilent|1' =
        '30-Installation\InstallPackageSilent.ps1'

    'InstallPackageInteractive|1' =
        '30-Installation\InstallPackageInteractive.ps1'

    'NewPackageWorkingDirectory|1' =
        '40-Cleanup\NewPackageWorkingDirectory.ps1'

    'IsPhoenixManagedPath|1' =
        '40-Cleanup\IsPhoenixManagedPath.ps1'

    'CleanupPackage|1' =
        '40-Cleanup\CleanupPackage.ps1'

    'CanRepairSilently|1' =
        '50-Repair\CanRepairSilently.ps1'

    'RepairPackage|1' =
        '50-Repair\RepairPackage.ps1'

    'RepairPackage|2' =
        '50-Repair\RepairPackageWithMode.ps1'

    'RepairPackageSilent|1' =
        '50-Repair\RepairPackageSilent.ps1'

    'RepairPackageInteractive|1' =
        '50-Repair\RepairPackageInteractive.ps1'

    'UpdatePackage|1' =
        '60-PackageManagement\UpdatePackage.ps1'

    'RemovePackage|1' =
        '60-PackageManagement\RemovePackage.ps1'
}

$unmappedMethods =
    [System.Collections.Generic.List[string]]::new()

$duplicateTargets =
    [System.Collections.Generic.List[string]]::new()

$targetAssignments = @{}

foreach ($method in $methodMembers) {

    [string]$signatureKey = '{0}|{1}' -f `
        $method.Name,
        $method.Parameters.Count

    if (-not $methodMap.ContainsKey($signatureKey)) {

        $unmappedMethods.Add(
            (
                '{0} with {1} parameter(s), source line {2}' -f
                $method.Name,
                $method.Parameters.Count,
                $method.Extent.StartLineNumber
            )
        )

        continue
    }

    [string]$relativeTarget =
        $methodMap[$signatureKey]

    if ($targetAssignments.ContainsKey($relativeTarget)) {

        $duplicateTargets.Add(
            "$relativeTarget <= $signatureKey"
        )

        continue
    }

    $targetAssignments[$relativeTarget] =
        $method
}

if ($unmappedMethods.Count -gt 0) {

    Write-Host 'Unmapped methods:' -ForegroundColor Red

    $unmappedMethods |
        ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }

    throw (
        'Migration stopped because one or more methods have no target file.'
    )
}

if ($duplicateTargets.Count -gt 0) {

    Write-Host 'Duplicate fragment targets:' -ForegroundColor Red

    $duplicateTargets |
        ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }

    throw (
        'Migration stopped because multiple methods map to one fragment.'
    )
}

##########################################################
## Back up the source and current scaffold
##########################################################

if (
    $PSCmdlet.ShouldProcess(
        $backupRoot,
        'Create migration backup'
    )
) {

    $null = New-Item `
        -ItemType Directory `
        -Path $backupRoot `
        -Force

    Copy-Item `
        -LiteralPath $sourcePath `
        -Destination (
            Join-Path `
                $backupRoot `
                'PhoenixProvider.legacy.ps1'
        ) `
        -Force

    Copy-Item `
        -LiteralPath $targetRoot `
        -Destination (
            Join-Path `
                $backupRoot `
                'PhoenixProvider.fragments-before'
        ) `
        -Recurse `
        -Force
}

##########################################################
## Write the class header
##########################################################

$headerLines =
    [System.Collections.Generic.List[string]]::new()

$headerLines.Add(
    '##########################################################'
)

$headerLines.Add(
    '## PhoenixProvider composite class header'
)

$headerLines.Add(
    '## Generated from the validated legacy provider'
)

$headerLines.Add(
    '##########################################################'
)

$headerLines.Add('')

$headerLines.Add('class PhoenixProvider {')
$headerLines.Add('')

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

foreach ($property in $propertyMembers) {

    $headerLines.Add(
        $property.Extent.Text.TrimEnd()
    )
}

$headerLines.Add('')

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

$headerLines.Add(
    $constructorMembers[0].Extent.Text.TrimEnd()
)

$headerLines.Add('')

if (
    $PSCmdlet.ShouldProcess(
        $headerPath,
        'Write composite class header'
    )
) {

    [IO.File]::WriteAllLines(
        $headerPath,
        $headerLines,
        [Text.UTF8Encoding]::new($true)
    )
}

##########################################################
## Write one method per fragment
##########################################################

$writtenFiles =
    [System.Collections.Generic.List[string]]::new()

foreach ($relativeTarget in (
    $targetAssignments.Keys |
        Sort-Object
)) {

    $method = $targetAssignments[$relativeTarget]

    $targetPath = Join-Path `
        $methodsRoot `
        $relativeTarget

    $targetDirectory = Split-Path `
        $targetPath `
        -Parent

    if (
        $PSCmdlet.ShouldProcess(
            $targetDirectory,
            'Create method directory'
        )
    ) {

        $null = New-Item `
            -ItemType Directory `
            -Path $targetDirectory `
            -Force
    }

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

    if (
        $PSCmdlet.ShouldProcess(
            $targetPath,
            'Write method fragment'
        )
    ) {

        [IO.File]::WriteAllLines(
            $targetPath,
            $fragmentLines,
            [Text.UTF8Encoding]::new($true)
        )
    }

    $writtenFiles.Add($targetPath)
}

##########################################################
## Write the single class-closing brace
##########################################################

$footerLines = @(
    '##########################################################'
    '## PhoenixProvider composite class footer'
    '##########################################################'
    ''
    '}'
)

if (
    $PSCmdlet.ShouldProcess(
        $footerPath,
        'Write composite class footer'
    )
) {

    [IO.File]::WriteAllLines(
        $footerPath,
        $footerLines,
        [Text.UTF8Encoding]::new($true)
    )
}

##########################################################
## Validate the assembled composite class syntax
##########################################################

$tempCompositePath = Join-Path `
    $env:TEMP `
    (
        'PhoenixProvider-composite-{0}.ps1' -f
        [guid]::NewGuid().ToString('N')
    )

try {

    $compositeLines =
        [System.Collections.Generic.List[string]]::new()

    foreach ($line in [IO.File]::ReadAllLines($headerPath)) {
        $compositeLines.Add($line)
    }

    $compositeLines.Add('')

    foreach ($targetPath in (
        $writtenFiles |
            Sort-Object
    )) {

        foreach ($line in [IO.File]::ReadAllLines($targetPath)) {
            $compositeLines.Add($line)
        }

        $compositeLines.Add('')
    }

    foreach ($line in [IO.File]::ReadAllLines($footerPath)) {
        $compositeLines.Add($line)
    }

    [IO.File]::WriteAllLines(
        $tempCompositePath,
        $compositeLines,
        [Text.UTF8Encoding]::new($true)
    )

    $compositeTokens = $null
    $compositeParseErrors = $null

    [System.Management.Automation.Language.Parser]::ParseFile(
        $tempCompositePath,
        [ref]$compositeTokens,
        [ref]$compositeParseErrors
    ) | Out-Null

    $syntaxErrors = @(
        $compositeParseErrors |
            Where-Object {
                $_.Message -notlike 'Unable to find type*'
            }
    )

    if ($syntaxErrors.Count -gt 0) {

        Write-Host ''
        Write-Host (
            'The assembled PhoenixProvider has syntax errors:'
        ) -ForegroundColor Red

        $syntaxErrors |
            Select-Object `
                @{Name = 'Line'; Expression = {
                    $_.Extent.StartLineNumber
                }},
                Message |
            Format-Table -AutoSize -Wrap

        throw (
            'Composite PhoenixProvider validation failed.'
        )
    }
}
finally {

    Remove-Item `
        -LiteralPath $tempCompositePath `
        -Force `
        -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'PhoenixProvider migration completed.' `
    -ForegroundColor Green

Write-Host (
    "Properties migrated: $($propertyMembers.Count)"
)

Write-Host (
    "Methods migrated: $($methodMembers.Count)"
)

Write-Host "Backup: $backupRoot"

Write-Host ''
Write-Host 'Next commands:' -ForegroundColor Cyan

Write-Host (
    '.\Build\Set-PhoenixCompositeProvider.ps1 ' +
    '-ProviderName PhoenixProvider'
)

Write-Host (
    '.\Build\Build-PhoenixClasses.ps1'
)