# Report Portal Powershell Client (*unofficial*)
Custom PowerShell (v5) client for Report Portal (http://reportportal.io/)

Since version 5 PowerShell support classes. This module use them.

## Usage

```powershell

$reporter = Get-ReporterInstance "MyLaunchName"

#optional
$reporter.endpoint = 127.0.0.1:8080
$reporter.projectName = "DEMO";
$reporter.token = "7ff757b0-ecb1-459d-8494-ff081804157d"; # UUID from portal
$reporter.tag= "debian";

$rep.createLaunch()

$item0 = $rep.createRootTestItem("MyTestSuperPack", "Test all product", "SUITE")

$rep.createChildTestItem("First test", "Test first part of product", "TEST")
$rep.addLogs("error", "Object references an unsaved transient instance")
$rep.finishChildTestItem("failed") # remember last child item

$item = $rep.createChildTestItem("Second test", "Test second part of product", "TEST")
$rep.addLogs($item, "info", "Done!")
$rep.finishTestItem($item, "passed")

$rep.finishRootTestItem("failed") #remember last root item

$rep.finishLaunch()

#search
$launchId = $rep.getLaunchByName("MyLaunchName")

```

**TODO:**
* support files for logger
* edit items
* internal container for created items with search by name
