<#
.DESCRIPTION
    Assign Azure BluePrint

.NOTES
    Author: Neil Peterson
    Intent: Sample to demonstrate Azure BluePrints with Azure DevOps
#>

# Helper functions
Import-Module ./helperFunctions.psm1

# Get authentication details
$ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName
$Endpoint = Get-VstsEndpoint -Name $ConnectedServiceName
$TenantId = $Endpoint.Auth.Parameters.tenantid
$ClientId = $Endpoint.Auth.Parameters.ServicePrincipalId
$ClientSecret = $Endpoint.Auth.Parameters.ServicePrincipalKey

# Get Service connection details
$BlueprintManagementGroupId = $Endpoint.Data.managementGroupId

# Get Blueprint Assignment details
$BlueprintName = Get-VstsInput -Name BlueprintName
$BlueprintVersion = Get-VstsInput -Name BlueprintVersion
$ParametersFilePath = Get-VstsInput -Name ParametersFile
$TargetSubscriptionID = Get-VstsInput -Name SubscriptionID
$Wait = Get-VstsInput -Name Wait
$Timeout = Get-VstsInput -Name Timeout

$Body = Get-Content -Raw -Path $ParametersFilePath | ConvertFrom-Json

$AuthenticationToken = Get-AuthenticationToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

If ($BlueprintVersion -eq 'latest') {
    $BlueprintParams = @{
        LatestPublished = $true
    }
}
else {
    $BlueprintParams = @{
        BlueprintVersion = $BlueprintVersion
    }
}

try {
    $BlueprintID = Get-Blueprint "Subscription" -SubscriptionID $TargetSubscriptionID -BlueprintName $BlueprintName @BlueprintParams -AuthenticationToken $AuthenticationToken
}
catch {
	Write-Host "Blueprint not found at Subscription"

    if ($BlueprintManagementGroupId) {
        try {
            $BlueprintID = Get-Blueprint -Scope "ManagementGroup" -ManagementGroupId $BlueprintManagementGroupId -BlueprintName $BlueprintName @BlueprintParams -AuthenticationToken $AuthenticationToken
        }
        catch {
            Write-Host "Blueprint not found at Management Group"
        }
	}
}

if (!$BlueprintID) {
    Write-Host "No blueprint found"
    Exit
}

# Update Assignment body with Blueprint ID
$Body.properties.blueprintId = $BlueprintID.id

# Create Assignment
$BPAssign = Get-BlueprintAssignmentURI -SubscriptionID $TargetSubscriptionID -BlueprintName $BlueprintName
$Body = $Body | ConvertTo-Json -Depth 4
Invoke-BlueprintRestMethod -Method PUT -Uri $BPAssign -AuthenticationToken $AuthenticationToken -Body $body

# Wait for Assignment
if ($Wait -eq "true") {

    # Timeout logic
    $Timeout = New-TimeSpan -Seconds $Timeout
    $StopWatch = [diagnostics.stopwatch]::StartNew()

    while ($StopWatch.elapsed -lt $Timeout) {

        # Get Assignment Operation ID
        $AssignmentOperations = Get-BlueprintAssignmentOperationURI -SubscriptionID $TargetSubscriptionID -BlueprintName $BlueprintName
        $Assignment = Invoke-BlueprintRestMethod -Uri $AssignmentOperations -AuthenticationToken $AuthenticationToken

        # Get Assignment Status
        $AssignmentStatus = Get-BlueprintAssignmentStatusURI -SubscriptionID $TargetSubscriptionID -BlueprintName $BlueprintName -AssignmentOperationID $Assignment.value[0].name

        Do {
            $Status = Invoke-BlueprintRestMethod -Uri $AssignmentStatus -AuthenticationToken $AuthenticationToken

            if ($Status.properties.assignmentState -eq "failed") {
                Write-Error $Status.properties.deployments.result.error.message
                break
            }

            Sleep 5

        } while ($Status.properties.assignmentState -ne "succeeded")
    }
}
