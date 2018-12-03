 <#- -----------------------------------------------------------SUMMARY-----------------------------------------------------------
       .SYNOPSIS
       +-------------------+
       | Backup_Report.ps1 |
       +-------------------+

       .DESCRIPTION
       +--------------------------------+
       | Azure Backup Compliance Report |
       +--------------------------------+

       .PARAMETER
       +---------------------------------------+
       | Number of days to generate the report |
       +---------------------------------------+

       .INPUTS
       +-----------------------------------------+
       | - Number of days to generate the report |
       | - User credentials                      |
       | - Subscription                          |
       +-----------------------------------------+

       .OUTPUTS
       +------------------------------------------------------------------------------------------------------------+
       | The Azure Backup compliance report for each vault along with a conslidation report as a single excel file. |
       | The result file will be stored locally in the location C:\Backup_job_report.                               |
       +------------------------------------------------------------------------------------------------------------+

       .EXAMPLE
       +-----------------+
       | Run stand alone |
       | C:\.\Run.bat    |
       +-----------------+
 
       .NOTES
       +----------------------------------------------------------------+
       | * Please update the latest version into the $script_version.   |
       | * Requirements:   Powershell v5.1, MS Excel, Azure Powershell. |
       | * Modules required:                                            |
       |    - AzureRm Module                                            |
       |    - ImportExcel Module                                        |
       +----------------------------------------------------------------+

       .VERSION DETAILS
       +-----------+-------------------+----------------+
       | VERSION   |    AUTHOR         |        DATE    |
       +-----------+-------------------+----------------+      
       |  v1.0     |   Vaishali S      |     10/04/2018 |            
       |  v2.0     |   Vaishali S      |     19/04/2018 |
       +-----------+-------------------+----------------+

---------------------------------------------------------------END OF SUMMARY----------------------------------------------------#>



#-------------------------------------------PARAMETERS---------------------------------------------------#

Param(
[parameter(Mandatory=$true)] 
[Datetime] $startDate,
[parameter(Mandatory=$true)]
[Datetime] $endDate)

#----------------------------------------------SCRIPT------------------------------------------------#

#Get the latest version from the change log and update the value here
$ScriptVersion = "V2.0"
Echo "---------------------------------------Script version = $ScriptVersion-----------------------------------------"

$ErrorActionPreference = "SilentlyContinue"

# Login to Azure Account
try
{
    Login-AzureRmAccount -ErrorAction Stop
}
catch
{
    # The exception lands in [Microsoft.Azure.Commands.Common.Authentication.AadAuthenticationCanceledException]

    Write-Host "User Cancelled The Authentication" -ForegroundColor Yellow
    exit
}

    $subscriptionList = Get-AzureRmSubscription -WarningAction SilentlyContinue
    
    $select = $subscriptionList | Select SubscriptionId, Name, State, TenantId | Out-GridView -OutputMode Single -Title "Please select a subscription"
    $selectedSubscriptionID = $select.SubscriptionId
    Write-Host "You have selected the subscription: $selectedSubscriptionID. `n" 

    # Setting the selected subscription
    
    $subscription = Select-AzureRmSubscription -SubscriptionId $selectedSubscriptionID
    $sub = ($subscription.Subscription).Name
    Write-host "Current subscription is $sub. `n"

    # Creating a directory, overrides if any directory exists with the same name

    Write-Host "Creating a directory: C:\Backup_job_report. This operation will override if you have a directory with the same name. `n"
    New-Item C:\Backup_job_report -Type Directory -Force | Out-Null

$BackupSizeList = @()
$ConsolidatedInfo = @()
$ItemList =@()
$result=@()

#Retrieve the Tag values

$tagkeys=Get-AzureRmTag
foreach($tagkey in $tagkeys) 
{
    $tagvalues=(Get-AzureRmTag $tagkey.name).values
    foreach($tagvalue in $tagvalues) 
    {
        $result+=Find-AzureRmResource -tag @{$tagkey.name=$tagvalue.name} | select name,resourcegroupname,location,@{label="tagName";expression={$tagkey.name}},@{label="tagValue";expression={$tagvalue.name}}
    }
}

    # Fetching the list of Azure Recovery Services Vault

    $azure_recovery_services_vault_list = Get-AzureRmRecoveryServicesVault

foreach($azure_recovery_services_vault in $azure_recovery_services_vault_list)
{
    #Set the context

    Set-AzureRmRecoveryServicesVaultContext -Vault $azure_recovery_services_vault

    $vault = $azure_recovery_services_vault.Name

    $container_list = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM 
    foreach($container_list_iterator in $container_list)
    {
        $vmList = Get-AzureRmRecoveryServicesBackupItem -Container $container_list_iterator -WorkloadType AzureVM
        $VM = $vmList.Name
        $VMName = $VM.Split(";")[3]

        $object1 = new-object psobject
        $object1 | Add-Member -Name VMName -MemberType NoteProperty -Value $VMName
        $object1 | add-member -Name VaultName -MemberType NoteProperty -Value $vault
        $ItemList+= $object1       
    }

    #Gather the backup job details for each vault

    $startDate = Get-Date -Date $startDate -DisplayHint Date
    $startDate
    $f = $startDate.ToString("dd-MM-yy")
    $From = ($startDate.ToUniversalTime()).Adddays(+1)
    $From1 = Get-Date $From -Hour 00 -Minute 00 -Second 00
    
    $endDate = Get-Date -Date $endDate -DisplayHint Date
    $T = $endDate.ToString("dd-MM-yy")
    $To1 = ($endDate.ToUniversalTime()).Adddays(+1)   
    $To = Get-Date $To1 -Hour 23 -Minute 59 -Second 59

    Echo "Generating report for the time period $f to $t"

    $JobList = Get-AzureRmRecoveryservicesBackupJob -Operation Backup -From $From1 -To $To1
    $JobList | Select-Object -Property JobId, Operation, Status, WorkloadName, StartTime, EndTime, @{label= "Duration";Expression={ $sec = [math]::floor(($_.duration -split ":")[2]);
    $hour = ($_.duration -split ":" )[0] ; $min = ($_.duration -split ":")[1] ; "$($hour):$($min):$($sec)"}}, BackupManagementType | Export-Excel -WorkSheetname $vault -Path "C:\Backup_job_report\Backup_Report.xlsx"

    #Gather the backup job details to generate the consolidated report

    $ConsolidatedInfo+= $JobList
    
    #Get the VM Backup Size

    $JobIds = $JobList.JobId

    foreach($JobId in $jobIds)
    { 
        $property = (Get-AzureRmRecoveryservicesBackupJobDetails -JobId $JobId | Select-Object -Property Properties).Properties 
        $object = new-object psobject
        $object | Add-Member -Name JobID -MemberType NoteProperty -Value $JobId
        $object | add-member -Name VMName -MemberType NoteProperty -Value $property["VM Name"]
        $object | add-member -Name BackupSize -MemberType NoteProperty -Value $property["Backup Size"]
        $BackupSizeList+= $object 
    }
    
    #Filter the jobs count for each status for each vault

    $totalJobsPerVault = $JobList.Count
    $successJobsPerVault = ($JobList.Status | where {$_ -eq 'Completed'}).count
    If ($successJobsPerVault -eq $null)
    {
        $successJobsPerVault = 0
    }

    $failureJobsPerVault = ($JobList.Status | where {$_ -eq 'Failed'}).count
    If ($failureJobsPerVault -eq $null) 
    {
        $failureJobsPerVault = 0
    }

    $progressJobsPerVault = ($JobList.Status | where {$_ -eq 'InProgress'}).count
    If ($progressJobsPerVault -eq $null) 
    {
        $progressJobsPerVault = 0
    }


    #Perform calculations in excel
    
    $excel = New-Object -ComObject excel.application
    $workbook = $excel.Workbooks.open("C:\Backup_job_report\Backup_Report.xlsx")
    $excel.displayAlerts = $false

    $BackupWorksheet = $workbook.Worksheets.Item($vault) 
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(9)
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(10)
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(11)
    $BackupWorksheet.Cells.Item(1,9) ='Backup Size'
    $BackupWorksheet.Cells.Item(1,10) ='Tag Name'
    $BackupWorksheet.Cells.Item(1,11) ='Tag Value'
    $headerRange = $BackupWorksheet.Range($BackupWorksheet.cells.Item(1,1),$BackupWorksheet.cells.Item(1, 11))
    $headerRange.Font.Bold = $true

    #Add the Tag name and value for respective virtual machines

    $Workload = $ConsolidatedInfo.WorkloadName
    $VMlist = $result.Name

    foreach ($wname in $Workload)
    {
        $Target = $BackupWorksheet.UsedRange.find($wname)
        $First = $Target

        Do
        {
            $row = $Target.row
            if ($result.name -contains $wname)
            {
                $tagName = $result | Select Name,tagName | where {$_.Name -eq $wname}
                $tagValue = $result | Select Name,tagValue | where-object {$_.Name -eq $wname}

                $BackupWorksheet.cells.item($row,10) = $tagName.tagName -join ','
                $BackupWorksheet.cells.item($row,11) = $tagvalue.tagValue -join ','
            }

            Else 
            {
                $BackupWorksheet.cells.item($row,10) = "-"
                $BackupWorksheet.cells.item($row,11) = "-"        
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)
        }
        While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())
    }

    $BSJobList = $BackupSizeList.JobId

    foreach($JobId in $jobIds)
    {

        $Target = $BackupWorksheet.UsedRange.find($JobId)
        $First = $Target

        Do
        {

            $row = $Target.row
            if ($BackupSizeList.JobId -contains $JobId)
            {
                $BackupSize = $BackupSizeList | Select JobId,BackupSize | where {$_.JobId -eq $JobId}
                $BackupWorksheet.cells.item($row,9) = $BackupSize.BackupSize 
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)

        }While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())
    }

    $BackupWorksheet = $BackupWorksheet.UsedRange
    $RowCount = $BackupWorksheet.Rows.Count

    $BackupWorksheet.cells.item(1,5) = "StartTime (In UTC)"
    $BackupWorksheet.cells.item(1,6) = "EndTime (In UTC)"

    $BackupWorksheet.cells.item($RowCount+2,1) = "Subscription name"
    $BackupWorksheet.cells.item($RowCount+2,2) = $sub

    $BackupWorksheet.cells.item($RowCount+3,1) = "Total jobs"
    $BackupWorksheet.cells.item($RowCount+3,2) = $totalJobsPerVault

    $BackupWorksheet.cells.item($RowCount+4,1) = "Total Jobs Completed"
    $BackupWorksheet.cells.item($RowCount+4,2) = $successJobsPerVault
    $BackupWorksheet.cells.item($RowCount+5,1) = "Total Jobs Failed"
    $BackupWorksheet.cells.item($RowCount+5,2) = $failureJobsPerVault
    $BackupWorksheet.cells.item($RowCount+6,1) = "Total Jobs InProgress"
    $BackupWorksheet.cells.item($RowCount+6,2) = $progressJobsPerVault

    $failurePercent = ($failurejobsPerVault/$totalJobsPerVault)*100
    $successPercent = ($successJobsPerVault/$totalJobsPerVault)*100 

    $BackupWorksheet.cells.item($RowCount+7,1) = "Total Failure Percentage"
    $BackupWorksheet.cells.item($RowCount+7,2) = $failurePercent
    $BackupWorksheet.cells.item($RowCount+8,1) = "Total Success Percentage"
    $BackupWorksheet.cells.item($RowCount+8,2) = $successPercent

    $BackupWorksheet.cells.item($RowCount+9,1) = "Time period"
    $BackupWorksheet.cells.item($RowCount+9,2) = $startDate
    $BackupWorksheet.cells.item($RowCount+9,3) = $endDate

    $BackupWorksheet.cells.item($RowCount+10,1) = "Script Version"
    $BackupWorksheet.cells.item($RowCount+10,2) = $ScriptVersion

    $BackupWorksheet.UsedRange.Columns.AutoFit() | Out-Null

    $Workbook.SaveAs("C:\Backup_job_report\Backup_Report.xlsx")
    $Excel.Quit()

    Echo "Created worksheet for vault $Vault"
    
}

    # wait for it to finish

    Start-Sleep -s 5

    #Filter the jobs count for each status for consildated report

    $ConsolidatedInfo | Select-Object -Property JobId, Operation, Status, WorkloadName, StartTime, EndTime, @{label= "Duration";Expression={ $sec = [math]::floor(($_.duration -split ":")[2]);
    $hour = ($_.duration -split ":" )[0] ; $min = ($_.duration -split ":")[1] ; "$($hour):$($min):$($sec)"}}, BackupManagementType | Export-Excel -WorkSheetname ConsolidatedReport -Path "C:\Backup_job_report\Backup_Report.xlsx"
        
    $totalJobs = $ConsolidatedInfo.Count
    $successJobs = ($ConsolidatedInfo.Status | where {$_ -eq 'Completed'}).count
    If ($successJobs -eq $null)
    {
        $successJobs = 0
    }
    
    $failureJobs = ($ConsolidatedInfo.Status | where {$_ -eq 'Failed'}).count
    If ($failureJobs -eq $null) 
    {
        $failureJobs = 0
    }

    $progressJobs = ($ConsolidatedInfo.Status | where {$_ -eq 'InProgress'}).count
    If ($progressJobsPerVault -eq $null) 
    {
        $progressJobs = 0
    }

    $excel = New-Object -ComObject excel.application
    $workbook = $excel.Workbooks.open("C:\Backup_job_report\Backup_Report.xlsx")
    $excel.displayAlerts = $false

    $BackupWorksheet = $workbook.Worksheets.Item("ConsolidatedReport") 
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(9)
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(10)
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(11)
    $BackupWorksheet.Cells.Item(1,9) ='Backup Size'
    $BackupWorksheet.Cells.Item(1,10) ='Tag Name'
    $BackupWorksheet.Cells.Item(1,11) ='Tag Value'
    $BackupWorksheet.Cells.Item(1,12) ='Vault'
    $headerRange = $BackupWorksheet.Range($BackupWorksheet.cells.Item(1,1),$BackupWorksheet.cells.Item(1, 12))
    $headerRange.Font.Bold = $true

    $Workload = $ConsolidatedInfo.WorkloadName
    $VMlist = $result.Name

    foreach ($wname in $Workload)
    {
        $Target = $BackupWorksheet.UsedRange.find($wname)
        $First = $Target

        Do
        {
            $row = $Target.row
            if ($result.name -contains $wname)
            {
                $tagName = $result | Select Name,tagName | where {$_.Name -eq $wname}
                $tagValue = $result | Select Name,tagValue | where-object {$_.Name -eq $wname}

                $BackupWorksheet.cells.item($row,10) = $tagName.tagName -join ','
                $BackupWorksheet.cells.item($row,11) = $tagvalue.tagValue -join ','
            }

            Else 
            {
                $BackupWorksheet.cells.item($row,10) = "-"
                $BackupWorksheet.cells.item($row,11) = "-"        
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)
        }
        While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())

        Do
        {
            $row = $Target.row
            if ($ItemList.VMName -contains $wname)
            {
                $VName = $ItemList | Select VMName,VaultName | where {$_.VMName -eq $wname}

                $BackupWorksheet.cells.item($row,12) = $VName.VaultName
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)
        }
        While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())
    }

   <# foreach ($wname in $Workload)
    {
        $Target = $BackupWorksheet.UsedRange.find($wname)
        $First = $Target

        
    } #>

    $JobIds = $ConsolidatedInfo.JobId

    $BSJobList = $BackupSizeList.JobId

    foreach($JobId in $jobIds)
    {

        $Target = $BackupWorksheet.UsedRange.find($JobId)
        $First = $Target

        Do
        {

            $row = $Target.row
            if ($BackupSizeList.JobId -contains $JobId)
            {
                $BackupSize = $BackupSizeList | Select JobId,BackupSize | where {$_.JobId -eq $JobId}
                $BackupWorksheet.cells.item($row,9) = $BackupSize.BackupSize 
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)

        }While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())
    }

    $BackupWorksheet = $BackupWorksheet.UsedRange
    $RowCount = $BackupWorksheet.Rows.Count

    $BackupWorksheet.cells.item(1,5) = "StartTime (In UTC)"
    $BackupWorksheet.cells.item(1,6) = "EndTime (In UTC)"

    $BackupWorksheet.cells.item($RowCount+2,1) = "Subscription name"
    $BackupWorksheet.cells.item($RowCount+2,2) = $sub

    $BackupWorksheet.cells.item($RowCount+3,1) = "Total jobs"
    $BackupWorksheet.cells.item($RowCount+3,2) = $totalJobs

    $BackupWorksheet.cells.item($RowCount+4,1) = "Total Jobs Completed"
    $BackupWorksheet.cells.item($RowCount+4,2) = $successJobs
    $BackupWorksheet.cells.item($RowCount+5,1) = "Total Jobs Failed"
    $BackupWorksheet.cells.item($RowCount+5,2) = $failureJobs
    $BackupWorksheet.cells.item($RowCount+6,1) = "Total Jobs InProgress"
    $BackupWorksheet.cells.item($RowCount+6,2) = $progressJobs
    
    $failurePercent = ($failurejobs/$totalJobs)*100
    $successPercent = ($successJobs/$totalJobs)*100

    $BackupWorksheet.cells.item($RowCount+7,1) = "Total Failure Percentage"
    $BackupWorksheet.cells.item($RowCount+7,2) = $failurePercent
    $BackupWorksheet.cells.item($RowCount+8,1) = "Total Success Percentage"
    $BackupWorksheet.cells.item($RowCount+8,2) = $successPercent

    $BackupWorksheet.cells.item($RowCount+9,1) = "Time period"
    $BackupWorksheet.cells.item($RowCount+9,2) = $startDate
    $BackupWorksheet.cells.item($RowCount+9,3) = $endDate

    $BackupWorksheet.cells.item($RowCount+10,1) = "Script Version"
    $BackupWorksheet.cells.item($RowCount+10,2) = $ScriptVersion

    $BackupWorksheet.UsedRange.Columns.AutoFit() | Out-Null

$Workbook.SaveAs("C:\Backup_job_report\Backup_Report.xlsx")
$Excel.Quit()

Echo "Created the consolidated report."

# wait for it to finish

Start-Sleep -s 5  

#Logout from the account

Logout-AzureRmAccount
Echo "Logged out of all Azure accounts" 

#Rename the file

Rename-Item -Path "C:\Backup_job_report\Backup_Report.xlsx" -NewName "Backup_Report_$F-to-$T.xlsx" -Force
Echo "The file has been renamed and is now ready to view."

#--------------------------------------------------------END OF SCRIPT------------------------------------------------------#