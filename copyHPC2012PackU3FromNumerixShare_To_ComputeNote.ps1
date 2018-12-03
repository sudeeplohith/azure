$User = "METNET\dbalsam1"
$PWord = ConvertTo-SecureString -String "aMg33PhS%6@8" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord
$server = "iazncqvhpc0161.metnet.net"
$session = New-PSSession -ComputerName $server -Credential $Credential
#$remoteFolderPath = "S:\HPC2012\HPC2012R2_Update3_Full"
$ShareUserName = "AZURE\mimusncqa7264"
$SharePassword = "Kq+Zb6ONE+wf3UpFl3oWCWXMtxpcDxMTftSf5gvGVhC4TyOJlvinsVwc9yLYN5A6jWTiv96HXhmCQ8ZX+UpphA=="|ConvertTo-SecureString -AsPlainText -Force
$Sharecred = New-Object System.Management.Automation.PSCredential($ShareUserName, $SharePassword)
$script = {net use S: \\mimusncqa7264.file.core.windows.net\cmethvhpc0175files /PERSISTENT:NO /u:AZURE\mimusncqa7264 Kq+Zb6ONE+wf3UpFl3oWCWXMtxpcDxMTftSf5gvGVhC4TyOJlvinsVwc9yLYN5A6jWTiv96HXhmCQ8ZX+UpphA== ; dir S: ; Copy-Item S:\HPC2012\HPC2012R2_Update3_Full -Destination C:\temp\HPC2012 -Recurse ; Get-Childitem -Path C:\temp\HPC2012 -Recurse } 

Invoke-Command -Session $session -ScriptBlock $script
Invoke-Command -Session $session -ScriptBlock {Start-Sleep -s 5}
Invoke-Command -Session $session -ScriptBlock {Remove-PSDrive -Name "S"}
Remove-PSSession -Session $session