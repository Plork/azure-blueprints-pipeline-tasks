<#
.DESCRIPTION
    Assign Azure BluePrint

.NOTES
    Author: Neil Peterson
    Intent: Sample to demonstrate Azure BluePrints with Azure DevOps
#>

# Helper functions
Import-Module ./helperFunctions.psm1

$ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName
$Endpoint = Get-VstsEndpoint -Name $ConnectedServiceName

$BlueprintManagementGroupId = $Endpoint.Data.managementGroupId

$BlueprintName = Get-VstsInput -Name BlueprintName
$BlueprintVersion = Get-VstsInput -Name Version
$ParametersFilePath = Get-VstsInput -Name ParametersFile
$TargetSubscriptionID = Get-VstsInput -Name SubscriptionID
$Wait = Get-VstsInput -Name Wait
$Timeout = Get-VstsInput -Name Timeout

Set-ExecutionPolicy -ExecutionPolicy Unrestricted
Install-Module -Name Az -Repository PSGallery -AllowClobber -Force
Uninstall-AzureRM
Write-Host "Successfully installed Az module"

Install-Module -Name Az.Blueprint -AllowClobber -Force
Write-Host "Successfully installed Az.Blueprint module"

. "./ps_modules/CommonScripts/Utility.ps1"
$targetAzurePs = Get-RollForwardVersion -azurePowerShellVersion $targetAzurePs

$authScheme = ''
try
{
	$serviceNameInput = Get-VstsInput -Name ConnectedServiceNameSelector -Default 'ConnectedServiceName'
	$serviceName = Get-VstsInput -Name $serviceNameInput -Default (Get-VstsInput -Name DeploymentEnvironmentName)
	if (!$serviceName)
	{
			Get-VstsInput -Name $serviceNameInput -Require
	}

	$endpoint = Get-VstsEndpoint -Name $serviceName -Require

	if($endpoint)
	{
		$authScheme = $endpoint.Auth.Scheme
	}

	 Write-Verbose "AuthScheme $authScheme"
}
catch
{
   $error = $_.Exception.Message
   Write-Verbose "Unable to get the authScheme $error"
}



Import-Module $PSScriptRoot\ps_modules\VstsAzureHelpers_
Initialize-Azure -azurePsVersion $targetAzurePs -strict

$Body = Get-Content -Raw -Path $ParametersFilePath | ConvertFrom-JsonAsHash

$AzBlueprintParams = @{
    Name = $BlueprintName
}

if ($BlueprintVersion -eq "Lastest") {
    $AzBlueprintParams['LatestPublished'] = $true
}
Else {
    $AzBlueprintParams['Version'] = $BlueprintVersion
}

$AzBlueprint = Get-AzBlueprint -SubscriptionId $TargetSubscriptionID @AzBlueprintParams -ErrorAction SilentlyContinue
if ([String]::IsNullOrEmpty($AzBlueprint) -eq $true) {
    Write-Host "Blueprint not found at Subscription, trying Management Group"
    if ($BlueprintManagementGroupId) {
        $AzBlueprint = Get-AzBlueprint -ManagementGroupId $BlueprintManagementGroupId @AzBlueprintParams -ErrorAction Stop
    }
    else {
        Throw "Blueprint not found at Management Group"
    }
}

$AzBlueprintAssignmentParams = @{
    SubscriptionId = $TargetSubscriptionID
    Name           = ("Assignment-{0}" -f $azBlueprint.Name)
}

$AzBlueprintAssignment = Get-AzBlueprintAssignment @AzBlueprintAssignmentParams -ErrorAction SilentlyContinue

if ($Body['properties']['resourceGroups'].Keys.Count -ne 0) {
    $AzBlueprintAssignmentParams['ResourceGroupParameter'] = $Body['properties']['resourceGroups']
}

if ($Body['properties']['parameters'].Keys.Count -ne 0) {
    $AzBlueprintAssignmentParams['Parameter'] = $Body['properties']['parameters']
}

if ([String]::IsNullOrEmpty($AzBlueprintAssignment) -eq $true) {
    New-AzBlueprintAssignment @AzBlueprintAssignmentParams -Blueprint $azBlueprint -Location $Body['location'] -SystemAssignedIdentity
}
Else {
    Set-AzBlueprintAssignment @AzBlueprintAssignmentParams -Blueprint $azBlueprint -Location $Body['location'] -SystemAssignedIdentity
}

if ($Wait -eq "true") {
    $timeout = New-TimeSpan -Seconds $Timeout
    $stopwatch = [diagnostics.stopwatch]::StartNew()

    while ($stopwatch.elapsed -lt $timeout) {
        Do {
            $Status = Get-AzBlueprintAssignment -SubscriptionId $TargetSubscriptionID -Name ("Assignment-{0}" -f 'commonPolicies')

            if ($Status.ProvisioningState -eq "Failed") {
                Write-Error $Status.properties.deployments.result.error.message
                break
            }

            sleep 5

        } while ($Status.ProvisioningState -ne "succeeded")
    }
}
