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
 [Alias('wi')]
 [SWITCH]$WhatIf
)


function Get-ADData {
 process {
  $params = @{
   Filter = "Enabled -eq 'False' -and EmployeeId -like '*' -and HomePage -like '*@*' -and userAccountControl -ne 514"
  }
  $users = Get-ADUser @params
  if (!$users) { return }
  $users
 }
}

function Set-UserUACFlag {
 process {
  # 0x200 (512) is the value for active acocunts
  # 0x0202 for inactive/disabled
  Write-Host ('{0},{1},UserAccountControl = 514 (0x0202)' -f $MyInvocation.MyCommand.Name, $_.SamAccountName) -F Magenta
  Set-ADUser -Identity $_.ObjectGUID -Replace @{UserAccountControl = 0x0202 } -WhatIf:$WhatIf
 }
}

Import-Module -Name CommonScriptFunctions
if ($WhatIf) { Show-TestRun }
Show-BlockInfo main
$adCmdLets = 'Get-ADUser', 'Set-ADUser'
'Running every 60 minutes until {0}' -f $(Get-Date '6:00pm')
do {
 Connect-ADSession $DomainControllers $ADCredential $adCmdLets
 Get-ADData | Set-UserUACFlag
 Clear-SessionData
 if (!$WhatIf) {
  Write-Host ( 'Next run time {0}' -f (Get-Date).AddMinutes((60)) )
  Start-Sleep (60 * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge (Get-Date '6:00pm')) )
if ($WhatIf) { Show-TestRun }