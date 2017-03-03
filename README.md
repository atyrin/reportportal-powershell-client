# Report Portal Powershell Client (*unofficial*)
Custom PowerShell (v5) client for Report Portal (http://reportportal.io/)

Since version 5 PowerShell support classes. This module use them.

## Usage

#### Workflow
```powershell

$reporter = Get-ReporterInstance "MyLaunchName"

#optional
$reporter.endpoint = "127.0.0.1:8080"
$reporter.projectName = "DEMO";
$reporter.token = "7ff757b0-ecb1-0000-0000-00081804157d"; # UUID from portal
$reporter.tag= "mytag";

$reporter.createLaunch()
#or $reporter.createLaunch("launch description")

$rootItemId = $rep.createRootTestItem("MyTestSuperPack", "Test all product", "SUITE")

$reporter.createChildTestItem("First test", "Test first part of product", "TEST") #create for last root id
$reporter.addLogs("error", "Object references an unsaved transient instance $($_.Exception.Stacktrace)")
$reporter.finishChildTestItem("failed") # remember last child item

$item = $rep.createChildTestItem("Second test", "Test second part of product", "TEST", $rootItemId)
$reporter.addLogs($item, "info", "Done!")
$reporter.finishTestItem($item, "passed")

$reporter.finishRootTestItem("failed") #remember last root item

$reporter.finishLaunch()
```
#### Additional features
```powershell
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

#add tag to launch. save previous tags.
$reporter.addLaunchTag($launchId, "newtag")
 
#add tag to launch. re-write previous tags.
$reporter.updateLaunch($launchId, "newtag")
#or
$reporter.updateLaunch($launchId, @("newtag1","newtag2"))

```
#### Customize logging
In function LogThis replace Write-Host(-Warning and -Error) to your own logger
```powershell
function LogThis{
    Param(
        [String]$message,
        [string]$loglevel = "info"
    )

    if($loglevel.ToLower() -eq "error"){
        Write-MyLogger $message -level error
    }
    elseif ($loglevel.ToLower() -eq "warn") {
        Write-MyLogger $message -level warning
    }
    else{
        Write-MyLogger $message -level info
    }
}
```