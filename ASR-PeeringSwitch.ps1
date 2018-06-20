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

if($RecoveryPlanContext.FailoverDirection -ne 'PrimaryToSecondary')
{
    Write-Output 'Script is reverses since Azure is not the target'

    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName VNET-CACEN-ASR -Name VNET-CACEN-ASR-TO-VNET-UKSOU -ResourceGroupName rgSwiftSolvesBase-asr
    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName VNET-UKSOU -Name VNET-UKSOU-TO-VNET-CACEN-ASR -ResourceGroupName rgSwiftSolvesBase

    $vnet1 = Get-AzureRmVirtualNetwork -Name VNET-UKSOU -ResourceGroupName rgSwiftSolvesBase
    $vnet2 = Get-AzureRmVirtualNetwork -Name VNET-CACEN -ResourceGroupName rgSwiftSolvesBase

    Add-AzureRmVirtualNetworkPeering -Name VNET-UKSOU-TO-VNET-CACEN -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id
    Add-AzureRmVirtualNetworkPeering -Name VNET-CACEN-TO-VNET-UKSOU -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id
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

    

    Remove-AzureRmVirtualNetworkPeering -VirtualNetworkName VNET-UKSOU -Name VNET-UKSOU-TO-VNET-CACEN2 -ResourceGroupName rgSwiftSolvesBase

    $vnet1 = Get-AzureRmVirtualNetwork -Name VNET-UKSOU -ResourceGroupName rgSwiftSolvesBase
    $vnet2 = Get-AzureRmVirtualNetwork -Name VNET-CACEN-ASR -ResourceGroupName rgSwiftSolvesBase-asr

    Add-AzureRmVirtualNetworkPeering -Name VNET-UKSOU-TO-VNET-CACEN-ASR -VirtualNetwork $vnet1 -RemoteVirtualNetworkId $vnet2.Id
    Add-AzureRmVirtualNetworkPeering -Name VNET-CACEN-ASR-TO-VNET-UKSOU -VirtualNetwork $vnet2 -RemoteVirtualNetworkId $vnet1.Id

 }