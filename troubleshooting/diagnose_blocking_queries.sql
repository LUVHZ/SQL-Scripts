/*
    Purpose: Identify blocking queries and deadlocks in real-time
    Usage: Run during performance issues to pinpoint blocking relationships
    Prerequisites: VIEW SERVER STATE permission
    Safety Notes: Read-only diagnostic; use to inform blocking mitigation strategy
    Version: SQL Server 2016+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. IDENTIFY CURRENT BLOCKING (Real-time)
-- ============================================================================
PRINT '=== CURRENT BLOCKING CHAINS ===';

WITH BlockingCTE AS (
    SELECT 
        session_id,
        blocking_session_id,
        wait_duration_ms,
        wait_type,
        last_wait_type,
        NULL AS [chain_level]
    FROM sys.dm_exec_requests
    WHERE session_id > 50  -- Exclude system sessions
)
SELECT 
    er.session_id,
    er.blocking_session_id,
    er.wait_duration_ms,
    er.wait_type,
    er.status,
    es.login_name,
    SUBSTRING(st.text, (er.statement_start_offset/2)+1, 
        ((CASE 
            WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text))
            ELSE er.statement_end_offset
        END - er.statement_start_offset)/2) + 1) AS [ExecutingCommand],
    db_name(er.database_id) AS [Database],
    er.start_time
FROM sys.dm_exec_requests er
INNER JOIN sys.dm_exec_sessions es 
    ON er.session_id = es.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE er.session_id > 50
    AND er.blocking_session_id > 0  -- Only show blocked sessions
ORDER BY er.blocking_session_id, er.session_id;

-- ============================================================================
-- 2. SHOW BLOCKERS (Blocking other sessions)
-- ============================================================================
PRINT '=== BLOCKING SESSION DETAILS ===';

SELECT 
    er.session_id AS [BlockingSessionID],
    es.login_name AS [LoginName],
    es.host_name AS [HostName],
    er.status,
    er.last_wait_type,
    er.cpu_time,
    er.total_elapsed_time,
    SUBSTRING(st.text, (er.statement_start_offset/2)+1, 
        ((CASE 
            WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), st.text))
            ELSE er.statement_end_offset
        END - er.statement_start_offset)/2) + 1) AS [ExecutingCommand],
    CONVERT(VARCHAR(23), er.start_time, 121) AS [StartTime]
FROM sys.dm_exec_requests er
INNER JOIN sys.dm_exec_sessions es 
    ON er.session_id = es.session_id
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE er.session_id IN (
    SELECT DISTINCT blocking_session_id 
    FROM sys.dm_exec_requests 
    WHERE blocking_session_id > 0
);

-- ============================================================================
-- 3. LOCKS HELD BY SESSIONS
-- ============================================================================
PRINT '=== LOCKS AND WAIT INFORMATION ===';

SELECT 
    er.session_id,
    es.login_name,
    er.wait_type,
    er.wait_time_ms,
    er.last_wait_type,
    OBJECT_NAME(l.resource_associated_entity_id) AS [LockedObject],
    l.resource_type,
    l.request_mode,
    l.request_status
FROM sys.dm_exec_requests er
INNER JOIN sys.dm_exec_sessions es 
    ON er.session_id = es.session_id
LEFT JOIN sys.dm_tran_locks l 
    ON er.session_id = l.request_session_id
WHERE er.session_id > 50
    AND l.request_status IN ('GRANT', 'WAIT')
ORDER BY er.session_id, l.resource_type;

-- ============================================================================
-- 4. IDENTIFY DEADLOCK VICTIMS
-- ============================================================================
PRINT '=== RECENT DEADLOCKS (from system health) ===';

-- Note: Requires Query Store or SQL Trace to be available
SELECT 
    er.session_id,
    er.connection_id,
    es.login_name,
    er.status,
    er.wait_type,
    OBJECT_NAME(l.resource_associated_entity_id) AS [LockedObject]
FROM sys.dm_exec_requests er
INNER JOIN sys.dm_exec_sessions es 
    ON er.session_id = es.session_id
LEFT JOIN sys.dm_tran_locks l 
    ON er.session_id = l.request_session_id
WHERE er.session_id > 50
ORDER BY er.session_id;

-- ============================================================================
-- 5. KILL BLOCKING SESSION (DANGEROUS - Use with caution)
-- ============================================================================
-- To kill a blocking session, uncomment and replace session_id:
-- KILL [session_id];  -- Where session_id is the blocking_session_id from query 1

PRINT '=== To terminate a blocking session, use: KILL [session_id] ===';
PRINT '=== Example: KILL 52 ===';
