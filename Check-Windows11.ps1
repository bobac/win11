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
    try {
        Write-Host "Stahuji $url..."
        $html = Invoke-WebRequest -Uri $url -UseBasicParsing
        $lines = $html.Content -split "`n" | 
            Where-Object { $_ -match '<td[^>]*>(.*?)</td>' } |
            ForEach-Object {
                if ($_ -match '<td[^>]*>(.*?)</td>') {
                    $matches[1].Trim()
                }
            }
        # Filtrujeme pouze řádky obsahující model procesoru (čísla a písmena)
        $lines | Where-Object { $_ -match '[0-9]+[A-Za-z]*' } | Set-Content -Path $path
        Write-Host "Uloženo do $path"
        return $true
    } catch {
        Write-Host "Chyba při stahování ${url}: $($_.Exception.Message)"
        return $false
    }
}

# Stažení seznamů
$intelDownloaded = Download-CPUList -url $intelUrl -path $intelFile
$amdDownloaded = Download-CPUList -url $amdUrl -path $amdFile
$qualcommDownloaded = Download-CPUList -url $qualcommUrl -path $qualcommFile

# Kontrola a použití existujících souborů v případě selhání stahování
if (-not $intelDownloaded -and (Test-Path $intelFile) -and (Get-Item $intelFile).Length -gt 0) {
    Write-Host "Používám existující soubor $intelFile"
}
if (-not $amdDownloaded -and (Test-Path $amdFile) -and (Get-Item $amdFile).Length -gt 0) {
    Write-Host "Používám existující soubor $amdFile"
}
if (-not $qualcommDownloaded -and (Test-Path $qualcommFile) -and (Get-Item $qualcommFile).Length -gt 0) {
    Write-Host "Používám existující soubor $qualcommFile"
}

# Kontrola, zda máme alespoň jeden platný soubor
if (-not (Test-Path $intelFile) -or (Get-Item $intelFile).Length -eq 0) {
    Write-Host "Chyba: Nelze získat seznam Intel procesorů"
    exit 1
}
if (-not (Test-Path $amdFile) -or (Get-Item $amdFile).Length -eq 0) {
    Write-Host "Chyba: Nelze získat seznam AMD procesorů"
    exit 1
}
if (-not (Test-Path $qualcommFile) -or (Get-Item $qualcommFile).Length -eq 0) {
    Write-Host "Chyba: Nelze získat seznam Qualcomm procesorů"
    exit 1
}

# TPM verze
function Get-TPMVersion {
    $tpm = Get-CimInstance -Namespace "Root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue
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
    # Extrahujeme model procesoru z celého názvu
    $cpuModel = $cpuName -replace '.*(i[0-9]-[0-9]+[A-Za-z]*).*', '$1'
    
    $intelList = Get-Content -Path $intelFile
    $amdList = Get-Content -Path $amdFile
    $qualcommList = Get-Content -Path $qualcommFile

    # Kontrolujeme přesnou shodu modelu
    foreach ($line in $intelList + $amdList + $qualcommList) {
        if ($line -eq $cpuModel) {
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
Write-Host "RAM: $([math]::Round($ram, 2)) GB"
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
