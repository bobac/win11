# Paths to local files with lists
$intelFile = ".\intel.txt"
$amdFile = ".\amd.txt"
$qualcommFile = ".\qualcomm.txt"

# Links to official lists
$intelUrl = "https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-intel-processors"
$amdUrl = "https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-amd-processors"
$qualcommUrl = "https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-qualcomm-processors"

function Download-CPUList {
    param(
        [string]$url,
        [string]$path
    )
    try {
        Write-Host "Downloading $url..."
        $html = Invoke-WebRequest -Uri $url -UseBasicParsing
        $lines = $html.Content -split "`n" | 
            Where-Object { $_ -match '<td[^>]*>(.*?)</td>' } |
            ForEach-Object {
                if ($_ -match '<td[^>]*>(.*?)</td>') {
                    $matches[1].Trim()
                }
            }
        # Filter only lines containing processor model (numbers and letters)
        $lines | Where-Object { $_ -match '[0-9]+[A-Za-z]*' } | Set-Content -Path $path
        Write-Host "Saved to $path"
        return $true
    } catch {
        Write-Host "Error downloading ${url}: $($_.Exception.Message)"
        return $false
    }
}

# Download lists
$intelDownloaded = Download-CPUList -url $intelUrl -path $intelFile
$amdDownloaded = Download-CPUList -url $amdUrl -path $amdFile
$qualcommDownloaded = Download-CPUList -url $qualcommUrl -path $qualcommFile

# Check and use existing files if download fails
if (-not $intelDownloaded -and (Test-Path $intelFile) -and (Get-Item $intelFile).Length -gt 0) {
    Write-Host "Using existing file $intelFile"
}
if (-not $amdDownloaded -and (Test-Path $amdFile) -and (Get-Item $amdFile).Length -gt 0) {
    Write-Host "Using existing file $amdFile"
}
if (-not $qualcommDownloaded -and (Test-Path $qualcommFile) -and (Get-Item $qualcommFile).Length -gt 0) {
    Write-Host "Using existing file $qualcommFile"
}

# Check if we have at least one valid file
if (-not (Test-Path $intelFile) -or (Get-Item $intelFile).Length -eq 0) {
    Write-Host "Error: Cannot get Intel processor list"
    exit 1
}
if (-not (Test-Path $amdFile) -or (Get-Item $amdFile).Length -eq 0) {
    Write-Host "Error: Cannot get AMD processor list"
    exit 1
}
if (-not (Test-Path $qualcommFile) -or (Get-Item $qualcommFile).Length -eq 0) {
    Write-Host "Error: Cannot get Qualcomm processor list"
    exit 1
}

# TPM version
function Get-TPMVersion {
    $tpm = Get-CimInstance -Namespace "Root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    if ($tpm -and $tpm.SpecVersion) {
        return $tpm.SpecVersion
    } else {
        return "Not detected"
    }
}

# Secure Boot
function Get-SecureBootStatus {
    try {
        $sb = Confirm-SecureBootUEFI
        return $sb
    } catch {
        return $false
    }
}

# 64-bit OS check
function Is-64BitOS {
    return [Environment]::Is64BitOperatingSystem
}

# Free disk space check
function Get-FreeDiskSpace {
    $systemDrive = $env:SystemDrive
    $drive = Get-PSDrive -Name $systemDrive[0]
    return [math]::Round($drive.Free / 1GB, 2)
}

# DirectX 12 support check
function Has-DirectX12Support {
    try {
        $dxdiag = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\DirectX" -Name "Version" -ErrorAction SilentlyContinue
        if ($dxdiag -and $dxdiag.Version -ge 12) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

# CPU model
function Get-CPUModel {
    $cpu = Get-CimInstance -ClassName Win32_Processor
    return $cpu.Name
}

# CPU support
function Is-CPUSupported {
    param (
        [string]$cpuName
    )
    $intelList = Get-Content -Path $intelFile
    $amdList = Get-Content -Path $amdFile
    $qualcommList = Get-Content -Path $qualcommFile

    # Check if any supported model is contained in the CPU name
    foreach ($line in $intelList + $amdList + $qualcommList) {
        if ($cpuName -like "*$line*") {
            return $true
        }
    }
    return $false
}

# Checks
$tpmVersion = Get-TPMVersion
$ram = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$secureBoot = Get-SecureBootStatus
$is64Bit = Is-64BitOS
$freeSpace = Get-FreeDiskSpace
$directX12 = Has-DirectX12Support
$cpuModel = Get-CPUModel
$cpuSupported = Is-CPUSupported -cpuName $cpuModel

# Output
Write-Host "TPM Version: $tpmVersion"
Write-Host "RAM: $([math]::Round($ram, 2)) GB"
Write-Host "Secure Boot: $secureBoot"
Write-Host "64-bit OS: $is64Bit"
Write-Host "Free Disk Space: $freeSpace GB"
Write-Host "DirectX 12 Support: $directX12"
Write-Host "CPU Model: $cpuModel"
Write-Host "CPU Supported: $cpuSupported"

# Decision
if ($tpmVersion -like "2.*" -and $ram -ge 4 -and $secureBoot -eq $true -and $is64Bit -eq $true -and $freeSpace -ge 64 -and $directX12 -eq $true -and $cpuSupported -eq $true) {
    Write-Host "✅ Computer is compatible with Windows 11."
    exit 0
} else {
    Write-Host "❌ Computer is not compatible with Windows 11."
    exit 1001
}
