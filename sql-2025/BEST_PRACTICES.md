# SQL Server Best Practices Guide

## Complete Guide for All Versions with SQL Server 2025 Focus

---

## Table of Contents

1. [General Best Practices (All Versions)](#general-best-practices)
2. [SQL Server 2025 Specific Best Practices](#sql-server-2025-best-practices)
3. [Data Tools Tricks for SQL Server 2025](#data-tools-tricks)
4. [Architecture & Design](#architecture--design)
5. [Performance Optimization](#performance-optimization)
6. [Security](#security)
7. [Maintenance & Monitoring](#maintenance--monitoring)
8. [Development Standards](#development-standards)
9. [Disaster Recovery & High Availability](#disaster-recovery--high-availability)
10. [Cloud & Hybrid Integration](#cloud--hybrid-integration)

---

## General Best Practices

### ✅ Always Apply These Regardless of Version

#### 1. Backup Strategy

```sql
-- Best practice: Implement 3-2-1 backup strategy
-- 3 copies of data, 2 different media, 1 offsite

-- Full backup weekly
BACKUP DATABASE [ProductionDB]
TO DISK = '\\BackupServer\Backups\ProductionDB_Full.bak'
WITH
    COMPRESSION,
    CHECKSUM,
    COPY_ONLY;  -- Doesn't reset differential chain

-- Differential backup daily
BACKUP DATABASE [ProductionDB]
TO DISK = '\\BackupServer\Backups\ProductionDB_Diff.bak'
WITH
    DIFFERENTIAL,
    COMPRESSION,
    CHECKSUM;

-- Transaction log backup every 15 minutes
BACKUP LOG [ProductionDB]
TO DISK = '\\BackupServer\Backups\ProductionDB_Log.bak'
WITH
    COMPRESSION,
    CHECKSUM;

-- Verify backups regularly
RESTORE VERIFYONLY FROM DISK = '\\BackupServer\Backups\ProductionDB_Full.bak';

-- Schedule SQL Agent jobs for automated backups
-- Test restore procedures quarterly
```

#### 2. Regular Maintenance Tasks

```sql
-- Weekly: Update statistics
EXEC sp_MSForEachDB '
    IF ''?'' NOT IN (''master'', ''model'', ''msdb'')
    BEGIN
        USE [?];
        UPDATE STATISTICS (FULLSCAN);
    END
';

-- Weekly: Rebuild fragmented indexes
DECLARE @FragmentedIndexes TABLE (
    TableName NVARCHAR(128),
    IndexName NVARCHAR(128),
    Fragmentation FLOAT
);

INSERT INTO @FragmentedIndexes
SELECT
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent AS Fragmentation
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id
        AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
    AND ips.page_count > 1000;

-- Rebuild or reorganize based on fragmentation
DECLARE @SQL NVARCHAR(MAX);
SELECT @SQL = STRING_AGG(
    CASE
        WHEN Fragmentation > 30
        THEN 'ALTER INDEX [' + IndexName + '] ON [' + TableName + '] REBUILD;'
        ELSE 'ALTER INDEX [' + IndexName + '] ON [' + TableName + '] REORGANIZE;'
    END,
    ' '
)
FROM @FragmentedIndexes;

EXEC sp_executesql @SQL;

-- Weekly: Check database integrity
DBCC CHECKDB (N'ProductionDB') WITH NO_INFOMSGS;

-- Monthly: Review SQL logs for errors
EXEC sp_readerrorlog;
```

#### 3. Security - Apply to All Versions

```sql
-- ✅ Use strong passwords for sa account
-- Change default sa password immediately after installation
ALTER LOGIN sa WITH PASSWORD = 'Complex$Password123!@#';
ALTER LOGIN sa DISABLE;  -- Disable if not needed

-- ✅ Use Windows Authentication when possible
CREATE LOGIN [DOMAIN\ServiceAccount] FROM WINDOWS;
CREATE USER [DOMAIN\ServiceAccount];
ALTER ROLE db_datareader ADD MEMBER [DOMAIN\ServiceAccount];

-- ✅ Principle of Least Privilege
CREATE ROLE ApplicationRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Orders TO ApplicationRole;
GRANT EXECUTE ON sp_ProcessOrders TO ApplicationRole;
-- DO NOT grant db_owner to application user

-- ✅ Enable audit logging
AUDIT SERVER
ADD (DATABASE_OBJECT_ACCESS, SUCCESSFUL_LOGIN_GROUP);

-- ✅ Encrypt sensitive data
-- SQL 2016+: Always Encrypted
-- SQL 2019+: Transparent Data Encryption (TDE)

-- ✅ Restrict xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;

-- ✅ Monitor failed logins
SELECT TOP 20
    login_name,
    COUNT(*) AS FailedAttempts,
    MAX(login_time) AS LastAttempt
FROM sys.dm_exec_sessions
GROUP BY login_name
ORDER BY COUNT(*) DESC;
```

#### 4. Naming Conventions (All Versions)

```sql
-- ✅ Use consistent naming conventions
-- SCHEMA.ObjectName format

-- Tables: [dbo].[TableName] (PascalCase, no spaces)
CREATE TABLE dbo.CustomerOrders (...);

-- Columns: PascalCase, descriptive names
CREATE TABLE dbo.Customers (
    CustomerID INT,
    FirstName NVARCHAR(50),
    EmailAddress NVARCHAR(100),
    CreatedDate DATETIME,
    IsActive BIT
);

-- Stored Procedures: [dbo].[sp_ActionObject]
CREATE PROCEDURE dbo.sp_GetCustomerOrders (@CustomerID INT) AS ...
CREATE PROCEDURE dbo.sp_InsertNewOrder (@OrderData ...) AS ...

-- Functions: [dbo].[fn_DescriptiveName]
CREATE FUNCTION dbo.fn_CalculateOrderTotal (@OrderID INT) ...

-- Indexes: [IX_TableName_ColumnName]
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
CREATE UNIQUE CLUSTERED INDEX UX_Customers_Email ON dbo.Customers(EmailAddress);

-- Primary Keys: [PK_TableName]
-- Foreign Keys: [FK_TableName_ReferencedTable]
-- Unique Constraints: [UQ_TableName_ColumnName]
-- Check Constraints: [CK_TableName_Condition]

ALTER TABLE dbo.Orders
ADD CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers(CustomerID),
    CONSTRAINT CK_Orders_Amount CHECK (Amount > 0);
```

#### 5. Database Design Standards

```sql
-- ✅ Use appropriate data types
-- Avoid: SELECT * or using nvarchar for everything
-- Do:
CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,           -- INT for identity
    ProductName NVARCHAR(255) NOT NULL,                -- NVARCHAR for text
    UnitPrice DECIMAL(10,2) NOT NULL,                  -- DECIMAL for money
    Quantity INT NOT NULL CHECK (Quantity >= 0),       -- INT for count
    IsActive BIT DEFAULT 1,                            -- BIT for boolean
    CreatedDate DATETIME DEFAULT GETDATE(),            -- DATETIME for timestamps
    LastModified DATETIME DEFAULT GETDATE(),
    RowVersion ROWVERSION                              -- For optimistic locking
);

-- ✅ Implement proper relationships
CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    TotalAmount DECIMAL(10,2) NOT NULL,
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ✅ Use sensible defaults
-- - GETDATE() for creation dates
-- - 1 for active status
-- - NULL for optional fields (not empty strings)

-- ✅ Avoid NULL abuse
-- Use NOT NULL where possible
-- Reserve NULL for truly optional data
```

---

## SQL Server 2025 Best Practices

### 🚀 Leverage New Features

#### 1. Enable IQP Features Immediately

```sql
-- This is THE most important change from prior versions
-- These should be enabled on EVERY SQL 2025 database

ALTER DATABASE SCOPED CONFIGURATION
SET QUERY_OPTIMIZER_HOTFIXES = ON;

ALTER DATABASE SCOPED CONFIGURATION
SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;

ALTER DATABASE SCOPED CONFIGURATION
SET INTERLEAVED_EXECUTION_TVF = ON;

ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_ADAPTIVE_JOINS = ON;

ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = ON;

-- Verify all are enabled
SELECT name, value_for_primary
FROM sys.database_scoped_configurations
WHERE name LIKE '%OPTIMIZER%' OR name LIKE '%PARAMETER%' OR name LIKE '%BATCH%'
ORDER BY name;

-- ✅ Best Practice: Enable by default during database creation
CREATE DATABASE NewProductionDB
WITH COMPATIBILITY_LEVEL = 170;

ALTER DATABASE NewProductionDB
SET QUERY_OPTIMIZER_HOTFIXES = ON;
```

#### 2. Use Query Store Hints Instead of Code Changes

```sql
-- ✅ BEST PRACTICE: Use hints via Query Store
-- This avoids changing application code

-- Identify problematic query
SELECT query_id, query_hash
FROM sys.query_store_query q
    INNER JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
WHERE rs.avg_cpu_time > 1000000  -- > 1 second
ORDER BY rs.avg_cpu_time DESC;

-- Apply hint without changing code
EXEC sp_query_store_set_hints
    @query_id = 42,
    @query_hint_text = N'OPTION(RECOMPILE, MAXDOP 1)';

-- Monitor effectiveness
SELECT
    q.query_id,
    rs.avg_cpu_time AS AvgCPUTimeAfterHint,
    qsh.query_hint_text
FROM sys.query_store_query q
    INNER JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
    INNER JOIN sys.query_store_plan_forcing_locations qsh ON q.query_id = qsh.query_id
WHERE qsh.query_hint_text IS NOT NULL
ORDER BY rs.avg_cpu_time DESC;

-- ✅ Best Practice for Production:
-- 1. Identify slow query
-- 2. Test hint in Query Store
-- 3. Monitor for 24 hours
-- 4. Apply permanently if proven
-- 5. Never modify app code for performance tuning
```

#### 3. Implement Incremental Statistics on Large Tables

```sql
-- ✅ SQL 2025 Best Practice: Incremental statistics
-- Large partitioned tables benefit 50-70% faster updates

ALTER DATABASE CURRENT SET INCREMENTAL_STATISTICS ON;

-- For existing large tables
UPDATE STATISTICS dbo.LargeOrdersTable
WITH INCREMENTAL = ON, MAXDOP = 8;

-- Verify incremental is enabled
SELECT
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatisticName,
    s.incremental,
    sp.partition_number,
    sp.last_updated
FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.incremental = 1
ORDER BY OBJECT_NAME(s.object_id);

-- ✅ Best Practice: Monitor statistics age
SELECT
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatisticName,
    sp.last_updated,
    DATEDIFF(DAY, sp.last_updated, GETDATE()) AS DaysSinceUpdate
FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE DATEDIFF(DAY, sp.last_updated, GETDATE()) > 7
ORDER BY DATEDIFF(DAY, sp.last_updated, GETDATE()) DESC;
```

#### 4. Use Nonclustered Columnstore for Analytics

```sql
-- ✅ SQL 2025 Best Practice: Hybrid approach
-- Columnstore for analytics, rowstore for OLTP

-- Create nonclustered columnstore on analytical columns only
CREATE NONCLUSTERED COLUMNSTORE INDEX ncci_SalesAnalytics
ON dbo.Orders (OrderID, OrderDate, CustomerID, TotalAmount, Status, ProductID)
WHERE OrderDate >= DATEFROMPARTS(YEAR(GETDATE()) - 2, 1, 1)
WITH (MAXDOP = 8);

-- OLTP queries use clustered index (fast inserts)
SELECT OrderID, OrderDate, TotalAmount
FROM dbo.Orders
WHERE OrderID = 12345;  -- Uses CI, fast

-- Analytics queries use columnstore
SELECT
    YEAR(OrderDate) AS OrderYear,
    COUNT(*) AS OrderCount,
    SUM(TotalAmount) AS TotalRevenue
FROM dbo.Orders
WHERE OrderDate >= '2024-01-01'
GROUP BY YEAR(OrderDate);  -- Uses columnstore, 20-50x faster

-- Monitor columnstore efficiency
SELECT
    OBJECT_NAME(ics.object_id) AS TableName,
    ics.name AS IndexName,
    ps.row_group_count,
    CAST(100.0 * ps.deleted_rows / NULLIF(ps.total_rows, 0) AS DECIMAL(5,2)) AS DeletedRowPercentage
FROM sys.indexes ics
    OUTER APPLY sys.dm_db_column_store_row_group_physical_stats(ics.object_id, ics.index_id) ps
WHERE ps.deleted_rows > ps.total_rows * 0.1;  -- Show fragmented groups
```

#### 5. Optimize with Memory Grant Feedback

```sql
-- ✅ SQL 2025 Best Practice: Enable memory grant feedback
ALTER DATABASE SCOPED CONFIGURATION
SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = ON;

-- Monitor memory grant effectiveness
SELECT TOP 20
    qs.execution_count,
    CASE
        WHEN qs.total_rows > qs.last_rows THEN 'Over-granted'
        WHEN qs.total_rows < qs.last_rows * 0.8 THEN 'Under-granted'
        ELSE 'Optimized'
    END AS MemoryStatus,
    CAST(qs.total_rows AS FLOAT) / NULLIF(qs.last_rows, 0) AS EfficiencyRatio,
    SUBSTRING(qt.query_sql_text, 1, 80) AS QueryStart
FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qs.last_rows > 0
ORDER BY CAST(qs.total_rows AS FLOAT) / NULLIF(qs.last_rows, 1) DESC;

-- ✅ Best Practice: Use EXCEPTION pattern
-- This allows memory grant feedback to learn and adapt
CREATE PROCEDURE dbo.sp_OptimizedQuery
    @CustomerID INT
WITH RECOMPILE  -- Allow recompile for memory feedback
AS
BEGIN
    SELECT TOP 1000
        o.OrderID,
        o.TotalAmount,
        od.ProductID,
        od.Quantity
    FROM dbo.Orders o
        INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
        LEFT JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
    WHERE o.CustomerID = @CustomerID
    ORDER BY o.OrderDate DESC;
END;
```

#### 6. Leverage Vector Data for AI Integration

```sql
-- ✅ SQL 2025 NEW: Vector data types for AI embeddings
-- Store and search embeddings for AI models

-- Create table with vector column
CREATE TABLE dbo.ProductEmbeddings (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(255),
    Description NVARCHAR(MAX),
    Category NVARCHAR(100),
    -- Vector column: 1536 dimensions for OpenAI embeddings
    -- Embedding VECTOR(1536)
    CreatedDate DATETIME DEFAULT GETDATE()
);

-- Best Practice: Similarity search pattern
-- SELECT TOP 10
--     ProductID,
--     ProductName,
--     VECTOR_DISTANCE('cosine', @queryVector, Embedding) AS SimilarityScore
-- FROM dbo.ProductEmbeddings
-- ORDER BY SimilarityScore DESC;

-- ✅ Best Practice: Index vectors for performance
-- CREATE INDEX IX_ProductEmbeddings_Vector ON dbo.ProductEmbeddings
--     USING VECTOR_INDEX (Embedding);
```

#### 7. Use Always Encrypted for Regulated Data

```sql
-- ✅ SQL 2025 Best Practice: Enable Always Encrypted
-- For healthcare, financial, PII data

-- Step 1: Create Column Master Key (do this once)
-- This should be stored securely in Azure Key Vault, not in database

-- Step 2: Create Column Encryption Key
-- CREATE COLUMN ENCRYPTION KEY CEK_Finance
-- WITH VALUES (
--     COLUMN_MASTER_KEY = CMK_Finance,
--     ALGORITHM = 'RSA_OAEP',
--     ENCRYPTED_VALUE = ...);

-- Step 3: Create encrypted table
CREATE TABLE dbo.EmployeeBenefits (
    EmployeeID INT PRIMARY KEY,
    EmployeeName NVARCHAR(100) NOT NULL,
    -- Deterministic: Can be used in WHERE clause, but less secure
    SSN NVARCHAR(11) ENCRYPTED WITH (
        ENCRYPTION_TYPE = DETERMINISTIC,
        ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        -- COLUMN_ENCRYPTION_KEY = CEK_Finance
    ),
    -- Randomized: Cannot use in WHERE, more secure
    CreditCardNumber NVARCHAR(20) ENCRYPTED WITH (
        ENCRYPTION_TYPE = RANDOMIZED,
        ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        -- COLUMN_ENCRYPTION_KEY = CEK_Finance
    ),
    BankAccountNumber NVARCHAR(30) ENCRYPTED WITH (
        ENCRYPTION_TYPE = RANDOMIZED,
        ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256'
        -- COLUMN_ENCRYPTION_KEY = CEK_Finance
    )
);

-- ✅ Best Practice: Use in application connection
-- Connection string: "Column Encryption Setting=enabled;"
-- Application automatically handles encryption/decryption

-- ✅ Best Practice: Still use TDE for database-level encryption
-- Always Encrypted handles column-level
-- TDE handles file-level
```

---

## Data Tools Tricks for SQL Server 2025

### 🛠️ SQL Server Management Studio (SSMS) 20.x+

#### Trick 1: Use Query Plan Analysis Dashboard

```sql
-- ✅ TRICK: Right-click execution plan → "Analyze Actual Plan"
-- SSMS 20.x shows automated recommendations for:
-- - Missing indexes
-- - Query inefficiencies
-- - Statistics issues

-- Look for green checkmarks (OK) vs red X (problems)
SELECT TOP 100
    o.OrderID,
    c.CustomerName,
    o.TotalAmount,
    o.OrderDate
FROM dbo.Orders o
    INNER JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
    LEFT JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
WHERE o.OrderDate > '2025-01-01'
    AND c.CreditLimit > 10000
ORDER BY o.OrderDate DESC;

-- SSMS will suggest: "Add index on Orders.OrderDate"
```

#### Trick 2: Activity Monitor - Real-Time Performance

```
✅ TRICK: Use Activity Monitor for real-time diagnostics
Step 1: Right-click database → Activity Monitor
Step 2: View:
  - CPU usage by process
  - Blocking queries
  - File I/O statistics
  - Memory consumption

Best for: Finding slow processes NOW, not in history
No coding required!
```

#### Trick 3: Execution Plan Comparison

```
✅ TRICK: Compare plans to find regressions
Step 1: Run query (capture Actual Plan)
Step 2: Change parameter or hint
Step 3: Run again (capture new Actual Plan)
Step 4: Right-click first plan → "Compare Showplan"
Step 5: SSMS highlights differences in green/red
```

#### Trick 4: Query Store Visual Reports

```
✅ TRICK: Use Query Store GUI instead of writing queries
Step 1: Database → Query Store → Open Reports
Step 2: Select report:
  - "Overall Resource Consumption" - Top CPU queries
  - "Tracked Queries" - Find regressions
  - "Query Forced Plans" - See what hints you've applied
  - "Implementation Execution Plan Regression" - Auto-detect regressions

Visual and interactive - no SQL required!
```

#### Trick 5: Statistics Details Window

```
✅ TRICK: SSMS shows statistics age in GUI
Step 1: Expand database → Statistics
Step 2: Right-click any statistic → Properties
Step 3: See:
  - Last updated date
  - Update count
  - Sample percentage
  - Density information

Color coding: Red = needs update, Green = fresh
```

#### Trick 6: Showplan XML Analysis

```sql
-- ✅ TRICK: Extract execution plan issues programmatically
-- Save actual plan as .sqlplan file, then:

SELECT
    query_plan.value('@StatementText', 'NVARCHAR(MAX)') AS Query,
    query_plan.value('@CompileTime', 'NVARCHAR(10)') AS CompileTimeMS,
    query_plan.value('@CompileMemory', 'INT') AS CompileMemoryKB,
    RelOp.value('@NodeId', 'INT') AS OperatorID,
    RelOp.value('@PhysicalOp', 'NVARCHAR(50)') AS Operator,
    RelOp.value('@EstimatedRows', 'FLOAT') AS EstimatedRows,
    RelOp.value('@ActualRows', 'BIGINT') AS ActualRows
FROM sys.dm_exec_cached_plans p
    CROSS APPLY sys.dm_exec_query_plan(p.plan_handle) qp
    CROSS APPLY qp.query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS stmt(query_plan)
    CROSS APPLY stmt.query_plan.nodes('./QueryPlan/RelOp') AS op(RelOp)
WHERE p.dbid = DB_ID();

-- Parse XML to find:
-- - EstimatedRows vs ActualRows mismatch
-- - Spills to tempdb
-- - Sort operations (usually expensive)
```

#### Trick 7: Batch SQL Scripts with Comments for Organization

```sql
-- ✅ TRICK: Use GO and comments for organized scripts
-- SSMS will let you quickly navigate with Ctrl+K, Ctrl+C

-- ==================================================
-- 1. STATISTICS UPDATE SECTION
-- ==================================================

UPDATE STATISTICS dbo.Orders;

GO  -- Batch separator - executes previous statements

-- ==================================================
-- 2. INDEX MAINTENANCE SECTION
-- ==================================================

ALTER INDEX ALL ON dbo.Orders REBUILD;

GO

-- ==================================================
-- 3. QUERY STORE CLEANUP SECTION
-- ==================================================

EXEC sp_query_store_set_hints @query_id = 1, @query_hint_text = N'OPTION(RECOMPILE)';

GO

-- TRICK: Ctrl+Shift+M to outline these sections
```

### 🎯 SQL Server Data Tools (SSDT) 2025

#### Trick 1: Pre-Deployment & Post-Deployment Scripts

```xml
<!-- ✅ TRICK: Use SSDT to automate schema + data migrations -->
<!-- In SSDT project, add scripts/ folder -->

<!-- Pre-deployment: DisableConstraints.sql -->
ALTER TABLE dbo.Orders NOCHECK CONSTRAINT ALL;

<!-- Post-deployment: EnableConstraints.sql -->
ALTER TABLE dbo.Orders CHECK CONSTRAINT ALL;
```

#### Trick 2: Refactoring Tools

```
✅ TRICK: SSDT refactoring without manual risk
Step 1: Right-click column → Refactor → Rename
Step 2: SSDT finds ALL references across all scripts
Step 3: Rename happens everywhere automatically
Step 4: Version control tracks changes
Step 5: Deploy with confidence

Applies to:
- Tables
- Columns
- Stored procedures
- Functions
- Parameters
```

#### Trick 3: Schema Comparison

```
✅ TRICK: Compare two databases to find schema drift
Step 1: Tools → SQL Server → New Schema Comparison
Step 2: Select Source DB and Target DB
Step 3: SSDT shows:
  - Missing tables
  - Extra columns not in source
  - Constraint differences
  - Permission differences

Step 4: Generate script to fix target
```

#### Trick 4: Data Comparison

```
✅ TRICK: Find data differences between environments
Step 1: SQL Server → New Data Comparison
Step 2: Compare Production vs Staging
Step 3: See exactly which rows differ
Step 4: Generate update scripts to sync
Step 5: Safe way to test data migrations
```

#### Trick 5: Solution Configuration for Environments

```xml
<!-- ✅ TRICK: One SSDT project, deploy to multiple environments -->
<!-- Properties → Database Settings → Environment Specific -->

<!-- Debug.sqlproj (Development) -->
<DatabaseVariableReplacements>
  <DatabaseVariable name="BackupPath">C:\DevBackups</DatabaseVariable>
  <DatabaseVariable name="RetentionDays">7</DatabaseVariable>
</DatabaseVariableReplacements>

<!-- Staging.sqlproj (Staging) -->
<DatabaseVariable name="BackupPath">\\StagingBackupServer\Backups</DatabaseVariable>
<DatabaseVariable name="RetentionDays">30</DatabaseVariable>

<!-- Production.sqlproj (Production) -->
<DatabaseVariable name="BackupPath">\\ProductionBackupServer\Backups</DatabaseVariable>
<DatabaseVariable name="RetentionDays">365</DatabaseVariable>

<!-- In scripts use: $(BackupPath) and $(RetentionDays) -->
```

### 📊 Azure Data Studio (2025 Cross-Platform)

#### Trick 1: Notebooks for Documentation

```sql
-- ✅ TRICK: Create SQL notebooks that mix code + markdown
-- File → New Notebook (or .ipynb)

-- # Performance Analysis Report
-- Generated: 2025-02-10

-- ## CPU-Intensive Queries

SELECT TOP 10
    q.query_id,
    SUM(rs.sum_cpu_time) AS TotalCPUTime,
    COUNT(*) AS ExecutionCount
FROM sys.query_store_query q
    INNER JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
GROUP BY q.query_id
ORDER BY SUM(rs.sum_cpu_time) DESC;

-- ## Recommendations
-- 1. Add index on Orders.OrderDate
-- 2. Update statistics on Customers table
-- 3. Consider columnstore for historical data
```

#### Trick 2: KQL Extensions for Analytics

```sql
-- ✅ TRICK: Install KQL (Kusto Query Language) extension
-- Use to query:
-- - Azure SQL Database
-- - Azure Data Explorer
-- - Azure Monitor logs

-- Query: Failed login attempts
AuditLogs
| where OperationName == "Login" and Result == "Failure"
| summarize Count = count() by User, bin(TimeGenerated, 1h)
| order by Count desc
```

#### Trick 3: Jupyter Integration

```python
# ✅ TRICK: Mix Python + SQL queries in notebooks
import pandas as pd
import pyodbc

# Connect to SQL Server
conn = pyodbc.connect('Driver={ODBC Driver 17 for SQL Server};'
                     'Server=myserver;Database=mydb;'
                     'Trusted_Connection=yes;')

# Run SQL query
query = "SELECT * FROM dbo.Orders WHERE OrderDate > '2025-01-01'"
df = pd.read_sql(query, conn)

# Analyze in Python
print(f"Total orders: {len(df)}")
print(df['TotalAmount'].describe())

# Visualize
import matplotlib.pyplot as plt
df.groupby('OrderDate')['TotalAmount'].sum().plot()
plt.show()
```

#### Trick 4: Connection Configuration Snippets

```
✅ TRICK: Save connection templates in ADS
File → Preferences → Settings
Create connection profiles for:
- Local dev
- Dev server
- Staging
- Production

Quick switch with Ctrl+Shift+P → "Connect to..."
```

### 🔧 Query Store GUI Tricks

#### Trick 1: Identify Top Resource Consumers

```
✅ TRICK: Use Query Store Built-in Reports
Database → Query Store → Reports → Overall Resource Consumption

Shows:
- Top 10 CPU-consuming queries
- Top 10 I/O intensive queries
- Top 10 memory-consuming queries
- Top 10 duration queries

Click any query → See:
- Execution plans
- Execution history
- All variations of that query
```

#### Trick 2: Auto-Regression Detection

```
✅ TRICK: Query Store automatically flags regressions
Database → Query Store → Reports → Regressed Queries

Green bars = good performance
Red bars = degraded performance (recently got slower)

Compare to:
- Different parameter values
- Different time periods
- Different execution contexts
```

#### Trick 3: Plan Forcing GUI

```
✅ TRICK: Force specific plan without writing code
Step 1: Database → Query Store → Tracked Queries
Step 2: Right-click query → "Force Plan"
Step 3: Select which plan version to use
Step 4: ADS tracks forcing effectiveness
Step 5: Unforce if needed (red X button)
```

---

## Architecture & Design

### ✅ Design Patterns for SQL 2025

#### 1. Microservices Database Pattern

```sql
-- ✅ SQL 2025 Best Practice: Separate database per service
-- Each microservice has its own database for independence

-- OrderService database
CREATE DATABASE OrderDB;

CREATE TABLE dbo.Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT,  -- External reference only
    OrderTotal DECIMAL(10,2)
);

-- Don't create FK to CustomerDB
-- Instead: Validate CustomerID exists via API call

-- CustomerService database
CREATE DATABASE CustomerDB;

CREATE TABLE dbo.Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName NVARCHAR(255),
    Email NVARCHAR(255)
);

-- ✅ Best Practice: Use service-to-service APIs
-- Not cross-database foreign keys
-- Ensures services can scale independently

-- Communication pattern:
-- OrderService → REST API → CustomerService to validate customer
-- Not: OrderService.dbo.Orders.CustomerID → FK → CustomerService
```

#### 2. Event Sourcing with Query Store

```sql
-- ✅ SQL 2025: Use Query Store for audit trail
-- Every query execution is tracked

-- Create audit table for business events
CREATE TABLE dbo.OrderEvents (
    EventID BIGINT IDENTITY(1,1) PRIMARY KEY,
    EventType NVARCHAR(50),  -- Created, Updated, Cancelled, Shipped
    OrderID INT,
    EventData NVARCHAR(MAX),  -- JSON payload
    EventTimestamp DATETIME DEFAULT GETDATE(),
    ChangedBy NVARCHAR(255)
);

-- Store events as JSON
INSERT INTO dbo.OrderEvents (EventType, OrderID, EventData, ChangedBy)
VALUES (
    'OrderCreated',
    123,
    JSON_OBJECT(
        'CustomerID', 456,
        'TotalAmount', 1000.50,
        'Items', JSON_ARRAY(1, 2, 3)
    ),
    SYSTEM_USER
);

-- Query with JSON functions (SQL 2025 features)
SELECT
    EventID,
    EventType,
    JSON_VALUE(EventData, '$.TotalAmount') AS Amount,
    JSON_ARRAY_LENGTH(EventData, '$.Items') AS ItemCount
FROM dbo.OrderEvents
WHERE EventType = 'OrderCreated';
```

#### 3. CQRS (Command Query Responsibility Segregation)

```sql
-- ✅ SQL 2025: Separate read/write databases
-- Write to main database (with all constraints)
-- Read from replicated read-only database (optimized)

-- Main database: OLTP (normalized, all constraints)
CREATE DATABASE SQLSalesOLTP;

-- Replica database: OLAP (denormalized, pre-aggregated)
CREATE DATABASE SQLSalesOLAP;

-- Sync via Always On AG or Transactional Replication
CREATE AVAILABILITY GROUP AG_Sales WITH (
    AUTOMATED_BACKUP_PREFERENCE = SECONDARY_ONLY,
    REPLICA_SYNCHRONIZATION_COMMIT_OF = SYNCHRONOUS_COMMIT
);

-- ✅ Best Practice: Application routing
-- Writes → OLTP database (consistency critical)
-- Reads → OLAP database (eventual consistency OK)
-- Reporting queries → OLAP only
-- Transactional queries → OLTP only
```

---

## Performance Optimization

### ✅ SQL 2025 Performance Best Practices

#### 1. Query Optimization Strategy

```sql
-- ✅ Benchmark → Profile → Optimize → Validate cycle

-- Step 1: Baseline
CREATE TABLE dbo.PerformanceBaseline (
    CaptureDate DATETIME,
    QueryHash BINARY(8),
    AvgCPUTime BIGINT,
    AvgElapsedTime BIGINT,
    ExecutionCount INT
);

INSERT INTO dbo.PerformanceBaseline
SELECT
    GETDATE(),
    qs.query_hash,
    AVG(qs.total_cpu_time),
    AVG(qs.total_elapsed_time),
    COUNT(*)
FROM sys.dm_exec_query_stats qs
GROUP BY qs.query_hash;

-- Step 2: Profile slow queries
SELECT TOP 10
    qt.query_sql_text,
    qs.execution_count,
    qs.total_cpu_time / qs.execution_count AS AvgCPUTime,
    qs.total_elapsed_time / qs.execution_count AS AvgElapsedTime,
    qs.total_logical_reads / qs.execution_count AS AvgLogicalReads
FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY qs.total_cpu_time DESC;

-- Step 3: Optimize (add index, update stats, use hints, etc.)
-- Step 4: Compare with baseline
-- Step 5: Validate improvement > 10% before deploying
```

#### 2. Index Strategy for SQL 2025

```sql
-- ✅ Modern indexing approach

-- Clustered Index: Always on Primary Key
CREATE TABLE dbo.Orders (
    OrderID INT PRIMARY KEY,  -- Automatic clustered index
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    TotalAmount DECIMAL(10,2),
    Status VARCHAR(20)
);

-- Non-clustered indexes: For filtering and sorting
CREATE INDEX IX_Orders_CustomerID ON dbo.Orders(CustomerID);
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders(OrderDate DESC)
    INCLUDE (TotalAmount);  -- Include for covering query

-- Filtered indexes: Reduce size, increase selectivity
CREATE INDEX IX_Orders_Active ON dbo.Orders(OrderDate)
    WHERE Status = 'Completed';  -- Only index completed orders

-- Nonclustered columnstore: For analytics
CREATE NONCLUSTERED COLUMNSTORE INDEX ncci_Orders_Analytics
    ON dbo.Orders (OrderID, CustomerID, OrderDate, TotalAmount)
    WHERE OrderDate >= DATEFROMPARTS(YEAR(GETDATE())-2, 1, 1);

-- ✅ Best Practice: Avoid index bloat
-- Monitor unused indexes
SELECT
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    s.user_updates,
    s.user_seeks + s.user_scans + s.user_lookups AS UserReads
FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats s
        ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE s.user_seeks + s.user_scans + s.user_lookups = 0
    AND s.user_updates > 0
    AND i.name IS NOT NULL;  -- Unused indexes

-- Drop unused indexes to improve INSERT/UPDATE performance
```

#### 3. Join Optimization

```sql
-- ✅ SQL 2025: Let IQP decide join strategy
-- Enable adaptive joins (usually better than manual hints)

-- Instead of manually forcing join type:
-- ❌ SELECT ... FROM t1 INNER HASH JOIN t2 ...
-- ✅ Let IQP choose (with proper statistics)

SELECT o.OrderID, c.CustomerName, SUM(od.Quantity) AS TotalItems
FROM dbo.Orders o
    INNER JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
    INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
WHERE o.OrderDate > '2025-01-01'
GROUP BY o.OrderID, c.CustomerName;

-- IQP will automatically choose:
-- - HASH join if building hash table on smaller side
-- - NESTED LOOP if probing single row
-- - MERGE join if both sides pre-sorted

-- ✅ Best Practice: Ensure good cardinality estimations
-- = Force IQP to pick correct join
UPDATE STATISTICS dbo.Orders FULLSCAN;
UPDATE STATISTICS dbo.Customers FULLSCAN;
UPDATE STATISTICS dbo.OrderDetails FULLSCAN;
```

---

## Security

### ✅ SQL 2025 Security Best Practices

#### 1. Layered Security Approach

```sql
-- Layer 1: Network Security
-- - Firewall rules (block all, allow only necessary)
-- - VPC/Private networks only
-- - No public internet access

-- Layer 2: Authentication
-- ✅ Best: Windows Authentication + Service Accounts
CREATE LOGIN [DOMAIN\SQLServiceAccount] FROM WINDOWS;

-- ✅ OK: Strong Azure AD authentication
-- Connection string: "Authentication=Active Directory Integrated;"

-- ❌ Avoid: SQL Authentication for production (if possible)
-- If must use: Complex passwords > 20 characters

-- Layer 3: Authorization (least privilege)
-- Never grant db_owner to applications
-- Always check EXECUTE permissions

CREATE ROLE ApplicationRole;
GRANT SELECT, INSERT, UPDATE ON dbo.Orders TO ApplicationRole;
GRANT EXECUTE ON dbo.sp_ProcessOrders TO ApplicationRole;

-- Layer 4: Encryption
-- TDE for data at rest
-- SSL/TLS for data in transit (FORCE_ENCRYPTION)

-- Layer 5: Auditing & Monitoring
CREATE DATABASE AUDIT SPECIFICATION dbo_AuditSpec
FOR SERVER AUDIT ServerSecAudit
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.Orders BY dbo)
WITH (STATE = ON);
```

#### 2. Encryption Strategy

```sql
-- TDE (Transparent Data Encryption) - Database level
CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER ASYMMETRIC KEY TDE_Key;

ALTER DATABASE [ProductionDB] SET ENCRYPTION ON;

-- Always Encrypted - Column level (for PII/regulated data)
-- SET UP IN APPLICATION CONNECTION STRING:
-- "Column Encryption Setting=enabled;"

-- Backup Encryption - Backup files
BACKUP DATABASE [ProductionDB]
TO DISK = '\\BackupServer\ProductionDB.bak'
WITH
    ENCRYPTION(ALGORITHM = AES_256, SERVER CERTIFICATE = BackupServerCert),
    COMPRESSION;

-- Row-Level Security - Row level
CREATE FUNCTION FN_EmployeeRLS(@EmployeeDepartmentID INT)
    RETURNS TABLE
    WITH SCHEMABINDING
AS RETURN (
    SELECT 1 AS AccessResult
    WHERE @EmployeeDepartmentID = CAST(SESSION_CONTEXT(N'DepartmentID') AS INT)
       OR CAST(SESSION_CONTEXT(N'IsManager') AS BIT) = 1
);

CREATE SECURITY POLICY EmployeePolicy
    ADD FILTER PREDICATE FN_EmployeeRLS(DepartmentID) ON dbo.Employees;
```

---

## Maintenance & Monitoring

### ✅ SQL 2025 Maintenance & Monitoring

#### 1. Comprehensive Monitoring Dashboard

```sql
-- ✅ SQL 2025 Best Practice: Real-time monitoring

-- Real-time queries
SELECT TOP 20
    s.session_id,
    r.status,
    CAST(r.cpu_time / 1000 / 1000 AS DECIMAL(10,2)) AS CPUTimeSeconds,
    CAST(r.total_elapsed_time / 1000 / 1000 AS DECIMAL(10,2)) AS ElapsedTimeSeconds,
    r.reads,
    r.writes,
    SUBSTRING(st.text, r.statement_start_offset / 2 + 1,
        (CASE r.statement_end_offset WHEN -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text))
              ELSE r.statement_end_offset END - r.statement_start_offset) / 2) AS CurrentSQL
FROM sys.dm_exec_requests r
    JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC;

-- Wait statistics (what's slowing things down)
SELECT TOP 20
    wait_type,
    wait_time_ms,
    waiting_tasks_count,
    CAST(100.0 * wait_time_ms / SUM(wait_time_ms) OVER () AS DECIMAL(5,2)) AS WaitPercentage
FROM sys.dm_os_wait_stats
ORDER BY wait_time_ms DESC;

-- Database size growth trend
SELECT
    CONVERT(DATE, GETDATE()) AS ReportDate,
    DB_NAME(database_id) AS DatabaseName,
    SUM(size) * 8 / 1024 AS SizeGB,
    DATEDIFF(DAY, LAG(CONVERT(DATE, GETDATE())) OVER (PARTITION BY database_id ORDER BY GETDATE()), GETDATE()) AS DaysSinceLastCheck
FROM sys.master_files
GROUP BY database_id;
```

#### 2. Automated Maintenance Jobs

```sql
-- ✅ SQL 2025 Best Practice: Schedule regular maintenance

-- Weekly: Update statistics
EXEC sp_add_job @job_name = 'UpdateStatistics_Weekly';
EXEC sp_add_jobstep @job_name = 'UpdateStatistics_Weekly',
    @command = 'EXEC sp_MSForEachDB "IF ''?'' NOT IN (''master'', ''model'', ''msdb'') BEGIN USE [?]; UPDATE STATISTICS (FULLSCAN); END"';
EXEC sp_add_schedule @schedule_name = 'Weekly_Sunday_2AM',
    @freq_type = 8, @freq_interval = 1, @active_start_time = 020000;
EXEC sp_attach_schedule @job_name = 'UpdateStatistics_Weekly', @schedule_name = 'Weekly_Sunday_2AM';

-- Daily: Check integrity
EXEC sp_add_job @job_name = 'CheckDBIntegrity_Daily';
EXEC sp_add_jobstep @job_name = 'CheckDBIntegrity_Daily',
    @command = 'DBCC CHECKDB (N''ProductionDB'') WITH NO_INFOMSGS;';
EXEC sp_add_schedule @schedule_name = 'Daily_3AM',
    @freq_type = 4, @freq_interval = 1, @active_start_time = 030000;

-- Hourly: Query Store cleanup
EXEC sp_add_job @job_name = 'QueryStoreCleanup_Hourly';
EXEC sp_add_jobstep @job_name = 'QueryStoreCleanup_Hourly',
    @command = 'EXEC sp_query_store_remove_wait_statistics @query_id = NULL;';

-- Monthly: Defragmentation
EXEC sp_add_job @job_name = 'DefragmentIndexes_Monthly';

-- Enable notifications when job fails
EXEC sp_add_notification @job_name = 'UpdateStatistics_Weekly',
    @notify_level_eventlog_failure = 2,
    @notify_level_email_failure = 2,
    @operator_name = 'DBA_Team';
```

---

## Development Standards

### ✅ SQL Server Development Best Practices

#### 1. Stored Procedures

```sql
-- ✅ Best Practice Template

CREATE PROCEDURE dbo.sp_ProcessMonthlyOrders
    @ProcessDate DATETIME = NULL,
    @VerboseLogging BIT = 0
WITH RECOMPILE  -- Allow memory grant feedback
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- Rollback on error

    -- Initialize
    DECLARE @RowCount INT = 0;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    DECLARE @ErrorNumber INT;
    DECLARE @StartTime DATETIME = GETDATE();

    -- Validate input
    IF @ProcessDate IS NULL
        SET @ProcessDate = EOMONTH(GETDATE(), -1);

    IF @ProcessDate > GETDATE()
    BEGIN
        RAISERROR('ProcessDate cannot be in future', 16, 1);
        RETURN -1;
    END

    BEGIN TRY
        -- Logging
        IF @VerboseLogging = 1
            INSERT INTO dbo.ProcedureLog VALUES
                (OBJECT_NAME(@@PROCID), @StartTime, 'Started', NULL);

        BEGIN TRANSACTION;

        -- Process orders
        UPDATE dbo.Orders
        SET Status = 'Processed', ProcessedDate = GETDATE()
        WHERE MONTH(OrderDate) = MONTH(@ProcessDate)
            AND YEAR(OrderDate) = YEAR(@ProcessDate)
            AND Status = 'Pending';

        SET @RowCount = @@ROWCOUNT;

        COMMIT TRANSACTION;

        -- Success logging
        IF @VerboseLogging = 1
            INSERT INTO dbo.ProcedureLog VALUES
                (OBJECT_NAME(@@PROCID), @StartTime, 'Completed',
                 'Rows processed: ' + CAST(@RowCount AS NVARCHAR(10)));

        RETURN @RowCount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorNumber = ERROR_NUMBER();

        INSERT INTO dbo.ErrorLog VALUES
            (OBJECT_NAME(@@PROCID), @ErrorNumber, @ErrorMessage, GETDATE());

        RAISERROR (@ErrorMessage, 16, 1);
        RETURN -1;
    END CATCH
END;

-- EXECUTE
EXEC dbo.sp_ProcessMonthlyOrders @ProcessDate = '2025-01-01', @VerboseLogging = 1;
```

#### 2. Functions

```sql
-- ✅ Inline Table-Valued Functions (better for performance)

CREATE FUNCTION dbo.fn_GetOrderDetails (@OrderID INT)
RETURNS TABLE
AS RETURN (
    SELECT
        o.OrderID,
        o.OrderDate,
        o.TotalAmount,
        od.ProductID,
        od.Quantity,
        od.UnitPrice
    FROM dbo.Orders o
        INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.OrderID = @OrderID
);

-- Usage: Can be indexed, typically fast
SELECT * FROM dbo.fn_GetOrderDetails(123);

-- ❌ Avoid: Scalar functions in SELECT (row-by-row execution)
-- DON'T: SELECT OrderID, dbo.fn_CalculateDiscount(TotalAmount) FROM Orders;
-- DO: SELECT OrderID, CASE WHEN TotalAmount > 1000 THEN TotalAmount * 0.1 ELSE 0 END ...
```

---

## Disaster Recovery & High Availability

### ✅ SQL 2025 DR/HA Best Practices

#### 1. Always On AG Setup

```sql
-- ✅ SQL 2025 Best Practice: Always On Availability Groups
-- Replaces: Database Mirroring (deprecated), Replication (deprecated)

-- Prerequisites
-- - Failover clustering enabled
-- - SQLSERVER service account has domain permissions

-- Create AG
CREATE AVAILABILITY GROUP AG_Production
WITH (
    AUTOMATED_BACKUP_PREFERENCE = SECONDARY_ONLY,
    DB_FAILOVER = ON,  -- Automatic failover on DB failure
    FAILURE_CONDITION_LEVEL = 3
);

-- Define replicas
ALTER AVAILABILITY GROUP AG_Production
ADD REPLICA ON
    N'Server1' WITH (
        ENDPOINT_URL = N'TCP://Server1.domain.com:5022',
        FAILOVER_MODE = AUTOMATIC,
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC
    ),
    N'Server2' WITH (
        ENDPOINT_URL = N'TCP://Server2.domain.com:5022',
        FAILOVER_MODE = MANUAL,
        AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC
    );

-- Add database
ALTER AVAILABILITY GROUP AG_Production ADD DATABASE [ProductionDB];

-- Monitor AG health
SELECT
    ag.name,
    ar.replica_server_name,
    ar.role_desc,
    drs.is_local,
    drs.is_primary_replica,
    drs.synchronization_state_desc,
    drs.last_hardened_time
FROM sys.availability_groups ag
    INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    INNER JOIN sys.dm_hadr_database_replica_states drs
        ON ar.replica_id = drs.replica_id;
```

#### 2. Backup Strategy

```sql
-- ✅ SQL 2025 Recovery Strategy

-- RPO (Recovery Point Objective): 15 minutes
-- RTO (Recovery Time Objective): < 5 minutes

-- Full: Sunday 2 AM
BACKUP DATABASE [ProductionDB]
TO DISK = '\\NetworkBackup\Full_Sunday.bak'
WITH COMPRESSION, CHECKSUM;

-- Differential: Daily midnight
BACKUP DATABASE [ProductionDB]
TO DISK = '\\NetworkBackup\Diff_Daily.bak'
WITH DIFFERENTIAL, COMPRESSION, CHECKSUM;

-- Transaction Log: Every 15 minutes
BACKUP LOG [ProductionDB]
TO DISK = '\\NetworkBackup\Log_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmm') + '.trn'
WITH COMPRESSION, CHECKSUM;

-- Archive old backups to cold storage (Azure)
-- BACKUP … TO URL = 'https://...container/backup'

-- Test restore quarterly
RESTORE VERIFYONLY FROM DISK = '\\NetworkBackup\Full_Sunday.bak';
```

---

## Cloud & Hybrid Integration

### ✅ SQL Server 2025 Cloud Best Practices

#### 1. Azure SQL Database Compatibility

```sql
-- ✅ SQL 2025: Arc-enabled SQL Server for hybrid
-- Brings Azure management to on-premises servers

-- Arc registration
-- az sql server-instance create --name MySQL2025 --resource-group RG --location eastus

-- Managed backup to Azure
EXEC managed_backup.sp_backup_config_basic
    @enable_backup = 1,
    @database_name = NULL,  -- All databases
    @storage_account_url = 'https://myaccount.blob.core.windows.net',
    @storage_account_key = 'AccessKey',
    @retention_days = 30;

-- Monitor backups
SELECT * FROM managed_backup.fn_backup_db_config;

-- ✅ Best Practice: Automated patch management via Arc
-- Patches applied automatically without interruption
```

#### 2. Azure Migrate for SQL Server

```sql
-- ✅ SQL 2025: Test cloud compatibility

-- Run compatibility checker
EXEC sp_validatecompilations;

-- Generate migration script
-- Use Database Migration Assistant (DMA)
-- Analyzes for compatibility issues
-- Recommends Azure SQL DB or SQL Managed Instance

-- For on-premises to cloud:
-- 1. Run DMA to identify issues
-- 2. Fix breaking changes (replication, CLR, etc.)
-- 3. Use Azure Migrate or DMS for data transfer
-- 4. Validate in cloud environment
-- 5. Cutover with minimal downtime
```

---

## Summary Table: Best Practices by Category

| Category | SQL 2022 & Earlier | SQL 2025 Enhancement |
|----------|-------------------|----------------------|
| **Query Optimization** | Manual index tuning | Enable IQP features |
| **Performance Tuning** | Query hints in code | Query Store hints (no code change) |
| **Statistics** | Full database stats | Incremental statistics |
| **Analytics** | Separate OLAP DB needed | Nonclustered columnstore |
| **Memory Management** | Manual | Memory grant feedback |
| **Replication** | Supported | Use Always On AG instead |
| **Encryption** | TDE only | TDE + Always Encrypted |
| **Tool Integration** | SSMS only | SSMS + Azure Data Studio |
| **Vector Data** | Not supported | Native vector types |
| **Deployment** | SSDT risky | SSDT safe with refactoring tools |

---

## Checklist: New SQL 2025 Instance Setup

```
✅ Post-Installation Configuration

Server Level:
□ Change sa password & disable sa account
□ Set minimum password length policy
□ Configure max memory (leave 4GB for OS)
□ Enable backup compression by default
□ Configure default backup location
□ Create operator for alerts
□ Schedule agent jobs for maintenance

Database Level:
□ Enable COMPATIBILITY_LEVEL = 170
□ Enable QUERY_OPTIMIZER_HOTFIXES
□ Enable PARAMETER_SENSITIVE_PLAN_OPTIMIZATION
□ Enable BATCH_MODE_ADAPTIVE_JOINS
□ Enable BATCH_MODE_MEMORY_GRANT_FEEDBACK
□ Configure proper recovery model
□ Setup Query Store (READ_WRITE mode)
□ Schedule statistics updates
□ Schedule integrity checks
□ Configure backup schedule

Security:
□ Setup Windows Authentication
□ Disable SQL Authentication if possible
□ Create service accounts for SQL jobs
□ Implement TDE if handling sensitive data
□ Setup Always Encrypted for PII columns
□ Enable auditing
□ Configure firewall rules

Monitoring:
□ Setup Activity Monitor alerts
□ Configure email notification
□ Create performance baseline
□ Setup Query Store reports
□ Create custom DMV monitoring views
□ Test backup restore procedure
```

---

*Last Updated: February 2025*

**Remember**: These are guidelines. Adapt them to your specific environment, compliance requirements, and workload characteristics. Regular testing and monitoring are essential for success.
