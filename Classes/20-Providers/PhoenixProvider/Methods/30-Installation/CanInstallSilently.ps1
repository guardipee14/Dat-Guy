##########################################################
## Method: CanInstallSilently
## Legacy source line: 286
##########################################################

[bool] CanInstallSilently([Package]$Package) {

        return $this.SupportsSilentInstall
    }

