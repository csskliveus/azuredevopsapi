<#
------------------------------------------------------------------------------------

------------------------------------------------------------------------------------

1. Get current release id.  15575 
2. Get the stage you want to edit. [stage name or stage id ]
3. Call API and get release details. 
5. Add projects to be deployed to the list. 
6. skip remaining projects. 
7. Send the updated data object to the PUT call to update release.

------------------------------------------------------------------------------------
Questions:
 1. Am i trying to update release from the same release ? 
 2. 
#>

param(

    [string] $organisation = "", 
    [string] $project = "$env:System_TeamProject",
    [string] $releaseid = '15575',
    [string] $projectdeploymentlist = "defaultalias,templates,APIM_Deployment,APIM_Deployment_QA"

)

# project that needs to be deployed

$projectsforcurrentdeployment = New-Object -TypeName "System.Collections.ArrayList"

# API headers

function addProjectsForDeployment
{
   $projects = $projectdeploymentlist.Split(',')

   foreach ($project in $projects)
   {
    $projectsforcurrentdeployment.add($project)
   }

}

function releaseBasedOnReleaseId  
{
 # get release based on release id 
    [cmdletbinding()]
    param(
        [ parameter (Mandatory = $true)]
        [string] $releaseid,
        [ parameter (Mandatory = $true)]
        [string] $organisation,
        [ parameter (Mandatory = $true)]
        [string] $project,
        [ parameter (mandatory = $true)]
        [string] $method,
        [ parameter (mandatory = $false)]         
        [System.Object] $body
    )
    try
    {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "Basic $EncodedPAT")


        $url = "https://"+$organisation+".vsrm.visualstudio.com/"+$project+"/_apis/Release/releases/"+$releaseid+"?api-version=6.0"
        
        if ( $method -eq 'GET') {
            write-host "GET"
            $response = Invoke-RestMethod $url -Method $method -Headers $headers }

        elseif ( $method -eq 'PUT') {
            write-host "PUT"
            $url1 = "https://vsrm.dev.azure.com/$organisation/$project/_apis/release/releases/$releaseid?api-version=6.0" 
            $response = Invoke-RestMethod $url1 -Method 'PUT' -Headers $headers -Body $body 
            
             
            }
        else{
            write-host "No matching method"
        }
    }
    catch
    {
      Write-Host $_.Exception.Message
      Write-Host $_
    }

    return $response

}


function skipRepositoriesInStageAndUpdateObject{

   [cmdletbinding()]
    param(
        [ parameter (Mandatory = $true)]
        [System.Collections.ArrayList] $projectsforcurrentdeployment,
        [ parameter (Mandatory = $true)]
        [System.Object] $getreleaseresponse
    )
    
    foreach ($downloadinput in $getreleaseresponse.environments[3].deployPhasesSnapshot[0].deploymentInput.artifactsDownloadInput.downloadInputs)
    {
        
        #if ($downloadinput.alias -ne 'Voyager_MS_ClientPatientSearchManagement' -and ($downloadinput.alias -notin $projectsforcurrentdeployment) )
        if ($downloadinput.alias -notin $projectsforcurrentdeployment)
        {
            write-host $downloadinput.alias
            $downloadinput.artifactDownloadMode = 'Skip'
        }
    }
      return $getreleaseresponse
}



addProjectsForDeployment

write-host $projectsforcurrentdeployment

$url = "https://$organisation.vsrm.visualstudio.com/$project/_apis/Release/releases/$releaseid" 

$getresponse = releaseBasedOnReleaseId -releaseid $releaseid -organisation $organisation -project $project -method 'GET'

write-host "get response is "
write-host $getresponse

$res1 = skipRepositoriesInStageAndUpdateObject -projectsforcurrentdeployment $projectsforcurrentdeployment -getreleaseresponse $getresponse

$jsonres = $res1 | ConvertTo-Json -Depth 100


$putresponse1 = releaseBasedOnReleaseId -releaseid $releaseid -organisation $organisation -project $project -method 'PUT' -body $jsonres

write-host $putresponse1

#$response = Invoke-RestMethod $url -Method 'GET' -Headers $headers -Body $body
#$response.GetType()






#-----
#$response | ConvertTo-Json
#write-host $response.environments.deployPhasesSnapshot[0].deploymentInput.artifactsDownloadInput.downloadInputs

#$body = $response | ConvertTo-Json -Depth 100 

#$response | ConvertTo-Json -Depth 100 |  Out-File -FilePath C:\\updatedoutput.json

