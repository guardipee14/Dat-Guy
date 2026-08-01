BeforeAll {
    $projectRoot =
        Split-Path `
            -Path (
                Split-Path `
                    -Path $PSScriptRoot `
                    -Parent
            ) `
            -Parent
    $xamlPath = Join-Path `
        $projectRoot `
        'Private\ControlCenter\PhoenixControlCenter.xaml'
    $desktopPath = Join-Path `
        $projectRoot `
        'Private\ControlCenter\Show-PhoenixDesktop.ps1'
    $workerPath = Join-Path `
        $projectRoot `
        'Tools\Invoke-PhoenixControlCenterWorker.ps1'
    $smokePath = Join-Path `
        $projectRoot `
        'Build\Invoke-PhoenixWindowsVmSmoke.ps1'

    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
    [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw
    $reader = [Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    [string]$desktopSource = Get-Content -LiteralPath $desktopPath -Raw
    [string]$workerSource = Get-Content -LiteralPath $workerPath -Raw
    [string]$smokeSource = Get-Content -LiteralPath $smokePath -Raw
}

Describe 'Phoenix Control Center end-to-end integration' {
    It 'resolves every named WPF control from the shipped XAML' {
        $namespaceManager = [Xml.XmlNamespaceManager]::new($xaml.NameTable)
        $namespaceManager.AddNamespace(
            'x',
            'http://schemas.microsoft.com/winfx/2006/xaml'
        )
        $namespaceManager.AddNamespace(
            'p',
            'http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        )
        $controlNames = @(
            $xaml.SelectNodes(
                '//*[@x:Name and not(ancestor::p:ControlTemplate)]',
                $namespaceManager
            ) |
                ForEach-Object {
                    [string]$_.GetAttribute(
                        'Name',
                        $namespaceManager.LookupNamespace('x')
                    )
                } |
                Sort-Object -Unique
        )
        $missingControls = @(
            $controlNames |
                Where-Object { $null -eq $window.FindName($_) }
        )

        ($controlNames.Count -gt 100) | Should-BeTrue
        $missingControls.Count | Should-Be 0
    }

    It 'binds provider filtering versions sources and alternatives in Applications' {
        foreach ($controlName in @(
            'ApplicationProviderFilter',
            'SearchProviderFilter',
            'ApplicationGrid',
            'SearchResultGrid'
        )) {
            ($null -ne $window.FindName($controlName)) | Should-BeTrue
        }

        $applicationBindings = @(
            $window.FindName('ApplicationGrid').Columns |
                ForEach-Object {
                    if ($null -ne $_.Binding -and $null -ne $_.Binding.Path) {
                        [string]$_.Binding.Path.Path
                    }
                }
        )
        foreach ($binding in @(
            'Version',
            'AvailableVersion',
            'Provider',
            'Source',
            'ProviderAlternatives',
            'UpdateStatus'
        )) {
            ($binding -in $applicationBindings) | Should-BeTrue
        }
    }

    It 'routes one-provider and all-provider searches through the worker' {
        $desktopSource.Contains(
            'Provider = @($searchProviders)'
        ) | Should-BeTrue
        $desktopSource.Contains(
            '$selectedProvider -eq ''All providers'''
        ) | Should-BeTrue
        $workerSource.Contains(
            '$searchParameters.Provider = @($workerParameters.Provider)'
        ) | Should-BeTrue
        $workerSource.Contains(
            'Search-PhoenixControlCenterPackage @searchParameters'
        ) | Should-BeTrue
    }

    It 'binds provider OEM and version sources in Drivers' {
        $driverBindings = @(
            $window.FindName('DriverGrid').Columns |
                ForEach-Object {
                    if ($null -ne $_.Binding -and $null -ne $_.Binding.Path) {
                        [string]$_.Binding.Path.Path
                    }
                }
        )
        $updateBindings = @(
            $window.FindName('DriverUpdateGrid').Columns |
                ForEach-Object {
                    if ($null -ne $_.Binding -and $null -ne $_.Binding.Path) {
                        [string]$_.Binding.Path.Path
                    }
                }
        )
        $oemBindings = @(
            $window.FindName('OemAdapterGrid').Columns |
                ForEach-Object {
                    if ($null -ne $_.Binding -and $null -ne $_.Binding.Path) {
                        [string]$_.Binding.Path.Path
                    }
                }
        )

        ('Provider' -in $driverBindings) | Should-BeTrue
        ('Version' -in $driverBindings) | Should-BeTrue
        ('InstalledVersion' -in $updateBindings) | Should-BeTrue
        ('AvailableVersion' -in $updateBindings) | Should-BeTrue
        ('Source' -in $updateBindings) | Should-BeTrue
        ('UtilityName' -in $oemBindings) | Should-BeTrue
        ('Applicable' -in $oemBindings) | Should-BeTrue
    }

    It 'connects every live page data source to an isolated worker action' {
        foreach ($action in @(
            'Inventory',
            'ApplicationUpdates',
            'SearchPackages',
            'PackageAction',
            'DriverAction',
            'RestorePlan',
            'RestorePlanExecute',
            'RestoreVerify'
        )) {
            $desktopSource.Contains("-Action '$action'") | Should-BeTrue
            $workerSource.Contains("'$action' {") | Should-BeTrue
        }
    }

    It 'ships a syntactically valid live Windows VM WPF smoke gate' {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile(
            $smokePath,
            [ref]$tokens,
            [ref]$errors
        )

        @($errors).Count | Should-Be 0
        $smokeSource.Contains("Schema = 'PhoenixWindowsVmSmoke'") |
            Should-BeTrue
        $smokeSource.Contains('window.Show()') | Should-BeTrue
        $smokeSource.Contains('Get-PhoenixControlCenterInventory') |
            Should-BeTrue
        $smokeSource.Contains('Test-PhoenixPrivilege') | Should-BeTrue
    }

    It 'covers standard and administrator privilege expectations' {
        $smokeSource.Contains(
            "[ValidateSet('Current', 'Standard', 'Administrator')]"
        ) | Should-BeTrue
        $smokeSource.Contains(
            "ExpectedPrivilege -eq 'Standard'"
        ) | Should-BeTrue
        $smokeSource.Contains(
            "ExpectedPrivilege -eq 'Administrator'"
        ) | Should-BeTrue
        $smokeSource.Contains(
            'StandardScenarioRequiresElevation = $true'
        ) | Should-BeTrue
        $smokeSource.Contains(
            'AdministratorScenarioRequiresElevation = $false'
        ) | Should-BeTrue
    }
}
