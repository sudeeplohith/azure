###MetlifeEAQRMAutomate### Connection Object

###The Following is the PS Script used to setup a service principle (applicationID) which uses a X.509 (public + private key) certificate for authentication.###
###Script Guidance###
###https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal#create-service-principal-with-self-signed-certificate
###Author :: Daniel Balsam
###Prereqs for execution :: run on Windows 2016 or Windows 10 host with Access to Azure API
###Input Parameters: $ApplicationDisplayName, $SubscriptionId, $ResourceGroup
###$SubscriptionId = 77b083f7-d8e8-4deb-a6e7-af3e278eae5c
###$ApplicationDisplayName = "MetlifeQRMWorkloadMgtAutomation"
###$ResourceGroup = mim-use-10948-rg

Param (

 # Use to set scope to resource group. If no value is provided, scope is set to subscription.
 [Parameter(Mandatory=$true)]
 [String] $ResourceGroup,

 # Use to set subscription. If no value is provided, default subscription is used.
 [Parameter(Mandatory=$true)]
 [String] $SubscriptionId,

 [Parameter(Mandatory=$true)]
 [String] $ApplicationDisplayName

 )

#Use your individual Azure account to login
Write-Host "Now Login to Azure using your Metlife E-mail and METNET ID"
Sleep 5
$creds = Get-Credential
Login-AzureRmAccount -Credential $creds
Import-Module AzureRM.Resources

 if ($SubscriptionId -eq "")
 {
    $SubscriptionId = (Get-AzureRmContext).Subscription.Id
 }
 else
 {
    Set-AzureRmContext -SubscriptionId $SubscriptionId
 }

 if ($ResourceGroup -eq "")
 {
    $Scope = "/subscriptions/" + $SubscriptionId
 }
 else
 {
    $Scope = (Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop).ResourceId
 }

 #Craft the Certificate Common Name
 $CertCommonName = "CN="+$ApplicationDisplayName

 #Check your variables before you create the account
 write-host $ResourceGroup
 write-host $ApplicationDisplayName
 write-host $SubscriptionId
 write-host $CertCommonName

Sleep 15

 #Generate the Self-Signed Cert using the Parameters

 $cert = New-SelfSignedCertificate -CertStoreLocation "Cert:\CurrentUser\My" -Subject $CertCommonName -KeySpec None -KeyUsage None -KeyAlgorithm RSA -KeyLength 2048 -KeyExportPolicy Exportable -HashAlgorithm sha256 -NotAfter (Get-Date).AddMonths(12) -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
 $keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())



 $ServicePrincipal = New-AzureRMADServicePrincipal -DisplayName $ApplicationDisplayName -CertValue $keyValue -EndDate $cert.NotAfter -StartDate $cert.NotBefore
 Get-AzureRmADServicePrincipal -ObjectId $ServicePrincipal.Id

 $NewRole = $null
 $Retries = 3;
 While ($NewRole -eq $null -and $Retries -le 6)
 {
    # Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
    Sleep 15
    New-AzureRMRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $ServicePrincipal.ApplicationId -Scope $Scope | Write-Verbose -ErrorAction SilentlyContinue
    $NewRole = Get-AzureRMRoleAssignment -ServicePrincipalName $ServicePrincipal.ApplicationId -ErrorAction SilentlyContinue
    $Retries++;
 }