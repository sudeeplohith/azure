#iazncqvhpc0164
$User = Read-Host "Enter METNET userID as 'METNET\userID'"
$Password = Read-Host "Enter METNET ID Password"
$PWord = ConvertTo-SecureString -String $Password -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
$Session = New-PSSession -ComputerName "iazncqvhpc0001.metnet.net" -Credential $Credential
Copy-Item "E:\Software\Powershell5.1-4-W2K12\" -Destination "B:\software\PS4.1-to-5.1-Patches" -ToSession $Session -Recurse
#Invoke-Command -Session $session -ScriptBlock {Expand-Archive -LiteralPath B:\software\HPC2012\HPC2012R2_Update3_Full_Refresh_4.5.5194.zip -DestinationPath B:\software\HPC2012\HPC2012R2_Update3_Full_4_5_5094 } 
Invoke-Command -Session $session -ScriptBlock {Get-Childitem -Path "B:\software\PS4.1-to-5.1-Patches\" -Recurse}
Remove-PSSession -Session $Session