# This script pings a list of SQL servers to check their activity status

# Define the list of SQL servers
$servers = @("Server1", "Server2", "Server3")

foreach ($server in $servers) {
    $ping = Test-Connection -ComputerName $server -Count 1 -Quiet
    if ($ping) {
        Write-Host "$server is reachable." -ForegroundColor Green
    } else {
        Write-Host "$server is not reachable." -ForegroundColor Red
    }
}