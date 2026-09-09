using module '..\Classes\Phoenix.Classes.psm1'

function Get-PhoenixDeploymentPrerequisite {

    [CmdletBinding()]
    [OutputType([PhoenixDeploymentReadiness])]
    param(
        [Parameter()]
        [ValidateSet('x64')]
        [string]$Architecture = 'x64',

        [Parameter()]
        [AllowEmptyString()]
        [string]$KitsRoot = '',

        [Parameter()]
        [AllowEmptyString()]
        [string]$WinPERoot = '',

        [Parameter()]
        [AllowEmptyString()]
        [string]$HostArchitecture = ''
    )

    $result =
        New-Object -TypeName PhoenixDeploymentReadiness

    $result.Architecture = $Architecture

    if ([string]::IsNullOrWhiteSpace($HostArchitecture)) {
        $HostArchitecture =
            [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    }

    $result.HostArchitecture = $HostArchitecture
    $result.HostSupported =
        $IsWindows -and $HostArchitecture -match '^(?i:x64|amd64)$'

    if ([string]::IsNullOrWhiteSpace($KitsRoot) -and $IsWindows) {
        try {
            $installedRoots =
                Get-ItemProperty `
                    -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' `
                    -ErrorAction Stop

            $KitsRoot = [string]$installedRoots.KitsRoot10
        }
        catch {
            $result.Warnings = @(
                $result.Warnings
                'Windows Kits registry discovery did not find KitsRoot10.'
            )
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($KitsRoot)) {
        $result.AdkRoot = [IO.Path]::GetFullPath($KitsRoot)
    }

    if ([string]::IsNullOrWhiteSpace($WinPERoot) -and -not [string]::IsNullOrWhiteSpace($result.AdkRoot)) {
        $WinPERoot =
            Join-Path `
                $result.AdkRoot `
                'Assessment and Deployment Kit\Windows Preinstallation Environment'
    }

    if (-not [string]::IsNullOrWhiteSpace($WinPERoot)) {
        $result.WinPERoot = [IO.Path]::GetFullPath($WinPERoot)
    }

    [string]$deploymentToolsRoot =
        if ([string]::IsNullOrWhiteSpace($result.AdkRoot)) {
            ''
        }
        else {
            Join-Path $result.AdkRoot 'Assessment and Deployment Kit\Deployment Tools'
        }

    [string]$architectureFolder = 'amd64'

    $requirements = @(
        [pscustomobject]@{
            Name = 'ADK DISM'
            Path = if ($deploymentToolsRoot) { Join-Path $deploymentToolsRoot "$architectureFolder\DISM\dism.exe" } else { '' }
            Required = $true
        }
        [pscustomobject]@{
            Name = 'Oscdimg'
            Path = if ($deploymentToolsRoot) { Join-Path $deploymentToolsRoot "$architectureFolder\Oscdimg\oscdimg.exe" } else { '' }
            Required = $true
        }
        [pscustomobject]@{
            Name = 'WinPE base image'
            Path = if ($result.WinPERoot) { Join-Path $result.WinPERoot "$architectureFolder\en-us\winpe.wim" } else { '' }
            Required = $true
        }
        [pscustomobject]@{
            Name = 'WinPE media root'
            Path = if ($result.WinPERoot) { Join-Path $result.WinPERoot "$architectureFolder\Media" } else { '' }
            Required = $true
        }
        [pscustomobject]@{
            Name = 'WinPE optional components'
            Path = if ($result.WinPERoot) { Join-Path $result.WinPERoot "$architectureFolder\WinPE_OCs" } else { '' }
            Required = $false
        }
    )

    foreach ($requirement in $requirements) {
        $status =
            New-Object -TypeName PhoenixDeploymentToolStatus

        $status.Name = $requirement.Name
        $status.Path = [string]$requirement.Path
        $status.Required = [bool]$requirement.Required
        $status.Available =
            -not [string]::IsNullOrWhiteSpace($status.Path) -and
            (Test-Path -LiteralPath $status.Path)

        if ($status.Available -and (Test-Path -LiteralPath $status.Path -PathType Leaf)) {
            try {
                $status.Version =
                    [Diagnostics.FileVersionInfo]::GetVersionInfo($status.Path).FileVersion
            }
            catch {
                $status.Version = ''
            }
        }

        $status.Message =
            if ($status.Available) {
                "Available at '$($status.Path)'."
            }
            elseif ($status.Required) {
                "Required prerequisite was not found at '$($status.Path)'."
            }
            else {
                "Optional prerequisite was not found at '$($status.Path)'."
            }

        $result.AddTool($status)
    }

    $result.Complete()
    return $result
}
