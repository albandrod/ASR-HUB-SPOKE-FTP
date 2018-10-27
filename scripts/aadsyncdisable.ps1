Import-Module ADSync

Get-ADSyncScheduler | Write-Output

Set-ADSyncScheduler -SyncCycleEnabled $false

Get-ADSyncScheduler | Write-Output