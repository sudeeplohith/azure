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
       +------------------------------------------------+
       | Start date and end date to generate the report |
       +------------------------------------------------+

       .INPUTS
       +--------------------------------------------------+
       | - Start date and end date to generate the report |
       | - User credentials                               |
       | - Subscription                                   |
       +--------------------------------------------------+

       .OUTPUTS
       +------------------------------------------------------------------------------------------------------------+
       | The Azure Backup compliance report for each vault along with a conslidation report as a single excel file. |
       | The result file will be stored locally in the location E:\Reports\Backup_job_report.                               |
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
       |  v3.0     |   Vaishali S      |     31/07/2018 |
       +-----------+-------------------+----------------+

---------------------------------------------------------------END OF SUMMARY----------------------------------------------------#>



#-------------------------------------------PARAMETERS---------------------------------------------------#

Param(
[parameter(Mandatory=$true)] 
[Datetime] $startDate,
[parameter(Mandatory=$true)]
[Datetime] $endDate,
[parameter(Mandatory=$true)]
[String] $TagName)

#----------------------------------------------DECLARATIONS------------------------------------------------#

$BackupSizeList = @()
$ConsolidatedInfo = @()
$ItemList =@()
$result=@()
$FormattedDate = Get-Date -Format "yyyy-MM-dd hh:mm tt"

#----------------------------------------------CHECK THE PRE-REQUESITIES------------------------------------------------#

###################
# Check PSVersion #
###################

$Link = "https://www.microsoft.com/en-us/download/details.aspx?id=50395"
$ps = $psversiontable.PSVersion
$Major = $ps.Major
$Minor = $ps.Minor
$version = "$Major"+'.'+"$Minor"
Echo "`n#---------------------------------------------------------------------------------#"

if($version -lt 5)
{
    Write-Host "`nCurrent Powershell Version: $version. Upgrade Powershell version to 5.0 or above to continue the script execution." -ForegroundColor Yellow
    write-host "`nLink: $Link`n" -ForegroundColor DarkCyan
    Write-Error " Script execution stopped " -ErrorAction Stop
}
else
{
    write-host "`nPowershell Version: $version`nContinuing with the script execution...`n"
}

###########################################
# Check if required modules are installed #
###########################################

Echo "#---------------------------------------------------------------------------------#`n"
$Modules = @("AzureRm", "ImportExcel", "AzureRM.RecoveryServices","AzureRM.RecoveryServices.Backup")
foreach($Module in $Modules)
{
    if (Get-Module -ListAvailable -Name $Module) 
    {
        Write-Host "$Module Module exists"
    } 
    else 
    {
        Install-Module -Name $Module -Force -AllowClobber
        Import-Module -Name $Module -Force
    } 
} 

###########################################
# Check if Excel application is installed #
###########################################

$Application = Get-WmiObject -Class Win32_Product | ? {$_.Name -match "Office 16"} | Select Name
If($Application -ne $null) {
    
    Echo "`nExcel application is available"
    }

Else {

    Write-Host "`nExcel applciation is required to run this script. Please install and then continue the execution."
    Write-Error " Script execution stopped " -ErrorAction Stop
    }

#----------------------------------------------CHECK FOR LOG FILE--------------------------------------------#

# Check if log file exists

Echo "`n#---------------------------------------------------------------------------------#"

# Creating a directory, overrides if any directory exists with the same name

Write-Host "`nCreating a directory: E:\Reports\Backup_job_report. This operation will override if you have a directory with the same name.`n"
New-Item C:\Backup_job_report -Type Directory -Force | Out-Null

$logFile = "E:\Reports\Backup_job_report\AzureBackupReport.log"
If(Test-Path "$logFile")
{
    $CreatedOn = (Get-ChildItem $logFile).CreationTime
    $currentDate = Get-date
    $Days = (New-TimeSpan -Start $CreatedOn -End $currentDate).Days
    If($Days -gt 10)
    {
        Remove-Item $logFile
        New-Item -Path "E:\Reports\Backup_job_report" -Name "AzureBackupReport.log" -ItemType file | Out-Null
        Write-Host "`nCreated a new log file $logFile after deleting the old log file"
    }
    Else
    {
        Write-Host "`n$logFile is available"
    }
}
Else
{
    $logFile = New-Item -Path "E:\Reports\Backup_job_report" -Name "AzureBackupReport.log" -ItemType file
    Write-Host "`nCreated a new log file $logFile"
}

#----------------------------------------------SCRIPT------------------------------------------------#

#Get the latest version from the change log and update the value here
$ScriptVersion = "V3.0"
Write-Host "`n#-----------------------------Script version = $ScriptVersion-------------------------------#" -ForegroundColor Green

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

# Login to Azure Account
try
{
    $login = Login-AzureRmAccount -ErrorAction Stop
}
catch
{
    "$FormattedDate : ERRO : User cancelled the subscription" | Out-File -FilePath $logfile -Append
    Write-Error "User Cancelled The Authentication" -ErrorAction Stop
}

$User = $login.Context.Account
"$FormattedDate : INFO : The user $User has logged into the Azure environment successfully" | Out-File -FilePath $logfile -Append
Write-Host "`nThe user $User has logged into Azure environment successfully."

$subscriptionList = Get-AzureRmSubscription -WarningAction SilentlyContinue
$selectedSubscriptionList = $subscriptionList | Select SubscriptionId, Name, State, TenantId | Out-GridView -OutputMode Multiple -Title "Please select the subscription(s)"
    
Foreach($Subscription in $selectedSubscriptionList){ 
   
    $selectedSubscriptionID = $Subscription.SubscriptionId

    # Setting the selected subscription
    
    $subscription = Select-AzureRmSubscription -SubscriptionId $selectedSubscriptionID
    $sub = ($subscription.Subscription).Name
    Echo "`nYou are now accessing the following subscription."
    Write-host "`nName: '$sub' `nID: $selectedSubscriptionID`n" -ForegroundColor Cyan
    if($sub -ne '')
    {
        "$FormattedDate : INFO : Accessing the '$sub' subcription." | Out-File -FilePath $logfile -Append
    }
    else
    {
        "$FormattedDate : ERRO : Couldn't access the '$sub' subcription" | Out-File -FilePath $logfile -Append
    }
    Echo "#---------------------------------------------------------------------------------#"

    ############################################
    # Check if required services are available #
    ############################################

    $Services = @("Microsoft.RecoveryServices","Microsoft.Backup")
    Foreach($Service in $Services) {

        $Output = Get-AzureRmResourceProvider -ProviderNamespace "$Service"
        If($Output -eq $null) {
        
            Register-AzureRmResourceProvider -ProviderNamespace $Service
            Echo "Registered the service $Service."
        }

        Else {

            Echo "$Service has been registered already."
        }
    }
    Echo "`n#---------------------------------------------------------------------------------#`n"

    #Retrieve the Tag values

$VMList = Get-AzureRmVM
$TagList = $VMList | Select Name,Tags 
foreach($Tag in $TagList) {
    
    $Tags = $Tag.Tags 
    $List = new-object psobject
    $List | Add-Member -Name Name -MemberType NoteProperty -Value $Tag.Name
    $List | Add-Member -Name TagName -MemberType NoteProperty -Value $TagName
    If($Tags["$TagName"] -ne $null) {
    $List | Add-Member -Name TagValue -MemberType NoteProperty -Value $Tags["$TagName"]}
    Else {
    $List | Add-Member -Name TagValue -MemberType NoteProperty -Value "-"}
    $result+=$List
}
    Write-host "`nThe tag details for the '$sub' subcription has been collected.`n"
    "$FormattedDate : INFO : The tag details for the '$sub' subcription has been collected." | Out-File -FilePath $logfile -Append

    # Fetching the list of Azure Recovery Services Vault

    $azure_recovery_services_vault_list = Get-AzureRmRecoveryServicesVault

    foreach($azure_recovery_services_vault in $azure_recovery_services_vault_list){

        #Set the context

        Set-AzureRmRecoveryServicesVaultContext -Vault $azure_recovery_services_vault

        $vault = $azure_recovery_services_vault.Name

        $container_list = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM 
        foreach($container_list_iterator in $container_list){

            $vmList = Get-AzureRmRecoveryServicesBackupItem -Container $container_list_iterator -WorkloadType AzureVM
            $VM = $vmList.Name
            $VMName = $VM.Split(";")[3]

            $object1 = new-object psobject
            $object1 | Add-Member -Name VMName -MemberType NoteProperty -Value $VMName
            $object1 | add-member -Name VaultName -MemberType NoteProperty -Value $vault
            $object1 | add-member -Name Subscription -MemberType NoteProperty -Value $sub
            $ItemList+= $object1       
        }

        #Gather the backup job details for each vault

        $startDate = Get-Date -Date $startDate -DisplayHint Date
        $f = $startDate.ToString("dd-MM-yy")
        $From = ($startDate.ToUniversalTime()).Adddays(+1)
        $From1 = Get-Date $From -Hour 00 -Minute 00 -Second 00
    
        $endDate = Get-Date -Date $endDate -DisplayHint Date
        $T = $endDate.ToString("dd-MM-yy")
        $To1 = ($endDate.ToUniversalTime()).Adddays(+1)   
        $To = Get-Date $To1 -Hour 23 -Minute 59 -Second 59

        Echo "`nFetching Backup job details from the vault $vault."

        $JobList = Get-AzureRmRecoveryservicesBackupJob -Operation Backup -From $From1 -To $To1
        $JobList | Select-Object -Property JobID,WorkloadName,BackupManagementType,StartTime,EndTime,@{label= "Duration";Expression={ $sec = [math]::floor(($_.duration -split ":")[2]);
        $hour = ($_.duration -split ":" )[0] ; $min = ($_.duration -split ":")[1] ; "$($hour):$($min):$($sec)"}},Status | Out-Null

        #Gather the backup job details to generate the consolidated report

        $ConsolidatedInfo+= $JobList

        Write-host "`nFetched Backup job from the vault $vault."
        "$FormattedDate : INFO : Fetched Backup job from the vault $vault for the time period $f to $t." | Out-File -FilePath $logfile -Append
    
        #Get the VM Backup Size

        $JobIds = $JobList.JobId

        foreach($JobId in $jobIds){ 

            $JobDetails = Get-AzureRmRecoveryservicesBackupJobDetails -JobId $JobId
            $JobProperties = $JobDetails.Properties
            if($JobDetails.Status -eq "Failed"){

                $ErrorMessage = $JobDetails.errordetails.ErrorMessage
            }
            Else{

                $ErrorMessage = "-"
            }

            $object = new-object psobject
            $object | Add-Member -Name JobID -MemberType NoteProperty -Value $JobId
            $object | add-member -Name VMName -MemberType NoteProperty -Value $JobProperties["VM Name"]
            $object | add-member -Name BackupSize -MemberType NoteProperty -Value $JobProperties["Backup Size"]
            $object | add-member -Name ErrorMessage -MemberType NoteProperty -Value $ErrorMessage
            $BackupSizeList+= $object 
            
        }

        Write-host "`nFetched Backup size value and error message from $vault.`n" 
        "$FormattedDate : INFO : Fetched Backup size value and error message from $vault." | Out-File -FilePath $logfile -Append
        Echo "#---------------------------------------------------------------------------------#" 
    } 
}

    # wait for it to finish

    Start-Sleep -s 5

    #Filter the jobs count for each status for consildated report

    $ConsolidatedInfo | Select-Object -Property WorkloadName,JobID,BackupManagementType,StartTime,EndTime,@{label= "Duration";Expression={ $sec = [math]::floor(($_.duration -split ":")[2]);
        $hour = ($_.duration -split ":" )[0] ; $min = ($_.duration -split ":")[1] ; "$($hour):$($min):$($sec)"}},Status | Export-Excel -WorkSheetname ConsolidatedReport -Path "E:\Reports\Backup_job_report\Backup_Report.xlsx"
    
    Write-host "`nExported the Backup job details for all the subscription(s).`n"
    "$FormattedDate : INFO : Exported the Backup job details for all the subscription(s)." | Out-File -FilePath $logfile -Append
    Echo "#---------------------------------------------------------------------------------#"
        
    $totalJobs = $ConsolidatedInfo.Count
    $successJobs = ($ConsolidatedInfo.Status | where {$_ -eq 'Completed'}).count
    If ($successJobs -eq $null){

        $successJobs = 0
    }
    
    $failureJobs = ($ConsolidatedInfo.Status | where {$_ -eq 'Failed'}).count
    If ($failureJobs -eq $null){

        $failureJobs = 0
    }

    $progressJobs = ($ConsolidatedInfo.Status | where {$_ -eq 'InProgress'}).count
    If ($progressJobsPerVault -eq $null){

        $progressJobs = 0
    }

    $excel = New-Object -ComObject excel.application
    $workbook = $excel.Workbooks.open("E:\Reports\Backup_job_report\Backup_Report.xlsx")
    $excel.displayAlerts = $false

    $BackupWorksheet = $workbook.Worksheets.Item("ConsolidatedReport") 
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(10)
    $BackupWorksheet.Columns.ListObject.ListColumns.Add(11)

    $range = $BackupWorksheet.Range("A:A").EntireColumn
    $range.Insert($xlShiftToLeft) | Out-null
    $range.Insert($xlShiftToLeft) | Out-null
    $range.Insert($xlShiftToLeft) | Out-null
    
    $BackupWorksheet.cells.item(1,1) = "Subscription"
    $BackupWorksheet.cells.item(1,2) = "Vault" 
    $BackupWorksheet.cells.item(1,3) = $TagName
    $BackupWorksheet.Cells.Item(1,11) ='BackupSize'
    $BackupWorksheet.Cells.Item(1,12) ='ErrorMessage'
    $headerRange = $BackupWorksheet.Range($BackupWorksheet.cells.Item(1,1),$BackupWorksheet.cells.Item(1, 13))
    $headerRange.Font.Bold = $true

    $Workload = $ConsolidatedInfo.WorkloadName
    $VMlist = $result.Name

    foreach ($wname in $Workload){

        $Target = $BackupWorksheet.UsedRange.find($wname)
        $First = $Target

        Do{

            $row = $Target.row
            if ($result.name -contains $wname){

                $tagValue = $result | Select Name,tagValue | where-object {$_.Name -eq $wname}
                $BackupWorksheet.cells.item($row,3) = $tagvalue.tagValue -join ','
            }
            Else{

                $BackupWorksheet.cells.item($row,3) = "-"        
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)
        }
        While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())

        Do{

            $row = $Target.row
            if ($ItemList.VMName -contains $wname){

                $VName = $ItemList | Select VMName,VaultName,Subscription | where {$_.VMName -eq $wname}
                $BackupWorksheet.cells.item($row,2) = $VName.VaultName
                $BackupWorksheet.cells.item($row,1) = $VName.Subscription
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)
        }
        While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())
    }

    $JobIds = $ConsolidatedInfo.JobId
    $BSJobList = $BackupSizeList.JobId

    foreach($JobId in $jobIds){

        $Target = $BackupWorksheet.UsedRange.find($JobId)
        $First = $Target

        Do{

            $row = $Target.row
            if ($BSJobList -contains $JobId){

                $BackupSize = $BackupSizeList | Select JobId,BackupSize,ErrorMessage | where {$_.JobId -eq $JobId}
                $BackupWorksheet.cells.item($row,11) = $BackupSize.BackupSize
                $BackupWorksheet.cells.item($row,12) = $BackupSize.ErrorMessage
            }

            $Target = $BackupWorksheet.UsedRange.FindNext($Target)
        }
        While ($Target -ne $NULL -and $Target.AddressLocal() -ne $First.AddressLocal())
    }

    $BackupWorksheet = $BackupWorksheet.UsedRange
    $RowCount = $BackupWorksheet.Rows.Count

    $BackupWorksheet.cells.item(1,7) = "StartTime (In UTC)"
    $BackupWorksheet.cells.item(1,8) = "EndTime (In UTC)"

    $BackupWorksheet.cells.item($RowCount+2,1) = "Total jobs"
    $BackupWorksheet.cells.item($RowCount+2,2) = $totalJobs

    $BackupWorksheet.cells.item($RowCount+3,1) = "Total Jobs Completed"
    $BackupWorksheet.cells.item($RowCount+3,2) = $successJobs
    $BackupWorksheet.cells.item($RowCount+4,1) = "Total Jobs Failed"
    $BackupWorksheet.cells.item($RowCount+4,2) = $failureJobs
    $BackupWorksheet.cells.item($RowCount+5,1) = "Total Jobs InProgress"
    $BackupWorksheet.cells.item($RowCount+5,2) = $progressJobs
    
    $failurePercent = [Int](($failurejobs/$totalJobs)*100)
    $successPercent = [Int](($successJobs/$totalJobs)*100)

    $BackupWorksheet.cells.item($RowCount+6,1) = "Total Failure Percentage"
    $BackupWorksheet.cells.item($RowCount+6,2) = "$failurePercent%"
    $BackupWorksheet.cells.item($RowCount+7,1) = "Total Success Percentage"
    $BackupWorksheet.cells.item($RowCount+7,2) = "$successPercent%"

    $BackupWorksheet.cells.item($RowCount+8,1) = "Time period"
    $BackupWorksheet.cells.item($RowCount+8,2) = $startDate
    $BackupWorksheet.cells.item($RowCount+8,3) = $endDate

    $BackupWorksheet.cells.item($RowCount+9,1) = "Script Version"
    $BackupWorksheet.cells.item($RowCount+9,2) = $ScriptVersion
    
    Start-Sleep -s 5

    $BackupWorksheet.UsedRange.Columns.AutoFit() | Out-Null

$workbook.Save()
$workbook.Close()
$Excel.Quit()

Echo "`nCreated the consolidated report."

#Logout from the account

Logout-AzureRmAccount
Echo "Logged out of all Azure accounts"
"$FormattedDate : INFO : Logged out of all Azure accounts." | Out-File -FilePath $logfile -Append
 
# wait for it to finish

Start-Sleep -Seconds 5

#Rename the file

Rename-Item -Path "E:\Reports\Backup_job_report\Backup_Report.xlsx" -NewName "Backup_Report_$F-to-$T.xlsx" -Force
Write-Host "`nThe file has been renamed and is now ready to view.`n"
"$FormattedDate : INFO : The file E:\Reports\Backup_job_report\Backup_Report_$F-to-$T.xlsx has been created successfully and is ready to use." | Out-File -FilePath $logfile -Append
Echo "#---------------------------------------------------------------------------------#"

#--------------------------------------------------------END OF SCRIPT------------------------------------------------------#