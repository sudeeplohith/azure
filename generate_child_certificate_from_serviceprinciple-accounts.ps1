#This script generates a child certificate based on a root certificate common name input, and exports it to a *.pfx file.
# = Read-Host "Please enter common name of the root certificate"
$rccn = Read-Host "Please enter the common name of the Root certificate"
$thumbprint = (Get-ChildItem -Path "Cert:\CurrentUser\My\" | Where-Object {$_.Subject -match $rccn}).Thumbprint -join ";";
#####
#Create Child Certificate Common Name
#####
#Naming Syntax :: <Fnction>+"ChildCert"+<app ID>-<Environment>-<createdate> 
#E.G. :: StartStopVMAutomateRootCertDEV20180716
# <Function> = StartStopVMAutomate
# <appID> = 10948
# <env>   = DEV
# <createdate = 20180716
# =StartStopVMAutomateChildCert-10948-DEV-20180716
$function = Read-Host "What is the function of the Child Cert?"
$appID = Read-Host "What is the name of the appID?"
$env = Read-Host "What is the app environment (DEV, TEST, QA, PROD)?"
$createdate = Read-Host "What is today's date (yyyymmdd)?"
$cccn = "CN="+$function+"ChildCert"+"-"+$appID+"-"+$env+"-"+$createdate
$rootcertpath = "cert:\CurrentUser\my\"+$thumbprint
#sign the new child certificate with the root certificate
$rootcert = Get-ChildItem -Path $rootcertpath 
$childcert = New-SelfSignedCertificate -Type Custom -KeySpec Signature ` -Subject $cccn -KeyExportPolicy Exportable ` -HashAlgorithm sha256 -KeyLength 4096 ` -CertStoreLocation "Cert:\CurrentUser\My" ` -Signer $rootcert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
Write-Host "This is the new Common Name :"$childcert.Subject
Write-Host "This is the new Thumbprint :"$childcert.Thumbprint
###Add in a private key password
$pwd = Read-Host " Please enter a private key password of 4 digits which include at least 4 uppercase, 4 lowercase, 4 numbers"
$pkpwd = ConvertTo-SecureString -String $pwd -Force -AsPlainText
$filepath = "E:\Credentials\ServicePrinciple\"+$function+"ChildCert"+"-"+$appID+"-"+$env+"-"+$createdate+".pfx"
$childcertpath = "cert:\CurrentUser\my\"+$childcert.Thumbprint
Get-ChildItem -Path $childcertpath | Export-PfxCertificate -FilePath $filepath -Password $pkpwd