##########################################################
## Method: UpdateProvider
## Legacy source line: 46
##########################################################

[Result] UpdateProvider() {

        winget source update | Out-Null

        return [Result]::Success(
            "WinGet sources updated."
        )

    }

