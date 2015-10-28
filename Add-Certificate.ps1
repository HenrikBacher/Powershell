$Header = "Server","Path","Store","User"
$CertificatesConfigurations = Import-Csv -LiteralPath C:\temp\test.csv -Delimiter "," -Header $Header

foreach ($CertificatesConfiguration in $CertificatesConfigurations) {
    
    $server = $CertificatesConfiguration.Server
    $destination = "\\$server\c$\Temp"

    New-Item $destination -ItemType Directory
    Copy-Item $CertificatesConfiguration.Path -Destination $destination
    
    If ($CertificatesConfiguration.Path -like "*cer") {

        Invoke-Command -ComputerName $CertificatesConfiguration.Server -ScriptBlock  {param($Path,$Store)
        Import-Certificate -FilePath $Path -CertStoreLocation $Store
        } -ArgumentList $CertificatesConfiguration.Path, $CertificatesConfiguration.Store
    }

    else {
    Invoke-Command -ComputerName $CertificatesConfiguration.Server -ScriptBlock  {param($Path,$Store,$User)
            
            $Password = Read-Host -Prompt "Angiv Password for $Path"
            $PFXCertificate = Import-PfxCertificate -FilePath $Path -CertStoreLocation $Store -Password (ConvertTo-SecureString -String $Password -AsPlainText -Force)
            
            $PrivateKey=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $PFXCertificate.Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName
            $KeyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"

            $FullPath=$KeyPath+$PrivateKey
            $acl=Get-Acl -Path $FullPath
            $Permission=$User,"Read","Allow"
            $AccessRule=new-object System.Security.AccessControl.FileSystemAccessRule $Permission
            
            $acl.AddAccessRule($AccessRule)
            Set-Acl $fullPath $acl
        } -ArgumentList $CertificatesConfiguration.Path, $CertificatesConfiguration.Store, $CertificatesConfiguration.User
    }
    
    Remove-Item -Path $destination -Recurse
}


