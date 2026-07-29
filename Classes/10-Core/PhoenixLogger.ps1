class PhoenixLogger {

    [string]$LogDirectory
    [string]$LogFile

    PhoenixLogger([string]$ProjectRoot) {

        $this.LogDirectory = Join-Path $ProjectRoot 'Logs'

        if (-not (Test-Path $this.LogDirectory)) {
            New-Item -ItemType Directory `
                -Path $this.LogDirectory `
                -Force | Out-Null
        }

        $this.LogFile = Join-Path $this.LogDirectory (
            "Phoenix-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss')
        )
    }

    [void] Write(
        [string]$Level,
        [string]$Message
    ) {

        $Line = "[{0}] [{1}] {2}" -f `
            (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
            $Level.ToUpper(),
            $Message

        Add-Content -Path $this.LogFile -Value $Line
    }
}