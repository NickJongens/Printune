[CmdletBinding()]
param
(
    [Parameter()]
    [String] $PrinterName = $null,
    [Parameter()]
    [String] $PrinterPortName = $null
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
$LogDirectory = "C:\Intune\Printers\$PrinterName"
$LogFile = "$LogDirectory\UninstallLog.log"

# Create log directory if it doesn't exist
if (!(Test-Path -Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

# Log function
function Write-Log {
    param (
        [string] $Message
    )
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$TimeStamp - $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $LogEntry
}

# Function to exit with a message
function Update-OutputOnExit {
    param (
        [bool] $F_ExitCode,
        [String] $F_Message
    )
    
    Write-Log "STATUS=$F_Message"
    
    if ($F_ExitCode) {
        exit 1
    } else {
        exit 0
    }
}

# Attempt to remove the printer
try {
    if (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue) {
        Remove-Printer -Name $PrinterName -ErrorAction Stop
        Write-Log "Removed printer: '$PrinterName'."
    } else {
        Write-Log "Printer '$PrinterName' does not exist."
    }
} catch {
    Write-Log "Failed to remove printer: '$PrinterName'. Error: $_"
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED to remove printer"
}

# Attempt to remove the printer port
try {
    if (Get-PrinterPort -Name $PrinterPortName -ErrorAction SilentlyContinue) {
        Remove-PrinterPort -Name $PrinterPortName -ErrorAction Stop
        Write-Log "Removed printer port: '$PrinterPortName'."
    } else {
        Write-Log "Printer port '$PrinterPortName' does not exist."
    }
} catch {
    Write-Log "Failed to remove printer port: '$PrinterPortName'. Error: $_"
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED to remove printer port"
}

# Attempt to remove the printer registry key
try {
    $RegKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$PrinterName"
    if (Test-Path -Path $RegKeyPath) {
        Remove-Item -Path $RegKeyPath -Recurse -Force
        Write-Log "Removed registry key: '$RegKeyPath'."
    } else {
        Write-Log "Registry key '$RegKeyPath' does not exist."
    }
} catch {
    Write-Log "Failed to remove registry key: '$RegKeyPath'. Error: $_"
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED to remove registry key"
}

Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
