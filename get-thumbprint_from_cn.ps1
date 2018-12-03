$cn = Read-Host "Please enter the common name of the Root certificate"
$thumbprint = (Get-ChildItem -Path "Cert:\CurrentUser\My\" | Where-Object {$_.Subject -match $cnstub}).Thumbprint -join ";" ;
Write-Host "My Thumprint is : " $thumbprint