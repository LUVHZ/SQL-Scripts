# This script checks if SQL services are running on a remote host

# Define the server
$server = "RemoteHost"

# Check SQL services
$services = Get-Service -ComputerName $server | Where-Object { $_.DisplayName -like "*SQL*" }

foreach ($service in $services) {
    Write-Host "Service: $($service.DisplayName) - Status: $($service.Status)" -ForegroundColor Yellow
}