#Naming standard for root certs: Common Name = <Function>+RootCert+<Environment or DXC team><Createdate> 
#E.G.  General Workload Start/Stop Automation :: StartStopVMAutomateRootCertDEV20180716
#E.G.  P2S Remote Access                      :: P2SRootCertODT20180714 or P2SRootCertCloudOps20180714 or P2SRootCertDBA20180714 or P2SRootCertFWAdmin20180714
#E.G.  HPC Automation                         :: HPCRootCertDEV20180716
$certname = Read-host "Please enter the name of the root certificate, e.g. 'P2SAzureMyCert'"
#The Keylength should be 4096 as per Metlife Corporate Standard
#The HashAlgorithm should be sha256 which is optimized for Azure use.
#Technically, we to expire the certificates every 6 months, so we add a 6 month expiry
New-SelfSignedCertificate -Type Custom -KeySpec Signature `
-Subject "CN=$certname" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 4096  -NotAfter (Get-Date).AddMonths(6) `
-CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

# Certificate is exported to this location 'C:\Users\adminjump001\AppData\Roaming\Microsoft\SystemCertificates\My\Certificates' and stored as a binary file
# Open certmgr.exe //Personal/Cerificates to pick up certs and export.