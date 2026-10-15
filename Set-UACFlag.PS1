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
 [Parameter(Mandatory = $True)][PSCredential]$ADCredential,
 [Alias('wi')][SWITCH]$WhatIf
)

function Get-ADData ([pscredential]$cred) {
 process {
  $filter = "EmployeeId -like '*' -and
  HomePage -like '*@*' -and
  -not(Title -like '*Generic*') -and
  -not(Title -like '*Service*') -and
  -not(Description -like '*Test*')
  "
  $params = @{
   Filter     = $filter
   Properties = 'employeeType', 'EmployeeId', 'userAccountControl'
   Credential = $cred
  }
  $users = Get-ADUser @params
  if (!$users) { return }
  $users
 }
}

function Set-UserUACFlag ([pscredential]$cred) {
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
  $msg = $MyInvocation.MyCommand.Name, $_.SamAccountName, $_.employeeType, $_.Enabled, $_.userAccountControl, $uacFlag
  Write-Host ('{0},{1},type:{2},Enabled:{3},Old:{4},New:{5}' -f $msg) -F Cyan
  $params = @{
   Identity   = $_.ObjectGUID
   Replace    = @{ UserAccountControl = $uacFlag }
   Credential = $cred
   WhatIf     = $WhatIf
  }
  Set-ADUser @params
 }
}

Import-Module -Name CommonScriptFunctions
Import-Module -Name ActiveDirectory -Cmdlet Get-ADUser, Set-ADUser -WarningAction SilentlyContinue

if ($WhatIf) { Show-TestRun }

Show-BlockInfo main

$stopTime = Get-Date '6:00pm'
'Running every 60 minutes until {0}' -f $stopTime
do {
 Get-ADData -cred $ADCredential | Set-UserUACFlag -cred $ADCredential
 if ($WhatIf) { break }
 Write-Host ( 'Next run time {0}' -f (Get-Date).AddMinutes((60)) )
 Start-Sleep (60 * 60)
} until ( (Get-Date) -ge $stopTime )

if ($WhatIf) { Show-TestRun }