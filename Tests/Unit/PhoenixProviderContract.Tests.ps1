using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'Phoenix provider contract' -Tag @(
    'Unit'
    'Provider'
    'Contract'
) {
    It 'publishes one capability and availability snapshot' {
        $provider = [PhoenixProvider]::new()
        $provider.Name = 'MockProvider'
        $provider.Version = '1.2.3'
        $provider.Available = $true
        $provider.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::Administrator
        $provider.SupportsRepair = $true
        $provider.SupportsExport = $true

        $capability = $provider.GetCapability()

        $capability.ProviderName |
            Should-Be 'MockProvider'

        $capability.ProviderVersion |
            Should-Be '1.2.3'

        $capability.Availability.ToString() |
            Should-Be 'Available'

        $capability.RequiredPrivilege.ToString() |
            Should-Be 'Administrator'

        $capability.Supports(
            [PhoenixProviderOperation]::Repair
        ) |
            Should-BeTrue

        (
            $capability.SupportedOperations -contains
            'Export'
        ) |
            Should-BeTrue

        $capability.HealthMessage |
            Should-Be 'Ready'
    }

    It 'models mocked availability for every registered provider' {
        $providerMocks = @(
            [pscustomobject]@{
                Name = 'WinGet'
                Available = $true
                Privilege =
                    [PhoenixPrivilegeLevel]::User
            }
            [pscustomobject]@{
                Name = 'Chocolatey'
                Available = $false
                Privilege =
                    [PhoenixPrivilegeLevel]::Administrator
            }
        )

        foreach ($providerMock in $providerMocks) {
            $provider = [PhoenixProvider]::new()
            $provider.Name = $providerMock.Name
            $provider.Available = $providerMock.Available
            $provider.RequiredPrivilege =
                $providerMock.Privilege

            $capability = $provider.GetCapability()

            $capability.ProviderName |
                Should-Be $providerMock.Name

            $capability.Available |
                Should-Be $providerMock.Available

            [string]$expectedAvailability =
                if ($providerMock.Available) {
                    'Available'
                }
                else {
                    'Unavailable'
                }

            $capability.Availability.ToString() |
                Should-Be $expectedAvailability

            $capability.Supports(
                [PhoenixProviderOperation]::Search
            ) |
                Should-BeTrue

            $capability.Supports(
                [PhoenixProviderOperation]::Restore
            ) |
                Should-BeTrue
        }
    }

    It 'normalizes data for every provider operation' {
        $provider = [PhoenixProvider]::new()
        $provider.Name = 'MockProvider'

        foreach (
            $operation in @(
                [PhoenixProviderOperation]::Search
                [PhoenixProviderOperation]::Inventory
                [PhoenixProviderOperation]::Install
                [PhoenixProviderOperation]::Update
                [PhoenixProviderOperation]::Repair
                [PhoenixProviderOperation]::Remove
                [PhoenixProviderOperation]::Export
                [PhoenixProviderOperation]::Restore
            )
        ) {
            $normalized =
                $provider.NormalizeData(
                    [pscustomobject]@{
                        Operation = $operation.ToString()
                    },
                    $operation,
                    'Contoso.App'
                )

            $normalized.Success |
                Should-BeTrue

            $normalized.Operation.ToString() |
                Should-Be $operation.ToString()

            $normalized.Target |
                Should-Be 'Contoso.App'

            $normalized.Code |
                Should-Be (
                    'PHX_PROVIDER_{0}_SUCCEEDED' -f
                    $operation.ToString().ToUpperInvariant()
                )
        }
    }

    It 'normalizes privilege restart timeout cancellation and exit data' {
        $provider = [PhoenixProvider]::new()
        $provider.Name = 'Chocolatey'
        $provider.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::Administrator

        $sourceResult = [Result]::Failure(
            'The provider process timed out.'
        )
        $sourceResult.Code = 'PHX_PROVIDER_TIMEOUT'
        $sourceResult.Warnings = @(
            'Cached metadata was used.'
        )
        $sourceResult.Errors = @(
            'The provider did not exit before the deadline.'
        )
        $sourceResult.Data = [pscustomobject]@{
            ExitCode = 1460
            RebootRequired = $true
            TimedOut = $true
            Cancelled = $true
        }

        $normalized =
            $provider.NormalizeResult(
                $sourceResult,
                [PhoenixProviderOperation]::Install,
                'Contoso.App'
            )

        $normalized.Success |
            Should-BeFalse

        $normalized.Code |
            Should-Be 'PHX_PROVIDER_TIMEOUT'

        $normalized.RequiredPrivilege.ToString() |
            Should-Be 'Administrator'

        $normalized.RequiresRestart |
            Should-BeTrue

        $normalized.TimedOut |
            Should-BeTrue

        $normalized.Cancelled |
            Should-BeTrue

        $normalized.HasExitCode |
            Should-BeTrue

        $normalized.ExitCode |
            Should-Be 1460

        $normalized.Warnings.Count |
            Should-Be 1

        $normalized.Errors.Count |
            Should-Be 1
    }
}
