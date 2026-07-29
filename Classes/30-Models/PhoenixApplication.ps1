class PhoenixApplication {

    [string]$Name
    [string]$Version
    [string]$Build
    [datetime]$StartTime

    PhoenixApplication() {

        $this.Name = "Phoenix Deploy"

        $this.Version = "0.1.0-alpha"

        $this.Build = "0001"

        $this.StartTime = Get-Date

    }

}