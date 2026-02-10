# This script retrieves host information like CPU and memory usage

# Define the server
$server = "RemoteHost"

# Get CPU and memory information
$cpu = Get-WmiObject -Class Win32_Processor -ComputerName $server | Select-Object -Property Name, LoadPercentage
$memory = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $server | Select-Object -Property TotalVisibleMemorySize, FreePhysicalMemory

Write-Host "CPU Information:" -ForegroundColor Cyan
$cpu
Write-Host "Memory Information:" -ForegroundColor Cyan
$memory