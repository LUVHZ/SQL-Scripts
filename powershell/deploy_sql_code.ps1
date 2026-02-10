# This script deploys SQL code to a remote SQL server

# Define the server and script details
$server = "RemoteSQLServer"
$database = "TargetDatabase"
$sqlScriptPath = "C:\Path\To\Your\Script.sql"

# Deploy the SQL script
Invoke-Sqlcmd -ServerInstance $server -Database $database -InputFile $sqlScriptPath
Write-Host "SQL script deployed to $server on database $database." -ForegroundColor Green