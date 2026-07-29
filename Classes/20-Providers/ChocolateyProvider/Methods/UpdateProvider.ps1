##########################################################
## Method: UpdateProvider
## Legacy source line: 276
##########################################################

[Result] UpdateProvider() {

        choco upgrade chocolatey -y

        return [Result]::Success(
            "Chocolatey updated."
        )

    }

