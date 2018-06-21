<# 
    .DESCRIPTION 
        This will create a Public IP address for the failed over VM(s). 
         
        Pre-requisites 
        All resources involved are based on Azure Resource Manager (NOT Azure Classic)

        The following AzureRm Modules are required
        - AzureRm.Profile
        - AzureRm.Resources
        - AzureRm.Compute
        - AzureRm.Network

        How to add the script? 
        Add the runbook as a post action in boot up group containing the VMs, where you want to assign a public IP.. 
         
        Clean up test failover behavior 
        You must manually remove the Public IP interfaces 
 
    .NOTES 
        AUTHOR: naswif@microsoft.com 
        LASTEDIT: 19 June, 2018 
#> 
param ( 
        [Object]$RecoveryPlanContext 
      ) 

Write-Output $RecoveryPlanContext

if($RecoveryPlanContext.FailoverDirection -ne 'PrimaryToSecondary')
{
    Write-Output 'Script is ignored since Azure is not the target'
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
    # Get VMs within the Resource Group
Try
 {
    $VMs = Get-AzureRmVm -ResourceGroupName $RGName
    Write-Output ("Found the following VMs: `n " + $VMs.Name) 
 }
Catch
 {
      $ErrorMessage = 'Failed to find any VMs in the Resource Group.'
      $ErrorMessage += " `n"
      $ErrorMessage += 'Error: '
      $ErrorMessage += $_
      Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
 }
Try
 {

    ## NSG Rules
    $rdpRule = New-AzureRmNetworkSecurityRuleConfig -Name Allow-RDP -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
    $ftpRule = New-AzureRmNetworkSecurityRuleConfig -Name Allow-FTP -Description "Allow FTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 21
    $passftpRule = New-AzureRmNetworkSecurityRuleConfig -Name Allow-PassFTP -Description "Allow Passive FTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 1003 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8001-8010


    foreach ($VM in $VMs)
    {
        $ARMNic = Get-AzureRmResource -ResourceId $VM.NetworkProfile.NetworkInterfaces[0].id
        $NIC = Get-AzureRmNetworkInterface -Name $ARMNic.Name -ResourceGroupName $ARMNic.ResourceGroupName
        $PIP = New-AzureRmPublicIpAddress -Name $VM.Name -ResourceGroupName $RGName -Location $VM.Location -AllocationMethod Dynamic -Force
        $NIC.IpConfigurations[0].PublicIpAddress = $PIP
        Set-AzureRmNetworkInterface -NetworkInterface $NIC    
        Write-Output ("Added public IP address to the following VM: " + $VM.Name) 
        
        If ($VM.Name -match "ADDC" )
            {
                Write-Output ("ADDC VM Found")

                $nsgName = $VM.Name + "-NSG"
                $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGname -Location $VM.Location -Name $nsgName -SecurityRules $rdpRule -Force

                $nicset = Get-AzureRmNetworkInterface -Name $NIC.name -ResourceGroupName $NIC.ResourceGroupName
                $nicset.NetworkSecurityGroup = $nsg
                $nicset | Set-AzureRmNetworkInterface

            }
        ElseIf ($VM.Name -match "FTP")
            {
                Write-Output ("FTP VM Found")

                $nsgName = $VM.Name + "-NSG"
                $nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $RGname -Location $VM.Location -Name $nsgName -SecurityRules $rdpRule,$ftpRule,$passftpRule -Force

                $nicset = Get-AzureRmNetworkInterface -Name $NIC.name -ResourceGroupName $NIC.ResourceGroupName
                $nicset.NetworkSecurityGroup = $nsg
                $nicset | Set-AzureRmNetworkInterface

                $rs = Get-AzureRmDnsRecordSet -name "ftp" -RecordType A -ZoneName "swiftman33.com" -ResourceGroupName "rgswiftman33dns"


                $armpip = (Get-AzureRmResource -ResourceId $nicset.IpConfigurations[0].PublicIpAddress.Id).Properties.ipaddress
                
                $rs.Records[0].Ipv4Address = $armpip
                Set-AzureRmDnsRecordSet -RecordSet $rs
            }
        Else 
            {
            Write-Output ("ADDC or FTP VM NOT Found!")
            }
         
    }
    Write-Output ("Operation completed on the following VM(s): `n" + $VMs.Name)
 }
Catch
 {
      $ErrorMessage = 'Failed to add public IP address to the VM.'
      $ErrorMessage += " `n"
      $ErrorMessage += 'Error: '
      $ErrorMessage += $_
      Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
 }
}
