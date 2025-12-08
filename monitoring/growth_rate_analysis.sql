/*
    Purpose: Monitor database growth trends and burn rate for capacity planning
    Usage: Run regularly; analyze growth patterns; forecast storage needs
    Prerequisites: Historical data collection recommended; SELECT on system views
    Safety Notes: Read-only analysis; use for planning infrastructure upgrades
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. CURRENT DATABASE SIZE AND GROWTH
-- ============================================================================
PRINT '=== DATABASE SIZE AND GROWTH ===';

SELECT 
    d.name AS [Database],
    CAST((SUM(mf.size) * 8.0) / 1024 AS DECIMAL(10,2)) AS [CurrentSizeMB],
    CAST((SUM(FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedSpaceMB],
    CAST((SUM(mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [FreeSpaceMB],
    CAST(100.0 * SUM(FILEPROPERTY(mf.name, 'SpaceUsed')) / SUM(mf.size) AS DECIMAL(5,2)) AS [PercentUsed],
    d.create_date AS [CreatedDate],
    DATEDIFF(DAY, d.create_date, GETDATE()) AS [DaysOld]
FROM sys.databases d
INNER JOIN sys.master_files mf 
    ON d.database_id = mf.database_id
GROUP BY d.name, d.create_date
ORDER BY CAST((SUM(mf.size) * 8.0) / 1024 AS DECIMAL(10,2)) DESC;

-- ============================================================================
-- 2. ESTIMATE MONTHLY GROWTH
-- ============================================================================
PRINT '=== ESTIMATED MONTHLY GROWTH ===';

-- Note: This requires manual data collection over time
-- Create a tracking table to store historical sizes

/*
CREATE TABLE dbo.DatabaseGrowthHistory (
    RecordDate DATETIME,
    DatabaseName NVARCHAR(128),
    SizeMB DECIMAL(15,2),
    UsedSpaceMB DECIMAL(15,2)
);

-- Insert current data
INSERT INTO dbo.DatabaseGrowthHistory
SELECT 
    GETDATE(),
    d.name,
    CAST((SUM(mf.size) * 8.0) / 1024 AS DECIMAL(15,2)),
    CAST((SUM(FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(15,2))
FROM sys.databases d
INNER JOIN sys.master_files mf 
    ON d.database_id = mf.database_id
GROUP BY d.name;
*/

-- Analyze growth rates if historical table exists
SELECT 
    h.DatabaseName,
    MIN(h.RecordDate) AS [FirstRecordDate],
    MAX(h.RecordDate) AS [LatestRecordDate],
    DATEDIFF(DAY, MIN(h.RecordDate), MAX(h.RecordDate)) AS [DaysRecorded],
    CAST(MAX(h.SizeMB) AS DECIMAL(10,2)) AS [LatestSizeMB],
    CAST(MIN(h.SizeMB) AS DECIMAL(10,2)) AS [EarliestSizeMB],
    CAST((MAX(h.SizeMB) - MIN(h.SizeMB)) AS DECIMAL(10,2)) AS [TotalGrowthMB],
    CAST((MAX(h.SizeMB) - MIN(h.SizeMB)) / NULLIF(DATEDIFF(DAY, MIN(h.RecordDate), MAX(h.RecordDate)), 0) AS DECIMAL(10,2)) AS [DailyGrowthMB],
    CAST(((MAX(h.SizeMB) - MIN(h.SizeMB)) / NULLIF(DATEDIFF(DAY, MIN(h.RecordDate), MAX(h.RecordDate)), 0)) * 30 AS DECIMAL(10,2)) AS [EstimatedMonthlyGrowthMB]
FROM dbo.DatabaseGrowthHistory h
GROUP BY h.DatabaseName
ORDER BY [EstimatedMonthlyGrowthMB] DESC;

-- ============================================================================
-- 3. TABLE SIZE ANALYSIS
-- ============================================================================
PRINT '=== LARGEST TABLES ===';

SELECT TOP 20
    OBJECT_NAME(ps.object_id) AS [TableName],
    CAST((SUM(ps.reserved_page_count) * 8.0) / 1024 AS DECIMAL(10,2)) AS [ReservedMB],
    CAST((SUM(ps.used_page_count) * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    SUM(ps.row_count) AS [RowCount],
    CAST((SUM(ps.used_page_count) * 8.0) / 1024 / NULLIF(SUM(ps.row_count), 0) AS DECIMAL(10,2)) AS [BytesPerRow]
FROM sys.dm_db_partition_stats ps
WHERE OBJECT_NAME(ps.object_id) NOT LIKE 'sys%'
GROUP BY ps.object_id
ORDER BY CAST((SUM(ps.reserved_page_count) * 8.0) / 1024 AS DECIMAL(10,2)) DESC;

-- ============================================================================
-- 4. MONITOR TEMPDB GROWTH BURN RATE
-- ============================================================================
PRINT '=== TEMPDB BURN RATE ===';

SELECT 
    'User Objects Space (MB)' AS [Metric],
    CAST(SUM(su.user_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2)) AS [Value]
FROM sys.dm_db_session_space_usage su

UNION ALL

SELECT 
    'Internal Objects Space (MB)',
    CAST(SUM(su.internal_objects_alloc_page_count * 8.0) / 1024 AS DECIMAL(10,2))
FROM sys.dm_db_session_space_usage su;

-- ============================================================================
-- 5. LOG FILE GROWTH ANALYSIS
-- ============================================================================
PRINT '=== TRANSACTION LOG GROWTH ===';

SELECT 
    d.name AS [DatabaseName],
    mf.name AS [LogFileName],
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [CurrentSizeMB],
    CAST((FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    mf.growth AS [AutoGrowthSize],
    CASE WHEN mf.is_percent_growth = 1 THEN 'Percent' ELSE 'MB' END AS [GrowthType],
    CAST((mf.max_size * 8.0) / 1024 AS DECIMAL(10,2)) AS [MaxSizeMB]
FROM sys.databases d
INNER JOIN sys.master_files mf 
    ON d.database_id = mf.database_id
WHERE mf.type = 1  -- Log files
ORDER BY d.name;

-- ============================================================================
-- 6. FORECAST DISK SPACE NEEDED (30-day projection)
-- ============================================================================
PRINT '=== 30-DAY SPACE FORECAST ===';

WITH GrowthRates AS (
    SELECT 
        h.DatabaseName,
        MAX(h.SizeMB) AS [CurrentSizeMB],
        CAST(((MAX(h.SizeMB) - MIN(h.SizeMB)) / NULLIF(DATEDIFF(DAY, MIN(h.RecordDate), MAX(h.RecordDate)), 0)) * 30 AS DECIMAL(10,2)) AS [EstimatedMonthlyGrowth]
    FROM dbo.DatabaseGrowthHistory h
    GROUP BY h.DatabaseName
)
SELECT 
    DatabaseName,
    [CurrentSizeMB],
    [EstimatedMonthlyGrowth],
    CAST([CurrentSizeMB] + [EstimatedMonthlyGrowth] AS DECIMAL(10,2)) AS [ProjectedSize30Days],
    CASE 
        WHEN ([EstimatedMonthlyGrowth] / [CurrentSizeMB]) > 0.1 THEN 'HIGH - Monitor closely'
        WHEN ([EstimatedMonthlyGrowth] / [CurrentSizeMB]) > 0.05 THEN 'MEDIUM - Plan expansion'
        ELSE 'LOW - Normal growth'
    END AS [GrowthRate]
FROM GrowthRates
ORDER BY [EstimatedMonthlyGrowth] DESC;

-- ============================================================================
-- 7. DATA FILE FRAGMENTATION IMPACT ON SIZE
-- ============================================================================
PRINT '=== DATA FILE FRAGMENTATION (Space Waste) ===';

SELECT TOP 10
    d.name AS [DatabaseName],
    mf.name AS [FileName],
    CAST((mf.size * 8.0) / 1024 AS DECIMAL(10,2)) AS [AllocatedMB],
    CAST((FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0) / 1024 AS DECIMAL(10,2)) AS [UsedMB],
    CAST(((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) AS [UnusedMB],
    CAST(100.0 * (mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / mf.size AS DECIMAL(5,2)) AS [UnusedPercent]
FROM sys.databases d
INNER JOIN sys.master_files mf 
    ON d.database_id = mf.database_id
WHERE mf.type = 0  -- Data files
ORDER BY CAST(((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) * 8.0) / 1024 AS DECIMAL(10,2)) DESC;

-- ============================================================================
-- 8. CAPACITY PLANNING RECOMMENDATIONS
-- ============================================================================
PRINT '=== CAPACITY PLANNING RECOMMENDATIONS ===';
PRINT '1. Establish baseline by running this script monthly';
PRINT '2. Store results in a history table for trend analysis';
PRINT '3. Monitor databases consuming >50% allocated space';
PRINT '4. Alert when growth rate > 10% of current size per month';
PRINT '5. Plan SAN/disk expansion when available space < 20%';
PRINT '6. Consider archiving old data for high-growth databases';
PRINT '7. Use data compression for large tables';
PRINT '8. Implement purging strategies for transient data';
