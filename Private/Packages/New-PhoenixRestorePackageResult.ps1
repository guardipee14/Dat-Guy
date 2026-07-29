function New-PhoenixRestorePackageResult {

    [CmdletBinding()]
    [OutputType([Result])]
    param(
        [Parameter(Mandatory)]
        [Package]$Package,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Code,

        [Parameter(Mandatory)]
        [bool]$Success,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ProviderCode = '',

        [Parameter()]
        [object[]]$Warnings = @(),

        [Parameter()]
        [object[]]$Errors = @()
    )

    [Result]$result = if ($Success) {
        [Result]::Success()
    }
    else {
        [Result]::Failure($Message)
    }

    $result.Success = $Success
    $result.Code = $Code
    $result.Message = $Message
    $result.Warnings = @($Warnings)
    $result.Errors = @($Errors)

    $result.Data = [pscustomobject]@{
        Stage              = 'RestorePackage'
        Id                 = $Package.Id
        Name               = $Package.Name
        Provider           = $Package.Provider
        Version            = $Package.Version
        InstallerType      = $Package.InstallerType
        ProviderResultCode = $ProviderCode
    }

    return $result
}
