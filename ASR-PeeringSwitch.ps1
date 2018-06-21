<# 
    .DESCRIPTION 
        This will re-create VNET peerings back to failed over ADDC in ASR VNET. 
         
 
    .NOTES 
        AUTHOR: naswif@microsoft.com 
        LASTEDIT: 20 June, 2018 
#> 
param ( 
        [Object]$RecoveryPlanContext 
      ) 

Write-Output $RecoveryPlanContext

Try
 {
    "Logging in to Azure..."
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection 
     Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

    "Selecting Azure subscription..."
    Select-AzureRmSubscription -SubscriptionId $Conn.SubscriptionID -TenantId $Conn.tenantid 
 }
Catch
 {
      $ErrorMessage = 'Login to Azure subscription failed.'
      $ErrorMessage += " `n"
      $ErrorMessage += 'Error: '
      $ErrorMessage += $_
      Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
 }

if($RecoveryPlanContext.FailoverDirection -ne 'PrimaryToSecondary')
{
    Write-Output 'Script is reverses since Azure is not the target'

    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-CACEN-ASR" -Name "VNET-CACEN-ASR-TO-VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase-asr" -Force
    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-UKSOU" -Name "VNET-UKSOU-TO-VNET-CACEN-ASR" -ResourceGroupName "rgSwiftSolvesBase" -Force

    $peering1name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-CACEN-ASR" -ResourceGroupName "rgSwiftSolvesBase-asr").Name
    $peering2name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase-asr").Name

    Do
    {
        "$peering1name found at $(get-date)"
        "$peering2name found at $(get-date)"
        $peering1name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-CACEN-ASR" -ResourceGroupName "rgSwiftSolvesBase").Name
        $peering2name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase").Name
        if (!$peering1name) { $check1 = 0 }
        if ($peering1name) { $check1 = 1 }
        if (!$peering2name) { $check2 = 0 }
        if ($peering2name) { $check2 = 1 }
        "$check1 is at $(get-date)"
        "$check2 is at $(get-date)"
        start-sleep 15
    } While ($check2 -eq 1-and $check1 -eq 1)

    $vnet1 = Get-AzureRmVirtualNetwork -Name "VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase"
    $vnet2 = Get-AzureRmVirtualNetwork -Name "VNET-CACEN" -ResourceGroupName "rgSwiftSolvesBase"

    Add-AzureRmVirtualNetworkPeering -Name "VNET-UKSOU-TO-VNET-CACEN" -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id
    Add-AzureRmVirtualNetworkPeering -Name "VNET-CACEN-TO-VNET-UKSOU" -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id
}
else
{

    $VMinfo = $RecoveryPlanContext.VmMap | Get-Member | Where-Object MemberType -EQ NoteProperty | select -ExpandProperty Name

    Write-Output ("Found the following VMGuid(s): `n" + $VMInfo)

    if ($VMInfo -is [system.array])
    {
        $VMinfo = $VMinfo[0]

        Write-Output "Found multiple VMs in the Recovery Plan"
    }
    else
    {
        Write-Output "Found only a single VM in the Recovery Plan"
    }

    $RGName = $RecoveryPlanContext.VmMap.$VMInfo.ResourceGroupName

    Write-OutPut ("Name of resource group: " + $RGName)

    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-UKSOU" -Name "VNET-UKSOU-TO-VNET-CACEN" -ResourceGroupName "rgSwiftSolvesBase" -Force
    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-CACEN" -Name "VNET-CACEN-TO-VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase" -Force

    $peering1name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-CACEN" -ResourceGroupName "rgSwiftSolvesBase").Name
    $peering2name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase").Name

    Do
    {
        "$peering1name found at $(get-date)"
        "$peering2name found at $(get-date)"
        $peering1name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-CACEN" -ResourceGroupName "rgSwiftSolvesBase").Name
        $peering2name = (Get-AzureRmVirtualNetworkPeering -VirtualNetworkName "VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase").Name
        if (!$peering1name) { $check1 = 0 }
        if ($peering1name) { $check1 = 1 }
        if (!$peering2name) { $check2 = 0 }
        if ($peering2name) { $check2 = 1 }
        "$check1 is at $(get-date)"
        "$check2 is at $(get-date)"
        start-sleep 15
    } While ($check2 -eq 1-and $check1 -eq 1)

    $vnet1 = Get-AzureRmVirtualNetwork -Name "VNET-UKSOU" -ResourceGroupName "rgSwiftSolvesBase"
    $vnet2 = Get-AzureRmVirtualNetwork -Name "VNET-CACEN-ASR" -ResourceGroupName "rgSwiftSolvesBase-asr"

    Add-AzureRmVirtualNetworkPeering -Name "VNET-UKSOU-TO-VNET-CACEN-ASR" -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id
    Add-AzureRmVirtualNetworkPeering -Name "VNET-CACEN-ASR-TO-VNET-UKSOU" -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id

 }
