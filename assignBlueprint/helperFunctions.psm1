$ManagementGroupBaseURI = "https://management.azure.com/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Blueprint/blueprints/{1}"
$SubscriptionBaseURI = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Blueprint/blueprints/{1}"
$BlueprintVersionpath = "/versions/{2}"
$AssignmentBaseURI = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Blueprint/blueprintAssignments/{1}"
$AssignmentBaseURI = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Blueprint/blueprintAssignments/{1}"
$APIVersion = '?api-version=2018-11-01-preview'

function Get-AuthenticationToken {
    Param (
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret
    )

    $Resource = "https://management.core.windows.net/"
    $RequestAccessTokenUri = 'https://login.microsoftonline.com/{0}/oauth2/token' -f $TenantId
    $body = "grant_type=client_credentials&client_id={0}&client_secret={1}&resource={2}" -f $ClientId, $ClientSecret , $Resource
    $Token = Invoke-RestMethod -Method Post -Uri $RequestAccessTokenUri -Body $body

    $Script:AuthenticationToken = $Token
    return $script:AuthenticationToken
}
function Invoke-BluePrintRestMethod {
    param(
        [ValidateSet('Get', 'Put', 'Post')]
        [string]$Method = 'Get',
        [uri]$Uri,
        $AuthenticationToken = $script:AuthenticationToken,
        [string]$ContentType = 'application/json',
        $Body
    )

    $Headers = @{ }
    $Headers.Add("Authorization", "$($AuthenticationToken.token_type) " + " " + "$($AuthenticationToken.access_token)")
    $Response = $null

    $InvokeParams = @{
        Uri    = $Uri
        Method = $Method
    }

    If ($Body) {
        $InvokeParams['body'] = $Body
    }

    try {
        $Response = Invoke-RestMethod @InvokeParams -DisableKeepAlive -Headers:$Headers -ContentType:$ContentType
    }
    catch {
        $ResponseBody = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message
    $errorMessage = 'Status code {0}. Server reported the following message: {1}.' -f $_.Exception.Response.StatusCode, $ResponseBody

    throw $errorMessage
}

Write-Verbose -Message ('Response: {0}' -f $Response)
return $Response
}

function Get-LatestVersion {
    [OutputType([string])]
    Param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string[]]$InputObject
    )
    Begin {
        $Versions = @()
    }
    Process {
        $versions += $InputObject
    }
    end {
        return ($versions | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1).ToString()
}
}

function Get-BluePrint {
    param (
        [string]$Scope,
        [string]$ManagementGroupIdId,
        [string]$SubscriptionId,
        [string]$BlueprintName,
        [string]$BluePrintVersion,
        [switch]$LatestPublished,
        $AuthenticationToken = $script:AuthenticationToken
    )

    $BluePrintParams = @{
        BlueprintName = $BlueprintName
    }

    If ($Scope -eq "ManagementGroup") {
        $BluePrintParams['Scope'] = 'ManagementGroup'
        $BluePrintParams['ManagementGroupId'] = $ManagementGroupIdId
    }
    Else {
        $BluePrintParams['Scope'] = 'Subscription'
        $BluePrintParams['SubscriptionId'] = $SubscriptionId
    }

    $BlueprintUri = Get-BlueprintURI @BluePrintParams

    try {
        $Blueprint = Invoke-BluePrintRestMethod -Uri $BlueprintUri -AuthenticationToken $AuthenticationToken
    }
    catch {
        if (!$Blueprint) {
            Throw "Blueprint $BlueprintName not found at $scope"
        }
    }

    If ($LatestPublished) {
        $BlueprintVersionsUri = Get-BlueprintVersionsURI @BluePrintParams
        $BlueprintVersions = Invoke-BluePrintRestMethod -Uri $BlueprintVersionsUri -AuthenticationToken $AuthenticationToken

        $BlueprintVersion = $BlueprintVersions.Value.Name | Get-LatestVersion
}

$BlueprintUri = Get-BlueprintURI @BluePrintParams -BluePrintVersion $BlueprintVersion

try {
    $BlueprintID = Invoke-BlueprintRestMethod -Uri $BlueprintUri -AuthenticationToken $AuthenticationToken
}
catch {
    if (!$BlueprintID) {
        Throw "Blueprint $BlueprintName version $BluePrintVersion not found at $scope"
    }
}

return $BlueprintID
}

function Get-BlueprintURI {
    param (
        [string]$Scope,
        [string]$ManagementGroupId,
        [string]$SubscriptionId,
        [string]$BlueprintName,
        [string]$BluePrintVersion
    )

    $sb = [System.Text.StringBuilder]::new()
    If ($Scope -eq "ManagementGroup") {

        [void]$sb.Append($ManagementGroupBaseURI)

        IF ($BluePrintVersion) {
            [void]$sb.Append($BlueprintVersionpath)
            [void]$sb.replace('{2}', $BluePrintVersion)
        }

        [void]$sb.Append($APIVersion)
        [void]$sb.replace('{0}', $ManagementGroupId)
        [void]$sb.replace('{1}', $BlueprintName)

        return $sb.ToString()

    }
    ElseIf ($Scope -eq "Subscription") {

        [void]$sb.Append($SubscriptionBaseURI)

        IF ($BluePrintVersion) {
            [void]$sb.Append($BlueprintVersionpath)
            [void]$sb.replace('{2}', $BluePrintVersion)
        }

        [void]$sb.Append($APIVersion)
        [void]$sb.replace('{0}', $SubscriptionId)
        [void]$sb.replace('{1}', $BlueprintName)

        return $sb.ToString()
    }
}

function Get-BlueprintVersionsURI {

    param (
        [string]$Scope,
        [string]$ManagementGroupId,
        [string]$SubscriptionId,
        [string]$BlueprintName,
        [switch]$ListVersions
    )

    $sb = [System.Text.StringBuilder]::new()
    If ($Scope -eq "ManagementGroup") {

        [void]$sb.Append($ManagementGroupBaseURI)
        [void]$sb.Append('/versions')
        [void]$sb.Append($APIVersion)
        [void]$sb.replace('{0}', $ManagementGroupId)
        [void]$sb.replace('{1}', $BlueprintName)

        return $sb.ToString()

    }
    ElseIf ($Scope -eq "Subscription") {

        [void]$sb.Append($SubscriptionBaseURI)
        [void]$sb.Append('/versions')
        [void]$sb.Append($APIVersion)
        [void]$sb.replace('{0}', $SubscriptionId)
        [void]$sb.replace('{1}', $BlueprintName)

        return $sb.ToString()
    }
}

function Get-BlueprintAssignmentURI {

    param (
        [string]$SubscriptionId,
        [string]$BlueprintName
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append($AssignmentBaseURI)
    [void]$sb.Append($APIVersion)
    [void]$sb.replace('{0}', $SubscriptionId)
    [void]$sb.replace('{1}', $BlueprintName)

    return $sb.ToString()
}

function Get-BlueprintAssignmentOperationURI {

    param (
        [string]$SubscriptionId,
        [string]$BlueprintName
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append($AssignmentBaseURI)
    [void]$sb.Append('/assignmentOperations')
    [void]$sb.Append($APIVersion)
    [void]$sb.replace('{0}', $SubscriptionId)
    [void]$sb.replace('{1}', $BlueprintName)

    return $sb.ToString()

}

function Get-BlueprintAssignmentStatusURI {

    param (
        [string]$SubscriptionId,
        [string]$BlueprintName,
        [string]$AssignmentOperationID
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append($AssignmentBaseURI)
    [void]$sb.Append('/assignmentOperations/')
    [void]$sb.Append($AssignmentOperationID)
    [void]$sb.Append($APIVersion)
    [void]$sb.replace('{0}', $SubscriptionId)
    [void]$sb.replace('{1}', $BlueprintName)

    return $sb.ToString()

}
