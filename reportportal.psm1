###################################################
# Windows Powershell 5.0 (WMF) download link
# https://msdn.microsoft.com/en-us/powershell/wmf/5.0/requirements
##################################################


class Reporter{
    # from config or global variable
    [string]$endpoint = ""; #endpoint
    [string]$projectName = ""; #Current project name
    [string]$token = "" # UUID from portal
    [string]$mode = "DEFAULT"; # DEFAULT or DEBUG
    $tag = ""; # special tags

    #internal properties
    hidden [String]$apiVersion = "v1"
    #launch
    hidden [string]$launchName; # launch name (ex. build)
    hidden [string]$launchId; #current launch id
    hidden [string]$launchSuburl = "launch";

    #items
    hidden [String]$itemSuburl = "item";
    hidden [String]$lastRootItem; #last created root item
    hidden [String]$lastItem; #last created item (child or root)

    #logs
    hidden [String]$logSuburl = "log"


    Reporter([String] $build){
        $this.launchName = $build;
    }


    ########################
    # launch functions
    ########################

    [String] createLaunch(){
        return $this.createLaunch($null)
    }


    [String] createLaunch([String] $description){
        <#
        .DESCRIPTION
            Create new test launch in portal. Take some class fields. 
        .PARAMETER description
            Launch description.
        #>
        if(!$description){
            $description = "Launch from powershell"
        }
        [String] $url = $this.buildURL($this.launchSuburl)
        $json = @{
            "description" = "$description"
            "mode" = "$($this.mode)"
            "name" = "$($this.launchName)"
            "start_time" = "$(Get-Date -Format s)"
            "tags" = @(
                $($this.tag)
            )
        }
        $json = $json | ConvertTo-Json
        $response = $this.sendRequest("POST", $url, $json)
        $this.launchId = $response.id
        return $response.id
    }


    [void] finishLaunch([String]$launchId){
        <#
        .DESCRIPTION
            Finish test launch with id from param.
        #>
        $url = $this.buildURL("$($this.launchSuburl)/$($launchId)/finish")
        $json = @{
            "end_time" =  $(Get-Date -Format s)
            }
        $json = $json | ConvertTo-Json
        $response = $this.sendRequest("PUT", $url, $json)
    }
    

    [void] finishLaunch(){
        <#
        .DESCRIPTION
            Finish test launch, which was started in this instance.
        #>
        $this.finishLaunch($this.launchId)
    }


    [void] forceFinishLaunch([String]$launchId){
        <#
        .DESCRIPTION
            Force finish test launch with id from param. 
            Will finish launch even if some test in running state.
        #>
        $url = $this.buildURL("$($this.launchSuburl)/$($launchId)/stop")
        $json = @{
            "end_time" = $(Get-Date -Format s)
        }
        $json = $json | ConvertTo-Json
        $response = $this.sendRequest("PUT", $url, $json)
    }


    [void] forceFinishLaunch(){
        $this.forceFinishLaunch($this.launchId)
    }


    hidden [String] getLaunchByParam([hashtable]$params){
        <#
        .DESCRIPTION
            Get specific launch by params. Service method.
        .PARAMETER params
            HashTable with filters
        #>
        [System.Text.StringBuilder]$paramsString = "tab.id=allCases&page.sort=start_time,DESC&" #sort for taking last
        foreach($item in $params.GetEnumerator()){
            $paramsString.Append("$($item.Key)=$($item.Value)&")
        }
        [String] $url = $this.buildURL($this.launchSuburl, "$($paramsString.ToString())")
        $response = $this.sendRequest("GET", $url)
        if($response.content.Length -gt 1){
            Write-Warning "There are $($response.content.Length) launches with such name. Take latest"
        }
        $this.launchId = $response.content[0].id
        return $response.content[0].id
    }


    [String] getLaunchByName([String]$name){
        $filter = @{
            "filter.cnt.name" = $name
        }
        return $this.getLaunchByParam($filter)
    }


    [String] getLaunchByNameAndTag([String]$name, [String]$tag){
        $filter = @{
            "filter.cnt.name" = $name
            "filter.has.tags" = $tag
        }
        return $this.getLaunchByParam($filter)
    }


    hidden [Object] getLaunchInfo([String]$launchId){
        <#
        .DESCRIPTION
            Get full information about existing launch. Service method.
        #>
        [String] $url = $this.buildURL("$($this.launchSuburl)/$launchId")
        return $this.sendRequest("GET", $url)
    }


    [bool] isLaunchRunning([String]$launchId){
        <#
        .DESCRIPTION
            Check is launch in running state.
        #>
        $response = $this.getLaunchInfo($launchId)
        if($response.status -eq "IN_PROGRESS"){
            return $true
        }
        else{
            return $false
        }
    }


    hidden [void] updateLaunch([String]$launchID, $tag){
        <#
        .DESCRIPTION
            Set tag to existing launch. Remove current tags. Service method.
        .PARAMETER launchid
            Launch ID for new tag.
        .PARAMETER tag
            Tag for set.
        #>
        [String]$url = $this.buildURL("$($this.launchSuburl)/$launchId/update")
        $json = @{
            "tags" = @($tag)
        }
        $json = $json | ConvertTo-Json
        $response = $this.sendRequest("PUT", $url, $json)
        Write-Host $response.msg
    }


    [void] addLaunchTag([String]$launchId, [String]$tag){
        <#
        .DESCRIPTION
            Add tag for existing launch. With saving current tags.
        .PARAMETER launchid
            Launch ID for new tag.
        .PARAMETER tag
            Tag for addition.
        #>
        if(!$this.isLaunchRunning($launchID)){
            throw "This launch was already finished"
        }
        $response = $this.getLaunchInfo($launchId)
        [System.Collections.ArrayList]$tags = $response.tags
        $tags.add($tag)
        $this.updateLaunch($launchID, $tags)
    }


    [void] addLaunchTag([String]$tag){
        $this.addLaunchTag($this.launchId, $tag)
    }



    ########################
    # items functions
    ########################

    [String] createRootTestItem([String]$name, [String]$description, [Types]$type){
        <#
        .DESCRIPTION
            Create root item. Ex. suite.
        .PARAMETER name
            Test name.
        .PARAMETER description
            Item description.
        .PARAMETER type
            Item type from enum in te bottom.
        #>

        [String] $url = $this.buildURL($this.itemSuburl)
        $json = @{
            "description" = $description
            "launch_id" = $($this.launchId)
            "name" = $name
            "start_time" = $(Get-Date -Format s)
            "type" = "$type"
            }
        $json = $json | ConvertTo-Json
        $response = $this.sendRequest("POST", $url, $json)
        if($this.lastRootItem){
            Write-Warning "Re-write last root item id."
        }
        $this.lastRootItem = $response.id;
        return $response.id
    }


    [String] createChildTestItem([String]$name, [String]$description, [Types]$type, [String]$root){
        <#
        .DESCRIPTION
            Create sub item. Ex. test.
        .PARAMETER name
            Test name.
        .PARAMETER description
            Item description.
        .PARAMETER type
            Item type from enum in te bottom.
        .PARAMETER root
            ID of parent item.
        #>

        if(!$root){
            Write-Warning "Using last created root item id"
            $root = $this.lastRootItem;
        }

        [String] $url = $this.buildURL("$($this.itemSuburl)/$root")

        $json = @{
            "description" = $description
            "launch_id" = $($this.launchId)
            "name" = $name
            "start_time" = $(Get-Date -Format s)
            "type" = "$type"
            }
        $json = $json | ConvertTo-Json
        $response = $this.sendRequest("POST", $url, $json)
        $this.lastItem = $response.id
        return $response.id
    }


    [String] createChildTestItem([String]$name, [String]$description, [Types]$type){
        return $this.createChildTestItem([String]$name, [String]$description, [Types]$type, $null)
    }


    [void] finishTestItem([String]$itemId, [String]$status){
        <#
        .DESCRIPTION
            Finish any running test item.
        .PARAMETER itemId
            Test item id for finish.
        .PARAMETER status
            Item status which will be set after finishing. Ex. PASSED.
        #>
        if(!$itemId){
            Write-Warning "[FinishTestItem] Using last created item id"
            $itemId = $this.lastItem;
        }
        [String] $url = $this.buildURL("$($this.itemSuburl)/$itemId")

        $json = @{
            "end_time" = $(Get-Date -Format s)
            "status" = $status
        }

        $json = $json | ConvertTo-Json
        $this.sendRequest("PUT", $url, $json)
    }


    [void] finishRootTestItem([String]$status){
        if(!$this.lastRootItem){
            throw "Failed to finish child item. Last Root Item is empty."
        }
        $this.finishTestItem($this.lastRootItem, $status)
    }

    [void] finishChildTestItem([String]$status){
        if(!$this.lastItem){
            throw "Failed to finish child item. Last Item is empty."
        }
        $this.finishTestItem($this.lastItem, $status)
    }


    ########################
    # logs functions
    ########################

    [int] addLogs([String]$itemId, [Level]$level, [String]$logText){
        <#
        .DESCRIPTION
            Uploading logs to item. For one item may be uploaded as much as you want logs.
        .PARAMETER itemId
            Item id.
        .PARAMETER level
            Level of current uploading log.
        .PARAMETER logText
            Log content.
        #>
        if(!$itemId){
            Write-Warning "[addLogs] Using last created item id"
            $itemId = $this.lastItem;
        }

        [String] $url = $this.buildURL($this.logSuburl)
        $counter = 0
        do{
            try{
                $counter++
                $json = @{
                    "item_id" = $itemId
                    "level" = $level
                    "message" = $($logText.Replace("\","\\").Replace("`n", "\n").Replace("`r"," "))
                    "time" = $(Get-Date -Format s)
                }
                $json = $json | ConvertTo-Json
                $this.sendRequest("POST", $url, $json)
                return 0
            }
            catch [System.Exception] {
                Write-Warning "Failed to send logs. Retry #$counter"
                Start-Sleep -Seconds 5
            }
        }
        while($counter -lt 3)
        Write-Warning "Failed to send logs. Exit."
        return 1
    }


    [void] addLogs([Level]$level, [String]$logText){
        if(!$this.lastItem){
            throw "Last Item is empty"
        }
        $this.addLogs($this.lastItem, $level, $logText)
    }


    ########################
    # export report functions
    ########################

    [String] exportHTMLReport([String]$launchId){
        [String]$url = $this.buildURL("$($this.launchSuburl)/$($launchId)/report", "view=html&")
        return $this.sendRequest("GET", $url)
    }

    [String] exportHTMLReport(){
        if(!$this.launchId){
            throw "Failed to export html report. Launch ID is empty."
        }
        return $this.exportHTMLReport($this.launchId)
    }


    ########################
    # common functions
    ########################

    hidden [String] buildURL([String] $str){
        return $this.buildURL($str, $null)
    }

    hidden [String] buildURL([String] $str, [String]$params){
        <#
        .DESCRIPTION
            Creating URL for request.
        #>
            return "$($this.endpoint)/api/$($this.apiVersion)/$($this.projectname)/$($str)?$($params)access_token=$($this.token)"
    }


    hidden [String] FailureResponseHandler() {
        <#
        .DESCRIPTION
            Request error handler. Get body from error response.
        #>
        
        $result = $_.Exception.Response.GetResponseStream();
        [System.IO.StreamReader]$reader = New-Object System.IO.StreamReader($result);
        [String] $responseBody = $reader.ReadToEnd();
        Write-Host "Response from failure handler $responseBody"
        return $responseBody;
    }


    hidden [Object] sendRequest([String]$method, [String]$url, $body ){
        <#
        .DESCRIPTION
            HTTP-requests invoker.
        .PARAMETER method
            HTTP method.
        .PARAMETER url
            Request target.
        .PARAMETER body
            Request body.
        #>
        if (($method -ne "GET") -and ($body)){
           try{
            $response = Invoke-RestMethod -Method $method -Uri "$url" -Body $body -ContentType "application/json"
            return $response
            }
            catch [Exception]{
                throw $this.FailureResponseHandler()
            }
        }
        elseif($method -eq "GET"){
            try{
                $response = Invoke-RestMethod -Method $method -Uri "$url" -ContentType "application/json"
                return $response
            }
            catch [Exception]{
                throw $this.FailureResponseHandler()
            }
        }
        else{
            throw "Body is empty"
        }
    }


    hidden [Object] sendRequest([string]$method, [string]$url){
        return $this.sendRequest($method, $url, $null) 
    }


    [String] ToString()
    {
        return $this.launchId
    }
}

Enum Types
{
    SUITE
    STORY
    TEST
    SCENARIO
    STEP
    BEFORE_CLASS
    BEFORE_GROUPS
    BEFORE_METHOD
    BEFORE_SUITE
    BEFORE_TEST
    AFTER_CLASS
    AFTER_GROUPS
    AFTER_METHOD
    AFTER_SUITE
    AFTER_TEST
}

Enum Level
{
    TRACE
    DEBUG
    INFO
    WARN 
    ERROR 
    ATTACHMENT
}

Enum Status
{
    PASSED
    FAILED
    IN_PROGRESS
}



function Get-ReporterInstance($launchName){
    <#
    .DESCRIPTION
        Return instance of Reporter.
    .PARAMETER launchName
        Parameter for constructor.
        #>
    return [Reporter]::new($launchName)
}
