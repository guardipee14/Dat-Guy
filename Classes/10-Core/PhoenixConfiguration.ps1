class PhoenixConfiguration {

    [string]$ConfigDirectory
    [string]$ConfigFile
    [hashtable]$Settings

    PhoenixConfiguration([string]$ProjectRoot) {

        $this.ConfigDirectory =
            Join-Path $ProjectRoot 'Config'

        $this.ConfigFile =
            Join-Path $this.ConfigDirectory 'Phoenix.json'

        $this.Settings = @{}
    }

    [void] Load() {

        if (Test-Path $this.ConfigFile) {

            [object]$jsonObject =
                Get-Content $this.ConfigFile -Raw |
                    ConvertFrom-Json

            $this.Settings = @{}

            foreach ($property in $jsonObject.PSObject.Properties) {
                $this.Settings[$property.Name] = $property.Value
            }
        }
    }

    [void] Save() {

        if (-not (Test-Path $this.ConfigDirectory)) {

            New-Item `
                -ItemType Directory `
                -Path $this.ConfigDirectory `
                -Force |
                Out-Null
        }

        $this.Settings |
            ConvertTo-Json -Depth 10 |
            Set-Content $this.ConfigFile
    }

    [object] Get([string]$Name) {

        return $this.Settings[$Name]
    }

    [void] Set(
        [string]$Name,
        [object]$Value
    ) {

        $this.Settings[$Name] = $Value
    }
}