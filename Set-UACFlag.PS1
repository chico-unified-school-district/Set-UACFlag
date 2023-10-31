<#
.SYNOPSIS
 Bradford requires a specific AD User Account Control flag be set to determine if an account has access
 to various CUSD network services. The User Account Control flag for disable dobjects is 0x0202.
 A Powershell script is used to search AD for qualifying disabled user objects and set the flag.
 This process runs every 30 minutes as a scheduled task.
.DESCRIPTION
 A PSSession is created with an account with access to a domain controller and write/change permisssions on user objects.
.EXAMPLE
.\Set-UACFlag.PS1 -DomainController 'myDC' -ADCredential $CredentialObject
.EXAMPLE
.\Set-UACFlag.PS1 -DomainController 'myDC' -ADCredential $CredentialObject -WhatIf -Verbose
.INPUTS
.OUTPUTS
.NOTES
#>

[cmdletbinding()]
param (
 [Parameter(Mandatory = $True)]
 [Alias('DCs')]
 [string[]]$DomainControllers,
 # PSSession to Domain Controller and Use Active Directory CMDLETS
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [SWITCH]$WhatIf
)

. .\lib\Add-Log.ps1
. .\lib\Clear-SessionData.ps1
. .\lib\New-ADSession.ps1
. .\lib\Select-DomainController.ps1
. .\lib\Show-TestRun.ps1

# AD Domain Controller Session
$adCmdLets = 'Get-ADUser', 'Set-ADUser'
$dc = Select-DomainController $DomainControllers
New-ADSession $dc $adCmdLets $ADCredential

# Processing
$waitTime = 60 # Minutes
$endTime = '11:00pm'
Add-Log script ("Running every $waitTime minutes until $(Get-Date $endTime -f HH:mm)") $WhatIf
do {
 $users = $null
 Write-Verbose 'Getting qualifying disabled AD User objects'
 $users = Get-ADUser -Filter { (enabled -eq $false) -and
  (employeeID -like "*") -and
  (homepage -like "*@*") -and
  (userAccountControl -ne 514) }
 if ($users) {
  foreach ($obj in $users) {
   # 0x200 (512) is the value for active acocunts
   # 0x0202 for inactive/disabled
   Add-log update ('{0},UserAccountControl = 514 (0x0202)' -f $obj.samAccountName) $WhatIf
   Set-ADUser -Identity $obj.ObjectGUID -Replace @{UserAccountControl = 0x0202 } -WhatIf:$WhatIf
  }
 }
 if (!$WhatIf) {
  Write-Verbose ('Sleeping for {0} minutes...' -f $waitTime)
  Start-Sleep ($waitTime * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge (Get-Date $endTime)) )

Clear-SessionData
Show-TestRun