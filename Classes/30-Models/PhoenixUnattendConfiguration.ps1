class PhoenixUnattendConfiguration {

    [string]$Schema
    [string]$SchemaVersion
    [string]$Architecture
    [string]$ComputerName
    [string]$InputLocale
    [string]$SystemLocale
    [string]$UiLanguage
    [string]$UserLocale
    [string]$TimeZone
    [string]$ProductKeyPolicy
    [object[]]$LocalAccounts
    [bool]$HideEulaPage
    [bool]$ProtectYourPc

    PhoenixUnattendConfiguration() {
        $this.Schema = 'PhoenixUnattendConfiguration'
        $this.SchemaVersion = '1.0'
        $this.Architecture = 'amd64'
        $this.ComputerName = '*'
        $this.InputLocale = 'en-US'
        $this.SystemLocale = 'en-US'
        $this.UiLanguage = 'en-US'
        $this.UserLocale = 'en-US'
        $this.TimeZone = 'Mountain Standard Time'
        $this.ProductKeyPolicy = 'Prompt'
        $this.LocalAccounts = @()
        $this.HideEulaPage = $false
        $this.ProtectYourPc = $true
    }

    [void] AddLocalAccount([string]$Name, [string]$DisplayName, [string]$Group) {
        if ($Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,19}$' -or
            $Name -in @('Administrator','Guest','DefaultAccount','WDAGUtilityAccount')) {
            throw 'Local account names may contain 1-20 letters, digits, dots, underscores, or hyphens.'
        }

        if ([string]::IsNullOrWhiteSpace($DisplayName)) {
            $DisplayName = $Name
        }

        if ($Group -notin @('Administrators', 'Users')) {
            throw "Unsupported local account group '$Group'."
        }

        foreach ($account in $this.LocalAccounts) {
            if ([string]::Equals([string]$account.Name, $Name, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Local account '$Name' is already configured."
            }
        }

        $this.LocalAccounts = @(
            $this.LocalAccounts
            [pscustomobject]@{
                Name = $Name
                DisplayName = $DisplayName.Trim()
                Group = $Group
            }
        )
    }

    [bool] IsValid() {
        if (
            $this.Schema -cne 'PhoenixUnattendConfiguration' -or
            $this.SchemaVersion -cne '1.0' -or
            $this.Architecture -cne 'amd64' -or
            [string]::IsNullOrWhiteSpace($this.ComputerName) -or
            $this.ComputerName.Length -gt 15 -or
            ($this.ComputerName -ne '*' -and $this.ComputerName -cnotmatch '^[A-Za-z0-9-]+$') -or
            ($this.ComputerName -ne '*' -and $this.ComputerName -notmatch '[A-Za-z]') -or
            $this.ProductKeyPolicy -notin @('Prompt', 'Firmware', 'ProvidedAtDeployment') -or
            [string]::IsNullOrWhiteSpace($this.TimeZone) -or
            $null -eq $this.LocalAccounts
        ) {
            return $false
        }

        foreach ($locale in @($this.InputLocale, $this.SystemLocale, $this.UiLanguage, $this.UserLocale)) {
            if ($locale -cnotmatch '^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})+$') {
                return $false
            }
            try { $null = [Globalization.CultureInfo]::GetCultureInfo($locale) }
            catch { return $false }
        }
        try { $null = [TimeZoneInfo]::FindSystemTimeZoneById($this.TimeZone) }
        catch { return $false }

        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

        foreach ($account in $this.LocalAccounts) {
            if (
                $null -eq $account -or
                [string]$account.Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,19}$' -or
                [string]$account.Name -in @('Administrator','Guest','DefaultAccount','WDAGUtilityAccount') -or
                [string]::IsNullOrWhiteSpace([string]$account.DisplayName) -or
                [string]$account.DisplayName -match '[\x00-\x1f]' -or
                [string]$account.Group -notin @('Administrators', 'Users') -or
                -not $names.Add([string]$account.Name)
            ) {
                return $false
            }
            foreach ($property in $account.PSObject.Properties.Name) {
                if ($property -notin @('Name','DisplayName','Group')) { return $false }
            }
        }

        return $true
    }
}
