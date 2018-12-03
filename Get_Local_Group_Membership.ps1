$mycredentials = Get-Credential -Message "Enter Credentials" -UserName METNET\dbalsam1
Enter-PSSession -ComputerName iazedvctx0015.metnet.net -Credential $mycredentials
Write-host ""
Write-Host "Administrators Membership"
Get-LocalGroupMember -Group "Administrators"
#Write-Host "Power Users Membership"
#Get-LocalGroupMember -Group "Power Users"
#Write-Host "RDP Users Membership"
#Get-LocalGroupMember -Group "Remote Desktop Users"