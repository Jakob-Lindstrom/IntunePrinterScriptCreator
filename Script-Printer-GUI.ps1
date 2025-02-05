# Script for uploading printer scripts to Intune via winapputil.
#
# A printer driver must be uploaded to intune before using this script.
#
# Add your driver names in DriverNames.json
#
# Jakob Lindstrom 2023-06-17

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)

$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

if ($myWindowsPrincipal.IsInRole($adminRole))
{
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    Clear-Host
}
else
{
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
	$newProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
	$newProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($newProcess);

    Exit
}


# Creating a folder in the same place as the script
New-Item -ItemType Directory -Path "$PSScriptRoot\Printer" -Force

# Global variable to store the printer name and folder name
$global:GlobalPrinterName = ""


# GUI form
$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(400, 460) # Increased height to accommodate the LPR Port
$form.Text = "Intune Printer Script"

# Labels
$label1 = New-Object System.Windows.Forms.Label
$label1.Location = New-Object System.Drawing.Point(50, 50)
$label1.Size = New-Object System.Drawing.Size(100, 20)
$label1.Text = "Printer Name"

$label2 = New-Object System.Windows.Forms.Label
$label2.Location = New-Object System.Drawing.Point(50, 100)
$label2.Size = New-Object System.Drawing.Size(100, 20)
$label2.Text = "IP Address"

$label3 = New-Object System.Windows.Forms.Label
$label3.Location = New-Object System.Drawing.Point(50, 150)
$label3.Size = New-Object System.Drawing.Size(100, 20)
$label3.Text = "LPR Queue"

$label4 = New-Object System.Windows.Forms.Label
$label4.Location = New-Object System.Drawing.Point(50, 200)
$label4.Size = New-Object System.Drawing.Size(100, 20)
$label4.Text = "LPR Port"

$label5 = New-Object System.Windows.Forms.Label
$label5.Location = New-Object System.Drawing.Point(50, 250)
$label5.Size = New-Object System.Drawing.Size(100, 20)
$label5.Text = "Printer Driver"

# Text Boxes
$textBox1 = New-Object System.Windows.Forms.TextBox
$textBox1.Location = New-Object System.Drawing.Point(150, 50)
$textBox1.Size = New-Object System.Drawing.Size(200, 20)

$textBox2 = New-Object System.Windows.Forms.TextBox
$textBox2.Location = New-Object System.Drawing.Point(150, 100)
$textBox2.Size = New-Object System.Drawing.Size(200, 20)

$textBox3 = New-Object System.Windows.Forms.TextBox
$textBox3.Location = New-Object System.Drawing.Point(150, 150)
$textBox3.Size = New-Object System.Drawing.Size(200, 20)

# Combo Box for LPR Port
$lprPortComboBox = New-Object System.Windows.Forms.ComboBox
$lprPortComboBox.Location = New-Object System.Drawing.Point(150, 200)
$lprPortComboBox.Size = New-Object System.Drawing.Size(200, 20)
# Add LPR options (LPR1, LPR2, LPR3, etc.)
1..8 | ForEach-Object { $lprPortComboBox.Items.Add("LPR$_") }

# Combo Box for Printer Driver
$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(150, 250)
$comboBox.Size = New-Object System.Drawing.Size(200, 20)

# Check Boxes
$checkBoxDefault = New-Object System.Windows.Forms.CheckBox
$checkBoxDefault.Location = New-Object System.Drawing.Point(50, 300)
$checkBoxDefault.Size = New-Object System.Drawing.Size(100, 20)
$checkBoxDefault.Text = "Default"

$checkBoxColour = New-Object System.Windows.Forms.CheckBox
$checkBoxColour.Location = New-Object System.Drawing.Point(150, 300)
$checkBoxColour.Size = New-Object System.Drawing.Size(100, 20)
$checkBoxColour.Text = "Colour"

$checkBoxDuplex = New-Object System.Windows.Forms.CheckBox
$checkBoxDuplex.Location = New-Object System.Drawing.Point(260, 300)
$checkBoxDuplex.Size = New-Object System.Drawing.Size(100, 20)
$checkBoxDuplex.Text = "Duplex"

# Load the driver names from the JSON file
$driversJsonPath = "$PSScriptRoot\DriverNames.json" 
$driversData = Get-Content -Raw -Path $driversJsonPath | ConvertFrom-Json
$driverNames = $driversData.drivers

# Add the driver names to the combobox
$driverNames | ForEach-Object {
    $comboBox.Items.Add($_)
}

# Button for PS1 file
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(145, 340)
$button.Size = New-Object System.Drawing.Size(100, 30)
$button.Text = "Create Printer"
$button.Add_Click({
    $in_printerName = $textBox1.Text
    $in_ipAddress = $textBox2.Text
    $in_lprQueue = $textBox3.Text
    $in_printerDriver = $comboBox.SelectedItem
    $in_colour = $checkBoxColour.Checked -eq $true
    $in_duplex = $checkBoxDuplex.Checked -eq $true
	$in_default = $checkBoxDefault.Checked -eq $true
	$selectedLPRPort = $lprPortComboBox.SelectedItem

	# Compute port name and the corresponding Add-PrinterPort command
	if ([string]::IsNullOrWhiteSpace($in_lprQueue)) {
		$portName = "IP_$in_ipAddress"
		$addPortCommand = "Add-PrinterPort -Name `"$portName`" -PrinterHostAddress `"$in_ipAddress`""
	} else {
		$portName = "$selectedLPRPort" + "_" + "$in_ipAddress"
		$addPortCommand = "Add-PrinterPort -Name `"$portName`" -LprQueueName `"$in_lprQueue`" -LprHostAddress `"$in_ipAddress`""
	}

	# Compute the Set-PrintConfiguration command
	if ($in_colour -and $in_duplex) {
		$setPrintConfig = "Set-PrintConfiguration -PrinterName `"$in_printerName`" -DuplexingMode TwoSidedLongEdge -Color `$true"
	} elseif ($in_colour) {
		$setPrintConfig = "Set-PrintConfiguration -PrinterName `"$in_printerName`" -Color `$true"
	} elseif ($in_duplex) {
		$setPrintConfig = "Set-PrintConfiguration -PrinterName `"$in_printerName`" -DuplexingMode TwoSidedLongEdge -Color `$false"
	} else {
		$setPrintConfig = "Set-PrintConfiguration -PrinterName `"$in_printerName`" -Color `$false"
	}


	if ($in_default) {
		$setDefault = 'Get-CimInstance -ClassName Win32_Printer -Filter "Name = ''$printerName''" | Invoke-CimMethod -MethodName SetDefaultPrinter'
	}
	
	



	# Generate PowerShell script
	$script = @"
	# Pre-computed printer installation details
	`$printerName = "$in_printerName"
	`$printerDriver = "$in_printerDriver"
	`$portName = "$portName"

	# Add Printer Port
	`$checkPortExists = Get-PrinterPort -Name `$portName -ErrorAction SilentlyContinue
	if (-not `$checkPortExists) {
		$addPortCommand
	}

	# Install Printer
	Add-Printer -Name `$printerName -DriverName `$printerDriver -PortName `$portName

	# Configure Printer Settings
	$setPrintConfig

	#Default
	$setDefault
"@

# Create the folder
$folderName = "$in_printerName"
New-Item -ItemType Directory -Path "$PSScriptRoot\Printer\$folderName"

# Save the first script to a file inside the folder
$script | Out-File -FilePath "$PSScriptRoot\Printer\$folderName\install-$in_printerName.ps1"

# Create the second PS1 file
$removeScript = @"
Remove-Printer -Name "$in_printerName"
"@

# Save the second script to a file inside the folder
$removeScript | Out-File -FilePath "$PSScriptRoot\Printer\$folderName\uninstall-$in_printerName.ps1"

# Save the printer name and folder name to the global variables
$global:GlobalPrinterName = $in_printerName


# Enable the intuneButton if the necessary conditions are met
    if ($in_printerName -ne "" -and $in_ipAddress -ne "" -and $in_printerDriver -ne $null) {
        $intuneButton.Enabled = $true
    }

})

# Button for executing IntuneWinAppUtil
$intuneButton = New-Object System.Windows.Forms.Button
$intuneButton.Location = New-Object System.Drawing.Point(255, 340)
$intuneButton.Size = New-Object System.Drawing.Size(100, 30)
$intuneButton.Text = "Create intunewin"
$intuneButton.Enabled = $false  # Set the initial state to disabled
$intuneButton.Add_Click({
    # Check if IntuneWinAppUtil.exe exists in the current directory
    $intuneWinAppPath = Join-Path $PSScriptRoot "IntuneWinAppUtil.exe"
    if (-not (Test-Path -Path $intuneWinAppPath -PathType Leaf)) {
        $result = [System.Windows.Forms.MessageBox]::Show("IntuneWinAppUtil.exe not found. Do you want to download it?", "Download IntuneWinAppUtil.exe", [System.Windows.Forms.MessageBoxButtons]::YesNo)
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Download IntuneWinAppUtil.exe from the GitHub URL
            $downloadUrl = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $intuneWinAppPath)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Cannot proceed without IntuneWinAppUtil.exe.", "Download Canceled", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            Exit
        }
    }

    # After IntuneWinAppUtil.exe is confirmed or downloaded, proceed with the intunewin creation
    $currentFolderPath = $PSScriptRoot
    $printerFolderPath = Join-Path $currentFolderPath "Printer"
    $folderFullPath = Join-Path $printerFolderPath $global:GlobalPrinterName
    
    $setupFile = "$folderFullPath\install-$($global:GlobalPrinterName).ps1"
    $Arguments = "-q -c ""$folderFullPath"" -s ""$setupFile"" -o ""$folderFullPath"""
    
    try {
        Start-Process -FilePath $intuneWinAppPath -ArgumentList $Arguments
        $configFilePath = Join-Path $folderFullPath "settings-$($global:GlobalPrinterName).txt"
        $configContents = @"
Intune Configuration:

App information:
IntuneWinFileName: $($global:GlobalPrinterName).intunewin
PrinterName: $($global:GlobalPrinterName)
Add Description:
Publisher:
Category: Printers
Logo: Add transparent picture of the printer model

Program:
Installation Settings: powershell.exe -ExecutionPolicy Bypass -file "install-$($global:GlobalPrinterName).ps1"
Uninstall Settings: powershell.exe -ExecutionPolicy Bypass -file "uninstall-$($global:GlobalPrinterName).ps1"

Detection Rule: 
Rule type: Registry 
Key path: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Printers\$($global:GlobalPrinterName)
Detection Method: Key exists

Dependencies:
Add your already uploaded driver to intune
Automatically install: Yes

Supersedence: Set supersedence if this printer is replacing an old printer with a new name.
"@
        $configContents | Out-File -FilePath $configFilePath
    } catch {
        Write-Host "Error occurred: $_"
    }
})


# Add elements to the form
$form.Controls.Add($label1)
$form.Controls.Add($label2)
$form.Controls.Add($label3)
$form.Controls.Add($label4)
$form.Controls.Add($label5)
$form.Controls.Add($textBox1)
$form.Controls.Add($textBox2)
$form.Controls.Add($textBox3)
$form.Controls.Add($lprPortComboBox)
$form.Controls.Add($comboBox)
$form.Controls.Add($checkBoxDefault)
$form.Controls.Add($checkBoxColour)
$form.Controls.Add($checkBoxDuplex)
$form.Controls.Add($button)
$form.Controls.Add($intuneButton)

# Show the form
$form.ShowDialog()
