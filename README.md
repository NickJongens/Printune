# Printune: Intune Printer Deployment Toolkit

A web-based toolkit that streamlines printer deployment via Intune, eliminating inconsistent configurations and manual setup challenges.

## Getting Started

1. Open the [Printune App](https://printune.jongens.nz) in your web browser
2. Follow the guided steps to configure your printer deployment

## Quick Start: Using Pre-configured Drivers

### Step 1: Printer Details
- **Printer Port IP Address**: IP address or DNS hostname (e.g., `10.195.100.200`)
- **Printer Port Name**: Descriptive port name (e.g., `"Intune Deployed - Company - 10.195.100.200"`)
- **Printer Name**: User-friendly name that appears when printing (e.g., `"Upstairs Printer"`)
- **Printer Brand & Model**: Select from the dropdown lists

Click **"Next"** - if brand/model are selected, you'll skip directly to Step 3.

### Step 2: Driver Details (Auto-populated)
When a brand/model is selected, driver details are automatically populated. You can still modify them if needed.

### Step 3: Review & Download
- Review the generated PowerShell commands (Install/Uninstall)
- Copy the detection registry instructions
- Click **"Download Package"** to generate your deployment package

The package includes:
- `Install.ps1` - Installation script
- `Uninstall.ps1` - Removal script
- Driver ZIP file (if selected)

---

## Manual Configuration

If your printer isn't in the pre-configured list, or you need custom settings:

### Step 1: Printer Details
Fill in the same fields as above, but leave **Printer Brand** as `--Select Brand--` or choose **"Manual"**.

### Step 2: Driver Details (Manual Entry)

#### Driver File
- **Manual Input**: Type the driver INF filename (e.g., `BROHL17A.INF`)
- **Upload .inf**: Upload the INF file to auto-detect available models

#### Driver Model Name
- **Manual Input**: Enter the exact model name as shown in Windows printer settings (Advanced tab)
- **Select from INF**: Choose from models detected in uploaded INF file

#### Driver ZIP File
- **Manual Input**: Enter just the ZIP filename (e.g., `HP_GENERIC.zip`) - the `Driver/` path is handled automatically
- **Select Driver ZIP**: Choose from pre-loaded driver packages

### Step 3: Config Export (Optional)
After testing a local printer installation, export the configuration:
- Enter a config filename (e.g., `config.dat`)
- Copy the generated command and run it on a test machine
- The config file will contain paper size, duplex, and color settings

### Step 4: Review & Download
Same as Quick Start above.

---

## Intune Deployment

1. Extract the downloaded `<PrinterName>.zip` to a folder (e.g., `C:\Temp`)
2. Download the [Microsoft Win32 Content Prep Tool](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management)
3. Run `IntuneWinAppUtil.exe`:
   - **Source folder**: Your extracted package folder
   - **Setup file**: `Install.ps1`
   - **Output folder**: Destination for the `.intunewin` file
4. Upload the `.intunewin` package to Intune
5. Configure the app with the generated install/uninstall commands and registry detection method

---

## Additional Resources

- [Config Export Guide](config.md) - Detailed instructions for exporting printer configurations
- [Request a Driver](https://printune.jongens.nz) - Don't see your printer? Request it via the About tab
- [GitHub Repository](https://github.com/NickJongens/Printune) - Report issues or contribute
