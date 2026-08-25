# Printune: Intune Printer Deployment Toolkit

A web-based toolkit for creating Microsoft Intune Win32 packages that deploy local TCP/IP printers, manufacturer drivers, and optional printer defaults.

[Open the Printune App](https://printune.jongens.nz/) · [Report an Issue](https://github.com/NickJongens/Printune/issues)

## Getting Started

1. Open the [Printune App](https://printune.jongens.nz/) in your browser.
2. Enter the printer, port, and driver details.
3. Review the generated commands and detection settings.
4. Download the completed deployment package.

## Quick Start: Pre-configured Drivers

### Step 1: Printer Details

- **Printer Port IP Address**: IP address or DNS hostname, such as `192.0.2.10`.
- **Printer Port Name**: Descriptive Windows port name, such as `Intune - Office Printer`.
- **Printer Name**: User-facing queue name, such as `Office Printer`.
- **Printer Brand & Model**: Select a model from the available lists.

When a pre-configured model is selected, its driver details are populated automatically.

### Step 2: Review and Download

- Review the generated install and uninstall commands.
- Copy the registry detection settings.
- Select **Download Package**.

The package can include:

- `Install.ps1` — driver, port, queue, and configuration installation.
- `Uninstall.ps1` — printer queue and unused port removal.
- The selected driver ZIP.
- An optional exported printer configuration file.

## Manual Configuration

Use manual configuration when the required printer is not pre-configured or when a different driver package is needed.

### Driver INF

- Enter the INF filename, such as `OEMSETUP.INF`.
- Alternatively, upload an INF to detect the driver models it exposes.
- A relative path such as `64bit\OEMSETUP.INF` can be entered when required.

The installer searches the extracted driver package recursively and prefers driver files beneath `64bit`, `x64`, or `amd64` directories.

### Driver Model Name

Enter the exact driver model name exposed by the INF and registered by Windows, such as:

```text
Vendor Model PCL 6
```

### Driver ZIP

Enter the ZIP filename included with the deployment package, such as:

```text
PrinterDriver.zip
```

## Driver Publisher Trust

Some signed driver packages cannot be installed silently until their catalogue publisher is trusted. For a driver obtained from a manufacturer or another source you trust, append this optional switch to the generated install command:

```text
-TrustDriverPublisher
```

When enabled, the installer:

1. Locates the catalogue declared by the selected INF.
2. Validates its Authenticode signature.
3. Confirms that the signer chains to a trusted root certificate.
4. Adds only that catalogue signer to `LocalMachine\TrustedPublisher`.
5. Stages the driver using Windows `PnPUtil`.

This option does not install unsigned drivers, disable signature validation, or trust unrelated certificates. Do not use it with an untrusted driver package.

## Printer Configuration Export

After installing and testing the printer locally, export the global printer defaults and driver-specific data:

```cmd
rundll32 printui.dll,PrintUIEntry /Ss /n "Office Printer" /a "config.dat" g d
```

The flags export:

- `g` — global printer DEVMODE settings, including defaults such as paper size, colour, and duplex where supported by the driver.
- `d` — printer-specific driver data.

Include `config.dat` in the deployment package and add the following parameter to the install command:

```text
-ConfigFilePath "config.dat"
```

During installation, Printune restores the `g` and `d` settings while retaining the deployed printer name and port. This allows a configuration exported from a test queue to be applied to a differently named production queue.

See the [Config Export Guide](config.md) for further information.

## Example Install Command

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1 `
    -PrinterPortIPAddress "192.0.2.10" `
    -PrinterPortName "Intune - Office Printer" `
    -PrinterName "Office Printer" `
    -PrinterDriverModelName "Vendor Model PCL 6" `
    -PrinterDriverZipFileName "PrinterDriver.zip" `
    -PrinterDriverModelFileName "OEMSETUP.INF" `
    -ConfigFilePath "config.dat"
```

Add `-TrustDriverPublisher` only when the verified driver package requires it.

## Intune Deployment

1. Extract the package downloaded from Printune.
2. Download the [Microsoft Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool).
3. Run `IntuneWinAppUtil.exe`.
4. Select the extracted package directory as the source folder.
5. Select `Install.ps1` as the setup file.
6. Upload the resulting `.intunewin` file as a Windows app (Win32).
7. Install in the **System** context.
8. Configure the generated install, uninstall, and registry detection settings.

To explicitly invoke 64-bit Windows PowerShell from the Intune Management Extension, begin the command with:

```text
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1
```

## Uninstallation

Example:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1 `
    -PrinterName "Office Printer" `
    -PrinterPortName "Intune - Office Printer"
```

The uninstall script removes the requested printer queue. It removes the port only when no other installed printer is using it. Driver packages and trusted publisher certificates are retained because another printer may require them.

## Intune Detection

Use a registry detection rule for the installed printer queue:

| Setting | Value |
|---|---|
| Key path | `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Printers\<PrinterName>` |
| Value name | `Name` |
| Detection method | String comparison |
| Operator | Equals |
| Value | `<PrinterName>` |

## Installer Parameters

| Parameter | Required | Purpose |
|---|---:|---|
| `PrinterPortIPAddress` | Yes | Printer IPv4 address or resolvable hostname. |
| `PrinterPortName` | Yes | Windows Standard TCP/IP port name. |
| `PrinterName` | Yes | User-facing printer queue name. |
| `PrinterDriverModelName` | Yes | Exact driver name registered by Windows. |
| `PrinterDriverZipFileName` | Yes | Driver ZIP included beside `Install.ps1`. |
| `PrinterDriverModelFileName` | Yes | INF filename or relative path within the ZIP. |
| `ConfigFilePath` | No | Exported configuration file applied after queue creation. |
| `TrustDriverPublisher` | No | Validates and trusts the selected package's catalogue signer before staging. |

## Logging and Troubleshooting

Installation logs are written to:

```text
C:\Intune\Printers\<PrinterName>\PrinterSetup.log
```

Uninstallation logs are written to:

```text
C:\Intune\Printers\<PrinterName>\UninstallLog.log
```

For Windows driver-staging failures, also inspect:

```text
C:\Windows\INF\setupapi.dev.log
```

Common errors:

| Error | Meaning or action |
|---|---|
| `0x800F0242` | The signed catalogue publisher is not trusted. Verify the package source before considering `-TrustDriverPublisher`. |
| `0x80070705` | The requested driver is not registered. Check the preceding PnPUtil and SetupAPI errors. |
| Win32 error `87` | An invalid parameter or path was supplied. Confirm the ZIP, INF filename, and exact driver model name. |

The scripts return exit code `1` when an installation or removal action fails. A port still used by another printer is retained and is not treated as an uninstall failure.

## Additional Resources

- [Config Export Guide](config.md)
- [Request a Driver](https://printune.jongens.nz/)
- [GitHub Repository](https://github.com/NickJongens/Printune)
- [Microsoft PrintUIEntry command reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/rundll32-printui)

## Important

Test each new driver and configuration package on a representative Windows device before broad deployment. Printer vendors vary in INF structure, signing, architecture, supporting files, and configuration behaviour.
