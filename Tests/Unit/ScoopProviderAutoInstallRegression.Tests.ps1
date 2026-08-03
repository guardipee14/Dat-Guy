using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Scoop provider automatic installation regression' -Tag @(
    'Unit'
    'Provider'
    'Scoop'
) {
    BeforeAll {
        $script:source =
            Get-Content (
                Join-Path `
                    $PSScriptRoot `
                    '..\..\Classes\20-Providers\ScoopProvider.ps1'
            ) -Raw
    }

    It 'uses the official Scoop installer endpoint' {
        $script:source.Contains(
            "'https://get.scoop.sh'"
        ) | Should-BeTrue
    }

    It 'uses only a child-process execution-policy bypass' {
        $script:source.Contains(
            "'-ExecutionPolicy'"
        ) | Should-BeTrue

        $script:source.Contains(
            "'Bypass'"
        ) | Should-BeTrue

        $script:source.Contains(
            'Set-ExecutionPolicy'
        ) | Should-BeFalse
    }

    It 'supports an elevated Phoenix process explicitly' {
        $script:source.Contains(
            '-RunAsAdmin'
        ) | Should-BeTrue

        $script:source.Contains(
            '$isAdministrator'
        ) | Should-BeTrue
    }

    It 'enforces a finite timeout and verifies Scoop' {
        $script:source.Contains(
            '$process.WaitForExit(300000)'
        ) | Should-BeTrue

        $script:source.Contains(
            'PHX_PROVIDER_INSTALL_TIMEOUT'
        ) | Should-BeTrue

        $script:source.Contains(
            'PHX_PROVIDER_INSTALL_VERIFY_FAILED'
        ) | Should-BeTrue
    }

    It 'does not use invalid class-method automatic variables' {
        $script:source.Contains(
            '$ExecutionContext'
        ) | Should-BeFalse

        $script:source.Contains(
            '$PID'
        ) | Should-BeFalse
    }

    It 'reports a structured successful installation' {
        $script:source.Contains(
            'PHX_PROVIDER_INSTALL_SUCCEEDED'
        ) | Should-BeTrue

        $script:source.Contains(
            'PHX_PROVIDER_INSTALL_APPROVAL_REQUIRED'
        ) | Should-BeFalse
    }
}
