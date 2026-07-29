function Request-PhoenixElevation {

    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [PhoenixPrivilegeLevel]$RequiredPrivilege,

        [Parameter()]
        [string]$Reason =
            'Phoenix requires elevated privileges.',

        [Parameter()]
        [ValidateSet(
            'Install-PhoenixPackage',
            'Remove-PhoenixPackage',
            'Repair-PhoenixPackage',
            'Update-PhoenixPackage',
            'Update-Phoenix'
        )]
        [string]$CommandName,

        [Parameter()]
        [hashtable]$CommandParameters = @{},

        [Parameter()]
        [switch]$WaitForCompletion
    )

    if (
        Test-PhoenixPrivilege `
            -RequiredPrivilege $RequiredPrivilege
    ) {
        return $false
    }

    if (
        $RequiredPrivilege -eq
        [PhoenixPrivilegeLevel]::System
    ) {
        Write-Warning (
            'SYSTEM privilege support has not been implemented.'
        )

        return $false
    }

    $context = $null

    try {
        $context =
            Get-PhoenixContext -ErrorAction Stop
    }
    catch {
        $context = $null
    }

    if ($null -eq $context) {
        Write-Warning 'Phoenix context is unavailable.'
        return $false
    }

    [string]$projectRoot =
        $context.ProjectRoot

    [string]$manifestPath =
        Join-Path `
            $projectRoot `
            'Phoenix.psd1'

    [string]$powerShellPath =
        Join-Path `
            $env:WINDIR `
            'System32\WindowsPowerShell\v1.0\powershell.exe'

    [string]$resultPath = ''

    if ($WaitForCompletion) {

        $resultPath =
            Join-Path `
                ([System.IO.Path]::GetTempPath()) `
                (
                    'Phoenix-Elevated-{0}.clixml' -f
                    [guid]::NewGuid().ToString('N')
                )
    }

    if (-not (Test-Path -LiteralPath $manifestPath)) {

        Write-Warning (
            "Phoenix manifest was not found: $manifestPath"
        )

        return $false
    }

    if (-not (Test-Path -LiteralPath $powerShellPath)) {

        Write-Warning (
            "PowerShell executable was not found: $powerShellPath"
        )

        return $false
    }

    [string]$escapedProjectRoot =
        $projectRoot.Replace("'", "''")

    [string]$escapedManifestPath =
        $manifestPath.Replace("'", "''")

    [string]$escapedReason =
        $Reason.Replace("'", "''")

    [string]$escapedResultPath =
        $resultPath.Replace("'", "''")

    [string]$resumeCommand = ''

    if ([string]::IsNullOrWhiteSpace($CommandName)) {

        $resumeCommand = @"
Set-Location -LiteralPath '$escapedProjectRoot'
Import-Module -Name '$escapedManifestPath' -Force
Start-Phoenix -Resume
"@
    }
    else {

        [hashtable]$payload = @{
            CommandName = $CommandName
            Parameters  = $CommandParameters
        }

        [string]$payloadJson =
            $payload |
                ConvertTo-Json `
                    -Depth 10 `
                    -Compress

        [string]$encodedPayload =
            [Convert]::ToBase64String(
                [Text.Encoding]::UTF8.GetBytes(
                    $payloadJson
                )
            )

        $resumeCommand = @'
Set-Location -LiteralPath '__PROJECT_ROOT__'

$resultPath = '__RESULT_PATH__'
$resultEnvelope = $null

try {

    Import-Module `
        -Name '__MANIFEST_PATH__' `
        -Force `
        -ErrorAction Stop

    Start-Phoenix

    $payloadJson =
        [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String(
                '__PAYLOAD__'
            )
        )

    $payload =
        $payloadJson |
            ConvertFrom-Json

    $commandName =
        [string]$payload.CommandName

    $commandParameters = @{}

    foreach (
        $property in
        $payload.Parameters.PSObject.Properties
    ) {
        $commandParameters[$property.Name] =
            $property.Value
    }

    Write-Host ''
    Write-Host (
        'Phoenix is running with administrator privileges.'
    ) -ForegroundColor Green

    Write-Host (
        'Reason: __REASON__'
    ) -ForegroundColor DarkGray

    Write-Host ''

    $result = @(
        & $commandName @commandParameters
    )

    $resultEnvelope = [pscustomobject]@{
        Completed    = $true
        Results      = @($result)
        ErrorMessage = $null
    }

    Write-Host ''
    Write-Host 'Elevated Phoenix result:' `
        -ForegroundColor Cyan

    $result |
        Format-List `
            Success,
            Code,
            Message,
            Errors,
            Warnings
}
catch {

    $resultEnvelope = [pscustomobject]@{
        Completed    = $false
        Results      = @()
        ErrorMessage = $_.Exception.Message
    }

    Write-Host ''
    Write-Host (
        'Elevated Phoenix command failed:'
    ) -ForegroundColor Red

    $_ |
        Format-List * -Force
}
finally {

    if (
        -not [string]::IsNullOrWhiteSpace(
            $resultPath
        ) -and
        $null -ne $resultEnvelope
    ) {

        try {

            $resultEnvelope |
                Export-Clixml `
                    -LiteralPath $resultPath `
                    -Depth 10
        }
        catch {

            Write-Host (
                "Could not save the elevated result: $($_.Exception.Message)"
            ) -ForegroundColor Red
        }
    }
}

if (
    $null -eq $resultEnvelope -or
    -not $resultEnvelope.Completed
) {
    exit 1
}
'@

        $resumeCommand =
            $resumeCommand.Replace(
                '__PROJECT_ROOT__',
                $escapedProjectRoot
            )

        $resumeCommand =
            $resumeCommand.Replace(
                '__MANIFEST_PATH__',
                $escapedManifestPath
            )

        $resumeCommand =
            $resumeCommand.Replace(
                '__PAYLOAD__',
                $encodedPayload
            )

        $resumeCommand =
            $resumeCommand.Replace(
                '__REASON__',
                $escapedReason
            )

        $resumeCommand =
            $resumeCommand.Replace(
                '__RESULT_PATH__',
                $escapedResultPath
            )
    }

    [string]$encodedCommand =
        [Convert]::ToBase64String(
            [Text.Encoding]::Unicode.GetBytes(
                $resumeCommand
            )
        )

    [string]$argumentString = (
        '-NoLogo -NoProfile ' +
        '-ExecutionPolicy Bypass ' +
        "-EncodedCommand $encodedCommand"
    )

    Write-Host ''
    Write-Host (
        'Administrator privileges are required.'
    ) -ForegroundColor Yellow

    Write-Host (
        'A Windows UAC prompt will appear.'
    ) -ForegroundColor Yellow

    Write-Host ''

    try {

        $process =
            Start-Process `
                -FilePath $powerShellPath `
                -Verb RunAs `
                -WorkingDirectory $projectRoot `
                -ArgumentList $argumentString `
                -PassThru `
                -ErrorAction Stop

        if (-not $WaitForCompletion) {
            return $true
        }

        Write-Host (
            'Waiting for the elevated Phoenix operation to complete...'
        ) -ForegroundColor Cyan

        $process.WaitForExit()

        if (
            [string]::IsNullOrWhiteSpace(
                $resultPath
            ) -or
            -not (
                Test-Path `
                    -LiteralPath $resultPath
            )
        ) {

            return [pscustomobject]@{
                Started      = $true
                Completed    = $false
                ExitCode     = $process.ExitCode
                Results      = @()
                ErrorMessage = (
                    'The elevated process closed without returning a result.'
                )
            }
        }

        $resultEnvelope =
            Import-Clixml `
                -LiteralPath $resultPath

        Remove-Item `
            -LiteralPath $resultPath `
            -Force `
            -ErrorAction SilentlyContinue

        return [pscustomobject]@{
            Started      = $true
            Completed    = [bool]$resultEnvelope.Completed
            ExitCode     = $process.ExitCode
            Results      = @($resultEnvelope.Results)
            ErrorMessage = [string]$resultEnvelope.ErrorMessage
        }
    }
    catch {

        if (
            -not [string]::IsNullOrWhiteSpace(
                $resultPath
            )
        ) {

            Remove-Item `
                -LiteralPath $resultPath `
                -Force `
                -ErrorAction SilentlyContinue
        }

        Write-Warning (
            "Elevation was cancelled or failed: $($_.Exception.Message)"
        )

        if ($WaitForCompletion) {

            return [pscustomobject]@{
                Started      = $false
                Completed    = $false
                ExitCode     = $null
                Results      = @()
                ErrorMessage = $_.Exception.Message
            }
        }

        return $false
    }
}