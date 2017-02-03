# Report Portal Powershell Client (*unofficial*)
Custom PowerShell (v5) client for Report Portal (http://reportportal.io/)

Since version 5 PowerShell supporting classes. This module using them.

## Usage

```powershell

$reporter = Get-ReporterInstance "MyLaunchName"

#optional
$reporter.endpoint = 127.0.0.1:8080
$reporter.projectName = "DEMO";
$reporter.token = "88005553535"; # UUID from portal
$reporter.tag= "debian";

$rep.createLaunch()

$item0 = $rep.createRootTestItem("MyTestSuperPack", "Test all product", "SUITE")
$item1 = $rep.createChildTestItem("First test", "Test first part of product", "TEST")
$item2 = $rep.createChildTestItem("Second test", "Test second part of product", "TEST")

$rep.addLogs($item1, "error", "Object references an unsaved transient instance")
$rep.addLogs($item2, "info", "Done!")

$rep.finishTestItem($item1, "failed")
$rep.finishTestItem($item2, "passed")

$rep.finishTestItem($item0, "failed")

$rep.finishLaunch()
```

**TODO:**
* enum for statuses
* overloading functions
* support files for logger
* edit items
* internal container for created items with search by name
