# User Configurable Variables
$DomainNetbiosName="LAB"
$DomainControllerName="DC01"
$DomainName="lab.nosnik.dk"
$IPv4Prefix="172.21.21"
$DomainAdminUsername="hbacher"
$DomainAdminPassword=ConvertTo-SecureString "P@ssw0rd3" -AsPlainText -Force
$SafeModeAdministratorPassword = ConvertTo-SecureString "P@ssw0rd1" -AsPlainText -Force
$AdminPassword = ConvertTo-SecureString "P@ssw0rd3" -AsPlainText -Force
$AdminCredentials = New-Object System.Management.Automation.PSCredential ("Administrator", $AdminPassword)
$ADCredentials = New-Object System.Management.Automation.PSCredential ("$DomainNetbiosName\Administrator", $AdminPassword)

#host
New-VMSwitch –SwitchName "NATSwitch" –SwitchType Internal
New-NetIPAddress –IPAddress $IPv4Prefix'.1' -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
New-NetNat –Name VMNetwork –InternalIPInterfaceAddressPrefix $IPv4Prefix'.0/24'

#Addumes VM Name is "$DomainControllerName'.'$DomainName"
$Session = New-PSSession -VMName $DomainControllerName'.'$DomainName -Credential $AdminCredentials
Invoke-Command -Session $Session -scriptblock {
    Get-NetAdapter -name "Ethernet" | New-NetIPAddress $using:IPv4Prefix'.10' -PrefixLength 24 -DefaultGateway $using:IPv4Prefix'.1'
    Get-NetAdapter -name "Ethernet" | Set-DnsClientServerAddress -ServerAddress ("8.8.8.8", "8.8.4.4")
    Rename-Computer $using:DomainControllerName

    Restart-Computer -force
}

$Session = New-PSSession -VMName $DomainControllerName'.'$DomainName -Credential $AdminCredentials
Invoke-Command -Session $Session -scriptblock {
    Get-WindowsFeature AD-Domain-Services | Install-WindowsFeature

    Install-ADDSForest `
     -DomainName "$using:DomainName" `
     -DomainNetbiosName "$using:DomainNetbiosName" `
     -InstallDns:$true `
     -Force:$true `
     -SafeModeAdministratorPassword $using:SafeModeAdministratorPassword
}


$Session = New-PSSession -VMName $DomainControllerName'.'$DomainName -Credential $ADCredentials
Invoke-Command -Session $Session -scriptblock {
    Get-WindowsFeature DHCP | Install-WindowsFeature
    netsh dhcp add securitygroups
    Restart-service dhcpserver
    Add-DhcpServerInDC
    Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2

    Set-DhcpServerv4DnsSetting -ComputerName $using:DomainControllerName -DynamicUpdates "Always" -DeleteDnsRRonLeaseExpiry $True

    Add-DhcpServerV4Scope -Name "DHCP Scope" -StartRange $using:IPv4Prefix'.100' -EndRange $using:IPv4Prefix'.199' -SubnetMask 255.255.255.0
    Set-DhcpServerV4OptionValue -DnsDomain $using:DomainName -DnsServer $using:IPv4Prefix'.10' -Router $using:IPv4Prefix'.1' 
    Set-DhcpServerv4Scope -ScopeId $using:IPv4Prefix'.10' -LeaseDuration 1.00:00:00

    New-ADUser -Name "$using:DomainAdminUsername.da" -Displayname "$using:DomainAdminUsername Domain Admin" -AccountPassword $using:DomainAdminPassword
    Get-ADUser "$using:DomainAdminUsername.da" | Set-ADUser -ChangePasswordAtLogon:$false -Enabled:$true
    Add-ADGroupMember "Domain Admins" "$using:DomainAdminUsername.da"
    Restart-Computer -force
}
