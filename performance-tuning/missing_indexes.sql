/*
    Purpose: Identify missing indexes based on query execution history
    Usage: Run regularly; review top recommendations by improvement impact
    Prerequisites: Query Store enabled; SELECT on system views
    Safety Notes: Not all suggested indexes improve performance; test in dev first
    Version: SQL Server 2016+ with Query Store
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. MISSING INDEXES FROM MISSING INDEX DMVs (Current Session)
-- ============================================================================
PRINT '=== MISSING INDEXES - ALL DATABASES ===';

SELECT 
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.avg_total_user_cost,
    migs.avg_user_impact,
    migs.user_seeks,
    migs.user_scans,
    migs.user_lookups,
    (migs.user_seeks + migs.user_scans + migs.user_lookups) AS [TotalReads],
    CAST((migs.user_seeks + migs.user_scans + migs.user_lookups) * migs.avg_user_impact * (migs.avg_total_user_cost) AS DECIMAL(12, 2)) AS [ImprovementMeasure],
    mid.statement AS [TableName]
FROM sys.dm_db_missing_index_groups ig
INNER JOIN sys.dm_db_missing_index_group_stats migs 
    ON ig.index_group_id = migs.group_handle
INNER JOIN sys.dm_db_missing_index_details mid 
    ON ig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
    AND (migs.user_seeks + migs.user_scans + migs.user_lookups) > 100  -- Only indexes used 100+ times
ORDER BY [ImprovementMeasure] DESC;

-- ============================================================================
-- 2. GENERATE CREATE INDEX STATEMENTS FOR TOP RECOMMENDATIONS
-- ============================================================================
PRINT '=== GENERATE CREATE INDEX STATEMENTS ===';

SELECT TOP 10
    'CREATE NONCLUSTERED INDEX [IX_' 
    + REPLACE(REPLACE(REPLACE(mid.equality_columns, ', ', '_'), '[', ''), ']', '') 
    + '_' + CAST(ROW_NUMBER() OVER (ORDER BY migs.avg_user_impact * migs.user_seeks DESC) AS VARCHAR(3))
    + '] ON ' + mid.statement
    + ' (' + ISNULL(mid.equality_columns, '') 
    + CASE WHEN mid.inequality_columns IS NOT NULL 
            THEN ', ' + mid.inequality_columns 
            ELSE '' 
      END
    + ')'
    + CASE WHEN mid.included_columns IS NOT NULL 
            THEN ' INCLUDE (' + mid.included_columns + ')'
            ELSE ''
      END
    + ' WITH (FILLFACTOR = 90);' AS [CreateIndexStatement],
    migs.avg_user_impact * migs.user_seeks AS [EstimatedImpact],
    migs.user_seeks + migs.user_scans + migs.user_lookups AS [TotalReads]
FROM sys.dm_db_missing_index_groups ig
INNER JOIN sys.dm_db_missing_index_group_stats migs 
    ON ig.index_group_id = migs.group_handle
INNER JOIN sys.dm_db_missing_index_details mid 
    ON ig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
    AND (migs.user_seeks + migs.user_scans + migs.user_lookups) > 100
ORDER BY migs.avg_user_impact * migs.user_seeks DESC;

-- ============================================================================
-- 3. EXISTING INDEXES NOT BEING USED (Candidates for Removal)
-- ============================================================================
PRINT '=== UNUSED INDEXES (Candidates for Removal) ===';

SELECT 
    OBJECT_NAME(i.object_id) AS [TableName],
    i.name AS [IndexName],
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan,
    s.last_user_lookup
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s 
    ON i.object_id = s.object_id
    AND i.index_id = s.index_id
    AND s.database_id = DB_ID()
WHERE i.type_desc = 'NONCLUSTERED'
    AND i.is_primary_key = 0
    AND i.is_unique_constraint = 0
    AND (s.user_seeks = 0 OR s.user_seeks IS NULL)
    AND (s.user_scans = 0 OR s.user_scans IS NULL)
    AND (s.user_lookups = 0 OR s.user_lookups IS NULL)
    AND s.user_updates > 0  -- Being maintained but not used for reads
ORDER BY OBJECT_NAME(i.object_id), i.name;
