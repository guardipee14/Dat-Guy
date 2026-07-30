BeforeAll {

    $projectRoot = (
        Resolve-Path (
            Join-Path `
                $PSScriptRoot `
                '..\..'
        )
    ).Path

    . (
        Join-Path `
            $projectRoot `
            'Private\Core\Get-PhoenixPropertyValue.ps1'
    )

    . (
        Join-Path `
            $projectRoot `
            'Private\Packages\Test-PhoenixRestorePackage.ps1'
    )
}

Describe 'Get-PhoenixPropertyValue' -Tag @(
    'Unit'
    'Core'
) {

    It 'returns the default value for a null input object' {

        Get-PhoenixPropertyValue `
            -InputObject $null `
            -Name 'Id' `
            -DefaultValue 'fallback' |
            Should-Be 'fallback'
    }
}

Describe 'Test-PhoenixRestorePackage' -Tag @(
    'Unit'
    'Manifest'
    'Restore'
) {

    It 'accepts a WinGet community-source package' {

        $package = [pscustomobject]@{
            Name     = 'PowerToys'
            Id       = 'Microsoft.PowerToys'
            Provider = 'WinGet'
            Source   = 'winget'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeTrue
    }

    It 'matches the WinGet provider and source without case sensitivity' {

        $package = [pscustomobject]@{
            Name     = 'PowerToys'
            Id       = 'Microsoft.PowerToys'
            Provider = 'winget'
            Source   = 'WINGET'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeTrue
    }

    It 'accepts a Chocolatey package' {

        $package = [pscustomobject]@{
            Name     = '7-Zip'
            Id       = '7zip'
            Provider = 'Chocolatey'
            Source   = ''
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeTrue
    }

    It 'rejects a WinGet ARP inventory record' {

        $package = [pscustomobject]@{
            Name     = 'Legacy Application'
            Id       = 'ARP\Machine\X64\LegacyApplication'
            Provider = 'WinGet'
            Source   = 'winget'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeFalse
    }

    It 'rejects a WinGet MSIX inventory record' {

        $package = [pscustomobject]@{
            Name     = 'Store Application'
            Id       = 'MSIX\Contoso.Application_1.0.0.0_x64'
            Provider = 'WinGet'
            Source   = 'winget'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeFalse
    }

    It 'rejects a WinGet package from a non-community source' {

        $package = [pscustomobject]@{
            Name     = 'Store Application'
            Id       = '9NBLGGH4NNS1'
            Provider = 'WinGet'
            Source   = 'msstore'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeFalse
    }

    It 'rejects an unsupported provider' {

        $package = [pscustomobject]@{
            Name     = 'Example Application'
            Id       = 'example'
            Provider = 'Scoop'
            Source   = 'main'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeFalse
    }

    It 'rejects a record without an ID' {

        $package = [pscustomobject]@{
            Name     = 'Missing ID'
            Provider = 'WinGet'
            Source   = 'winget'
        }

        Test-PhoenixRestorePackage `
            -InputObject $package |
            Should-BeFalse
    }

    It 'rejects a null record' {

        Test-PhoenixRestorePackage `
            -InputObject $null |
            Should-BeFalse
    }
}