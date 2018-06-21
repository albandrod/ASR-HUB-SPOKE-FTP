<# 
    .DESCRIPTION 
        This will create a CSE to execute PS script to update FileZilla on FTP VM. 
         
 
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
    # Set FTP VM within the Resource Group
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
     foreach ($VM in $VMs)
    {
        If ($VM.Name -match "FTP" ) 
        {
            Write-Output ("FTP VM Found")
            $url = "https://raw.githubusercontent.com/swiftsolves-msft/ASR-HUB-SPOKE-FTP/master/updatexml.ps1"
            $guid = New-Guid

            Set-AzureRmVMCustomScriptExtension -ResourceGroupName $RGName `
            -VMName $VM.Name `
            -Location $VM.Location `
            -FileUri $url `
            -Run 'updatexml.ps1' `
            -Name "UpdateFileZillaConfig-$guid"
        }
        Else 
        {
            Write-Output ("FTP VM NOT Found!")
        }
    }
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
}
