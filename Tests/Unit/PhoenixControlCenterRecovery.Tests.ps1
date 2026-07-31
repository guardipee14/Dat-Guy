BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    Import-Module `
        -Name (
            Join-Path `
                $projectRoot `
                'Phoenix.psd1'
        ) `
        -Force `
        -ErrorAction Stop `
        6>$null
}

AfterAll {
    Remove-Module `
        -Name Phoenix `
        -Force `
        -ErrorAction SilentlyContinue
}

Describe 'Phoenix Control Center recovery' -Tag @(
    'Unit'
    'ControlCenter'
    'Recovery'
) {

    It 'normalizes a UI exception into a structured Phoenix failure' {
        $failure =
            InModuleScope Phoenix {
                try {
                    throw 'Simulated component failure'
                }
                catch {
                    New-PhoenixControlCenterFailure `
                        -Component 'Inventory' `
                        -Operation 'Refresh' `
                        -ErrorRecord $_
                }
            }

        $failure.Success |
            Should-BeFalse

        $failure.Code |
            Should-Be 'PHX_UI_COMPONENT_FAILED'

        $failure.Data.Stage |
            Should-Be 'ControlCenter'

        $failure.Data.Component |
            Should-Be 'Inventory'

        $failure.Data.Operation |
            Should-Be 'Refresh'

        $failure.Data.Recoverable |
            Should-BeTrue

        [string]::IsNullOrWhiteSpace(
            [string]$failure.Data.FailureId
        ) |
            Should-BeFalse

        @($failure.Errors).Count |
            Should-Be 1
    }

    It 'returns component data when the protected action succeeds' {
        $result =
            InModuleScope Phoenix {
                Invoke-PhoenixControlCenterBoundary `
                    -Component 'ThemeList' `
                    -Operation 'Load' `
                    -Action {
                        return 'Loaded'
                    }
            }

        $result.Success |
            Should-BeTrue

        $result.Code |
            Should-Be 'PHX_UI_COMPONENT_COMPLETE'

        $result.Data |
            Should-Be 'Loaded'
    }

    It 'contains protected-action failures without rethrowing them' {
        $result =
            InModuleScope Phoenix {
                Mock Write-PhoenixControlCenterFailure {
                    [pscustomobject]@{
                        Success = $true
                    }
                }

                Invoke-PhoenixControlCenterBoundary `
                    -Component 'ProviderGrid' `
                    -Operation 'Bind' `
                    -Action {
                        throw 'Simulated binding failure'
                    }
            }

        $result.Success |
            Should-BeFalse

        $result.Code |
            Should-Be 'PHX_UI_COMPONENT_FAILED'

        $result.Message |
            Should-MatchString 'Simulated binding failure'
    }

    It 'records the last failure and retains only 20 history files' {
        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'ControlCenterJournal'

        $writeResults =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Mock Write-PhoenixLog {
                        return
                    }

                    $results = @(
                        foreach ($number in 1..23) {
                            $failure =
                                New-PhoenixControlCenterFailure `
                                    -Component 'Applications' `
                                    -Operation "Test$number" `
                                    -Message "Failure $number"

                            Write-PhoenixControlCenterFailure `
                                -Failure $failure `
                                -ProjectRoot $RecoveryProjectRoot `
                                -RetentionCount 20
                        }
                    )

                    return @($results)
                }

        @(
            $writeResults |
                Where-Object {
                    -not $_.Success
                }
        ).Count |
            Should-Be 0

        [string]$lastFailurePath =
            Join-Path `
                $runtimeRoot `
                'Cache\ControlCenter\LastFailure.json'

        Test-Path `
            -LiteralPath $lastFailurePath |
            Should-BeTrue

        $lastFailure =
            Get-Content `
                -LiteralPath $lastFailurePath `
                -Raw |
            ConvertFrom-Json

        $lastFailure.Data.Operation |
            Should-Be 'Test23'

        @(
            Get-ChildItem `
                -LiteralPath (
                    Join-Path `
                        $runtimeRoot `
                        'Cache\ControlCenter\Failures'
                ) `
                -Filter 'PhoenixUiFailure-*.json' `
                -File
        ).Count |
            Should-Be 20
    }

    It 'reloads the most recent structured failure safely' {
        [string]$runtimeRoot =
            Join-Path `
                $TestDrive `
                'ControlCenterReload'

        $reloadedFailure =
            InModuleScope Phoenix `
                -Parameters @{
                    RecoveryProjectRoot = $runtimeRoot
                } {
                    param($RecoveryProjectRoot)

                    Mock Write-PhoenixLog {
                        return
                    }

                    $failure =
                        New-PhoenixControlCenterFailure `
                            -Component 'Drivers' `
                            -Operation 'Refresh' `
                            -Message 'Simulated driver failure'

                    $null =
                        Write-PhoenixControlCenterFailure `
                            -Failure $failure `
                            -ProjectRoot $RecoveryProjectRoot

                    Get-PhoenixControlCenterLastFailure `
                        -ProjectRoot $RecoveryProjectRoot
                }

        $reloadedFailure.Code |
            Should-Be 'PHX_UI_COMPONENT_FAILED'

        $reloadedFailure.Data.Component |
            Should-Be 'Drivers'

        $reloadedFailure.Data.JournalPath |
            Should-MatchString 'LastFailure\.json$'
    }
}
