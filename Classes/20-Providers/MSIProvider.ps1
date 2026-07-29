class SomeProvider : PhoenixProvider {

    SomeProvider() {

        $this.Name = "SomeProvider"
        $this.Priority = 0
        $this.Available = $this.TestAvailable()

    }

    [bool] TestAvailable() {

        return $false

    }

    [Result] InstallProvider() {

        return [Result]::Failure("Not implemented.")

    }

    [Result] UpdateProvider() {

        return [Result]::Failure("Not implemented.")

    }

    [Package[]] GetInstalledPackages() {

        return @()

    }

    [Package[]] SearchPackage([string]$Name) {

        return @()

    }

    [Result] InstallPackage([Package]$Package) {

        return [Result]::Failure("Not implemented.")

    }

    [Result] UpdatePackage([Package]$Package) {

        return [Result]::Failure("Not implemented.")

    }

    [Result] RemovePackage([Package]$Package) {

        return [Result]::Failure("Not implemented.")

    }

}