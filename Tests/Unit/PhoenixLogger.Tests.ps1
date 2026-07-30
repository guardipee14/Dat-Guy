using module '..\..\Classes\Phoenix.Classes.psm1'

Describe 'PhoenixLogger' -Tag @(
    'Unit'
    'Logging'
) {

    BeforeEach {

        $testProjectRoot =
            Join-Path `
                $TestDrive `
                ([guid]::NewGuid().ToString('N'))

        $logger =
            [PhoenixLogger]::new($testProjectRoot)
    }

    It 'does not create a file for messages below the configured level' {

        $logger.Configure('Info', 20)
        $logger.Write('Verbose', 'Routine discovery detail.')

        Test-Path `
            -LiteralPath $logger.LogFile |
            Should-BeFalse
    }

    It 'uses one log file for multiple relevant messages' {

        $logger.Configure('Info', 20)
        $logger.Write('Info', 'Phoenix started.')
        $logger.Write('Success', 'Phoenix completed.')
        $logger.Write('Warning', 'Phoenix warning.')

        $ownedLogs = @(
            Get-ChildItem `
                -LiteralPath $logger.LogDirectory `
                -Filter 'Phoenix-*.log' `
                -File
        )

        $ownedLogs.Count |
            Should-Be 1

        @(
            Get-Content `
                -LiteralPath $logger.LogFile
        ).Count |
            Should-Be 3
    }

    It 'keeps only the newest 20 Phoenix-owned log files' {

        $logger.Configure('Info', 20)

        foreach ($index in 0..24) {

            $legacyLog =
                Join-Path `
                    $logger.LogDirectory `
                    (
                        'Phoenix-20260701-{0:000000}.log' -f
                        $index
                    )

            Set-Content `
                -LiteralPath $legacyLog `
                -Value "Legacy log $index"

            (
                Get-Item `
                    -LiteralPath $legacyLog
            ).LastWriteTimeUtc =
                (Get-Date).ToUniversalTime().AddMinutes(
                    -100 - $index
                )
        }

        $unrelatedLog =
            Join-Path `
                $logger.LogDirectory `
                'Application.log'

        $lookalikeLog =
            Join-Path `
                $logger.LogDirectory `
                'Phoenix-manual.log'

        Set-Content `
            -LiteralPath $unrelatedLog `
            -Value 'Unrelated application log.'

        Set-Content `
            -LiteralPath $lookalikeLog `
            -Value 'Not a Phoenix session log.'

        $logger.Write('Info', 'Apply retention.')

        $ownedLogs = @(
            Get-ChildItem `
                -LiteralPath $logger.LogDirectory `
                -Filter 'Phoenix-*.log' `
                -File |
                Where-Object {
                    $_.Name -match (
                        '^Phoenix-\d{8}-\d{6}(?:-\d{3})?\.log$'
                    )
                }
        )

        $ownedLogs.Count |
            Should-Be 20

        Test-Path `
            -LiteralPath $logger.LogFile |
            Should-BeTrue

        Test-Path `
            -LiteralPath $unrelatedLog |
            Should-BeTrue

        Test-Path `
            -LiteralPath $lookalikeLog |
            Should-BeTrue
    }

    It 'keeps the startup log entry from being duplicated' {

        $projectRoot = (
            Resolve-Path (
                Join-Path `
                    $PSScriptRoot `
                    '..\..'
            )
        ).Path

        $startSource =
            Get-Content `
                -LiteralPath (
                    Join-Path `
                        $projectRoot `
                        'Public\Start-Phoenix.ps1'
                ) `
                -Raw

        [regex]::Matches(
            $startSource,
            '\.Logger\.Write\('
        ).Count |
            Should-Be 0

        [regex]::Matches(
            $startSource,
            "'Phoenix started\.'"
        ).Count |
            Should-Be 1
    }
}