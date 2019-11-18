function Get-AuthenticationHeader()
{
    $AzureRMSubscription = (Get-AzContext).Subscription
    $AzureRmProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $RMProfileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($AzureRmProfile)
    $OAuthToken = $RMProfileClient.AcquireAccessToken($AzureRMSubscription.TenantId)
    $Header = @{"Content-Type" = "application/json"; "Authorization" = ("Bearer {0}" -f $OAuthToken.AccessToken) }
    return $Header
}

function Get-RemoteVNetPeerings($remoteVirtualNetworkSubscriptionId, $remoteVirtualNetworkResourceGroupName, $remoteVirtualNetworkName)
{
    $headers = Get-AuthenticationHeader
    $uri = "https://management.azure.com/subscriptions/$remoteVirtualNetworkSubscriptionId/resourceGroups/$remoteVirtualNetworkResourceGroupName/providers/Microsoft.Network/virtualNetworks/$remoteVirtualNetworkName/virtualNetworkPeerings?api-version=2019-09-01"
    $result = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
    return $result.value
}

function Remove-VNetPeering($subscriptionId, $resourceGroupName, $virtualNetworkName, $peeringName)
{
    $headers = Get-AuthenticationHeader
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Network/virtualNetworks/$virtualNetworkName/virtualNetworkPeerings/$($peeringName)?api-version=2019-09-01"
    Invoke-RestMethod -Method DELETE -Uri $uri -Headers $headers | Out-Null
}

function Get-AdGroupsToDelete($ResourceGroupName, $ADGroupNamePattern)
{
    $ResourceGroup = Get-AzResourceGroup $ResourceGroupName 
    return Get-AzRoleAssignment -Scope $ResourceGroup.ResourceId | 
    Where-Object { $_.ObjectType -eq "Group" -and $_.Scope -eq $ResourceGroup.ResourceId } | # Must be an AD Group and must be directly associated to group (not inherited)
    Where-Object { $_.DisplayName -match "$ADGroupNamePattern" }  # Group Name must match pattern
}

function Get-AdGroupNamePattern($ResourceGroupName)
{
    $AzureADName = 'AdminIT RG {0} {1} {2}'

    if ($ResourceGroupName -match 'Intranet')
    {
        $environment = 'IN'
    }
    elseif ($ResourceGroupName -match 'InternetOnly')
    {
        $environment = 'PI'
    }
    else 
    {
        throw "No environment found. Expected are Intranet or InternetOnly within the Resource Group Name."
    }

    if ($ResourceGroupName -match 'BASIC')
    {
        $classification = 'BASIC'
    }
    elseif ($ResourceGroupName -match 'PREMIUM')
    {
        $classification = 'PREMIUM'
    }
    else 
    {
        throw "No classification found. Expected are BASIC or PREMIUM within the Resource Group Name."
    }

    #$count = $ResourceGroupName.Substring($ResourceGroupName.LastIndexOf('_') + 1, ($ResourceGroupName.Length - $ResourceGroupName.LastIndexOf('_') - 1))
    $index = $ResourceGroupName -Replace '\D+',$1
    if (-not ($index))
    {
        throw "No index found. Index should be a number which will be identify the related resource group for the AAD Group."
    }

    $AdGroupNamePattern = $AzureADName -f $environment, $classification, $index
    return $AdGroupNamePattern
}

function Get-RemoteVNetPeeringsToDelete($ResourceGroupName)
{
    $containedVNets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
    $remoteVNetPeeringsToDelete = @()
    $containedVNetPeerings = @()
    foreach ($containedVNet in $containedVNets)
    {
        $containedVNetPeerings += $containedVNet.VirtualNetworkPeerings
        foreach ($peering in $containedVNet.VirtualNetworkPeerings)
        {
            $idRegExMatch = [Regex]::Match($peering.RemoteVirtualNetwork.Id, "/subscriptions/(?<subscriptionId>.+)/resourceGroups/(?<resourceGroupName>.+)/providers/Microsoft.Network/virtualNetworks/(?<name>.+)")
            $remoteVirtualNetworkSubscriptionId = $idRegExMatch.Groups["subscriptionId"].Value
            $remoteVirtualNetworkResourceGroupName = $idRegExMatch.Groups["resourceGroupName"].Value
            $remoteVirtualNetworkName = $idRegExMatch.Groups["name"].Value
            $remoteVNetPeerings = Get-RemoteVNetPeerings -remoteVirtualNetworkSubscriptionId $remoteVirtualNetworkSubscriptionId -remoteVirtualNetworkResourceGroupName $remoteVirtualNetworkResourceGroupName -remoteVirtualNetworkName $remoteVirtualNetworkName
            $remoteVNetPeeringsToDelete += $remoteVNetPeerings | 
            Where-Object { $_.properties.remoteVirtualNetwork.id -eq $containedVNet.Id } |
            ForEach-Object {
                $idRegExMatch = [Regex]::Match($_.id, "/subscriptions/(?<subscriptionId>.+)/resourceGroups/(?<resourceGroupName>.+)/providers/Microsoft.Network/virtualNetworks/(?<vnetName>.+)/virtualNetworkPeerings/(?<name>.+)")
                return new-Object PSOBject -Property @{
                    SubscriptionId    = $idRegExMatch.Groups["subscriptionId"].Value
                    ResourceGroupName = $idRegExMatch.Groups["resourceGroupName"].Value
                    VNetName          = $idRegExMatch.Groups["vnetName"].Value        
                    Name              = $idRegExMatch.Groups["name"].Value    
                    Raw               = $_
                } 
            }
        } 
    }
    return $remoteVNetPeeringsToDelete
}

function Remove-RgAndAssociatedObjects
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [Parameter(Mandatory=$true)] $ResourceGroupName
    )

    if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction "SilentlyContinue"))
    {
        Write-Host "Could not find resource group $ResourceGroupName."
        return
    }

    $remoteVNetPeeringsToDelete = Get-RemoteVNetPeeringsToDelete -ResourceGroupName $ResourceGroupName
    $ADGroupNamePattern = Get-AdGroupNamePattern -ResourceGroupName $ResourceGroupName
    Write-Host "Using pattern $ADGroupNamePattern to filter associated groups."
    $adGroupsToDelete = Get-AdGroupsToDelete -ResourceGroupName $ResourceGroupName -ADGroupNamePattern $ADGroupNamePattern
    $publicIpsToDelete = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName 

    Write-Host "Resource group $ResourceGroupName will be deleted."

    Write-Host "Following remote VNet Peerings will explicitly be deleted."
    foreach ($peering in $remoteVNetPeeringsToDelete)
    {
        Write-Host "- Name: $($peering.Name), RemoteVNetId: $($peering.Raw.properties.RemoteVirtualNetwork.Id)"
    }

    Write-Host "Following associated AD Groups will explicitly be deleted."
    foreach ($assignedGroup in $adGroupsToDelete)
    {
        Write-Host "- ObjectId: $($assignedGroup.ObjectId), DisplayName: $($assignedGroup.DisplayName)"
    }

    Write-Host "ACTION REQIRED: Following IPs will be implicitly deleted with resource group. Make sure that any corresponding DNS entries are changed/deleted as well!"
    foreach ($address in $publicIpsToDelete)
    {
        Write-Host "- IP: $($address.IpAddress), Name: $($address.Name)"
    }

    # ========== Actual Execution (supporting -Whatif) ==========
    if ($PSCmdlet.ShouldProcess($ResourceGroupName, "Delete resource group and associated objects")) 
    {
        Write-Host "Removing remote VNet Peerings."
        foreach ($peering in $remoteVNetPeeringsToDelete)
        {
            Remove-VNetPeering -subscriptionId $peering.SubscriptionId -resourceGroupName $peering.ResourceGroupName -virtualNetworkName $peering.VNetName -peeringName $peering.Name
        }

        Write-Host "Removing AD groups."
        foreach ($group in $adGroupsToDelete)
        {
            Remove-AzAdGroup -ObjectId ($group.ObjectId) -Force -PassThru | Out-Null
        }
    
        Write-Host "Removing resource group."
        Remove-AzResourceGroup -Name $ResourceGroupName -Force | Out-Null
    }
}