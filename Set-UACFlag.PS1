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
 [Parameter(Mandatory = $True)][Alias('DCs')][string[]]$DomainControllers,
 [Parameter(Mandatory = $True)][System.Management.Automation.PSCredential]$ADCredential,
 [string]$StudentSearchBase,
 [string]$StaffSearchBase,
 [Alias('wi')][SWITCH]$WhatIf
)


function Get-ADData ($ou) {
 process {
  $params = @{
   Filter     = "EmployeeId -like '*' -and HomePage -like '*@*'"
   SearchBase = $ou
   Properties = 'employeeType', 'EmployeeId', 'userAccountControl'
  }
  $users = Get-ADUser @params
  if (!$users) { return }
  $users
 }
}

function Set-UserUACFlag {
 begin {
  $activeStaff = 512 #      (This should be “Normal Account”)
  $disabledStaff = 514 #    (This should be “Normal Account, Disabled”)
  $activeStudent = 544 #    (This should be “Password Not Required, Normal Account”)
  $disabledStudent = 546  # (This should be “Password Not Required, Normal Account)
 }
 process {
  $uacFlag = if ($_.employeeType -eq 'student' -and $_.Enabled -eq $true) { $activeStudent }
  elseif ($_.employeeType -eq 'student' -and $_.Enabled -eq $false) { $disabledStudent }
  elseif ($_.employeeType -ne 'student' -and $_.Enabled -eq $true) { $activeStaff }
  else { $disabledStaff }
  if ($_.userAccountControl -eq $uacFlag) { return }
  Write-Host ('{0},{1},Enabled:{2},Old:{3},New:{4}' -f $MyInvocation.MyCommand.Name, $_.SamAccountName, $_.Enabled, $_.userAccountControl, $uacFlag) -F Cyan
  Set-ADUser -Identity $_.ObjectGUID -Replace @{UserAccountControl = $uacFlag } -WhatIf:$WhatIf
 }
}

Import-Module -Name CommonScriptFunctions

if ($WhatIf) { Show-TestRun }
Show-BlockInfo main
$adCmdLets = 'Get-ADUser', 'Set-ADUser'
'Running every 60 minutes until {0}' -f $(Get-Date '6:00pm')
do {
 Connect-ADSession $DomainControllers $ADCredential $adCmdLets
 Get-ADData $StaffSearchBase | Set-UserUACFlag
 Get-ADData $StudentSearchBase | Set-UserUACFlag
 Clear-SessionData
 if (!$WhatIf) {
  Write-Host ( 'Next run time {0}' -f (Get-Date).AddMinutes((60)) )
  Start-Sleep (60 * 60)
 }
} until ( $WhatIf -or ((Get-Date) -ge (Get-Date '6:00pm')) )
if ($WhatIf) { Show-TestRun }