	# Pre-computed printer installation details
	$printerName = "Test-Printer"
	$printerDriver = "HP Universal Printing PCL 6"
	$portName = "IP_192.168.0.10"

	# Add Printer Port
	$checkPortExists = Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue
	if (-not $checkPortExists) {
		Add-PrinterPort -Name "IP_192.168.0.10" -PrinterHostAddress "192.168.0.10"
	}

	# Install Printer
	Add-Printer -Name $printerName -DriverName $printerDriver -PortName $portName

	# Configure Printer Settings
	Set-PrintConfiguration -PrinterName "Test-Printer" -DuplexingMode TwoSidedLongEdge -Color $true
