/*
    Purpose: Configure and monitor SQL Server Failover Clustering for high availability
    Usage: Setup cluster resources, monitor cluster health, manage failovers
    Prerequisites: Windows Failover Cluster configured; shared storage; matching instances
    Safety Notes: Complex infrastructure change; requires cluster admin permissions
    Version: SQL Server 2008+
*/

SET NOCOUNT ON;

-- ============================================================================
-- 1. CHECK CLUSTER CONFIGURATION
-- ============================================================================
PRINT '=== FAILOVER CLUSTER CONFIGURATION ===';

SELECT 
    SERVERPROPERTY('ServerName') AS [InstanceName],
    SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [ComputerName],
    SERVERPROPERTY('InstanceName') AS [InstanceNameOnly],
    SERVERPROPERTY('IsClustered') AS [IsClustered],
    CASE WHEN SERVERPROPERTY('IsClustered') = 1 THEN 'Clustered' ELSE 'Standalone' END AS [ClusterStatus];

-- ============================================================================
-- 2. VIEW CLUSTER NODES
-- ============================================================================
PRINT '=== CLUSTER NODES ===';

SELECT 
    name AS [NodeName],
    status AS [Status],
    status_description AS [StatusDescription]
FROM sys.dm_hadr_cluster_members
ORDER BY name;

-- ============================================================================
-- 3. VIEW CLUSTER NETWORKS
-- ============================================================================
PRINT '=== CLUSTER NETWORKS ===';

SELECT 
    network_name AS [NetworkName],
    network_subnet_ip_prefix AS [SubnetIPPrefix],
    network_subnet_ipv4_mask AS [SubnetIPv4Mask],
    network_subnet_flags AS [Flags]
FROM sys.dm_hadr_cluster_networks
ORDER BY network_name;

-- ============================================================================
-- 4. FAILOVER CLUSTER INSTANCE (FCI) RESOURCES
-- ============================================================================
PRINT '=== SQL SERVER CLUSTER RESOURCES ===';

SELECT 
    resource_name AS [ResourceName],
    resource_type AS [ResourceType],
    owner_group AS [OwnerGroup],
    state AS [State],
    state_description AS [StateDescription]
FROM sys.dm_hadr_cluster_members
ORDER BY resource_name;

-- ============================================================================
-- 5. CHECK IP RESOURCE CONFIGURATION
-- ============================================================================
PRINT '=== IP ADDRESS RESOURCES ===';

SELECT 
    'SQL Server Network Name' AS [ResourceType],
    COUNT(*) AS [Count]
FROM sys.dm_hadr_cluster_networks;

-- ============================================================================
-- 6. MANUAL FAILOVER TO ANOTHER NODE (Uncomment to execute)
-- ============================================================================
/*
-- Run on cluster node you want to fail over FROM
ALTER AVAILABILITY GROUP [AGName] SET (ROLE = SECONDARY);

-- Wait for synchronization to complete, then on new primary
ALTER AVAILABILITY GROUP [AGName] SET (ROLE = PRIMARY);
*/

-- ============================================================================
-- 7. CHECK QUORUM CONFIGURATION
-- ============================================================================
PRINT '=== CLUSTER QUORUM STATUS ===';

SELECT 
    'Quorum Information' AS [Configuration],
    COUNT(*) AS [NodeCount]
FROM sys.dm_hadr_cluster_members
WHERE member_type = 1;  -- ClusterNode

-- ============================================================================
-- 8. VIEW DISK RESOURCES
-- ============================================================================
PRINT '=== CLUSTER DISK RESOURCES ===';

SELECT 
    'Check cluster disk resources using:' AS [Command],
    'Get-ClusterResource | Where {$_.ResourceType -eq "Physical Disk"} | fl' AS [PowerShellCommand];

-- ============================================================================
-- 9. MONITOR NODE STATUS
-- ============================================================================
PRINT '=== NODE HEALTH STATUS ===';

SELECT 
    node_name AS [NodeName],
    state AS [State],
    CASE 
        WHEN state = 1 THEN 'Up'
        WHEN state = 2 THEN 'Down'
        WHEN state = 3 THEN 'Paused'
        WHEN state = 4 THEN 'Joining'
        ELSE 'Unknown'
    END AS [StateDescription]
FROM sys.dm_hadr_cluster_members
ORDER BY node_name;

-- ============================================================================
-- 10. VERIFY CLUSTER NETWORK CONNECTIVITY
-- ============================================================================
PRINT '=== NETWORK CONNECTIVITY CHECK ===';

SELECT 
    network_name AS [NetworkName],
    network_subnet_ip_prefix AS [IPPrefix],
    'Verify network is accessible from all nodes' AS [Action]
FROM sys.dm_hadr_cluster_networks
ORDER BY network_name;

-- ============================================================================
-- 11. CLUSTER FAILOVER HISTORY
-- ============================================================================
PRINT '=== FAILOVER HISTORY ===';
PRINT 'Query Windows Event Log for cluster failover events';
PRINT 'Event IDs to monitor: 1000-1999 (Cluster Service)';
PRINT 'Source: System Event Log on cluster nodes';

-- ============================================================================
-- 12. TROUBLESHOOTING CHECKS
-- ============================================================================
PRINT '=== FAILOVER CLUSTER TROUBLESHOOTING ===';
PRINT '1. Verify all nodes are healthy and up';
PRINT '2. Check shared storage is accessible from all nodes';
PRINT '3. Verify quorum is healthy (witness required for even node count)';
PRINT '4. Check network connectivity between nodes';
PRINT '5. Review cluster validation report';
PRINT '6. Monitor cluster disk utilization';
PRINT '7. Verify SQL Server service can access cluster resources';
