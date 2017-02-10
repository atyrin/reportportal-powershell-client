# Report Portal Powershell Client (*unofficial*)
Custom PowerShell (v5) client for Report Portal (http://reportportal.io/)

Since version 5 PowerShell support classes. This module use them.

## Usage

```powershell

$reporter = Get-ReporterInstance "MyLaunchName"

#optional
$reporter.endpoint = "127.0.0.1:8080"
$reporter.projectName = "DEMO";
$reporter.token = "7ff757b0-ecb1-0000-0000-00081804157d"; # UUID from portal
$reporter.tag= "mytag";

$reporter.createLaunch()

$rootItemId = $rep.createRootTestItem("MyTestSuperPack", "Test all product", "SUITE")

$reporter.createChildTestItem("First test", "Test first part of product", "TEST") #create for last root id
$reporter.addLogs("error", "Object references an unsaved transient instance $($_.Exception.Stacktrace)")
$reporter.finishChildTestItem("failed") # remember last child item

$item = $rep.createChildTestItem("Second test", "Test second part of product", "TEST", $rootItemId)
$reporter.addLogs($item, "info", "Done!")
$reporter.finishTestItem($item, "passed")

$reporter.finishRootTestItem("failed") #remember last root item

$reporter.finishLaunch()
if($reporter.isLaunchRunning($reporter.launchId)){
    $reporter.forceFinishLaunch($launchId) #hard stop of launch
}

#search latest (by creation time) launch
$launchId = $reporter.getLaunchByName("MyLaunchName")
$launchId = $reporter.getLaunchByNameAndTag("MyLaunchName", "mytag")

#export launch result
$html = $reporter.exportHTMLReport() 
#or 
$reporter.exportHTMLReport($launchId)

```

