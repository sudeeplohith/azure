get-module powershellget|fl *path*
#Path:C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1\PSModule.psm1

write-host " Choose the Path from above command result and put it as below" -ForegroundColor green

save-module -Name importexcel -Path 'C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\1.0.0.1'
Install-Module -Name ImportExcel

