/*
    Purpose: Analyze and rebuild fragmented indexes to maintain query performance
    Usage: Run regularly; rebuild at >30% fragmentation, reorganize at 10-30%
    Prerequisites: ALTER permissions on tables; SELECT on system views
    Safety Notes: Rebuilds lock tables; schedule during low-activity windows
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ============================================================================
-- 1. ANALYZE INDEX FRAGMENTATION
-- ============================================================================
PRINT '=== INDEX FRAGMENTATION ANALYSIS ===';

SELECT 
    OBJECT_NAME(ips.object_id) AS [TableName],
    i.name AS [IndexName],
    ips.avg_fragmentation_in_percent AS [FragmentationPercent],
    ips.page_count AS [PageCount],
    CASE 
        WHEN ips.avg_fragmentation_in_percent < 10 THEN 'OK - No Action'
        WHEN ips.avg_fragmentation_in_percent BETWEEN 10 AND 30 THEN 'REORGANIZE'
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
    END AS [RecommendedAction]
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i 
    ON ips.object_id = i.object_id
    AND ips.index_id = i.index_id
WHERE ips.database_id = DB_ID()
    AND ips.page_count > 1000  -- Only tables with significant pages
    AND i.type_desc = 'NONCLUSTERED'
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- ============================================================================
-- 2. REORGANIZE INDEXES (10-30% fragmentation)
-- ============================================================================
PRINT '=== REORGANIZING INDEXES (10-30% fragmentation) ===';

DECLARE @TableName NVARCHAR(128);
DECLARE @IndexName NVARCHAR(128);

DECLARE index_cursor CURSOR FOR
SELECT 
    OBJECT_NAME(ips.object_id),
    i.name
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i 
    ON ips.object_id = i.object_id
    AND ips.index_id = i.index_id
WHERE ips.database_id = DB_ID()
    AND ips.avg_fragmentation_in_percent BETWEEN 10 AND 30
    AND ips.page_count > 1000
    AND i.type_desc = 'NONCLUSTERED';

OPEN index_cursor;

FETCH NEXT FROM index_cursor INTO @TableName, @IndexName;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Reorganizing: ' + @TableName + '.' + @IndexName;
        ALTER INDEX [' + @IndexName + '] ON [' + @TableName + '] REORGANIZE;
        PRINT 'Success: ' + @TableName + '.' + @IndexName;
    END TRY
    BEGIN CATCH
        PRINT 'Error reorganizing ' + @TableName + '.' + @IndexName + ': ' + ERROR_MESSAGE();
    END CATCH
    
    FETCH NEXT FROM index_cursor INTO @TableName, @IndexName;
END

CLOSE index_cursor;
DEALLOCATE index_cursor;

-- ============================================================================
-- 3. REBUILD INDEXES (>30% fragmentation)
-- ============================================================================
PRINT '=== REBUILDING INDEXES (>30% fragmentation) ===';

DECLARE @TableName2 NVARCHAR(128);
DECLARE @IndexName2 NVARCHAR(128);

DECLARE rebuild_cursor CURSOR FOR
SELECT 
    OBJECT_NAME(ips.object_id),
    i.name
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i 
    ON ips.object_id = i.object_id
    AND ips.index_id = i.index_id
WHERE ips.database_id = DB_ID()
    AND ips.avg_fragmentation_in_percent > 30
    AND ips.page_count > 1000
    AND i.type_desc = 'NONCLUSTERED';

OPEN rebuild_cursor;

FETCH NEXT FROM rebuild_cursor INTO @TableName2, @IndexName2;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        PRINT 'Rebuilding: ' + @TableName2 + '.' + @IndexName2;
        ALTER INDEX [' + @IndexName2 + '] ON [' + @TableName2 + '] REBUILD;
        PRINT 'Success: ' + @TableName2 + '.' + @IndexName2;
    END TRY
    BEGIN CATCH
        PRINT 'Error rebuilding ' + @TableName2 + '.' + @IndexName2 + ': ' + ERROR_MESSAGE();
    END CATCH
    
    FETCH NEXT FROM rebuild_cursor INTO @TableName2, @IndexName2;
END

CLOSE rebuild_cursor;
DEALLOCATE rebuild_cursor;

-- ============================================================================
-- 4. POST-MAINTENANCE STATISTICS
-- ============================================================================
PRINT '=== FRAGMENTATION AFTER MAINTENANCE ===';

SELECT 
    OBJECT_NAME(ips.object_id) AS [TableName],
    i.name AS [IndexName],
    ips.avg_fragmentation_in_percent AS [FragmentationPercent],
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i 
    ON ips.object_id = i.object_id
    AND ips.index_id = i.index_id
WHERE ips.database_id = DB_ID()
    AND ips.page_count > 1000
ORDER BY ips.avg_fragmentation_in_percent DESC;
