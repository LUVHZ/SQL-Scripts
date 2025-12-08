/*
    Purpose: Configure and manage SQL Server linked servers for remote database access
    Usage: Create linked server connections, test connectivity, manage security
    Prerequisites: SELECT permission on linked server; appropriate login rights
    Safety Notes: Security risk - verify login credentials are secure; test in dev first
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. CREATE LINKED SERVER (SQL Server)
-- ============================================================================
PRINT '=== LINKED SERVER CONFIGURATION ===';

/*
EXEC master.dbo.sp_addlinkedserver
    @server = N'RemoteSQLServer',
    @srvproduct = N'SQL Server',
    @provider = N'SQLNCLI11',
    @datasrc = N'RemoteServer.domain.com\SQLEXPRESS',
    @catalog = N'master';

-- Set login for linked server
EXEC master.dbo.sp_addlinkedsrvlogin
    @rmtsrvname = N'RemoteSQLServer',
    @useself = N'False',
    @rmtuser = N'sa',
    @rmtpassword = N'StrongPassword123!';
*/

-- ============================================================================
-- 2. CREATE LINKED SERVER (Oracle, MySQL, etc.)
-- ============================================================================
/*
-- Oracle Linked Server
EXEC master.dbo.sp_addlinkedserver
    @server = N'OracleServer',
    @srvproduct = N'Oracle',
    @provider = N'OraOLEDB.Oracle',
    @datasrc = N'OracleServiceName';

EXEC master.dbo.sp_addlinkedsrvlogin
    @rmtsrvname = N'OracleServer',
    @useself = N'False',
    @rmtuser = N'OracleUser',
    @rmtpassword = N'OraclePassword';
*/

-- ============================================================================
-- 3. VIEW LINKED SERVERS
-- ============================================================================
PRINT '=== LINKED SERVERS ===';

SELECT 
    name AS [LinkedServerName],
    product AS [Product],
    provider AS [Provider],
    data_source AS [DataSource],
    location AS [Location],
    provider_string AS [ProviderString],
    catalog AS [DefaultCatalog],
    is_rpc_out_enabled AS [RpcEnabled],
    is_data_access_enabled AS [DataAccessEnabled],
    is_collation_compatible AS [CollationCompatible]
FROM sys.servers
WHERE server_id > 0  -- Exclude local server
ORDER BY name;

-- ============================================================================
-- 4. VIEW LINKED SERVER LOGINS
-- ============================================================================
PRINT '=== LINKED SERVER LOGINS ===';

SELECT 
    lsl.server_id,
    s.name AS [LinkedServerName],
    lsl.local_principal_id,
    lsl.uses_self_credential AS [UsesSelfCredential],
    lsl.remote_name AS [RemoteLoginName]
FROM sys.linked_logins lsl
INNER JOIN sys.servers s 
    ON lsl.server_id = s.server_id
ORDER BY s.name;

-- ============================================================================
-- 5. TEST LINKED SERVER CONNECTION
-- ============================================================================
PRINT '=== TEST LINKED SERVER CONNECTIVITY ===';

/*
-- Test query (uncomment to run)
SELECT TOP 5 * FROM OPENQUERY([RemoteSQLServer], 'SELECT * FROM master..sysobjects');

-- OR using four-part naming
SELECT TOP 5 * FROM [RemoteSQLServer].master.dbo.sysobjects;
*/

-- ============================================================================
-- 6. EXECUTE REMOTE PROCEDURE
-- ============================================================================
/*
EXEC sp_executesql
    @query = N'SELECT @@SERVERNAME AS ServerName',
    @params = N'@server NVARCHAR(128)',
    @server = N'RemoteSQLServer';

-- OR direct execution
EXEC [RemoteSQLServer].master.dbo.sp_who;
*/

-- ============================================================================
-- 7. CONFIGURE LINKED SERVER OPTIONS
-- ============================================================================
PRINT '=== CONFIGURE LINKED SERVER OPTIONS ===';

/*
-- Enable RPC
EXEC master.dbo.sp_serveroption
    @server = N'RemoteSQLServer',
    @optname = N'rpc',
    @optvalue = N'true';

-- Enable RPC out
EXEC master.dbo.sp_serveroption
    @server = N'RemoteSQLServer',
    @optname = N'rpc out',
    @optvalue = N'true';

-- Enable collation compatible
EXEC master.dbo.sp_serveroption
    @server = N'RemoteSQLServer',
    @optname = N'collation compatible',
    @optvalue = N'true';

-- Enable data access
EXEC master.dbo.sp_serveroption
    @server = N'RemoteSQLServer',
    @optname = N'data access',
    @optvalue = N'true';

-- Enable distributed transactions
EXEC master.dbo.sp_serveroption
    @server = N'RemoteSQLServer',
    @optname = N'remote proc transaction promotion',
    @optvalue = N'true';
*/

-- ============================================================================
-- 8. VIEW LINKED SERVER SETTINGS
-- ============================================================================
PRINT '=== LINKED SERVER SETTINGS ===';

SELECT 
    s.name AS [LinkedServer],
    lso.option_name,
    lso.option_value
FROM sys.servers s
LEFT JOIN sys.linked_server_options lso 
    ON s.server_id = lso.server_id
WHERE s.server_id > 0
ORDER BY s.name, lso.option_name;

-- ============================================================================
-- 9. MODIFY LINKED SERVER
-- ============================================================================
/*
EXEC master.dbo.sp_dropserver
    @server = N'RemoteSQLServer',
    @droplogins = 'droplogins';  -- Also drop logins

-- Recreate with new settings
EXEC master.dbo.sp_addlinkedserver
    @server = N'RemoteSQLServer',
    @srvproduct = N'SQL Server',
    @provider = N'SQLNCLI11',
    @datasrc = N'NewServer.domain.com';
*/

-- ============================================================================
-- 10. TROUBLESHOOTING LINKED SERVER ISSUES
-- ============================================================================
PRINT '=== LINKED SERVER TROUBLESHOOTING ===';
PRINT '1. Verify remote server is online and accessible';
PRINT '2. Check login credentials have appropriate permissions';
PRINT '3. Verify firewall allows connection on required port (1433 for SQL Server)';
PRINT '4. Check RPC and RPC Out are enabled if using stored procedures';
PRINT '5. Verify provider is installed on local server';
PRINT '6. Check Event Log for connection errors';
PRINT '7. Use OPENQUERY for complex queries';
PRINT '8. Avoid using SELECT * with four-part naming';
