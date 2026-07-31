using module ..\..\Classes\Phoenix.Classes.psm1

Describe 'PhoenixBackgroundOperation' -Tag @(
    'Unit'
    'BackgroundOperation'
) {
    It 'creates a background operation in the Created state' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'Inventory',
                [pscustomobject]@{},
                'Inventory',
                'Collecting Phoenix inventory...',
                {}
            )

        [string]::IsNullOrWhiteSpace(
            $operation.OperationId
        ) |
            Should-BeFalse

        $operation.State.ToString() |
            Should-Be 'Created'

        $operation.Action |
            Should-Be 'Inventory'

        $operation.Component |
            Should-Be 'Inventory'

        $operation.Description |
            Should-Be 'Collecting Phoenix inventory...'

        $operation.CreatedAtUtc |
            Should-BeGreaterThan ([datetime]::MinValue)

        $operation.IsTerminal() |
            Should-BeFalse
    }

    It 'moves through the successful operation lifecycle' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'SearchPackages',
                [pscustomobject]@{
                    Query = 'PowerShell'
                },
                'PackageSearch',
                'Searching for packages...',
                {}
            )

        $operation.MarkStarting()

        $operation.State.ToString() |
            Should-Be 'Starting'

        $operation.MarkRunning()

        $operation.State.ToString() |
            Should-Be 'Running'

        $operation.UpdateProgress(
            45,
            'Searching Chocolatey...'
        )

        $operation.ProgressPercent |
            Should-Be 45

        $operation.ProgressMessage |
            Should-Be 'Searching Chocolatey...'

        $operation.MarkCompleted()

        $operation.State.ToString() |
            Should-Be 'Completed'

        $operation.ProgressPercent |
            Should-Be 100

        $operation.IsTerminal() |
            Should-BeTrue

        $operation.CompletedAtUtc |
            Should-BeGreaterThan ([datetime]::MinValue)
    }

    It 'clamps progress to the supported range' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'Inventory',
                [pscustomobject]@{},
                'Inventory',
                'Collecting inventory...',
                {}
            )

        $operation.MarkStarting()
        $operation.MarkRunning()

        $operation.UpdateProgress(
            -10,
            'Starting...'
        )

        $operation.ProgressPercent |
            Should-Be 0

        $operation.UpdateProgress(
            150,
            'Finishing...'
        )

        $operation.ProgressPercent |
            Should-Be 100
    }

    It 'supports cancellation from the Running state' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'DriverAction',
                [pscustomobject]@{},
                'Drivers',
                'Scanning drivers...',
                {}
            )

        $operation.MarkStarting()
        $operation.MarkRunning()

        $operation.CanCancel() |
            Should-BeTrue

        $operation.RequestCancellation()

        $operation.State.ToString() |
            Should-Be 'CancellationRequested'

        $operation.CancellationRequested |
            Should-BeTrue

        $operation.MarkCancelled()

        $operation.State.ToString() |
            Should-Be 'Cancelled'

        $operation.IsTerminal() |
            Should-BeTrue
    }

    It 'records a structured failed state' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'PackageAction',
                [pscustomobject]@{},
                'Applications',
                'Installing applications...',
                {}
            )

        $operation.MarkStarting()
        $operation.MarkRunning()
        $operation.MarkFailed(
            'The package worker stopped unexpectedly.'
        )

        $operation.State.ToString() |
            Should-Be 'Failed'

        $operation.ErrorMessage |
            Should-Be (
                'The package worker stopped unexpectedly.'
            )

        $operation.IsTerminal() |
            Should-BeTrue
    }

    It 'rejects invalid lifecycle transitions' {
        $operation =
            [PhoenixBackgroundOperation]::new(
                'Inventory',
                [pscustomobject]@{},
                'Inventory',
                'Collecting inventory...',
                {}
            )

        {
            $operation.MarkRunning()
        } |
            Should-Throw
    }

    It 'requires the operation contract fields' {
        {
            [PhoenixBackgroundOperation]::new(
                '',
                [pscustomobject]@{},
                'Inventory',
                'Collecting inventory...',
                {}
            )
        } |
            Should-Throw

        {
            [PhoenixBackgroundOperation]::new(
                'Inventory',
                [pscustomobject]@{},
                '',
                'Collecting inventory...',
                {}
            )
        } |
            Should-Throw

        {
            [PhoenixBackgroundOperation]::new(
                'Inventory',
                [pscustomobject]@{},
                'Inventory',
                '',
                {}
            )
        } |
            Should-Throw
    }
}
