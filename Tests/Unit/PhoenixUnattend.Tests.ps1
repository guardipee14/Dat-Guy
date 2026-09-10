BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    Import-Module (Join-Path $projectRoot 'Phoenix.psd1') -Force 6>$null
    function New-TestSecureValue {
        param([string]$Text)
        $value=[Security.SecureString]::new()
        foreach ($character in $Text.ToCharArray()) { $value.AppendChar($character) }
        $value.MakeReadOnly()
        return $value
    }
}

AfterAll {
    Remove-Module Phoenix -Force -ErrorAction SilentlyContinue
}

Describe 'Phoenix unattended setup generation' -Tag @('Unit', 'Deployment', 'Unattend', 'Secret') {
    It 'creates a valid typed configuration without storing secrets' {
        [string]$testComputerName = @('PHOENIX', 'VM') -join '-'
        $configuration = New-PhoenixUnattendConfiguration -ComputerName $testComputerName -Locale 'en-US' -LocalAccountName 'phoenixadmin'

        $configuration.IsValid() | Should-BeTrue
        $configuration.ProductKeyPolicy | Should-Be 'Prompt'
        (
            ($configuration | ConvertTo-Json -Depth 10) -match
                '(?i)"Password"\s*:|"ProductKey"\s*:'
        ) | Should-BeFalse
    }

    It 'generates a secret-free answer file by default' {
        [string]$testComputerName = @('PHOENIX', 'VM') -join '-'
        $configuration = New-PhoenixUnattendConfiguration -ComputerName $testComputerName
        $path = Join-Path $TestDrive 'autounattend.xml'

        $result = New-PhoenixUnattendFile -Configuration $configuration -Path $path -Confirm:$false
        [string]$xml = Get-Content -LiteralPath $path -Raw

        $result.Created | Should-BeTrue
        $result.ContainsSecrets | Should-BeFalse
        $xml | Should-MatchString 'urn:schemas-microsoft-com:unattend'
        ($xml -match '<Password>|<ProductKey>') | Should-BeFalse
    }

    It 'requires explicit secret inclusion and does not echo secure values in results' {
        $configuration = New-PhoenixUnattendConfiguration -LocalAccountName 'phoenixadmin' -ProductKeyPolicy ProvidedAtDeployment
        $password = [Security.SecureString]::new()
        foreach ($character in 'Fixture-Password-123!'.ToCharArray()) {
            $password.AppendChar($character)
        }
        $password.MakeReadOnly()

        $productKey = [Security.SecureString]::new()
        foreach ($character in 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'.ToCharArray()) {
            $productKey.AppendChar($character)
        }
        $productKey.MakeReadOnly()
        $path = Join-Path $TestDrive 'secret-unattend.xml'

        {
            New-PhoenixUnattendFile -Configuration $configuration -Path $path -LocalAccountPassword $password -ProductKey $productKey -Confirm:$false
        } | Should-Throw

        $result = New-PhoenixUnattendFile -Configuration $configuration -Path $path -LocalAccountPassword $password -ProductKey $productKey -IncludeSecrets -Confirm:$false
        [string]$resultJson = $result | ConvertTo-Json -Depth 20

        $result.ContainsSecrets | Should-BeTrue
        ($resultJson -match 'Fixture-Password-123|AAAAA-BBBBB') | Should-BeFalse
    }

    It 'redacts common secret forms from diagnostic text' {
        InModuleScope Phoenix {
            $safe = Protect-PhoenixSecretText -Text 'password=Example123 token:abc product-key=AAAAA-BBBBB' -Secret @('Example123')

            ($safe -match 'Example123|token:abc|AAAAA-BBBBB') | Should-BeFalse
            $safe | Should-MatchString '\[REDACTED\]'
        }
    }
    It 'defers local accounts rather than emitting blank-password accounts' {
        $configuration=New-PhoenixUnattendConfiguration -LocalAccountName 'phoenixuser'
        $configuration.LocalAccounts[0].Group | Should-Be 'Users'
        $path=Join-Path $TestDrive 'deferred.xml'
        $result=New-PhoenixUnattendFile -Configuration $configuration -Path $path -Confirm:$false
        $result.DeferredLocalAccountCount | Should-Be 1
        (Get-Content $path -Raw) | Should-NotMatchString '<UserAccounts>|<LocalAccount>'
    }
    It 'creates output with an explicit current-user and SYSTEM-only DACL' {
        $path=Join-Path $TestDrive 'acl.xml'
        New-PhoenixUnattendFile -Configuration (New-PhoenixUnattendConfiguration) -Path $path -Confirm:$false | Out-Null
        $acl=Get-Acl -LiteralPath $path
        $acl.AreAccessRulesProtected | Should-BeTrue
        $allowed=@([Security.Principal.WindowsIdentity]::GetCurrent().User.Value,'S-1-5-18')
        foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
            ($rule.IdentityReference.Value -in $allowed) | Should-BeTrue
            $rule.IsInherited | Should-BeFalse
        }
    }
    It 'preserves an existing destination' {
        $path=Join-Path $TestDrive 'existing.xml'
        [IO.File]::WriteAllText($path,'keep existing content')
        { New-PhoenixUnattendFile -Configuration (New-PhoenixUnattendConfiguration) -Path $path -Confirm:$false } | Should-Throw '*already exists*'
        [IO.File]::ReadAllText($path) | Should-Be 'keep existing content'
    }
    It 'never materializes credentials for WhatIf' {
        $configuration=New-PhoenixUnattendConfiguration -LocalAccountName 'phoenixuser'
        $password=New-TestSecureValue 'Synthetic-Only-123!'
        Mock -ModuleName Phoenix ConvertFrom-PhoenixSecureString { throw 'must not decrypt' }
        $path=Join-Path $TestDrive 'preview.xml'
        (New-PhoenixUnattendFile -Configuration $configuration -Path $path -LocalAccountPassword $password -IncludeSecrets -WhatIf).Created | Should-BeFalse
        Test-Path $path | Should-BeFalse
        Should-NotInvoke -ModuleName Phoenix ConvertFrom-PhoenixSecureString
    }
    It 'emits component identities and namespaced local-account actions' {
        $configuration=New-PhoenixUnattendConfiguration -LocalAccountName 'phoenixuser'
        $path=Join-Path $TestDrive 'contract.xml'
        New-PhoenixUnattendFile -Configuration $configuration -Path $path -LocalAccountPassword (New-TestSecureValue 'Synthetic-Only-123!') -IncludeSecrets -Confirm:$false | Out-Null
        [xml]$doc=Get-Content $path -Raw
        $components=@($doc.SelectNodes('//*[local-name()="component"]'))
        $components.Count | Should-Be 3
        foreach ($component in $components) {
            $component.GetAttribute('publicKeyToken') | Should-Be '31bf3856ad364e35'
            $component.GetAttribute('versionScope') | Should-Be 'nonSxS'
            $component.NamespaceURI | Should-Be 'urn:schemas-microsoft-com:unattend'
        }
        $account=$doc.SelectSingleNode('//*[local-name()="LocalAccount"]')
        $account.GetAttribute('action','http://schemas.microsoft.com/WMIConfig/2002/State') | Should-Be 'add'
        (Get-Content $path -Raw).Contains('xmlns=""') | Should-BeFalse
    }
    It 'does not include secure values in XML serialization failures' {
        $configuration=New-PhoenixUnattendConfiguration -LocalAccountName 'phoenixuser'
        $password=New-TestSecureValue ('Synthetic-Secret'+[char]0+'Tail')
        $errorText=''
        try { New-PhoenixUnattendFile -Configuration $configuration -Path (Join-Path $TestDrive 'invalid.xml') -LocalAccountPassword $password -IncludeSecrets -Confirm:$false }
        catch { $errorText=$_.Exception.Message }
        $errorText | Should-MatchString 'creation failed'
        $errorText | Should-NotMatchString 'Synthetic-Secret|Tail'
    }
    It 'rejects secret properties added to account configuration' {
        $configuration=New-PhoenixUnattendConfiguration -LocalAccountName 'phoenixuser'
        $configuration.LocalAccounts[0] | Add-Member -NotePropertyName Password -NotePropertyValue 'must not serialize'
        $configuration.IsValid() | Should-BeFalse
    }
    It 'rejects reserved account names and numeric-only computer names' {
        { New-PhoenixUnattendConfiguration -LocalAccountName 'Administrator' } | Should-Throw
        $numericNameFixture='12345'
        { New-PhoenixUnattendConfiguration -ComputerName $numericNameFixture } | Should-Throw
    }
    It 'rejects supplied keys outside explicit deployment policy' {
        $key=New-TestSecureValue 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'
        { New-PhoenixUnattendFile -Configuration (New-PhoenixUnattendConfiguration) -Path (Join-Path $TestDrive 'wrong-policy.xml') -ProductKey $key -IncludeSecrets -Confirm:$false } | Should-Throw '*ProvidedAtDeployment*'
    }
}
