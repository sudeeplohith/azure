$ShareUserName = "AZURE\mimusncqa7264"
$SharePassword = "Kq+Zb6ONE+wf3UpFl3oWCWXMtxpcDxMTftSf5gvGVhC4TyOJlvinsVwc9yLYN5A6jWTiv96HXhmCQ8ZX+UpphA=="|ConvertTo-SecureString -AsPlainText -Force
$Sharecred = New-Object System.Management.Automation.PSCredential($ShareUserName, $SharePassword)
New-PSDrive -Name "S" -PSProvider FileSystem -Root "\\mimusncqa7264.file.core.windows.net\cmethvhpc0175files" -Credential $Sharecred
Copy-Item S:\HPC2012\HPC2012R2_Update3_Full -Destination C:\temp\HPC2012 -Recurse