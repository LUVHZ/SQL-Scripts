/*
    Purpose: Setup and monitor SQL Server database mirroring for synchronous replication
    Usage: Configure principal and mirror servers, monitor mirroring status
    Prerequisites: Enterprise Edition or Standard (with limitations); matching databases; mirroring endpoints
    Safety Notes: High availability feature; test failover in non-prod first
    Version: SQL Server 2005+ (deprecated in SQL Server 2012+, use Always On instead)
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. CREATE MIRRORING ENDPOINT (Run on both principal and mirror)
-- ============================================================================
PRINT '=== DATABASE MIRRORING SETUP ===';

/*
-- On Principal Server
CREATE ENDPOINT Mirroring
    STATE = STARTED
    AS TCP (
        LISTENER_PORT = 5022,
        LISTENER_IP = ALL
    )
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = WINDOWS NTLM,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );

-- On Mirror Server
CREATE ENDPOINT Mirroring
    STATE = STARTED
    AS TCP (
        LISTENER_PORT = 5022,
        LISTENER_IP = ALL
    )
    FOR DATABASE_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = WINDOWS NTLM,
        ENCRYPTION = REQUIRED ALGORITHM AES
    );
*/

-- ============================================================================
-- 2. SETUP MIRRORING SESSION (Run on Principal)
-- ============================================================================
/*
-- First, take full backup on principal
BACKUP DATABASE [YourDatabase] 
TO DISK = N'C:\Backups\YourDatabase_Full.bak' 
WITH INIT, COMPRESSION;

-- Take log backup
BACKUP LOG [YourDatabase] 
TO DISK = N'C:\Backups\YourDatabase_Log.trn' 
WITH INIT, COMPRESSION;

-- Restore on mirror with NORECOVERY
RESTORE DATABASE [YourDatabase] 
FROM DISK = N'\\\\PrincipalServer\\Backups\\YourDatabase_Full.bak' 
WITH NORECOVERY;

RESTORE LOG [YourDatabase] 
FROM DISK = N'\\\\PrincipalServer\\Backups\\YourDatabase_Log.trn' 
WITH NORECOVERY;

-- Setup mirroring on principal
ALTER DATABASE [YourDatabase]
SET PARTNER = N'TCP://MirrorServer.domain.com:5022';

-- Setup on mirror
ALTER DATABASE [YourDatabase]
SET PARTNER = N'TCP://PrincipalServer.domain.com:5022';
*/

-- ============================================================================
-- 3. VIEW MIRRORING STATUS
-- ============================================================================
PRINT '=== MIRRORING STATUS ===';

SELECT 
    d.name AS [DatabaseName],
    d.mirroring_state_desc AS [MirroringState],
    d.mirroring_role_desc AS [MirroringRole],
    d.mirroring_partner_name AS [PartnerServer],
    d.mirroring_partner_instance AS [PartnerInstance],
    d.mirroring_safety_level_desc AS [SafetyLevel],
    d.mirroring_witness_name AS [WitnessServer],
    d.mirroring_witness_state_desc AS [WitnessState]
FROM sys.database_mirroring d
WHERE d.mirroring_state_desc IS NOT NULL
ORDER BY d.name;

-- ============================================================================
-- 4. DETAILED MIRRORING STATS
-- ============================================================================
PRINT '=== MIRRORING PERFORMANCE METRICS ===';

SELECT 
    d.name AS [DatabaseName],
    dms.mirroring_state_desc AS [State],
    dms.mirroring_role_desc AS [Role],
    dms.partner_name AS [Partner],
    dms.log_send_queue_size AS [LogSendQueueSize],
    dms.log_send_rate_kb_per_sec AS [LogSendRateKB],
    dms.redo_queue_size AS [RedoQueueSize],
    dms.redo_rate_kb_per_sec AS [RedoRateKB],
    dms.synchronization_health_desc AS [HealthStatus],
    dms.last_hardened_lsn AS [LastHardenedLSN],
    dms.last_sent_lsn AS [LastSentLSN],
    dms.last_received_lsn AS [LastReceivedLSN],
    dms.last_redone_lsn AS [LastRedoneLSN]
FROM sys.databases d
LEFT JOIN sys.dm_database_mirroring_auto_page_repair dms 
    ON d.database_id = dms.database_id
WHERE d.mirroring_state IS NOT NULL
ORDER BY d.name;

-- ============================================================================
-- 5. VIEW MIRRORING ENDPOINTS
-- ============================================================================
PRINT '=== MIRRORING ENDPOINTS ===';

SELECT 
    e.name AS [EndpointName],
    e.endpoint_id,
    e.state_desc AS [State],
    e.type_desc AS [Type],
    e.protocol_desc AS [Protocol],
    e.port AS [Port],
    ep.role_desc AS [Role]
FROM sys.endpoints e
INNER JOIN sys.database_mirroring_endpoints ep 
    ON e.endpoint_id = ep.endpoint_id
ORDER BY e.name;

-- ============================================================================
-- 6. MONITOR MIRRORING LATENCY
-- ============================================================================
PRINT '=== MIRRORING LATENCY ANALYSIS ===';

SELECT 
    d.name AS [DatabaseName],
    CASE 
        WHEN d.mirroring_role_desc = 'PRINCIPAL' THEN 'Principal'
        WHEN d.mirroring_role_desc = 'MIRROR' THEN 'Mirror'
        ELSE 'Unknown'
    END AS [Role],
    DATEDIFF(SECOND, GETDATE(), GETDATE()) AS [LatencySeconds]
FROM sys.databases d
WHERE d.mirroring_state IS NOT NULL
ORDER BY d.name;

-- ============================================================================
-- 7. MANUAL FAILOVER (Run on Principal)
-- ============================================================================
/*
ALTER DATABASE [YourDatabase] SET PARTNER OFF;  -- Disconnect mirror
ALTER DATABASE [YourDatabase] SET PARTNER FAILOVER;  -- Failover
*/

-- ============================================================================
-- 8. REMOVE MIRRORING (CAUTION)
-- ============================================================================
/*
-- On principal
ALTER DATABASE [YourDatabase] SET PARTNER OFF;

-- On mirror
ALTER DATABASE [YourDatabase] SET PARTNER OFF;
*/

-- ============================================================================
-- 9. TROUBLESHOOTING
-- ============================================================================
PRINT '=== MIRRORING TROUBLESHOOTING ===';
PRINT 'Common Issues:';
PRINT '1. Authentication failed - Verify Windows login permissions on both servers';
PRINT '2. Endpoint not accessible - Check firewall, port 5022 open';
PRINT '3. Mirroring suspended - Check network connectivity and log space';
PRINT '4. High latency - Check network bandwidth and disk I/O';
PRINT ' ';
PRINT 'Note: Database Mirroring is deprecated. Use Always On Availability Groups instead.';
