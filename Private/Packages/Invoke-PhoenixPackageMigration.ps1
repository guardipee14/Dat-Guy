function Invoke-PhoenixPackageMigration {

    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixProvider]$Provider,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [Package]$Package,

        [Parameter()]
        [switch]$AllowMigration,

        [Parameter()]
        [switch]$ForceProtectedMigration,

        [Parameter()]
        [switch]$Unattended
    )

    [string[]]$protectedPackageIds = @(
        'Microsoft.Edge'
        'Microsoft.AppInstaller'
        'Microsoft.DesktopAppInstaller'
        'Microsoft.WindowsStore'
    )

    [bool]$isProtectedPackage =
        $Package.Id -in $protectedPackageIds

    if (
        $isProtectedPackage -and
        -not $ForceProtectedMigration
    ) {

        [Result]$result = [Result]::Failure(
            (
                "Migration is blocked for protected package " +
                "'$($Package.Id)'."
            )
        )

        $result.Code =
            'PHX_UPDATE_MIGRATION_PROTECTED'

        $result.Message = (
            "$($Package.Id) requires an uninstall and reinstall, " +
            'but Phoenix will not remove this protected package ' +
            'without -ForceProtectedMigration.'
        )

        $result.Data = $Package

        return $result
    }

    [bool]$migrationApproved = (
        [bool]$AllowMigration -or
        [bool]$ForceProtectedMigration
    )

    if (-not $migrationApproved) {

        if ($Unattended) {

            [Result]$result = [Result]::Success(
                $Package
            )

            $result.Code =
                'PHX_UPDATE_MIGRATION_SKIPPED'

            $result.Message = (
                "$($Package.Id) requires migration, but it was " +
                'skipped in unattended mode. Use -AllowMigration ' +
                'to permit eligible migrations.'
            )

            return $result
        }

        try {

            [System.Management.Automation.Host.ChoiceDescription[]]$choices = @(
                [System.Management.Automation.Host.ChoiceDescription]::new(
                    '&No',
                    'Leave the existing installation unchanged.'
                )
                [System.Management.Automation.Host.ChoiceDescription]::new(
                    '&Yes',
                    'Uninstall the existing package and reinstall it using WinGet.'
                )
            )

            [int]$choice =
                $Host.UI.PromptForChoice(
                    'Phoenix package migration',
                    (
                        "$($Package.Id) cannot be upgraded in place because " +
                        'its installer technology changed. Uninstall and reinstall it now?'
                    ),
                    $choices,
                    0
                )

            $migrationApproved = ($choice -eq 1)
        }
        catch {

            [Result]$result = [Result]::Success(
                $Package
            )

            $result.Code =
                'PHX_UPDATE_MIGRATION_SKIPPED'

            $result.Message = (
                "$($Package.Id) requires migration, but Phoenix " +
                'could not display an interactive confirmation prompt. ' +
                'Use -AllowMigration to approve eligible migrations.'
            )

            $result.Warnings = @(
                $_.Exception.Message
            )

            return $result
        }
    }

    if (-not $migrationApproved) {

        [Result]$result = [Result]::Success(
            $Package
        )

        $result.Code =
            'PHX_UPDATE_MIGRATION_SKIPPED'

        $result.Message = (
            "$($Package.Id) migration was declined; the existing " +
            'installation was left unchanged.'
        )

        return $result
    }

    Write-Host ''
    Write-Host (
        "Migrating $($Package.Name) [$($Package.Id)]..."
    ) -ForegroundColor Yellow

    Write-Host (
        'Phoenix will uninstall the existing package and reinstall it.'
    ) -ForegroundColor Yellow

    Write-PhoenixLog `
        -Level Warning `
        -Message (
            "Starting installer-technology migration for $($Package.Id)."
        )

    [Result]$removeResult =
        $Provider.RemovePackage(
            $Package
        )

    if (
        $null -eq $removeResult -or
        -not $removeResult.Success
    ) {

        [string]$removeMessage =
            'The existing package could not be removed.'

        if (
            $null -ne $removeResult -and
            -not [string]::IsNullOrWhiteSpace(
                $removeResult.Message
            )
        ) {
            $removeMessage = $removeResult.Message
        }

        [Result]$result = [Result]::Failure(
            (
                "Migration failed while removing '$($Package.Id)': " +
                $removeMessage
            )
        )

        $result.Code =
            'PHX_UPDATE_MIGRATION_REMOVE_FAILED'

        $result.Data = $Package

        if ($null -ne $removeResult) {
            $result.Errors = @(
                $removeResult.Errors
            )
        }

        return $result
    }

    [Result]$installResult =
        $Provider.InstallPackage(
            $Package,
            [PhoenixInstallMode]::SilentPreferred
        )

    if (
        $null -eq $installResult -or
        -not $installResult.Success
    ) {

        [string]$installMessage =
            'The replacement package could not be installed.'

        if (
            $null -ne $installResult -and
            -not [string]::IsNullOrWhiteSpace(
                $installResult.Message
            )
        ) {
            $installMessage = $installResult.Message
        }

        [Result]$result = [Result]::Failure(
            (
                "Migration removed '$($Package.Id)' but the " +
                "reinstallation failed: $installMessage"
            )
        )

        $result.Code =
            'PHX_UPDATE_MIGRATION_INSTALL_FAILED'

        $result.Data = $Package

        $result.Warnings = @(
            'The previous installation was removed. Manual recovery may be required.'
        )

        if ($null -ne $installResult) {
            $result.Errors = @(
                $installResult.Errors
            )
        }

        return $result
    }

    [Result]$result = [Result]::Success(
        $Package
    )

    $result.Code = 'PHX_UPDATED_MIGRATED'
    $result.Message = (
        "$($Package.Id) was migrated successfully by uninstalling " +
        'the previous installer technology and reinstalling the package.'
    )

    $result.Warnings = @(
        $removeResult.Warnings
        $installResult.Warnings
    ) | Where-Object {
        $null -ne $_ -and
        -not [string]::IsNullOrWhiteSpace(
            $_.ToString()
        )
    }

    Write-PhoenixLog `
        -Level Success `
        -Message (
            "Completed installer-technology migration for $($Package.Id)."
        )

    return $result
}
