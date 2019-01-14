Get-Partition -DriveLetter "P"| Set-Partition -NewDriveLetter $TempDriveLetter
$TempDriveLetter = $TempDriveLetter + ":"
$drive = Get-WmiObject -Class win32_volume -Filter “DriveLetter = '$TempDriveLetter'”
#re-enable page file on new Drive
$drive = Get-WmiObject -Class win32_volume -Filter “DriveLetter = '$TempDriveLetter'”
Set-WMIInstance -Class Win32_PageFileSetting -Arguments @{ Name = "$TempDriveLetter\pagefile.sys"; MaximumSize = 0; }
Restart-Computer -Force