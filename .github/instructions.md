# AI Coding Agent Instructions for SQL-Scripts

## Project Overview
This repository contains SQL scripts and utilities for database administration, performance tuning, and troubleshooting. It focuses on production-grade SQL solutions with emphasis on clarity and reusability.

## Key Principles

### SQL Script Standards
- **Format & Comments**: Always include clear headers with purpose, parameters, prerequisites, and usage examples
- **Production Safety**: Include safety checks (existence validation, backup reminders, transaction handling)
- **Documentation**: Each script should be self-documenting with inline comments explaining complex logic
- **File Naming**: Use descriptive names reflecting the script's purpose (e.g., `diagnose_blocking_queries.sql`, `optimize_index_fragmentation.sql`)

### Directory Organization
Scripts are organized by functional area:

```
/administration/          - Admin tasks (user management, backups, maintenance jobs, mail)
/performance-tuning/      - Query optimization, index management, statistics
/troubleshooting/         - Diagnostic scripts for investigating issues
/high-availability/       - HA/DR setup (Always On, Log Shipping, Replication, Clustering, Linked Servers)
/monitoring/              - Performance counters, growth rate, burn rate analysis
/utilities/               - Helper functions and reusable procedures
```

### SQL Server Coverage
Scripts cover these enterprise SQL Server features:
- **Always On Availability Groups** - Multi-replica synchronous/async replication
- **Log Shipping** - Asynchronous DR with log backups
- **Database Mirroring** - Legacy synchronous replication (deprecated)
- **Replication** - Publisher/Subscriber distribution model
- **Failover Clustering** - Shared storage high availability
- **Linked Servers** - Remote query execution and heterogeneous joins
- **Database Mail** - Email notifications and alerts
- **Maintenance Jobs** - Automated backup, index, statistics management
- **Performance Monitoring** - Counters, metrics, capacity planning
- **Burn Rate Analysis** - Resource consumption trending

### Database Compatibility
- Target SQL Server 2016+ unless otherwise specified
- Note any version-specific features (e.g., `--SQL 2019+`, `--Azure SQL compatible`)
- Include fallback queries for older versions when possible
- Document Enterprise vs Standard Edition requirements

## Development Patterns

### SQL Best Practices to Follow
1. **Error Handling**: Use TRY-CATCH blocks with meaningful error messages
2. **Performance**: Optimize for readability first; add performance hints with explanation
3. **Transactions**: Be explicit about transaction scope; use `SET XACT_ABORT ON` for safety
4. **Testing Context**: Scripts should include sample execution scenarios in comments

### Documentation Requirements
Every new script must include:
```sql
/*
    Purpose: [What this script does]
    Usage: [How to run it and expected parameters]
    Prerequisites: [Required permissions, objects, or state]
    Safety Notes: [Any warnings about impact]
    Version: SQL Server 2019+ (or specify compatibility)
*/
```

## When to Ask for Clarification
- Database version or compatibility requirements not stated
- Scope of intended impact (single database vs. instance-wide)
- Performance constraints or acceptance criteria for optimization scripts
- Whether this is for diagnostic/readonly or operational/write purposes

## Common Tasks
- **Adding a diagnostic script**: Create in `/troubleshooting/`, include sample output format
- **Performance tuning utility**: Place in `/performance-tuning/`, reference execution examples
- **Admin operation script**: Add to `/administration/`, emphasize safety checks
