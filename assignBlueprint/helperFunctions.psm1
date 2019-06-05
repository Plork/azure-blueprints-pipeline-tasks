$ManagementGroupBaseURI = "https://management.azure.com/providers/Microsoft.Management/managementGroups/{0}/providers/Microsoft.Blueprint/blueprints/{1}"
$SubscriptionBaseURI = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Blueprint/blueprints/{1}"
$AssignmentBaseURI = "https://management.azure.com/subscriptions/{0}/providers/Microsoft.Blueprint/blueprintAssignments/{1}"
$APIVersion = '?api-version=2018-11-01-preview'

function ConvertFrom-JsonAsHash {
    <#
    .ForwardHelpTargetName Microsoft.PowerShell.Utility\ConvertFrom-Json
    .ForwardHelpCategory Cmdlet
    #>
    [CmdletBinding(HelpUri = 'http://go.microsoft.com/fwlink/?LinkID=217031', RemotingCapability = 'None')]
    param(
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [String] $InputObject
    )

    begin {
        Write-Debug "Beginning $($MyInvocation.Mycommand)"
        Write-Debug "Bound parameters:`n$($PSBoundParameters | out-string)"

        $psVersion = $PSVersionTable.PSVersion
        If ($psVersion.Major -lt 6) {
            try {
                # Use this class to perform the deserialization:
                # https://msdn.microsoft.com/en-us/library/system.web.script.serialization.javascriptserializer(v=vs.110).aspx
                Add-Type -AssemblyName "System.Web.Extensions, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" -ErrorAction Stop
            }
            catch {
                throw "Unable to locate the System.Web.Extensions namespace from System.Web.Extensions.dll. Are you using .NET 4.5 or greater?"
            }

            $jsSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        }
    }
    process {

        If ($psVersion.Major -lt 6) {
            $jsSerializer.Deserialize($InputObject, 'Hashtable')
        }
        else {
            ConvertFrom-Json $InputObject -asHashTable
        }
    }
    end {
        If ($psVersion.Major -lt 6) {
            $jsSerializer = $null
        }
        Write-Debug "Completed $($MyInvocation.Mycommand)"
    }
}

function Get-BlueprintURI {

    param (
        [string]$Scope,
        [string]$ManagementGroup,
        [string]$SubscriptionID,
        [string]$BlueprintName
    )

    $sb = [System.Text.StringBuilder]::new()
    If ($Scope -eq "ManagementGroup") {

        [void]$sb.Append($ManagementGroupBaseURI)
        [void]$sb.Append($APIVersion)
        [void]$sb.replace('{0}',$ManagementGroup)
        [void]$sb.replace('{1}',$BlueprintName)

        return $sb.ToString()

    } ElseIf ($Scope -eq "Subscription") {

        [void]$sb.Append($SubscriptionBaseURI)
        [void]$sb.Append($APIVersion)
        [void]$sb.replace('{0}',$SubscriptionID)
        [void]$sb.replace('{1}',$BlueprintName)

        return $sb.ToString()
    }
}

function Get-BlueprintAssignmentURI  {

    param (
        [string]$SubscriptionID,
        [string]$BlueprintName
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append($AssignmentBaseURI)
    [void]$sb.Append($APIVersion)
    [void]$sb.replace('{0}',$SubscriptionID)
    [void]$sb.replace('{1}',$BlueprintName)

    return $sb.ToString()
}

function Get-BlueprintAssignmentOperationURI {

    param (
        [string]$SubscriptionID,
        [string]$BlueprintName
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append($AssignmentBaseURI)
    [void]$sb.Append('/assignmentOperations')
    [void]$sb.Append($APIVersion)
    [void]$sb.replace('{0}',$SubscriptionID)
    [void]$sb.replace('{1}',$BlueprintName)

    return $sb.ToString()

}

function Get-BlueprintAssignmentStatusURI {

    param (
        [string]$SubscriptionID,
        [string]$BlueprintName,
        [string]$AssignmentOperationID
    )

    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append($AssignmentBaseURI)
    [void]$sb.Append('/assignmentOperations/')
    [void]$sb.Append($AssignmentOperationID)
    [void]$sb.Append($APIVersion)
    [void]$sb.replace('{0}',$SubscriptionID)
    [void]$sb.replace('{1}',$BlueprintName)

    return $sb.ToString()

}
