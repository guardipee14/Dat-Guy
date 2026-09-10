function New-PhoenixRestrictedAnswerFile {
    [CmdletBinding()]
    [OutputType([IO.FileStream])]
    param([Parameter(Mandatory)][string]$Path)
    if (-not $IsWindows) { throw 'Windows access controls are required for answer files.' }
    Test-PhoenixPathAncestors -Path $Path
    $security=[Security.AccessControl.FileSecurity]::new()
    $security.SetAccessRuleProtection($true,$false)
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        foreach ($sid in @($identity.User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
            $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','Allow'))
        }
        # CreateNew with the DACL applied atomically: no inherited broad-access interval.
        return [IO.FileSystemAclExtensions]::Create(
            [IO.FileInfo]::new($Path),[IO.FileMode]::CreateNew,
            [Security.AccessControl.FileSystemRights]::FullControl,[IO.FileShare]::None,
            4096,[IO.FileOptions]::None,$security)
    }
    finally { $identity.Dispose() }
}
