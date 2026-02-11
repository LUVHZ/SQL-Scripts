# SQL Server 2025 - Tips & Tricks

## Performance Tuning Tips

### Tip 1: Leverage Intelligent Query Processing
**The Problem**: Complex queries with multiple parameters often have suboptimal execution plans.

**The Solution**: Enable IQP features for automatic plan optimization.

```sql
-- Enable at database level (recommended)
ALTER DATABASE SCOPED CONFIGURATION
SET QUERY_OPTIMIZER_HOTFIXES = ON;

ALTER DATABASE SCOPED CONFIGURATION
SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;

-- Verify status
SELECT name, value
FROM sys.database_scoped_configurations
WHERE name LIKE '%OPTIMIZER%' OR name LIKE '%PARAMETER%';
```

**Impact**: 15-30% improvement on variable parameter workloads

---

### Tip 2: Use Query Store Hints Instead of Code Changes
**The Problem**: You need to change query execution without modifying application code.

**The Solution**: Use Query Store hints to guide the optimizer.

```sql
-- Add a hint via Query Store
EXEC sp_query_store_set_hints
    @query_id = 42,
    @hint_id = 1,
    @query_hint_text = N'OPTION(RECOMPILE, MAXDOP 1)';

-- View existing hints
SELECT query_id, query_hint_text
FROM sys.query_store_query_hints;
```

**Benefit**: Non-invasive performance tuning without application deployment

---

### Tip 3: Optimize Columnstore for Mixed Workloads
**The Problem**: Columnstore indexes can impact OLTP performance.

**The Solution**: Use filtered columnstore or nonclustered columnstore.

```sql
-- Create nonclustered columnstore for analytics
CREATE NONCLUSTERED COLUMNSTORE INDEX ncci_Sales_Orders
ON dbo.Orders (OrderID, OrderDate, Amount, CustomerID)
WHERE OrderDate >= DATEFROMPARTS(YEAR(GETDATE()), 1, 1);

-- With filtered columnstore, OLTP remains on rowstore
SELECT * FROM dbo.Orders WHERE OrderID = 123; -- Uses clustered index
SELECT SUM(Amount) FROM dbo.Orders WHERE YEAR(OrderDate) = 2025; -- Uses columnstore
```

**Impact**: Better analytics performance without OLTP degradation

---

### Tip 4: Implement Incremental Statistics on Large Tables
**The Problem**: Large table statistics updates are slow and resource-intensive.

**The Solution**: Use incremental statistics that update by partition.

```sql
-- Enable incremental statistics
ALTER DATABASE [YourDB]
SET INCREMENTAL_STATISTICS ON;

-- For existing tables
UPDATE STATISTICS dbo.LargeTable
WITH INCREMENTAL = ON, MAXDOP = 8;

-- Monitor incremental statistics
SELECT object_name(object_id) AS TableName,
       name AS StatisticName,
       incremental
FROM sys.stats
WHERE incremental = 1;
```

**Benefit**: 50-70% faster statistics updates on large tables

---

## Security Best Practices

### Tip 5: Implement Always Encrypted for Sensitive Data
**The Problem**: Encrypted columns in transit and at rest but queryable data at rest.

**The Solution**: Use Always Encrypted with column encryption keys.

```sql
-- Create column master key
CREATE COLUMN MASTER KEY MyCMK
WITH (KEY_STORE_PROVIDER_NAME = 'MSSQL_CERTIFICATE_STORE',
      KEY_PATH = 'CurrentUser/My/thumbprint_here');

-- Create column encryption key
CREATE COLUMN ENCRYPTION KEY MyCEK
WITH VALUES (
    COLUMN_MASTER_KEY = MyCMK,
    ALGORITHM = 'RSA_OAEP',
    ENCRYPTED_VALUE = 0x...) -- Generated key value

-- Enable Always Encrypted for connection
-- In connection string: Column Encryption Setting=enabled;
```

**Impact**: Transparent encryption without query changes

---

### Tip 6: Enable Real-Time Threat Detection
**The Problem**: SQL injection and unusual access patterns go undetected.

**The Solution**: Configure Advanced Threat Protection (ATP).

```sql
-- Enable ATP alerts (Azure SQL)
-- Via Azure Portal: Security > Advanced Threat Protection

-- Or via T-SQL for Arc-enabled servers
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'threat detection enabled', 1;
RECONFIGURE;
```

**Benefit**: Proactive threat identification and alerts

---

### Tip 7: Implement Row-Level Security (RLS)
**The Problem**: Users see data they shouldn't have access to.

**The Solution**: Use RLS to filter data at query level.

```sql
-- Create security policy function
CREATE FUNCTION dbo.EmployeeAccessPredicate(@EmployeeDepartmentID INT)
    RETURNS TABLE
    WITH SCHEMABINDING
AS
    RETURN (
        SELECT 1 AS AccessResult
        WHERE @EmployeeDepartmentID = CAST(SESSION_CONTEXT(N'DepartmentID') AS INT)
           OR CAST(SESSION_CONTEXT(N'IsManager') AS BIT) = 1
    );

-- Create security policy
CREATE SECURITY POLICY EmployeeSecurityPolicy
ADD FILTER PREDICATE dbo.EmployeeAccessPredicate(DepartmentID)
ON dbo.Employees;

-- Usage: Set context before query
EXEC sp_set_session_context @key = 'DepartmentID', @value = 5;
```

**Benefit**: Automatic data filtering based on user context

---

## Cloud & Hybrid Tips

### Tip 8: Use Managed Backup for Arc-Enabled Servers
**The Problem**: Manual backup management is error-prone.

**The Solution**: Enable automatic Azure backup for on-premises SQL Server.

```sql
-- Enable managed backup for Arc SQL Server
EXEC msdb.managed_backup.sp_backup_config_basic
    @enable_backup = 1,
    @database_name = 'YourDatabase',
    @storage_account_url = 'https://youraccount.blob.core.windows.net',
    @storage_account_key = 'YourAccessKey',
    @retention_days = 30;

-- Monitor backup job
EXEC msdb.managed_backup.sp_backup_config_info;
```

**Benefit**: Automated backups with Azure storage

---

### Tip 9: Implement Azure Synapse Link for Real-Time Analytics
**The Problem**: High latency between transactional and analytical queries.

**The Solution**: Enable Azure Synapse Link for continuous sync.

```sql
-- Enable Synapse Link in SQL database
ALTER DATABASE [YourDB] SET SYNC_WITH_HUB = ON;

-- Enable table for sync
ALTER TABLE dbo.SalesOrders ENABLE SYNAPSE_LINK;

-- Monitor sync status
SELECT table_name, synapse_link_enabled, last_sync_time
FROM sys.synapse_link_enabled_tables;
```

**Impact**: Sub-second latency for analytical queries

---

### Tip 10: Use Service-Main Arc Integration
**The Problem**: Complex multi-database management across hybrid environments.

**The Solution**: Deploy Arc-enabled SQL Server for unified management.

```sql
-- Register SQL Server with Arc
az sql server-instance create \
    --name MySQL2025Instance \
    --resource-group MyResourceGroup \
    --location eastus

-- View Arc-enabled instances
SELECT @@SERVERNAME, SERVERPROPERTY('ProductVersion') AS Version;
```

**Benefit**: Single pane of glass for hybrid SQL Server management

---

## Developer Tips

### Tip 11: Use JSON Functions for Semi-Structured Data
**The Problem**: Handling complex nested data structures.

**The Solution**: Native JSON support with improved functions.

```sql
-- Modern JSON manipulation in SQL 2025
DECLARE @json NVARCHAR(MAX) = N'{"orders": [{"id": 1, "total": 100}, {"id": 2, "total": 200}]}';

-- Extract values
SELECT JSON_VALUE(@json, '$.orders[0].id') AS OrderID,
       JSON_VALUE(@json, '$.orders[0].total') AS Total;

-- Query arrays
SELECT * FROM OPENJSON(@json, '$.orders')
WITH (id INT '$.id', total DECIMAL '$.total');

-- Build JSON
SELECT JSON_OBJECT(
    'OrderID', 123,
    'Total', 1000,
    'Items', JSON_ARRAY(456, 789)
) AS JsonResult;
```

**Benefit**: Native JSON handling without UDFs

---

### Tip 12: Master Graph Database Queries
**The Problem**: Traversing relationships is complex in traditional relational design.

**The Solution**: Use graph database features for relationship queries.

```sql
-- Create node tables
CREATE TABLE dbo.Person (
    PersonID INT PRIMARY KEY,
    Name NVARCHAR(100)
) AS NODE;

CREATE TABLE dbo.Friends (
    CONSTRAINT [Friends] CONNECTION (Person TO Person)
) AS EDGE;

-- Navigate relationships
SELECT Person1.Name AS Person1,
       Person2.Name AS Person2
FROM Person AS Person1
    JOIN Friends ON Person1.PersonID = Friends.from_id
    JOIN Person AS Person2 ON Friends.to_id = Person2.PersonID;
```

**Benefit**: Elegant relationship queries without complex JOINs

---

## Monitoring & Diagnostics

### Tip 13: Use Extended Events for Deep Diagnostics
**The Problem**: Trace is deprecated and XE is complex.

**The Solution**: Use query templates for common scenarios.

```sql
-- Create XE session for long-running queries
CREATE EVENT SESSION [LongRunningQueries] ON SERVER
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.database_id)
    WHERE duration > 5000000) -- 5 seconds in microseconds
ADD TARGET package0.event_file(SET filename = 'C:\Logs\LongRunning.xel')
WITH (MAX_DISPATCH_LATENCY = 30 SECONDS);

ALTER EVENT SESSION [LongRunningQueries] ON SERVER STATE = START;
```

**Benefit**: Low-overhead activity tracing

---

### Tip 14: Automate Performance Analysis
**The Problem**: Manual performance investigation is time-consuming.

**The Solution**: Create dashboards with SQL Agent jobs.

```sql
-- Daily performance analysis job
CREATE PROCEDURE dbo.sp_DailyPerformanceAnalysis AS
BEGIN
    -- Missing indexes
    SELECT database_id, COUNT(*) AS MissingIndexCount
    FROM sys.dm_db_missing_index_details
    GROUP BY database_id;

    -- Index fragmentation
    SELECT object_name(ips.object_id) AS TableName,
           COUNT(*) AS FragmentedIndexes
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    WHERE ips.avg_fragmentation_in_percent > 10
    GROUP BY ips.object_id;
END;

-- Schedule via SQL Agent job
```

**Benefit**: Automated insights into performance issues

---

### Tip 15: Implement Query Store Cleanup Policy
**The Problem**: Query Store grows unboundedly consuming resources.

**The Solution**: Configure automatic cleanup policies.

```sql
-- Configure Query Store retention
ALTER DATABASE [YourDB] SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    MAX_STORAGE_SIZE_MB = 1000,
    INTERVAL_LENGTH_MINUTES = 10
);

-- Monitor Query Store size
SELECT actual_state, current_storage_size_mb
FROM sys.database_query_store_options;
```

**Benefit**: Controlled Query Store growth

---

## Common Pitfalls to Avoid

### ❌ Don't: Use implicit conversions in WHERE clauses
```sql
-- WRONG - Slows down queries
WHERE CAST(StringColumn AS INT) = 123;
-- RIGHT
WHERE StringColumn = '123';
```

### ❌ Don't: Ignore IQP for existing queries
```sql
-- WRONG - Missing optimization opportunities
-- Just run queries as-is
-- RIGHT
-- Enable IQP and let optimizer improve plans
```

### ❌ Don't: Use SELECT * in production code
```sql
-- WRONG
SELECT * FROM LargeTable;
-- RIGHT
SELECT SpecificColumn1, SpecificColumn2 FROM LargeTable;
```

### ❌ Don't: Skip backup verification
```sql
-- WRONG
-- Take backups without testing restore
-- RIGHT
-- Regularly test restore procedures
RESTORE VERIFYONLY FROM DISK = 'backup.bak';
```

---

*Last Updated: February 2025*
