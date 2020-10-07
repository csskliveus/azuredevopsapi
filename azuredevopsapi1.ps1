#16926 - 2 bugs
#16930 - 1 bug
#14010 - 5 bugs
#13874 - 1 us
# 13170 - feature
# 10788 - multiple us and bugs 
param(
[string]$PAT = 'pat', 
[string] $pullRequestId = '15894',
[string] $organisation = 'org',
[string] $project = 'project',
[string] $repo = 'repo'

)


$userstoryArray = New-Object -TypeName "System.Collections.ArrayList"
$userstoryArray = [System.Collections.ArrayList]@()

function getParentUserStoryBasedOnWorkItem {
    [cmdletbinding()]
    param (
        [ Parameter (Mandatory = $true)]
        [string]$workitemid,
        [ Parameter (Mandatory = $true)]
        [string]$base64AuthInfo,
        [ Parameter (Mandatory = $true)]
        [string]$user

    )
    
    #$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pat)))

    $baseurl = 'https://analytics.dev.azure.com/$organisation/$project/_odata/v2.0//WorkItems'
    $parent = 'Parent($filter=WorkItemType eq ''User Story'';$select=WorkItemId,Title,State,WorkItemType)'

    $url = $baseurl+'?$select=WorkItemId,Title&$expand='+$parent+'&$filter=WorkItemId eq '+$workitemid

    $response = Invoke-RestMethod  -Uri $url -Method 'GET' -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)} -Body $body
    
    
     if ($response.value[0].parent) {
        return $response.value[0].parent
        }
     else { return $null } 
    #write-host $userstory
    return $userstory
}

# Get test cases based on the workitem details 


function getTestCasesBasedOnUserStory {
    [cmdletbinding()]
    param (
        [ Parameter (Mandatory = $true)]
        [string]$workitemid,
        [ Parameter (Mandatory = $true)]
        [string]$base64AuthInfo,
        [ Parameter (Mandatory = $true)]
        [string]$user

    )
    
    #$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PAT"))
    
    $baseurl = 'https://analytics.dev.azure.com/$organisation/$project/_odata/v2.0//WorkItems?'

    $expand = '$expand=Children($filter=WorkItemType eq ''Test Case''; $select=WorkItemId,Title,Priority)&'

    $select =  '$select=WorkItemId,Title,State,WorkItemType&'

    $filter =  '$filter=WorkItemId eq '+$workitemid

    $url = $baseurl+$select+$expand+$filter
    #write-host $url
    
    $response = Invoke-RestMethod  -Uri $url -Method 'GET' -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)} -Body $body
    
    
    $testcases = $response.value.Children
    $testcasescount = $response.value.Children.Length
    #write-host $testcases
    if ( $testcasescount -gt 0){
        write-host "Test case count is - $testcasescount"
        $testcases | Format-Table
    }
    else
    {
    write-host "No test cases are attached to the user story" -fore yellow   }

}

$base64AuthInfo = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$PAT"))

$threadURL = "https://dev.azure.com/$organisation/$project/_apis/git/repositories/$repo/pullRequests/$pullRequestId/workitems"   # get pull request related work items

    $response_1 = Invoke-RestMethod -Uri $threadURL -Method Get -ContentType "application/json" -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
    #write-host  $response_1

    # For each work item related to the pull request id 
    foreach ($val in $response_1.value)
    {
       $prworkitemid = $val.id

        write-host "Workitem [bug id or user story id] is $prworkitemid" 

        $workItemsDetail = 'https://dev.azure.com/$organisation/_apis/wit/workitems?ids=' + $val.id +'&fields=System.Id,System.State,System.WorkItemType&api-version=6.0'
        
        #write-host $workItemsDetail 
        
        $workitemsresponse = Invoke-RestMethod -Uri $workItemsDetail -Headers @{Authorization = "Basic $base64AuthInfo"} -Method Get  # get the type of the work item and its status 
        #write-host $workitemsresponse.value.fields
        
        foreach ($field in $workitemsresponse.value.fields)
        {
             if($field.'System.WorkItemType' -eq 'Bug')  # if the work item is bug and it is in fixed or closed status
                {   
                    if($field.'System.State' -eq 'Fixed' -Or $field.'System.State' -eq 'Closed')
                    {
                        $bugid = $field.'System.Id'
                        $parentobject = getParentUserStoryBasedOnWorkItem -workitemid $bugid -base64AuthInfo $base64AuthInfo -user $user 

                        if ($parentobject -ne $null)
                        {
                            $usid = $parentobject.WorkItemId
                            
                            write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                            write-host "Pull request id - $pullrequestid : Bug is - $bugid : Parent user story id - $usid" -fore green 
                            #write-host "`n"
                            if ( $usid -notin $userstoryArray) 
                            {
                                getTestCasesBasedOnUserStory -workitemid $usid -base64AuthInfo $base64AuthInfo -user $user 
                                $userstoryArray.Add($usid)   # adding all the userstory ids to an array. 
                            }
                            else { write-host "Test cases are already written to terminal output. " }
                             #write-host "`n"
                            write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                        }
                        else
                        { write-host "--- No user story is associated with bug. Please check ----" -fore yellow  
                        write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                        }

                    }

                    else 
                    { write-host "--- Bug is not in fixed or closed status. So test cases are not pulled for this bug - $bugid --" -fore yellow  
                        write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                        }

               }

              elseif ($field.'System.WorkItemType' -eq 'User Story')
              {
               $usid = $field.'System.Id'
                write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
                write-host "Pull request id - $pullrequestid : Parent user story id - $usid" -fore green 

                if ( $usid -notin $userstoryArray) 
                    {
                        getTestCasesBasedOnUserStory -workitemid $usid -base64AuthInfo $base64AuthInfo -user $user 
                        $userstoryArray.Add($usid)   # adding all the userstory ids to an array. 
                    }
                    else { write-host "Test cases are already written to terminal output. " }

              
                write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

              }
              else
              {
                 write-host "Pull request id - $pullrequestid : workitem id  - $prworkitemid, work item is not a 'userstory' or 'bug' " -fore yellow 
                 write-host "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
              }

        }
       
    }
Write-Output $userstoryArray