function Test-PhoenixPrivilege {

    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPrivilegeLevel]$RequiredPrivilege
    )

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        return $false
    }

    if ($RequiredPrivilege -eq [PhoenixPrivilegeLevel]::System) {

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        return $identity.Name -eq 'NT AUTHORITY\SYSTEM'
    }

    return (
        [int]$context.PrivilegeLevel -ge
        [int]$RequiredPrivilege
    )
}