##########################################################
## Method: InstallProvider
## Legacy source line: 74
##########################################################

[Result] InstallProvider() {

        return [Result]::Failure(
            "$($this.Name) cannot install itself."
        )

    }

