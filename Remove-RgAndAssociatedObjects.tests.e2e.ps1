$location = "westeurope"
$orgPrefix = "MYORG"
$adGroupPrefix = "AdminIT"

$globalOwnerAdGroupName =         "$($adGroupPrefix) Global Owners"
$myRgContributorsAdGroupName =    "$($adGroupPrefix) RG IN BASIC 123 MY Contributors"
$myRgOwnersAdGroupName =          "$($adGroupPrefix) RG IN BASIC 123 MY Owners"
$otherRgContributorsAdGroupName = "$($adGroupPrefix) RG IN BASIC 124 OTHER Contributors"
$otherRgOwnersAdGroupName =       "$($adGroupPrefix) RG IN BASIC 124 OTHER Owners"

$hubRgName =   "$($orgPrefix)_HUB"
$myRgName =    "$($orgPrefix)_RG_Intranet_BASIC_MY_123"
$otherRgName = "$($orgPrefix)_RG_Intranet_BASIC_OTHER_124"

$hubVNetName = "$($orgPrefix)_HUB_VNET"
$myVnetName = "$($orgPrefix)_MY_VNET"
$myVnet2Name = "$($orgPrefix)_MY_VNET_2"
$otherVnetName = "$($orgPrefix)_OTHER_VNET"

function Ensure-TestObjects 
{
    Write-Host "Ensuring AD groups..."
    $globalOwnerAdGroup = Get-AzADGroup -DisplayName $globalOwnerAdGroupName -ErrorAction "SilentlyContinue" -First 1
    $script:globalOwnerAdGroupId = if ($globalOwnerAdGroup) { $globalOwnerAdGroup.Id } else { (New-AzADGroup -DisplayName $globalOwnerAdGroupName -MailNickname $globalOwnerAdGroupName.Replace(" ","")).Id } # This group should not be deleted by our script, although it is associated
    $myRgContributorsAdGroup = Get-AzADGroup -DisplayName $myRgContributorsAdGroupName -ErrorAction "SilentlyContinue" -First 1
    $script:myRgContributorsAdGroupId = if ($myRgContributorsAdGroup) { $myRgContributorsAdGroup.Id } else { (New-AzADGroup -DisplayName $myRgContributorsAdGroupName -MailNickname $myRgContributorsAdGroupName.Replace(" ","")).Id }
    $myRgOwnersAdGroup = Get-AzADGroup -DisplayName $myRgOwnersAdGroupName -ErrorAction "SilentlyContinue" -First 1
    $script:myRgOwnersAdGroupId = if ($myRgOwnersAdGroup) { $myRgOwnersAdGroup.Id } else { (New-AzADGroup -DisplayName $myRgOwnersAdGroupName -MailNickname $myRgOwnersAdGroupName.Replace(" ","")).Id }
    $otherRgContributorsAdGroup = Get-AzADGroup -DisplayName $otherRgContributorsAdGroupName -ErrorAction "SilentlyContinue" -First 1
    $script:otherRgContributorsAdGroupId = if ($otherRgContributorsAdGroup) { $otherRgContributorsAdGroup.Id } else { (New-AzADGroup -DisplayName $otherRgContributorsAdGroupName -MailNickname $otherRgContributorsAdGroupName.Replace(" ","")).Id }
    $otherRgOwnersAdGroup = Get-AzADGroup -DisplayName $otherRgOwnersAdGroupName -ErrorAction "SilentlyContinue" -First 1
    $script:otherRgOwnersAdGroupId = if ($otherRgOwnersAdGroup) { $otherRgOwnersAdGroup.Id } else { (New-AzADGroup -DisplayName $otherRgOwnersAdGroupName -MailNickname $otherRgOwnersAdGroupName.Replace(" ","")).Id }

    Write-Host "Ensuring resource groups..."
    $hubRgId = (New-AzResourceGroup -Name $hubRgName -Location $location -Force).ResourceId
    $myRgId = (New-AzResourceGroup -Name $myRgName -Location $location -Force).ResourceId
    $otherRgId = (New-AzResourceGroup -Name $otherRgName -Location $location -Force).ResourceId

    Write-Host "Ensuring role assignments..."
    if (-not (Get-AzRoleAssignment -RoleDefinitionName "Owner" -ObjectId $globalOwnerAdGroupId -Scope $myRgId -ErrorAction "SilentlyContinue")) { New-AzRoleAssignment -RoleDefinitionName "Owner" -Scope $myRgId -ObjectId $globalOwnerAdGroupId }
    if (-not (Get-AzRoleAssignment -RoleDefinitionName "Owner" -ObjectId $globalOwnerAdGroupId -Scope $otherRgId -ErrorAction "SilentlyContinue")) { New-AzRoleAssignment -RoleDefinitionName "Owner" -Scope $otherRgId -ObjectId $globalOwnerAdGroupId }
    if (-not (Get-AzRoleAssignment -RoleDefinitionName "Owner" -ObjectId $myRgOwnersAdGroupId -Scope $myRgId -ErrorAction "SilentlyContinue")) { New-AzRoleAssignment -RoleDefinitionName "Owner" -Scope $myRgId -ObjectId $myRgOwnersAdGroupId }
    if (-not (Get-AzRoleAssignment -RoleDefinitionName "Owner" -ObjectId $otherRgOwnersAdGroupId -Scope $otherRgId -ErrorAction "SilentlyContinue")) { New-AzRoleAssignment -RoleDefinitionName "Owner" -Scope $otherRgId -ObjectId $otherRgOwnersAdGroupId }
    if (-not (Get-AzRoleAssignment -RoleDefinitionName "Contributor" -ObjectId $myRgContributorsAdGroupId -Scope $myRgId -ErrorAction "SilentlyContinue")) { New-AzRoleAssignment -RoleDefinitionName "Contributor" -Scope $myRgId -ObjectId $myRgContributorsAdGroupId }
    if (-not (Get-AzRoleAssignment -RoleDefinitionName "Contributor" -ObjectId $otherRgContributorsAdGroupId -Scope $otherRgId -ErrorAction "SilentlyContinue")) { New-AzRoleAssignment -RoleDefinitionName "Contributor" -Scope $otherRgId -ObjectId $otherRgContributorsAdGroupId }

    Write-Host "Ensuring VNets..."
    $hubVnet = New-AzVirtualNetwork -Name $hubVNetName -ResourceGroupName $hubRgName -AddressPrefix "10.1.0.0/16" -Location $location -Force
    $myVnet = New-AzVirtualNetwork -Name $myVNetName -ResourceGroupName $myRgName -AddressPrefix "10.2.0.0/16" -Location $location -Force
    $myVnet2 = New-AzVirtualNetwork -Name $myVNet2Name -ResourceGroupName $myRgName -AddressPrefix "10.3.0.0/16" -Location $location -Force
    $otherVnet = New-AzVirtualNetwork -Name $otherVnetName -ResourceGroupName $otherRgName -AddressPrefix "10.4.0.0/16" -Location $location -Force

    Write-Host "Ensuring peerings..."
    if (-not (Get-AzVirtualNetworkPeering -VirtualNetworkName $hubVNetName -ResourceGroupName $hubRgName -Name "HUB2MY" -ErrorAction "SilentlyContinue"))
        {Add-AzVirtualNetworkPeering -Name "HUB2MY" -VirtualNetwork $hubVNet -RemoteVirtualNetworkId $myVnet.Id -AllowForwardedTraffic -AllowGatewayTransit}
    if (-not (Get-AzVirtualNetworkPeering -VirtualNetworkName $myVNetName -ResourceGroupName $myRgName -Name "MY2HUB" -ErrorAction "SilentlyContinue"))
        {Add-AzVirtualNetworkPeering -Name "MY2HUB" -VirtualNetwork $myVNet -RemoteVirtualNetworkId $hubVnet.Id -AllowForwardedTraffic}
    if (-not (Get-AzVirtualNetworkPeering -VirtualNetworkName $hubVNetName -ResourceGroupName $hubRgName -Name "HUB2OTHER" -ErrorAction "SilentlyContinue"))
        {Add-AzVirtualNetworkPeering -Name "HUB2OTHER" -VirtualNetwork $hubVNet -RemoteVirtualNetworkId $otherVnet.Id -AllowForwardedTraffic -AllowGatewayTransit}
    if (-not (Get-AzVirtualNetworkPeering -VirtualNetworkName $otherVnetName -ResourceGroupName $otherRgName -Name "OTHER2HUB" -ErrorAction "SilentlyContinue"))
        {Add-AzVirtualNetworkPeering -Name "OTHER2HUB" -VirtualNetwork $otherVnet -RemoteVirtualNetworkId $hubVnet.Id -AllowForwardedTraffic}

    Write-Host "Ensuring public IPs..."
    New-AzPublicIpAddress -Name "MYPUBIP1" -ResourceGroupName $myRgName -Location $location -AllocationMethod Dynamic -Force
    New-AzPublicIpAddress -Name "MYPUBIP2" -ResourceGroupName $myRgName -Location $location -AllocationMethod Dynamic -Force
}

Describe "Remove-RgAndAssociatedObjects" {

    BeforeAll {
        # In an ideal world (where time plays no role) we would
        # execute the Code under Test each time from a clean state
        # for any fact we want to ensure (every "It" part below).
        # Yet for long running stuff that needs configuration up 
        # front - like these end-to end-tests - we run the test just
        # once (in this BeforeAll-Block) and then the indidual "Tests"
        # in the "It"-Parts check the different aspects (facts) we want
        # to make sure. If we need different runs with different params
        # we use different Describe-Blocks (or maybe Scenarios).
        
        Write-Host "== Arrange: Creating/updating test objects." # In this case make sure we have something to delete and some other things that should be spared.
        Ensure-TestObjects
        Write-Host "== Act: Executing our Code/System under Test (SUT)."
        .$PSScriptRoot\Remove-RgAndAssociatedObjects.ps1 -ResourceGroupName "$myRgName" -Confirm:$false
        Write-Host "== Assert: Examining the results."
    }
    
    It "deletes the resource group" {
        Get-AzResourceGroup -Name "$myRgName" -ErrorAction "SilentlyContinue" | 
            Should -BeNullOrEmpty
    }

    It "does not delete the other resource group" {
        Get-AzResourceGroup -Name "$otherRgName" -ErrorAction "SilentlyContinue" | 
            Should -Not -BeNullOrEmpty
    }

    It "deletes the remote network peering for the deleted VNet" {
        Get-AzVirtualNetworkPeering -ResourceGroupName "$hubRgName" -VirtualNetworkName "$hubVNetName" -Name "HUB2MY" -ErrorAction "SilentlyContinue" |
            Should -BeNullOrEmpty
    }

    It "does not delete the remote network peering for the other VNet" {
        Get-AzVirtualNetworkPeering -ResourceGroupName "$hubRgName" -VirtualNetworkName "$hubVNetName" -Name "HUB2OTHER" -ErrorAction "SilentlyContinue" |
            Should -Not -BeNullOrEmpty
    }

    It "deletes the associated Owner AD group" {
        Get-AzADGroup -ObjectId "$myRgOwnersAdGroupId" -ErrorAction "SilentlyContinue" | 
            Should -BeNullOrEmpty
    }

    It "deletes the associated Contributor AD group" {
        Get-AzADGroup -ObjectId "$myRgContributorsAdGroupId" -ErrorAction "SilentlyContinue" | 
            Should -BeNullOrEmpty
    }

    It "does not delete the other resource group's Owner AD group" {
        Get-AzADGroup -ObjectId "$otherRgOwnersAdGroupId" -ErrorAction "SilentlyContinue" | 
            Should -Not -BeNullOrEmpty
    }

    It "does not delete the other resource group's Contributor AD group" {
        Get-AzADGroup -ObjectId "$otherRgContributorsAdGroupId" -ErrorAction "SilentlyContinue" | 
            Should -Not -BeNullOrEmpty
    }

    It "does not delete the global owner AD group" {
        Get-AzADGroup -ObjectId "$globalOwnerAdGroupId" -ErrorAction "SilentlyContinue" | 
            Should -Not -BeNullOrEmpty
    }

}

function Remove-TestObjects 
{
    az group list --query "[?contains(name,'$orgPrefix')].name" -o tsv | xargs -L1 az group delete --yes --no-wait --name
    az ad group list --query "[?contains(displayName,'$adGroupPrefix')].objectId" -o tsv | xargs -L1 az ad group delete --group
}