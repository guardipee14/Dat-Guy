Set-StrictMode -Version Latest

Describe 'Phoenix v0.3.0 platform matrix' {

    BeforeAll {
        $script:ProjectRoot =
            Split-Path `
                -Parent `
                (Split-Path -Parent $PSScriptRoot)

        $script:MatrixPath =
            Join-Path `
                $script:ProjectRoot `
                'Docs\Phoenix-v0.3.0-Platform-Matrix.md'

        $script:VmTestingPath =
            Join-Path `
                $script:ProjectRoot `
                'Docs\Windows-VM-Testing.md'

        $script:RoadmapPath =
            Join-Path `
                $script:ProjectRoot `
                'ROADMAP.md'

        $script:Matrix =
            Get-Content `
                -LiteralPath $script:MatrixPath `
                -Raw

        $script:VmTesting =
            Get-Content `
                -LiteralPath $script:VmTestingPath `
                -Raw

        $script:Roadmap =
            (
                Get-Content `
                    -LiteralPath $script:RoadmapPath `
                    -Raw
            ) -replace "`r`n", "`n"
    }

    It 'defines the supported Windows and PowerShell boundary' {
        Test-Path `
            -LiteralPath $script:MatrixPath `
            -PathType Leaf |
            Should-BeTrue

        $requiredMatrixText = @(
            '| Windows 11 25H2 | x64 | Validated primary platform |'
            '| Windows 11 24H2 | x64 | Supported |'
            '| Windows 10 Enterprise LTSC 2021 | x64 |'
            '| Windows 11 26H1, build 28000 | Any | Detect only |'
            '| PowerShell 7.6 LTS, latest servicing update | x64 |'
            '| Windows PowerShell 5.1 | Any | Bootstrap or diagnostics only;'
        )

        foreach ($requiredText in $requiredMatrixText) {
            $script:Matrix |
                Should-MatchString ([regex]::Escape($requiredText))
        }
    }

    It 'defines the deployment architecture and toolchain boundary' {
        $requiredMatrixText = @(
            'Windows ADK `10.1.26100.2454`'
            'Windows ADK patch `KB5079391`'
            '| Firmware | UEFI required for deployment execution |'
            '| System and target disk style | GPT required |'
            '| Phoenix host process | x64 |'
            '| Windows PE workspace and media | x64 |'
            'ADK and Windows PE components from different version families'
        )

        foreach ($requiredText in $requiredMatrixText) {
            $script:Matrix |
                Should-MatchString ([regex]::Escape($requiredText))
        }
    }

    It 'records the completed v0.2.2 privilege validation' {
        $requiredValidationText = @(
            '| Computer | `TESTWINDOWS` |'
            '| Windows version | 25H2 |'
            '| Windows build | `26200.8894` |'
            '| PowerShell | `7.6.4` Core |'
            '| Firmware | UEFI |'
            '| System disk | GPT |'
            '| Runtime controls resolved | 139 | 139 |'
            '| Control Center pages measured | 6 | 6 |'
            '| Providers bound | 10 | 10 |'
            '| Applications bound | 91 | 91 |'
            '| Drivers bound | 70 | 70 |'
            '| OEM adapters bound | 6 | 6 |'
        )

        foreach ($requiredText in $requiredValidationText) {
            $script:Matrix |
                Should-MatchString ([regex]::Escape($requiredText))
        }
    }

    It 'links the VM validation record to the platform matrix' {
        $script:VmTesting |
            Should-MatchString '## v0\.2\.2 validation record'

        $script:VmTesting |
            Should-MatchString 'resolved\s+139 runtime controls'

        $script:VmTesting |
            Should-MatchString (
                [regex]::Escape(
                    '`Docs/Phoenix-v0.3.0-Platform-Matrix.md`'
                )
            )
    }

    It 'records the completed v0.2.2 roadmap release status' {
        $script:Roadmap |
            Should-MatchString (
                '(?m)^- \[x\] Complete the live administrator-token ' +
                'Control Center smoke gate left$'
            )

        $script:Roadmap |
            Should-MatchString (
                '(?m)^- \[x\] Define supported Windows host and target ' +
                'builds, PowerShell versions,$'
            )

        $script:Roadmap |
            Should-MatchString (
                '(?m)^- \[x\] The carried-forward administrator-token ' +
                'VM gate passes\.$'
            )

        $script:Roadmap |
            Should-MatchString (
                '(?m)^- \[x\] `v0\.2\.2` - Complete elevated-token ' +
                'VM validation and define the v0\.3\.0$'
            )
    }
}
