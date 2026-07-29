##########################################################
## Method: InstallPackage
## Legacy source line: 307
##########################################################

[Result] InstallPackage([Package]$Package) {

    return $this.InstallPackage(
        $Package,
        [PhoenixInstallMode]::SilentPreferred
    )
}

