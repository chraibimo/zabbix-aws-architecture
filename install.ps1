#
# install.ps1
#
<#
.SYNOPSIS

    Extract the bundle into Ec2Launch file path.

.DESCRIPTION

.EXAMPLE

    ./install

#>

# Required for powershell to determine what parameter set to use when running with zero args (us a non existent set name)
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
  # Allows EC2Launch to send telemetry to AWS.
  # Disable telemetry by installing with -EnableTelemetry:$false.
  [Parameter(Mandatory = $false,ParameterSetName = "Schedule")]
  [switch]$EnableTelemetry = $true
)

try {
  $OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
}
catch {
  Write-Host "Failed to get operating system information due to the following error: $_"
  exit 1
}
if ($null -eq $OperatingSystem) {
  Write-Host "Get-CimInstance returned null"
  exit 1
}
$WindowsCaption = ($OperatingSystem.Caption).Trim()
if ([string]::IsNullOrWhiteSpace($WindowsCaption)) {
  $WindowsCaption = "this Windows version"
}
$WindowsBuildNumber = [Environment]::OSVersion.Version.Build
# Prevent unsupported installation on Windows operating system build versions numbered 26040 and above.
$IsWindowsServer2025OrLater = $WindowsBuildNumber -ge 26040
if ($IsWindowsServer2025OrLater) {
  Write-Host "EC2Launch v1 is not supported on $WindowsCaption. You must upgrade your launch agent to EC2Launch v2."
  exit 1
}

$sourcePath = Join-Path $PSScriptRoot -ChildPath "EC2-Windows-Launch.zip"
$destPath = Join-Path $env:programData -ChildPath "Amazon\EC2-Windows\Launch"
Set-Variable TelemetryEnvVar -Option Constant -Scope Local -Value "EC2LAUNCH_TELEMETRY"

# Check if source package exists in current location
if (-not (Test-Path $sourcePath))
{
  Write-Host ("{0} is not found.. exit!" -f $sourcePath)
  exit 1
}

$telemetryEnvVarValue = "0"
if ($EnableTelemetry)
{
  $telemetryEnvVarValue = "1"
}
[Environment]::SetEnvironmentVariable($TelemetryEnvVar,$telemetryEnvVarValue,'Machine')

# Check if Ec2Launch is already installed
if (Test-Path $destPath)
{
  Remove-Item -Path $destPath -Recurse -Force -Confirm:$false
}

$unpacked = $false;
if ($PSVersionTable.PSVersion.Major -ge 5)
{
  try
  {
    # Nano doesn't support Expand-Archive yet, but plans to add it in future release.
    # Attempt to execute Expand-Archive to unzip the source package first.
    Expand-Archive $sourcePath -DestinationPath $destPath -Force

    # Set this TRUE to indicate the unpack is done
    $unpacked = $true;

    Write-Host ("Successfully extract files to {0}" -f $destPath)
  }
  catch
  {
    Write-Host "Failed to extract files by Expand-Archive cmdlet.."
  }
}

# If unpack failed with Expand-Archive cmdlet, try it with [System.IO.Compression.ZipFile]::ExtractToDirectory
if (-not $unpacked)
{
  Write-Host "Attempting it again with [System.IO.Compression.ZipFile]::ExtractToDirectory"

  try
  {
    # Load [System.IO.Compression.FileSystem]
    Add-Type -AssemblyName System.IO.Compression.FileSystem
  }
  catch
  {
    # If failed, try to load [System.IO.Compression.ZipFile]
    Add-Type -AssemblyName System.IO.Compression.ZipFile
  }

  try
  {
    # Try to unpack the package by [System.IO.Compression.ZipFile]::ExtractToDirectory and move them to destination
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$sourcePath","$destPath")
    Write-Host ("Successfully extract files to {0}" -f $destPath)
  }
  catch
  {
    Write-Host "Failed to extract the files.. exit!"
    exit 1
  }
}

try
{
  $administratorAndSystemOnlyAcl = New-Object System.Security.AccessControl.DirectorySecurity
  $userExecuteAcl = New-Object System.Security.AccessControl.DirectorySecurity
  $userWrite = New-Object System.Security.AccessControl.DirectorySecurity

  # Disable inheritance of the folder from the parent folder and clear inherited access rules.
  $administratorAndSystemOnlyAcl.SetAccessRuleProtection($true <# isProtected #>, $false <# preserveInheritance #>)
  $userExecuteAcl.SetAccessRuleProtection($true <# isProtected #>, $false <# preserveInheritance #>)
  $userWrite.SetAccessRuleProtection($true <# isProtected #>, $false <# preserveInheritance #>)

  # Create access control rule allowing full control rights for Administrators.
  $BuiltinAdminSID = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
  $AdminFullControlRule = New-Object System.Security.AccessControl.FileSystemAccessRule (
    # PARAMETER IdentityReference
    # This rule applies to the Administrators user group.
    $BuiltinAdminSID,
    # PARAMETER FileSystemRights
    # This rule specifies full control access rights.
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    # PARAMETER InheritanceFlags
    # This rule is inherited by subfolders (ContainerInherit) and files (ObjectInherit).
    ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
    # PARAMETER PropagationFlags
    # No propagation flags are set. This rule applies to the target folder (is not inherited only).
    [System.Security.AccessControl.PropagationFlags]::None,
    # PARAMETER AccessControlType
    # This rule allows the above full control rights.
    [System.Security.AccessControl.AccessControlType]::Allow
  )
  $administratorAndSystemOnlyAcl.AddAccessRule($AdminFullControlRule)
  $userExecuteAcl.AddAccessRule($AdminFullControlRule)
  $userWrite.AddAccessRule($AdminFullControlRule)

  # Create access control rule allowing full control rights for the SYSTEM.
  $LocalSystemSID = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
  $SystemFullControlRule = New-Object System.Security.AccessControl.FileSystemAccessRule (
    # PARAMETER IdentityReference
    # This rule applies to SYSTEM access.
    $LocalSystemSID,
    # PARAMETER FileSystemRights
    # This rule specifies full control access rights.
    [System.Security.AccessControl.FileSystemRights]::FullControl,
    # PARAMETER InheritanceFlags
    # This rule is inherited by subfolders (ContainerInherit) and files (ObjectInherit).
    ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
    # PARAMETER PropagationFlags
    # No propagation flags are set. This rule applies to the target folder (is not inherit only).
    [System.Security.AccessControl.PropagationFlags]::None,
    # PARAMETER AccessControlType
    # This rule allows the above full control rights.
    [System.Security.AccessControl.AccessControlType]::Allow
  )
  $administratorAndSystemOnlyAcl.AddAccessRule($SystemFullControlRule)
  $userExecuteAcl.AddAccessRule($SystemFullControlRule)
  $userWrite.AddAccessRule($SystemFullControlRule)

  # Allow full control access to the destination folder for SYSTEM/Administrators.
  $administratorAndSystemOnlyAcl | Set-Acl -Path $destPath

  # Create access control rule allowing read/execute rights for standard user accounts.
  $BuiltinUsersSID = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545'
  $AllowUserReadExecRule = New-Object System.Security.AccessControl.FileSystemAccessRule (
    # PARAMETER IdentityReference
    # This rule applies to the BUILTIN\Users group.
    $BuiltinUsersSID,
    # PARAMETER FileSystemRights
    # This rule specifies read and execute access rights only.
    [System.Security.AccessControl.FileSystemRights]::ReadAndExecute,
    # PARAMETER InheritanceFlags
    # This rule is not inherited.
    [System.Security.AccessControl.InheritanceFlags]::None,
    # PARAMETER PropagationFlags
    # No propagation flags are set. This rule applies to the target folder (is not inherit only).
    [System.Security.AccessControl.PropagationFlags]::None,
    # PARAMETER AccessControlType
    # This rule allows the above read and execute rights.
    [System.Security.AccessControl.AccessControlType]::Allow
  )
  $userExecuteAcl.AddAccessRule($AllowUserReadExecRule)
  $userWrite.AddAccessRule($AllowUserReadExecRule)

  # Allow read/execute permission for standard user accounts to access resources required for Set-Wallpaper.
  $userResources = @(
    "Library/InstanceTypes.json"
    "Library/InstanceTypes.ps1"
    "Module/Ec2Launch-Wallpaper.psd1"
    "Module/Ec2Launch-Wallpaper.psm1"
    "Module/Scripts/Complete-Log.ps1"
    "Module/Scripts/Import-WallpaperUtil.ps1"
    "Module/Scripts/Initialize-Log.ps1"
    "Module/Scripts/Get-Metadata.ps1"
    "Module/Scripts/Set-Wallpaper.ps1"
    "Module/Scripts/Test-NanoServer.ps1"
    "Module/Scripts/Write-Log.ps1"
  )
  foreach ($resource in $userResources)
  {
    $resourcePath = Join-Path -Path $script:destPath -ChildPath $resource
    $userExecuteAcl | Set-Acl -Path $resourcePath
  }

  # Create wallpaper log and set permissions so user can write
  $logPath = Join-Path -Path $script:destPath -ChildPath "Log"
  $wallpaperLogPath = Join-Path -Path $logPath -ChildPath "WallpaperSetup.log"
  if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory
  }
  if (-not (Test-Path -Path $wallpaperLogPath)) {
    New-Item -Path $wallpaperLogPath -ItemType File
  }

  $AllowUserWriteRule = New-Object System.Security.AccessControl.FileSystemAccessRule (
    # PARAMETER IdentityReference
    # This rule applies to the BUILTIN\Users group.
    $BuiltinUsersSID,
    # PARAMETER FileSystemRights
    # This rule specifies write access only.
    [System.Security.AccessControl.FileSystemRights]::Write,
    # PARAMETER InheritanceFlags
    # This rule is not inherited.
    [System.Security.AccessControl.InheritanceFlags]::None,
    # PARAMETER PropagationFlags
    # No propagation flags are set. This rule applies to the target folder (is not inherit only).
    [System.Security.AccessControl.PropagationFlags]::None,
    # PARAMETER AccessControlType
    # This rule allows the above write rights.
    [System.Security.AccessControl.AccessControlType]::Allow
  )
  $userWrite.AddAccessRule($AllowUserWriteRule)
  $userWrite | Set-Acl -Path $wallpaperLogPath
}
catch
{
  Write-Host "Failed to update user permissions for EC2 Launch"
  exit 1
}

# Add a shortcut to the Settings UI
$settingsPath = Join-Path $destPath -ChildPath "Settings"
if (-not (Test-Path $settingsPath))
{
  Write-Host "Failed to find Settings folder after installation"
  exit 1
}

$shortcutTargetPath = Join-Path $settingsPath -ChildPath "Ec2LaunchSettings.exe"
if (-not (Test-Path $shortcutTargetPath))
{
  Write-Host "Failed to find EC2Launch Settings UI after installation"
  exit 1
}

$shortcutDirPath = Join-Path $env:programData -ChildPath "Microsoft\Windows\Start Menu\Programs"
if (-not (Test-Path $shortcutDirPath))
{
  $shortcutDirPath = Join-Path $env:userProfile -ChildPath "Start Menu\Programs"
  if (-not (Test-Path $shortcutDirPath))
  {
    Write-Host "Failed to select a Windows shortcut directory"
    exit 1
  }
}

try
{
  $shortcutPath = Join-Path $shortcutDirPath -ChildPath "Ec2LaunchSettings.lnk"
  $wshShell = New-Object -ComObject WScript.Shell
  $shortcut = $WshShell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $shortcutTargetPath
  $shortcut.Save()
}
catch
{
  Write-Host "Failed to create shortcut to the Settings UI"
  exit 1
}

# SIG # Begin signature block
# MIIurgYJKoZIhvcNAQcCoIIunzCCLpsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCxo9/BTcHv2Fqn
# ouiXyfjJdh0NvhhuHa28iE1TvhEjQ6CCE+MwggXAMIIEqKADAgECAhAP0bvKeWvX
# +N1MguEKmpYxMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xKzApBgNV
# BAMTIkRpZ2lDZXJ0IEhpZ2ggQXNzdXJhbmNlIEVWIFJvb3QgQ0EwHhcNMjIwMTEz
# MDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQD
# ExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aa
# za57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllV
# cq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT
# +CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd
# 463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+
# EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92k
# J7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5j
# rubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7
# f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJU
# KSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+wh
# X8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQAB
# o4IBZjCCAWIwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wHwYDVR0jBBgwFoAUsT7DaQP4v0cB1JgmGggC72NkK8MwDgYDVR0P
# AQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMH8GCCsGAQUFBwEBBHMwcTAk
# BggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEkGCCsGAQUFBzAC
# hj1odHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRIaWdoQXNzdXJh
# bmNlRVZSb290Q0EuY3J0MEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEhpZ2hBc3N1cmFuY2VFVlJvb3RDQS5jcmwwHAYD
# VR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcNAQELBQADggEBAEHx
# qRH0DxNHecllao3A7pgEpMbjDPKisedfYk/ak1k2zfIe4R7sD+EbP5HU5A/C5pg0
# /xkPZigfT2IxpCrhKhO61z7H0ZL+q93fqpgzRh9Onr3g7QdG64AupP2uU7SkwaT1
# IY1rzAGt9Rnu15ClMlIr28xzDxj4+87eg3Gn77tRWwR2L62t0+od/P1Tk+WMieNg
# GbngLyOOLFxJy34riDkruQZhiPOuAnZ2dMFkkbiJUZflhX0901emWG4f7vtpYeJa
# 3Cgh6GO6Ps9W7Zrk9wXqyvPsEt84zdp7PiuTUy9cUQBY3pBIowrHC/Q7bVUx8ALM
# R3eWUaNetbxcyEMRoacwggawMIIEmKADAgECAhAIrUCyYNKcTJ9ezam9k67ZMA0G
# CSqGSIb3DQEBDAUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0
# IFRydXN0ZWQgUm9vdCBHNDAeFw0yMTA0MjkwMDAwMDBaFw0zNjA0MjgyMzU5NTla
# MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UE
# AxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEz
# ODQgMjAyMSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDVtC9C
# 0CiteLdd1TlZG7GIQvUzjOs9gZdwxbvEhSYwn6SOaNhc9es0JAfhS0/TeEP0F9ce
# 2vnS1WcaUk8OoVf8iJnBkcyBAz5NcCRks43iCH00fUyAVxJrQ5qZ8sU7H/Lvy0da
# E6ZMswEgJfMQ04uy+wjwiuCdCcBlp/qYgEk1hz1RGeiQIXhFLqGfLOEYwhrMxe6T
# SXBCMo/7xuoc82VokaJNTIIRSFJo3hC9FFdd6BgTZcV/sk+FLEikVoQ11vkunKoA
# FdE3/hoGlMJ8yOobMubKwvSnowMOdKWvObarYBLj6Na59zHh3K3kGKDYwSNHR7Oh
# D26jq22YBoMbt2pnLdK9RBqSEIGPsDsJ18ebMlrC/2pgVItJwZPt4bRc4G/rJvmM
# 1bL5OBDm6s6R9b7T+2+TYTRcvJNFKIM2KmYoX7BzzosmJQayg9Rc9hUZTO1i4F4z
# 8ujo7AqnsAMrkbI2eb73rQgedaZlzLvjSFDzd5Ea/ttQokbIYViY9XwCFjyDKK05
# huzUtw1T0PhH5nUwjewwk3YUpltLXXRhTT8SkXbev1jLchApQfDVxW0mdmgRQRNY
# mtwmKwH0iU1Z23jPgUo+QEdfyYFQc4UQIyFZYIpkVMHMIRroOBl8ZhzNeDhFMJlP
# /2NPTLuqDQhTQXxYPUez+rbsjDIJAsxsPAxWEQIDAQABo4IBWTCCAVUwEgYDVR0T
# AQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQUaDfg67Y7+F8Rhvv+YXsIiGX0TkIwHwYD
# VR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNV
# HR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRU
# cnVzdGVkUm9vdEc0LmNybDAcBgNVHSAEFTATMAcGBWeBDAEDMAgGBmeBDAEEATAN
# BgkqhkiG9w0BAQwFAAOCAgEAOiNEPY0Idu6PvDqZ01bgAhql+Eg08yy25nRm95Ry
# sQDKr2wwJxMSnpBEn0v9nqN8JtU3vDpdSG2V1T9J9Ce7FoFFUP2cvbaF4HZ+N3HL
# IvdaqpDP9ZNq4+sg0dVQeYiaiorBtr2hSBh+3NiAGhEZGM1hmYFW9snjdufE5Btf
# Q/g+lP92OT2e1JnPSt0o618moZVYSNUa/tcnP/2Q0XaG3RywYFzzDaju4ImhvTnh
# OE7abrs2nfvlIVNaw8rpavGiPttDuDPITzgUkpn13c5UbdldAhQfQDN8A+KVssIh
# dXNSy0bYxDQcoqVLjc1vdjcshT8azibpGL6QB7BDf5WIIIJw8MzK7/0pNVwfiThV
# 9zeKiwmhywvpMRr/LhlcOXHhvpynCgbWJme3kuZOX956rEnPLqR0kq3bPKSchh/j
# wVYbKyP/j7XqiHtwa+aguv06P0WmxOgWkVKLQcBIhEuWTatEQOON8BUozu3xGFYH
# Ki8QxAwIZDwzj64ojDzLj4gLDb879M4ee47vtevLt/B3E+bnKD+sEq6lLyJsQfmC
# XBVmzGwOysWGw/YmMwwHS6DTBwJqakAwSEs0qFEgu60bhQjiWQ1tygVQK+pKHJ6l
# /aCnHwZ05/LWUpD9r4VIIflXO7ScA+2GRfS0YW6/aOImYIbqyK+p/pQd52MbOoZW
# eE4wggdnMIIFT6ADAgECAhAIaSgnopDAtpU2nRSjj8m1MA0GCSqGSIb3DQEBCwUA
# MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UE
# AxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEz
# ODQgMjAyMSBDQTEwHhcNMjUwODA0MDAwMDAwWhcNMjYwODAzMjM1OTU5WjCB7zET
# MBEGCysGAQQBgjc8AgEDEwJVUzEZMBcGCysGAQQBgjc8AgECEwhEZWxhd2FyZTEd
# MBsGA1UEDwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xEDAOBgNVBAUTBzQxNTI5NTQx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdTZWF0
# dGxlMSIwIAYDVQQKExlBbWF6b24gV2ViIFNlcnZpY2VzLCBJbmMuMRAwDgYDVQQL
# EwdBV1MgRUMyMSIwIAYDVQQDExlBbWF6b24gV2ViIFNlcnZpY2VzLCBJbmMuMIIB
# ojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA09z6LRLZ6B29Vw2rlhoClpGs
# KaHQgVSWBiQsZoosPwxMx7nOp3AC4aRP4V7v8E8e1zmzvevPdVL/p9KSPvFz4ApF
# Lt4c5xDryw+bn053Dy6eiKvmiOetjTuP/3b49H4R6kt8LZ8x5KhaphgypeIHKQHC
# 3JrfDjCq3Zh+WYMvL5O2fwcaMQQunl1AiXXKAfahflmC2r0GYzNthvqXvBkfAs9F
# e6ivOSLGVxrtptGveY8omIrde1vVFWItRww+Lk1yxXN5zO28M5SsDMJ5eryZPQ3y
# CWc0722z2GJJ7horCYpWqz9swuVd/YArwtk/Fmbwr8K+A7ZIbM0dLHPx20K3+r/n
# dNyO0gd0G8HGEMbTuE8zG0gPcOLn8faWM7W1pMmkiuOL8WUa2B/Pd0xJw5WinHhj
# FEyGB3LKPEZbxa/IIfHcbqPNE9tLJYJWZ9t9Cg10fECSJ+xsNEeLwerLkZaEzs/H
# fimTNMa/5SuWjCES/e3QUOIm2kg1TO7mXSdAljhtAgMBAAGjggICMIIB/jAfBgNV
# HSMEGDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQU6KNonE+tTU2/
# W3Q6S4Ynvfd8w3IwPQYDVR0gBDYwNDAyBgVngQwBAzApMCcGCCsGAQUFBwIBFhto
# dHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwDgYDVR0PAQH/BAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMIG1BgNVHR8Ega0wgaowU6BRoE+GTWh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5
# NlNIQTM4NDIwMjFDQTEuY3JsMFOgUaBPhk1odHRwOi8vY3JsNC5kaWdpY2VydC5j
# b20vRGlnaUNlcnRUcnVzdGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIx
# Q0ExLmNybDCBlAYIKwYBBQUHAQEEgYcwgYQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBcBggrBgEFBQcwAoZQaHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0Q29kZVNpZ25pbmdSU0E0MDk2U0hB
# Mzg0MjAyMUNBMS5jcnQwCQYDVR0TBAIwADANBgkqhkiG9w0BAQsFAAOCAgEAFx4M
# +HScolpI7T6bQYaAO4SU9rP1qiJxBSzEZ7j9rr0Jv3qdBm0SF7iB5NMBmgAKFRnn
# Wb0D46Da1q4hKlC4b9GX7oO6DLiA4b6upXn4ARULR8B+zMaC3PIXLemcnu1ENkj4
# UeFzIaxPbpeT5mNUT8D5dWDsO4L712KN0gkbtt+rwF5cowDuv6ei1A17HHkPPP1D
# KELMP2u5CGrjn67HuNv6n4+gHJW1CP0NSCyB2LpEZf/2FFiqfz4cpCYh6S81/ziA
# cvchuWGSxNpcGRmZFwAcd7wQcNveTJW9YE0JIJApE/q7EsLmk2pyYk02beNXedRN
# fVE7HMLb9ll706RZT93oMdJpfKVHq1qCLsIz/CChcBd4mHsStvxtj9cVCTlE7ELw
# g44I0sZQ+AITXgon+86fyjEM1G4SsZWcnhu8A9U2QzsfvD8vCkuHi3CnEeztf/u2
# 87tzprVnbz0/Y+DmOetj+CmdzNR0949irc10C2ikfK6dWt5r46bzHNYnHEhTVafX
# HL6zHhjOO4liSDb9yP4085xWnjAn4i0NpvL3uHb3Q4NrTrjJQtekVpIBbPuPsF4w
# a/uGLkDjeqjU3CJ9BifbYXHYZNw4ZJz+l5VGFU7RlABPgUIj4Fmac0ZnmbRemFQ8
# I3WQSlfftfuWwHUJ0NkQ/kEl47ZXRNyVfVEuLDYxghohMIIaHQIBATB9MGkxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGln
# aUNlcnQgVHJ1c3RlZCBHNCBDb2RlIFNpZ25pbmcgUlNBNDA5NiBTSEEzODQgMjAy
# MSBDQTECEAhpKCeikMC2lTadFKOPybUwDQYJYIZIAWUDBAIBBQCgfDAQBgorBgEE
# AYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgYte+YepMM2kznJKM
# ZaJsM7i9YjFFs+MAjat4WaHja34wDQYJKoZIhvcNAQEBBQAEggGAhnn4vaNLFEc5
# dOeY8VwEeGeeB6X/XOcPspNKnt0dNKW5AbV5wDlO05tJydFy4AnTMd5zq8pz/YGV
# PwqEksCjNTjPhWDlgt98Hvk3U2lXLk3hGBlsetl6O0wGnfXGPJzxY/Xz8mekDCvv
# jfdOhCgt0ENWvbb7zWGcKKIQKRA+QxvHbfdK8LHPEoe4AxaYH6GIwKaWWxT6kthd
# Xz7PdaKGVq44yl3cl2/mxXGBPOGXxK0HsCDxQ1vIKVG6L2/0vZXy53I5Asg8ep/O
# ThE0K3dv2iulTZDuaEE48Z2VJiCJkCB4oR5tHGAHmjlGUNGvmyFwyXDSDYXa+rI7
# 701+2FZExZcWBZwO6C2pW9Qws02YFulcaLoVHu3JVKTLCRP5P3pSpavsul13pL05
# n/ODgBdpkc9stbhc9PQoGiUVJK7gGcXgSAfHWFI+ER8hPBORNu31lC4pU8fQrTdO
# gkVXreHGwPUBCzBBg5dnmJAmHXgDiD+4iCiwQGdgoMFHy9iTNvSioYIXdzCCF3MG
# CisGAQQBgjcDAwExghdjMIIXXwYJKoZIhvcNAQcCoIIXUDCCF0wCAQMxDzANBglg
# hkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcwZQIBAQYJYIZIAYb9bAcBMDEw
# DQYJYIZIAWUDBAIBBQAEIKD6Z1OgcD3SMYaQhUX2PoH/za7NJfPD7N/W/qay7kYZ
# AhEAkDiUDRkeCHTEMyVN3ZyCRxgPMjAyNTEwMTMwNTIxMDBaoIITOjCCBu0wggTV
# oAMCAQICEAqA7xhLjfEFgtHEdqeVdGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UE
# BhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2Vy
# dCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENB
# MTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVT
# MRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hB
# MjU2IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/K
# N8wZQjBjMqiZ3xTWcfsLwOvRxUwXcGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3
# IU8kgNkeECqVQ+3bzWYesFtkepErvUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQF
# oxQ2Dsw4vEjoT1FpS54dNApZfKY61HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9l
# KMqzdIo7VA1R0V3Zp3DjjANwqAf4lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4
# zyh1uSqgr6UnbksIcFJqLbkIXIPbcNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9y
# krjS6GS3NR39iTTFS+ENTqW8m6THuOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+
# 8CTXaETkVWz0dVVZw7knh1WZXOLHgDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL
# 1naFKBy1p6llN3QgshRta6Eq4B40h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3D
# oK2O65Uck5Wggn8O2klETsJ7u8xEehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOee
# StPeldYRNMmSF3voIgMFtNGh86w3ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppw
# n4D3/Pt5pwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv8
# 8jHt/f3X85FxYxlQQ89hjOgwHwYDVR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ens
# y04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggr
# BgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5j
# cnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEu
# Y3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0B
# AQsFAAOCAgEAZSqt8RwnBLmuYEHs0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXR
# GQ/YAavXzWjZhY+hIfP2JkQ38U+wtJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1
# PzC/ZRX4pvP/ciZmUnthfAEP1HShTrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ
# 7vllKluHWiKk6FxRPyUPxAAYH2Vy1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4e
# KGxDJ8WDl/FQUSntbjZ80FU3i54tpx5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbt
# oRAmaaslNXdCG1+lqvP4FbrQ6IwSBXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00Gr
# JzPQFnCEH1Y58678IgmfORBPC1JKkYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6
# JfwyYHXSd+V08X1JUPvB4ILfJdmL+66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDI
# GMUG1dUtwq1qmcwbdUfcSYCn+OwncVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96
# HAlXHAL5SlfYxJ7La54i71McVWRP66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3
# AWVPGrbn5PhDBf3Froguzzhk++ami+r3Qrx5bIbY3TVzgiFI7Gq3zWcwgga0MIIE
# nKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0y
# NTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBH
# NCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51N
# rY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5ba
# p+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf7
# 7S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF
# 2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFkriK9tUKJm/s80Fio
# cSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzV
# yhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl
# 92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGP
# RdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//
# Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4O
# Lu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM
# 7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4E
# FgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcG
# CCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNV
# HSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIB
# ABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM
# 0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqW
# Gd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr
# 0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35
# k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKq
# MVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiy
# fTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDU
# phPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTj
# d6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2Z
# yJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWC
# nb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIFjTCCBHWgAwIBAgIQ
# DpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAx
# MDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQD
# ExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4IC
# DwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aa
# za57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllV
# cq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT
# +CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd
# 463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+
# EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92k
# J7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5j
# rubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7
# f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJU
# KSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYiCd98THU/Y+wh
# X8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQAB
# o4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5n
# P+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0P
# AQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDww
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IB
# AQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229
# GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FD
# RJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVG
# amlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCw
# rFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvR
# XKwYw02fc7cBqZ9Xql4o4rmUMYIDfDCCA3gCAQEwfTBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExAhAKgO8Y
# S43xBYLRxHanlXRoMA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqGSIb3DQEJAzENBgsq
# hkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUxMDEzMDUyMTAwWjArBgsqhkiG
# 9w0BCRACDDEcMBowGDAWBBTdYjCshgotMGvaOLFoeVIwB/tBfjAvBgkqhkiG9w0B
# CQQxIgQgOgHFvDyA5Ud0uELnAjY+g0rU3yVq3S4zM/sFJNWfhjwwNwYLKoZIhvcN
# AQkQAi8xKDAmMCQwIgQgSqA/oizXXITFXJOPgo5na5yuyrM/420mmqM08UYRCjMw
# DQYJKoZIhvcNAQEBBQAEggIAXLPy3nSYxyBjOmOujarGVgabR/H7wGHrwhPHPjkt
# vjRLFfg/63qHao6rbIrTJqbHnU7OXXSV3pRvUPK179VgNyivlHr/QPiTarYEUqtx
# GB1rmtg/CBAqDR3dBADH15x0w3H8J9vwHTZlbQQXrB456OHJTbOkRUf3lo3Wsd8d
# we085c8CEOLt5GDHWeEkYQMB/S0cLf9RFFhwuaMkjUVeMnjxScejfccecPmSJWuC
# jUDnd+BxRsSLpB2sAnTY04XtFadGtW4dQpz8auZlhOuPNVAWpkmnjDYyxphoKFQI
# LBf0FlrnQ1r1SWFt0699OsJ+kvk6jcPpXZRTWu3KAbVURDs/p8u4eN7sZN0Z6UW8
# qB9BU/Z9W1vN0wIdPievFqTPGJ3owaT7RXICs2w3vqE5gPuNjBk6RahhWYzX6Gc5
# nnR1ZAEXSU4OBO8CfSA+Y54hG1FavFvX/mjuOjDh4/sUs7kllqKXg1Te3Hdz5280
# UKK/PJJRmASkLxxZfQJ9HD2Jn08XjNwluit5ifFBsZNB1GS+Yn+s5S639oOeEJLW
# 9+2M1/fu+VJDhr0Pa5JEdKEaVn4EQUIt4+p3NqvShy+CU8y7OHeArLubfjs/x375
# aevptTc4xRMkCymfAUEuCmYs6OK9XGuB5wkNir1QRbX309r6L0F/DlEfH4zHvqAu
# TM4=
# SIG # End signature block
