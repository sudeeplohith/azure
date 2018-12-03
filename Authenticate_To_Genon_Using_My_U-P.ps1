# The azure account here must not be a Live ID.
$azureAccountName = Read-Host "Enter your Genon E-mail Account, e.g. userID@genon.com"
$azurePassword = Read-Host "Enter your Azure Password" -AsSecureString
$cred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)
$subscriptionID = "4ad3107f-9af6-4894-bea8-b62cf9cc4b0e"
$AzureADtenantID = "309dd320-e9a4-4eb9-8880-6ba863225f98"

Login-AzureRmAccount -Credential $cred
#Set-AzureRMContext -SubscriptionId bb548696-527d-45a9-ab30-c847b7dd3838 -TenantId 1abeafd7-d107-4713-be8a-03e064e14f40