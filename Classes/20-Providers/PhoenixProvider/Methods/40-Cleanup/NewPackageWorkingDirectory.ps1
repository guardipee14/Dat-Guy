##########################################################
## Method: NewPackageWorkingDirectory
## Legacy source line: 106
##########################################################

hidden [string] NewPackageWorkingDirectory(
    [Package]$Package
) {

    $context = Get-PhoenixContext

    if ($null -eq $context) {
        throw 'Phoenix context is unavailable.'
    }

    [string]$safePackageId = [regex]::Replace(
        $Package.Id,
        '[^a-zA-Z0-9._-]',
        '_'
    )

    [string]$directoryName = '{0}-{1}' -f `
        $safePackageId,
        [guid]::NewGuid().ToString('N')

    [string]$workingDirectory = Join-Path `
        $context.WorkingRoot `
        $directoryName

    New-Item `
        -ItemType Directory `
        -Path $workingDirectory `
        -Force |
        Out-Null

    $Package.WorkingDirectory = $workingDirectory

    $Package.CleanupPaths = @(
        $Package.CleanupPaths
    ) + @(
        $workingDirectory
    )

    return $workingDirectory
}

