Param (

 [Parameter(Mandatory=$false)]
 [String] $CertCN,

 [Parameter(Mandatory=$true)]
 [String] $Thumbprint,

 [Parameter(Mandatory=$true)]
 [String] $ApplicationId,

 [Parameter(Mandatory=$true)]
 [String] $TenantId
 )

$TenantId = 1abeafd7-d107-4713-be8a-03e064e14f40
$Thumbprint = 147A5C244FC71314F5BDC0D15A81DE92E6EB253B
$ApplicationId = 651dc920-c826-4199-aa09-d07cdc07b821

#$Thumbprint = (Get-ChildItem cert:\CurrentUser\My\ | Where-Object {$_.Subject -match $CertCN }).Thumbprint
Login-AzureRmAccount -ServicePrincipal -CertificateThumbprint $Thumbprint -ApplicationId $ApplicationId -TenantId $TenantId