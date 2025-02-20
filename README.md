# Printune: Intune Printer Deployment Toolkit

## Introduction
Printune is a web-based toolkit designed to streamline the process of deploying printers using Intune. Developed to address the frustrations of inconsistent printer setups, this tool guides you through each step of configuring and deploying printers within your organisation. This README provides detailed instructions on filling out each field in the app.

## Getting Started
1. Open the [Printune App](https://printune.jongens.nz) in your web browser.
2. Follow the steps provided to enter your printer and driver details.

## Section 1: Printer Details
This section collects the basic information about your printer deployment. You will need to fill out the following fields:

### Printer Port IP Address
Enter the IP address where the printer is accessible (for example, `10.195.100.200`). 

***This could also be a DNS hostname***

### Printer Port Name
Provide a descriptive name for the printer port. A common convention might be `"Intune Deployed - Company - 10.195.100.200"`.

### Printer Name
Input a user-friendly name for the printer (for example, `"Upstairs Printer"`). 

***This is what the user will see when they print.***

This name is used in the deployment scripts and detection registry instructions.

Once these fields are complete, click the **"Next"** button to proceed.

## Section 2: Driver Details
This section allows you to specify details about the printer driver. It is divided into two main parts:

### Driver File
- **Manual Input**: You can directly type the driver file name (e.g., `"BROHL17A.INF"`).
- **Upload .inf File**: Alternatively, upload the `.inf` file. The app will auto-detect printer models from the file. 

### Driver Model Name
- **Manual Input**: Enter the driver model name (for example, `"Brother HL-L2350DW series"`). *This is what's shown in the Advanced tab in the printer settings within  Windows*
- **Select Model from INF**: If you have uploaded an INF file, any detected models will appear in a drop-down list. Select the appropriate model from the list. *Not all driver files will auto-detect.*

Use the **"Previous"** and **"Next"** navigation buttons at the bottom of the section to move between steps.

## Section 3: Driver & Config Settings
This final section requires additional deployment details:

### Printer Driver ZIP File Name (Required)
Enter the name of the ZIP file that contains the printer driver. This field is essential, and there are a few drivers pre-loaded that can automatically be added to the package. *If you'd like a driver added - please open an issue in the repo*

### Config File Path (Optional)
Specify the path to a configuration file if applicable (for example, `"config.dat"`). These can contain Paper size, Duplex/Colour settings and can be exported from a pre-configured printer using the **config.dat** export [Command.](https://github.com/NickJongens/Printune/config.md)

### Command Previews
Based on your entries, the app generates commands for both installing and uninstalling the printer. These commands are shown with syntax highlighting. Use the provided copy buttons to easily copy the commands and add these to your Intune Win32 App.

### Detection Registry Instructions
A registry detection method is generated showing the registry key path, value name, detection method, operator, and value used to detect the printer. I have found detection scripts to introduce the most inconsistencies in deployment.

## Download Package
After filling in all required fields, click the **"Download Package"** button to generate a deployment package. This package includes:

- `Install.ps1`: PowerShell script for installing the printer.
- `Uninstall.ps1`: PowerShell script for removing the printer.
- The selected Printer Driver ZIP file (if provided).
- Adding a config to be added into this zip is not supported as of yet.

## Section 4: Preparing for Intune Deployment
Once you have generated the `PrinterDeploymentPackage.zip` file, you will need to extract and repackage it for deployment using the official **IntuneWinAppUtil**.

### Steps to Prepare for Deployment:
1. Extract the contents of `PrinterDeploymentPackage.zip` to a folder. e.g. `C:\Temp`
2. Download and install the [Microsoft Win32 Content Prep Tool (IntuneWinAppUtil)](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management).
3. Run `IntuneWinAppUtil.exe` and follow the prompts:
   - **Source folder**: The extracted package folder.
   - **Setup file**: Select `Install.ps1`.
   - **Output folder**: Choose a destination where the `.intunewin` file will be saved. e.g. `C:\Temp\Output`
4. Once generated, upload the `.intunewin` package to Intune and configure the app settings with the generated install/uninstall command and registry detection.

This process is currently manual, but an upcoming feature is planned to automate this frustrating step.
