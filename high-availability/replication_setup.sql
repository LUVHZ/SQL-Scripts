/*
    Purpose: Configure and monitor SQL Server replication for distributing data
    Usage: Setup publisher, distributor, and subscribers; monitor replication agents
    Prerequisites: Network connectivity; sufficient disk space; appropriate login permissions
    Safety Notes: Complex setup; requires careful planning for circular replication
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. ENABLE REPLICATION ON INSTANCE
-- ============================================================================
PRINT '=== SQL SERVER REPLICATION SETUP ===';

/*
-- Run sp_adddistributor on Publisher (if distributor is local)
USE master;
GO

sp_adddistributor @distributor = @@SERVERNAME, 
    @password = N'StrongPassword123!';
GO

-- Create distribution database
sp_adddistributiondb
    @database = N'distribution',
    @data_folder = N'C:\Replication\Data\',
    @log_folder = N'C:\Replication\Log\',
    @log_file_size = 2,
    @min_distretention = 0,
    @max_distretention = 72,
    @history_retention = 48,
    @history_cleanup_agent_interval = 1;
GO

-- Enable distribution subscriber
sp_adddistpublisher
    @publisher = @@SERVERNAME,
    @distribution_db = N'distribution',
    @security_mode = 1,
    @working_directory = N'C:\ReplData\\';
GO
*/

-- ============================================================================
-- 2. VIEW REPLICATION CONFIGURATION
-- ============================================================================
PRINT '=== REPLICATION PUBLISHERS ===';

SELECT 
    name AS [PublisherName],
    distribution_db AS [DistributionDatabase],
    security_mode AS [SecurityMode],
    login_name AS [LoginName],
    password_date AS [PasswordDate]
FROM msdb.dbo.MSdistpublishers
ORDER BY name;

-- ============================================================================
-- 3. VIEW PUBLICATIONS
-- ============================================================================
PRINT '=== PUBLICATIONS ===';

SELECT 
    p.name AS [PublicationName],
    p.publication_id,
    p.pubid,
    p.publication_type AS [Type],
    p.status AS [Status],
    p.creation_date,
    a.name AS [ArticleCount]
FROM msdb.dbo.MSpublications p
LEFT JOIN (
    SELECT publication_id, COUNT(*) AS name
    FROM msdb.dbo.MSpublication_access
    GROUP BY publication_id
) a ON p.publication_id = a.publication_id
ORDER BY p.name;

-- ============================================================================
-- 4. CREATE PUBLICATION (Example - Uncomment to use)
-- ============================================================================
/*
USE [YourDatabase];
GO

EXEC sp_addpublication
    @publication = N'MyPublication',
    @description = N'Publication for distribution',
    @sync_method = N'concurrent',
    @retention = 0,
    @allow_push = 1,
    @allow_pull = 1,
    @allow_anonymous = 0,
    @enabled_for_internet = 0,
    @snapshot_in_defaultfolder = 1,
    @compress_snapshot = 0,
    @ftp_address = NULL,
    @ftp_port = 21,
    @ftp_subdirectory = NULL,
    @ftp_login = NULL,
    @alt_snapshot_folder = NULL,
    @pre_snapshot_script = NULL,
    @post_snapshot_script = NULL,
    @replicate_ddl = 1,
    @enabled_for_p2p = 0;
GO
*/

-- ============================================================================
-- 5. ADD ARTICLES TO PUBLICATION (Example)
-- ============================================================================
/*
EXEC sp_addarticle
    @publication = N'MyPublication',
    @article = N'TableName',
    @source_owner = N'dbo',
    @source_object = N'TableName',
    @type = N'logbased',
    @description = NULL,
    @creation_script = NULL,
    @pre_creation_cmd = N'drop',
    @schema_option = 0x000000000B03B0DD,
    @destination_table = N'TableName',
    @destination_owner = N'dbo',
    @vertical_partition = N'false',
    @updatable = 0;
GO
*/

-- ============================================================================
-- 6. VIEW SUBSCRIBERS
-- ============================================================================
PRINT '=== SUBSCRIBERS ===';

SELECT 
    s.name AS [SubscriberName],
    s.subscriber_id,
    s.type AS [SubscriberType],
    s.login_name AS [LoginName],
    s.distribution_db AS [DistributionDatabase]
FROM msdb.dbo.MSsubscriber_info s
ORDER BY s.name;

-- ============================================================================
-- 7. VIEW SUBSCRIPTIONS
-- ============================================================================
PRINT '=== SUBSCRIPTIONS ===';

SELECT 
    p.name AS [PublicationName],
    sub.subscriber_db AS [SubscriberDatabase],
    sub.subscriber_id,
    sub.status AS [Status],
    sub.subscription_type AS [Type]
FROM msdb.dbo.MSsubscriptions sub
INNER JOIN msdb.dbo.MSpublications p 
    ON sub.publication_id = p.publication_id
ORDER BY p.name, sub.subscriber_db;

-- ============================================================================
-- 8. MONITOR REPLICATION AGENTS
-- ============================================================================
PRINT '=== REPLICATION AGENT STATUS ===';

SELECT 
    a.agent_id,
    a.name AS [AgentName],
    a.agent_type AS [AgentType],
    CASE 
        WHEN a.agent_type = 1 THEN 'Snapshot'
        WHEN a.agent_type = 2 THEN 'Log Reader'
        WHEN a.agent_type = 3 THEN 'Distribution'
        WHEN a.agent_type = 4 THEN 'Merge'
        WHEN a.agent_type = 9 THEN 'Queue Reader'
    END AS [AgentTypeDesc],
    a.profile_id,
    a.job_id
FROM msdb.dbo.MSagent a
ORDER BY a.name;

-- ============================================================================
-- 9. VIEW AGENT HISTORY
-- ============================================================================
PRINT '=== REPLICATION AGENT HISTORY (Last 10 executions) ===';

SELECT TOP 10
    ah.agent_id,
    ah.agent_type,
    ah.runstatus AS [Status],
    ah.start_time,
    ah.time AS [Duration],
    ah.comments AS [Message]
FROM msdb.dbo.MSagent_history ah
ORDER BY ah.agent_id, ah.start_time DESC;

-- ============================================================================
-- 10. CHECK REPLICATION HEALTH
-- ============================================================================
PRINT '=== REPLICATION HEALTH CHECK ===';

SELECT 
    'Check agent profiles' AS [HealthCheck],
    COUNT(*) AS [Count]
FROM msdb.dbo.MSagent
WHERE enabled = 1

UNION ALL

SELECT 
    'Active subscriptions',
    COUNT(*)
FROM msdb.dbo.MSsubscriptions
WHERE status = 2;  -- Subscribed

-- ============================================================================
-- 11. TROUBLESHOOTING QUERIES
-- ============================================================================
PRINT '=== REPLICATION TROUBLESHOOTING ===';
PRINT 'Common checks:';
PRINT '1. Verify all replication agents are running';
PRINT '2. Check agent job history for errors';
PRINT '3. Verify subscriber connectivity and database exists';
PRINT '4. Check for constraint violations on subscriber';
PRINT '5. Monitor replication latency with sp_replmonitorsubscriptionstatus';
