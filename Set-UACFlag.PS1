<# 
.SYNOPSIS			
 Bradford requires a specific AD User Account Control flag be chosen to determine if an account has access
 to various CUSD network services. We chose to set the User Account Control flag to 0x0202 for disabled 
 AD accounts. A Powershell script is used to search AD for qualifying user objects and set the flag.
 This process runs every 30 minutes as a scheduled task.
.DESCRIPTION
.EXAMPLE
.INPUTS
.OUTPUTS
.NOTES
#>

[cmdletbinding()]
param ( 
 [Parameter(Mandatory=$True)]
 [Alias('DC','Server')]
 [ValidateScript({Test-Connection -ComputerName $_ -Quiet -Count 1})]
 [string]$DomainController,
 # PSSession to Domain Controller and Use Active Directory CMDLETS  
 [Parameter(Mandatory=$True)]
 [Alias('ADCred')]
 [System.Management.Automation.PSCredential]$ADCredential,
 [SWITCH]$WhatIf 
 )

CLS;$error.clear() # Clear Screen and $error
Get-PSSession | Remove-PSSession

# AD Domain Controller Session
$adCmdLets = 'Get-ADUser','Set-ADUser'
$adSession = New-PSSession -ComputerName $DomainController -Credential $ADCredential
Import-PSSession -Session $adSession -Module ActiveDirectory -CommandName $adCmdLets -AllowClobber

"`nBradford requires a specific AD User Account Control flag be chosen to determine if an account has access
to various CUSD network services.`n
We chose to set the User Account Control flag to 0x0202 for disabled AD accounts.`n
This Powershell script is used to search AD for qualifying user objects and set the flag."

# Processing
"`nRunning every 30 minutes until $(Get-Date "11:30pm" -f hh:mmp)"
do {
 $users = $null
 $users = Get-ADUser -Filter {(enabled -eq $false) -and 
                     (employeeID -like "*") -and 
                     (homepage -like "*@chicousd.net") -and
                     (userAccountControl -ne 514)}
 if ($users){
  "Setting UserAccountControl flag to 514 (0x0202) for`: "
  $users.samAccountName
  $users | %{$samid=$_.SamAccountName;Set-ADUser $samid -Replace @{UserAccountControl=0x0202} -WhatIf:$WhatIf}
 }
 Start-Sleep 1800 # 30 minute wait cycle
} until ( (Get-Date) -ge (Get-Date "11:30pm") )
                    
Write-Verbose "Tearing down sessions"
Get-PSSession | Remove-PSSession