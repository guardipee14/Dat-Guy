class PhoenixProviderResult {

    [string]$ProviderName
    [PhoenixProviderOperation]$Operation
    [string]$Target
    [bool]$Success
    [string]$Code
    [string]$Message
    [object]$Data
    [string[]]$Warnings
    [string[]]$Errors
    [PhoenixPrivilegeLevel]$RequiredPrivilege
    [bool]$RequiresRestart
    [bool]$TimedOut
    [bool]$Cancelled
    [bool]$HasExitCode
    [int]$ExitCode
    [datetime]$Timestamp

    PhoenixProviderResult() {

        $this.ProviderName = ''
        $this.Target = ''
        $this.Code = ''
        $this.Message = ''
        $this.Warnings = @()
        $this.Errors = @()
        $this.RequiredPrivilege =
            [PhoenixPrivilegeLevel]::User
        $this.Timestamp = [datetime]::UtcNow
    }
}
