$hostname = Read-host "What is the hostname you are trying to join to the domain?"
$ouPath = Read-host "WHat is the OU Path"
Add-Computer -ComputerName $hostname -LocalCredential $hostname\rootadmin -DomainName metnet.net -Credential METNET\dbalsam1 -OUPath $ouPath -passthru -ErrorAction Stop