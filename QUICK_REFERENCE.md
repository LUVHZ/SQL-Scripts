# SQL-Scripts Index & Quick Reference

## 🎯 Finding Scripts by SQL Server Feature

### Always On Availability Groups
- **Setup & Monitor**: `high-availability/always_on_availability_groups.sql`
- Features: Create AG, add replicas, failover, listener config, health monitoring

### Log Shipping (Disaster Recovery)
- **Setup & Monitor**: `high-availability/log_shipping_setup.sql`
- Features: Primary/secondary setup, backup/restore job monitoring, failover procedures

### Database Mirroring (Legacy)
- **Setup & Monitor**: `high-availability/database_mirroring_setup.sql`
- Features: Endpoint creation, session setup, manual failover, status monitoring
- ⚠️ Note: Deprecated in SQL Server 2012+; use Always On instead

### SQL Replication
- **Setup & Monitor**: `high-availability/replication_setup.sql`
- Features: Publisher/subscriber setup, article management, agent monitoring

### Failover Clustering
- **Setup & Monitor**: `high-availability/failover_cluster_instance.sql`
- Features: Node health, quorum status, disk resources, manual failover

### Linked Servers
- **Setup & Monitor**: `high-availability/linked_servers.sql`
- Features: Create links, security config, test connectivity, OPENQUERY usage

### Database Mail
- **Setup & Monitor**: `administration/database_mail_setup.sql`
- Features: Account creation, profile setup, test delivery, troubleshooting

### Maintenance Jobs
- **Setup & Monitor**: `administration/maintenance_jobs_setup.sql`
- Features: Backup jobs, index maintenance, statistics updates, scheduling

---

## 📊 Finding Scripts by Task

### Setup & Configuration Tasks
| Task | Script |
|------|--------|
| Configure Always On | `high-availability/always_on_availability_groups.sql` |
| Setup Log Shipping | `high-availability/log_shipping_setup.sql` |
| Create Linked Server | `high-availability/linked_servers.sql` |
| Setup Database Mail | `administration/database_mail_setup.sql` |
| Create Maintenance Jobs | `administration/maintenance_jobs_setup.sql` |
| Manage Users & Logins | `administration/user_management.sql` |

### Monitoring & Diagnostics
| Task | Script |
|------|--------|
| Monitor CPU/Memory/IO | `monitoring/performance_counters.sql` |
| Track Database Growth | `monitoring/growth_rate_analysis.sql` |
| Analyze Resource Burn | `monitoring/burn_rate_analysis.sql` |
| Diagnose Blocking | `troubleshooting/diagnose_blocking_queries.sql` |
| Check Database Health | `troubleshooting/check_database_health.sql` |
| Monitor Tempdb | `troubleshooting/tempdb_usage.sql` |
| Check Disk Space | `troubleshooting/disk_space_usage.sql` |

### Performance Optimization
| Task | Script |
|------|--------|
| Find Missing Indexes | `performance-tuning/missing_indexes.sql` |
| Fix Fragmented Indexes | `performance-tuning/index_fragmentation.sql` |
| Update Statistics | `performance-tuning/table_statistics.sql` |

### Utilities
| Task | Script |
|------|--------|
| Get Server Info | `utilities/get_server_info.sql` |
| Create DDL Statements | `utilities/generate_sql_statements.sql` |
| Access Helper Functions | `utilities/common_functions.sql` |

### Auditing & Security
| Task | Script |
|------|--------|
| Audit Permissions | `administration/permission_audit.sql` |
| Backup Databases | `administration/database_backup.sql` |

---

## 🔍 Finding Scripts by Enterprise Feature

### High Availability & Disaster Recovery
- Always On Availability Groups: `high-availability/always_on_availability_groups.sql`
- Log Shipping: `high-availability/log_shipping_setup.sql`
- Database Mirroring: `high-availability/database_mirroring_setup.sql`
- Replication: `high-availability/replication_setup.sql`
- Clustering: `high-availability/failover_cluster_instance.sql`

### Monitoring & Capacity Planning
- Performance Counters: `monitoring/performance_counters.sql`
- Growth Rate Analysis: `monitoring/growth_rate_analysis.sql`
- Burn Rate Analysis: `monitoring/burn_rate_analysis.sql`

### Performance Tuning
- Missing Indexes: `performance-tuning/missing_indexes.sql`
- Index Fragmentation: `performance-tuning/index_fragmentation.sql`
- Statistics Updates: `performance-tuning/table_statistics.sql`

### Administration & Operations
- Backup: `administration/database_backup.sql`
- Users & Logins: `administration/user_management.sql`
- Permissions: `administration/permission_audit.sql`
- Database Mail: `administration/database_mail_setup.sql`
- Maintenance Jobs: `administration/maintenance_jobs_setup.sql`

### Troubleshooting & Diagnostics
- Blocking Queries: `troubleshooting/diagnose_blocking_queries.sql`
- Database Health: `troubleshooting/check_database_health.sql`
- Tempdb Usage: `troubleshooting/tempdb_usage.sql`
- Disk Space: `troubleshooting/disk_space_usage.sql`

---

## 📋 Common Workflow Combinations

### Daily Operations
1. `monitoring/performance_counters.sql` - Check system health
2. `troubleshooting/diagnose_blocking_queries.sql` - Any blocking?
3. `troubleshooting/disk_space_usage.sql` - Disk capacity OK?

### Weekly Maintenance
1. `performance-tuning/index_fragmentation.sql` - Rebuild/reorganize
2. `performance-tuning/table_statistics.sql` - Update stats
3. `administration/permission_audit.sql` - Security review

### Monthly Planning
1. `monitoring/growth_rate_analysis.sql` - Growth trends
2. `monitoring/burn_rate_analysis.sql` - Resource consumption
3. `utilities/get_server_info.sql` - Baseline config

### High Availability Setup
1. `high-availability/always_on_availability_groups.sql` - Setup AG
2. `high-availability/linked_servers.sql` - Cross-instance access
3. `administration/database_mail_setup.sql` - Alert notifications
4. `administration/maintenance_jobs_setup.sql` - Automation

### Troubleshooting Session
1. `troubleshooting/diagnose_blocking_queries.sql` - What's blocking?
2. `monitoring/performance_counters.sql` - System metrics
3. `troubleshooting/tempdb_usage.sql` - Temp space?
4. `troubleshooting/disk_space_usage.sql` - Disk capacity?
5. `troubleshooting/check_database_health.sql` - Database health?

---

## ⚡ Quick Command Examples

```sql
-- Monitor Always On status
USE master; GO
:r "high-availability/always_on_availability_groups.sql"

-- Check for blocking
USE master; GO
:r "troubleshooting/diagnose_blocking_queries.sql"

-- Analyze growth
USE master; GO
:r "monitoring/growth_rate_analysis.sql"

-- Setup automated jobs
USE msdb; GO
:r "administration/maintenance_jobs_setup.sql"

-- Performance baseline
USE master; GO
:r "monitoring/performance_counters.sql"

-- Find missing indexes
USE [DatabaseName]; GO
:r "performance-tuning/missing_indexes.sql"
```

---

## 📖 Each Script Includes

✓ **Purpose**: What the script does and why  
✓ **Usage**: How to run it and expected parameters  
✓ **Prerequisites**: What's needed before running  
✓ **Safety Notes**: Warnings and impact assessment  
✓ **Version Info**: SQL Server compatibility  
✓ **Examples**: Commented code showing how to use  
✓ **Troubleshooting**: How to diagnose issues  

---

## 🔗 Related Documentation

- **README.md** - Complete project overview
- **.github/copilot-instructions.md** - AI agent coding standards
- Each script's header - Specific usage instructions

---

*Last Updated: December 2025*
*SQL Server 2005+ Compatible*
*Production-Ready Scripts*
