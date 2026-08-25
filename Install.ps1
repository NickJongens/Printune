# Printer driver and queue deployment
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterPortIPAddress,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterPortName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterDriverModelName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterDriverZipFileName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $PrinterDriverModelFileName,

    [Parameter()]
    [string] $ConfigFilePath,

    [Parameter()]
    [switch] $TrustDriverPublisher
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$LogDirectory = Join-Path 'C:\Intune\Printers' $PrinterName
$LogFile = Join-Path $LogDirectory 'PrinterSetup.log'
$ExtractionRoot = $null
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

function Resolve-DriverInf {
    param(
        [Parameter(Mandatory = $true)][string] $SearchRoot,
        [Parameter(Mandatory = $true)][string] $RequestedInf,
        [Parameter(Mandatory = $true)][string] $ModelName
    )

    $InfLeaf = Split-Path -Path $RequestedInf -Leaf
    $RequestedSuffix = $RequestedInf.TrimStart([char[]]'\/')
    $Candidates = @(Get-ChildItem -LiteralPath $SearchRoot -Recurse -File -Filter $InfLeaf)

    if ($Candidates.Count -eq 0) {
        $AvailableInfs = @(Get-ChildItem -LiteralPath $SearchRoot -Recurse -File -Filter '*.inf' |
            Select-Object -ExpandProperty FullName)
        throw "No INF named '$InfLeaf' was found after extracting the ZIP. Available INF files: $($AvailableInfs -join '; ')"
    }

    $RankedCandidates = @($Candidates | ForEach-Object {
        $Score = 0
        $InfText = Get-Content -LiteralPath $_.FullName -Raw
        $ContainsModelHint = $InfText.IndexOf(
            $ModelName,
            [System.StringComparison]::OrdinalIgnoreCase
        ) -ge 0

        if ($_.FullName.EndsWith($RequestedSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $Score += 100
        }
        if ($_.FullName -match '(?i)[\\/](64bit|x64|amd64)[\\/]') {
            $Score += 50
        }
        if ($_.FullName -match '(?i)[\\/](32bit|x86)[\\/]') {
            $Score -= 50
        }
        if ($ContainsModelHint) {
            # This also recognises models declared through a token in an INF
            # [Strings] section because the resolved model value is still present.
            $Score += 25
        }

        [pscustomobject]@{
            File              = $_
            Score             = $Score
            ContainsModelHint = $ContainsModelHint
        }
    } | Sort-Object -Property Score -Descending)

    $SelectedCandidate = $RankedCandidates[0]
    if (-not $SelectedCandidate.ContainsModelHint) {
        Write-Log "WARNING: The selected INF does not contain a plain-text model hint for '$ModelName'. Installation will continue and the registered driver name will be verified after staging."
    }

    return $SelectedCandidate.File.FullName
}

function Add-DriverPublisherTrust {
    param([Parameter(Mandatory = $true)][string] $InfPath)

    $InfText = Get-Content -LiteralPath $InfPath -Raw
    $CatalogMatch = [regex]::Match(
        $InfText,
        '(?im)^\s*CatalogFile(?:\.[^=]+)?\s*=\s*(?<Catalog>[^;\r\n]+)'
    )

    if (-not $CatalogMatch.Success) {
        throw "No CatalogFile entry was found in '$InfPath'."
    }

    $CatalogName = $CatalogMatch.Groups['Catalog'].Value.Trim()
    $CatalogPath = Join-Path (Split-Path -Path $InfPath -Parent) $CatalogName
    if (-not (Test-Path -LiteralPath $CatalogPath)) {
        throw "The signed driver catalogue was not found: '$CatalogPath'."
    }

    $Signature = Get-AuthenticodeSignature -LiteralPath $CatalogPath
    if ($null -eq $Signature.SignerCertificate) {
        throw "The driver catalogue does not expose a signer certificate: '$CatalogPath'."
    }

    if ($Signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
        throw "Driver catalogue signature validation failed: $($Signature.Status) - $($Signature.StatusMessage)"
    }

    $Signer = $Signature.SignerCertificate
    $Chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    $Chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    if (-not $Chain.Build($Signer)) {
        $ChainErrors = @($Chain.ChainStatus | ForEach-Object { $_.StatusInformation.Trim() }) -join '; '
        throw "The catalogue signer does not chain to a trusted root: $ChainErrors"
    }

    $Store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        'TrustedPublisher',
        [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine
    )

    try {
        $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $Existing = $Store.Certificates.Find(
            [System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
            $Signer.Thumbprint,
            $false
        )

        if ($Existing.Count -eq 0) {
            $Store.Add($Signer)
            Write-Log "Trusted signed driver publisher '$($Signer.Subject)' with thumbprint '$($Signer.Thumbprint)'."
        }
        else {
            Write-Log "Driver publisher is already trusted: '$($Signer.Subject)'."
        }
    }
    finally {
        $Store.Close()
    }
}

try {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This installation must run as an administrator or as SYSTEM.'
    }

    $ZipPath = Join-Path $PSScriptRoot $PrinterDriverZipFileName
    if (-not (Test-Path -LiteralPath $ZipPath)) {
        throw "Driver ZIP not found: '$ZipPath'."
    }

    $ExtractionRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        'ADITS-PrinterDriver-{0}' -f [guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $ExtractionRoot -Force | Out-Null
    Write-Log "Extracting '$ZipPath' to temporary working directory."
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractionRoot -Force

    $InfPath = Resolve-DriverInf `
        -SearchRoot $ExtractionRoot `
        -RequestedInf $PrinterDriverModelFileName `
        -ModelName $PrinterDriverModelName

    Write-Log "Selected driver INF: '$InfPath'."

    $SpoolerService = Get-Service -Name 'Spooler' -ErrorAction Stop
    if ($SpoolerService.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        Start-Service -Name 'Spooler' -ErrorAction Stop
        Write-Log 'Started the Print Spooler service.'
    }

    $ExistingDriver = Get-PrinterDriver -Name $PrinterDriverModelName -ErrorAction SilentlyContinue
    if (-not $ExistingDriver) {
        if ($TrustDriverPublisher) {
            Write-Log 'TrustDriverPublisher was specified. Validating the signed catalogue before trusting its publisher.'
            Add-DriverPublisherTrust -InfPath $InfPath
        }
        else {
            Write-Log 'TrustDriverPublisher was not specified. The catalogue publisher will not be added to LocalMachine\TrustedPublisher.'
        }

        Write-Log 'Staging driver package with PnPUtil.'
        $PnPOutput = @(& "$env:SystemRoot\System32\pnputil.exe" /add-driver $InfPath /install)
        $PnPExitCode = $LASTEXITCODE
        foreach ($OutputLine in $PnPOutput) {
            Write-Log "PnPUtil: $OutputLine"
        }

        if ($PnPExitCode -notin @(0, 1641, 3010)) {
            $TrustHint = if (-not $TrustDriverPublisher) {
                ' If SetupAPI reports 0x800F0242, rerun with -TrustDriverPublisher.'
            }
            else {
                ''
            }
            throw "PnPUtil failed with exit code $PnPExitCode. Review '$env:SystemRoot\INF\setupapi.dev.log' for the underlying SetupAPI error.$TrustHint"
        }

        Write-Log "Registering printer driver '$PrinterDriverModelName' with the print subsystem."
        Add-PrinterDriver -Name $PrinterDriverModelName -ErrorAction Stop
    }
    else {
        Write-Log "Printer driver '$PrinterDriverModelName' is already installed."
    }

    $InstalledDriver = Get-PrinterDriver -Name $PrinterDriverModelName -ErrorAction SilentlyContinue
    if (-not $InstalledDriver) {
        throw "Driver staging completed without error, but '$PrinterDriverModelName' is not registered in the print subsystem."
    }
    Write-Log "Verified printer driver '$PrinterDriverModelName'."

    $ExistingPrinter = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($ExistingPrinter -and (
        $ExistingPrinter.DriverName -ne $PrinterDriverModelName -or
        $ExistingPrinter.PortName -ne $PrinterPortName
    )) {
        Remove-Printer -Name $PrinterName -Confirm:$false -ErrorAction Stop
        Write-Log "Removed existing printer '$PrinterName' because its driver or port did not match."
        $ExistingPrinter = $null
    }

    $ExistingPort = Get-PrinterPort -Name $PrinterPortName -ErrorAction SilentlyContinue
    if ($ExistingPort -and
        $ExistingPort.PrinterHostAddress -ne $PrinterPortIPAddress) {
        if ($ExistingPrinter) {
            Remove-Printer -Name $PrinterName -Confirm:$false -ErrorAction Stop
            $ExistingPrinter = $null
        }
        Remove-PrinterPort -Name $PrinterPortName -Confirm:$false -ErrorAction Stop
        Write-Log "Removed printer port '$PrinterPortName' because its address did not match."
        $ExistingPort = $null
    }

    if (-not $ExistingPort) {
        Add-PrinterPort `
            -Name $PrinterPortName `
            -PrinterHostAddress $PrinterPortIPAddress `
            -PortNumber 9100 `
            -ErrorAction Stop
        Write-Log "Added printer port '$PrinterPortName' for '$PrinterPortIPAddress'."
    }
    else {
        Write-Log "Printer port '$PrinterPortName' already exists."
    }

    if (-not $ExistingPrinter) {
        Add-Printer `
            -Name $PrinterName `
            -PortName $PrinterPortName `
            -DriverName $PrinterDriverModelName `
            -ErrorAction Stop
        Write-Log "Added printer '$PrinterName'."
    }
    else {
        Write-Log "Printer '$PrinterName' is already configured correctly."
    }

    if ($ConfigFilePath) {
        $ResolvedConfigPath = $ConfigFilePath
        if (-not [System.IO.Path]::IsPathRooted($ResolvedConfigPath)) {
            $ResolvedConfigPath = Join-Path $PSScriptRoot $ResolvedConfigPath
        }
        if (-not (Test-Path -LiteralPath $ResolvedConfigPath)) {
            throw "Printer configuration file not found: '$ResolvedConfigPath'."
        }
        if ((Get-Item -LiteralPath $ResolvedConfigPath).Length -eq 0) {
            throw "Printer configuration file is empty: '$ResolvedConfigPath'."
        }

        # Restore global DEVMODE and printer-specific driver data only. The r
        # and p flags retain the deployed queue and port names when the config
        # was exported from a differently named test queue.
        $PrintUiArguments = 'printui.dll,PrintUIEntry /Sr /n "{0}" /a "{1}" g d r p /q' -f `
            $PrinterName, $ResolvedConfigPath
        $PrintUiProcess = Start-Process `
            -FilePath "$env:SystemRoot\System32\rundll32.exe" `
            -ArgumentList $PrintUiArguments `
            -Wait `
            -PassThru `
            -WindowStyle Hidden

        if ($PrintUiProcess.ExitCode -ne 0) {
            throw "Printer configuration import failed with exit code $($PrintUiProcess.ExitCode)."
        }
        Write-Log "Applied global printer defaults and driver data from '$ResolvedConfigPath'."
    }

    Write-Log 'STATUS=SUCCESS'
}
catch {
    $ExitCode = 1
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log 'STATUS=FAILED'
}
finally {
    if ($ExtractionRoot -and (Test-Path -LiteralPath $ExtractionRoot)) {
        try {
            Remove-Item -LiteralPath $ExtractionRoot -Recurse -Force -ErrorAction Stop
        }
        catch {
            Write-Log "WARNING: Could not remove temporary extraction directory '$ExtractionRoot': $($_.Exception.Message)"
        }
    }
}

exit $ExitCode
