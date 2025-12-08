/*
    Purpose: Collect comprehensive SQL Server configuration and environment information
    Usage: Run for baseline documentation and troubleshooting
    Prerequisites: VIEW SERVER STATE permission; sysadmin for some details
    Safety Notes: Read-only diagnostic; safe to run during normal operations
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. SQL SERVER INSTANCE INFORMATION
-- ============================================================================
PRINT '=== SQL SERVER INSTANCE INFORMATION ===';

SELECT 
    SERVERPROPERTY('ServerName') AS [ServerName],
    SERVERPROPERTY('ProductVersion') AS [ProductVersion],
    SERVERPROPERTY('Edition') AS [Edition],
    SERVERPROPERTY('EngineEdition') AS [EngineEdition],
    CASE SERVERPROPERTY('EngineEdition')
        WHEN 1 THEN 'Personal'
        WHEN 2 THEN 'Standard'
        WHEN 3 THEN 'Enterprise'
        WHEN 4 THEN 'Express'
        WHEN 5 THEN 'Azure SQL Database'
        WHEN 6 THEN 'Azure SQL Managed Instance'
        WHEN 8 THEN 'Azure SQL Database Edge'
        ELSE 'Unknown'
    END AS [EditionDesc],
    SERVERPROPERTY('MachineName') AS [MachineName],
    SERVERPROPERTY('InstanceName') AS [InstanceName],
    SERVERPROPERTY('ResourceLastUpdateDateTime') AS [ResourceLastUpdate],
    CAST(SERVERPROPERTY('BuildClusterEnabled') AS BIT) AS [IsClusteredInstance];

-- ============================================================================
-- 2. SQL SERVER CONFIGURATION OPTIONS
-- ============================================================================
PRINT '=== SQL SERVER CONFIGURATION ===';

SELECT 
    name,
    value,
    value_in_use AS [CurrentValue],
    description
FROM sys.configurations
ORDER BY name;

-- ============================================================================
-- 3. MEMORY CONFIGURATION
-- ============================================================================
PRINT '=== MEMORY CONFIGURATION ===';

SELECT 
    'Max Server Memory (MB)' AS [Configuration],
    CAST(c.value AS VARCHAR(20)) AS [ConfiguredValue],
    'See sys.configurations' AS [Notes]
FROM sys.configurations c
WHERE c.name = 'max server memory (MB)'

UNION ALL

SELECT 
    'Min Server Memory (MB)',
    CAST(c.value AS VARCHAR(20)),
    'See sys.configurations'
FROM sys.configurations c
WHERE c.name = 'min server memory (MB)';

-- Physical memory available
SELECT 
    'Total System Memory (MB)' AS [Configuration],
    CAST(CAST(si.physical_memory_in_bytes AS DECIMAL(18,2)) / 1024 / 1024 AS VARCHAR(20)) AS [Value],
    'Physical memory available to Windows' AS [Notes]
FROM sys.dm_os_sys_info si;

-- ============================================================================
-- 4. DATABASE LIST AND SIZE
-- ============================================================================
PRINT '=== DATABASE INVENTORY ===';

SELECT 
    d.name AS [DatabaseName],
    d.state_desc AS [State],
    d.recovery_model_desc AS [RecoveryModel],
    d.is_read_only AS [IsReadOnly],
    d.create_date AS [Created],
    CAST((SUM(mf.size) * 8.0) / 1024 AS DECIMAL(10,2)) AS [SizeMB]
FROM sys.databases d
LEFT JOIN sys.master_files mf 
    ON d.database_id = mf.database_id
GROUP BY d.name, d.state_desc, d.recovery_model_desc, d.is_read_only, d.create_date
ORDER BY d.name;

-- ============================================================================
-- 5. SQL SERVER SERVICES STATUS
-- ============================================================================
PRINT '=== SQL SERVER SERVICES ===';

SELECT 
    SERVERPROPERTY('ServerName') AS [Instance],
    'SQL Server Database Engine' AS [Service],
    CASE SERVERPROPERTY('ProductVersion') 
        WHEN '16.0.4000.0' THEN 'SQL Server 2022'
        WHEN '15.0.2000.0' THEN 'SQL Server 2019'
        WHEN '14.0.3000.0' THEN 'SQL Server 2017'
        WHEN '13.0.1000.0' THEN 'SQL Server 2016'
        ELSE 'Version ' + SERVERPROPERTY('ProductVersion')
    END AS [Version],
    'Check Services.msc for SQL Server Agent, Full Text Search, etc.' AS [Note];

-- ============================================================================
-- 6. TRACE FLAGS ENABLED
-- ============================================================================
PRINT '=== ACTIVE TRACE FLAGS ===';

DBCC TRACESTATUS (-1);

-- ============================================================================
-- 7. STARTUP PARAMETERS
-- ============================================================================
PRINT '=== STARTUP PARAMETERS ===';
PRINT 'Check Registry: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\[Instance]\MSSQLServer';
PRINT 'Look for SqlArg0, SqlArg1, etc. for startup flags';

-- ============================================================================
-- 8. SYSTEM CPU AND OS INFORMATION
-- ============================================================================
PRINT '=== SYSTEM RESOURCES ===';

SELECT 
    'CPU Count' AS [Configuration],
    CAST(cpu_count AS VARCHAR(10)) AS [Value],
    'Logical CPUs visible to SQL Server' AS [Notes]
FROM sys.dm_os_sys_info

UNION ALL

SELECT 
    'Server Start Time',
    CONVERT(VARCHAR(23), sqlserver_start_time, 121),
    'Last time SQL Server was restarted'
FROM sys.dm_os_sys_info

UNION ALL

SELECT 
    'Scheduler Count',
    CAST(scheduler_count AS VARCHAR(10)),
    'Number of active schedulers'
FROM sys.dm_os_sys_info;

-- ============================================================================
-- 9. SQL AGENT STATUS (if available)
-- ============================================================================
PRINT '=== SQL AGENT JOBS ===';

SELECT 
    'Check SQL Server Agent for job history'
    FROM (SELECT 1) AS t;
