class PhoenixLogger {

    [string]$LogDirectory
    [string]$LogFile
    [string]$MinimumLevel
    [int]$MaximumLogFiles

    hidden [bool]$RetentionApplied

    PhoenixLogger([string]$ProjectRoot) {

        $this.LogDirectory =
            Join-Path `
                $ProjectRoot `
                'Logs'

        if (-not (Test-Path -LiteralPath $this.LogDirectory)) {

            New-Item `
                -ItemType Directory `
                -Path $this.LogDirectory `
                -Force |
                Out-Null
        }

        $this.LogFile =
            Join-Path `
                $this.LogDirectory `
                (
                    'Phoenix-{0}.log' -f
                    (
                        Get-Date `
                            -Format 'yyyyMMdd-HHmmss-fff'
                    )
                )

        $this.MinimumLevel = 'Info'
        $this.MaximumLogFiles = 20
        $this.RetentionApplied = $false
    }

    [void] Configure(
        [string]$MinimumLevel,
        [int]$MaximumLogFiles
    ) {

        if (
            $this.GetLevelRank($MinimumLevel, $true) -lt 0
        ) {
            throw [ArgumentException]::new(
                "Unsupported Phoenix minimum log level '$MinimumLevel'."
            )
        }

        if ($MaximumLogFiles -lt 1) {
            throw [ArgumentOutOfRangeException]::new(
                'MaximumLogFiles',
                'MaximumLogFiles must be at least 1.'
            )
        }

        $this.MinimumLevel =
            $this.NormalizeLevel($MinimumLevel)

        $this.MaximumLogFiles = $MaximumLogFiles
    }

    [void] Write(
        [string]$Level,
        [string]$Message
    ) {

        [int]$levelRank =
            $this.GetLevelRank($Level, $false)

        if ($levelRank -lt 0) {
            throw [ArgumentException]::new(
                "Unsupported Phoenix log level '$Level'."
            )
        }

        if ([string]::IsNullOrWhiteSpace($Message)) {
            throw [ArgumentException]::new(
                'Phoenix log messages cannot be empty.'
            )
        }

        [int]$minimumRank =
            $this.GetLevelRank(
                $this.MinimumLevel,
                $true
            )

        if ($levelRank -lt $minimumRank) {
            return
        }

        [string]$normalizedLevel =
            $this.NormalizeLevel($Level)

        [string]$line = (
            '[{0}] [{1}] {2}' -f
            (
                Get-Date `
                    -Format 'yyyy-MM-dd HH:mm:ss'
            ),
            $normalizedLevel.ToUpperInvariant(),
            $Message
        )

        Add-Content `
            -LiteralPath $this.LogFile `
            -Value $line `
            -Encoding UTF8 `
            -ErrorAction Stop

        if (-not $this.RetentionApplied) {
            $this.ApplyRetention()
        }
    }

    hidden [void] ApplyRetention() {

        $this.RetentionApplied = $true

        [string]$currentLogPath =
            [IO.Path]::GetFullPath($this.LogFile)

        [object[]]$previousLogs = @(
            Get-ChildItem `
                -LiteralPath $this.LogDirectory `
                -Filter 'Phoenix-*.log' `
                -File `
                -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Name -match (
                        '^Phoenix-\d{8}-\d{6}(?:-\d{3})?\.log$'
                    ) -and
                    [IO.Path]::GetFullPath($_.FullName) -ne
                        $currentLogPath
                } |
                Sort-Object `
                    -Property @(
                        @{
                            Expression = {
                                $_.LastWriteTimeUtc
                            }
                            Descending = $true
                        }
                        @{
                            Expression = {
                                $_.Name
                            }
                            Descending = $true
                        }
                    )
        )

        [int]$previousLogsToKeep =
            $this.MaximumLogFiles - 1

        [object[]]$expiredLogs = @(
            $previousLogs |
                Select-Object `
                    -Skip $previousLogsToKeep
        )

        foreach ($expiredLog in $expiredLogs) {

            try {
                Remove-Item `
                    -LiteralPath $expiredLog.FullName `
                    -Force `
                    -ErrorAction Stop
            }
            catch {
                Write-Warning (
                    "Could not remove expired Phoenix log '{0}': {1}" -f
                    $expiredLog.FullName,
                    $_.Exception.Message
                )
            }
        }
    }

    hidden [int] GetLevelRank(
        [string]$Level,
        [bool]$MinimumLevel
    ) {

        if ([string]::IsNullOrWhiteSpace($Level)) {
            return -1
        }

        switch ($Level.Trim().ToUpperInvariant()) {
            'DEBUG' {
                return 0
            }
            'VERBOSE' {
                return 1
            }
            'INFO' {
                return 2
            }
            'SUCCESS' {

                if ($MinimumLevel) {
                    return -1
                }

                return 2
            }
            'WARNING' {
                return 3
            }
            'ERROR' {
                return 4
            }
            default {
                return -1
            }
        }

        return -1
    }

    hidden [string] NormalizeLevel([string]$Level) {

        switch ($Level.Trim().ToUpperInvariant()) {
            'DEBUG' {
                return 'Debug'
            }
            'VERBOSE' {
                return 'Verbose'
            }
            'INFO' {
                return 'Info'
            }
            'SUCCESS' {
                return 'Success'
            }
            'WARNING' {
                return 'Warning'
            }
            'ERROR' {
                return 'Error'
            }
            default {
                throw [ArgumentException]::new(
                    "Unsupported Phoenix log level '$Level'."
                )
            }
        }

        return ''
    }
}