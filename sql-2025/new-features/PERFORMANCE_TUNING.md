# SQL Server 2025 - Performance Tuning Guide

## Overview

SQL Server 2025 introduces advanced performance optimization features that can significantly improve workload performance. This guide provides practical strategies for leveraging these new capabilities.

## 1. Query Optimization with IQP (Intelligent Query Processing)

### 1.1 Enable IQP Features

```sql
-- Enable at database level (recommended)
ALTER DATABASE SCOPED CONFIGURATION SET QUERY_OPTIMIZER_HOTFIXES = ON;
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;
ALTER DATABASE SCOPED CONFIGURATION SET INTERLEAVED_EXECUTION_TVF = ON;
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_ADAPTIVE_JOINS = ON;
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = ON;
ALTER DATABASE SCOPED CONFIGURATION SET APPROXIMATE_COUNT_DISTINCT = OFF;

-- Verify settings
SELECT name, value_for_primary, value_for_secondary
FROM sys.database_scoped_configurations
ORDER BY name;
```

### 1.2 Adaptive Joins in Action

```sql
-- Create a stored procedure that benefits from adaptive joins
CREATE PROCEDURE dbo.sp_AdaptiveJoinExample
    @OrderCount INT = 100,
    @LargeOrderThreshold DECIMAL(10,2) = 1000
AS
BEGIN
    -- This query will automatically choose between Hash and Nested Loop based on runtime data
    SELECT
        o.OrderID,
        c.CustomerName,
        od.ProductID,
        od.Quantity,
        od.UnitPrice,
        ROW_NUMBER() OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate DESC) AS OrderSequence
    FROM dbo.Orders o
        INNER JOIN dbo.Customers c ON o.CustomerID = c.CustomerID
        INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID
    WHERE o.OrderDate >= DATEADD(MONTH, -3, GETDATE())
        AND o.TotalAmount > @LargeOrderThreshold
    ORDER BY o.OrderID;
END;

-- Monitor adaptive join feedback
SELECT
    query_id,
    execution_plan_id,
    execution_count,
    total_spills,
    total_adaptive_joins_recompiled
FROM sys.dm_exec_query_profiles
WHERE total_adaptive_joins_recompiled > 0;
```

### 1.3 Parameter Sensitive Plan Optimization (PSPUDF)

```sql
-- Queries with parameters that have significantly different selectivity benefit most
CREATE PROCEDURE dbo.sp_ParameterSensitiveQuery
    @DepartmentID INT,
    @StatusCode VARCHAR(10)
AS
BEGIN
    -- Different plan needed for each department due to data skew
    SELECT
        e.EmployeeID,
        e.EmployeeName,
        e.Salary,
        e.HireDate
    FROM dbo.Employees e
    WHERE e.DepartmentID = @DepartmentID
        AND e.StatusCode = @StatusCode
    ORDER BY e.Salary DESC;
END;

-- Test with different parameters
EXEC dbo.sp_ParameterSensitiveQuery @DepartmentID = 1, @StatusCode = 'A';
EXEC dbo.sp_ParameterSensitiveQuery @DepartmentID = 5, @StatusCode = 'A';

-- Check Query Store for plan variations
SELECT
    q.query_id,
    p.plan_id,
    COUNT(DISTINCT rs.execution_type_desc) AS ExecutionTypeCount,
    AVG(CAST(rs.avg_cpu_time AS FLOAT)) AS AvgCPUTime
FROM sys.query_store_query q
    INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
    INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE q.query_hash = CONVERT(BINARY(8), '0x...')  -- Replace with actual hash
GROUP BY q.query_id, p.plan_id
HAVING COUNT(DISTINCT rs.execution_type_desc) > 1;
```

## 2. Advanced Indexing Strategy

### 2.1 Columnstore Index Optimization

```sql
-- Analyze workload suitability for columnstore
CREATE PROCEDURE dbo.sp_AnalyzeColumnstoreSuitability
    @TableName SYSNAME,
    @DatabaseName SYSNAME = DB_NAME()
AS
BEGIN
    DECLARE @RowCount BIGINT;

    -- Get table size
    SELECT @RowCount = SUM(p.rows)
    FROM sys.partitions p
        INNER JOIN sys.objects o ON p.object_id = o.object_id
    WHERE o.name = @TableName;

    -- Columnstore is beneficial for:
    -- - Tables with > 1M rows
    -- - Wide tables (many columns)
    -- - Aggregation-heavy workloads

    SELECT
        @TableName AS TableName,
        @RowCount AS RowCount,
        CASE WHEN @RowCount > 1000000 THEN 'YES' ELSE 'NO' END AS SuitableForColumnstore,
        'For analytical queries, update freq < once/hour' AS Recommendation;
END;

-- Example: Create nonclustered columnstore for mixed workload
CREATE NONCLUSTERED COLUMNSTORE INDEX ncci_Orders_Analytics
ON dbo.Orders (OrderID, OrderDate, CustomerID, TotalAmount, Status)
WHERE OrderDate >= DATEFROMPARTS(YEAR(GETDATE()) - 1, 1, 1)
WITH (MAXDOP = 8, DROP_EXISTING = OFF);

-- Monitor columnstore quality
SELECT
    OBJECT_NAME(ics.object_id) AS TableName,
    ics.name AS IndexName,
    ics.type_desc AS IndexType,
    ISNULL(ics.compression_delay, 0) AS CompressionDelayMinutes,
    ics.state_desc AS IndexState,
    ps.row_group_count,
    ps.total_rows,
    CAST(100.0 * ps.deleted_rows / NULLIF(ps.total_rows, 0) AS DECIMAL(5,2)) AS DeletedRowPercentage
FROM sys.indexes ics
    OUTER APPLY sys.dm_db_column_store_row_group_physical_stats(ics.object_id, ics.index_id) ps
WHERE ics.type_desc LIKE '%COLUMNSTORE%'
ORDER BY ps.deleted_rows DESC;
```

### 2.2 Incremental Statistics

```sql
-- Enable incremental statistics for large partitioned tables
ALTER DATABASE SCOPED CONFIGURATION SET INCREMENTAL_STATISTICS = ON;

-- Create partitioned table example
CREATE PARTITION FUNCTION pf_monthly (DATE) AS RANGE LEFT FOR VALUES
('2025-01-01'), ('2025-02-01'), ('2025-03-01'), ('2025-04-01'),
('2025-05-01'), ('2025-06-01'), ('2025-07-01'), ('2025-08-01'),
('2025-09-01'), ('2025-10-01'), ('2025-11-01'), ('2025-12-01');

CREATE PARTITION SCHEME ps_monthly AS PARTITION pf_monthly
TO ([PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY],
    [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY], [PRIMARY]);

-- Recreate statistics as incremental
UPDATE STATISTICS dbo.SalesData WITH INCREMENTAL = ON, MAXDOP = 8;

-- Monitor incremental stats
SELECT
    s.object_id,
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatisticName,
    s.incremental,
    sp.last_updated,
    sp.partition_number,
    sp.modification_counter
FROM sys.stats s
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE s.incremental = 1 AND s.object_id = OBJECT_ID('dbo.SalesData')
ORDER BY sp.partition_number;
```

## 3. Memory and Buffer Pool Efficiency

### 3.1 Memory Grant Feedback

```sql
-- Automatically tune memory grants for queries
ALTER DATABASE SCOPED CONFIGURATION SET BATCH_MODE_MEMORY_GRANT_FEEDBACK = ON;

-- Monitor memory grant feedback
SELECT
    qs.execution_count,
    qs.total_rows,
    qs.last_rows,
    CASE WHEN qs.total_rows > qs.last_rows THEN 'Grant Too Large'
         WHEN qs.total_rows < qs.last_rows AND qs.last_rows > qs.total_rows * 1.5 THEN 'Grant Too Small'
         ELSE 'Grant OK' END AS MemoryGrantStatus,
    CAST(qs.total_rows AS FLOAT) / NULLIF(qs.last_rows, 0) AS EfficiencyRatio
FROM sys.dm_exec_query_stats qs
WHERE qs.last_rows > 0
ORDER BY CAST(qs.total_rows AS FLOAT) / NULLIF(qs.last_rows, 1) DESC;
```

### 3.2 Buffer Pool Extension (For Hybrid Scenarios)

```sql
-- Configure buffer pool extension for enterprise environments
EXEC sp_configure 'buffer pool extension', 1;
RECONFIGURE;

-- Add SSD storage for buffer pool
ALTER SERVER CONFIGURATION SET BUFFER POOL EXTENSION ON
(FILENAME = 'E:\BPE\BufferPoolExtension.BPE', SIZE = 100 GB);

-- Monitor buffer pool extension usage
SELECT
    file_id,
    file_type_desc,
    file_size_in_bytes / 1024 / 1024 / 1024 AS SizeGB,
    state_desc
FROM sys.dm_os_buffer_pool_extension_pages_info;
```

## 4. Query Store Optimization

### 4.1 Query Store Configuration

```sql
-- Optimal configuration for production
ALTER DATABASE CURRENT SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,  -- 15 minutes
    MAX_STORAGE_SIZE_MB = 10000,        -- Adjust based on workload
    INTERVAL_LENGTH_MINUTES = 10,
    MAX_PLANS_PER_QUERY = 200
);

-- Archive old data to reduce growth
ALTER DATABASE CURRENT SET QUERY_STORE (QUERY_STORE_MODE = READ_WRITE);
ALTER DATABASE CURRENT SET QUERY_STORE (QUERY_STORE_CAPTURE_MODE = AUTO);
```

### 4.2 Identify Regression Queries

```sql
-- Find queries with performance regressions
WITH QueryStats AS (
    SELECT
        q.query_id,
        qt.query_sql_text,
        p.plan_id,
        MIN(rs.last_execution_time) AS FirstExecution,
        MAX(rs.last_execution_time) AS LastExecution,
        AVG(rs.avg_cpu_time) AS AvgCPUTime,
        AVG(rs.avg_logical_reads) AS AvgLogicalReads,
        AVG(rs.avg_elapsed_time) AS AvgElapsedTime,
        ROW_NUMBER() OVER (PARTITION BY q.query_id ORDER BY rs.last_execution_time DESC) AS PlanRank
    FROM sys.query_store_query q
        INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
        INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
        INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
    WHERE q.query_hash IS NOT NULL
    GROUP BY q.query_id, qt.query_sql_text, p.plan_id
)
SELECT TOP 20
    qs1.query_id,
    qs1.query_sql_text,
    qs1.AvgCPUTime AS CurrentAvgCPUTime,
    LAG(qs1.AvgCPUTime) OVER (PARTITION BY qs1.query_id ORDER BY qs1.PlanRank DESC) AS PreviousAvgCPUTime,
    CAST(100.0 * (qs1.AvgCPUTime - LAG(qs1.AvgCPUTime) OVER (PARTITION BY qs1.query_id ORDER BY qs1.PlanRank DESC)) /
         NULLIF(LAG(qs1.AvgCPUTime) OVER (PARTITION BY qs1.query_id ORDER BY qs1.PlanRank DESC), 0) AS DECIMAL(10,2)) AS RegressionPercentage
FROM QueryStats qs1
WHERE qs1.PlanRank = 1
ORDER BY RegressionPercentage DESC;
```

### 4.3 Force Plans for Critical Queries

```sql
-- Identify best performing plans
SELECT TOP 5
    q.query_id,
    p.plan_id,
    qt.query_sql_text,
    COUNT(*) AS ExecutionCount,
    MIN(rs.avg_cpu_time) AS BestCPUTime,
    MAX(rs.avg_cpu_time) AS WorstCPUTime
FROM sys.query_store_query q
    INNER JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
    INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
    INNER JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
GROUP BY q.query_id, p.plan_id, qt.query_sql_text
ORDER BY BestCPUTime ASC;

-- Force a specific plan
EXEC sp_query_store_force_plan @query_id = 1, @plan_id = 1;

-- Monitor forced plans
SELECT
    q.query_id,
    p.plan_id,
    p.query_plan,
    qph.last_force_failure_reason_desc,
    qph.force_failure_count
FROM sys.query_store_query q
    INNER JOIN sys.query_store_plan p ON q.query_id = p.query_id
    INNER JOIN sys.query_store_plan_forcing_locations qph ON p.plan_id = qph.plan_id
WHERE qph.is_forced = 1;

-- Unforce a plan if needed
EXEC sp_query_store_unforce_plan @query_id = 1, @plan_id = 1;
```

## 5. Workload Classification

### 5.1 Classify Queries for Different Optimization

```sql
-- Create workload classifier stored procedure
CREATE PROCEDURE dbo.sp_ClassifyWorkload
    @QueryText NVARCHAR(MAX),
    @QueryDuration INT OUTPUT,
    @WorkloadCategory VARCHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Classify based on characteristics
    IF @QueryText LIKE '%INSERT INTO%' OR @QueryText LIKE '%UPDATE %' OR @QueryText LIKE '%DELETE FROM%'
        SET @WorkloadCategory = 'DML'
    ELSE IF @QueryText LIKE '%SELECT%SUM%' OR @QueryText LIKE '%GROUP BY%' OR @QueryText LIKE '%HAVING%'
        SET @WorkloadCategory = 'AGGREGATION'
    ELSE IF @QueryDuration > 5000
        SET @WorkloadCategory = 'LONG_RUNNING'
    ELSE
        SET @WorkloadCategory = 'OLTP';
END;

-- Use classification for targeted optimization
SELECT
    q.query_id,
    SUM(rs.execution_count) AS TotalExecutions,
    AVG(rs.avg_elapsed_time) AS AvgElapsedTime,
    CASE
        WHEN SUM(rs.execution_count) > 10000 THEN 'HIGH_FREQUENCY'
        WHEN AVG(rs.avg_elapsed_time) > 1000000 THEN 'LONG_RUNNING'
        ELSE 'NORMAL'
    END AS WorkloadType
FROM sys.query_store_query q
    INNER JOIN sys.query_store_runtime_stats rs ON q.query_id = rs.query_id
GROUP BY q.query_id
ORDER BY CASE
    WHEN SUM(rs.execution_count) > 10000 THEN 1
    ELSE 2
END;
```

## 6. Monitoring Dashboard Queries

### 6.1 Real-Time Performance Metrics

```sql
-- Top resource-consuming queries
SELECT TOP 20
    r.session_id,
    r.start_time,
    r.status,
    CAST(r.cpu_time / 1000 AS BIGINT) AS CPUTimeMs,
    CAST(r.total_elapsed_time / 1000 AS BIGINT) AS ElapsedTimeMs,
    r.reads,
    r.writes,
    SUBSTRING(s.text, r.statement_start_offset / 2 + 1,
        (CASE r.statement_end_offset WHEN -1 THEN LEN(CONVERT(NVARCHAR(MAX), s.text))
              ELSE r.statement_end_offset END - r.statement_start_offset) / 2) AS SqlText
FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) s
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC;

-- Index usage statistics
SELECT TOP 20
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan
FROM sys.indexes i
    LEFT JOIN sys.dm_db_index_usage_stats s ON i.object_id = s.object_id
        AND i.index_id = s.index_id
        AND s.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
ORDER BY s.user_seeks + s.user_scans + s.user_lookups DESC;

-- Missing indexes (top 10)
SELECT TOP 10
    CONVERT(DECIMAL(18,2), (s.user_seeks + s.user_scans + s.user_lookups) * s.avg_total_user_cost * s.avg_user_impact * 0.01) AS ImprovementMeasure,
    d.equality_columns,
    d.inequality_columns,
    d.included_columns,
    OBJECT_NAME(d.object_id) AS TableName
FROM sys.dm_db_missing_index_details d
    INNER JOIN sys.dm_db_missing_index_groups g ON d.index_handle = g.index_handle
    INNER JOIN sys.dm_db_missing_index_groups_stats s ON g.index_group_id = s.group_handle
WHERE database_id = DB_ID()
ORDER BY ImprovementMeasure DESC;
```

---

*Last Updated: February 2025*

## Next Steps

1. **Baseline Current Performance**: Before implementing changes, document current metrics
2. **Test in Non-Production**: Always test optimization changes in dev/test first
3. **Monitor After Changes**: Use the monitoring queries above to validate improvements
4. **Iterate**: Continuously refine based on actual workload characteristics

---

For more information:
- [Query Store Documentation](https://docs.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)
- [Intelligent Query Processing](https://docs.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing)
- [Columnstore Indexes](https://docs.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-overview)
