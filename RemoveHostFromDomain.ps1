$hostname = Read-host "What is the hostname you are trying to join to the domain?"
#$ouPath = Read-host "WHat is the OU Path"
Remove-Computer -UnjoinDomainCredential METNET\dbalsam1 -ComputerName $hostname -Confirm -Force -LocalCredential $hostname\rootadmin -PassThru -WorkgroupName temp