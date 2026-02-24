# Chapter 7: Your First Backup Job

## Table of Contents
1. [Anatomy of a Bareos Job](#1-anatomy-of-a-bareos-job)
2. [Defining a FileSet](#2-defining-a-fileset)
3. [Defining a Schedule](#3-defining-a-schedule)
4. [Defining JobDefs (Templates)](#4-defining-jobdefs-templates)
5. [Defining the Backup Job](#5-defining-the-backup-job)
6. [The BackupCatalog Job (Never Skip This)](#6-the-backupcatalog-job-never-skip-this)
7. [Labeling Volumes](#7-labeling-volumes)
8. [Running Your First Manual Backup](#8-running-your-first-manual-backup)
9. [Reading the Job Log Output](#9-reading-the-job-log-output)
10. [Scheduling Automatic Backups](#10-scheduling-automatic-backups)
11. [Lab 7-1: Complete First Backup Configuration](#11-lab-7-1-complete-first-backup-configuration)
12. [Lab 7-2: Running and Monitoring the Job](#12-lab-7-2-running-and-monitoring-the-job)
13. [Summary](#13-summary)

---

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

Bareos supports four Job types:

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

    # Core data directories
    File = /home
    File = /etc
    File = /var/www
    File = /var/lib/bareos       # Bareos working data (bootstrap files)
    File = /opt                  # Locally installed applications
    File = /srv                  # Service data (NOT the backup volumes themselves)
    File = /root                 # Root user's home
  }

  Exclude {
    # Virtual/kernel filesystems — never back these up
    File = /proc
    File = /sys
    File = /dev
    File = /run
    File = /tmp
    File = /var/tmp
    File = /lost+found

    # Swap
    File = /swap.img
    File = /var/lib/swap

    # Package caches — can be regenerated
    File = /var/cache/dnf
    File = /var/cache/yum

    # Container overlay storage — ephemeral, re-pull images instead
    File = /var/lib/containers/storage/overlay
    File = /home/bareos/.local/share/containers/storage/overlay

    # The backup storage itself (never back up your backups to themselves)
    File = /srv/bareos-storage/volumes
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

  # Weekly Full every other Sunday → Weekly pool
  Run = Level=Full Pool=Weekly sun at 23:00

  # Daily Incremental Mon-Sat → Daily pool
  Run = Level=Incremental Pool=Daily mon-sat at 23:00
}
```

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

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupCatalog.conf > /dev/null <<'EOF'
Job {
  Name = "BackupCatalog"
  JobDefs = "StandardBackup"

  # Always a Full backup (the dump is always a complete snapshot)
  Level = Full

  # Use a dedicated catalog pool with longer retention
  Pool = Full

  # The catalog client is the Director host itself
  Client = bareos-fd

  # Special FileSet that only includes the catalog dump
  FileSet = "Catalog"

  # Run daily at 00:30, 30 minutes after the regular backup window
  Schedule = "WeeklyCycleAfterBackup"

  # Use a RunBeforeJob script to create the dump
  # This script is provided by Bareos and dumps all catalogs to /var/lib/bareos/
  RunBeforeJob = "/usr/lib/bareos/scripts/make_catalog_backup.pl MyCatalog"

  # Prune old catalog records after backing up
  RunAfterJob = "/usr/lib/bareos/scripts/delete_catalog_backup"

  Write Bootstrap = "/var/lib/bareos/%n.bsr"

  Priority = 11     # Run slightly after regular backup jobs (lower number = higher priority)
}
EOF

# Schedule for catalog backup (30 minutes after main backup window)
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
    # Bareos catalog backup script writes dumps here
    File = "/var/lib/bareos/bareos.sql"
  }
}
EOF
```

> **Critical**: The `make_catalog_backup.pl` script runs on the File Daemon host (the Director host in our setup). It uses `mysqldump` / `mariadb-dump` to create a plain-SQL dump of the entire catalog. This dump is then backed up by the regular backup engine to a Volume. If you ever need to recover the catalog, you restore this dump and import it into a fresh MariaDB instance.

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
*label volume=Full-0001 pool=Full storage=File mediatype=File
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
Pool:     Full (From Job FullPool override)
Storage:  File (From Job resource)
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

# Show all jobs scheduled to run in the next 24 hours
*list nextjobs
+----------+---------------------+-------------+-------+-------+
| JobId    | Scheduled Time      | Name        | Level | Client|
+----------+---------------------+-------------+-------+-------+
| 0        | 2026-02-25 23:00:00 | BackupLocalHost | Full  | bareos-fd |
+----------+---------------------+-------------+-------+-------+
```

### Preventing Overlapping Jobs

If a previous job is still running when the next one is scheduled:

```bareos
Job {
  Name = "BackupLocalHost"
  ...
  # If a previous instance is running, wait up to 24 hours
  # before starting the new instance
  Maximum Start Delay = 24 hours

  # Allow only one simultaneous instance of this job
  Allow Mixed Priority = no
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
    File = /home
    File = /etc
    File = /root
    File = /opt
    File = /var/lib/bareos
  }
  Exclude {
    File = /proc
    File = /sys
    File = /dev
    File = /run
    File = /tmp
    File = /var/tmp
    File = /var/cache/dnf
    File = /var/lib/containers/storage/overlay
    File = /home/bareos/.local/share/containers/storage/overlay
    File = /srv/bareos-storage/volumes
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

# Create the catalog backup job
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupCatalog.conf > /dev/null <<'CEOF'
Job {
  Name = "BackupCatalog"
  JobDefs = "StandardBackup"
  Level = Full
  Client = bareos-fd
  FileSet = "Catalog"
  Schedule = "WeeklyCycleAfterBackup"
  RunBeforeJob = "/usr/lib/bareos/scripts/make_catalog_backup.pl MyCatalog"
  RunAfterJob  = "/usr/lib/bareos/scripts/delete_catalog_backup"
  Write Bootstrap = "/var/lib/bareos/%n.bsr"
  Priority = 11
}
CEOF

# Catalog FileSet
sudo -u bareos tee /etc/bareos/bareos-dir.d/fileset/Catalog.conf > /dev/null <<'CFEOF'
FileSet {
  Name = "Catalog"
  Include {
    Options { Signature = SHA256 }
    File = "/var/lib/bareos/bareos.sql"
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
echo "Validation complete. Reload the Director..."
echo "status director" | bconsole > /dev/null && \
  echo "reload" | bconsole
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 7-2: Running and Monitoring the Job

```bash
# Step 1: Reload the Director to pick up new config
echo "reload" | bconsole

# Step 2: Verify the client is reachable
echo "status client=bareos-fd" | bconsole

# Step 3: Label a Volume manually (optional - LabelMedia=yes handles this automatically)
# bconsole:
# *label volume=Full-0001 pool=Full storage=File mediatype=File

# Step 4: Run the first Full backup manually
bconsole <<'EOF'
run job=BackupLocalHost level=Full yes
wait
messages
quit
EOF

# Step 5: Check the job result
echo "list jobs" | bconsole

# Step 6: Verify files were cataloged
echo "list files jobid=1" | bconsole | head -20

# Step 7: Check volume usage
echo "list volumes" | bconsole

# Step 8: Run an Incremental (make a change first)
echo "test incremental change" >> /etc/bareos-test-change.txt
bconsole <<'EOF'
run job=BackupLocalHost level=Incremental yes
wait
messages
quit
EOF

# Step 9: Verify only changed files were in the incremental
echo "list files jobid=2" | bconsole | wc -l
# Expected: only a handful of files (just the ones that changed)

# Cleanup test file
rm -f /etc/bareos-test-change.txt
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Summary

In this chapter you created and ran your first complete Bareos backup configuration:

- **Job anatomy**: A Job resource ties together Client, FileSet, Schedule, Storage, Pool, Messages, and an optional JobDefs template.
- **FileSet**: Defined exactly what to include (`/home`, `/etc`, etc.) and what to exclude (`/proc`, `/sys`, container overlay layers, the backup storage itself). Options control checksum type (SHA256), compression (ZSTD), ACL/xattr preservation, and filesystem boundary control.
- **Schedule**: Weekly Full on Sunday, Incremental Mon-Sat. Schedules can override job-level `Level` on a per-run basis.
- **JobDefs**: DRY template for shared job settings. Multiple jobs inherit from one `JobDefs` to reduce repetition.
- **BackupCatalog job**: Critical — always configure this. It dumps MariaDB with `make_catalog_backup.pl` and backs the dump to a Volume. This is your recovery path if you lose the catalog.
- **Volume labeling**: `LabelMedia = yes` in the Storage Device enables automatic labeling. Manual labeling is done with `label` in bconsole.
- **Running jobs**: `run job=Name level=Full yes` in bconsole runs a job immediately. `messages` shows the result. `list jobs` shows history.
- **Reading job reports**: `FD Files/Bytes Written` vs `SD Files/Bytes Written` reveals compression effectiveness. `Termination: Backup OK` is the only acceptable outcome.
- **Accurate mode**: Enables precise change detection using a full file index comparison instead of mtime-only. Recommended for production.

---

**Next Chapter:** [Chapter 8: Restoring Data](./08-restore.md)

---

[↑ Back to Table of Contents](#table-of-contents)
