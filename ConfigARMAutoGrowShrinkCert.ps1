<#
.Synopsis
   Configure the certificate used by AzureAutoGrowShrink.ps1 to auto grow shrink the HPC Pack Azure IaaS compute nodes in Azure resource manager(ARM) mode
.DESCRIPTION
   This script configures the certificate used by AzureAutoGrowShrink.ps1 to auto grow shrink the HPC Pack Azure IaaS compute nodes in Azure resource manager(ARM) mode
   Author :  Microsoft HPC Pack team
.EXAMPLE
   .\ConfigARMAutoGrowShrinkCert.ps1 -DisplayName "MyHpcPackApp" -HomePage "https://MyHpcPackApp" -IdentifierUri "https://MyHpcPackApp" -CertificateThumbprint "ABDDA0C72E64D5BB123616B5D308A2ED7FBCC9EF"
   .\ConfigARMAutoGrowShrinkCert.ps1 -DisplayName "MyHpcPackApp" -HomePage "https://MyHpcPackApp" -IdentifierUri "https://MyHpcPackApp" -PfxFile "d:\mypfxfile.pfx" -Password "MyPassWord"
.INPUTS
   None
.OUTPUTS
   None
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param (
    # The display name of the Azure Active Directory application to be created 
    [Parameter(Mandatory=$true)]
    [string] $DisplayName,

    # The home page of the Azure Active Directory application to be created
    [Parameter(Mandatory=$true)]
    [string] $HomePage,

    # The identifier Uri of the Azure Active Directory application to be created
    [Parameter(Mandatory=$true)]
    [string] $IdentifierUri,

    # The thumbprint of the certificate to be used for the the Azure Active Directory application, the certificate must already exist under Cert:\CurrentUser\My or Cert:\LocalMachine\My
    [Parameter(Mandatory=$true, ParameterSetName="Thumbprint")]
    [string] $CertificateThumbprint,

    # The file path of the PFX file to be used for the the Azure Active Directory application, it will be imported to Cert:\CurrentUser\My
    [Parameter(Mandatory=$true, ParameterSetName="PfxFile")]
    [string] $PfxFile,

    # The protection password path of the PFX file
    [Parameter(Mandatory=$false, ParameterSetName="PfxFile")]
    [string] $Password,

    [Parameter(Mandatory=$false)]
    [Switch] $Force
)

$ErrorActionPreference = "Stop"
if((-not $Force.IsPresent) -and (-not $PsCmdlet.ShouldContinue("Continue?","This script shall only be run on the HPC head node deployed in Azure resource manager model")))
{
    exit 1
}


$azureModule = Get-Module -ListAvailable -Name Azure
if ($null -eq $azureModule)
{
    throw "Azure Powershell not found. Install the latest version from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}

if ($azureModule.Version -lt "1.5.0")
{
    $ver = $azureModule.Version
    throw "Azure Powershell version $ver is too old. Install the latest Azure PowerShell version from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}


$clusInfo = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\HPC\IaaSInfo | Select -Property SubscriptionId,ThumbPrint,TenantId,ApplicationId
if([string]::IsNullOrEmpty($clusInfo.SubscriptionId))
{
    throw "Please run ConfigClusterInfo.ps1 first"
}
if((-not [string]::IsNullOrEmpty($clusInfo.ThumbPrint)) -and (-not [string]::IsNullOrEmpty($clusInfo.TenantId)) -and (-not [string]::IsNullOrEmpty($clusInfo.ApplicationId)))
{
    Write-Host "You had configured the certificate before"
    exit 0
}

$SubscriptionId = $clusInfo.SubscriptionId
try
{
    $sub = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
}
catch
{
    throw "The AzureRm subscription $SubscriptionId not found, run Login-AzureRmAccount to login first"
}

Select-AzureRmSubscription -SubscriptionId $SubscriptionId
if($PsCmdlet.ParameterSetName -eq "Thumbprint")
{
    $cert = Get-Item Cert:\CurrentUser\My\$CertificateThumbprint -ErrorAction SilentlyContinue
    if($null -eq $cert)
    {
        $cert = Get-Item Cert:\LocalMachine\My\$CertificateThumbprint -ErrorAction SilentlyContinue
    }

    if($null -eq $cert)
    {
        throw "The certificate with thumbprint $CertificateThumbprint not found, you shall import the certificate under Cert:\CurrentUser\My or Cert:\LocalMachine\My"
    }
}
else
{
    $retry = 0
    while($true)
    {
        try
        {
            $cert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxFile, $Password)
            break
        }
        catch
        {
            if($_.Exception.HResult -eq 0x80070056)
            {
                if([String]::IsNullOrEmpty($Password))
                {
                    $prompt = "The certificate file $PfxFile is password protected. Please input the password"
                }
                else
                {
                    $prompt = "The password for the certificate file $PfxFile is incorrect. Please input the correct password"
                }
                
                if($retry -lt 3)
                {
                    $secPsw = Read-Host -Prompt $prompt -AsSecureString
                    $Password = ConvertSecureStrToPlain -SecurePassword $secPsw 
                    $retry++
                }
                else
                {
                    throw "The password for the certificate file $PfxFile is incorrect."
                }
            }
            elseif($_.Exception.HResult -eq 0x80092009)
            {
                throw "The file $PfxFile is not a valid PFX file."
            }
            else
            {
                throw "Failed to read the certificate file $PfxFile : $_"
            }
        }
    }

    $CertificateThumbprint = $cert.Thumbprint
    $foundCert = Get-Item Cert:\CurrentUser\My\$CertificateThumbprint -ErrorAction SilentlyContinue
    if($null -eq $foundCert)
    {
        $foundCert = Get-Item Cert:\LocalMachine\My\$CertificateThumbprint -ErrorAction SilentlyContinue
    }
    if($null -eq $foundCert)
    {
        $secPsw = ConvertTo-SecureString -String $Password -AsPlainText -Force
        Write-Host "Import Certificate $PfxFile to Cert:\CurrentUser\My\$CertificateThumbprint"
        Import-PfxCertificate -FilePath $PfxFile -CertStoreLocation Cert:\CurrentUser\My -Password $secPsw
    }
    else
    {
        Write-Host "The Certificate with same thubprint $CertificateThumbprint was already in certificate store"
    }
}

$azureAdApplication = Get-AzureRmADApplication -IdentifierUri $IdentifierUri -ErrorAction SilentlyContinue
if($null -eq $azureAdApplication)
{
    Write-Host "Create AD Application $DisplayName"


    $keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
    if ($azureModule.Version -lt "2.0.0")
    {
        $azureAdApplication = New-AzureRmADApplication -DisplayName $DisplayName -HomePage $HomePage -IdentifierUris $IdentifierUri -KeyValue $keyValue -KeyType AsymmetricX509Cert -EndDate $cert.NotAfter -StartDate $cert.NotBefore
    }
    else
    {
        $azureAdApplication = New-AzureRmADApplication -DisplayName $DisplayName -HomePage $HomePage -IdentifierUris $IdentifierUri -CertValue $keyValue -EndDate $cert.NotAfter -StartDate $cert.NotBefore
    }
}
else
{
    if($azureAdApplication.DisplayName -ne $DisplayName)
    {
        throw "Another AD Application with same IdentifierUri $IdentifierUri already exists"
    }
    else
    {
        if(-not $PsCmdlet.ShouldContinue("Do you want to use it?","AD Application $DisplayName with IdentifierUri $IdentifierUri already exists"))
        {
            Write-Host "Specify a different IdentifierUri and run again"
            exit 1
        }
    }
}

$roleAssignment = @(Get-AzureRmRoleAssignment -ServicePrincipalName $azureAdApplication.ApplicationId -ErrorAction SilentlyContinue | ?{$_.RoleDefinitionName -eq "Contributor" -or $_.RoleDefinitionName -eq "Owner"})
if($roleAssignment.Count -gt 0)
{
    Write-Host "The AD Application $DisplayName was already assigned 'Owner' or 'Contributor' role"
}
else
{
    $svcPrincipal = Get-AzureRmADServicePrincipal -ServicePrincipalName $azureAdApplication.ApplicationId -ErrorAction SilentlyContinue
    if($null -ne $svcPrincipal)
    {
        Write-Host "The service Principal for AD Application $DisplayName already exists"
    }
    else
    {
        Write-Host "Create a service principal for the AD Application $DisplayName"
        New-AzureRmADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
    }

    Write-Host "Assign 'Contributor' role for the service Principal"
    $retry = 0
    while($true)
    {
        try
        {
            New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $azureAdApplication.ApplicationId
            break
        }
        catch
        {
            if($retry -lt 10)
            {
                $retry++
                Write-Host "Failed to assign 'Contributor' role for the service Principal, try again..."
                Start-Sleep -Seconds 10
            }
            else
            {
                throw
            }
        }
    }
}

Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\HPC\IaaSInfo -Name ThumbPrint -Value $cert.ThumbPrint | Out-Null
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\HPC\IaaSInfo -Name ApplicationId -Value $azureAdApplication.ApplicationId | Out-Null
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\HPC\IaaSInfo -Name TenantId -Value $sub.TenantId | Out-Null
Write-Host "The certificate has been configured"
# SIG # Begin signature block
# MIIdrwYJKoZIhvcNAQcCoIIdoDCCHZwCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUV19dmujHAdVHd5trLpS3Clgc
# eTCgghhlMIIEwzCCA6ugAwIBAgITMwAAAMzLuBPrXXItRQAAAAAAzDANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODU2
# WhcNMTgwOTA3MTc1ODU2WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OjE0OEMtQzRCOS0yMDY2MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwe5bp0PH7Nar
# LeUDfq1E+Jd4WNpGm2kgEVzLGmOAjML+w5RXEzQOQuqTl8SfMUcrg1+to2Ihbu3h
# fPFFRQJq0cPH/i14X1w0cWP6jRqyAqv/T3lSM4O3dDSNZK+QUsUq0yXeF+FmvW0i
# gBHUpOpXEyxHha0QNzbJm9iyCXSu/WaUstgcq8wHA2gvuLdvSA6pDt+AgAUf0o/f
# 2Nwl25HtlDNRiI1PgfSRdw+W0gnSalk3xycrDVFDlVLavPccwXNc0YsNrKFr9T17
# baz3xYPTb/+90NtpUoBgSdpV2Rr7ev7l806lz4mlxEEqFv/xwk7Yws4BowtU9pE1
# zaPyNiV2GQIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFPWhmmbVkedPZa+s2RQAnZdC
# m8+qMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAJaBLYob96ccjvtcRqUl/51+iQ6TX4WoJCYb+jf3sMtgQLd4
# kLPpCB/2f8uuZePf9wSdjCu2SPFt1Px6vJysXk2B7rReYR3A8G0SsoUv/nCdFjp3
# dtr3lm2xkMU2wv5Ox4BO4Jf+0vT9+s3PbLnPZK/GjUJ1idWSG0sKpXgq7mpSw9SV
# 7jIjjdM0bupBd2xLCKfocxjYir5UYJWiC8C0kb//6F8/JL/n1Gr1Ty7mZdiFjW4F
# BEIxTU3r0EnAqtOv/O0cApLuC9AV1pFixlGgQRqlA/xRQLLaui3j5qGKeJeijYSz
# RJgTY5L21IbbuV6arIrZhpJkL059QogKBFgjmiIwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhEwggP5
# oAMCAQICEzMAAACOh5GkVxpfyj4AAAAAAI4wDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNjExMTcyMjA5MjFaFw0xODAy
# MTcyMjA5MjFaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDQh9RCK36d2cZ61KLD4xWS
# 0lOdlRfJUjb6VL+rEK/pyefMJlPDwnO/bdYA5QDc6WpnNDD2Fhe0AaWVfIu5pCzm
# izt59iMMeY/zUt9AARzCxgOd61nPc+nYcTmb8M4lWS3SyVsK737WMg5ddBIE7J4E
# U6ZrAmf4TVmLd+ArIeDvwKRFEs8DewPGOcPUItxVXHdC/5yy5VVnaLotdmp/ZlNH
# 1UcKzDjejXuXGX2C0Cb4pY7lofBeZBDk+esnxvLgCNAN8mfA2PIv+4naFfmuDz4A
# lwfRCz5w1HercnhBmAe4F8yisV/svfNQZ6PXlPDSi1WPU6aVk+ayZs/JN2jkY8fP
# AgMBAAGjggGAMIIBfDAfBgNVHSUEGDAWBgorBgEEAYI3TAgBBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUq8jW7bIV0qqO8cztbDj3RUrQirswUgYDVR0RBEswSaRHMEUxDTAL
# BgNVBAsTBE1PUFIxNDAyBgNVBAUTKzIzMDAxMitiMDUwYzZlNy03NjQxLTQ0MWYt
# YmM0YS00MzQ4MWU0MTVkMDgwHwYDVR0jBBgwFoAUSG5k5VAF04KqFzc3IrVtqMp1
# ApUwVAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jcmwvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNybDBhBggrBgEF
# BQcBAQRVMFMwUQYIKwYBBQUHMAKGRWh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljQ29kU2lnUENBMjAxMV8yMDExLTA3LTA4LmNydDAMBgNV
# HRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4ICAQBEiQKsaVPzxLa71IxgU+fKbKhJ
# aWa+pZpBmTrYndJXAlFq+r+bltumJn0JVujc7SV1eqVHUqgeSxZT8+4PmsMElSnB
# goSkVjH8oIqRlbW/Ws6pAR9kRqHmyvHXdHu/kghRXnwzAl5RO5vl2C5fAkwJnBpD
# 2nHt5Nnnotp0LBet5Qy1GPVUCdS+HHPNIHuk+sjb2Ns6rvqQxaO9lWWuRi1XKVjW
# kvBs2mPxjzOifjh2Xt3zNe2smjtigdBOGXxIfLALjzjMLbzVOWWplcED4pLJuavS
# Vwqq3FILLlYno+KYl1eOvKlZbiSSjoLiCXOC2TWDzJ9/0QSOiLjimoNYsNSa5jH6
# lEeOfabiTnnz2NNqMxZQcPFCu5gJ6f/MlVVbCL+SUqgIxPHo8f9A1/maNp39upCF
# 0lU+UK1GH+8lDLieOkgEY+94mKJdAw0C2Nwgq+ZWtd7vFmbD11WCHk+CeMmeVBoQ
# YLcXq0ATka6wGcGaM53uMnLNZcxPRpgtD1FgHnz7/tvoB3kH96EzOP4JmtuPe7Y6
# vYWGuMy8fQEwt3sdqV0bvcxNF/duRzPVQN9qyi5RuLW5z8ME0zvl4+kQjOunut6k
# LjNqKS8USuoewSI4NQWF78IEAA1rwdiWFEgVr35SsLhgxFK1SoK3hSoASSomgyda
# Qd691WZJvAuceHAJvDCCB3owggVioAMCAQICCmEOkNIAAAAAAAMwDQYJKoZIhvcN
# AQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAw
# BgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEx
# MB4XDTExMDcwODIwNTkwOVoXDTI2MDcwODIxMDkwOVowfjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9zb2Z0IENvZGUg
# U2lnbmluZyBQQ0EgMjAxMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AKvw+nIQHC6t2G6qghBNNLrytlghn0IbKmvpWlCquAY4GgRJun/DDB7dN2vGEtgL
# 8DjCmQawyDnVARQxQtOJDXlkh36UYCRsr55JnOloXtLfm1OyCizDr9mpK656Ca/X
# llnKYBoF6WZ26DJSJhIv56sIUM+zRLdd2MQuA3WraPPLbfM6XKEW9Ea64DhkrG5k
# NXimoGMPLdNAk/jj3gcN1Vx5pUkp5w2+oBN3vpQ97/vjK1oQH01WKKJ6cuASOrdJ
# Xtjt7UORg9l7snuGG9k+sYxd6IlPhBryoS9Z5JA7La4zWMW3Pv4y07MDPbGyr5I4
# ftKdgCz1TlaRITUlwzluZH9TupwPrRkjhMv0ugOGjfdf8NBSv4yUh7zAIXQlXxgo
# tswnKDglmDlKNs98sZKuHCOnqWbsYR9q4ShJnV+I4iVd0yFLPlLEtVc/JAPw0Xpb
# L9Uj43BdD1FGd7P4AOG8rAKCX9vAFbO9G9RVS+c5oQ/pI0m8GLhEfEXkwcNyeuBy
# 5yTfv0aZxe/CHFfbg43sTUkwp6uO3+xbn6/83bBm4sGXgXvt1u1L50kppxMopqd9
# Z4DmimJ4X7IvhNdXnFy/dygo8e1twyiPLI9AN0/B4YVEicQJTMXUpUMvdJX3bvh4
# IFgsE11glZo+TzOE2rCIF96eTvSWsLxGoGyY0uDWiIwLAgMBAAGjggHtMIIB6TAQ
# BgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQUSG5k5VAF04KqFzc3IrVtqMp1ApUw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAUci06AjGQQ7kUBU7h6qfHMdEjiTQwWgYDVR0f
# BFMwUTBPoE2gS4ZJaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNybDBeBggrBgEFBQcB
# AQRSMFAwTgYIKwYBBQUHMAKGQmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kv
# Y2VydHMvTWljUm9vQ2VyQXV0MjAxMV8yMDExXzAzXzIyLmNydDCBnwYDVR0gBIGX
# MIGUMIGRBgkrBgEEAYI3LgMwgYMwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvZG9jcy9wcmltYXJ5Y3BzLmh0bTBABggrBgEFBQcC
# AjA0HjIgHQBMAGUAZwBhAGwAXwBwAG8AbABpAGMAeQBfAHMAdABhAHQAZQBtAGUA
# bgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAZ/KGpZjgVHkaLtPYdGcimwuWEeFj
# kplCln3SeQyQwWVfLiw++MNy0W2D/r4/6ArKO79HqaPzadtjvyI1pZddZYSQfYtG
# UFXYDJJ80hpLHPM8QotS0LD9a+M+By4pm+Y9G6XUtR13lDni6WTJRD14eiPzE32m
# kHSDjfTLJgJGKsKKELukqQUMm+1o+mgulaAqPyprWEljHwlpblqYluSD9MCP80Yr
# 3vw70L01724lruWvJ+3Q3fMOr5kol5hNDj0L8giJ1h/DMhji8MUtzluetEk5CsYK
# wsatruWy2dsViFFFWDgycScaf7H0J/jeLDogaZiyWYlobm+nt3TDQAUGpgEqKD6C
# PxNNZgvAs0314Y9/HG8VfUWnduVAKmWjw11SYobDHWM2l4bf2vP48hahmifhzaWX
# 0O5dY0HjWwechz4GdwbRBrF1HxS+YWG18NzGGwS+30HHDiju3mUv7Jf2oVyW2ADW
# oUa9WfOXpQlLSBCZgB/QACnFsZulP0V3HjXG0qKin3p6IvpIlR+r+0cjgPWe+L9r
# t0uX4ut1eBrs6jeZeRhL/9azI2h15q/6/IvrC4DqaTuv/DDtBEyO3991bWORPdGd
# Vk5Pv4BXIqF4ETIheu9BCrE/+6jMpF3BoYibV3FWTkhFwELJm3ZbCoBIa/15n8G9
# bW1qyVJzEw16UM0xggS0MIIEsAIBATCBlTB+MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5n
# IFBDQSAyMDExAhMzAAAAjoeRpFcaX8o+AAAAAACOMAkGBSsOAwIaBQCggcgwGQYJ
# KoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQB
# gjcCARUwIwYJKoZIhvcNAQkEMRYEFFo5BXVYEJQO9G/Vn8dwNWtYXpJlMGgGCisG
# AQQBgjcCAQwxWjBYoDaANABNAGkAYwByAG8AcwBvAGYAdAAgAEgAUABDACAAUABh
# AGMAawAgADIAMAAxADIAIABSADKhHoAcaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L0hQQzANBgkqhkiG9w0BAQEFAASCAQBIg34XHDKon37CU6KvSIE36FP7vWCAln3c
# 9TLvOOxi3CLefnFtHsyWDGnIlCclfGi2W5znYQ1RhaHQ27rBgc/sZs8vDYKr7JwO
# Wo6IFXw6+kp4bZLlG+7ah6oD6wG8Jrl4uHSLVJs/Em+pz1MwtgeY/cwOHG7WVrRY
# Ggzk+0TRo+jgJ1kJ1tIpdsJoYMXIB6U+0BKS/lx8aCRYsqCCcfLhcSOUJVJa/lDY
# jh72W2iJaDkLpn8zIFQlC16JOOQyFrVHB0N574CFH5hePAtnksZY7wOMME97A4fT
# Mgw9Xph8cVwXSVphGaQxaK/yc6LZ5sZ8exjxsXpUBXbZ2pe94YUOoYICKDCCAiQG
# CSqGSIb3DQEJBjGCAhUwggIRAgEBMIGOMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xITAfBgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QQITMwAAAMzLuBPrXXItRQAAAAAAzDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkD
# MQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTcwNjAxMDc1ODAzWjAjBgkq
# hkiG9w0BCQQxFgQUSI+lVc3UvG7C3rE5LNnJgfMaWMgwDQYJKoZIhvcNAQEFBQAE
# ggEAEHn7ceSzQGkLMPqRwmA5uAyBTLTyNlmPlzqqTXPqrNbptLTivoNmeeyRnpA9
# rNjXmEUM8e+BUufQiKJKX/Lv0hLcFFw06YSsauGHdgQr0QC2rMOhOB4DZT3sai6J
# DcpJfyNnxCx/JYxXBFRJ1nBilyJKK0a8eCwyS69GViDzjK5K/JWDJgP5KpQjZAB/
# 31vXFvRDYHA3cqpEhuNU/5ZpxWAI++e/iIojDPAvtBA+caKIyTwxWWTZO0uLZR7f
# IKwDeRp+Z0JNEDtP4Pbmg9/XmhL/i4hJ4QtqbYWUacWOtkDwW4WWsuLFbrbcav5P
# B949H8p9EiSh4McUA15bW9k18Q==
# SIG # End signature block
