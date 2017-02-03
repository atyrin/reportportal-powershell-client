class Reporter{
    # from config or global variable
    [string]$endpoint; #endpoint
    [string]$projectName; #Current project name
    [string]$token; # UUID from portal
    [string]$mode = "DEFAULT"; # DEFAULT or DEBUG
    [string]$tag; # special tags

    #internal properties
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


    [String] createLaunch (){
        $this.createLaunch($null)
    }


    [String] createLaunch ([String] $description){
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
        [String] $json = @"
    {
    "description": "$description",
    "mode": "$($this.mode)",
    "name": "$($this.launchName)",
    "start_time": "$(Get-Date -Format s)",
    "tags": [
        "$($this.tag)"
    ]
    }
"@
        $response = $this.sendRequest("POST", $url, $json)
        $this.launchId = $response.id
        return $response.id
    }


    [void] finishLaunch(){
        <#
        .DESCRIPTION
            Finish test launch, which was started in this instance.
        #>
        $url = $this.buildURL("$($this.launchSuburl)/$($this.launchId)/finish")
        [String] $json = @"
            {
            "end_time": "$(Get-Date -Format s)"
            }
"@
            $response = $this.sendRequest("PUT", $url, $json)
    }


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
        $json=@"
            {
            "description": "$description",
            "launch_id": "$($this.launchId)",
            "name": "$name",
            "start_time": "$(Get-Date -Format s)",
            "type": "$type"
            }
"@
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

        $json=@"
            {
            "description": "$description",
            "launch_id": "$($this.launchId)",
            "name": "$name",
            "start_time": "$(Get-Date -Format s)",
            "type": "$type"
            }
"@
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
            $itemId = $this.lastRootItem;
        }
        [String] $url = $this.buildURL("$($this.itemSuburl)/$itemId")

        $json=@"
           {
  "end_time": "$(Get-Date -Format s)",
  "status": "$status"
}
"@
        $this.sendRequest("PUT", $url, $json)
        Write-Host ""
    }


    [void] addLogs([String]$itemId, [String]$level, [String]$logText){
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

        $json=@"
            {
            "item_id": "$itemId",
            "level": "$level",
            "message": "$logText",
            "time": "$(Get-Date -Format s)"
            }
"@
        $this.sendRequest("POST", $url, $json)
    }


    hidden [String] buildURL([String] $str){
        <#
        .DESCRIPTION
            Creating URL for request.
        #>
            return "$($this.rphost)/api/v1/$($this.projectname)/$str?access_token=$($this.token)"
    }


    [String] FailureResponseHandler() {
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


    [Object] sendRequest([string]$method, [string]$url, [string]$body ){
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
                $response = Invoke-RestMethod -Method $method -Uri $url -Body $body -ContentType "application/json"
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



function Get-ReporterInstance($launchName){
    <#
    .DESCRIPTION
        Return instance of Reporter.
    .PARAMETER launchName
        Parameter for constructor.
        #>
    return [Reporter]::new($launchName)
}
