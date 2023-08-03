# CheckSMBSigning
Checks for SMB signing disabled on all hosts in the network

Run as follows:

```
iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/CheckSMBSigning/main/CheckSMBSigning.ps1')
```

Check for SMB Signing on all hosts in the network

```
CheckSMBSigning
```

Check for SMB Signing on specified targets

```
CheckSMBSigning -Targets "Server-01,Workstation-02"
```
```
CheckSMBSigning -Targets "Server-01.domain.local,Workstation-02.domain.local"
```

![image](https://github.com/Leo4j/CheckSMBSigning/assets/61951374/b051bf4a-7caf-4c6f-9c2a-211653c35ee6)

Borrowed code from https://github.com/TheKevinWang/Get-SMBSigning
