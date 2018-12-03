$Credentials = Get-Credential
$Computer = "iazedvapp0044"
#$Computer = get-content <filename>
#foreach ($comp in $computer){ <loop code goes here>}
$Results = Invoke-Command -Computer $Computer -Credential $Credentials -Script { Get-ComputerInfo -Property CsDNSHostName,TimeZone | select CsDNSHostName,TimeZone | ft }
$Results | Out-File -FilePath E:\Queries\results_timecheck.csv -Append