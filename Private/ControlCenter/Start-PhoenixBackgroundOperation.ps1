function Start-PhoenixBackgroundOperation {

    [CmdletBinding()]
    [OutputType([PhoenixBackgroundOperation])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PhoenixBackgroundOperation]$Operation,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectRoot,

        [Parameter()]
        [AllowNull()]
        [string]$WorkerPath,

        [Parameter()]
        [AllowNull()]
        [string]$PowerShellPath
    )

    if (
        $Operation.State -ne
        [PhoenixBackgroundOperationState]::Created
    ) {
        throw (
            "Operation '$($Operation.OperationId)' cannot start " +
            "from state '$($Operation.State)'."
        )
    }

    [string]$resolvedProjectRoot = (
        Resolve-Path `
            -LiteralPath $ProjectRoot `
            -ErrorAction Stop
    ).Path

    if ([string]::IsNullOrWhiteSpace($WorkerPath)) {
        $WorkerPath =
            Join-Path `
                $resolvedProjectRoot `
                'Tools\Invoke-PhoenixControlCenterWorker.ps1'
    }

    [string]$resolvedWorkerPath = (
        Resolve-Path `
            -LiteralPath $WorkerPath `
            -ErrorAction Stop
    ).Path

    if ([string]::IsNullOrWhiteSpace($PowerShellPath)) {
        $PowerShellPath =
            (Get-Process -Id $PID).Path
    }

    [string]$resolvedPowerShellPath = (
        Resolve-Path `
            -LiteralPath $PowerShellPath `
            -ErrorAction Stop
    ).Path

    foreach (
        $requiredPath in @(
            $Operation.JobDirectory
            $Operation.RequestPath
            $Operation.ProgressPath
            $Operation.ResultPath
        )
    ) {
        if ([string]::IsNullOrWhiteSpace($requiredPath)) {
            throw (
                "Operation '$($Operation.OperationId)' does not " +
                'have a complete job-file contract.'
            )
        }
    }

    $Operation.MarkStarting()

    [string]$temporaryRequestPath = (
        '{0}.{1}.tmp' -f
        $Operation.RequestPath,
        [guid]::NewGuid().ToString('N')
    )

    try {
        [pscustomobject][ordered]@{
            OperationId = $Operation.OperationId
            Action      = $Operation.Action
            Component   = $Operation.Component
            Description = $Operation.Description
            Parameters  = $Operation.Parameters
        } |
            ConvertTo-Json `
                -Depth 20 |
            Set-Content `
                -LiteralPath $temporaryRequestPath `
                -Encoding UTF8 `
                -ErrorAction Stop

        Move-Item `
            -LiteralPath $temporaryRequestPath `
            -Destination $Operation.RequestPath `
            -Force `
            -ErrorAction Stop

        $startInfo =
            [System.Diagnostics.ProcessStartInfo]::new()

        $startInfo.FileName =
            $resolvedPowerShellPath

        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.WorkingDirectory =
            $resolvedProjectRoot

        foreach (
            $argument in @(
                '-NoLogo'
                '-NoProfile'
                '-NonInteractive'
                '-ExecutionPolicy'
                'Bypass'
                '-STA'
                '-File'
                $resolvedWorkerPath
                '-ProjectRoot'
                $resolvedProjectRoot
                '-RequestPath'
                $Operation.RequestPath
                '-ProgressPath'
                $Operation.ProgressPath
                '-ResultPath'
                $Operation.ResultPath
            )
        ) {
            $startInfo.ArgumentList.Add(
                [string]$argument
            )
        }

        $process =
            [System.Diagnostics.Process]::Start(
                $startInfo
            )

        if ($null -eq $process) {
            throw (
                'The background worker process did not start.'
            )
        }

        $Operation.Process =
            $process

        $Operation.MarkRunning()

        return $Operation
    }
    catch {
        if (-not $Operation.IsTerminal()) {
            $Operation.MarkFailed(
                (
                    'The background worker could not be started: {0}' -f
                    $_.Exception.Message
                )
            )
        }

        throw
    }
    finally {
        if (
            Test-Path `
                -LiteralPath $temporaryRequestPath `
                -PathType Leaf
        ) {
            Remove-Item `
                -LiteralPath $temporaryRequestPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}
