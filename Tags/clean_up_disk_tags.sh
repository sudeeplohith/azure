rg="mim-usnc-qa-7264-rg"
#Generate list of IDs
disk=$(az disk list -g $rg --query "[].id" -o tsv)
az disk list -g $rg --query "[].{name:name,tags:tags}" 
#Clear existing tags
az resource tag --tags '' --ids $disk
az disk list -g $rg --query "[].{name:name,tags:tags}" 
#Add Tags back
az resource tag --tags "ARM_Template"="hpc-compute-v3" "Application"="Numerix XVA" "DPCCODE"="SCMD BDIN DIST" "DXC_AutoDeploy"="False" "DepartmentName"="QUALITY ASSURANCE" "EAICODE"="7264" "Project"="7264" --ids $disk