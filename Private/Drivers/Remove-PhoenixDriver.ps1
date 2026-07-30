function Remove-PhoenixDriver {

    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'High'
    )]
    [OutputType([Result[]])]
    param(
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$InfName
    )

    $results =
        [System.Collections.Generic.List[Result]]::new()

    $resolvedInfNames = @(
        $InfName |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )

    if ($resolvedInfNames.Count -eq 0) {

        [Result]$result = [Result]::Failure(
            'Select at least one installed third-party driver package.'
        )

        $result.Code =
            'PHX_DRIVER_REMOVE_SELECTION_REQUIRED'

        return @($result)
    }

    if (
        -not (
            Test-PhoenixPrivilege `
                -RequiredPrivilege (
                    [PhoenixPrivilegeLevel]::Administrator
                )
        )
    ) {

        [Result]$result = [Result]::Failure(
            'Administrator privileges are required to uninstall driver packages.'
        )

        $result.Code =
            'PHX_DRIVER_REMOVE_ADMIN_REQUIRED'

        return @($result)
    }

    [string]$pnputilPath =
        Join-Path `
            $env:WINDIR `
            'System32\pnputil.exe'

    if (-not (Test-Path -LiteralPath $pnputilPath)) {

        [Result]$result = [Result]::Failure(
            "PnPUtil was not found: $pnputilPath"
        )

        $result.Code =
            'PHX_DRIVER_TOOL_NOT_FOUND'

        return @($result)
    }

    foreach ($resolvedInfName in $resolvedInfNames) {

        if ($resolvedInfName -notmatch '^(?i:oem\d+\.inf)$') {

            [Result]$result = [Result]::Failure(
                (
                    "Driver package '$resolvedInfName' was not removed. " +
                    'Phoenix only removes third-party oem#.inf packages.'
                )
            )

            $result.Code =
                'PHX_DRIVER_REMOVE_PROTECTED'

            $result.Data = [pscustomobject]@{
                Stage   = 'DriverRemoval'
                InfName = $resolvedInfName
            }

            $results.Add($result)
            continue
        }

        if (
            -not $PSCmdlet.ShouldProcess(
                $resolvedInfName,
                'Uninstall devices and remove third-party driver package'
            )
        ) {

            [Result]$result = [Result]::Success()
            $result.Code =
                'PHX_DRIVER_REMOVE_SKIPPED'

            $result.Message = (
                "Driver removal was skipped for '$resolvedInfName'."
            )

            $result.Data = [pscustomobject]@{
                Stage   = 'DriverRemoval'
                InfName = $resolvedInfName
            }

            $results.Add($result)
            continue
        }

        Write-PhoenixLog `
            -Level Warning `
            -Message (
                "Uninstalling third-party driver package '$resolvedInfName'."
            )

        $output = @(
            & $pnputilPath `
                /delete-driver `
                $resolvedInfName `
                /uninstall `
                2>&1
        )

        [int]$exitCode = $LASTEXITCODE

        [string[]]$outputText = @(
            $output |
                ForEach-Object {
                    [string]$_
                }
        )

        [bool]$rebootRequired =
            $exitCode -in @(1641, 3010) -or
            (
                $outputText -join
                    [Environment]::NewLine
            ) -match '(?i:restart|reboot)'

        if ($exitCode -in @(0, 1641, 3010)) {

            [Result]$result = [Result]::Success()
            $result.Code =
                'PHX_DRIVER_REMOVE_COMPLETE'

            $result.Message = (
                "Driver package '$resolvedInfName' was uninstalled."
            )

            Write-PhoenixLog `
                -Level Success `
                -Message $result.Message
        }
        else {

            [Result]$result = [Result]::Failure(
                (
                    "Driver package '$resolvedInfName' could not be removed " +
                    "because PnPUtil exited with code $exitCode."
                )
            )

            $result.Code =
                'PHX_DRIVER_REMOVE_FAILED'

            $result.Errors = @($outputText)

            Write-PhoenixLog `
                -Level Error `
                -Message $result.Message
        }

        $result.Data = [pscustomobject]@{
            Stage          = 'DriverRemoval'
            InfName        = $resolvedInfName
            ExitCode       = $exitCode
            RebootRequired = $rebootRequired
            Output         = @($outputText)
        }

        $results.Add($result)
    }

    return $results.ToArray()
}
