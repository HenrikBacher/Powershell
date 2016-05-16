#host
New-VMSwitch –SwitchName “NATSwitch” –SwitchType Internal
New-NetIPAddress –IPAddress 172.21.21.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
New-NetNat –Name VMNetwork –InternalIPInterfaceAddressPrefix 172.21.21.0/24

Enter-PSSession -VMName DC01
Get-NetAdapter -name "Ethernet" | New-NetIPAddress 172.21.21.10 -PrefixLength 24 -DefaultGateway 172.21.21.1
Get-NetAdapter -name "Ethernet" | Set-DnsClientServerAddress  -ServerAddress ("8.8.8.8", "8.8.4.4")
Rename-Computer DC01

Restart-Computer -force

Enter-PSSession -VMname DC01
Get-WindowsFeature AD-Domain-Services | Install-WindowsFeature

Enter-PSSession -Name DC01
Install-ADDSForest `
 -DomainName "lab.nosnik.dk" `
 -DomainNetbiosName "Lab" `
 -InstallDns:$true `
 -Force:$true

Enter-PSSession -VMname DC01

Get-WindowsFeature DHCP | Install-WindowsFeature
netsh dhcp add securitygroups
Restart-service dhcpserver
Add-DhcpServerInDC
Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2

Add-DhcpServerV4Scope -Name "DHCP Scope" -StartRange 172.21.21.100 -EndRange 172.21.21.199 -SubnetMask 255.255.255.0
Set-DhcpServerV4OptionValue -DnsDomain Lab.nosnik.dk -DnsServer 172.21.21.10 -Router 172.21.21.1 
Set-DhcpServerv4Scope -ScopeId 172.21.21.10 -LeaseDuration 1.00:00:00

New-ADUser -Name "hbacher" -Displayname "Henrik Bierbum Bacher" -AccountPassword (ConvertTo-Securestring "P@ssw0rd" -AsPlainText -Force)
Add-ADGroupMember "Domain Admins" "hbacher"