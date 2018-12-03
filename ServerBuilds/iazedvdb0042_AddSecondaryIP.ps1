$PIP = "10.12.196.25"   #Add Primary IP of Server e.g. 10.12.172.0/22 or 10.12.160.0/24
$SIP = "10.12.197.250" #ADD Secondary IP of Server
$MaskBits = 23 # ADD Netmask of SUBNET on which the server resides : Usually 255.255.252.0 (22) or 255.255.255.0(24) or 255.255.254.0 (23)
$Gateway = "10.12.196.1" #Add Gateway IP of Subnet on which server sits. E.G. 10.12.172.1 or 10.12.160.1
#####DO NOT CHANGE THE REST OF THIS SCRIPT#####
$IPType = "IPv4"
# Retrieve the network adapter that you want to configure
$adapter = Get-NetAdapter | ? {$_.Status -eq "up"}
# Remove any existing IP, gateway from our ipv4 adapter
If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
 $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
}
If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
 $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
}
 # Configure the Primary IP address and default gateway
$adapter | New-NetIPAddress `
 -AddressFamily $IPType `
 -IPAddress $PIP `
 -PrefixLength $MaskBits `
 -DefaultGateway $Gateway
Start-Sleep -s 15
ipconfig /registerdns
nslookup $env:computername
$adapter | Set-DnsClientServerAddress -ServerAddresses {10.9.167.218,10.9.167.161,10.10.61.71}  # Add additional DNS Servers to existing resolver list
$adapter | New-NetIPAddress -IPAddress $SIP -AddressFamily IPv4 -PrefixLength $MaskBits -SkipAsSource $True
Get-NetIPAddress -AddressFamily IPv4