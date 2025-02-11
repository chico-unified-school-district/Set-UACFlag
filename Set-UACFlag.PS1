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
 # PSSession to Domain Controller and Use Active Directory cmdlets
 [Parameter(Mandatory = $True)]
 [System.Management.Automation.PSCredential]$ADCredential,
 [SWITCH]$WhatIf
)
$moduleCmds = 'Clear-SessionData', 'New-ADSession', 'Select-DomainController', 'Show-TestRun'
Import-Module -Name CommonScriptFunctions -Cmdlet $moduleCmds -Global

# function New-ADSession ($dc, $cmdlets, $myUser) {
#  $msgVars = $MyInvocation.MyCommand.Name, $dc, ($cmdLets -join ',')
#  Write-Verbose ('{0},{1}' -f $msgVars)
#  $adSession = New-PSSession -ComputerName $dc -Credential $myUser
#  $sessionParams = @{
#   Session      = $adSession
#   Module       = 'ActiveDirectory'
#   CommandName  = $cmdLets
#   AllowClobber = $true
#   ErrorAction  = 'SilentlyContinue'
#  }
#  Import-PSSession @sessionParams | Out-Null
# }

# Processing
$waitTime = 60 # Minutes
$endTime = '11:00pm'
'Running every $waitTime minutes until {0}' -f $(Get-Date $endTime -f HH:mm)
do {
 $dc = Select-DomainController $DomainControllers
 $adCmdLets = 'Get-ADUser', 'Set-ADUser'
 $msgVars = $MyInvocation.MyCommand.Name, $dc, ($adCmdLets -join ',')
 Write-Verbose ('{0},{1},{2}' -f $msgVars)
 New-ADSession $dc $adCmdLets $ADCredential

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
   Write-Host ('{0},{1},UserAccountControl = 514 (0x0202)' -f $MyInvocation.MyCommand.Name, $obj.samAccountName)
   Set-ADUser -Identity $obj.ObjectGUID -Replace @{UserAccountControl = 0x0202 } -WhatIf:$WhatIf
  }
 }

 Clear-SessionData

 if (!$WhatIf) {
  Write-Host ( 'Next run time {0}' -f (Get-Date).AddMinutes(($waitTim)) )
  Start-Sleep ($waitTime * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge (Get-Date $endTime)) )

Show-TestRun