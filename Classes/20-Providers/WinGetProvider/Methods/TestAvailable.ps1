##########################################################
## Method: TestAvailable
## Legacy source line: 30
##########################################################

[bool] TestAvailable() {

        return $null -ne (
            Get-Command winget -ErrorAction SilentlyContinue
        )

    }

