BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Phoenix provider orchestration' -Tag @('Unit','Provider','Orchestration') {
    BeforeEach {
        InModuleScope Phoenix {
            Mock Test-PhoenixPrivilege { return $true }
            Mock Test-PhoenixRestorePackage { return $true }
        }
    }

    It 'selects the preferred eligible provider deterministically' {
        InModuleScope Phoenix -Parameters @{ Root = $TestDrive } {
            $context = [PhoenixContext]::new($Root)
            $preferred = [MSIProvider]::new()
            $preferred.Available = $true
            $fallback = [EXEProvider]::new()
            $fallback.Available = $true
            $context.Providers.Add($preferred)
            $context.Providers.Add($fallback)
            $package = [Package]::new()
            $package.Id = '{00000000-0000-0000-0000-000000000001}'
            $package.Provider = 'MSI'

            $selection = Resolve-PhoenixProviderSelection `
                -Context $context -Package $package -Operation Install

            $selection.Eligible | Should-BeTrue
            $selection.ProviderName | Should-Be 'MSI'
            $selection.Code | Should-Be 'PHX_PROVIDER_SELECTED'
        }
    }

    It 'falls back only when explicitly allowed' {
        InModuleScope Phoenix -Parameters @{ Root = $TestDrive } {
            $context = [PhoenixContext]::new($Root)
            $preferred = [MSIProvider]::new()
            $preferred.Available = $false
            $fallback = [EXEProvider]::new()
            $fallback.Available = $true
            $context.Providers.Add($preferred)
            $context.Providers.Add($fallback)
            $package = [Package]::new()
            $package.Id = 'Example'
            $package.Provider = 'MSI'

            $withoutFallback = Resolve-PhoenixProviderSelection `
                -Context $context -Package $package -Operation Install
            $withFallback = Resolve-PhoenixProviderSelection `
                -Context $context -Package $package -Operation Install `
                -AllowFallback

            $withoutFallback.Eligible | Should-BeFalse
            $withFallback.ProviderName | Should-Be 'EXE'
        }
    }

    It 'exposes ordered provider alternatives and privilege policy' {
        InModuleScope Phoenix -Parameters @{ Root = $TestDrive } {
            $context = [PhoenixContext]::new($Root)
            $msi = [MSIProvider]::new(); $msi.Available = $true
            $exe = [EXEProvider]::new(); $exe.Available = $true
            $context.Providers.Add($msi); $context.Providers.Add($exe)
            $package = [Package]::new()
            $package.Id = 'Example'; $package.Provider = 'MSI'

            $selection = Resolve-PhoenixProviderSelection `
                -Context $context -Package $package -Operation Install

            ($selection.Alternatives.Name -contains 'EXE') | Should-BeTrue
            ($selection.Alternatives[0].PSObject.Properties.Name -contains
                'RequiresElevation') | Should-BeTrue
            ($selection.PSObject.Properties.Name -contains 'Safety') |
                Should-BeTrue
        }
    }

    It 'blocks protected package-manager removal' {
        InModuleScope Phoenix -Parameters @{ Root = $TestDrive } {
            $context = [PhoenixContext]::new($Root)
            $provider = [MSIProvider]::new(); $provider.Available = $true
            $context.Providers.Add($provider)
            $package = [Package]::new()
            $package.Id = 'Microsoft.AppInstaller'; $package.Provider = 'MSI'

            $selection = Resolve-PhoenixProviderSelection `
                -Context $context -Package $package -Operation Remove

            $selection.Eligible | Should-BeFalse
            $selection.Code | Should-Be 'PHX_PROTECTED_PACKAGE'
        }
    }

    It 'normalizes provider operation results for CLI and UI consumers' {
        InModuleScope Phoenix {
            $result = ConvertTo-PhoenixOrchestratedResult `
                -Result ([Result]::Success()) `
                -Provider MSI -Operation Install -Target Example

            $result.Provider | Should-Be 'MSI'
            $result.Operation | Should-Be 'Install'
            $result.Target | Should-Be 'Example'
            $result.Code | Should-Be 'PHX_INSTALL_SUCCEEDED'
        }
    }
}
