# Cesty k lokálním souborům se seznamy
$intelFile = ".\intel.txt"
$amdFile = ".\amd.txt"
$qualcommFile = ".\qualcomm.txt"

# Odkazy na oficiální seznamy
$intelUrl = "https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-intel-processors"
$amdUrl = "https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-amd-processors"
$qualcommUrl = "https://learn.microsoft.com/en-us/windows-hardware/design/minimum/supported/windows-11-supported-qualcomm-processors"

function Download-CPUList {
    param(
        [string]$url,
        [string]$path
    )
    Write-Host "Stahuji $url..."
    $html = Invoke-WebRequest -Uri $url -UseBasicParsing
    $lines = ($html.ParsedHtml.getElementsByTagName("table") | Select-Object -First 1).rows |
        ForEach-Object {
            $_.cells[0].innerText.Trim()
        }
    $lines | Set-Content -Path $path
    Write-Host "Uloženo do $path"
}

# Stažení seznamů, pokud neexistují
if (-not (Test-Path $intelFile)) { Download-CPUList -url $intelUrl -path $intelFile }
if (-not (Test-Path $amdFile)) { Download-CPUList -url $amdUrl -path $amdFile }
if (-not (Test-Path $qualcommFile)) { Download-CPUList -url $qualcommUrl -path $qualcommFile }

# TPM verze
function Get-TPMVersion {
    $tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm -ErrorAction SilentlyContinue
    if ($tpm -and $tpm.SpecVersion) {
        return $tpm.SpecVersion
    } else {
        return "Není detekováno"
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

# UEFI
function Get-UEFIMode {
    $firmware = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "PEFirmwareType" -ErrorAction SilentlyContinue
    return ($firmware.PEFirmwareType -eq 2)
}

# CPU model
function Get-CPUModel {
    $cpu = Get-CimInstance -ClassName Win32_Processor
    return $cpu.Name
}

# Podpora CPU
function Is-CPUSupported {
    param (
        [string]$cpuName
    )
    $intelList = Get-Content -Path $intelFile
    $amdList = Get-Content -Path $amdFile
    $qualcommList = Get-Content -Path $qualcommFile

    foreach ($line in $intelList + $amdList + $qualcommList) {
        if ($cpuName -like "*$line*") {
            return $true
        }
    }
    return $false
}

# Kontroly
$tpmVersion = Get-TPMVersion
$ram = (Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB
$secureBoot = Get-SecureBootStatus
$uefi = Get-UEFIMode
$cpuModel = Get-CPUModel
$cpuSupported = Is-CPUSupported -cpuName $cpuModel

# Výstup
Write-Host "Verze TPM: $tpmVersion"
Write-Host "RAM: {0:N2} GB" -f $ram
Write-Host "Secure Boot: $secureBoot"
Write-Host "UEFI: $uefi"
Write-Host "Model CPU: $cpuModel"
Write-Host "CPU podporován: $cpuSupported"

# Rozhodnutí
if ($tpmVersion -like "2.*" -and $ram -ge 4 -and $secureBoot -eq $true -and $uefi -eq $true -and $cpuSupported -eq $true) {
    Write-Host "✅ Počítač je kompatibilní s Windows 11."
    exit 0
} else {
    Write-Host "❌ Počítač není kompatibilní s Windows 11."
    exit 1001
}
