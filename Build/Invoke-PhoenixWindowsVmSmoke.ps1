[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Current', 'Standard', 'Administrator')]
    [string]$ExpectedPrivilege = 'Current',

    [Parameter()]
    [AllowEmptyString()]
    [string]$ReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'The Phoenix Windows VM smoke test requires Windows.'
}

if (
    [Threading.Thread]::CurrentThread.ApartmentState -ne
        [Threading.ApartmentState]::STA
) {
    throw 'Run the Phoenix Windows VM smoke test from pwsh -Sta.'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $projectRoot 'Phoenix.psd1'
$xamlPath = Join-Path `
    $projectRoot `
    'Private\ControlCenter\PhoenixControlCenter.xaml'

$module = @(
    Import-Module -Name $modulePath -Force -PassThru -ErrorAction Stop
) | Select-Object -First 1

Start-Phoenix -SkipProviderBootstrap -ErrorAction Stop
$context = Get-PhoenixContext
if ($null -eq $context) {
    throw 'Phoenix did not publish a context during the VM smoke test.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
[bool]$isAdministrator = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (
    ($ExpectedPrivilege -eq 'Standard' -and $isAdministrator) -or
    ($ExpectedPrivilege -eq 'Administrator' -and -not $isAdministrator)
) {
    throw (
        'Expected a {0} token, but the current Windows token is {1}.' -f
        $ExpectedPrivilege,
        $(if ($isAdministrator) { 'Administrator' } else { 'Standard' })
    )
}

$inventory = & $module {
    Get-PhoenixControlCenterInventory
}

Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
Add-Type -AssemblyName PresentationCore -ErrorAction Stop

[xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -ErrorAction Stop
$reader = [Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

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
        ForEach-Object { [string]$_.GetAttribute('Name', $namespaceManager.LookupNamespace('x')) } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)
$missingControls = @(
    $controlNames |
        Where-Object { $null -eq $window.FindName($_) }
)
if ($missingControls.Count -gt 0) {
    throw "Unresolved XAML controls: $($missingControls -join ', ')"
}

$expectedBindings = [ordered]@{
    ProviderGrid = @('Name', 'Availability', 'Operations', 'Privilege', 'Health')
    ApplicationGrid = @(
        'Name', 'Id', 'Version', 'AvailableVersion', 'UpdateStatus',
        'Provider', 'Source', 'ProviderAlternatives', 'Actionable'
    )
    DriverGrid = @(
        'Name', 'Manufacturer', 'Provider', 'Version', 'Class', 'InfName',
        'ProblemCode'
    )
    OemAdapterGrid = @(
        'Name', 'Applicable', 'UtilityName', 'UtilityAvailable',
        'RequiresUtilityApproval'
    )
    DriverUpdateGrid = @(
        'Title', 'InstalledVersion', 'AvailableVersion', 'Source', 'Status'
    )
    RestorePlanGrid = @(
        'RecordType', 'Name', 'InstalledVersion', 'AvailableVersion',
        'Provider', 'PlannedAction', 'VerificationStatus'
    )
    ActivityGrid = @('State', 'Action', 'Provider', 'Target', 'ProgressText')
}

$bindingResults = [ordered]@{}
foreach ($gridName in $expectedBindings.Keys) {
    $grid = $window.FindName($gridName)
    $actualBindings = @(
        $grid.Columns |
            ForEach-Object {
                if ($null -ne $_.Binding -and $null -ne $_.Binding.Path) {
                    [string]$_.Binding.Path.Path
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    $missingBindings = @(
        $expectedBindings[$gridName] |
            Where-Object { $_ -notin $actualBindings }
    )
    if ($missingBindings.Count -gt 0) {
        throw (
            "Grid '$gridName' is missing bindings: " +
            ($missingBindings -join ', ')
        )
    }
    $bindingResults[$gridName] = $actualBindings
}

$driverUpdateRows = @(
    [pscustomobject]@{
        IsSelected = $false
        Title = 'Phoenix VM smoke driver update'
        DriverManufacturer = 'Phoenix'
        DriverModel = 'Synthetic device'
        DriverClass = 'System'
        InstalledVersion = '1.0.0'
        AvailableVersion = '1.1.0'
        Source = 'Windows Update'
        PublishedDisplay = 'Smoke only'
        Status = 'Available'
    }
)
$restoreRows = @(
    [pscustomobject]@{
        Selected = $true
        RecordType = 'Application'
        Name = 'Phoenix VM smoke package'
        RequestedVersion = '1.1.0'
        InstalledVersion = '1.0.0'
        AvailableVersion = '1.1.0'
        Provider = 'WinGet'
        PlannedAction = 'Update'
        VerificationStatus = 'Verified'
        RequiresElevation = $false
        RebootRequired = $false
    }
)
$activityRows = @(
    [pscustomobject]@{
        State = 'Completed'
        Action = 'VmSmoke'
        Provider = 'Phoenix'
        Target = 'Control Center bindings'
        ProgressText = '100% - Completed'
        StartedText = 'Now'
        ElapsedText = '0s'
    }
)
$searchRows = @(
    [pscustomobject]@{
        IsSelected = $false
        Name = 'Phoenix VM smoke search result'
        Id = 'Phoenix.VmSmoke'
        Version = '1.0.0'
        Provider = 'WinGet'
    }
)

$gridSources = [ordered]@{
    ProviderGrid = @($inventory.Providers)
    ApplicationGrid = @($inventory.Applications)
    DriverGrid = @($inventory.Drivers)
    OemAdapterGrid = @($inventory.OemAdapters)
    DriverUpdateGrid = $driverUpdateRows
    RestorePlanGrid = $restoreRows
    ActivityGrid = $activityRows
    SearchResultGrid = $searchRows
}

$rowCounts = [ordered]@{}
foreach ($gridName in $gridSources.Keys) {
    $grid = $window.FindName($gridName)
    $grid.ItemsSource = @($gridSources[$gridName])
    $rowCounts[$gridName] = @($grid.ItemsSource).Count
}

foreach ($filterName in @('ApplicationProviderFilter', 'SearchProviderFilter')) {
    $filter = $window.FindName($filterName)
    $filter.Items.Clear()
    [void]$filter.Items.Add('All providers')
    foreach (
        $providerName in @(
            $inventory.Providers |
                Where-Object { $_.Available } |
                ForEach-Object Name |
                Sort-Object -Unique
        )
    ) {
        [void]$filter.Items.Add([string]$providerName)
    }
    $filter.SelectedItem = 'All providers'
}

$pageNames = @(
    'OverviewPage',
    'ApplicationsPage',
    'DriversPage',
    'RestorePlanPage',
    'ActivityPage',
    'CustomizePage'
)
$window.ShowInTaskbar = $false
$window.Opacity = 0
$window.Show()
try {
    foreach ($pageName in $pageNames) {
        foreach ($candidatePage in $pageNames) {
            $window.FindName($candidatePage).Visibility =
                if ($candidatePage -eq $pageName) {
                    [Windows.Visibility]::Visible
                }
                else { [Windows.Visibility]::Collapsed }
        }
        $window.Measure([Windows.Size]::new(1440, 900))
        $window.Arrange([Windows.Rect]::new(0, 0, 1440, 900))
        $window.UpdateLayout()
    }
}
finally {
    $window.Close()
}

$currentUserAllowed = & $module {
    Test-PhoenixPrivilege -RequiredPrivilege User
}
$administratorAllowed = & $module {
    Test-PhoenixPrivilege -RequiredPrivilege Administrator
}
if (-not $currentUserAllowed -or $administratorAllowed -ne $isAdministrator) {
    throw 'The live privilege contract did not match the Windows token.'
}

$report = [pscustomobject]@{
    Schema = 'PhoenixWindowsVmSmoke'
    SchemaVersion = '1.0'
    Success = $true
    CompletedAtUtc = [datetime]::UtcNow
    ComputerName = $env:COMPUTERNAME
    User = $identity.Name
    Windows = [Environment]::OSVersion.VersionString
    PowerShell = $PSVersionTable.PSVersion.ToString()
    ApartmentState = [Threading.Thread]::CurrentThread.ApartmentState.ToString()
    ActualPrivilege = if ($isAdministrator) { 'Administrator' } else { 'Standard' }
    ExpectedPrivilege = $ExpectedPrivilege
    ContextState = [string]$context.LifecycleState
    ControlsResolved = $controlNames.Count
    PagesMeasured = $pageNames.Count
    GridRowCounts = $rowCounts
    GridBindings = $bindingResults
    PrivilegePolicy = [ordered]@{
        CurrentUserAllowed = [bool]$currentUserAllowed
        AdministratorAllowed = [bool]$administratorAllowed
        StandardScenarioRequiresElevation = $true
        AdministratorScenarioRequiresElevation = $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    [string]$resolvedReportPath = [IO.Path]::GetFullPath($ReportPath)
    [string]$reportRoot = Split-Path -Parent $resolvedReportPath
    if (-not (Test-Path -LiteralPath $reportRoot -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $reportRoot -Force
    }
    $report |
        ConvertTo-Json -Depth 20 |
        Set-Content -LiteralPath $resolvedReportPath -Encoding UTF8
}

return $report
