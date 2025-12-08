# SQL-Scripts

A comprehensive collection of production-grade SQL Server scripts for database administration, performance tuning, and troubleshooting.

## 📋 Contents

### 📁 `administration/`
Administrative tasks for managing SQL Server instances and databases.

- **`user_management.sql`** - Create and manage SQL Server logins, database users, and permission management
- **`database_backup.sql`** - Full and differential database backups with integrity verification
- **`permission_audit.sql`** - Comprehensive audit of user permissions and role membership across the server
- **`database_mail_setup.sql`** - Configure Database Mail for alerts and notifications
- **`maintenance_jobs_setup.sql`** - Create and manage scheduled maintenance jobs (backups, index rebuilds, stats)

### 📁 `performance-tuning/`
Query optimization and index management for maintaining database performance.

- **`missing_indexes.sql`** - Identify missing indexes from query execution history; generate CREATE INDEX statements
- **`index_fragmentation.sql`** - Analyze, reorganize, and rebuild fragmented indexes
- **`table_statistics.sql`** - Update table statistics to maintain query optimizer effectiveness

### 📁 `troubleshooting/`
Diagnostic scripts for investigating database issues and anomalies.

- **`diagnose_blocking_queries.sql`** - Identify blocking sessions and their executing commands in real-time
- **`check_database_health.sql`** - Run DBCC integrity checks and validate database consistency
- **`tempdb_usage.sql`** - Monitor tempdb space consumption and identify heavy users
- **`disk_space_usage.sql`** - Track data/log file sizes and alert on capacity issues

### 📁 `high-availability/`
High availability and disaster recovery configuration and monitoring.

- **`always_on_availability_groups.sql`** - Configure and monitor Always On Availability Groups
- **`log_shipping_setup.sql`** - Setup and monitor log shipping for disaster recovery
- **`database_mirroring_setup.sql`** - Configure database mirroring (note: deprecated in SQL 2012+)
- **`replication_setup.sql`** - Setup and monitor SQL Server replication
- **`failover_cluster_instance.sql`** - Configure and monitor failover clustering
- **`linked_servers.sql`** - Create and manage linked server connections

### 📁 `monitoring/`
Real-time and trend-based monitoring for performance analysis and capacity planning.

- **`performance_counters.sql`** - Monitor SQL Server performance counters (CPU, memory, I/O, cache hit ratio)
- **`growth_rate_analysis.sql`** - Analyze database growth trends and forecast future capacity needs
- **`burn_rate_analysis.sql`** - Monitor resource consumption rates (memory, disk, log, CPU)

### 📁 `utilities/`
Reusable helper functions and utility scripts used by other scripts.

- **`get_server_info.sql`** - Collect comprehensive SQL Server configuration and environment details
- **`common_functions.sql`** - Reusable T-SQL functions for byte formatting, object validation, etc.
- **`generate_sql_statements.sql`** - Generate DDL statements for existing objects (tables, indexes, procedures)

## 🚀 Quick Start

### Prerequisites
- SQL Server 2016+ (earlier versions may work with modifications)
- Appropriate permissions (sysadmin for some operations, VIEW SERVER STATE for diagnostics)
- SSMS or other SQL query tool

### Basic Usage

1. **Review** the script header to understand purpose, prerequisites, and safety notes
2. **Modify parameters** (database names, paths, thresholds) as needed for your environment
3. **Test in development** first, especially for write operations
4. **Execute** during appropriate maintenance windows where applicable

### Example: Check Database Health
```sql
USE [YourDatabaseName];
GO
:r "troubleshooting/check_database_health.sql"
```

### Example: Find Missing Indexes
```sql
USE [YourDatabaseName];
GO
:r "performance-tuning/missing_indexes.sql"
```

## 🔒 Safety and Best Practices

- **Backup First**: Always backup databases before running administrative scripts
- **Test in Dev**: Validate scripts in development/test environments before production use
- **Review Carefully**: Read the "Safety Notes" section in each script header
- **Schedule Wisely**: Run maintenance scripts (index rebuilds, statistics) during low-activity windows
- **Monitor Impact**: Watch for locking/blocking impact during execution
- **Document Changes**: Keep audit trail of when and why scripts were executed

## 📊 Common Workflows

### Performance Baseline (Monthly)
1. `performance-tuning/missing_indexes.sql` - Identify optimization opportunities
2. `performance-tuning/index_fragmentation.sql` - Check index health
3. `performance-tuning/table_statistics.sql` - Update query optimizer data

### Capacity Planning (Monthly)
1. `monitoring/growth_rate_analysis.sql` - Analyze size trends
2. `monitoring/burn_rate_analysis.sql` - Monitor resource consumption
3. `troubleshooting/disk_space_usage.sql` - Check available space

### Troubleshooting High Activity
1. `troubleshooting/diagnose_blocking_queries.sql` - Find blocking sessions
2. `troubleshooting/tempdb_usage.sql` - Check for runaway temp space usage
3. `monitoring/performance_counters.sql` - Monitor system metrics
4. `troubleshooting/disk_space_usage.sql` - Verify sufficient disk capacity

### Health Check (Weekly/Monthly)
1. `troubleshooting/check_database_health.sql` - DBCC integrity validation
2. `administration/permission_audit.sql` - Verify proper access controls
3. `utilities/get_server_info.sql` - Baseline server configuration

### High Availability Setup
1. `high-availability/always_on_availability_groups.sql` - Always On AG configuration
2. `high-availability/log_shipping_setup.sql` - Log shipping for DR
3. `high-availability/failover_cluster_instance.sql` - FCI monitoring
4. `high-availability/linked_servers.sql` - Cross-instance queries

### Maintenance Automation
1. `administration/maintenance_jobs_setup.sql` - Schedule backups, index rebuilds, stats
2. `administration/database_mail_setup.sql` - Configure email notifications
3. `administration/permission_audit.sql` - Regular permission reviews

## 🔧 Script Customization

Most scripts include customizable parameters in comments:
```sql
DECLARE @DatabaseName NVARCHAR(128) = 'YourDatabaseName';
DECLARE @BackupPath NVARCHAR(500) = 'C:\Backups\';
```

Edit these variables before running based on your environment.

## 📝 Version Support

All scripts target **SQL Server 2016+** by default. Some scripts note specific version requirements:
- `--SQL 2019+` indicates features only available in SQL Server 2019 or later
- `--Azure SQL compatible` indicates scripts work with Azure SQL Database

Check individual script headers for version-specific notes.

## 🐛 Troubleshooting Issues

**Permission Denied Errors**: Verify you have sysadmin or required VIEW SERVER STATE permission

**Script Not Found**: Use `:r` command in SSMS to reference relative paths, or use full absolute path

**Unexpected Results**: Review the script's WHERE clauses - they may exclude system tables or have thresholds (e.g., "only tables > 1000 pages")

## 📚 Additional Resources

- [SQL Server Documentation](https://learn.microsoft.com/en-us/sql/sql-server/)
- [T-SQL Best Practices](https://learn.microsoft.com/en-us/sql/t-sql/statements/)
- [Query Performance Tuning](https://learn.microsoft.com/en-us/sql/relational-databases/query-processing-and-optimization/)

## 📄 License

This repository contains educational SQL scripts. Review and test all scripts before production use.

## 🤝 Contributing

To add new scripts:
1. Follow the directory structure (`administration/`, `performance-tuning/`, `troubleshooting/`, `utilities/`)
2. Include complete header with purpose, usage, prerequisites, and safety notes
3. Add inline comments explaining complex logic
4. Use descriptive file names (e.g., `diagnose_blocking_queries.sql`)
5. Test thoroughly in non-production environments

See `.github/copilot-instructions.md` for detailed coding standards.
