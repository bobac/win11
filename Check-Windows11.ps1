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
        $htmlContent = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content

        # Regex to find table rows and extract the 3rd TD content
        # (?s) - single line mode, . matches newline
        # <tr>.*? - match <tr> and anything lazily
        # <td[^>]*>.*?</td>.*? - match first TD and content
        # <td[^>]*>.*?</td>.*? - match second TD and content
        # <td[^>]*>(.*?)</td> - match third TD and CAPTURE its content
        # .*?</tr> - match anything lazily until </tr>
        $regex = [regex]'(?s)<tr>.*?<td[^>]*>.*?</td>.*?<td[^>]*>.*?</td>.*?<td[^>]*>(.*?)</td>.*?</tr>'
        $matches = $regex.Matches($htmlContent)

        if ($matches.Count -eq 0) {
            Write-Host "Error processing ${url}: Could not find matching table data using primary regex. No fallback attempted."
            return $false
        }

        $models = $matches | ForEach-Object {
            try {
                $modelText = $_.Groups[1].Value # Access Group 1
                if ($null -eq $modelText) {
                    # Write-Host "Warning: Regex matched row, but Group 1 is null. Row HTML: $($_.Value)" # Optional debug
                    return $null # Skip this match
                }
                $modelText = $modelText.Trim()
                # Clean up potential HTML tags like <sup>[1]</sup> or other formatting
                $modelText = $modelText -replace '<[^>]+>', ''
                # Further cleanup - removes things like [1] or [2]
                $modelText = $modelText -replace '\[\d+\]', ''
                $modelText.Trim() # Trim again after replacements
            } catch {
                Write-Host "Error processing a specific match: $($_.Exception.Message). Match value: $($_.Value)"
                return $null # Skip this match on error
            }
        }

        # Filter out empty lines or header rows more carefully
        $filteredModels = $models | Where-Object {
            $_ -ne $null -and
            $_.Trim() -ne '' -and
            $_ -ne 'Model' -and # Explicitly exclude header
            $_ -notmatch '^\s*$' # Ensure it's not just whitespace
        }

        if ($filteredModels.Count -eq 0) {
             Write-Host "Error processing ${url}: Primary regex found rows, but filtering resulted in an empty list."
             return $false
        }

        $filteredModels | Set-Content -Path $path

        Write-Host "Saved to $path"
        return $true
    } catch {
        Write-Host "Error downloading or processing ${url}: $($_.Exception.Message)"
        return $false
    }
}

Write-Host "Downloading processor lists..."
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
    
    $listToSearch = $null
    $manufacturer = "Unknown"

    # Determine manufacturer and select the correct list
    if ($cpuName -match 'Intel') {
        $manufacturer = "Intel"
        $listToSearch = Get-Content -Path $intelFile -ErrorAction SilentlyContinue
    } elseif ($cpuName -match 'AMD') {
        $manufacturer = "AMD"
        $listToSearch = Get-Content -Path $amdFile -ErrorAction SilentlyContinue
    } elseif ($cpuName -match 'Qualcomm') {
        # Qualcomm detection might need refinement based on actual CPU names
        $manufacturer = "Qualcomm"
        $listToSearch = Get-Content -Path $qualcommFile -ErrorAction SilentlyContinue
    }

    if ($null -eq $listToSearch) {
        Write-Host "Warning: Could not determine CPU manufacturer or read the corresponding list for '$cpuName'. Assuming not supported."
        return $false
    }

    Write-Host "Debug: Checking CPU '$cpuName' against $manufacturer list."

    # Check if any line (full model name) from the selected list is contained in the CPU name
    foreach ($line in $listToSearch) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine -ne '') {
            if ($cpuName -like "*$trimmedLine*") {
                # Write-Host "Debug: Match found! CPU Name '$cpuName' contains list entry '$trimmedLine'"
                return $true
            }
        }
    }
    # Write-Host "Debug: No match found for CPU Name '$cpuName' in the $manufacturer list."
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
    Write-Host "[v] Computer is compatible with Windows 11."
    exit 0
} else {
    Write-Host "[x] Computer is not compatible with Windows 11."
    exit 1001
}
