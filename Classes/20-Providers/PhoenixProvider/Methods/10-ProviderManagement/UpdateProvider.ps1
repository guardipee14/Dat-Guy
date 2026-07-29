##########################################################
## Method: UpdateProvider
## Legacy source line: 82
##########################################################

[Result] UpdateProvider() {

        return [Result]::Failure(
            "$($this.Name) cannot update itself."
        )

    }

