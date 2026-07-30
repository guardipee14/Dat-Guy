BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    function Get-PhoenixParsedSource {

        param(
            [Parameter(Mandatory)]
            [string]$LiteralPath
        )

        $resolvedPath = (
            Resolve-Path `
                -LiteralPath $LiteralPath
        ).Path

        $tokens = $null
        $parseErrors = $null

        $ast =
            [System.Management.Automation.Language.Parser]::ParseFile(
                $resolvedPath,
                [ref]$tokens,
                [ref]$parseErrors
            )

        return [pscustomobject]@{
            Path   = $resolvedPath
            Ast    = $ast
            Errors = @($parseErrors)
            Text   = [IO.File]::ReadAllText($resolvedPath)
        }
    }

    $backupSource =
        Get-PhoenixParsedSource `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Public\Backup-Phoenix.ps1'
            )

    $restoreSource =
        Get-PhoenixParsedSource `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Public\Restore-Phoenix.ps1'
            )

    $classesSource =
        Get-PhoenixParsedSource `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Classes\Phoenix.Classes.psm1'
            )

    $winGetInstallPath = (
        Resolve-Path `
            -LiteralPath (
                Join-Path `
                    $projectRoot `
                    'Classes\20-Providers\WinGetProvider\Methods\InstallPackageSilent.ps1'
            )
    ).Path

    $winGetInstallSource =
        [IO.File]::ReadAllText($winGetInstallPath)
}

Describe 'Phoenix restore regressions' -Tag @(
    'Regression'
    'Manifest'
    'Restore'
) {

    It 'keeps the restore-related source files syntactically valid' {

        @($backupSource.Errors).Count |
            Should-Be 0

        @($restoreSource.Errors).Count |
            Should-Be 0

        @($classesSource.Errors).Count |
            Should-Be 0
    }

    It 'keeps complete software inventory separate from restorable packages' {

        (
            $backupSource.Text -match
            '(?s)Inventory\s*=\s*\[ordered\]@\{.*?Software\s*=\s*\$softwareRecords'
        ) |
            Should-BeTrue

        (
            $backupSource.Text -match
            '(?m)^\s*Packages\s*=\s*\$packageRecords\s*$'
        ) |
            Should-BeTrue
    }

    It 'uses the shared eligibility rule when producing manifest packages' {

        (
            $backupSource.Text -match
            '(?s)\$packageRecords\s*=\s*@\(.*?Test-PhoenixRestorePackage'
        ) |
            Should-BeTrue

        (
            $restoreSource.Text -match
            'Test-PhoenixRestorePackage'
        ) |
            Should-BeTrue
    }

    It 'passes one formatted installed-package key to HashSet Add' {

        $installedKeyCalls = @(
            $restoreSource.Ast.FindAll(
                {
                    param($node)

                    $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                    $node.Member.Value -eq 'Add' -and
                    $node.Expression.Extent.Text -eq
                        '$installedPackageKeys' -and
                    $node.Extent.Text -match
                        '\{0\}\|\{1\}'
                },
                $true
            )
        )

        $installedKeyCalls.Count |
            Should-Be 1

        $installedKeyCalls[0].Arguments.Count |
            Should-Be 1

        (
            $installedKeyCalls[0].Arguments[0].Extent.Text -match
            '\{0\}\|\{1\}'
        ) |
            Should-BeTrue
    }

    It 'normalizes the WinGet already-installed exit code as success' {

        (
            $winGetInstallSource -match
            '\$exitCode\s+-eq\s+-1978335135'
        ) |
            Should-BeTrue

        (
            $winGetInstallSource -match
            "'PHX_ALREADY_INSTALLED'"
        ) |
            Should-BeTrue
    }
}