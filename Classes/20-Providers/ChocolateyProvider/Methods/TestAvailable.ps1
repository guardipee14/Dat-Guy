##########################################################
## Method: TestAvailable
##########################################################

[bool] TestAvailable() {

    $command = Get-Command `
        choco.exe `
        -ErrorAction SilentlyContinue

    if ($null -ne $command) {

        try {

            & $command.Source --version *> $null

            if ($LASTEXITCODE -eq 0) {
                return $true
            }
        }
        catch {
            return $false
        }
    }

    $installRoot = $env:ChocolateyInstall

    if ([string]::IsNullOrWhiteSpace($installRoot)) {

        $installRoot = Join-Path `
            $env:ProgramData `
            'chocolatey'
    }

    $chocoExecutable = Join-Path `
        $installRoot `
        'bin\choco.exe'

    if (-not (Test-Path -LiteralPath $chocoExecutable)) {
        return $false
    }

    try {

        & $chocoExecutable --version *> $null

        return $LASTEXITCODE -eq 0
    }
    catch {

        return $false
    }
}