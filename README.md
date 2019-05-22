# Set-UACFlag
Sets the 'userAccountControl' flag for disabled Active Directory user objects.

Bradford requires a specific AD User Account Control flag be set to determine if an account has access
to various CUSD network services. 

The User Account Control flag for disabled dobjects is 0x0202. 
A Powershell script is used to search AD for qualifying disabled user objects and set the flag.