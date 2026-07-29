##########################################################
## Helper: GetChocolateyExecutable
##########################################################

hidden [string] GetChocolateyExecutable() {

    $command = Get-Command `
        choco.exe `
        -ErrorAction SilentlyContinue

    if ($null -ne $command) {
        return $command.Source
    }

    [string]$installRoot =
        $env:ChocolateyInstall

    if ([string]::IsNullOrWhiteSpace($installRoot)) {

        $installRoot = Join-Path `
            $env:ProgramData `
            'chocolatey'
    }

    [string]$chocoExecutable = Join-Path `
        $installRoot `
        'bin\choco.exe'

    if (Test-Path -LiteralPath $chocoExecutable) {
        return $chocoExecutable
    }

    return ''
}