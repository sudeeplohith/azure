# The azure account here must not be a Live ID.
$azureAccountName = Read-Host "Enter your Metlife E-mail Account, e.g. userID@metlife.com"
$azurePassword = Read-Host "Enter your Azure Password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)
$subscriptionID = "77b083f7-d8e8-4deb-a6e7-af3e278eae5c"
$AzureADtenantID = "ca56a4a5-e300-406a-98ff-7e36a0baac5b"

Login-AzureRmAccount -Credential $cred
Set-AzureRMContext -SubscriptionId $subscriptionID -TenantId $AzureADtenantID