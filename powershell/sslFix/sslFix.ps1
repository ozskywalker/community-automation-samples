# please paste these commands into your PowerShell session to solve SSL-related problems when using download commands

#C# class to create callback

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
$ignoreCerts = @"
public class SSLHandler
{
public static System.Net.Security.RemoteCertificateValidationCallback GetSSLHandler()
{
    return new System.Net.Security.RemoteCertificateValidationCallback((sender, certificate, chain, policyErrors) => { return true; });
}
}
"@

if(!("SSLHandler" -as [type])){
    Add-Type -TypeDefinition $ignoreCerts
}
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [SSLHandler]::GetSSLHandler()
