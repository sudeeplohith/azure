<#
.NAME
    Create_X509_ClientAccessCertificates_For_ServicePrincipalAccount
.SYNOPSIS  
	 This script will generate an X.509 self-signed certificate for use with a Service Principal credential.
.DESCRIPTION  
	 This script will generate an .509 self-signed certificate with a password which you can use to authenicate to an Azure Subscription using a ServicePrincipal-type certificate login.  Use in conjunciton with your Azure Runbooks.
		
	 You will need to import the *.PFX File in
.EXAMPLE  
	.\Create_X509_ClientAccessCertificates_For_ServicePrincipalAccount.ps1

.PARAMETER  
    Parameters are read in at execution time.  
    -  CertCommonName                           :  Common Name of your certificate which is prefixed by 'CN='***
    -  mypwd                                    :  Password used to protect your private key
   
   ***NOTE: The naming standard for this certificate is <functional role>+<Project ID>+<App Environment>
#>
$CertCommonName = Read-Host "Enter a Common Name for your Certificate. Omit the 'CN='"
$password = Read-Host "Type in your private key password"
$cert = New-SelfSignedCertificate -CertStoreLocation "Cert:\CurrentUser\My" -Subject $CertCommonName -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" -KeySpec None -KeyUsage None -KeyAlgorithm RSA -KeyLength 4096 -KeyExportPolicy Exportable -HashAlgorithm sha256 -NotAfter (Get-Date).AddMonths(6) -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
$mypwd = ConvertTo-SecureString -String $password -Force -AsPlainText
$thumbprint = $cert.Thumbprint
$subject = $cert.Subject
$certpath = "cert:\CurrentUser\my\"+$thumbprint
$filepath = "E:\Credentials\ServicePrinciple\"+$CertCommonName+".pfx"
 Write-Host ""
 Write-Host "The Common Name or Subject of your Certificate is :"-ForegroundColor Cyan $subject
 Write-Host ""
 Write-Host "The Public Key data of your certificate is..." -ForegroundColor Cyan
 Write-Host ""
 Write-Host $keyValue -ForegroundColor Green
 Write-Host ""
 Write-Host "The Thumbprint of your x509 certificate is :"-ForegroundColor Cyan $thumbprint
 Write-Host ""
 Write-Host "The location where you can pick up your Certificate's *.PFX File is..." -ForegroundColor Cyan
 Write-Host ""
Get-ChildItem -Path $certpath | Export-PfxCertificate -FilePath $filepath -Password $mypwd
