#!/bin/sh
# Cleans up erroneous Tags within VMs in a specific resource group
rg="mim-usnc-qa-7264-rg"
#Generate list of IDs
vms=$(az vm list -g $rg --query "[].id" -o tsv)
#Clear existing tags
az resource tag --tags '' --ids $vms
#query tags
az vm list -g $rg --query "[].{name:name,tags:tags}" 
#add tags back
az resource tag --ids $vms --tags "ARM_Template"="hpc-compute-v3" "Application"="Numerix XVA" "DPCCODE"="SCMD BDIN DIST" "DXC_AutoDeploy"="False" "DepartmentName"="QUALITY ASSURANCE" "EAICODE"="7264" "Numerix XVA (7264)"="Inv_Numerix_AM@metlife.com" "Primary Contact Email"="inv_env_team@metlife.com" "Primary Contact Phone"="1-973-368-9721" "Project"="7264" "Secondary Contact Email"="itg_inv_engineering_team@metlife.com"
#query tags
az vm list -g $rg --query "[].{name:name,tags:tags}"