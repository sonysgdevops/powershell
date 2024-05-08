# Get hostname
$hostname = hostname

# Get IP network information
$ipInfo = Get-NetIPAddress | Where-Object { $_.AddressFamily -eq "IPv4" } | Select-Object IPAddress, InterfaceAlias

# Get AD site information
$adSiteInfo = Get-ADDomainController -Discover
$adSite = $adSiteInfo.site

# Get current domain controller information
$currentDC = $adSiteInfo.hostname[0]

# Convert IP information to HTML table rows
$htmlIpInfo = $ipInfo | ForEach-Object {
    "<tr><td>$($_.IPAddress)</td><td>$($_.InterfaceAlias)</td></tr>"
}

$domainControllers = Get-ADDomainController -Filter * | Select-Object -ExpandProperty hostname
$sccmServers = @("SGKOMTASCCM01.KOM.KEPPELGROUP.COM", "SGKGPSCCMMP01.KEPPELGROUP.COM")

$adPorts = @{
    "DNS" = 53
    "Kerberos" = 88
    "RPC Endpoint Mapper" = 135
    "LDAP" = 389
    "SMB" = 445
    "Kerberos Change Password" = 464
    "LDAPS" = 636
    "Global Catalog" = 3268
    "Global Catalog LDAP SSL" = 3269
}

$sccmPorts = @{
    "SCCM" = 8530
    "SCCM Alternate" = 8531
    "HTTP" = 80
    "HTTPS" = 443

}

$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
<style>
table {
  border-collapse: collapse;
  width: 100%;
}

th, td {
  border: 1px solid #dddddd;
  text-align: left;
  padding: 8px;
}

th {
  background-color: #f2f2f2;
}

.success {
  color: green;
}

.failure {
  color: red;
}
</style>
</head>
<body>
<h1>Infra Ports Status Report</h1>

<h2>Host Information</h2>
<table>
<tr>
<th>Hostname</th>
<th>IPv4 Address</th>
<th>Interface Alias</th>
<th>AD Site</th>
<th>Current Domain Controller</th>
</tr>
<tr>
<td>$hostname</td>
<td colspan="3">
<table>
$htmlIpInfo
</table>
</td>
<td>$currentDC</td>
</tr>
</table>
"@

# Function to check port status and generate HTML row
function CheckPortStatus {
    param(
        [string]$target,
        [string]$portName,
        [int]$portNumber
    )
   
    $connection = Test-NetConnection -ComputerName $target -Port $portNumber
    if ($connection.TcpTestSucceeded) {
        $status = "<span class='success'>Open</span>"
    } else {
        $status = "<span class='failure'>Closed</span>"
    }

    "<tr><td>$portName</td><td>$portNumber</td><td>$status</td></tr>"
}

# Query Active Directory ports for domain controllers
foreach ($server in $domainControllers) {
    $htmlReport += @"
    <h2>Active Directory Ports Status Report for $server</h2>
    <table>
    <tr>
    <th>Port Name</th>
    <th>Port Number</th>
    <th>Status</th>
    </tr>
"@

    foreach ($portName in $adPorts.Keys) {
        $portNumber = $adPorts[$portName]
       
        # Check Active Directory ports
        $htmlReport += CheckPortStatus -target $server -portName $portName -portNumber $portNumber
    }

    $htmlReport += @"
    </table>
"@
}

# Query SCCM ports for SCCM servers
foreach ($server in $sccmServers) {
    $htmlReport += @"
    <h2>SCCM Ports Status Report for $server</h2>
    <table>
    <tr>
    <th>Port Name</th>
    <th>Port Number</th>
    <th>Status</th>
    </tr>
"@

    foreach ($portName in $sccmPorts.Keys) {
        $portNumber = $sccmPorts[$portName]
       
        # Check SCCM ports
        $htmlReport += CheckPortStatus -target $server -portName $portName -portNumber $portNumber
    }

    $htmlReport += @"
    </table>
"@
}

$htmlReport += @"
</body>
</html>
"@

$htmlReport | Out-File "InfraPortsStatusReport.html"
Write-Host "Report generated: InfraPortsStatusReport.html"