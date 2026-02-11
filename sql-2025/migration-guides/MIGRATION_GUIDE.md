# SQL Server 2025 - Migration Guide

## Pre-Migration Assessment

### Step 1: Inventory Current Environment

```sql
-- Collect server information
SELECT
    @@SERVERNAME AS ServerName,
    @@VERSION AS Version,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductLevel') AS ServicePack,
    SERVERPROPERTY('EngineEdition') AS EngineEdition;

-- List all databases
SELECT name, state_desc, compatibility_level, recovery_model
FROM sys.databases
ORDER BY name;

-- Check total size
SELECT SUM(CONVERT(BIGINT, size)) * 8 / 1024 / 1024 AS TotalSizeGB
FROM sys.master_files;
```

### Step 2: Identify Breaking Changes

```sql
-- Check for deprecated features in use
SELECT name, reference_count, GETDATE() AS CheckDate
FROM sys.dm_exec_cached_plans p
CROSS APPLY sys.dm_exec_sql_text(p.sql_handle) t
WHERE t.text LIKE '%sp_adduser%' -- Check for deprecated procedures
   OR t.text LIKE '%sp_addlogin%'
   OR t.text LIKE '%sp_change_users_login%'
UNION ALL
-- Check replication usage
SELECT 'Replication' AS Feature, COUNT(*) AS Reference, GETDATE()
FROM sys.databases
WHERE is_published = 1 OR is_subscribed = 1 OR is_distributor = 1
GROUP BY name;
```

## Migration Planning

### Phase 1: Pre-Migration (2-4 weeks)

**Tasks:**
1. ✅ Take complete backup of all databases
2. ✅ Document current baseline performance metrics
3. ✅ Identify all deprecated features being used
4. ✅ Test SQL Server 2025 compatibility in lab environment
5. ✅ Plan rollback procedures
6. ✅ Communicate with stakeholders

```sql
-- Backup all databases
-- Run on SQL Server 2019/2022 before migration
EXEC sp_MSForEachDB '
    IF ''?'' NOT IN (''master'', ''model'', ''msdb'', ''tempdb'')
    BEGIN
        BACKUP DATABASE [?]
        TO DISK = ''C:\Backups\PreMigration_[?]_'' +
                  CONVERT(NVARCHAR(20), GETDATE(), 121) + ''.bak''
        WITH COMPRESSION, CHECKSUM;
    END
';
```

### Phase 2: Staging Environment Testing (2-3 weeks)

**In a test environment that mirrors production:**

```sql
-- 1. Restore databases from backup
RESTORE DATABASE [ProductionDB]
FROM DISK = 'C:\Backups\PreMigration_ProductionDB_*.bak'
WITH REPLACE, RECOVERY;

-- 2. Update compatibility level (graduil approach)
ALTER DATABASE [ProductionDB] SET COMPATIBILITY_LEVEL = 160; -- SQL 2022
-- Test thoroughly
ALTER DATABASE [ProductionDB] SET COMPATIBILITY_LEVEL = 170; -- SQL 2025

-- 3. Run compatibility checker
EXEC sp_validatecompilations;

-- 4. Performance baseline testing
DECLARE @StartTime DATETIME = GETDATE();
-- Run representative workload
-- SELECT INTO ... FROM LargeTable ...
-- Measure execution time
SELECT DATEDIFF(SECOND, @StartTime, GETDATE()) AS ElapsedSeconds;

-- 5. Check for query regressions
SELECT query_id, COUNT(*) AS ExecutionCount
FROM sys.query_store_query_text qt
INNER JOIN sys.query_store_runtime_stats rs ON qt.query_id = rs.query_id
WHERE rs.execution_type_desc = 'Aborted'
GROUP BY query_id;
```

### Phase 3: Production Migration

#### Option A: In-Place Upgrade (Recommended for Small Instances)
- **Downtime**: Yes (2-6 hours)
- **Effort**: Low
- **Risk**: Medium

```powershell
# Stop all applications
# Stop SQL Server
net stop MSSQLSERVER

# Run SQL Server 2025 Setup
# Setup.exe /Action=Install /UpdateSource=...\Updates\
# Follow wizard

# Start SQL Server
net start MSSQLSERVER

# Verify upgrade completion
sqlcmd -S . -Q "SELECT SERVERPROPERTY('ProductVersion')"
```

#### Option B: Side-by-Side Migration (Recommended for Large/Critical Systems)
- **Downtime**: Minimal (minutes)
- **Effort**: High
- **Risk**: Low

```sql
-- On SQL Server 2025 instance:

-- 1. Restore all databases
RESTORE DATABASE [ProductionDB]
FROM DISK = 'Z:\Backups\ProductionDB.bak'
WITH REPLACE, RECOVERY;

-- 2. Update compatibility level gradually
ALTER DATABASE [ProductionDB] SET COMPATIBILITY_LEVEL = 170;

-- 3. Create replication/sync if needed
EXEC sp_adddistributor @distributor = 'NewServer2025';

-- 4. Migrate logins
EXEC sp_help_revlogin @login_name = NULL; -- Generate script
-- Execute generated login scripts
```

#### Option C: Cloud Migration (Azure SQL Migration Service)
- **Downtime**: Minimal
- **Effort**: Medium
- **Risk**: Low

```powershell
# Use Azure Data Migration Service
$client = New-AzDataMigrationClient
Start-AzDataMigrationTask -ServiceName "MigrationService" `
    -ProjectName "SQLProject" `
    -TaskName "SQLMigration"
```

## Migration Steps

### Step 1: Pre-Migration Checks

```sql
-- Verify prerequisites
SELECT
    CASE WHEN @@VERSION LIKE '%2016%' OR @@VERSION LIKE '%2017%'
         THEN 'Must upgrade to 2019+ first'
         ELSE 'OK - Direct upgrade possible' END AS UpgradeReadiness,
    db_name() AS Database,
    COUNT(*) AS TotalObjects
FROM sys.all_objects;

-- Check for schema issues
DBCC CHECKDB (N'ProductionDB', REPAIR_ALLOW_DATA_LOSS);

-- Verify backup
RESTORE HEADERONLY FROM DISK = 'C:\Backups\ProductionDB.bak';
```

### Step 2: Install SQL Server 2025

**Installation on Windows:**
```batch
# Mount SQL Server 2025 ISO
# Run Setup.exe
# Choose: Installation > New SQL Server Stand-alone Installation
# Leave default paths
# Choose Mixed Authentication Mode
# Add current user as SA
# Configure SQL Server Agent for Automatic Startup
# Enable TCP/IP in Network Configuration
# Complete installation
```

**Installation on Linux:**
```bash
# Add Microsoft repository
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2025.list |
  sudo tee /etc/apt/sources.list.d/mssql-server-2025.list

# Install SQL Server 2025
sudo apt-get update
sudo apt-get install -y mssql-server

# Run setup
sudo /opt/mssql/bin/mssql-conf setup

# Verify installation
systemctl status mssql-server
```

### Step 3: Restore Databases

```sql
-- Restore with REPLACE to overwrite any existing databases
RESTORE DATABASE [ProductionDB]
FROM DISK = 'C:\Backups\PreMigration_ProductionDB_*.bak'
WITH
    RECOVERY,
    REPLACE,
    STATS = 10;  -- Show progress every 10%

-- Wait for restore completion
WHILE (SELECT state_desc FROM sys.databases WHERE name = 'ProductionDB') <> 'ONLINE'
BEGIN
    WAITFOR DELAY '00:00:05';
    SELECT 'Restoring...', state_desc FROM sys.databases WHERE name = 'ProductionDB';
END;

SELECT 'Restore completed', recovery_model_desc, state_desc
FROM sys.databases
WHERE name = 'ProductionDB';
```

### Step 4: Update Compatibility Levels

```sql
-- Check current compatibility
SELECT name, compatibility_level
FROM sys.databases
WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb')
ORDER BY name;

-- Gradually migrate (recommended: 1 per day)
-- Day 1: Non-critical databases
ALTER DATABASE [TestDB] SET COMPATIBILITY_LEVEL = 170;

-- Day 2: Secondary databases
ALTER DATABASE [ReportingDB] SET COMPATIBILITY_LEVEL = 170;

-- Day 3: Production database (after validation)
ALTER DATABASE [ProductionDB] SET COMPATIBILITY_LEVEL = 170;
```

### Step 5: Migrate Logins and Permissions

```sql
-- Generate login scripts from SQL Server 2022/2019
-- Run this on OLD server:
CREATE PROCEDURE sp_help_revlogin @login_name sysname = NULL AS
DECLARE @name SYSNAME, @xstatus INT, @binpwd VARBINARY (256), @txtpwd SYSNAME, @tmpstr VARCHAR (256), @SID_varbinary VARBINARY (85), @SID_string VARCHAR(512), @IsntName INT

IF (@login_name IS NULL)
  DECLARE login_curs CURSOR FOR
  SELECT loginname FROM master.dbo.syslogins WHERE (loginname <> 'sa') AND (loginname <> 'NT AUTHORITY\SYSTEM')
ELSE
  DECLARE login_curs CURSOR FOR
  SELECT loginname FROM master.dbo.syslogins WHERE loginname = @login_name

OPEN login_curs

FETCH NEXT FROM login_curs INTO @name

WHILE (@@fetch_status = 0)
BEGIN
  SELECT @xstatus = xstatus, @binpwd = password FROM master.dbo.syslogins WHERE loginname = @name

  IF (@xstatus & 4) = 4
  BEGIN
    IF (@xstatus & 1) = 1
      SELECT @IsntName = 1
    ELSE
      SELECT @IsntName = 0
  END
  ELSE
  BEGIN
    SELECT @IsntName = 0
  END

  IF @IsntName = 1
  BEGIN
    SELECT @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) + ' FROM WINDOWS'
  END
  ELSE
  BEGIN
    SELECT @SID_varbinary = CONVERT( VARBINARY(85), SUBSTRING( @binpwd, 5, 16 ) )
    SELECT @SID_string = '0x'
    SELECT @tmpstr = ''
    SELECT @i = 0
    WHILE (@i <= DATALENGTH( @SID_varbinary ) - 1)
    BEGIN
      SELECT @tmpstr = (@tmpstr + SUBSTRING( master.dbo.fn_varbintohexstr( SUBSTRING( @SID_varbinary, @i + 1, 1 ) ), 3, 2 ))
      SELECT @i = @i + 1
    END
    SELECT @tmpstr = 'CREATE LOGIN ' + QUOTENAME( @name ) + ' WITH PASSWORD = ' + QUOTENAME( @tmpstr, '''''' ) + ' HASHED, SID = ' + @tmpstr
  END

  PRINT @tmpstr

  FETCH NEXT FROM login_curs INTO @name
END

CLOSE login_curs
DEALLOCATE login_curs

RETURN (0)

GO

-- Execute on old server
EXEC sp_help_revlogin

-- Copy output and execute on SQL 2025 server
```

### Step 6: Validate Data Integrity

```sql
-- Check database integrity
DBCC CHECKDB (N'ProductionDB') WITH NO_INFOMSGS;

-- Verify row counts
SELECT name, OBJECT_NAME(id) AS TableName, CONVERT(VARCHAR(20), SUM(rows)) AS RowCount
FROM sys.sysindexes
WHERE indid <= 1 AND name NOT IN ('dtproperties')
GROUP BY name, OBJECT_NAME(id)
ORDER BY OBJECT_NAME(id);

-- Check replication status if applicable
SELECT * FROM sys.dm_repl_publisher_monitor_threshold;

-- Verify job status
SELECT job_id, name, enabled FROM msdb.dbo.sysjobs;
```

### Step 7: Update Statistics

```sql
-- Update all statistics for optimal query plans
EXEC sp_MSForEachDB '
    IF ''?'' NOT IN (''master'', ''model'', ''msdb'')
    BEGIN
        USE [?];
        UPDATE STATISTICS (FULLSCAN);
    END
';

-- Verify completion
SELECT DB_NAME(ps.database_id) AS DatabaseName,
       OBJECT_NAME(ps.object_id, ps.database_id) AS TableName,
       ps.stats_date AS LastStatisticsUpdate
FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) ps
ORDER BY ps.stats_date DESC;
```

## Post-Migration Tasks

### 1. Application Testing (Critical)
```
- Test all critical business processes
- Verify report accuracy
- Validate API responses
- Check batch job performance
- Monitor for errors in application logs
```

### 2. Performance Baseline

```sql
-- Record new baseline
CREATE TABLE dbo.BaselineMetrics_SQL2025 (
    MetricDate DATETIME DEFAULT GETDATE(),
    MetricName NVARCHAR(100),
    MetricValue FLOAT,
    Unit NVARCHAR(50)
);

INSERT INTO dbo.BaselineMetrics_SQL2025
SELECT
    GETDATE(),
    'CPU Utilization %',
    AVG(100.0 - mex.avg_idle_time),
    '%'
FROM sys.dm_os_performance_counters mex
WHERE counter_name = 'CPU usage %';

-- Compare with pre-migration baseline
SELECT 'Pre-Migration' AS Period,
       AVG(MetricValue) AS AvgValue
FROM dbo.BaselineMetrics_SQL2022
WHERE MetricName = 'CPU Utilization %'
UNION ALL
SELECT 'Post-Migration',
       AVG(MetricValue)
FROM dbo.BaselineMetrics_SQL2025
WHERE MetricName = 'CPU Utilization %';
```

### 3. Cleanup

```sql
-- Enable new SQL 2025 features
ALTER DATABASE SCOPED CONFIGURATION
SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;

-- Disable legacy trace flags if any
DBCC TRACESTATUS (Global);

-- Archive old backups (keep 30 days)
-- (Use SQL Agent or PowerShell task)

-- Document changes
INSERT INTO dbo.MigrationLog
VALUES (GETDATE(), 'SQL Server 2025 Migration Completed', GETUSER());
```

## Rollback Procedure (If Needed)

```sql
-- If issues occur, restore from backup
RESTORE DATABASE [ProductionDB]
FROM DISK = 'C:\Backups\PreMigration_ProductionDB_*.bak'
WITH RECOVERY, REPLACE;

-- Verify restore
SELECT state_desc FROM sys.databases WHERE name = 'ProductionDB';

-- Notify team of rollback
-- Document issues for root cause analysis
```

## Common Migration Issues & Solutions

| Issue | Symptom | Solution |
|-------|---------|----------|
| Replication failing | Agent errors | Use Always On AG instead |
| Query performance degraded | Slow queries post-upgrade | Enable IQP and update statistics |
| Login failures | Cannot connect | Re-run login migration script |
| Permission errors | Access denied errors | Check object ownership and permissions |
| Memory errors | Out of memory exceptions | Review index strategies, consider nonclustered columnstore |

## Rollback Contingency Plan

**If critical issues occur:**
1. Notify stakeholders immediately
2. Stop all applications
3. Restore from pre-migration backup
4. Investigate root cause
5. Address issues in test environment
6. Schedule new migration attempt

---

*Last Updated: February 2025*
