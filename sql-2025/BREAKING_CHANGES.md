# SQL Server 2025 - Breaking Changes & Deprecated Features

## Deprecated Features (Still Supported but Will Be Removed)

### 1. Replication
**Status**: Deprecated in SQL 2025, removed in future versions
**Replacement**: Always On Availability Groups (AG)

```sql
-- DEPRECATED - Check if replication is configured
SELECT * FROM sys.databases
WHERE is_published = 1 OR is_subscribed = 1 OR is_distributor = 1;

-- RECOMMENDED - Use Always On AG instead
ALTER AVAILABILITY GROUP AG_Production
ADD DATABASE [YourDatabase];
```

**Migration Steps**:
1. Identify all replication publications/subscribers
2. Set up Always On AG
3. Migrate data using AG
4. Update applications to use AG listener
5. Decommission replication

---

### 2. Database Mirroring
**Status**: Deprecated in SQL 2022, removed in SQL 2025
**Replacement**: Always On Availability Groups

```sql
-- DEPRECATED - Check for mirroring
SELECT * FROM sys.database_mirroring
WHERE database_id IS NOT NULL AND state IS NOT NULL;

-- RECOMMENDED - Always On AG
CREATE AVAILABILITY GROUP AG_HA
WITH (
    AUTOMATED_BACKUP_PREFERENCE = SECONDARY_ONLY,
    REPLICA_SYNCHRONIZATION_COMMIT_OF = SYNCHRONOUS_COMMIT
);
```

---

### 3. Service Broker
**Status**: Limited support, discouraged for new development
**Replacement**: Azure Service Bus, SignalR

```sql
-- DEPRECATED
CREATE MESSAGE TYPE [SampleMessage] AUTHORIZATION dbo
VALIDATION = WELL_FORMED_XML;

-- RECOMMENDED - Use Azure Service Bus
-- Install-Package Azure.Messaging.ServiceBus
-- var client = new ServiceBusClient("connection-string");
-- var sender = client.CreateSender("queue-name");
```

---

### 4. Polybase v1 (Legacy)
**Status**: Deprecated, superseded by v2
**Replacement**: PolyBase v2

```sql
-- DEPRECATED - Old Polybase syntax
CREATE EXTERNAL DATA SOURCE DeprecatedSource
WITH (
    TYPE = HADOOP,
    LOCATION = 'hdfs://namenode:8020',
    RESOURCE_MANAGER_LOCATION = 'yarn_resource_manager'
);

-- RECOMMENDED - PolyBase v2 with storage integration
CREATE EXTERNAL DATA SOURCE ModernSource
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://youraccount.blob.core.windows.net',
    CREDENTIAL = AzureCredential
);
```

---

## Breaking Changes (Features Removed or Significantly Changed)

### 1. SQL Server Compact Edition (Removed)
**Impact**: Applications using SQL Server Compact cannot migrate directly

```sql
-- DEPRECATED - Not supported
-- SQLCE database files (.sdf)

-- RECOMMENDED - Migrate to SQL Server Express or LocalDB
-- Use Entity Framework Core with SQLite or SQL Server Express
```

**Migration Path**:
- Export SQLCE data
- Migrate to SQL Server LocalDB or Express
- Update connection strings
- Retarget .NET application

---

### 2. Replication Endpoints Changed
**Impact**: Some replication scripts need updates

```sql
-- OLD - Still works but deprecated
EXEC sp_addpublication @publication = 'Pub1';

-- RECOMMENDED - Use T-SQL or use Always On AG
ALTER AVAILABILITY GROUP AG_Prod MODIFY REPLICA ON N'Server1' WITH
    (ENDPOINT_URL = N'TCP://Server1.yourdomain.com:5022',
     FAILOVER_MODE = AUTOMATIC,
     AVAILABILITY_MODE = SYNCHRONOUS_COMMIT);
```

---

### 3. Compatibility Level Changes
**Impact**: Databases at very old compatibility levels may have behavioral changes

```sql
-- Check current compatibility levels
SELECT name, compatibility_level
FROM sys.databases
WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb');

-- Compatibility levels in SQL 2025:
-- 160 = SQL Server 2022
-- 170 = SQL Server 2025 (RECOMMENDED)

-- Minimum supported is 130 (SQL Server 2016)
ALTER DATABASE [OldDB] SET COMPATIBILITY_LEVEL = 160;  -- First upgrade to latest
THEN
ALTER DATABASE [OldDB] SET COMPATIBILITY_LEVEL = 170;  -- Then to SQL 2025
```

**Note**: Direct upgrade from compatibility 110 or below bypasses 2 version jumps

---

### 4. Index Hint Behavior Changes
**Breaking Change**: Some legacy index hints may work differently

```sql
-- OLD - May not work as expected
SELECT * FROM Orders WITH (INDEX = IX_OrderDate)
WHERE OrderDate > '2025-01-01';

-- RECOMMENDED - Use FORCESEEK or FORCESCAN
SELECT * FROM Orders WITH (FORCESEEK (IX_OrderDate (OrderDate)))
WHERE OrderDate > '2025-01-01';

-- Using Query Store hints (preferred in SQL 2025)
-- EXEC sp_query_store_set_hints @query_id = 1,
--     @query_hint_text = N'FORCESEEK (IX_OrderDate)';
```

---

### 5. CLR Integration (Restricted Mode)
**Breaking Change**: CLR code now runs in restricted context by default

```sql
-- OLD - UNSAFE assemblies
CREATE ASSEMBLY MyAssembly FROM 'C:\Assemblies\MyAssembly.dll'
WITH PERMISSION_SET = UNSAFE;

-- NEW - Must use SAFE or EXTERNAL_ACCESS
-- UNSAFE removed in SQL 2025
CREATE ASSEMBLY MyAssembly FROM 'C:\Assemblies\MyAssembly.dll'
WITH PERMISSION_SET = EXTERNAL_ACCESS;

-- Or recompile as SAFE code
```

---

### 6. XP_Cmdshell Changes
**Breaking Change**: Default security context is restricted

```sql
-- NOTE: xp_cmdshell still available but more restricted
-- OLD - Did not require special setup
EXEC xp_cmdshell 'dir C:\';

-- NEW - Requires explicit setup and should avoid if possible
-- Enable advanced options
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

-- Enable xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

-- RECOMMENDED - Use PowerShell or Windows agents instead
-- PowerShell is the preferred automation mechanism
```

---

### 7. Deprecated System Stored Procedures Removed

**Removed procedures** (no longer available):

```sql
-- These will cause errors in SQL 2025:

-- REMOVED
sp_adduser              -- Use CREATE USER instead
sp_addlogin             -- Use CREATE LOGIN instead
sp_addgroup             -- Use CREATE ROLE instead
sp_change_users_login   -- Use ALTER LOGIN ENABLE instead
sp_dropuser             -- Use DROP USER instead
sp_dropgroup            -- Use DROP ROLE instead
sp_droplogin            -- Use DROP LOGIN instead
sp_dropmember           -- Use ALTER ROLE instead
sp_addrolemember        -- Use ALTER ROLE instead
sp_helprole             -- Use sys.roles instead
sp_helpuser             -- Use sys.sysusers instead

-- RECOMMENDED - Use new syntax
-- Old way
sp_adduser 'DOMAIN\User', 'User';
-- New way
CREATE USER [DOMAIN\User] FOR LOGIN [DOMAIN\User];

-- Map to role
ALTER ROLE db_datareader ADD MEMBER [DOMAIN\User];
```

---

### 8. Security Changes - Policy Updates

**Old approach not supported the same way:**

```sql
-- OLD - EKM (External Key Manager) provider requirements changed
-- SQL 2025 requires TDE keys be managed through:
--   - MSSQL_CERTIFICATE_STORE
--   - Windows Key Management Service (KMS)

-- NEW - Simplified approach with Azure Key Vault
-- Remove old EKM provider
-- Use Service Principal or Managed Identity with Azure Key Vault

-- Check if using old EKM
SELECT * FROM sys.cryptographic_providers;
```

---

### 9. Execution Plan Changes

**SQL Server 2025 Optimizer generates different plans**

```sql
-- Your old queries may have different execution plans
-- This could cause performance variations

-- BEST PRACTICE - Baseline before and after migration
-- Recording baseline:
CREATE TABLE BaselineMetrics (
    CaptureDate DATETIME,
    QueryHash BINARY(8),
    AvgElapsedTime BIGINT,
    AvgLogicalReads BIGINT,
    ExecutionCount INT
);

INSERT INTO BaselineMetrics
SELECT
    GETDATE(),
    qs.query_hash,
    AVG(rs.avg_total_user_time),
    AVG(rs.avg_logical_reads),
    COUNT(*)
FROM sys.dm_exec_query_stats qs
    JOIN sys.dm_exec_query_plan(qs.plan_handle) p
    JOIN sys.dm_exec_query_runtime_stats rs ON qs.query_hash = rs.query_hash
GROUP BY qs.query_hash;
```

---

### 10. Feature Pack/Add-on Changes

**Some SQL Server add-ons have changed:**

- **SQL Server Express**: Limited to 1 GB RAM and 10 GB storage
- **SQL Server Standard**: Some Enterprise features now in Standard
- **Reporting Services**: Now primarily web-based
- **Analysis Services**: Azure Analysis Services preferred for cloud

---

## Migration Checklist

Use this checklist when upgrading to SQL 2025:

```sql
-- 1. Identify deprecated features
SELECT features_used FROM (
    SELECT 'Replication' AS features_used FROM sys.databases WHERE is_published = 1
    UNION ALL
    SELECT 'Database Mirroring' FROM sys.database_mirroring WHERE state IS NOT NULL
    UNION ALL
    SELECT 'Service Broker' FROM sys.service_queues
    UNION ALL
    SELECT 'xp_cmdshell' FROM (SELECT 1 WHERE EXISTS (SELECT 1 FROM master.sys.all_objects WHERE name = 'xp_cmdshell'))
) t WHERE features_used IS NOT NULL;

-- 2. Count usage of deprecated procedures
SELECT COUNT(*) AS DeprecatedProcedureCount
FROM sys.dm_exec_cached_plans p
    CROSS APPLY sys.dm_exec_sql_text(p.sql_handle) t
WHERE t.text LIKE '%sp_adduser%'
   OR t.text LIKE '%sp_addlogin%'
   OR t.text LIKE '%sp_addgroup%';

-- 3. Verify compatibility level support
SELECT name, compatibility_level,
       CASE WHEN compatibility_level < 130 THEN 'UPGRADE REQUIRED'
            WHEN compatibility_level < 170 THEN 'CAN UPGRADE'
            ELSE 'OK' END AS UpgradeStatus
FROM sys.databases
WHERE database_id > 4;

-- 4. Check for EKM providers (if using old encryption)
SELECT *
FROM sys.cryptographic_providers
WHERE provider_type_desc NOT LIKE 'MSSQL%';

-- 5. List CLR assemblies (if using CLR)
SELECT name, permission_set_desc
FROM sys.assemblies
WHERE is_user_defined = 1;
```

---

## Performance Considerations with New Features

### Potential Regressions (Monitor After Migration)

1. **Statistics behavior changes**
   - New cardinality estimator may create different estimates
   - Test with `TRACE FLAG 9481` for compatibility mode

2. **Index strategies**
   - New filtered index capabilities may reduce index count
   - Consider reorganizing index strategy

3. **Query Plan Cache**
   - Query Store may show different plan choices
   - Use Query Store hints to override if needed

### Performance Improvements (Expect These)

1. **IQP optimizations** - 10-30% improvement typical
2. **Columnstore enhancements** - 20-50% faster scans
3. **Statistics improvements** - Fewer query regressions
4. **Memory management** - Better memory grant feedback

---

*Last Updated: February 2025*
