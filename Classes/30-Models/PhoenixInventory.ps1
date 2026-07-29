class PhoenixInventory {

    [datetime]$Timestamp

    [string]$ComputerName

    [string]$UserName

    [hashtable]$Hardware

    [hashtable]$Software

    [hashtable]$Drivers

    [hashtable]$Packages

    [hashtable]$Providers

    PhoenixInventory() {

        $this.Timestamp    = Get-Date
        $this.ComputerName = $env:COMPUTERNAME
        $this.UserName     = $env:USERNAME

        $this.Hardware = @{}
        $this.Software = @{}
        $this.Drivers  = @{}
        $this.Packages = @{}
        $this.Providers = @{}

    }

}