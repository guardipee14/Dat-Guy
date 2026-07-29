##########################################################
## Method: NewFailure
## Legacy source line: 275
##########################################################

hidden [Result] NewFailure(
        [string]$Message,
        [string]$Code
    ) {

        $result = [Result]::Failure($Message)
        $result.Code = $Code

        return $result
    }

