[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterPortName
)

$ErrorActionPreference = 'Stop'
$LogDirectory = Join-Path 'C:\Intune\Printers' $PrinterName
$LogFile = Join-Path $LogDirectory 'UninstallLog.log'
$ExitCode = 0

function Write-Log {
    param([Parameter(Mandatory = $true)][string] $Message)

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $LogEntry = '{0} - {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $LogFile -Value $LogEntry
    Write-Host $LogEntry
}

try {
    $Printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($Printer) {
        Remove-Printer -Name $PrinterName -Confirm:$false -ErrorAction Stop
        Write-Log "Removed printer '$PrinterName'."
    }
    else {
        Write-Log "Printer '$PrinterName' does not exist."
    }

    $RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers\$PrinterName"
    if (Test-Path -LiteralPath $RegistryPath) {
        Remove-Item -LiteralPath $RegistryPath -Recurse -Force -ErrorAction Stop
        Write-Log "Removed remaining printer registry key '$RegistryPath'."
    }

    $Port = Get-PrinterPort -Name $PrinterPortName -ErrorAction SilentlyContinue
    if ($Port) {
        $PortUsers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object {
            $_.PortName -eq $PrinterPortName
        })

        if ($PortUsers.Count -gt 0) {
            $QueueNames = @($PortUsers | Select-Object -ExpandProperty Name) -join ', '
            Write-Log "Retained printer port '$PrinterPortName' because it is still used by: $QueueNames."
        }
        else {
            try {
                Remove-PrinterPort -Name $PrinterPortName -Confirm:$false -ErrorAction Stop
                Write-Log "Removed printer port '$PrinterPortName'."
            }
            catch {
                # A queue may have claimed the port between the check and the
                # removal attempt. Recheck before treating this as a failure.
                $PortUsers = @(Get-Printer -ErrorAction SilentlyContinue | Where-Object {
                    $_.PortName -eq $PrinterPortName
                })
                if ($PortUsers.Count -gt 0) {
                    $QueueNames = @($PortUsers | Select-Object -ExpandProperty Name) -join ', '
                    Write-Log "Retained printer port '$PrinterPortName' because it became or remained in use by: $QueueNames."
                }
                else {
                    throw
                }
            }
        }
    }
    else {
        Write-Log "Printer port '$PrinterPortName' does not exist."
    }

    Write-Log 'STATUS=SUCCESS'
}
catch {
    $ExitCode = 1
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log 'STATUS=FAILED'
}

exit $ExitCode
