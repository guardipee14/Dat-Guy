class ScoopProvider : PhoenixProvider {

    ScoopProvider() {
        $this.Name = 'Scoop'
        $this.Type = 'Package Manager'
        $this.Priority = 85
        $this.RequiredPrivilege = [PhoenixPrivilegeLevel]::User
        $this.SupportsSilentInstall = $true
        $this.SupportsInteractiveInstall = $false
        $this.SupportsRepair = $false
        $this.SupportsSilentRepair = $false
        $this.SupportsInteractiveRepair = $false
        $this.SupportsExport = $true
        $this.SupportsRestore = $true
        $this.Available = $this.TestAvailable()
    }

    [bool] TestAvailable() {
        return $null -ne (
            Get-Command scoop -ErrorAction SilentlyContinue
        )
    }

    [Result] InstallProvider() {
        if ($this.TestAvailable()) {
            $this.Available = $true

            $existingResult = [Result]::Success()
            $existingResult.Code =
                'PHX_PROVIDER_ALREADY_AVAILABLE'
            $existingResult.Message =
                'Scoop is already installed.'
            $existingResult.Provider = $this.Name
            $existingResult.Operation = 'InstallProvider'
            $existingResult.Target = 'Scoop'

            return $existingResult
        }

        [string]$installerUri =
            'https://get.scoop.sh'

        [string]$temporaryRoot =
            Join-Path `
                ([IO.Path]::GetTempPath()) `
                (
                    'Phoenix-Scoop-{0}' -f
                    [guid]::NewGuid().ToString('N')
                )

        [string]$installerPath =
            Join-Path $temporaryRoot 'install.ps1'

        [string]$wrapperPath =
            Join-Path $temporaryRoot 'invoke-install.ps1'

        [string]$standardOutputPath =
            Join-Path $temporaryRoot 'stdout.log'

        [string]$standardErrorPath =
            Join-Path $temporaryRoot 'stderr.log'

        try {
            $null =
                New-Item `
                    -ItemType Directory `
                    -Path $temporaryRoot `
                    -Force `
                    -ErrorAction Stop

            Invoke-WebRequest `
                -Uri $installerUri `
                -OutFile $installerPath `
                -UseBasicParsing `
                -MaximumRedirection 5 `
                -TimeoutSec 60 `
                -ErrorAction Stop

            if (
                -not (
                    Test-Path `
                        -LiteralPath $installerPath `
                        -PathType Leaf
                ) -or
                (Get-Item -LiteralPath $installerPath).Length -le 0
            ) {
                return $this.NewFailure(
                    'The Scoop installer download was empty.',
                    'PHX_PROVIDER_DOWNLOAD_FAILED'
                )
            }

            [string]$powerShellPath =
                [Environment]::ProcessPath

            if (
                [string]::IsNullOrWhiteSpace(
                    $powerShellPath
                ) -or
                -not (
                    Test-Path `
                        -LiteralPath $powerShellPath `
                        -PathType Leaf
                )
            ) {
                $powerShellCommand =
                    Get-Command `
                        pwsh.exe `
                        -ErrorAction SilentlyContinue

                if ($null -eq $powerShellCommand) {
                    $powerShellCommand =
                        Get-Command `
                            powershell.exe `
                            -ErrorAction SilentlyContinue
                }

                if ($null -eq $powerShellCommand) {
                    return $this.NewFailure(
                        'A PowerShell executable was not found.',
                        'PHX_PROVIDER_INSTALL_ENGINE_MISSING'
                    )
                }

                $powerShellPath =
                    [string]$powerShellCommand.Source
            }

            [bool]$isAdministrator =
                [Security.Principal.WindowsPrincipal]::new(
                    [Security.Principal.WindowsIdentity]::
                        GetCurrent()
                ).IsInRole(
                    [Security.Principal.WindowsBuiltInRole]::
                        Administrator
                )

            [string]$escapedInstallerPath =
                $installerPath.Replace(
                    "'",
                    "''"
                )

            [string]$wrapperText =
                if ($isAdministrator) {
                    @"
`$ErrorActionPreference = 'Stop'
& '$escapedInstallerPath' -RunAsAdmin
exit `$LASTEXITCODE
"@
                }
                else {
                    @"
`$ErrorActionPreference = 'Stop'
& '$escapedInstallerPath'
exit `$LASTEXITCODE
"@
                }

            [IO.File]::WriteAllText(
                $wrapperPath,
                $wrapperText,
                [Text.UTF8Encoding]::new($false)
            )

            $argumentList =
                [System.Collections.Generic.List[string]]::new()

            foreach ($argument in @(
                '-NoLogo'
                '-NoProfile'
                '-NonInteractive'
                '-ExecutionPolicy'
                'Bypass'
                '-File'
                ('"{0}"' -f $wrapperPath)
            )) {
                $argumentList.Add($argument)
            }

            $process =
                Start-Process `
                    -FilePath $powerShellPath `
                    -ArgumentList $argumentList.ToArray() `
                    -RedirectStandardOutput $standardOutputPath `
                    -RedirectStandardError $standardErrorPath `
                    -PassThru `
                    -WindowStyle Hidden `
                    -ErrorAction Stop

            [bool]$completed =
                $process.WaitForExit(300000)

            if (-not $completed) {
                try {
                    Stop-Process `
                        -Id $process.Id `
                        -Force `
                        -ErrorAction Stop
                }
                catch {
                }

                return $this.NewFailure(
                    'Scoop installation timed out after five minutes.',
                    'PHX_PROVIDER_INSTALL_TIMEOUT'
                )
            }

            [int]$exitCode =
                [int]$process.ExitCode

            [string]$standardOutput = ''

            if (
                Test-Path `
                    -LiteralPath $standardOutputPath `
                    -PathType Leaf
            ) {
                $standardOutput =
                    Get-Content `
                        -LiteralPath $standardOutputPath `
                        -Raw `
                        -ErrorAction SilentlyContinue
            }

            [string]$standardError = ''

            if (
                Test-Path `
                    -LiteralPath $standardErrorPath `
                    -PathType Leaf
            ) {
                $standardError =
                    Get-Content `
                        -LiteralPath $standardErrorPath `
                        -Raw `
                        -ErrorAction SilentlyContinue
            }

            if ($exitCode -ne 0) {
                [string]$failureMessage =
                    (
                        'Scoop installation failed with exit ' +
                        "code $exitCode."
                    )

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $standardError
                    )
                ) {
                    $failureMessage += (
                        ' ' +
                        $standardError.Trim()
                    )
                }
                elseif (
                    -not [string]::IsNullOrWhiteSpace(
                        $standardOutput
                    )
                ) {
                    $failureMessage += (
                        ' ' +
                        $standardOutput.Trim()
                    )
                }

                $failedResult =
                    $this.NewFailure(
                        $failureMessage,
                        'PHX_PROVIDER_INSTALL_FAILED'
                    )

                $failedResult.HasExitCode = $true
                $failedResult.ExitCode = $exitCode
                $failedResult.Provider = $this.Name
                $failedResult.Operation = 'InstallProvider'
                $failedResult.Target = 'Scoop'
                $failedResult.Errors = @(
                    $standardError
                    $standardOutput
                ) |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace(
                            [string]$_
                        )
                    }

                return $failedResult
            }

            [string]$machinePath =
                [Environment]::GetEnvironmentVariable(
                    'Path',
                    [EnvironmentVariableTarget]::Machine
                )

            [string]$userPath =
                [Environment]::GetEnvironmentVariable(
                    'Path',
                    [EnvironmentVariableTarget]::User
                )

            [string]$processPath =
                [Environment]::GetEnvironmentVariable(
                    'Path',
                    [EnvironmentVariableTarget]::Process
                )

            $pathEntries =
                [System.Collections.Generic.List[string]]::new()

            $seenPathEntries =
                [System.Collections.Generic.HashSet[string]]::new(
                    [StringComparer]::OrdinalIgnoreCase
                )

            foreach ($pathValue in @(
                $machinePath
                $userPath
                $processPath
            )) {
                foreach (
                    $pathEntry in @(
                        [string]$pathValue -split ';'
                    )
                ) {
                    [string]$trimmedEntry =
                        $pathEntry.Trim()

                    if (
                        -not [string]::IsNullOrWhiteSpace(
                            $trimmedEntry
                        ) -and
                        $seenPathEntries.Add($trimmedEntry)
                    ) {
                        $pathEntries.Add($trimmedEntry)
                    }
                }
            }

            [string]$scoopRoot =
                [Environment]::GetEnvironmentVariable(
                    'SCOOP',
                    [EnvironmentVariableTarget]::User
                )

            if (
                [string]::IsNullOrWhiteSpace(
                    $scoopRoot
                )
            ) {
                $scoopRoot =
                    Join-Path `
                        $env:USERPROFILE `
                        'scoop'
            }

            [string]$scoopShimPath =
                Join-Path $scoopRoot 'shims'

            if (
                Test-Path `
                    -LiteralPath $scoopShimPath `
                    -PathType Container
            ) {
                if ($seenPathEntries.Add($scoopShimPath)) {
                    $pathEntries.Add($scoopShimPath)
                }
            }

            [string]$refreshedPath =
                $pathEntries.ToArray() -join ';'

            [Environment]::SetEnvironmentVariable(
                'Path',
                $refreshedPath,
                [EnvironmentVariableTarget]::Process
            )

            $scoopCommand =
                Get-Command `
                    scoop `
                    -ErrorAction SilentlyContinue

            if ($null -eq $scoopCommand) {
                [string]$scoopCommandPath =
                    Join-Path `
                        $scoopShimPath `
                        'scoop.ps1'

                if (
                    Test-Path `
                        -LiteralPath $scoopCommandPath `
                        -PathType Leaf
                ) {
                    $scoopCommand =
                        Get-Command `
                            $scoopCommandPath `
                            -ErrorAction SilentlyContinue
                }
            }

            if ($null -eq $scoopCommand) {
                $verificationResult =
                    $this.NewFailure(
                        (
                            'The Scoop installer exited successfully, ' +
                            'but the scoop command could not be found.'
                        ),
                        'PHX_PROVIDER_INSTALL_VERIFY_FAILED'
                    )

                $verificationResult.HasExitCode = $true
                $verificationResult.ExitCode = $exitCode
                $verificationResult.Provider = $this.Name
                $verificationResult.Operation = 'InstallProvider'
                $verificationResult.Target = 'Scoop'

                return $verificationResult
            }

            $this.Available = $true

            $result = [Result]::Success()
            $result.Code =
                'PHX_PROVIDER_INSTALL_SUCCEEDED'
            $result.Message =
                'Scoop was installed and verified successfully.'
            $result.Provider = $this.Name
            $result.Operation = 'InstallProvider'
            $result.Target =
                [string]$scoopCommand.Source
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode
            $result.Data =
                [pscustomobject]@{
                    InstallerUri = $installerUri
                    PowerShellPath = $powerShellPath
                    RunAsAdmin = $isAdministrator
                    ScoopCommand =
                        [string]$scoopCommand.Source
                    StandardOutput = $standardOutput
                }

            return $result
        }
        catch {
            $exceptionResult =
                $this.NewFailure(
                    (
                        'Scoop installation failed: {0}' -f
                        $_.Exception.Message
                    ),
                    'PHX_PROVIDER_INSTALL_FAILED'
                )

            $exceptionResult.Provider = $this.Name
            $exceptionResult.Operation = 'InstallProvider'
            $exceptionResult.Target = 'Scoop'
            $exceptionResult.Errors = @(
                $_.Exception.Message
            )

            return $exceptionResult
        }
        finally {
            if (
                Test-Path `
                    -LiteralPath $temporaryRoot
            ) {
                Remove-Item `
                    -LiteralPath $temporaryRoot `
                    -Recurse `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }
    }

    [Result] UpdateProvider() {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        return $this.InvokeScoop(
            @('update'),
            'UpdateProvider',
            'Scoop'
        )
    }

    [Package[]] GetInstalledPackages() {
        $packages = [System.Collections.Generic.List[Package]]::new()

        if (-not $this.TestAvailable()) {
            return $packages.ToArray()
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source export 2>$null)

            if ($LASTEXITCODE -ne 0) {
                return $packages.ToArray()
            }

            $exportData = ($output -join [Environment]::NewLine) |
                ConvertFrom-Json -ErrorAction Stop

            foreach ($app in @($exportData.apps)) {
                if ([string]::IsNullOrWhiteSpace([string]$app.Name)) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = [string]$app.Name
                $package.Id = [string]$app.Name
                $package.Version = [string]$app.Version
                $package.Provider = $this.Name
                $package.InstallerType = 'Scoop'
                $package.Source = if (
                    [string]::IsNullOrWhiteSpace([string]$app.Source)
                ) { 'main' } else { [string]$app.Source }
                $package.Installed = $true
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }

        return $packages.ToArray()
    }

    [Package[]] SearchPackage([string]$Name) {
        $packages = [System.Collections.Generic.List[Package]]::new()

        if (
            [string]::IsNullOrWhiteSpace($Name) -or
            -not $this.TestAvailable()
        ) {
            return $packages.ToArray()
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source search $Name 2>$null)
            $seenIds = [System.Collections.Generic.HashSet[string]]::new(
                [StringComparer]::OrdinalIgnoreCase
            )

            foreach ($line in $output) {
                if ([string]$line -notmatch '^\s*([^\s]+)\s+\(([^)]+)\)') {
                    continue
                }

                [string]$id = $Matches[1]

                if (-not $seenIds.Add($id)) {
                    continue
                }

                $package = [Package]::new()
                $package.Name = $id
                $package.Id = $id
                $package.Version = $Matches[2]
                $package.Provider = $this.Name
                $package.InstallerType = 'Scoop'
                $package.Source = 'Scoop'
                $packages.Add($package)
            }
        }
        catch {
            return $packages.ToArray()
        }

        return $packages.ToArray()
    }

    [Result] InstallPackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('install', $Package.Id),
            'Install',
            $Package.Id
        )

        if ($result.Success) {
            $Package.Installed = $true
            $result.Code = 'PHX_INSTALLED'
        }

        $result.Data = $Package
        return $result
    }

    [Result] UpdatePackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('update', $Package.Id),
            'Update',
            $Package.Id
        )
        $result.Data = $Package

        if ($result.Success) {
            $result.Code = 'PHX_UPDATED'
        }

        return $result
    }

    [Result] RemovePackage([Package]$Package) {
        if ($null -eq $Package -or [string]::IsNullOrWhiteSpace($Package.Id)) {
            return $this.NewFailure(
                'A Scoop package ID is required.',
                'PHX_INVALID_PACKAGE'
            )
        }

        $result = $this.InvokeScoop(
            @('uninstall', $Package.Id),
            'Remove',
            $Package.Id
        )
        $result.Data = $Package

        if ($result.Success) {
            $Package.Installed = $false
            $result.Code = 'PHX_REMOVED'
        }

        return $result
    }

    [Result] ExportPackages() {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source export 2>&1)
            [int]$exitCode = $LASTEXITCODE
            $result = if ($exitCode -eq 0) {
                [Result]::Success($output -join [Environment]::NewLine)
            }
            else {
                [Result]::Failure('Scoop export failed.')
            }
            $result.Code = if ($result.Success) {
                'PHX_EXPORTED'
            } else { 'PHX_EXPORT_FAILED' }
            $result.Provider = $this.Name
            $result.Operation = 'Export'
            $result.Target = 'Scoop'
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode

            return $result
        }
        catch {
            return $this.NewFailure(
                "Scoop export failed: $($_.Exception.Message)",
                'PHX_EXPORT_FAILED'
            )
        }
    }

    [Result[]] RestorePackages([Package[]]$Packages) {
        $results = [System.Collections.Generic.List[Result]]::new()

        foreach ($package in @($Packages)) {
            $results.Add($this.InstallPackage($package))
        }

        return $results.ToArray()
    }

    hidden [Result] InvokeScoop(
        [string[]]$ArgumentList,
        [string]$Operation,
        [string]$Target
    ) {
        if (-not $this.TestAvailable()) {
            return $this.NewFailure(
                'Scoop is unavailable.',
                'PHX_PROVIDER_UNAVAILABLE'
            )
        }

        try {
            $command = Get-Command scoop -ErrorAction Stop
            $output = @(& $command.Source @ArgumentList 2>&1)
            [int]$exitCode = $LASTEXITCODE
            $result = if ($exitCode -eq 0) {
                [Result]::Success()
            }
            else {
                [Result]::Failure(
                    "Scoop $Operation failed with exit code $exitCode."
                )
            }
            $result.Code = if ($result.Success) {
                "PHX_$($Operation.ToUpperInvariant())D"
            }
            else {
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            }
            $result.Message = $output -join [Environment]::NewLine
            $result.Provider = $this.Name
            $result.Operation = $Operation
            $result.Target = $Target
            $result.HasExitCode = $true
            $result.ExitCode = $exitCode

            if (-not $result.Success) {
                $result.Errors = @($output)
            }

            return $result
        }
        catch {
            return $this.NewFailure(
                "Scoop $Operation failed: $($_.Exception.Message)",
                "PHX_$($Operation.ToUpperInvariant())_FAILED"
            )
        }
    }
}
