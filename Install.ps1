# ------------ MEM VARIABLES ----------------
[CmdletBinding()]
param
(
    [Parameter()]
    [String] $PrinterPortIPAddress = $null, # Printer Port IP Address
    [Parameter()]
    [String] $PrinterPortName = $null, # Printer Port Name
    [Parameter()]
    [String] $PrinterName = $null, # Name in Control Panel
    [Parameter()]
    [String] $PrinterDriverModelName = $null, # Installed Driver Model used in 'have disk' prompt.
    [Parameter()]
    [String] $PrinterDriverZipFileName = $null, # Driver ZIP file.
    [Parameter()]
    [String] $PrinterDriverModelFileName = $null, # Driver file used in 'have disk' prompt.
    [Parameter()]
    [String] $ConfigFilePath = $null  # parameter for config.dat file.
)

[bool] $ExitWithError = $true
[bool] $ExitWithNoError = $false
$LogDirectory = "C:\Intune\Printers\$PrinterName"
$LogFile = "$LogDirectory\PrinterSetup.log"

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

# Installing the Driver
Expand-Archive -Path "$PSScriptRoot\$PrinterDriverZipFileName" -DestinationPath "$PSScriptRoot\" -Force
If (Test-Path -Path "$PSScriptRoot\Driver") {
    try {
        cscript "C:\Windows\System32\Printing_Admin_Scripts\en-US\prndrvr.vbs" -a -m $PrinterDriverModelName -i "$PSScriptRoot\Driver\$PrinterDriverModelFileName" -h "$PSScriptRoot\Driver" -v 3
        Write-Log "Installed or updated driver: '$PrinterDriverModelName'."
    }
    catch {
        Write-Log "Driver installation failed for model: '$PrinterDriverModelName'."
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
} else {
    Write-Log "Driver directory does not exist."
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}

# Remove existing Printer Port if it exists
$existingPort = Get-PrinterPort | Where-Object {$_.Name -eq $PrinterPortName}
if ($existingPort) {
    try {
        Remove-PrinterPort -Name $PrinterPortName -Confirm:$false
        Write-Log "Removed existing Printer Port '$PrinterPortName'."
    } catch {
        Write-Log "Failed to remove existing Printer Port '$PrinterPortName'."
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}

# Add the new Printer Port
try {
    Add-PrinterPort -Name $PrinterPortName -PrinterHostAddress $PrinterPortIPAddress -PortNumber 9100
    Write-Log "Added Printer Port '$PrinterPortName' with IP address '$PrinterPortIPAddress.'"
} catch {
    Write-Log "Failed to add Printer Port '$PrinterPortName'."
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}

# Remove existing Printer if it exists
$existingPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if ($existingPrinter) {
    try {
        Remove-Printer -Name $PrinterName -Confirm:$false
        Write-Log "Removed existing Printer '$PrinterName'."
    } catch {
        Write-Log "Failed to remove existing Printer '$PrinterName.'"
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
    }
}

# Add the new Printer
try {
    Add-Printer -Name $PrinterName -PortName $PrinterPortName -DriverName $PrinterDriverModelName
    Write-Log "Added Printer '$PrinterName' with Port '$PrinterPortName' and Driver '$PrinterDriverModelName'."
} catch {
    Write-Log "Failed to add Printer '$PrinterName'."
    Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "FAILED"
}

# Install configuration if -ConfigFilePath parameter is passed
if ($ConfigFilePath) {
    try {
        & "printui.exe" /Sr /n "$PrinterName" /a "$ConfigFilePath"
        Write-Log "Printer configuration applied from '$ConfigFilePath'."
    } catch {
        Write-Log "Failed to apply configuration from '$ConfigFilePath'."
        Update-OutputOnExit -F_ExitCode $ExitWithError -F_Message "Configuration installation failed"
    }
}

Update-OutputOnExit -F_ExitCode $ExitWithNoError -F_Message "SUCCESS"
