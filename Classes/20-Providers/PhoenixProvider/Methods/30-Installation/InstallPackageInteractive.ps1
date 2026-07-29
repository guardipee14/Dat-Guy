##########################################################
## Method: InstallPackageInteractive
## Legacy source line: 299
##########################################################

[Result] InstallPackageInteractive([Package]$Package) {

        return $this.NewFailure(
            "$($this.Name) does not implement interactive installation.",
            'PHX_INTERACTIVE_UNAVAILABLE'
        )
    }

