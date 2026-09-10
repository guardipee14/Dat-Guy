using module '..\Classes\Phoenix.Classes.psm1'

function New-PhoenixUnattendFile {

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [PhoenixUnattendConfiguration]$Configuration,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [AllowNull()]
        [Security.SecureString]$LocalAccountPassword,

        [Parameter()]
        [AllowNull()]
        [Security.SecureString]$ProductKey,

        [Parameter()]
        [switch]$IncludeSecrets
    )

    if ($null -eq $Configuration -or -not $Configuration.IsValid()) {
        throw 'A valid Phoenix unattended setup configuration is required.'
    }

    if (-not $IncludeSecrets -and ($null -ne $LocalAccountPassword -or $null -ne $ProductKey)) {
        throw 'Secure values were supplied without explicitly selecting IncludeSecrets.'
    }

    if ($IncludeSecrets -and $Configuration.LocalAccounts.Count -gt 0 -and $null -eq $LocalAccountPassword) {
        throw 'A secure local-account password is required when secrets are included.'
    }

    if ($IncludeSecrets -and $Configuration.ProductKeyPolicy -eq 'ProvidedAtDeployment' -and $null -eq $ProductKey) {
        throw 'A secure product key is required for ProvidedAtDeployment policy.'
    }

    if ($null -ne $LocalAccountPassword -and ($Configuration.LocalAccounts.Count -ne 1 -or $LocalAccountPassword.Length -eq 0)) {
        throw 'Explicit password inclusion requires exactly one configured local account and a nonempty password.'
    }
    if ($null -ne $ProductKey -and $Configuration.ProductKeyPolicy -ne 'ProvidedAtDeployment') {
        throw 'A supplied product key requires ProvidedAtDeployment policy.'
    }
    if ($IncludeSecrets -and $null -eq $ProductKey -and $null -eq $LocalAccountPassword) { throw 'No secure value was supplied for IncludeSecrets.' }

    [string]$resolvedPath = [IO.Path]::GetFullPath($Path)
    Test-PhoenixPathAncestors -Path $resolvedPath
    if ([IO.Path]::GetExtension($resolvedPath) -ine '.xml') { throw 'Choose an XML output filename.' }
    if (Test-Path -LiteralPath $resolvedPath) { throw 'Answer-file output already exists; choose a new path.' }
    if (-not $PSCmdlet.ShouldProcess($resolvedPath, 'Create a restricted Windows answer file; explicit secrets are plaintext')) {
        return [pscustomobject]@{Path=$resolvedPath;Created=$false;ContainsSecrets=[bool]$IncludeSecrets;DeferredLocalAccountCount=$(if ($IncludeSecrets) {0} else {$Configuration.LocalAccounts.Count})}
    }
    [string]$passwordText = ''
    [string]$productKeyText = ''

    try {
        if ($IncludeSecrets -and $null -ne $LocalAccountPassword) {
            $passwordText = ConvertFrom-PhoenixSecureString -SecureString $LocalAccountPassword
        }

        if ($IncludeSecrets -and $null -ne $ProductKey) {
            $productKeyText = ConvertFrom-PhoenixSecureString -SecureString $ProductKey
            if ($productKeyText -cnotmatch '^[A-Za-z0-9]{5}(?:-[A-Za-z0-9]{5}){4}$') { throw 'Invalid key format.' }
        }

        $newElement = {
            param(
                [Parameter(Mandatory)]
                [string]$Name,

                [Parameter()]
                [AllowNull()]
                [object]$Value
            )

            $elementName = [System.Xml.Linq.XName]::Get($Name)

            if ($PSBoundParameters.ContainsKey('Value')) {
                return [System.Xml.Linq.XElement]::new($elementName, $Value)
            }

            return [System.Xml.Linq.XElement]::new($elementName)
        }

        $windowsPe = & $newElement -Name 'settings'
        $windowsPe.SetAttributeValue('pass', 'windowsPE')
        $international = & $newElement -Name 'component'
        $international.SetAttributeValue('name', 'Microsoft-Windows-International-Core-WinPE')
        $international.SetAttributeValue('processorArchitecture', $Configuration.Architecture)

        foreach ($entry in ([ordered]@{
            InputLocale = $Configuration.InputLocale
            SystemLocale = $Configuration.SystemLocale
            UILanguage = $Configuration.UiLanguage
            UserLocale = $Configuration.UserLocale
        }).GetEnumerator()) {
            $international.Add((& $newElement -Name $entry.Key -Value $entry.Value))
        }

        $windowsPe.Add($international)

        $specialize = & $newElement -Name 'settings'
        $specialize.SetAttributeValue('pass', 'specialize')
        $shellSpecialize = & $newElement -Name 'component'
        $shellSpecialize.SetAttributeValue('name', 'Microsoft-Windows-Shell-Setup')
        $shellSpecialize.SetAttributeValue('processorArchitecture', $Configuration.Architecture)
        $shellSpecialize.Add((& $newElement -Name 'ComputerName' -Value $Configuration.ComputerName))
        $shellSpecialize.Add((& $newElement -Name 'TimeZone' -Value $Configuration.TimeZone))

        if (-not [string]::IsNullOrWhiteSpace($productKeyText)) {
            $shellSpecialize.Add((& $newElement -Name 'ProductKey' -Value $productKeyText))
        }

        $specialize.Add($shellSpecialize)

        $oobeSystem = & $newElement -Name 'settings'
        $oobeSystem.SetAttributeValue('pass', 'oobeSystem')
        $shellOobe = & $newElement -Name 'component'
        $shellOobe.SetAttributeValue('name', 'Microsoft-Windows-Shell-Setup')
        $shellOobe.SetAttributeValue('processorArchitecture', $Configuration.Architecture)
        $oobe = & $newElement -Name 'OOBE'
        $oobe.Add((& $newElement -Name 'HideEULAPage' -Value $Configuration.HideEulaPage.ToString().ToLowerInvariant()))
        $oobe.Add((& $newElement -Name 'ProtectYourPC' -Value $(if ($Configuration.ProtectYourPc) { '1' } else { '3' })))
        $shellOobe.Add($oobe)

        if ($IncludeSecrets -and $Configuration.LocalAccounts.Count -gt 0) {
            $userAccounts = & $newElement -Name 'UserAccounts'
            $localAccounts = & $newElement -Name 'LocalAccounts'

            foreach ($account in $Configuration.LocalAccounts) {
                $localAccount = & $newElement -Name 'LocalAccount'
                $localAccount.SetAttributeValue([System.Xml.Linq.XName]::Get('action', 'http://schemas.microsoft.com/WMIConfig/2002/State'), 'add')
                $localAccount.Add((& $newElement -Name 'Name' -Value ([string]$account.Name)))
                $localAccount.Add((& $newElement -Name 'DisplayName' -Value ([string]$account.DisplayName)))
                $localAccount.Add((& $newElement -Name 'Group' -Value ([string]$account.Group)))

                if (-not [string]::IsNullOrWhiteSpace($passwordText)) {
                    $password = & $newElement -Name 'Password'
                    $password.Add((& $newElement -Name 'Value' -Value $passwordText))
                    $password.Add((& $newElement -Name 'PlainText' -Value 'true'))
                    $localAccount.Add($password)
                }

                $localAccounts.Add($localAccount)
            }

            $userAccounts.Add($localAccounts)
            $shellOobe.Add($userAccounts)
        }

        $oobeSystem.Add($shellOobe)

        $root = [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]::Get('unattend', 'urn:schemas-microsoft-com:unattend'))
        $root.SetAttributeValue([System.Xml.Linq.XName]::Get('wcm', 'http://www.w3.org/2000/xmlns/'), 'http://schemas.microsoft.com/WMIConfig/2002/State')
        $root.Add($windowsPe)
        $root.Add($specialize)
        $root.Add($oobeSystem)

        foreach ($element in @($root.DescendantsAndSelf())) {
            if ($element.Name.LocalName -eq 'component') {
                $element.SetAttributeValue('publicKeyToken', '31bf3856ad364e35')
                $element.SetAttributeValue('language', 'neutral')
                $element.SetAttributeValue('versionScope', 'nonSxS')
            }
            if ([string]::IsNullOrWhiteSpace($element.Name.NamespaceName)) {
                $element.Name =
                    [System.Xml.Linq.XName]::Get(
                        $element.Name.LocalName,
                        'urn:schemas-microsoft-com:unattend'
                    )
            }
        }

        $document = [System.Xml.Linq.XDocument]::new([System.Xml.Linq.XDeclaration]::new('1.0', 'utf-8', 'yes'), $root)

        $null = New-Item -ItemType Directory -Path (Split-Path $resolvedPath -Parent) -Force -ErrorAction Stop
        $stream = New-PhoenixRestrictedAnswerFile -Path $resolvedPath
        try { $document.Save($stream) }
        finally { $stream.Dispose() }

        [xml]$validationDocument = Get-Content -LiteralPath $resolvedPath -Raw -ErrorAction Stop

        if ($validationDocument.DocumentElement.LocalName -ne 'unattend' -or $validationDocument.DocumentElement.NamespaceURI -ne 'urn:schemas-microsoft-com:unattend') {
            throw 'Generated unattended answer file failed namespace validation.'
        }

        return [pscustomobject]@{
            Path = $resolvedPath
            Created = $true
            ContainsSecrets = [bool]$IncludeSecrets
            Sha256 = (Get-FileHash -LiteralPath $resolvedPath -Algorithm SHA256).Hash.ToLowerInvariant()
            DeferredLocalAccountCount = $(if ($IncludeSecrets) { 0 } else { $Configuration.LocalAccounts.Count })
            AccessRestricted = $true
            Validation = 'StructureOnly'
            RequiresWindowsSimValidation = $true
        }
    }
    catch {
        # Do not serialize an XML/IO exception which could embed secret values.
        throw 'Answer-file creation failed. Any newly created output remains restricted; inspect it before retrying.'
    }
    finally {
        $passwordText = $null
        $productKeyText = $null
    }
}
