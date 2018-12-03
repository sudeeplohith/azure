##
## Get Time Zones
##
#
$User = Read-Host "Enter your METNET ID as 'METNET\userID'"
$Password = Read-Host "Enter your METNET ID password"
$PWord = ConvertTo-SecureString -String $Password -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
##
## Grab target destinations
##
$targets = import-csv "E:\Scripts\ServerBuilds\TimeJobTargets.csv"
$results = New-Object -TypeName System.Collections.ArrayList
$results = @();
ForEach ($target in $targets) {
$server =  $($target.destinationHost)
Write-host "Starting Session on Host: $server" -ForegroundColor Cyan
$session = New-PSSession -ComputerName $server -Credential $Credential
$script = {
    tzutil /g
   } 
$results += $server+"::"+(Invoke-Command -Session $session -ScriptBlock $script)
Remove-PSSession -Session $session
Write-host "Ending Session on Host: $server" -ForegroundColor Cyan
}
$results