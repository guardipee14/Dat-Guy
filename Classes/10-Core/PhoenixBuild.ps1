class PhoenixBuild {

    [datetime]$StartTime
    [datetime]$EndTime

    [string]$Version
    [string]$Status

    PhoenixBuild() {

        $this.StartTime = Get-Date
        $this.Version = '0.1.0-alpha'
        $this.Status = 'Running'

    }

    [void] Finish() {

        $this.EndTime = Get-Date
        $this.Status = 'Completed'

    }

}