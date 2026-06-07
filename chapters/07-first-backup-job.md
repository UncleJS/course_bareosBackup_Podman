# Chapter 7: Your First Backup Job
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. Anatomy of a Bareos Job](#1-anatomy-of-a-bareos-job)
  - [Job Types](#job-types)
  - [Job Levels](#job-levels)
- [2. Defining a FileSet](#2-defining-a-fileset)
  - [FileSet Structure](#fileset-structure)
  - [FileSet Options Deep Dive](#fileset-options-deep-dive)
  - [Complete FileSet for RHEL 10](#complete-fileset-for-rhel-10)
  - [FileSet Versioning](#fileset-versioning)
- [3. Defining a Schedule](#3-defining-a-schedule)
  - [Schedule Syntax](#schedule-syntax)
  - [Standard Weekly Schedule](#standard-weekly-schedule)
  - [GFS Schedule (for Chapter 16 — preview)](#gfs-schedule-for-chapter-16-preview)
- [4. Defining JobDefs (Templates)](#4-defining-jobdefs-templates)
  - [What `Accurate = yes` Does](#what-accurate-yes-does)
- [5. Defining the Backup Job](#5-defining-the-backup-job)
  - [Bootstrap Files](#bootstrap-files)
- [6. The BackupCatalog Job (Never Skip This)](#6-the-backupcatalog-job-never-skip-this)
- [7. Labeling Volumes](#7-labeling-volumes)
  - [Automatic Labeling](#automatic-labeling)
  - [Manual Labeling (for explicit control)](#manual-labeling-for-explicit-control)
  - [Verifying Volumes in bconsole](#verifying-volumes-in-bconsole)
- [8. Running Your First Manual Backup](#8-running-your-first-manual-backup)
  - [Reloading the Director Configuration](#reloading-the-director-configuration)
  - [Running a Job Manually](#running-a-job-manually)
  - [Watching Job Progress](#watching-job-progress)
- [9. Reading the Job Log Output](#9-reading-the-job-log-output)
  - [Understanding the Job Report Fields](#understanding-the-job-report-fields)
  - [Common Termination Statuses](#common-termination-statuses)
- [10. Scheduling Automatic Backups](#10-scheduling-automatic-backups)
  - [Preventing Overlapping Jobs](#preventing-overlapping-jobs)
- [11. Lab 7-1: Complete First Backup Configuration](#11-lab-7-1-complete-first-backup-configuration)
- [12. Lab 7-2: Running and Monitoring the Job](#12-lab-7-2-running-and-monitoring-the-job)
- [13. Summary](#13-summary)

## 1. Anatomy of a Bareos Job

A Bareos backup job is the fundamental unit of work. Every job definition connects several resources together:

```
Job
 ├── Client     → Who is being backed up (which File Daemon)
 ├── FileSet    → What files to include/exclude
 ├── Schedule   → When to run automatically
 ├── Storage    → Which Storage Daemon and Device
 ├── Pool       → Which pool of Volumes to use
 ├── Messages   → How to report job outcomes
 └── JobDefs    → Optional template to inherit settings from
```

The `Job` resource glues all these pieces together. Each component can be shared across multiple jobs — for example, many jobs might use the same `FileSet` and `Schedule` but different `Pools` for different retention requirements.

### Job Types

Bareos supports six Job types:

| Type | Purpose |
|---|---|
| `Backup` | Read files from a client and write to storage |
| `Restore` | Read from storage and write files back to a client |
| `Verify` | Compare current files against a previous backup (integrity check) |
| `Copy` | Duplicate existing backup data from one Pool/Storage to another |
| `Migrate` | Move data between Pools/Storages (removes from source) |
| `Admin` | Run an administrative command (e.g., pruning) |

In this chapter we focus on `Type = Backup`. Restore is covered in Chapter 8.

### Job Levels

| Level | Meaning |
|---|---|
| `Full` | Back up all files in the FileSet |
| `Incremental` | Back up only files changed since the last backup of any type |
| `Differential` | Back up all files changed since the last Full backup |
| `VirtualFull` | Synthesize a Full backup from existing Incremental data (no re-reading client) |

The `Level` in the Job definition is the *default* level. The Schedule can override it:

```bareos
Job {
  Level = Incremental        ← default level (used when run manually)
}

Schedule {
  Run = Level=Full sun       ← overrides to Full every Sunday
  Run = Level=Incremental mon-sat  ← overrides to Incremental other days
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Defining a FileSet

The `FileSet` resource defines precisely what to back up and what to exclude. Getting this right is one of the most important configuration tasks.

### FileSet Structure

```bareos
FileSet {
  Name = "FileSetName"

  Include {
    Options {
      # How to handle files
    }
    File = /path/to/include
    File = /another/path
  }

  Exclude {
    File = /path/to/exclude
  }
}
```

### FileSet Options Deep Dive

The `Options` block inside `Include` controls how files are processed:

**Signature (checksum type):**
```bareos
Options {
  Signature = MD5       # Fast, widely supported, but not collision-resistant
  # OR
  Signature = SHA1      # Slightly slower, more secure than MD5
  # OR
  Signature = SHA256    # Recommended: best security, slight performance cost
}
```

Checksums serve three purposes:
1. Verify data integrity after backup (detect corruption)
2. Enable Accurate mode (detect changed files by content, not just mtime)
3. Verify restore integrity (the restored file matches the backed-up file)

**Compression:**
```bareos
Options {
  Compression = LZ4     # Fastest: minimal CPU, ~20% smaller than uncompressed
  # OR
  Compression = GZIP    # Slower: moderate CPU, ~50-60% smaller
  # OR
  Compression = ZSTD    # Best: excellent ratio AND speed (recommended for modern hardware)
}
```

> **Rule**: Always enable compression for network-based backups. The CPU cost is negligible compared to the bandwidth and storage savings. Choose `ZSTD` for best results, `LZ4` if CPU is constrained.

**OneFs (don't cross filesystem boundaries):**
```bareos
Options {
  OneFs = yes   # Stop at filesystem boundaries (don't follow mounts)
}
```

When backing up `/`, `OneFs = yes` prevents backing up `/proc`, `/sys`, and network mounts — even if they're not in the `Exclude` list. Always use this when including root (`/`).

**Exclude special files:**
```bareos
Options {
  Exclude = yes     # Exclude files matching the following patterns
  Wild = "*.tmp"    # wildcard pattern
  Wild = "*.log"    # exclude log files (if using log management separately)
  Regex = ".*\.pyc$" # Python compiled files
}
```

**ACL and xattr preservation:**
```bareos
Options {
  AclSupport = yes    # Back up POSIX ACLs
  XattrSupport = yes  # Back up extended attributes (SELinux labels, etc.)
}
```

> **Important**: Always include `XattrSupport = yes` on RHEL systems. SELinux labels are stored as xattrs. Without this, restored files lose their SELinux contexts and may not function correctly.

### Complete FileSet for RHEL 10

> **Recall the `/hostfs` convention (Chapter 6):** the File Daemon runs as the `bareos-fd` container with the host filesystem bind-mounted read-only at `/hostfs`. So every `File =` path that targets the *host* must carry the `/hostfs/` prefix — `File = /hostfs/home` backs up `/home` on the RHEL 10 host. The one exception is `/var/lib/bareos`, which the FD mounts directly via the shared `bareos-working` volume, so it is referenced as-is (no prefix).

```bareos
FileSet {
  Name = "RHEL10-Standard"

  Include {
    Options {
      Signature = SHA256
      Compression = ZSTD
      AclSupport = yes
      XattrSupport = yes
      OneFs = yes

      # Exclude temporary and cache files within included directories
      Wild = "*/.cache/*"
      Wild = "*/tmp/*"
      Wild = "*/.mozilla/firefox/*/Cache/*"
      Wild = "*/.local/share/recently-used.xbel"
      Exclude = yes
    }

    # Core data directories (host paths via the /hostfs mount)
    File = /hostfs/home
    File = /hostfs/etc
    File = /hostfs/var/www
    File = /var/lib/bareos       # Bareos working data (shared bareos-working volume — no /hostfs)
    File = /hostfs/opt           # Locally installed applications
    File = /hostfs/srv           # Service data (NOT the backup volumes themselves)
    File = /hostfs/root          # Root user's home
  }

  Exclude {
    # Virtual/kernel filesystems — never back these up
    File = /hostfs/proc
    File = /hostfs/sys
    File = /hostfs/dev
    File = /hostfs/run
    File = /hostfs/tmp
    File = /hostfs/var/tmp
    File = /hostfs/lost+found

    # Swap
    File = /hostfs/swap.img
    File = /hostfs/var/lib/swap

    # Package caches — can be regenerated
    File = /hostfs/var/cache/dnf
    File = /hostfs/var/cache/yum

    # Container overlay storage — ephemeral, re-pull images instead
    File = /hostfs/var/lib/containers/storage/overlay
    File = /hostfs/home/bareos/.local/share/containers/storage/overlay

    # The backup storage itself (never back up your backups to themselves)
    File = /hostfs/srv/bareos-storage/volumes
  }
}
```

### FileSet Versioning

An important Bareos behavior: if you modify a `FileSet` definition, Bareos detects the change by comparing an MD5 hash of the `FileSet` contents. When the FileSet hash changes, Bareos **automatically upgrades the next Incremental or Differential to a Full backup**. This is correct behavior — a changed FileSet may include previously-excluded files that need a full baseline.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Defining a Schedule

The `Schedule` resource defines when jobs run automatically.

### Schedule Syntax

```bareos
Schedule {
  Name = "ScheduleName"
  Run = [modifier] [day-spec] [month-spec] at HH:MM
}
```

**Day specifications:**
```bareos
Run = mon                    # Every Monday
Run = mon-fri                # Monday through Friday
Run = 1st mon                # First Monday of the month
Run = last fri               # Last Friday of the month
Run = sun                    # Every Sunday
Run = daily                  # Every day
Run = hourly                 # Every hour
Run = Level=Full 1st sun     # First Sunday of month: Full
Run = Level=Incremental daily at 23:00  # Every day at 11 PM
```

**Time formats:**
```bareos
Run = daily at 23:00         # 11:00 PM
Run = daily at 2h            # Every 2 hours
Run = hourly                 # Every hour at :00
```

### Standard Weekly Schedule

```bareos
Schedule {
  Name = "WeeklyBackup"

  # Full backup every Sunday at 11 PM
  Run = Level=Full sun at 23:00

  # Incremental backups Monday-Saturday at 11 PM
  Run = Level=Incremental mon-sat at 23:00
}
```

### GFS Schedule (for Chapter 16 — preview)

```bareos
Schedule {
  Name = "GFS-Schedule"

  # Monthly Full on the 1st Sunday of the month → Monthly pool
  Run = Level=Full Pool=Monthly 1st sun at 22:00

  # Weekly Full every Sunday (except the 1st, which the Monthly run covers) → Weekly pool
  Run = Level=Full Pool=Weekly 2nd-5th sun at 23:00

  # Daily Incremental Mon-Sat → Daily pool
  Run = Level=Incremental Pool=Daily mon-sat at 23:00
}
```

The `Daily`, `Weekly`, and `Monthly` pools referenced here are defined in Chapter 16, where the full Grandfather-Father-Son retention scheme is built out.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Defining JobDefs (Templates)

`JobDefs` define default settings that multiple Jobs can inherit. This reduces repetition and makes your configuration DRY (Don't Repeat Yourself).

```bareos
JobDefs {
  Name = "StandardBackup"

  Type = Backup
  Storage = File
  Messages = Standard
  Priority = 10
  Write Bootstrap = "/var/lib/bareos/%c.bsr"

  # Prefered pool by level (can be overridden per-job)
  Pool = Incremental
  Full Backup Pool = Full
  Differential Backup Pool = Differential

  # Accurate mode: track all files for precise Incremental detection
  Accurate = yes
}
```

### What `Accurate = yes` Does

In normal mode, Bareos determines if a file changed by comparing its `mtime` (modification timestamp) to the timestamp of the last backup. This is fast but can miss some changes:
- Files where `mtime` was manipulated (some applications do this)
- Files that were overwritten with identical content (no size or mtime change)
- Renamed files (the old name gets deleted and the new name looks new)

With `Accurate = yes`:
- The File Daemon builds an in-memory index of every file from the previous backup
- Every file in the current scan is compared against this index
- Deleted files are detected (and can be optionally backed up as "deleted" records)
- Renamed files are correctly tracked

The tradeoff: `Accurate = yes` uses more memory on the File Daemon (roughly 150 bytes per file × number of files). For a client with 500,000 files, this is about 75 MB — acceptable. For a client with 50 million files, it could be 7.5 GB — plan accordingly or disable it.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Defining the Backup Job

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupLocalHost.conf > /dev/null <<'EOF'
Job {
  Name = "BackupLocalHost"
  JobDefs = "StandardBackup"

  # Which client to back up
  Client = bareos-fd

  # What to back up
  FileSet = "RHEL10-Standard"

  # When to run automatically
  Schedule = "WeeklyBackup"

  # Explicit pool assignments (inherited from JobDefs but can be overridden)
  Pool = Incremental
  Full Backup Pool = Full
  Differential Backup Pool = Differential

  # Where to write bootstrap file (useful for bare-metal recovery)
  Write Bootstrap = "/var/lib/bareos/%c.bsr"
}
EOF
```

### Bootstrap Files

The `Write Bootstrap` directive tells Bareos to write a `.bsr` (Bootstrap) file after each successful backup. A bootstrap file is a compact record of:
- Which Volumes contain this job's data
- The exact byte offsets within those Volumes
- Which files are in the backup

Bootstrap files enable **disaster recovery without the catalog**: if you lose the MariaDB catalog, you can still restore using the bootstrap file and the raw Volumes. Always back up your bootstrap files (they are in `/var/lib/bareos/` and included in the `RHEL10-Standard` FileSet we defined above).

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. The BackupCatalog Job (Never Skip This)

The BackupCatalog job dumps the MariaDB catalog to a file and backs it up to a Volume. It should run every day, after all regular backups complete.

Because the catalog lives in the `bareos-db` container (not in a local socket), we dump it *over the network* with a small script that runs **inside the Director container**. The Director already has the MariaDB credentials available as environment variables (it loads `db.env` via `EnvironmentFile=`, set up in Chapter 6), and Chapter 6 bind-mounts the host directory `/etc/bareos/scripts` read-only into the Director container at the same path. We put two scripts there: one to create the dump before the job, one to clean it up after.

```bash
# Dump script — runs INSIDE the bareos-director container (RunsOnClient = no)
sudo tee /etc/bareos/scripts/dump-catalog.sh > /dev/null <<'EOF'
#!/bin/sh
# Dump the Bareos catalog from the bareos-db container over the network.
# MARIADB_* come from the Director container's EnvironmentFile=db.env.
set -eu
mkdir -p /var/lib/bareos/catalog-dump
mariadb-dump \
  --host=bareos-db \
  --user="${MARIADB_USER}" \
  --password="${MARIADB_PASSWORD}" \
  --single-transaction \
  "${MARIADB_DATABASE}" \
  | gzip > /var/lib/bareos/catalog-dump/bareos-catalog.sql.gz
EOF
sudo chmod 0755 /etc/bareos/scripts/dump-catalog.sh

# Cleanup script — removes the dump after the job has captured it
sudo tee /etc/bareos/scripts/delete-catalog-dump.sh > /dev/null <<'EOF'
#!/bin/sh
set -eu
rm -f /var/lib/bareos/catalog-dump/bareos-catalog.sql.gz
EOF
sudo chmod 0755 /etc/bareos/scripts/delete-catalog-dump.sh

# The BackupCatalog job
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupCatalog.conf > /dev/null <<'EOF'
Job {
  Name = "BackupCatalog"
  JobDefs = "StandardBackup"

  # Always a Full backup (the dump is always a complete snapshot)
  Level = Full

  # Use a dedicated catalog pool with longer retention
  Pool = Full

  # The File Daemon that reads the dump file
  Client = bareos-fd

  # Special FileSet that only includes the catalog dump directory
  FileSet = "Catalog"

  # Run daily, after the regular backup window
  Schedule = "WeeklyCycleAfterBackup"

  # Create the dump before the job. RunsOnClient = no means the command runs
  # in the Director container (which has the DB credentials), not on the FD.
  RunScript {
    RunsWhen        = Before
    RunsOnClient    = no
    FailJobOnError  = yes
    Command         = "/etc/bareos/scripts/dump-catalog.sh"
  }

  # Remove the dump after the job, whether it succeeded or failed.
  RunScript {
    RunsWhen        = After
    RunsOnClient    = no
    RunsOnSuccess   = yes
    RunsOnFailure   = yes
    Command         = "/etc/bareos/scripts/delete-catalog-dump.sh"
  }

  Write Bootstrap = "/var/lib/bareos/bareos-catalog.bsr"

  Priority = 11     # Run slightly after regular backup jobs (higher number = lower priority)
}
EOF

# Schedule for catalog backup (after main backup window)
sudo -u bareos tee /etc/bareos/bareos-dir.d/schedule/WeeklyCycleAfterBackup.conf > /dev/null <<'EOF'
Schedule {
  Name = "WeeklyCycleAfterBackup"
  Run = Level=Full sun-sat at 23:10
}
EOF

# FileSet for the catalog dump
sudo -u bareos tee /etc/bareos/bareos-dir.d/fileset/Catalog.conf > /dev/null <<'EOF'
FileSet {
  Name = "Catalog"
  Include {
    Options {
      Signature = SHA256
    }
    # The dump lands on the shared bareos-working volume, which the FD also
    # mounts at /var/lib/bareos — so it is referenced as-is, with no /hostfs prefix.
    File = /var/lib/bareos/catalog-dump
  }
}
EOF
```

> **Critical**: The dump runs **inside the Director container** (`RunsOnClient = no` directs the command to the Director, *not* to the File Daemon). It connects to the `bareos-db` container over the network with `mariadb-dump` and writes a gzipped SQL dump onto the shared `bareos-working` volume. The `bareos-fd` container, which mounts that same volume at `/var/lib/bareos`, then backs the dump up to a Volume. If you ever need to recover the catalog, you restore this dump and import it into a fresh MariaDB instance. (On a traditional RPM install the equivalent stock scripts are `make_catalog_backup.pl` and `delete_catalog_backup`; we do not use them here because there is no local DB socket — the catalog lives in a separate container. We also omit `--events/--routines/--triggers`: the Bareos catalog has none, and the `bareos` DB user lacks the privileges to dump them.)

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Labeling Volumes

Before Bareos can write to any storage Volume, it must **label** it. A label is a Bareos-format header written to the beginning of the Volume file. Bareos refuses to write backup data to an unlabeled file — this prevents accidental overwrite of non-backup data.

### Automatic Labeling

The `LabelMedia = yes` directive in the `Device` configuration (which we set in Chapter 6) allows Bareos to automatically label new Volumes as needed. This is the recommended setting for disk-based storage.

With `LabelMedia = yes`, Bareos will:
1. Look in the storage directory for new, unlabeled files
2. If a Pool is configured with `Label Format`, automatically create new Volume files following the pattern
3. Label them on first use

### Manual Labeling (for explicit control)

For environments where you want to explicitly control Volume names:

```
# In bconsole:
*label volume=Full-0001 pool=Full storage=File
```

This creates and labels a new Volume named `Full-0001` in the `Full` pool.

### Verifying Volumes in bconsole

```
*list volumes pool=Full
+----------+---------+-------+----------+----------+----------+---------+
| VolumeName | VolStatus | MediaType | VolBytes | NumJobs | LastWritten |
+----------+---------+-------+----------+----------+----------+---------+
| Full-0001  | Append    | File      | 0        | 0       | None        |
+----------+---------+-------+----------+----------+----------+---------+

*list volumes pool=Incremental
(empty — no volumes yet; will be created automatically on first use)
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Running Your First Manual Backup

After defining all resources, reload the Director configuration and run a job manually.

### Reloading the Director Configuration

The Director can reload its configuration without restarting (no service interruption):

```
# In bconsole:
*reload
```

Expected:
```
1000 OK: bareos-dir Version: 24.0.0 ... reloaded
```

If there is a configuration syntax error:
```
*reload
ERROR: Could not reload config: ...
```

The Director remains running with the old configuration. Fix the error and reload again.

### Running a Job Manually

```
# In bconsole
*run job=BackupLocalHost level=Full

Run Backup job
JobName:  BackupLocalHost
Level:    Full
Client:   bareos-fd
FileSet:  RHEL10-Standard
Pool:     Full (From JobDef FullPool override)
Storage:  File (From JobDef setting)
When:     2026-02-24 23:00:00
Priority: 10
OK to run? (yes/mod/no):
```

Type `yes` to confirm:

```
Job queued. JobId=1
```

### Watching Job Progress

```
# Watch the job in real time
*messages

# Or view the specific job's status
*status jobid=1

JobId 1: Type=Backup Level=Full Client=bareos-fd
         JobStatus=R (running)
         StartTime=2026-02-24 22:00:05
         Files=12,345  Bytes=156,890,123
         Elapsed=0:01:23
         ...
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Reading the Job Log Output

When a job completes, Bareos writes a detailed report to the Messages resource. Here is how to read it:

```
*list joblog jobid=1
```

Example successful job log:
```
24-Feb 22:00 bareos-dir JobId 1: Start Backup JobId 1, Job=BackupLocalHost.2026-02-24_22.00.05_04
24-Feb 22:00 bareos-dir JobId 1: Using Device "FileStorage" to write.
24-Feb 22:00 bareos-fd  JobId 1: Connected to Storage at bareos-storage:9103 with TLSv1.3.
24-Feb 22:00 bareos-fd  JobId 1: Start Accurate Fileset "RHEL10-Standard" OK.
24-Feb 22:01 bareos-sd  JobId 1: Wrote label to Volume "Full-0001"
24-Feb 22:03 bareos-dir JobId 1: Created new Volume="Full-0001" in catalog.
24-Feb 22:15 bareos-fd  JobId 1: End of Accurate Fileset "RHEL10-Standard" OK.
24-Feb 22:15 bareos-fd  JobId 1: Sending Accurate information to Director.

Bareos bareos-dir 24.0.0:
  Build OS:               x86_64-redhat-linux-gnu
  JobId:                  1
  Job:                    BackupLocalHost.2026-02-24_22.00.05_04
  Backup Level:           Full
  Client:                 "bareos-fd" 24.0.0
  FileSet:                "RHEL10-Standard"
  Pool:                   "Full" (From JobDef setting)
  Catalog:                "MyCatalog" (From Client resource)
  Storage:                "File" (From JobDef setting)
  Scheduled time:         24-Feb-2026 22:00:00
  Start time:             24-Feb-2026 22:00:05
  End time:               24-Feb-2026 22:15:22
  Elapsed time:           15 mins 17 secs
  Priority:               10
  FD Files Written:       89,412
  SD Files Written:       89,412
  FD Bytes Written:       15,234,567,890 (15.23 GB)
  SD Bytes Written:       4,123,456,789 (4.12 GB)       ← compressed!
  Rate:                   16,621 KB/s
  Software Compression:   3.7:1 (73.0%)                 ← ZSTD compression ratio
  Non-fatal FD errors:    0
  SD Errors:              0
  FD termination status:  OK
  SD termination status:  OK
  Termination:            Backup OK
```

### Understanding the Job Report Fields

| Field | Meaning |
|---|---|
| `FD Files Written` | Total files the File Daemon processed |
| `SD Files Written` | Must equal FD Files Written (if different, investigate) |
| `FD Bytes Written` | Original uncompressed data size |
| `SD Bytes Written` | Actual size written to the Volume (after compression) |
| `Rate` | Backup throughput in KB/s |
| `Software Compression` | Compression ratio (3.7:1 means original was 3.7× the stored size) |
| `Non-fatal FD errors` | Files that had warnings (e.g., permission denied) but backup continued |
| `SD Errors` | Storage Daemon errors — **should always be 0** |
| `Termination: Backup OK` | The job succeeded |

### Common Termination Statuses

| Status | Meaning | Action |
|---|---|---|
| `Backup OK` | Success, no errors | None |
| `Backup OK -- with warnings` | Success but some files had issues | Review `Non-fatal FD errors` in the log |
| `Backup Error` | Job failed | Check log for error message |
| `Backup Canceled` | Manually canceled or timed out | Investigate cause |

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Scheduling Automatic Backups

The Schedule we defined fires automatically once the Director is running. To verify the schedule will trigger:

```
# In bconsole: show upcoming scheduled jobs
*show schedule=WeeklyBackup
Schedule {
  Name = "WeeklyBackup"
  Run = Level=Full on sun at 23:00
  Run = Level=Incremental on mon-sat at 23:00
}

# Show the upcoming scheduled runs
*status scheduler
Scheduler Jobs:

Schedule         Type       Level         Next Run
================================================================
WeeklyBackup     Backup     Full          Sun 25-Feb-2026 23:00
WeeklyBackup     Backup     Incremental   Mon 26-Feb-2026 23:00
================================================================
```

### Preventing Overlapping Jobs

If a previous job is still running when the next one is scheduled:

```bareos
Job {
  Name = "BackupLocalHost"
  ...
  # Do not start a second instance while one is already running.
  # Bareos refuses the duplicate instead of running both concurrently.
  Allow Duplicate Jobs = no

  # Cancel a scheduled run if it cannot start within 2 hours of its
  # scheduled time (e.g. the previous run is still occupying the resource).
  # Note: Maximum Start Delay does NOT serialize duplicates — it bounds how
  # long a queued job may wait past its scheduled time before being canceled.
  Maximum Start Delay = 2 hours
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Lab 7-1: Complete First Backup Configuration

Write all the configuration files in order. Start with the FileSet:

```bash
# Create the FileSet
sudo -u bareos tee /etc/bareos/bareos-dir.d/fileset/RHEL10-Standard.conf > /dev/null <<'FEOF'
FileSet {
  Name = "RHEL10-Standard"
  Include {
    Options {
      Signature = SHA256
      Compression = ZSTD
      AclSupport = yes
      XattrSupport = yes
      OneFs = yes
      Wild = "*/.cache/*"
      Wild = "*/tmp/*"
      Exclude = yes
    }
    File = /hostfs/home
    File = /hostfs/etc
    File = /hostfs/root
    File = /hostfs/opt
    File = /var/lib/bareos       # shared bareos-working volume — no /hostfs prefix
  }
  Exclude {
    File = /hostfs/proc
    File = /hostfs/sys
    File = /hostfs/dev
    File = /hostfs/run
    File = /hostfs/tmp
    File = /hostfs/var/tmp
    File = /hostfs/var/cache/dnf
    File = /hostfs/var/lib/containers/storage/overlay
    File = /hostfs/home/bareos/.local/share/containers/storage/overlay
    File = /hostfs/srv/bareos-storage/volumes
  }
}
FEOF

# Create the Schedule
sudo -u bareos tee /etc/bareos/bareos-dir.d/schedule/WeeklyBackup.conf > /dev/null <<'SEOF'
Schedule {
  Name = "WeeklyBackup"
  Run = Level=Full     sun at 23:00
  Run = Level=Incremental mon-sat at 23:00
}
SEOF

# Create the JobDefs template
sudo -u bareos tee /etc/bareos/bareos-dir.d/jobdefs/StandardBackup.conf > /dev/null <<'JDEOF'
JobDefs {
  Name = "StandardBackup"
  Type = Backup
  Storage = File
  Messages = Standard
  Priority = 10
  Accurate = yes
  Write Bootstrap = "/var/lib/bareos/%c.bsr"
  Pool = Incremental
  Full Backup Pool = Full
  Differential Backup Pool = Differential
}
JDEOF

# Create the main backup job
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupLocalHost.conf > /dev/null <<'JEOF'
Job {
  Name = "BackupLocalHost"
  JobDefs = "StandardBackup"
  Client = bareos-fd
  FileSet = "RHEL10-Standard"
  Schedule = "WeeklyBackup"
}
JEOF

# Catalog dump + cleanup scripts (run inside the bareos-director container)
sudo tee /etc/bareos/scripts/dump-catalog.sh > /dev/null <<'DEOF'
#!/bin/sh
set -eu
mkdir -p /var/lib/bareos/catalog-dump
mariadb-dump \
  --host=bareos-db \
  --user="${MARIADB_USER}" \
  --password="${MARIADB_PASSWORD}" \
  --single-transaction \
  "${MARIADB_DATABASE}" \
  | gzip > /var/lib/bareos/catalog-dump/bareos-catalog.sql.gz
DEOF
sudo tee /etc/bareos/scripts/delete-catalog-dump.sh > /dev/null <<'DDEOF'
#!/bin/sh
set -eu
rm -f /var/lib/bareos/catalog-dump/bareos-catalog.sql.gz
DDEOF
sudo chmod 0755 /etc/bareos/scripts/dump-catalog.sh /etc/bareos/scripts/delete-catalog-dump.sh

# Create the catalog backup job
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupCatalog.conf > /dev/null <<'CEOF'
Job {
  Name = "BackupCatalog"
  JobDefs = "StandardBackup"
  Level = Full
  Pool = Full
  Client = bareos-fd
  FileSet = "Catalog"
  Schedule = "WeeklyCycleAfterBackup"
  RunScript {
    RunsWhen       = Before
    RunsOnClient   = no
    FailJobOnError = yes
    Command        = "/etc/bareos/scripts/dump-catalog.sh"
  }
  RunScript {
    RunsWhen      = After
    RunsOnClient  = no
    RunsOnSuccess = yes
    RunsOnFailure = yes
    Command       = "/etc/bareos/scripts/delete-catalog-dump.sh"
  }
  Write Bootstrap = "/var/lib/bareos/bareos-catalog.bsr"
  Priority = 11
}
CEOF

# Catalog FileSet (dump lives on the shared bareos-working volume — no /hostfs prefix)
sudo -u bareos tee /etc/bareos/bareos-dir.d/fileset/Catalog.conf > /dev/null <<'CFEOF'
FileSet {
  Name = "Catalog"
  Include {
    Options { Signature = SHA256 }
    File = /var/lib/bareos/catalog-dump
  }
}
CFEOF

# Catalog-after-backup schedule
sudo -u bareos tee /etc/bareos/bareos-dir.d/schedule/WeeklyCycleAfterBackup.conf > /dev/null <<'CSEOF'
Schedule {
  Name = "WeeklyCycleAfterBackup"
  Run = Level=Full sun-sat at 23:10
}
CSEOF

echo "Configuration files created. Validating..."
# Validate from inside the Director container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director \
  bareos-dir -t -c /etc/bareos
echo "Validation complete. Reloading the Director..."
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "reload"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 7-2: Running and Monitoring the Job

Each step below shows both the `bconsole` command and the equivalent action in the **Bareos WebUI** (`http://localhost:9100/bareos-webui`). Use whichever you prefer — both achieve the same result.

```bash
# Step 1: Reload the Director to pick up new config
# bconsole:
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "reload"
```

> **WebUI equivalent — Step 1:** Navigate to **Director → Reload** (top-right menu) or simply make any configuration change take effect — the WebUI triggers a reload automatically when you use its configuration forms.

```bash
# Step 2: Verify the client is reachable
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "status client=bareos-fd"
```

> **WebUI equivalent — Step 2:** Go to **Clients** in the left sidebar. The client `bareos-fd` should show status **Online**. Click it to see connection details.

```bash
# Step 3: Label a Volume manually (optional — LabelMedia=yes labels new
# Volumes automatically on first write, so you can skip this step entirely).
# Run it only if you want explicitly named Volumes:
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "label volume=Full-0001 pool=Full storage=File"
```

> **WebUI equivalent — Step 3:** Go to **Storage → Volumes → Label Volume**. Select the pool, storage, and enter the volume name.

```bash
# Step 4: Run the first Full backup manually
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'EOF'
run job=BackupLocalHost level=Full yes
wait
messages
quit
EOF
```

> **WebUI equivalent — Step 4:** Go to **Jobs → Run Job**. Select job `BackupLocalHost`, set Level to `Full`, and click **Run**. Watch the job appear in the **Jobs → Running** list.

```bash
# Step 5: Check the job result
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "list jobs"
```

> **WebUI equivalent — Step 5:** Go to **Jobs → All Jobs**. You will see the completed job with its status, runtime, files backed up, and bytes written. Click the job row to see the full log.

```bash
# Step 6: Verify files were cataloged
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "list files jobid=1" | head -20
```

> **WebUI equivalent — Step 6:** Open the job details page (from **Jobs → All Jobs**, click the Job ID). The **Files** tab lists all cataloged files.

```bash
# Step 7: Check volume usage
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "list volumes"
```

> **WebUI equivalent — Step 7:** Go to **Storage → Volumes**. Each volume shows its pool, status, number of jobs written, and bytes used.

```bash
# Step 8: Run an Incremental (make a change first)
echo "test incremental change" >> /etc/bareos-test-change.txt
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'EOF'
run job=BackupLocalHost level=Incremental yes
wait
messages
quit
EOF
```

> **WebUI equivalent — Step 8:** Same as Step 4 — **Jobs → Run Job**, but set Level to `Incremental`. After it finishes, notice the Files and Bytes counts are much smaller than the Full.

```bash
# Step 9: Verify only changed files were in the incremental
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "list files jobid=2" | wc -l
# Expected: only a handful of files (just the ones that changed)

# Cleanup test file
rm -f /etc/bareos-test-change.txt
```

> **WebUI equivalent — Step 9:** Open job 2's detail page. The Files tab shows only the changed file — compare the count to job 1's Full backup.

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Summary

In this chapter you created and ran your first complete Bareos backup configuration:

- **Job anatomy**: A Job resource ties together Client, FileSet, Schedule, Storage, Pool, Messages, and an optional JobDefs template.
- **FileSet**: Defined exactly what to include (`/home`, `/etc`, etc.) and what to exclude (`/proc`, `/sys`, container overlay layers, the backup storage itself). Options control checksum type (SHA256), compression (ZSTD), ACL/xattr preservation, and filesystem boundary control.
- **Schedule**: Weekly Full on Sunday, Incremental Mon-Sat. Schedules can override job-level `Level` on a per-run basis.
- **JobDefs**: DRY template for shared job settings. Multiple jobs inherit from one `JobDefs` to reduce repetition.
- **BackupCatalog job**: Critical — always configure this. A `RunScript` with `RunsOnClient = no` dumps the MariaDB catalog from inside the Director container (over the network to `bareos-db`) onto the shared `bareos-working` volume, and the File Daemon backs that dump up to a Volume. This is your recovery path if you lose the catalog.
- **Volume labeling**: `LabelMedia = yes` in the Storage Device enables automatic labeling. Manual labeling is done with `label` in bconsole or via **Storage → Volumes → Label Volume** in the WebUI.
- **Running jobs**: `run job=Name level=Full yes` in bconsole, or **Jobs → Run Job** in the WebUI. `messages` / the job details page shows the result. `list jobs` / **Jobs → All Jobs** shows history.
- **Reading job reports**: `FD Files/Bytes Written` vs `SD Files/Bytes Written` reveals compression effectiveness. `Termination: Backup OK` is the only acceptable outcome.
- **Accurate mode**: Enables precise change detection using a full file index comparison instead of mtime-only. Recommended for production.
- **WebUI**: Every bconsole operation in this chapter has an equivalent in the WebUI at `http://localhost:9100/bareos-webui`. Use the WebUI for day-to-day monitoring; use bconsole for scripting and diagnostics.

---

**Next Chapter:** [Chapter 8: Restoring Data](./08-restore.md)

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
