# Check-Windows11

A PowerShell script to check if your computer is compatible with Windows 11.

## Features

- Checks TPM version (2.0 required)
- Verifies RAM availability (4GB minimum)
- Validates Secure Boot status
- Confirms UEFI mode
- Validates CPU compatibility against Microsoft's official supported CPU lists
- Automatically downloads the latest CPU compatibility lists

## Requirements

- PowerShell 5.1 or newer
- Windows 10 or newer operating system
- Internet connection (for first run to download CPU lists)

## Usage

1. Clone this repository or download the script
2. Open PowerShell as Administrator
3. Navigate to the script directory
4. Run the script:

```powershell
.\Check-Windows11.ps1
```

## How It Works

The script performs the following checks:

1. TPM version - Must be 2.0 or higher
2. RAM - Must have at least 4GB of RAM
3. Secure Boot - Must be enabled
4. UEFI - Must be in UEFI mode, not legacy BIOS
5. CPU Compatibility - CPU must be on Microsoft's official supported list

The script will automatically download the latest CPU compatibility lists from Microsoft's documentation and cache them locally.

## Output

The script will output the status of each requirement and a final verdict:

- ✅ If all requirements are met, the computer is compatible with Windows 11
- ❌ If any requirement is not met, the computer is not compatible with Windows 11

## Exit Codes

- `0` - Computer is compatible with Windows 11
- `1001` - Computer is not compatible with Windows 11

## License

MIT 