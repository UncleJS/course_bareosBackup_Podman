# Chapter 14: Backing Up Database Containers (MariaDB and PostgreSQL)

## Table of Contents

- [1. Why Database Backup Is Fundamentally Different](#1-why-database-backup-is-fundamentally-different)
- [2. The Three Backup Approaches](#2-the-three-backup-approaches)
  - [2.1 Logical Dump](#21-logical-dump)
  - [2.2 Physical Backup with Container Stopped](#22-physical-backup-with-container-stopped)
  - [2.3 Online Physical Backup with mariabackup / pg_basebackup](#23-online-physical-backup-with-mariabackup-pg_basebackup)
- [3. MariaDB in Containers: Where the Data Lives](#3-mariadb-in-containers-where-the-data-lives)
  - [3.1 The Named Volume](#31-the-named-volume)
  - [3.2 Finding the Physical Path on the Host](#32-finding-the-physical-path-on-the-host)
  - [3.3 The db.env Secrets File](#33-the-dbenv-secrets-file)
- [4. MariaDB Logical Backup with mariadb-dump](#4-mariadb-logical-backup-with-mariadb-dump)
  - [4.1 What mariadb-dump Produces](#41-what-mariadb-dump-produces)
  - [4.2 Running mariadb-dump via podman exec](#42-running-mariadb-dump-via-podman-exec)
  - [4.3 Dumping All Databases](#43-dumping-all-databases)
  - [4.4 Where to Store the Dump File](#44-where-to-store-the-dump-file)
- [5. MariaDB Physical Backup: Stopping the Container](#5-mariadb-physical-backup-stopping-the-container)
  - [5.1 The Stop/Start Approach](#51-the-stopstart-approach)
  - [5.2 Pre/Post Scripts](#52-prepost-scripts)
  - [5.3 The Physical Data Path](#53-the-physical-data-path)
- [6. MariaDB Binary Logs and Point-in-Time Recovery](#6-mariadb-binary-logs-and-point-in-time-recovery)
  - [6.1 What Binary Logs Are](#61-what-binary-logs-are)
  - [6.2 Enabling Binary Logs in the Container](#62-enabling-binary-logs-in-the-container)
  - [6.3 Backing Up Binary Logs](#63-backing-up-binary-logs)
  - [6.4 Point-in-Time Recovery Concept](#64-point-in-time-recovery-concept)
- [7. mariabackup: Online Physical Backup](#7-mariabackup-online-physical-backup)
  - [7.1 What mariabackup Is](#71-what-mariabackup-is)
  - [7.2 Running mariabackup Inside the Container](#72-running-mariabackup-inside-the-container)
  - [7.3 Preparing the Backup](#73-preparing-the-backup)
  - [7.4 Incremental Backups with mariabackup](#74-incremental-backups-with-mariabackup)
- [8. PostgreSQL in Containers](#8-postgresql-in-containers)
  - [8.1 pg_dump: Logical Backup of a Single Database](#81-pg_dump-logical-backup-of-a-single-database)
  - [8.2 pg_dumpall: Dump All Databases Including Global Objects](#82-pg_dumpall-dump-all-databases-including-global-objects)
  - [8.3 pg_basebackup: Physical Online Backup](#83-pg_basebackup-physical-online-backup)
  - [8.4 Hook Script for PostgreSQL Logical Backup](#84-hook-script-for-postgresql-logical-backup)
- [9. PostgreSQL WAL Archiving Concept](#9-postgresql-wal-archiving-concept)
  - [9.1 Enabling WAL Archiving](#91-enabling-wal-archiving)
  - [9.2 Using WAL Archives for PITR](#92-using-wal-archives-for-pitr)
- [10. The Bareos Catalog Database: Special Considerations](#10-the-bareos-catalog-database-special-considerations)
  - [10.1 The Chicken-and-Egg Problem](#101-the-chicken-and-egg-problem)
  - [10.2 Catalog Backup Frequency](#102-catalog-backup-frequency)
  - [10.3 The Backup-Catalog Job in the Default Configuration](#103-the-backup-catalog-job-in-the-default-configuration)
- [11. make_catalog_backup.pl: The Built-in Bareos Catalog Script](#11-make_catalog_backuppl-the-built-in-bareos-catalog-script)
  - [11.1 What It Does](#111-what-it-does)
  - [11.2 Where to Find It](#112-where-to-find-it)
  - [11.3 How to Use It](#113-how-to-use-it)
  - [11.4 The Corresponding Cleanup Script](#114-the-corresponding-cleanup-script)
  - [11.5 Adapting for Container Environments](#115-adapting-for-container-environments)
- [12. Complete Bareos Job for MariaDB Container Backup](#12-complete-bareos-job-for-mariadb-container-backup)
  - [12.1 The Hook Script](#121-the-hook-script)
  - [12.2 The Bareos FileSet](#122-the-bareos-fileset)
  - [12.3 The Bareos Job](#123-the-bareos-job)
  - [12.4 The Schedule](#124-the-schedule)
- [13. Complete Bareos Job for PostgreSQL Container Backup](#13-complete-bareos-job-for-postgresql-container-backup)
  - [13.1 The Hook Script](#131-the-hook-script)
  - [13.2 The Bareos FileSet](#132-the-bareos-fileset)
  - [13.3 The Bareos Job](#133-the-bareos-job)
- [14. Complete Bareos Job for the Bareos Catalog](#14-complete-bareos-job-for-the-bareos-catalog)
  - [14.1 The Catalog Backup Script](#141-the-catalog-backup-script)
  - [14.2 The Bareos Job Configuration](#142-the-bareos-job-configuration)
  - [14.3 The Catalog FileSet](#143-the-catalog-fileset)
- [15. Restoring a MariaDB Container Database from a Logical Dump](#15-restoring-a-mariadb-container-database-from-a-logical-dump)
  - [15.1 Restore Procedure Overview](#151-restore-procedure-overview)
  - [15.2 Step 1: Restore the Dump File via Bareos](#152-step-1-restore-the-dump-file-via-bareos)
  - [15.3 Step 2: Decompress and Restore](#153-step-2-decompress-and-restore)
  - [15.4 Step 3: Verify the Restore](#154-step-3-verify-the-restore)
  - [15.5 Restoring a Single Database](#155-restoring-a-single-database)
- [16. Restoring a PostgreSQL Container Database from pg_dumpall](#16-restoring-a-postgresql-container-database-from-pg_dumpall)
  - [16.1 Retrieve the Dump File](#161-retrieve-the-dump-file)
  - [16.2 Restore All Databases](#162-restore-all-databases)
  - [16.3 Restore a Single Database from pg_dump Custom Format](#163-restore-a-single-database-from-pg_dump-custom-format)
- [Lab 14-1: Full MariaDB Container Backup](#lab-14-1-full-mariadb-container-backup)
- [Lab 14-2: Point-in-Time Restore of MariaDB Container Database](#lab-14-2-point-in-time-restore-of-mariadb-container-database)
- [Lab 14-3: Backup and Restore the Bareos Catalog](#lab-14-3-backup-and-restore-the-bareos-catalog)
- [20. Summary](#20-summary)

## 1. Why Database Backup Is Fundamentally Different

When you back up a plain directory full of files — configuration files, log files, documents — the process is straightforward: Bareos reads each file from disk and streams it to the Storage Daemon. Because these files are not being modified while the backup runs (or at least not in a way that corrupts the backup), the resulting archive is reliable.

Databases break this assumption completely.

A running database engine like MariaDB or PostgreSQL does not simply write one record per file. Instead, it maintains a complex set of binary data structures spread across multiple files: the tablespace files (InnoDB `.ibd` files for MariaDB, base directory files for PostgreSQL), write-ahead logs (binary logs in MariaDB, WAL files in PostgreSQL), undo logs, redo logs, and in-memory caches that have not yet been flushed to disk. At any given moment, the database may be in the middle of a multi-file transaction. If you copy those files while the database is running, you are virtually guaranteed to capture an inconsistent state — some files from "before" a commit and some files from "after" it — and when you restore from those files, the database engine will either refuse to start or silently corrupt your data.

This is called a **crash-inconsistent backup**, and it is the most dangerous kind: it looks like it worked, but it produces a database that does not reflect any real point in time.

**What "consistency" means for a database:**

A consistent database backup is one where every file in the backup reflects the same logical moment in time — the same transaction boundary. When you restore from it, the database engine can start cleanly, replay any pending transactions from the log, and arrive at a correct state.

**Three ways to achieve consistency:**

1. **Logical dump** — Ask the database engine itself to export all data as SQL statements. The engine handles consistency internally. Output is human-readable SQL.
2. **Physical backup with the database stopped** — Stop the database, copy the raw data files, then restart. No engine is running, so no inconsistency is possible.
3. **Online physical backup with a backup agent** — Use a tool like `mariabackup` or `pg_basebackup` that understands the database's internal locking and log mechanisms to take a consistent snapshot while the database continues running.

Each approach has different tradeoffs in terms of backup speed, restore speed, database downtime, and storage space required. The following sections cover all three for both MariaDB and PostgreSQL in the context of rootless Podman containers on RHEL 10.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. The Three Backup Approaches

### 2.1 Logical Dump

**Tools:** `mariadb-dump` (formerly `mysqldump`), `pg_dump`, `pg_dumpall`

**How it works:** You connect to the running database server and ask it to serialize all data as SQL `CREATE TABLE` and `INSERT` statements (or in PostgreSQL's case, a binary custom format). The engine holds a consistent read snapshot while dumping each table.

**Pros:**
- Human-readable (SQL format) or portable binary format
- Easy to restore individual tables or databases
- Works while the database is running (no downtime)
- Output is a single file, easy to include in a Bareos backup job

**Cons:**
- Slow on large databases (full table scans for every table)
- Restores are slow (re-executing millions of INSERT statements)
- Does not include binary logs needed for point-in-time recovery by itself
- For very large databases (100+ GB), the dump window may be too long

**Best for:** Small to medium databases, the Bareos catalog itself, situations where portability matters.

### 2.2 Physical Backup with Container Stopped

**How it works:** Use `systemctl --user stop` to stop the database container, then use Bareos to back up the named volume's data directory directly. Restart the container afterward.

**Pros:**
- Guaranteed consistency (no engine running)
- Fast restore (just copy the files back)
- Captures everything including configuration

**Cons:**
- Database is unavailable during the backup window
- Backup size is the full raw data size (often larger than a logical dump due to empty pages)
- Requires pre/post job scripts to stop and start the container

**Best for:** Smaller databases where brief downtime is acceptable, or when you want a simple, bulletproof approach.

### 2.3 Online Physical Backup with mariabackup / pg_basebackup

**How it works:** A backup agent runs inside the container (or connects to it) and uses the database's internal mechanisms to copy data files while the database continues serving requests. MariaDB uses `mariabackup`, which coordinates with InnoDB's redo log. PostgreSQL uses `pg_basebackup`, which uses the WAL streaming protocol.

**Pros:**
- Zero downtime
- Fast restore (file copy, not SQL replay)
- Supports incremental backups (mariabackup)
- Can serve as the foundation for point-in-time recovery

**Cons:**
- More complex setup
- Requires the backup tool to be available inside or alongside the container
- Output must be "prepared" before it can be restored

**Best for:** Production databases that cannot tolerate downtime, large databases, setups requiring incremental backup.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. MariaDB in Containers: Where the Data Lives

In our Bareos course setup, the Bareos Catalog database runs in a MariaDB container. Let's understand how that container stores its data before we can back it up correctly.

### 3.1 The Named Volume

When the MariaDB container is started via Quadlet, it is given a named volume for its data directory. A Quadlet container file for the Bareos database looks like this:

```ini
# /home/bareos/.config/containers/systemd/bareos-db.container
[Unit]
Description=Bareos MariaDB Catalog Database
After=network-online.target

[Container]
Image=docker.io/library/mariadb:10.11
ContainerName=bareos-db

# Named volume: Podman manages the path automatically
Volume=bareos-db-data:/var/lib/mysql

# Environment file for secrets (mode 600, never committed to git)
EnvironmentFile=/home/bareos/.config/bareos/db.env

# The database listens on the default MariaDB port
PublishPort=127.0.0.1:3306:3306

[Service]
Restart=always

[Install]
WantedBy=default.target
```

The line `Volume=bareos-db-data:/var/lib/mysql` tells Podman to create a named volume called `bareos-db-data` and mount it at `/var/lib/mysql` inside the container. This is the standard data directory for MariaDB/MySQL.

### 3.2 Finding the Physical Path on the Host

Podman stores named volume data at a predictable path:

```
~/.local/share/containers/storage/volumes/<volume-name>/_data/
```

For the `bareos` user (UID 1001):

```bash
# Run as the bareos user
export XDG_RUNTIME_DIR=/run/user/1001

# List all named volumes
podman volume ls

# Inspect a specific volume to find its mount point
podman volume inspect bareos-db-data

# The data is at:
ls /home/bareos/.local/share/containers/storage/volumes/bareos-db-data/_data/
```

The `_data/` directory contains the raw MariaDB data files:
- `ibdata1` — the InnoDB system tablespace
- `ib_logfile0`, `ib_logfile1` — InnoDB redo log files
- `mysql/` — system database directory
- `bareos/` — the Bareos catalog database directory (one `.ibd` file per table)
- `performance_schema/`, `sys/` — internal MariaDB databases

**Important SELinux note:** When Podman creates a named volume for a rootless container, it labels the `_data/` directory with the `container_file_t` SELinux type. Any process running inside the container gets this label automatically. However, if Bareos's File Daemon (also running in a container) needs to read these files directly for a physical backup, you must ensure the label permits access.

### 3.3 The db.env Secrets File

The MariaDB container reads credentials from an environment file. This file must be owned by `bareos:bareos` and mode `0600`:

```bash
# /home/bareos/.config/bareos/db.env
# Mode: 600, Owner: bareos:bareos
MARIADB_ROOT_PASSWORD=SuperSecretRootPass
MARIADB_DATABASE=bareos
MARIADB_USER=bareos
MARIADB_PASSWORD=BareosDBPass
```

These same credentials are needed in backup scripts that connect to MariaDB.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. MariaDB Logical Backup with mariadb-dump

### 4.1 What mariadb-dump Produces

`mariadb-dump` (the modern name; `mysqldump` is the legacy alias) connects to a running MariaDB server and produces a text file containing SQL statements that recreate the database. The output looks like:

```sql
-- MariaDB dump 10.19  Distrib 10.11.x-MariaDB
-- Host: localhost    Database: bareos
-- ...
CREATE TABLE `Client` (
  `ClientId` int(11) NOT NULL AUTO_INCREMENT,
  `Name` tinyblob NOT NULL,
  -- ...
) ENGINE=InnoDB;

INSERT INTO `Client` VALUES (1,'bareos-fd','bareos-fd',0,...);
```

This output can be piped to `gzip` for compression, reducing the file size by 70–90% for typical database content.

### 4.2 Running mariadb-dump via podman exec

Because the MariaDB binary (`mariadb-dump`) lives inside the container, you use `podman exec` to run it:

```bash
# Run as the bareos user
export XDG_RUNTIME_DIR=/run/user/1001

# Basic dump of the bareos database, compressed
podman exec bareos-db \
    mariadb-dump \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --hex-blob \
    --default-character-set=utf8mb4 \
    -u bareos \
    -pBareosDBPass \
    bareos \
  | gzip > /home/bareos/backups/bareos-catalog-$(date +%Y%m%d-%H%M%S).sql.gz
```

**Explaining the flags:**

| Flag | Meaning |
|------|---------|
| `--single-transaction` | Opens a single transaction before dumping, ensuring a consistent snapshot without locking tables (InnoDB only) |
| `--routines` | Includes stored procedures and functions |
| `--triggers` | Includes triggers (enabled by default, explicit for clarity) |
| `--events` | Includes scheduled events |
| `--hex-blob` | Dumps binary columns as hexadecimal to avoid encoding issues |
| `--default-character-set=utf8mb4` | Ensures Unicode data is dumped correctly |
| `-u bareos` | Connect as the `bareos` database user |
| `-pBareosDBPass` | Password (no space between `-p` and the password) |

**Important:** Passing a password on the command line is visible in `ps` output and shell history. For production, use a credentials file:

```bash
# /home/bareos/.config/bareos/my-backup.cnf
# Mode: 600
[client]
user=bareos
password=BareosDBPass
host=127.0.0.1
port=3306
```

Then call:
```bash
podman exec bareos-db \
    mariadb-dump \
    --defaults-file=/etc/bareos/my-backup.cnf \
    --single-transaction \
    bareos \
  | gzip > /home/bareos/backups/bareos-catalog.sql.gz
```

To mount the credentials file into the container, add a bind-mount in the Quadlet `.container` file:

```ini
Volume=/home/bareos/.config/bareos/my-backup.cnf:/etc/bareos/my-backup.cnf:ro,Z
```

The `:Z` suffix instructs Podman to automatically relabel the file with `container_file_t` so the container can read it under SELinux enforcing mode.

### 4.3 Dumping All Databases

```bash
podman exec bareos-db \
    mariadb-dump \
    --all-databases \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    -u root \
    -p"${MARIADB_ROOT_PASSWORD}" \
  | gzip > /home/bareos/backups/all-databases.sql.gz
```

### 4.4 Where to Store the Dump File

The dump file must be written to a location that Bareos's File Daemon can reach. In our rootless Podman setup, the File Daemon runs in its own container. The best approach is to write the dump to a directory that is bind-mounted into the File Daemon container.

A good location is `/home/bareos/backups/`:

```bash
mkdir -p /home/bareos/backups
chmod 750 /home/bareos/backups
```

In the File Daemon's Quadlet `.container` file, add:

```ini
Volume=/home/bareos/backups:/var/bareos/backups:ro,Z
```

The Bareos FileSet then references `/var/bareos/backups/` (the path inside the FD container).

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. MariaDB Physical Backup: Stopping the Container

The simplest way to get a crash-consistent physical backup is to stop the database container before Bareos reads the files. This guarantees that MariaDB has flushed all pending writes and closed all files cleanly.

### 5.1 The Stop/Start Approach

The workflow is:
1. Bareos Job's `RunBeforeJob` script stops the MariaDB container
2. Bareos reads the volume data directory
3. Bareos Job's `RunAfterJob` script restarts the MariaDB container

### 5.2 Pre/Post Scripts

```bash
#!/bin/bash
# /home/bareos/scripts/pre-mariadb-backup.sh
# Run before the physical backup job
# Stops the MariaDB container gracefully

set -euo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

echo "[$(date)] Stopping bareos-db container for physical backup..."
systemctl --user stop bareos-db.service

# Wait until the container is fully stopped
timeout 60 bash -c 'until ! podman ps --format "{{.Names}}" | grep -q "^bareos-db$"; do sleep 1; done'

echo "[$(date)] bareos-db container stopped successfully."
exit 0
```

```bash
#!/bin/bash
# /home/bareos/scripts/post-mariadb-backup.sh
# Run after the physical backup job
# Restarts the MariaDB container

set -euo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

echo "[$(date)] Restarting bareos-db container after physical backup..."
systemctl --user start bareos-db.service

# Wait until MariaDB is accepting connections
timeout 120 bash -c 'until podman exec bareos-db mariadb-admin -u root -p"${MARIADB_ROOT_PASSWORD}" ping --silent 2>/dev/null; do sleep 2; done'

echo "[$(date)] bareos-db container is back online."
exit 0
```

```bash
chmod +x /home/bareos/scripts/pre-mariadb-backup.sh
chmod +x /home/bareos/scripts/post-mariadb-backup.sh
```

### 5.3 The Physical Data Path

The Bareos FileSet for a physical backup points to the volume's data directory on the host:

```
/home/bareos/.local/share/containers/storage/volumes/bareos-db-data/_data/
```

**SELinux consideration:** The `_data/` directory is labeled `container_file_t`. If the Bareos File Daemon runs in a container, it will have a `container_t` domain, which can read `container_file_t` files. If the FD runs natively on the host (not in a container), you may need to add a policy or relabel the path. For our course setup (FD in a container), no extra steps are needed.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. MariaDB Binary Logs and Point-in-Time Recovery

### 6.1 What Binary Logs Are

The MariaDB binary log (binlog) is a sequential record of every change made to the database: every INSERT, UPDATE, DELETE, CREATE TABLE, ALTER TABLE. It is the foundation of MariaDB replication — a replica server reads the primary's binary log and replays those changes.

For backup purposes, the binary log enables **point-in-time recovery (PITR)**: starting from a full backup taken at time T0, you can replay the binary logs to recover the database to any point T1 between T0 and now. This is invaluable for recovering from accidental `DROP TABLE` or `DELETE FROM` without a `WHERE` clause.

### 6.2 Enabling Binary Logs in the Container

Binary logging requires configuration in MariaDB. The cleanest way is to create a custom MariaDB configuration file and bind-mount it into the container.

```ini
# /home/bareos/.config/bareos/mariadb-binlog.cnf
[mysqld]
# Enable binary logging
log_bin = /var/lib/mysql/mysql-bin
binlog_format = ROW
expire_logs_days = 7
server_id = 1
# Keep binlog files until they are at least 100MB
max_binlog_size = 100M
```

Add to the `bareos-db.container` Quadlet file:

```ini
Volume=/home/bareos/.config/bareos/mariadb-binlog.cnf:/etc/mysql/conf.d/binlog.cnf:ro,Z
```

After restarting the container, binary log files appear in `/var/lib/mysql/` (inside the container), which maps to the named volume `_data/` directory on the host:

```bash
export XDG_RUNTIME_DIR=/run/user/1001
podman exec bareos-db mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" \
    -e "SHOW BINARY LOGS;"
```

### 6.3 Backing Up Binary Logs

Binary log files are named sequentially: `mysql-bin.000001`, `mysql-bin.000002`, etc. They live in the same volume as the data files, so they are included in any physical backup of the volume.

For PITR purposes, you want to back them up frequently (e.g., every hour) so the recovery gap is small. A dedicated Bareos job can back up only the binlog files:

```
/home/bareos/.local/share/containers/storage/volumes/bareos-db-data/_data/mysql-bin.*
```

### 6.4 Point-in-Time Recovery Concept

To recover to a specific point in time:

1. Restore the last full backup to the data directory
2. Identify the binary log position corresponding to the moment just before the accidental change
3. Replay all binary logs from the backup point up to (but not including) the accident:
   ```bash
   podman exec bareos-db \
       mysqlbinlog \
       --start-datetime="2026-02-24 08:00:00" \
       --stop-datetime="2026-02-24 09:45:00" \
       /var/lib/mysql/mysql-bin.000010 \
       /var/lib/mysql/mysql-bin.000011 \
     | podman exec -i bareos-db mariadb -u root -p"${MARIADB_ROOT_PASSWORD}"
   ```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. mariabackup: Online Physical Backup

### 7.1 What mariabackup Is

`mariabackup` is an open-source hot backup tool for MariaDB, forked from Percona XtraBackup. It copies InnoDB data files while the database is running, using InnoDB's redo log to ensure consistency. The key advantage over `mariadb-dump` is speed: it copies files directly rather than running table scans.

### 7.2 Running mariabackup Inside the Container

The `docker.io/library/mariadb:10.11` image includes `mariabackup`. You can run it via `podman exec`:

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Create a directory for the backup output
# This path must be accessible from inside the container
mkdir -p /home/bareos/backups/mariabackup-full

# Run mariabackup (this takes a while for large databases)
podman exec bareos-db \
    mariabackup \
    --backup \
    --target-dir=/backup/mariabackup-full \
    --user=root \
    --password="${MARIADB_ROOT_PASSWORD}"
```

For this to work, `/home/bareos/backups/` must be bind-mounted into the `bareos-db` container at `/backup/`:

```ini
# In bareos-db.container
Volume=/home/bareos/backups:/backup:Z
```

### 7.3 Preparing the Backup

A raw mariabackup output is not immediately restorable — it may contain uncommitted transactions captured during the backup. You must **prepare** it first:

```bash
podman exec bareos-db \
    mariabackup \
    --prepare \
    --target-dir=/backup/mariabackup-full
```

This replays the InnoDB redo log against the copied data files, making them consistent.

### 7.4 Incremental Backups with mariabackup

mariabackup can take incremental backups that only capture changes since the last full or incremental backup:

```bash
# First: take a full backup
podman exec bareos-db mariabackup \
    --backup \
    --target-dir=/backup/mariabackup-full \
    --user=root --password="${MARIADB_ROOT_PASSWORD}"

# Later: take an incremental backup
podman exec bareos-db mariabackup \
    --backup \
    --target-dir=/backup/mariabackup-inc1 \
    --incremental-basedir=/backup/mariabackup-full \
    --user=root --password="${MARIADB_ROOT_PASSWORD}"
```

To restore an incremental chain, you prepare the full backup with `--apply-log-only`, apply each incremental, then do a final prepare without `--apply-log-only`.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. PostgreSQL in Containers

### 8.1 pg_dump: Logical Backup of a Single Database

`pg_dump` is PostgreSQL's built-in logical backup tool. It produces a consistent snapshot of a single database while the server is running.

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Dump in custom binary format (most flexible for restore)
podman exec bareos-pg \
    pg_dump \
    --format=custom \
    --compress=9 \
    --username=postgres \
    --dbname=myapp \
    --file=/backup/myapp-$(date +%Y%m%d-%H%M%S).pgdump
```

**Output formats:**

| Format | Flag | Notes |
|--------|------|-------|
| Plain SQL | `--format=plain` | Human-readable, large, slow to restore |
| Custom binary | `--format=custom` | Compressed, supports parallel restore with `pg_restore` |
| Directory | `--format=directory` | One file per table, supports parallel dump |
| Tar | `--format=tar` | Portable, supports parallel restore |

The `custom` format is recommended: it is compressed, can be restored in parallel (`pg_restore --jobs=4`), and allows selective table restore.

### 8.2 pg_dumpall: Dump All Databases Including Global Objects

`pg_dump` only handles one database at a time. `pg_dumpall` dumps all databases and also captures global objects that `pg_dump` misses: roles (users), tablespaces, and other cluster-level settings.

```bash
podman exec bareos-pg \
    pg_dumpall \
    --username=postgres \
    --file=/backup/pg-all-$(date +%Y%m%d-%H%M%S).sql
```

`pg_dumpall` always produces plain SQL (no binary format option), so compress it afterward:

```bash
gzip /backup/pg-all-$(date +%Y%m%d-%H%M%S).sql
```

### 8.3 pg_basebackup: Physical Online Backup

`pg_basebackup` takes a physical base backup of a running PostgreSQL cluster by streaming the data directory over the replication protocol. This is the foundation for streaming replication and for PITR.

```bash
podman exec bareos-pg \
    pg_basebackup \
    --pgdata=/backup/pg-basebackup-$(date +%Y%m%d) \
    --format=tar \
    --gzip \
    --compress=9 \
    --checkpoint=fast \
    --wal-method=stream \
    --username=replicator \
    --progress
```

**Flag explanations:**

| Flag | Meaning |
|------|---------|
| `--pgdata` | Output directory |
| `--format=tar` | Create a tar archive (vs. plain directory) |
| `--gzip` / `--compress=9` | Compress the tar archive |
| `--checkpoint=fast` | Force an immediate checkpoint before backup (faster start) |
| `--wal-method=stream` | Stream WAL files during the backup so the backup is self-contained |
| `--username=replicator` | Connect as this PostgreSQL role (needs `REPLICATION` privilege) |

For `pg_basebackup` to work, PostgreSQL must be configured to allow replication connections. In `pg_hba.conf`:

```
local   replication   replicator   trust
```

And in `postgresql.conf`:
```
wal_level = replica
max_wal_senders = 3
```

### 8.4 Hook Script for PostgreSQL Logical Backup

```bash
#!/bin/bash
# /home/bareos/scripts/pg-dump-backup.sh
# Called by Bareos RunBeforeJob to produce a dump file

set -euo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

BACKUP_DIR="/home/bareos/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DUMP_FILE="${BACKUP_DIR}/pg-all-${TIMESTAMP}.sql.gz"

echo "[$(date)] Starting PostgreSQL pg_dumpall..."

podman exec bareos-pg \
    pg_dumpall \
    --username=postgres \
    --clean \
  | gzip > "${DUMP_FILE}"

# Keep only the last 7 dump files
ls -t "${BACKUP_DIR}"/pg-all-*.sql.gz | tail -n +8 | xargs -r rm --

echo "[$(date)] pg_dumpall complete: ${DUMP_FILE}"
exit 0
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. PostgreSQL WAL Archiving Concept

Write-Ahead Log (WAL) archiving is to PostgreSQL what binary log backup is to MariaDB: it enables point-in-time recovery by recording every change as a sequence of WAL segment files.

### 9.1 Enabling WAL Archiving

In `postgresql.conf`:

```ini
wal_level = replica
archive_mode = on
archive_command = 'cp %p /backup/pg-wal-archive/%f'
```

The `archive_command` is run by PostgreSQL each time a WAL segment is completed. It must return exit code 0 on success. Here it simply copies the WAL file to an archive directory.

For containers, you would mount the archive directory:

```ini
# In bareos-pg.container Quadlet file
Volume=/home/bareos/backups/pg-wal-archive:/backup/pg-wal-archive:Z
```

### 9.2 Using WAL Archives for PITR

To restore to a point in time:
1. Restore the latest `pg_basebackup`
2. Create a `recovery.conf` (PostgreSQL 11 and earlier) or `postgresql.auto.conf` (PostgreSQL 12+) entry pointing to the WAL archive and specifying the target time
3. Start PostgreSQL — it will replay WAL until the target time

This is an advanced topic beyond our current scope, but understanding that WAL archiving exists is essential context for any serious PostgreSQL deployment.

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. The Bareos Catalog Database: Special Considerations

The Bareos Catalog is the most critical database in your backup infrastructure. It contains:

- The complete index of every file ever backed up
- Job history (when jobs ran, whether they succeeded)
- Volume records (which tapes/disk volumes hold which data)
- Client and Pool configuration

Without the Catalog, you cannot perform restores, because Bareos does not know which Volume contains which files.

### 10.1 The Chicken-and-Egg Problem

Here is the fundamental challenge: the Bareos Catalog is backed up **by** Bareos. But if you lose the Catalog, you lose your ability to restore anything — including the Catalog backup.

The solution has two parts:

1. **Separate, independent Catalog backup:** Store the Catalog dump somewhere outside the Bareos storage volumes — a separate file system, a remote host, or cloud storage. This ensures you can recover it even if all Bareos volumes are lost.

2. **Bootstrap file:** Bareos generates a `bootstrap` file (`.bsr`) for each job. The bootstrap file is a minimal index that tells Bareos exactly which Volume and which position on that Volume contains the data for a specific job — without needing the Catalog. Keep the bootstrap file for the Catalog backup job somewhere safe (separate from Bareos storage).

### 10.2 Catalog Backup Frequency

Back up the Catalog daily, at minimum. The Catalog grows with every backup job; losing a day's worth of Catalog records means you may not be able to locate files backed up during that day.

In a busy production environment, consider backing up the Catalog multiple times per day.

### 10.3 The Backup-Catalog Job in the Default Configuration

When you install Bareos, the default configuration includes a pre-built `BackupCatalog` job that uses the `make_catalog_backup.pl` script. We examine that script in the next section.

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. make_catalog_backup.pl: The Built-in Bareos Catalog Script

### 11.1 What It Does

`make_catalog_backup.pl` is a Perl script that ships with Bareos. It is designed to be called from a Bareos Job's `RunBeforeJob` directive. The script:

1. Reads the Bareos Director configuration to find the Catalog database credentials
2. Runs `mysqldump` (or `pg_dump` for PostgreSQL catalogs) to dump the catalog database
3. Writes the dump to a file that Bareos can then back up
4. Handles cleanup of old dump files

### 11.2 Where to Find It

Inside the Bareos Director container:

```bash
export XDG_RUNTIME_DIR=/run/user/1001
podman exec bareos-dir find / -name "make_catalog_backup.pl" 2>/dev/null
# Typically: /usr/lib/bareos/scripts/make_catalog_backup.pl
```

On the host (if Bareos is installed natively): `/usr/lib/bareos/scripts/make_catalog_backup.pl`

### 11.3 How to Use It

The script is called with the Catalog name as the argument. In the default Bareos Director configuration (`bareos-dir.conf`), you will see:

```
RunBeforeJob = "/usr/lib/bareos/scripts/make_catalog_backup.pl MyCatalog"
```

Where `MyCatalog` matches the name of a `Catalog { Name = MyCatalog; ... }` resource in the Director configuration.

The script reads the Catalog resource to find the database host, port, name, user, and password. It then runs `mysqldump` against the database and writes the output to:

```
/var/lib/bareos/bareos.sql
```

(or the equivalent path inside the Director container).

### 11.4 The Corresponding Cleanup Script

After the Catalog backup job completes, Bareos runs:

```
RunAfterJob = "/usr/lib/bareos/scripts/delete_catalog_backup"
```

This removes the `/var/lib/bareos/bareos.sql` file (since it has now been backed up and keeping it indefinitely would waste space).

### 11.5 Adapting for Container Environments

In our rootless Podman setup, `make_catalog_backup.pl` runs inside the Director container. It calls `mysqldump` — but the MariaDB server is in a **separate container** (`bareos-db`). The Director container must be able to reach the database container over the Podman internal network.

Ensure the containers are in the same Podman network:

```ini
# In bareos-dir.container
Network=bareos.network

# In bareos-db.container
Network=bareos.network
```

The Catalog resource in `bareos-dir.conf` must use the container name as the hostname:

```
Catalog {
  Name = MyCatalog
  DB Driver = mysql
  DB Name = bareos
  DB Address = bareos-db      # Container name resolves on the Podman network
  DB Port = 3306
  DB User = bareos
  DB Password = "BareosDBPass"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Complete Bareos Job for MariaDB Container Backup

This section provides a complete, production-ready Bareos configuration for backing up a MariaDB container using the logical dump approach. We use a RunBeforeJob script to perform the dump, then back up the resulting file.

### 12.1 The Hook Script

```bash
#!/bin/bash
# /home/bareos/scripts/mariadb-pre-backup.sh
# Produces a compressed SQL dump of all MariaDB databases
# Called by Bareos RunBeforeJob

set -euo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

BACKUP_DIR="/home/bareos/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DUMP_FILE="${BACKUP_DIR}/mariadb-full-${TIMESTAMP}.sql.gz"
LATEST_LINK="${BACKUP_DIR}/mariadb-latest.sql.gz"

# Load database credentials from the secrets file
# shellcheck source=/dev/null
source /home/bareos/.config/bareos/db.env

echo "[$(date)] Starting MariaDB logical dump..."

podman exec bareos-db \
    mariadb-dump \
    --all-databases \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    --hex-blob \
    --default-character-set=utf8mb4 \
    --user=root \
    --password="${MARIADB_ROOT_PASSWORD}" \
  | gzip > "${DUMP_FILE}"

# Update the "latest" symlink so the FileSet always references the same path
ln -sf "${DUMP_FILE}" "${LATEST_LINK}"

# Prune old dumps (keep last 7)
ls -t "${BACKUP_DIR}"/mariadb-full-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm --

echo "[$(date)] MariaDB dump complete: ${DUMP_FILE} ($(du -sh "${DUMP_FILE}" | cut -f1))"
exit 0
```

```bash
chmod 750 /home/bareos/scripts/mariadb-pre-backup.sh
```

### 12.2 The Bareos FileSet

```
# /etc/bareos/bareos-dir.d/fileset/MariaDB-Dump.conf
FileSet {
  Name = "MariaDB-Dump"
  Description = "Backs up the compressed MariaDB logical dump file"

  Include {
    Options {
      Signature = MD5
      Compression = LZ4          # Bareos-level compression (redundant with gzip, disable if using gzip)
      # Disable Bareos compression since the file is already gzip-compressed:
      Compression = ""
    }

    # The symlink always points to the latest dump
    File = "/var/bareos/backups/mariadb-latest.sql.gz"

    # Also back up the timestamped file explicitly if you want all copies
    # File = "/var/bareos/backups"
  }

  Exclude {
    File = "/var/bareos/backups/mariadb-full-*.sql.gz"
  }
}
```

> **Note on path:** `/var/bareos/backups` is the path **inside the File Daemon container**, which bind-mounts `/home/bareos/backups` from the host. The symlink target must also be resolvable from inside the FD container.

### 12.3 The Bareos Job

```
# /etc/bareos/bareos-dir.d/job/BackupMariaDB.conf
Job {
  Name = "BackupMariaDB-Container"
  Description = "Logical dump backup of the MariaDB database container"
  Type = Backup
  Level = Full             # Logical dumps are always Full; no incremental possible
  Client = bareos-fd
  FileSet = "MariaDB-Dump"
  Schedule = "WeeklyCycle"
  Storage = File-1
  Pool = Full
  Priority = 10

  # Run the dump script before the backup starts
  # The script must complete (exit 0) before Bareos reads any files
  RunBeforeJob = "/home/bareos/scripts/mariadb-pre-backup.sh"

  # On failure, log a warning but do not mark the job failed
  # (use RunAfterFailedJob for alerting)
  RunAfterFailedJob = "/home/bareos/scripts/notify-failure.sh MariaDB-Backup"

  # Write Messages here
  Messages = Standard

  # Where to write the bootstrap file (critical for catalog-less restore)
  Write Bootstrap = "/var/lib/bareos/%n.bsr"

  # Maximum time allowed for the pre-script + backup combined
  Max Start Delay = 4 hours
}
```

### 12.4 The Schedule

```
# /etc/bareos/bareos-dir.d/schedule/MariaDB-Schedule.conf
Schedule {
  Name = "MariaDB-Daily"
  Run = Full daily at 02:00
}
```

Update the Job to use `Schedule = "MariaDB-Daily"`.

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Complete Bareos Job for PostgreSQL Container Backup

### 13.1 The Hook Script

```bash
#!/bin/bash
# /home/bareos/scripts/pg-pre-backup.sh
# Produces a pg_dumpall of all PostgreSQL databases
# Called by Bareos RunBeforeJob

set -euo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

BACKUP_DIR="/home/bareos/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DUMP_FILE="${BACKUP_DIR}/pg-all-${TIMESTAMP}.sql.gz"
LATEST_LINK="${BACKUP_DIR}/pg-latest.sql.gz"

echo "[$(date)] Starting PostgreSQL pg_dumpall..."

# pg_dumpall requires no password if pg_hba.conf allows the connection,
# or set PGPASSWORD in the environment
# For containerized PostgreSQL, use trust auth for local connections
podman exec \
    --env PGPASSWORD="$(cat /home/bareos/.config/bareos/pg-password.txt)" \
    bareos-pg \
    pg_dumpall \
    --username=postgres \
    --clean \
    --if-exists \
  | gzip > "${DUMP_FILE}"

ln -sf "${DUMP_FILE}" "${LATEST_LINK}"

ls -t "${BACKUP_DIR}"/pg-all-*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm --

echo "[$(date)] pg_dumpall complete: ${DUMP_FILE}"
exit 0
```

```bash
# Store the password securely
echo -n "PostgresRootPass" > /home/bareos/.config/bareos/pg-password.txt
chmod 600 /home/bareos/.config/bareos/pg-password.txt
chmod 750 /home/bareos/scripts/pg-pre-backup.sh
```

### 13.2 The Bareos FileSet

```
# /etc/bareos/bareos-dir.d/fileset/PostgreSQL-Dump.conf
FileSet {
  Name = "PostgreSQL-Dump"
  Description = "Backs up the compressed pg_dumpall output"

  Include {
    Options {
      Signature = MD5
    }
    File = "/var/bareos/backups/pg-latest.sql.gz"
  }
}
```

### 13.3 The Bareos Job

```
# /etc/bareos/bareos-dir.d/job/BackupPostgreSQL.conf
Job {
  Name = "BackupPostgreSQL-Container"
  Description = "pg_dumpall logical backup of the PostgreSQL container"
  Type = Backup
  Level = Full
  Client = bareos-fd
  FileSet = "PostgreSQL-Dump"
  Schedule = "WeeklyCycle"
  Storage = File-1
  Pool = Full
  Priority = 10

  RunBeforeJob = "/home/bareos/scripts/pg-pre-backup.sh"
  RunAfterFailedJob = "/home/bareos/scripts/notify-failure.sh PostgreSQL-Backup"

  Messages = Standard
  Write Bootstrap = "/var/lib/bareos/%n.bsr"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Complete Bareos Job for the Bareos Catalog

This is the most important backup job in your entire Bareos setup.

### 14.1 The Catalog Backup Script

We adapt `make_catalog_backup.pl`'s logic into a shell script that works with our containerized MariaDB. The Director container runs this script via RunBeforeJob.

```bash
#!/bin/bash
# /home/bareos/scripts/backup-catalog.sh
# Dumps the Bareos catalog database to a file inside the Director container
# This script runs INSIDE the bareos-dir container (via RunBeforeJob)

set -euo pipefail

# These variables are set from db.env, which is loaded by the container
: "${MARIADB_PASSWORD:?MARIADB_PASSWORD must be set}"
: "${MARIADB_DATABASE:?MARIADB_DATABASE must be set}"
: "${MARIADB_USER:?MARIADB_USER must be set}"

DUMP_FILE="/var/lib/bareos/bareos-catalog.sql.gz"

echo "[$(date)] Starting Bareos Catalog dump..."

mariadb-dump \
    --host=bareos-db \
    --port=3306 \
    --user="${MARIADB_USER}" \
    --password="${MARIADB_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --events \
    "${MARIADB_DATABASE}" \
  | gzip > "${DUMP_FILE}"

echo "[$(date)] Catalog dump complete: ${DUMP_FILE}"
exit 0
```

```bash
# The cleanup script (run after the backup job completes)
#!/bin/bash
# /home/bareos/scripts/cleanup-catalog-dump.sh
rm -f /var/lib/bareos/bareos-catalog.sql.gz
echo "[$(date)] Catalog dump file removed."
exit 0
```

### 14.2 The Bareos Job Configuration

```
# /etc/bareos/bareos-dir.d/job/BackupCatalog.conf
Job {
  Name = "BackupCatalog"
  Description = "Backup the Bareos catalog database. This job must run after all other backup jobs."
  Type = Backup
  Level = Full
  Client = bareos-fd

  # The FileSet points to the dump file location inside the FD container
  FileSet = "Catalog"

  Schedule = "WeeklyCycleAfterBackup"
  Storage = File-1

  # Use a separate Pool for catalog backups so they are easy to find
  Pool = Full

  # CRITICAL: Run after all other jobs so the catalog is fully up to date
  Priority = 100

  # Run the dump script inside the Director container before backing up
  RunBeforeJob = "/usr/lib/bareos/scripts/make_catalog_backup.pl MyCatalog"

  # Clean up the dump file after the backup completes
  RunAfterJob  = "/usr/lib/bareos/scripts/delete_catalog_backup"

  Messages = Standard

  # The bootstrap file for the catalog backup must be kept somewhere
  # safe and separate from Bareos storage
  Write Bootstrap = "/var/lib/bareos/%n.bsr"

  # Never let this job run for too long
  Max Start Delay = 2 hours
}
```

### 14.3 The Catalog FileSet

```
# /etc/bareos/bareos-dir.d/fileset/Catalog.conf
FileSet {
  Name = "Catalog"
  Description = "Includes only the Bareos catalog dump file"

  Include {
    Options {
      Signature = MD5
    }
    # Path inside the File Daemon container that maps to
    # /var/lib/bareos/ on the host
    File = "/var/lib/bareos/bareos-catalog.sql.gz"
  }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Restoring a MariaDB Container Database from a Logical Dump

### 15.1 Restore Procedure Overview

Restoring from a `mariadb-dump` output requires:
1. Retrieve the dump file from Bareos storage using `bconsole`
2. Copy or mount the dump file where the MariaDB container can access it
3. Run `mariadb` inside the container to import the SQL

### 15.2 Step 1: Restore the Dump File via Bareos

```bash
# In bconsole
*restore
# Select the backup of mariadb-latest.sql.gz
# Choose: 5 (Select the most recent backup for a client)
# Select the file: /var/bareos/backups/mariadb-latest.sql.gz
# Confirm the restore directory (e.g., /tmp/bareos-restore/)
*run
*wait
```

After the restore, the dump file will be at:
```
/tmp/bareos-restore/var/bareos/backups/mariadb-latest.sql.gz
```

### 15.3 Step 2: Decompress and Restore

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Copy the dump file to the shared backup directory
cp /tmp/bareos-restore/var/bareos/backups/mariadb-latest.sql.gz \
    /home/bareos/backups/restore-dump.sql.gz

# Restore all databases (this will DROP and recreate all databases)
# WARNING: This replaces all existing data
zcat /home/bareos/backups/restore-dump.sql.gz \
  | podman exec -i bareos-db \
      mariadb \
      --user=root \
      --password="${MARIADB_ROOT_PASSWORD}"
```

### 15.4 Step 3: Verify the Restore

```bash
podman exec bareos-db \
    mariadb \
    --user=bareos \
    --password="${MARIADB_PASSWORD}" \
    bareos \
    -e "SELECT COUNT(*) FROM Job;"
```

### 15.5 Restoring a Single Database

If the dump contains all databases but you only need to restore one:

```bash
# Extract only the schema and data for the 'myapp' database from the dump
zcat /home/bareos/backups/restore-dump.sql.gz \
  | podman exec -i bareos-db \
      mariadb \
      --user=root \
      --password="${MARIADB_ROOT_PASSWORD}" \
      --one-database myapp
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Restoring a PostgreSQL Container Database from pg_dumpall

### 16.1 Retrieve the Dump File

Same as MariaDB: use `bconsole restore` to retrieve `pg-latest.sql.gz`, then place it at `/home/bareos/backups/pg-restore.sql.gz`.

### 16.2 Restore All Databases

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Decompress and pipe directly into psql
zcat /home/bareos/backups/pg-restore.sql.gz \
  | podman exec -i \
      --env PGPASSWORD="$(cat /home/bareos/.config/bareos/pg-password.txt)" \
      bareos-pg \
      psql \
      --username=postgres \
      --set ON_ERROR_STOP=off
```

The `--set ON_ERROR_STOP=off` flag is needed because `pg_dumpall --clean` generates `DROP` statements for objects that may not exist, which would otherwise cause `psql` to abort.

### 16.3 Restore a Single Database from pg_dump Custom Format

If you backed up a single database with `pg_dump --format=custom`:

```bash
podman exec \
    --env PGPASSWORD="$(cat /home/bareos/.config/bareos/pg-password.txt)" \
    bareos-pg \
    pg_restore \
    --username=postgres \
    --dbname=myapp \
    --clean \
    --if-exists \
    --jobs=2 \
    /backup/myapp-20260224-020000.pgdump
```

`--jobs=2` enables parallel restore, significantly speeding up large databases.

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 14-1: Full MariaDB Container Backup

**Objective:** Configure and run a complete MariaDB logical dump backup job, verify it in `bconsole`, and confirm the dump file was captured.

**Prerequisites:**
- Bareos running in rootless Podman containers
- MariaDB container (`bareos-db`) running with the `bareos` database
- File Daemon container bind-mounting `/home/bareos/backups`

**Step 1: Create the scripts directory and hook script**

```bash
# As the bareos user
su - bareos
export XDG_RUNTIME_DIR=/run/user/1001

mkdir -p /home/bareos/scripts /home/bareos/backups

cat > /home/bareos/scripts/mariadb-pre-backup.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail
export XDG_RUNTIME_DIR=/run/user/1001

BACKUP_DIR="/home/bareos/backups"
DUMP_FILE="${BACKUP_DIR}/mariadb-latest.sql.gz"

source /home/bareos/.config/bareos/db.env

echo "[$(date)] Dumping MariaDB..."
podman exec bareos-db \
    mariadb-dump \
    --all-databases \
    --single-transaction \
    --routines \
    --triggers \
    --user=root \
    --password="${MARIADB_ROOT_PASSWORD}" \
  | gzip > "${DUMP_FILE}"

echo "[$(date)] Done: ${DUMP_FILE} ($(du -sh "${DUMP_FILE}" | cut -f1))"
SCRIPT

chmod 750 /home/bareos/scripts/mariadb-pre-backup.sh
```

**Step 2: Test the hook script manually**

```bash
/home/bareos/scripts/mariadb-pre-backup.sh
ls -lh /home/bareos/backups/mariadb-latest.sql.gz
# Expected: a non-empty .sql.gz file
```

**Step 3: Verify the dump is readable**

```bash
zcat /home/bareos/backups/mariadb-latest.sql.gz | head -20
# Should show: -- MariaDB dump header
```

**Step 4: Add the Bareos configuration**

```bash
# As root or via sudo
cat > /etc/bareos/bareos-dir.d/job/BackupMariaDB.conf << 'JOB'
Job {
  Name = "BackupMariaDB-Lab"
  Type = Backup
  Level = Full
  Client = bareos-fd
  FileSet = "MariaDB-Dump"
  Schedule = "WeeklyCycle"
  Storage = File-1
  Pool = Full
  Priority = 10
  RunBeforeJob = "/home/bareos/scripts/mariadb-pre-backup.sh"
  Messages = Standard
  Write Bootstrap = "/var/lib/bareos/%n.bsr"
}
JOB

cat > /etc/bareos/bareos-dir.d/fileset/MariaDB-Dump.conf << 'FS'
FileSet {
  Name = "MariaDB-Dump"
  Include {
    Options { Signature = MD5 }
    File = "/var/bareos/backups/mariadb-latest.sql.gz"
  }
}
FS
```

**Step 5: Reload Bareos Director and run the job**

```bash
# Reload the Director configuration
podman exec bareos-dir bconsole << 'EOF'
reload
run job=BackupMariaDB-Lab level=Full yes
wait
status dir
EOF
```

**Step 6: Verify in bconsole**

```bash
podman exec -it bareos-dir bconsole
```

In `bconsole`:
```
*list jobs
# Find BackupMariaDB-Lab — Status should be "T" (Terminated OK)

*list files jobid=<JOBID>
# Should show /var/bareos/backups/mariadb-latest.sql.gz

*list volumes
# Should show the volume that contains this job
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 14-2: Point-in-Time Restore of MariaDB Container Database

**Objective:** Simulate a data loss event, restore a MariaDB database to the state captured in the Lab 14-1 backup.

**Step 1: Create test data before the backup**

```bash
export XDG_RUNTIME_DIR=/run/user/1001
source /home/bareos/.config/bareos/db.env

# Create a test table with data
podman exec bareos-db mariadb \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    -e "CREATE DATABASE IF NOT EXISTS lab14_test;
        USE lab14_test;
        CREATE TABLE IF NOT EXISTS items (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100));
        INSERT INTO items (name) VALUES ('alpha'),('beta'),('gamma');"

# Verify
podman exec bareos-db mariadb \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    -e "USE lab14_test; SELECT * FROM items;"
```

**Step 2: Run the backup (captures the test data)**

```bash
podman exec bareos-dir bconsole << 'EOF'
run job=BackupMariaDB-Lab level=Full yes
wait
EOF
```

Note the JobID from the output.

**Step 3: Simulate data loss**

```bash
podman exec bareos-db mariadb \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    -e "DROP DATABASE lab14_test;"

# Confirm it is gone
podman exec bareos-db mariadb \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    -e "SHOW DATABASES LIKE 'lab14_test';"
# Expected: empty result set
```

**Step 4: Restore the dump file via bconsole**

```bash
podman exec -it bareos-dir bconsole
```

```
*restore
Automatically selected Catalog: MyCatalog
Using Catalog "MyCatalog"
First you select one or more JobIds that contain files to be restored.
You will be placed into a file selection mode where you can select
the files to be restored.

To select the JobIds, you have the following choices:
     1: List last 20 Jobs run
     ...
     5: Select the most recent backup for a client

Item 5:
> 5
Automatically selected Client: bareos-fd
Automatically selected FileSet: MariaDB-Dump

The highlighted entry is the most recent backup.
Enter the file to restore (use 'mark', 'lsmark', 'done'):
$ mark /var/bareos/backups/mariadb-latest.sql.gz
$ done

Restoring to /tmp/bareos-restore/ ...
Run Restore job
JobId: ...
*yes
*wait
```

**Step 5: Restore the database from the retrieved dump**

```bash
# Find the restored file
ls /tmp/bareos-restore/var/bareos/backups/
cp /tmp/bareos-restore/var/bareos/backups/mariadb-latest.sql.gz \
    /home/bareos/backups/restore-lab14.sql.gz

# Restore the lab14_test database
zcat /home/bareos/backups/restore-lab14.sql.gz \
  | podman exec -i bareos-db \
      mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" \
      --one-database lab14_test
```

**Step 6: Verify the data is back**

```bash
podman exec bareos-db mariadb \
    -u root -p"${MARIADB_ROOT_PASSWORD}" \
    -e "USE lab14_test; SELECT * FROM items;"
# Expected: alpha, beta, gamma
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 14-3: Backup and Restore the Bareos Catalog

**Objective:** Run the Catalog backup job and verify the Catalog can be restored.

**Step 1: Run the BackupCatalog job**

```bash
podman exec bareos-dir bconsole << 'EOF'
run job=BackupCatalog yes
wait
list jobs
EOF
```

Check that the job status is `T` (Terminated successfully).

**Step 2: Identify the catalog dump volume**

```bash
podman exec -it bareos-dir bconsole
```

```
*list jobs
# Note the JobId for BackupCatalog

*list files jobid=<CATALOG_JOBID>
# Should show /var/lib/bareos/bareos-catalog.sql.gz (or similar)

*list volumes
# Note the Volume name that contains the catalog backup
```

**Step 3: Note the bootstrap file location**

```bash
ls -la /var/lib/bareos/BackupCatalog.bsr
# This file is critical — back it up separately!
cat /var/lib/bareos/BackupCatalog.bsr
```

The bootstrap file tells Bareos which Volume and byte offset contains the catalog backup — enabling catalog-less restore.

**Step 4: Simulate catalog loss and restore**

```bash
# CAUTION: This drops the entire Bareos catalog database.
# Only do this in a lab environment.
podman exec bareos-dir bconsole << 'EOF'
drop catalog MyCatalog yes
EOF

# Stop the Director
systemctl --user stop bareos-dir.service
```

**Step 5: Restore the catalog dump using bextract (catalog-less)**

```bash
# Use bextract to restore without the catalog, using the bootstrap file
podman exec bareos-sd \
    bextract \
    -b /var/lib/bareos/BackupCatalog.bsr \
    -D File-1 \
    /tmp/catalog-restore/

# The dump file is now at:
ls /tmp/catalog-restore/var/lib/bareos/bareos-catalog.sql.gz
```

**Step 6: Recreate the database schema and restore the dump**

```bash
# Recreate the Bareos database schema
podman exec bareos-dir \
    /usr/lib/bareos/scripts/create_bareos_database

# Restore the catalog data
zcat /tmp/catalog-restore/var/lib/bareos/bareos-catalog.sql.gz \
  | podman exec -i bareos-db \
      mariadb -u bareos -p"${MARIADB_PASSWORD}" bareos

# Restart the Director
systemctl --user start bareos-dir.service
```

**Step 7: Verify the catalog is intact**

```bash
podman exec bareos-dir bconsole << 'EOF'
list jobs
list clients
list volumes
EOF
# All previous jobs and clients should be visible
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 20. Summary

Database backup requires fundamentally different thinking from ordinary file backup. A database engine maintains complex internal state that can be captured correctly only by:

- **Asking the engine to dump itself** (logical backup): tools like `mariadb-dump` and `pg_dumpall` produce self-consistent SQL output that is portable and easy to restore, at the cost of performance on large databases.
- **Stopping the engine first** (physical offline backup): zero risk of inconsistency, but requires downtime.
- **Using an engine-aware backup agent** (mariabackup, pg_basebackup): online physical backup with no downtime, enabling incremental backup and point-in-time recovery.

In rootless Podman deployments on RHEL 10, these techniques are implemented through:
- `podman exec` to run dump tools inside running containers
- RunBeforeJob scripts that write dump files to bind-mounted directories
- Named volumes whose `_data/` paths can be backed up directly when containers are stopped
- SELinux label management (`:Z` volume mounts, `container_file_t` labels)

The Bareos Catalog is a special case: it must be backed up with high priority (Priority = 100 so it runs last), its bootstrap file must be stored outside Bareos storage, and it must be restorable without the catalog itself being intact. The `make_catalog_backup.pl` script and its companion `delete_catalog_backup` handle this workflow automatically in standard Bareos deployments.

Key takeaways:
- Never back up a live database by copying raw data files without the engine's cooperation
- Always test your restore procedure — a backup you have never restored is not a backup
- The Bareos Catalog is the key to restoring everything else; protect it as a first-class asset
- Keep bootstrap files and catalog dumps in a location separate from your main Bareos storage

[↑ Back to Table of Contents](#table-of-contents)
