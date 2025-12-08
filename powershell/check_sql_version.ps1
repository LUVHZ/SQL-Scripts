# This script checks the SQL Server version on a remote host

# Define the server
$server = "RemoteSQLServer"

# Check SQL Server version
$sqlVersion = Invoke-Sqlcmd -ServerInstance $server -Query "SELECT @@VERSION AS Version"
Write-Host "SQL Server Version on $server:" -ForegroundColor Cyan
$sqlVersion