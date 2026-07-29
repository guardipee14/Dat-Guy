##########################################################
## Method: InstallPackageSilent
## Legacy source line: 291
##########################################################

[Result] InstallPackageSilent([Package]$Package) {

        return $this.NewFailure(
            "$($this.Name) does not implement silent installation.",
            'PHX_SILENT_UNAVAILABLE'
        )
    }

