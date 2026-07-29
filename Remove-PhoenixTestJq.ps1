$choco = 'C:\ProgramData\chocolatey\bin\choco.exe'

& $choco `
    uninstall `
    jq `
    --yes `
    --no-progress

exit $LASTEXITCODE
