# Chapter 16: Advanced Schedules, Pools, and Retention Policies
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. The Backup Retention Lifecycle](#1-the-backup-retention-lifecycle)
  - [Phase 1: Creation](#phase-1-creation)
  - [Phase 2: Full Retention Period](#phase-2-full-retention-period)
  - [Phase 3: Pruning](#phase-3-pruning)
  - [Phase 4: Recycling](#phase-4-recycling)
- [2. Schedule Resource Deep Dive](#2-schedule-resource-deep-dive)
  - [The Run Directive](#the-run-directive)
  - [Time Specifiers](#time-specifiers)
  - [Hourly and Continuous Schedules](#hourly-and-continuous-schedules)
- [3. Full/Differential/Incremental Rotation and GFS Strategy](#3-fulldifferentialincremental-rotation-and-gfs-strategy)
  - [Understanding Backup Levels](#understanding-backup-levels)
  - [The GFS (Grandfather-Father-Son) Strategy](#the-gfs-grandfather-father-son-strategy)
- [4. How Bareos Determines Backup Level](#4-how-bareos-determines-backup-level)
  - [Level Upgrade Rules](#level-upgrade-rules)
  - [The Catalog Query](#the-catalog-query)
  - [Checking Level Decisions in bconsole](#checking-level-decisions-in-bconsole)
- [5. Pool Resource Anatomy](#5-pool-resource-anatomy)
  - [Complete Annotated Pool Resource](#complete-annotated-pool-resource)
  - [Directive Reference Table](#directive-reference-table)
- [6. Multiple Pool Strategy: Daily, Weekly, Monthly, Yearly](#6-multiple-pool-strategy-daily-weekly-monthly-yearly)
  - [Pool Configurations](#pool-configurations)
  - [GFS Schedule Configuration](#gfs-schedule-configuration)
  - [Job Configuration Using GFS Schedule](#job-configuration-using-gfs-schedule)
- [7. LabelFormat: Automatic Volume Labeling with Date Stamps](#7-labelformat-automatic-volume-labeling-with-date-stamps)
  - [Available Template Variables](#available-template-variables)
  - [Padding Format Modifier](#padding-format-modifier)
  - [Complete Label Examples](#complete-label-examples)
  - [Manually Labeling Volumes](#manually-labeling-volumes)
- [8. Storage Daemon Volume Configuration: What Happens on Disk](#8-storage-daemon-volume-configuration-what-happens-on-disk)
  - [Directory Structure on Disk](#directory-structure-on-disk)
  - [SELinux Context for Storage Directory](#selinux-context-for-storage-directory)
  - [Storage Daemon Device Resource](#storage-daemon-device-resource)
  - [Director's Storage Resource (Connects Director to Storage Daemon)](#directors-storage-resource-connects-director-to-storage-daemon)
- [9. Pruning: Jobs, Volumes, Files](#9-pruning-jobs-volumes-files)
  - [The Three Pruning Levels](#the-three-pruning-levels)
  - [Automatic Pruning](#automatic-pruning)
  - [Viewing What Would Be Pruned](#viewing-what-would-be-pruned)
- [10. Recycling: How Bareos Reclaims Volumes](#10-recycling-how-bareos-reclaims-volumes)
  - [Recycling Conditions](#recycling-conditions)
  - [The Recycle Algorithm](#the-recycle-algorithm)
  - [Recycling Across Pools with Recycle Pool](#recycling-across-pools-with-recycle-pool)
  - [Forcing Recycling Manually](#forcing-recycling-manually)
- [11. The Catalog's Role in Retention](#11-the-catalogs-role-in-retention)
  - [Key Catalog Tables](#key-catalog-tables)
  - [Retention Period Interaction](#retention-period-interaction)
  - [Querying the Catalog Directly](#querying-the-catalog-directly)
- [12. Copy Jobs and Migration Jobs](#12-copy-jobs-and-migration-jobs)
  - [Copy Job Configuration](#copy-job-configuration)
  - [Migration Job Configuration](#migration-job-configuration)
- [13. Virtual Full Backup](#13-virtual-full-backup)
  - [How Virtual Full Works Internally](#how-virtual-full-works-internally)
  - [Virtual Full Job Configuration](#virtual-full-job-configuration)
  - [Running a Virtual Full Manually in bconsole](#running-a-virtual-full-manually-in-bconsole)
- [14. Advanced FileSet Include/Exclude Patterns](#14-advanced-fileset-includeexclude-patterns)
  - [Complete Annotated FileSet](#complete-annotated-fileset)
  - [Options Directive Reference](#options-directive-reference)
- [15. Multiple Storage Daemon Setup](#15-multiple-storage-daemon-setup)
  - [Multiple Storage Configuration](#multiple-storage-configuration)
  - [Routing Jobs to Different Storages](#routing-jobs-to-different-storages)
  - [Quadlet for Second Storage Daemon](#quadlet-for-second-storage-daemon)
- [16. Lab 16-1: Build a Complete GFS Schedule with Four Pools](#16-lab-16-1-build-a-complete-gfs-schedule-with-four-pools)
  - [Prerequisites](#prerequisites)
  - [Step 1: Create the Storage Directory Structure](#step-1-create-the-storage-directory-structure)
  - [Step 2: Write the Pool Configuration](#step-2-write-the-pool-configuration)
  - [Step 3: Write the Schedule Configuration](#step-3-write-the-schedule-configuration)
  - [Step 4: Write the Job Configurations](#step-4-write-the-job-configurations)
  - [Step 5: Reload Bareos Director](#step-5-reload-bareos-director)
  - [Step 6: Verify Configuration in bconsole](#step-6-verify-configuration-in-bconsole)
  - [Step 7: Trigger a Manual Full to Seed the GFS Chain](#step-7-trigger-a-manual-full-to-seed-the-gfs-chain)
- [17. Lab 16-2: Force a Virtual Full and Verify in bconsole](#17-lab-16-2-force-a-virtual-full-and-verify-in-bconsole)
  - [Prerequisites](#prerequisites)
  - [Step 1: Verify the Backup Chain Exists](#step-1-verify-the-backup-chain-exists)
  - [Step 2: Add the Virtual Full Job](#step-2-add-the-virtual-full-job)
  - [Step 3: Run the Virtual Full](#step-3-run-the-virtual-full)
  - [Step 4: Verify in bconsole](#step-4-verify-in-bconsole)
- [18. Lab 16-3: Configure a Copy Job to Duplicate Critical Backups](#18-lab-16-3-configure-a-copy-job-to-duplicate-critical-backups)
  - [Step 1: Add the Offsite Pool](#step-1-add-the-offsite-pool)
  - [Step 2: Add the Copy Job](#step-2-add-the-copy-job)
  - [Step 3: Reload and Run the Copy Job](#step-3-reload-and-run-the-copy-job)
  - [Step 4: Verify Both Copies Exist](#step-4-verify-both-copies-exist)
- [19. Summary](#19-summary)

## 1. The Backup Retention Lifecycle

Understanding how Bareos manages the lifetime of a backup — from the moment data is written to tape or disk until the volume is physically overwritten — is the foundation for designing any reliable backup strategy. This lifecycle has four distinct phases, and every Pool and Schedule configuration you write is ultimately governing which phase a given backup occupies at any moment.

### Phase 1: Creation

A backup job runs. The Bareos Director contacts the File Daemon on the client, negotiates what files to back up, and streams data through the Storage Daemon onto a Volume (a physical file on disk or a tape cartridge). The catalog — a MariaDB or PostgreSQL database maintained by the Director — records metadata: which job ran, when, what files were included, how many bytes were transferred, and which Volume holds the data. At this point the job has the status `T` (Terminated successfully) and the Volume is in the `Append` state.

The critical insight is that **Bareos never deletes data from a Volume directly based on age**. It deletes *catalog records*, and only reclaims a Volume when every job recorded on it has been pruned from the catalog and the Volume itself has aged past its retention settings.

### Phase 2: Full Retention Period

During this phase the job record, the file records, and the volume are all present in the catalog. You can run a full restore. The length of this phase is controlled by three separate retention settings that you configure on the Client resource and the Pool resource:

- **File Retention** — how long individual file records (path, checksum, attributes) are kept in the catalog. File records are voluminous; keeping them too long bloats the catalog.
- **Job Retention** — how long job summary records (start time, end time, bytes, status) are kept. These are much lighter than file records.
- **Volume Retention** — the minimum time Bareos will wait before considering a Volume eligible for recycling, regardless of what the catalog says.

These three periods can be tuned independently. A common strategy is to keep File Retention short (30 days) to control catalog size, Job Retention longer (1 year) for auditing, and Volume Retention matching the desired restore window.

### Phase 3: Pruning

Once a retention period expires, Bareos does not automatically delete anything. Pruning is either triggered manually (`prune jobs`, `prune files`, `prune volumes` in bconsole) or automatically when `AutoPrune = yes` is set on the Client and Pool resources.

When a pruning run happens:
- Expired **file records** are deleted from the `File` table. You can no longer browse the directory tree for that job, but you can still restore the job as a whole if the job record and volume exist.
- Expired **job records** are deleted from the `Job` table. The job no longer appears in `list jobs`.
- A Volume is marked **Purged** when every job written to it has been removed from the catalog (either pruned or manually deleted).

A Purged volume is safe to recycle, but Bareos will not actually overwrite it until recycling runs.

### Phase 4: Recycling

A Volume in the **Purged** state and with `Recycle = yes` set on its Pool becomes a candidate for reuse. When the Director needs a new volume and finds no empty labeled volumes available, it looks for the oldest Purged volume in the pool and recycles it — resetting its catalog record and overwriting it from the start. This is analogous to taping over an old VHS cassette.

The `Recycle Pool` directive lets you redirect purged volumes to a different pool (for example, a "scratch" pool) rather than recycling them in place. This is useful when you want to manually audit volumes before they are reused.

```
Phase 1: Creation → Volume = "Append", Job = "T", all catalog records present
Phase 2: Full Retention → Volume = "Full" or "Append", restores available
Phase 3: Pruning → File/Job records deleted, Volume eventually = "Purged"
Phase 4: Recycling → Volume overwritten, ready for new data
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Schedule Resource Deep Dive

The **Schedule** resource in Bareos defines *when* a job runs and at *what level* (Full, Differential, or Incremental). A single Schedule can contain multiple `Run` directives, each with its own level and time specification. This allows one Schedule resource to express an entire GFS rotation — Full on Sundays, Differential on other weekdays, Incremental multiple times daily.

### The Run Directive

Every line inside a Schedule block is a `Run` directive:

```
Schedule {
  Name = "MySchedule"
  Run = Level=Full First Sun at 23:05
  Run = Level=Differential Mon-Sat at 23:05
  Run = Level=Incremental Mon-Sun at 06:05
  Run = Level=Incremental Mon-Sun at 12:05
  Run = Level=Incremental Mon-Sun at 18:05
}
```

The format of a Run directive is:

```
Run = [overrides] <time-specification>
```

**Overrides** are optional key=value pairs that can override job defaults:

| Override | Purpose |
|---|---|
| `Level=Full\|Differential\|Incremental\|VirtualFull` | Force a specific backup level |
| `Pool=<name>` | Write to a specific pool |
| `Storage=<name>` | Use a specific storage daemon |
| `Messages=<name>` | Use a specific messages resource |
| `Priority=<n>` | Set scheduling priority (lower = higher priority) |
| `SpoolData=yes\|no` | Override spool-to-disk setting |
| `MaxRunSchedTime=<time>` | Maximum run time for this scheduled execution |
| `Accurate=yes\|no` | Enable or disable accurate backup for this run |

### Time Specifiers

Bareos time specifiers are space-separated tokens. They are not a cron expression — they describe a specific time pattern using English-like keywords.

**Month specifiers** — restrict the run to specific months:

```
Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec
january, february, ...  (long form, also valid)
```

If no month is specified, the run applies to every month.

**Week-of-month specifiers** — restrict the run to a specific occurrence of a weekday within the month:

```
First        # first week of the month (days 1–7)
Second       # second week (days 8–14)
Third        # third week (days 15–21)
Fourth       # fourth week (days 22–28)
Fifth        # fifth week (days 29–31, if it exists)
Last         # last occurrence of the weekday in the month
```

**Day-of-week specifiers**:

```
Mon, Tue, Wed, Thu, Fri, Sat, Sun
monday, tuesday, ...
weekdays        # shorthand for Mon-Fri
weekend         # shorthand for Sat-Sun
```

You can specify a range: `Mon-Fri` or a list is implicit when multiple Run lines share the same time.

**Day-of-month specifiers** (ordinal numbers 1–31):

```
Run = Level=Full on 1 at 02:30    # First day of every month
Run = Level=Full on 15 at 02:30   # 15th of every month
```

**Hour and Minute**:

```
at HH:MM    # 24-hour clock, leading zeros optional
at 23:05
at 2:30
```

**Combining specifiers**:

```
# Full backup on the first Sunday of January, April, July, October (quarterly)
Run = Level=Full Pool=Quarterly Jan Apr Jul Oct First Sun at 01:00

# Monthly full on the last day of each month
Run = Level=Full Pool=Monthly Last Sun at 01:00

# Weekly differential every Saturday except the first Saturday
Run = Level=Differential Pool=Weekly Second Sat at 22:00
Run = Level=Differential Pool=Weekly Third Sat at 22:00
Run = Level=Differential Pool=Weekly Fourth Sat at 22:00
Run = Level=Differential Pool=Weekly Fifth Sat at 22:00
```

### Hourly and Continuous Schedules

For high-frequency backups, you can repeat the `Run` directive many times or use the `hourly` keyword:

```
Schedule {
  Name = "HourlyIncrementals"
  Run = Level=Incremental hourly at 0:05
}
```

`hourly at 0:05` means: at 5 minutes past every hour, every day. This produces 24 incremental jobs per day, which is common for database servers or NFS shares with frequent changes.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Full/Differential/Incremental Rotation and GFS Strategy

### Understanding Backup Levels

Bareos supports three main backup levels:

**Full** — Every file in the FileSet is backed up, regardless of whether it has changed. The resulting backup is self-contained: you can restore from it without any other backup. Drawback: slow, consumes the most storage.

**Differential** — All files that have changed since the *last Full* backup. To restore, you need the last Full plus the latest Differential. Differentials grow over time (they always compare against the Full, not the previous Differential).

**Incremental** — All files that have changed since the *last backup of any level* (Full, Differential, or Incremental). To restore, you need the last Full + last Differential + every Incremental since that Differential. Incrementals are small and fast but restore requires multiple steps.

**VirtualFull** — A special level discussed in Section 13. Bareos synthesizes a new Full in the catalog by combining an existing Full and subsequent Incrementals, without re-reading the client.

### The GFS (Grandfather-Father-Son) Strategy

GFS is the most widely used enterprise backup rotation strategy. It uses three (or four) tiers:

- **Son** — Daily backups (Incremental). Kept for one week (7 generations). These are your "quick restore" backups for recent changes.
- **Father** — Weekly backups (Differential or Full). Kept for one month (4–5 generations). Used when you need to restore to a point more than a week ago but within the last month.
- **Grandfather** — Monthly backups (Full). Kept for one year (12 generations). Used for longer-term recovery.
- **Great-Grandfather** — Yearly backups (Full). Kept indefinitely or for several years. Archival/compliance tier.

In Bareos, each tier typically maps to a separate **Pool**. This allows different retention policies per tier and lets volumes in each pool be sized and labeled appropriately.

```
         Mon  Tue  Wed  Thu  Fri  Sat  Sun
Week 1:   I    I    I    I    I    D    F(month end → Monthly pool)
Week 2:   I    I    I    I    I    D    F(week → Weekly pool)  
Week 3:   I    I    I    I    I    D    F(week → Weekly pool)
Week 4:   I    I    I    I    I    D    F(week → Weekly pool)

I = Incremental (Daily pool, 7-day retention)
D = Differential (Weekly pool, 30-day retention)  
F = Full (Weekly/Monthly/Yearly pool depending on date)
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. How Bareos Determines Backup Level

When a scheduled job runs with `Level=Incremental` or `Level=Differential`, Bareos does not blindly take an incremental or differential. It first queries the catalog to find the most recent successful backup of the appropriate level. If it cannot find the prerequisite, it **upgrades the level automatically**.

### Level Upgrade Rules

1. **Incremental with no prior Full** → upgraded to Full.
2. **Incremental with a prior Full but no prior Incremental or Differential since that Full** → runs as Incremental (comparing against the Full's timestamp).
3. **Differential with no prior Full** → upgraded to Full.
4. If `Always Incremental = yes` is set on the Job, Bareos uses a modified strategy (see Always Incremental documentation).

This auto-upgrade is a safety mechanism. When you first deploy a new client or add a new FileSet, Bareos will automatically run a Full before any Incrementals can succeed.

### The Catalog Query

Bareos runs roughly this logic (simplified):

```
For Incremental:
  SELECT MAX(EndTime) FROM Job
  WHERE ClientId = ? AND FileSetId = ? AND Level IN ('F','D','I')
    AND JobStatus = 'T' AND Type = 'B'

For Differential:
  SELECT MAX(EndTime) FROM Job
  WHERE ClientId = ? AND FileSetId = ? AND Level = 'F'
    AND JobStatus = 'T' AND Type = 'B'
```

If no record is found, the level is promoted to Full. This is why keeping `Job Retention` long enough to cover your backup cycle is critical — if job records are pruned before the next Full is due, every subsequent Incremental will silently become a Full, consuming far more storage than expected.

### Checking Level Decisions in bconsole

```
*list jobs client=myserver-fd fileset=LinuxAll
```

This shows recent job history for the client, including the Level column. You can verify that incrementals are correctly referencing the previous backup.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Pool Resource Anatomy

A **Pool** in Bareos is a logical grouping of Volumes with shared properties. Every Volume belongs to exactly one Pool. The Pool resource defines the rules that govern how volumes in that pool are created, filled, aged, and recycled. Understanding every important directive is essential before designing a multi-pool strategy.

### Complete Annotated Pool Resource

```hcl
Pool {
  # ──────────────────────────────────────────────────────────────
  # Identity
  # ──────────────────────────────────────────────────────────────

  Name = "Daily"
  # The unique name for this pool. Referenced by Job and Schedule resources.

  Pool Type = Backup
  # Always "Backup" for normal backup pools.
  # "Copy" and "Archive" are used for copy/migration jobs (Section 12).

  # ──────────────────────────────────────────────────────────────
  # Volume Labeling
  # ──────────────────────────────────────────────────────────────

  Label Format = "Daily-${Year}-${Month:p/2/0/r}-${Day:p/2/0/r}-"
  # Pattern used when Bareos automatically labels a new volume.
  # Variables: ${Year}, ${Month}, ${Day}, ${Hour}, ${Minute}, ${Second}
  # :p/2/0/r means: pad to width 2, pad character 0, right-align
  # This produces names like "Daily-2025-01-07-" followed by a sequence number.
  # Without LabelFormat, Bareos will ask the operator to label volumes manually.

  # ──────────────────────────────────────────────────────────────
  # Volume Count Limits
  # ──────────────────────────────────────────────────────────────

  Maximum Volumes = 14
  # Maximum number of volumes allowed in this pool.
  # When this limit is reached, Bareos will recycle the oldest eligible volume
  # rather than creating a new one. Set to a value that covers your retention
  # window: for a 7-day Daily pool, 14 gives 2x headroom.

  # ──────────────────────────────────────────────────────────────
  # Per-Volume Limits (when to close a volume and open a new one)
  # ──────────────────────────────────────────────────────────────

  Maximum Volume Jobs = 1
  # Maximum number of jobs that can be written to a single volume before
  # a new volume is created. Setting this to 1 means one job = one volume file.
  # This simplifies restore operations and makes retention calculation exact.
  # For tape, you might use a larger number to fill tapes efficiently.

  Maximum Volume Bytes = 50 GB
  # Maximum size of a single volume file. When this is reached, Bareos closes
  # the volume and creates a new one. This prevents runaway volumes from
  # consuming all disk space. Tune based on your average backup size.

  Volume Use Duration = 24 hours
  # Maximum wall-clock time a volume may remain in "Append" state.
  # Even if MaxVolumeJobs and MaxVolumeBytes haven't been hit, after this
  # duration the volume is closed. Useful to ensure daily volumes don't
  # accumulate across midnight. Set to 23h for daily jobs to be safe.

  # ──────────────────────────────────────────────────────────────
  # Retention (when to make a volume eligible for recycling)
  # ──────────────────────────────────────────────────────────────

  Volume Retention = 7 days
  # Minimum time a volume must exist before it can be recycled.
  # This is the primary retention knob for disk-based pools.
  # The volume will NOT be recycled until BOTH:
  #   1. This duration has passed since the volume was last written
  #   2. All jobs on the volume have been pruned from the catalog

  # ──────────────────────────────────────────────────────────────
  # Automatic Pruning and Recycling
  # ──────────────────────────────────────────────────────────────

  Auto Prune = yes
  # Automatically prune expired job and file records from the catalog
  # when a new volume is needed. Without this, volumes pile up as "Full"
  # and the pool runs out of space.

  Recycle = yes
  # Allow Bareos to reuse (recycle) purged volumes. If set to no, purged
  # volumes just sit there until a human manually deletes them.

  Recycle Pool = Scratch
  # Optional: when a volume is purged, move it to the "Scratch" pool
  # instead of recycling it in place. The Scratch pool acts as a holding
  # area. Useful in large environments where you want human oversight
  # before volumes are overwritten.

  # ──────────────────────────────────────────────────────────────
  # Storage Assignment
  # ──────────────────────────────────────────────────────────────

  Storage = FileStorage-Daily
  # Which Storage Daemon device this pool writes to by default.
  # Can be overridden in the Job or Schedule Run directive.
}
```

### Directive Reference Table

| Directive | Type | Purpose |
|---|---|---|
| `Label Format` | string/template | Auto-label format for new volumes |
| `Maximum Volumes` | integer | Max volumes allowed in pool |
| `Maximum Volume Jobs` | integer | Jobs per volume before closing |
| `Maximum Volume Bytes` | size | Bytes per volume before closing |
| `Volume Use Duration` | time | Wall time a volume stays open |
| `Volume Retention` | time | Minimum age before recycling |
| `Auto Prune` | yes/no | Auto-prune catalog on volume need |
| `Recycle` | yes/no | Allow volume reuse |
| `Recycle Pool` | pool name | Pool to send purged volumes to |
| `Storage` | storage name | Default storage for this pool |
| `Pool Type` | Backup/Copy/Archive | Pool purpose |

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Multiple Pool Strategy: Daily, Weekly, Monthly, Yearly

Here is a complete four-pool configuration suitable for a production GFS rotation. All files live at `/home/bareos/.config/containers/systemd/` for Quadlet, and Bareos Director configuration goes inside the Director container's configuration volume.

The Bareos Director container mounts its configuration from a named volume. You can find the actual data path at:

```
~/.local/share/containers/storage/volumes/bareos-director-config/_data/
```

Create a file `/home/bareos/.config/containers/systemd/bareos-director-config/_data/bareos-dir.d/pool/gfs-pools.conf` (or whichever path maps into your container's `/etc/bareos/bareos-dir.d/pool/` directory).

### Pool Configurations

```hcl
# /etc/bareos/bareos-dir.d/pool/gfs-pools.conf
# ─────────────────────────────────────────────────────────────────
# GFS Four-Pool Configuration
# Bareos 24 · RHEL 10 · Rootless Podman
# ─────────────────────────────────────────────────────────────────

# ─── DAILY POOL ──────────────────────────────────────────────────
# Holds incremental backups. Short retention, high churn.
Pool {
  Name                = "Daily"
  Pool Type           = Backup
  Label Format        = "Daily-${Year}-${Month:p/2/0/r}-${Day:p/2/0/r}-"
  Maximum Volumes     = 21          # 3 weeks of daily volumes (headroom)
  Maximum Volume Jobs = 1           # one job per volume, clean separation
  Maximum Volume Bytes = 30 GB
  Volume Use Duration = 23 hours    # force close before next daily run
  Volume Retention    = 8 days      # keep 8 days, prune after
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}

# ─── WEEKLY POOL ─────────────────────────────────────────────────
# Holds differential (or weekly full) backups. Medium retention.
Pool {
  Name                = "Weekly"
  Pool Type           = Backup
  Label Format        = "Weekly-${Year}-W${Week:p/2/0/r}-"
  Maximum Volumes     = 10          # ~2.5 months of weekly volumes
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 100 GB
  Volume Use Duration = 7 days
  Volume Retention    = 35 days     # keep 5 weeks
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}

# ─── MONTHLY POOL ────────────────────────────────────────────────
# Holds full backups taken on the first Sunday of each month.
Pool {
  Name                = "Monthly"
  Pool Type           = Backup
  Label Format        = "Monthly-${Year}-${Month:p/2/0/r}-"
  Maximum Volumes     = 15          # 15 months of monthly volumes
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 500 GB
  Volume Use Duration = 32 days
  Volume Retention    = 400 days    # keep ~13 months
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}

# ─── YEARLY POOL ─────────────────────────────────────────────────
# Holds the last full backup of each year. Long-term archival.
Pool {
  Name                = "Yearly"
  Pool Type           = Backup
  Label Format        = "Yearly-${Year}-"
  Maximum Volumes     = 10          # 10 years of yearly backups
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 2 TB
  Volume Use Duration = 400 days
  Volume Retention    = 3650 days   # keep 10 years
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}

# ─── SCRATCH POOL ────────────────────────────────────────────────
# Holding area for purged volumes awaiting reuse or disposal.
# Volumes move here from other pools when purged (Recycle Pool = Scratch).
Pool {
  Name      = "Scratch"
  Pool Type = Scratch
}
```

### GFS Schedule Configuration

```hcl
# /etc/bareos/bareos-dir.d/schedule/gfs-schedule.conf
# ─────────────────────────────────────────────────────────────────
# Complete GFS Schedule: Daily/Weekly/Monthly/Yearly
# ─────────────────────────────────────────────────────────────────

Schedule {
  Name = "GFS-Schedule"

  # ── YEARLY ────────────────────────────────────────────────────
  # Full backup on the last Sunday of December, written to Yearly pool.
  Run = Level=Full Pool=Yearly Dec Last Sun at 01:00

  # ── MONTHLY ───────────────────────────────────────────────────
  # Full backup on the First Sunday of each month (except December last week).
  # Pool=Monthly. This will NOT match Dec Last Sun because that Run comes first
  # and Bareos evaluates from top to bottom; actually in Bareos both matching
  # Runs will fire — so we use a separate job definition instead (see Lab 16-1).
  Run = Level=Full Pool=Monthly First Sun at 01:00

  # ── WEEKLY ────────────────────────────────────────────────────
  # Differential every Sunday that is NOT the First Sunday.
  # (Second, Third, Fourth, Fifth Sunday → Weekly pool)
  Run = Level=Differential Pool=Weekly Second Sun at 23:00
  Run = Level=Differential Pool=Weekly Third  Sun at 23:00
  Run = Level=Differential Pool=Weekly Fourth Sun at 23:00
  Run = Level=Differential Pool=Weekly Fifth  Sun at 23:00

  # ── DAILY ─────────────────────────────────────────────────────
  # Incremental every day Mon–Sat, written to Daily pool.
  Run = Level=Incremental Pool=Daily Mon-Sat at 23:00
}
```

### Job Configuration Using GFS Schedule

```hcl
# /etc/bareos/bareos-dir.d/job/backup-linux-gfs.conf

Job {
  Name            = "Backup-Linux-GFS"
  Type            = Backup
  Level           = Incremental    # default; Schedule overrides this per run
  Client          = myserver-fd
  FileSet         = "LinuxAll"
  Schedule        = "GFS-Schedule"
  Storage         = FileStorage
  Pool            = Daily          # default pool; Schedule Run overrides
  Messages        = Standard
  Priority        = 10
  Write Bootstrap = "/var/lib/bareos/%c.bsr"
  # Bootstrap files allow restore without catalog — keep these safe!
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. LabelFormat: Automatic Volume Labeling with Date Stamps

When Bareos needs a new volume and `Label Format` is set on the pool, it automatically creates and labels the volume without operator intervention. Without `Label Format`, the Director would wait indefinitely for a human to run `label` in bconsole.

### Available Template Variables

> **Note:** `Label Format` uses Bareos's own built-in variable substitution — **not** shell `date` formatting or C `strftime` specifiers. Variables like `${Year}`, `${Month}`, and `${Day}` are evaluated by the Bareos Director at label-creation time. Do not use `%Y`, `%m`, or `%d` (those are `strftime` format codes and will appear literally in the volume name).

| Variable | Description | Example |
|---|---|---|
| `${Year}` | 4-digit year | `2025` |
| `${Month}` | Month number (1–12) | `7` |
| `${Day}` | Day of month (1–31) | `4` |
| `${Hour}` | Hour (0–23) | `23` |
| `${Minute}` | Minute (0–59) | `5` |
| `${Second}` | Second (0–59) | `30` |
| `${Week}` | ISO week number (1–53) | `27` |
| `${WeekDay}` | Numeric weekday (0=Sun) | `0` |
| `${NumVols}` | Current volume count in pool | `5` |

### Padding Format Modifier

The `:p/width/char/side` modifier pads values for consistent sorting:

```
${Month:p/2/0/r}    → zero-pad to 2 chars on the right → "07"
${Day:p/2/0/r}      → "04"
${Week:p/2/0/r}     → "27"
```

### Complete Label Examples

```
# Daily volumes: Daily-2025-07-04-0001, Daily-2025-07-04-0002, ...
Label Format = "Daily-${Year}-${Month:p/2/0/r}-${Day:p/2/0/r}-"

# Weekly volumes by ISO week: Weekly-2025-W27-0001
Label Format = "Weekly-${Year}-W${Week:p/2/0/r}-"

# Monthly volumes: Monthly-2025-07-0001
Label Format = "Monthly-${Year}-${Month:p/2/0/r}-"

# Yearly volumes: Yearly-2025-0001
Label Format = "Yearly-${Year}-"
```

The suffix (e.g., `-0001`) is appended automatically by Bareos as a sequence number to ensure uniqueness within the pool.

### Manually Labeling Volumes

In bconsole you can label a volume manually (skipping LabelFormat):

```
*label
Automatically selected Storage: FileStorage
Enter new Volume name: Daily-Manual-001
Defined Pools:
     1: Daily
     2: Weekly
     ...
Select the Pool (1-5): 1
```

Or non-interactively:

```bash
# Run as bareos user with correct XDG_RUNTIME_DIR
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-dir \
  bconsole <<'EOF'
label storage=FileStorage volume=Daily-Manual-001 pool=Daily slot=0 drive=0
EOF
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Storage Daemon Volume Configuration: What Happens on Disk

Every Volume Bareos creates is a file (for disk-based storage) or a tape position. For our Podman-based setup, volumes are files on the host filesystem at `/srv/bareos-storage/volumes/`, which is bind-mounted into the Storage Daemon container.

### Directory Structure on Disk

```
/srv/bareos-storage/
└── volumes/
    ├── Daily-2025-07-04-0001     ← one volume file per job
    ├── Daily-2025-07-05-0001
    ├── Weekly-2025-W27-0001
    ├── Monthly-2025-07-0001
    └── Yearly-2025-0001
```

Each volume file is a raw binary stream of backup data in Bareos block format. It is not a tar archive or zip file — it can only be read by the Bareos Storage Daemon.

### SELinux Context for Storage Directory

The storage directory requires the custom SELinux type `bareos_store_t`. This must be configured before the Storage Daemon can write to it:

```bash
# Install the SELinux policy tools
sudo dnf install -y policycoreutils-python-utils

# Set the persistent SELinux file context for the storage directory
sudo semanage fcontext -a -t bareos_store_t "/srv/bareos-storage/volumes(/.*)?"

# Apply the context immediately (relabels existing files)
sudo restorecon -RFv /srv/bareos-storage/volumes/

# Verify
ls -laZ /srv/bareos-storage/volumes/ | head -5
# Expected: system_u:object_r:bareos_store_t:s0
```

### Storage Daemon Device Resource

The Storage Daemon's configuration defines the **Device** resource, which maps a Pool's storage to a physical directory:

```hcl
# Inside bareos-sd container: /etc/bareos/bareos-sd.d/device/FileStorage.conf

Device {
  Name                      = "FileStorage"
  # This name must match the Device Name in the Director's Storage resource.

  Media Type                = File
  # "File" means disk-based. Other options: "Tape", "FIFO".

  Archive Device            = /var/lib/bareos/storage
  # Path inside the container. The host path /srv/bareos-storage/volumes
  # is bind-mounted here in the Quadlet .container file.

  Label Media               = yes
  # Allow Bareos to automatically label new volumes. Required for LabelFormat.

  Random Access             = yes
  # File-based storage supports random access (as opposed to tape which is sequential).

  AutomaticMount            = yes
  # Automatically mount (open) the volume when needed.

  RemovableMedia            = no
  # This is fixed disk storage, not removable media.

  AlwaysOpen                = no
  # Don't hold the file open between jobs. Allows other processes to access
  # the directory. Set to yes for tape to keep the drive ready.

  Maximum Concurrent Jobs   = 5
  # Allow up to 5 simultaneous write streams on this device.
  # For disk, you can set this higher than for tape.

  Maximum Volume Size       = 500 GB
  # Hard cap per volume file. Belt-and-suspenders alongside Pool's MaxVolumeBytes.

  Maximum File Size         = 50 GB
  # Maximum size of each "file" within a volume (Bareos volumes can contain
  # multiple files separated by end-of-file marks). This controls file-within-
  # volume chunking, not the overall volume size.
}
```

### Director's Storage Resource (Connects Director to Storage Daemon)

```hcl
# /etc/bareos/bareos-dir.d/storage/FileStorage.conf

Storage {
  Name            = "FileStorage"
  # Name used by Pool, Job, and Schedule resources to reference this storage.

  Address         = bareos-sd
  # Hostname or IP of the Storage Daemon. In our Podman network, containers
  # communicate by service name. "bareos-sd" is the container's network alias.

  Port            = 9103
  # Default Bareos Storage Daemon port.

  Password        = "{{ sd_password }}"
  # Must match the password in bareos-sd.d/director/bareos-dir.conf

  Device          = "FileStorage"
  # Must match the Device Name in the Storage Daemon's device config.

  Media Type      = File
  # Must match the Media Type in the Device resource.

  Maximum Concurrent Jobs = 10
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Pruning: Jobs, Volumes, Files

Pruning removes catalog records that have exceeded their retention period. It does NOT delete data from volumes — the actual backup data is only lost when a volume is recycled and overwritten. This distinction is crucial: you can recover from accidental pruning if the volume still exists and has not been recycled.

### The Three Pruning Levels

**Prune Files** removes individual file records from the `File` table in the catalog:

```
*prune files client=myserver-fd
```

The File table grows rapidly in large backups because it stores one row per backed-up file (path, checksums, attributes, permissions). For a server backing up 500,000 files daily, that's 15 million rows per month. Pruning file records is the most impactful operation for catalog performance.

After file records are pruned, you can still restore entire jobs (because the job record pointing to the volume and offset is intact), but you cannot browse individual files in bconsole or WebUI.

**Prune Jobs** removes job summary records from the `Job` table:

```
*prune jobs client=myserver-fd
```

Once a job record is pruned, Bareos no longer knows that job ran. The volume that job was written to may not be recyclable yet (Volume Retention may not have expired), but the catalog has no reference to it. This is why `Volume Retention` must always be >= `Job Retention` — if you prune job records before Volume Retention expires, you can end up with volumes that are never recycled (their job records are gone but the volume hasn't aged out).

**Prune Volumes** removes volume records from the `Media` table when all jobs on that volume have already been pruned:

```
*prune volumes pool=Daily
```

This is typically the last step before recycling. After a volume's job records are all gone, running `prune volumes` marks it as `Purged`. The next time a new volume is needed, Bareos will recycle it.

### Automatic Pruning

Set `Auto Prune = yes` on both the **Client** resource and the **Pool** resource:

```hcl
# /etc/bareos/bareos-dir.d/client/myserver-fd.conf
Client {
  Name           = "myserver-fd"
  Address        = "bareos-fd"
  Port           = 9102
  Password       = "{{ fd_password }}"

  File Retention = 30 days
  # How long individual file records are kept in the catalog.

  Job Retention  = 180 days
  # How long job records are kept.

  Auto Prune     = yes
  # Automatically prune when needed (triggered when catalog is queried
  # for the next backup level determination, or when a volume is needed).
}
```

### Viewing What Would Be Pruned

Before running prune, you can preview with:

```
*list jobs client=myserver-fd
*list files jobid=<n>
```

To see the retention status of all volumes:

```
*list volumes
*list volumes pool=Daily
```

Look for `VolStatus = Full` (still retained), `VolStatus = Used` (still retained but closed), or `VolStatus = Purged` (all jobs pruned, ready for recycling).

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Recycling: How Bareos Reclaims Volumes

Recycling is the process of taking a **Purged** volume (one whose catalog records have all been pruned) and preparing it for reuse by a new job. The old data on the volume is not immediately erased; it is simply overwritten as new backup data is written.

### Recycling Conditions

A volume can be recycled when ALL of the following are true:

1. `VolStatus = Purged` (all jobs on it have been pruned from catalog)
2. `Volume Retention` time has elapsed since the volume was last written
3. `Recycle = yes` is set on the Pool
4. The pool needs a new volume (MaxVolumes has been reached or no empty volumes are available)

### The Recycle Algorithm

When a new volume is needed:
1. Look for a volume in the pool with `VolStatus = Recycle` (already flagged for reuse).
2. Look for `VolStatus = Purged` volumes that have passed `Volume Retention`.
3. If found, reset the volume record in the catalog (zero the byte count, reset the job count, set status to `Recycle`).
4. Begin writing the new job to this volume from byte 0.

### Recycling Across Pools with Recycle Pool

```hcl
Pool {
  Name         = "Daily"
  Recycle Pool = "Scratch"
  # When a Daily volume is purged, it moves to Scratch.
  # A human or automated process can then move it back to Daily
  # or another pool as needed.
  ...
}

Pool {
  Name      = "Scratch"
  Pool Type = Scratch
  # Scratch pools are globally accessible — any pool can draw
  # from the Scratch pool when it runs out of volumes.
  # Bareos will automatically take unlabeled (or Scratch) volumes
  # when a pool has MaxVolumes reached and no Purged volumes.
}
```

### Forcing Recycling Manually

```bash
# In bconsole: purge a volume manually (USE WITH CAUTION — deletes catalog records)
*purge volume=Daily-2025-01-01-0001

# Mark a purged volume for recycling immediately
*update volume=Daily-2025-01-01-0001 volstatus=Recycle
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. The Catalog's Role in Retention

The Bareos catalog is a relational database (MariaDB in our setup) that stores the complete metadata for every backup. Understanding its structure helps you design retention policies correctly.

### Key Catalog Tables

| Table | Contents | Affected by |
|---|---|---|
| `Job` | One row per job: start/end time, status, bytes, level | Prune Jobs |
| `File` | One row per backed-up file per job | Prune Files |
| `Media` | One row per volume: status, bytes, retention | Prune Volumes |
| `Client` | One row per client machine | Admin only |
| `FileSet` | One row per FileSet definition | Admin only |
| `Pool` | One row per pool | Admin only |

### Retention Period Interaction

The three retention periods on the Client resource interact as follows:

```
File Retention  ≤  Job Retention  ≤  Volume Retention

Recommended:
  File Retention  = 30 days   (catalog stays manageable)
  Job Retention   = 180 days  (6 months of job history for auditing)
  Volume Retention = 400 days (slightly longer than longest pool retention)
```

If `File Retention > Job Retention`, Bareos will prune the job records while file records still exist, which is an inconsistent state. Always keep `File Retention <= Job Retention`.

If `Job Retention > Volume Retention`, job records reference volumes that may have been recycled. Bareos handles this gracefully (it marks jobs on recycled volumes as unable to be restored), but it means your job history in bconsole will show jobs you can no longer restore.

### Querying the Catalog Directly

For debugging or custom reporting, you can query MariaDB directly from the container:

```bash
# As bareos user
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-db \
  mariadb -u bareos -p"$(cat /home/bareos/.config/bareos/db.env | grep DB_PASSWORD | cut -d= -f2)" \
  bareos -e "
SELECT j.Name, j.Level, j.StartTime, j.EndTime, j.JobStatus,
       j.JobFiles, j.JobBytes
FROM Job j
ORDER BY j.StartTime DESC
LIMIT 20;
"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Copy Jobs and Migration Jobs

Bareos supports two special job types for duplicating backup data to a second location:

- **Copy Job** — copies data from one pool to another, keeping the original. Both copies exist simultaneously. The original job can still be used for restore.
- **Migration Job** — moves data from one pool to another, removing it from the original pool. After migration, only the destination copy can be used for restore.

These are used for:
- **Off-site replication** — copying backups to a second storage daemon at a remote location
- **Tiered storage** — migrating old backups from fast disk to slow/cheap disk or tape
- **Deduplication** — migrating to a deduplicated storage backend

### Copy Job Configuration

```hcl
# /etc/bareos/bareos-dir.d/job/copy-to-offsite.conf

Job {
  Name            = "Copy-Critical-to-Offsite"
  Type            = Copy
  # Type=Copy means the source jobs are NOT deleted from the catalog.
  # Type=Migration would delete them.

  Level           = Full
  # For Copy/Migration jobs, Level specifies which source jobs to select.
  # Level=Full copies only Full backup jobs.
  # Level=Incremental would copy incrementals.

  Client          = myserver-fd
  # The client whose backups should be copied.

  FileSet         = "LinuxAll"

  Schedule        = "WeeklyCopySchedule"

  Storage         = FileStorage-Offsite
  # Destination storage daemon (different from source).

  Pool            = Daily
  # SOURCE pool — where jobs are read from.

  Next Pool       = Offsite-Daily
  # DESTINATION pool — where the copy is written.
  # This is what distinguishes copy/migration from regular backup.

  Messages        = Standard
  Priority        = 13
  # Lower priority than regular backups — copy jobs run after backups complete.

  Selection Type  = PoolUncopied
  # Selects jobs from the source pool that have NOT been copied yet.
  # Other options:
  #   PoolOccupied: all jobs in pool
  #   SmallestVolume: prioritize filling up small volumes
  #   OldestVolume: copy oldest jobs first
  #   Client: copy all jobs for a specific client
  #   Volume: copy all jobs on a specific volume
}

# The destination pool
Pool {
  Name                = "Offsite-Daily"
  Pool Type           = Backup
  Label Format        = "Offsite-Daily-${Year}-${Month:p/2/0/r}-${Day:p/2/0/r}-"
  Maximum Volumes     = 30
  Volume Retention    = 30 days
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage-Offsite
}
```

### Migration Job Configuration

```hcl
Job {
  Name            = "Migrate-Daily-to-Archive"
  Type            = Migration
  # After successful migration, source job is marked as "migrated"
  # and the source volume may be purged/recycled.

  Client          = myserver-fd
  FileSet         = "LinuxAll"
  Pool            = Daily          # source
  Next Pool       = Archive        # destination
  Storage         = FileStorage-Archive
  Messages        = Standard
  Priority        = 15

  Selection Type  = Volume
  # Migrate all jobs from selected volumes.

  Selection Pattern = "Daily-2025-.*"
  # Regex pattern to select source volumes by name.
  # Only Daily volumes from 2025 will be migrated.
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Virtual Full Backup

A **Virtual Full** is a Bareos feature that creates a new Full backup *in the catalog* by combining an existing Full with all subsequent Incrementals, without sending any data over the network from the client.

The result is a synthetic Full stored on a new volume that can be used as the base for future Incrementals. This allows you to:
- Reduce the gap between Full backups without the network overhead
- Create a single self-contained Full from many incremental pieces
- Consolidate storage: once the Virtual Full is created, you can safely prune the constituent Incrementals

> **Storage caveat:** A Virtual Full **does not reduce physical storage** — it writes a new, complete set of file data to a new volume. The storage used is approximately equal to the combined size of the original Full plus all Incrementals that were merged. Physical storage savings only occur *after* you prune the original Full and its Incrementals. Until those volumes are pruned and recycled, total storage usage will temporarily increase. Plan for at least 2× the size of a typical Full backup as headroom when running Virtual Full jobs.

### How Virtual Full Works Internally

1. Bareos reads the existing Full volume from the Storage Daemon.
2. It reads all Incremental volumes that were created after that Full.
3. It merges them (applying the delta logic: each Incremental overrides the same-path file from earlier backups).
4. It writes the merged result as a new "Full" backup to a target volume.
5. The catalog is updated to reflect the new Virtual Full job and its constituent files.

No network traffic goes to the client. The entire operation happens between the Director and the Storage Daemon.

### Virtual Full Job Configuration

```hcl
# /etc/bareos/bareos-dir.d/job/virtualfull.conf

Job {
  Name            = "VirtualFull-Linux"
  Type            = Backup
  Level           = VirtualFull
  # Forces a virtual full synthesis.

  Client          = myserver-fd
  FileSet         = "LinuxAll"
  Schedule        = "WeeklyVirtualFull"
  Storage         = FileStorage
  Pool            = Weekly
  # The Virtual Full is written to the Weekly pool.
  # It will be used as the new Full baseline for future Incrementals.

  Messages        = Standard
  Priority        = 11
  Accurate        = yes
  # Accurate mode is recommended for Virtual Full to ensure the
  # synthesized backup correctly represents the current file state.
}

Schedule {
  Name = "WeeklyVirtualFull"
  Run = Level=VirtualFull Pool=Weekly Sat at 22:00
}
```

### Running a Virtual Full Manually in bconsole

```
*run job=VirtualFull-Linux level=VirtualFull
Run Backup job
JobName:  VirtualFull-Linux
Level:    VirtualFull
Client:   myserver-fd
...
OK to run? (yes/mod/no): yes
Job queued. JobId=47
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Advanced FileSet Include/Exclude Patterns

The **FileSet** resource defines what to back up and how. Advanced FileSet options give you fine-grained control over compression, exclusions, checksumming, and attribute handling.

### Complete Annotated FileSet

```hcl
# /etc/bareos/bareos-dir.d/fileset/linux-all-advanced.conf

FileSet {
  Name = "LinuxAll-Advanced"

  Include {
    # ── Options apply to all files in this Include block ─────────

    Options {
      Signature       = SHA1
      # Compute SHA1 checksum for every file and store in catalog.
      # Enables verify jobs and integrity checking. Slight CPU overhead.
      # Alternative: MD5 (faster), SHA256 (stronger but slower).

      Compression     = GZIP
      # Compress data before sending to storage daemon.
      # Reduces bandwidth and storage. GZIP is balanced.
      # Alternatives: GZIP1-9 (level), LZO (faster, less compression),
      #               LZFAST, LZ4 (very fast), ZSTD (modern, excellent ratio).

      No Atime        = yes
      # Do not update file access times when reading files.
      # Prevents access-time changes from triggering incremental backups.
      # Requires the filesystem to support O_NOATIME.

      Portable        = yes
      # Store only POSIX attributes (owner, group, mode, timestamps).
      # Makes backups portable across different systems.
      # Set to no to include extended ACLs and extended attributes.

      Exclude         = no
      # This Options block includes matching files (default).
      # Set to yes to turn this into an exclusion rule.
    }

    # Additional Options block for specific file types
    Options {
      Compression     = no
      # Don't compress already-compressed files — wastes CPU.
      WildFile        = "*.gz"
      WildFile        = "*.bz2"
      WildFile        = "*.xz"
      WildFile        = "*.zip"
      WildFile        = "*.jpg"
      WildFile        = "*.jpeg"
      WildFile        = "*.mp4"
      WildFile        = "*.mkv"
    }

    # ── File/Directory Specifications ─────────────────────────────

    File = /etc
    # Back up the entire /etc directory and all subdirectories.

    File = /home
    # All home directories.

    File = /var/log
    # System logs.

    File = /var/lib/bareos
    # Bareos state files (catalog bootstrap, etc.).

    File = /root
    # Root's home directory.

    File = /usr/local
    # Locally installed software.

    # ── Wildcard and Regex Patterns in Include ────────────────────
    # Note: Wildcards in File specifications match differently than
    # in WildFile Options. Here we're specifying top-level paths.
  }

  Exclude {
    # Paths to exclude from backup entirely.
    # These are matched against the full absolute path.

    File = /proc
    # Kernel process filesystem — not real files.

    File = /sys
    # Kernel sysfs — not real files.

    File = /dev
    # Device files — not real files.

    File = /run
    # Runtime files (PIDs, sockets) — volatile and not useful to back up.

    File = /tmp
    # Temporary files — no value in backing up.

    File = /var/tmp
    File = /var/cache

    File = /var/lib/bareos/storage
    # Don't back up the backup storage directory — this would be circular.

    File = /mnt
    File = /media
    # Mount points for external/removable media.

    File = /lost+found

    # Excludes using wildcards (Options blocks inside Exclude)
    Options {
      Exclude         = yes
      WildDir         = /home/*/.cache
      # Exclude all .cache directories inside any home directory.
      WildDir         = /home/*/.local/share/Trash
      # Exclude trash directories.
      WildFile        = /home/*/.bash_history
      # Exclude shell history files (changes every login, low value).
      RegexFile       = ".*\.pyc$"
      # Exclude compiled Python bytecode files (regenerated automatically).
      RegexFile       = ".*node_modules.*"
      # Exclude Node.js module directories (large and reproducible).
    }
  }
}
```

### Options Directive Reference

| Directive | Values | Purpose |
|---|---|---|
| `Signature` | MD5, SHA1, SHA256, SHA512 | File checksum algorithm |
| `Compression` | GZIP, GZIP1-9, LZO, LZ4, ZSTD, no | Compression algorithm |
| `No Atime` | yes/no | Preserve file access times |
| `Portable` | yes/no | POSIX-only vs full attributes |
| `OneFS` | yes/no | Stay on one filesystem (don't cross mount points) |
| `Sparse` | yes/no | Handle sparse files efficiently |
| `ReadFifo` | yes/no | Back up FIFO pipe contents |
| `HardLinks` | yes/no | Preserve hard link structure |
| `WildFile` | glob pattern | Match files by pattern |
| `WildDir` | glob pattern | Match directories by pattern |
| `Regex` | regex | Match paths by regex |
| `RegexFile` | regex | Match file names by regex |
| `RegexDir` | regex | Match directory names by regex |
| `Exclude` | yes/no | This block is an exclusion rule |

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Multiple Storage Daemon Setup

In larger environments, you may want different jobs to write to different Storage Daemons — for example, a fast local NVMe for daily incrementals and a slow NAS for monthly fulls.

### Multiple Storage Configuration

```hcl
# /etc/bareos/bareos-dir.d/storage/fast-storage.conf

Storage {
  Name            = "FastStorage"
  Address         = bareos-sd-fast
  Port            = 9103
  Password        = "{{ fast_sd_password }}"
  Device          = "FastDevice"
  Media Type      = File
  Maximum Concurrent Jobs = 20
}

# /etc/bareos/bareos-dir.d/storage/archive-storage.conf

Storage {
  Name            = "ArchiveStorage"
  Address         = bareos-sd-archive
  Port            = 9103
  Password        = "{{ archive_sd_password }}"
  Device          = "ArchiveDevice"
  Media Type      = File
  Maximum Concurrent Jobs = 5
}
```

### Routing Jobs to Different Storages

Assign different Storages to different Pools, and use Schedule Run overrides:

```hcl
# Daily pool → FastStorage
Pool {
  Name    = "Daily"
  Storage = "FastStorage"
  ...
}

# Monthly pool → ArchiveStorage
Pool {
  Name    = "Monthly"
  Storage = "ArchiveStorage"
  ...
}

# Or override per-run in the Schedule:
Schedule {
  Name = "Multi-Storage-Schedule"
  Run = Level=Incremental Pool=Daily    Storage=FastStorage   Mon-Sat at 23:00
  Run = Level=Full        Pool=Monthly  Storage=ArchiveStorage First Sun at 01:00
}
```

### Quadlet for Second Storage Daemon

```ini
# /home/bareos/.config/containers/systemd/bareos-sd-archive.container

[Unit]
Description=Bareos Storage Daemon (Archive)
After=network-online.target bareos-sd-archive-volume.service

[Container]
Image=docker.io/bareos/bareos-storage:24
ContainerName=bareos-sd-archive
Network=bareos.network

# Archive storage on a slow/large disk
Volume=/srv/bareos-archive/volumes:/var/lib/bareos/storage:Z

# Configuration from named volume
Volume=bareos-sd-archive-config:/etc/bareos:Z

EnvironmentFile=/home/bareos/.config/bareos/bareos.env

PublishPort=127.0.0.1:9104:9103
# Note: different host port to avoid conflict with primary SD

[Service]
Restart=always
RestartSec=10
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Lab 16-1: Build a Complete GFS Schedule with Four Pools

This lab walks through building the complete GFS configuration from scratch inside your Bareos Director container.

### Prerequisites

- Bareos Director container running (from Chapter 14/15 setup)
- At least 100 GB free disk space at `/srv/bareos-storage/`
- `bareos` user with UID 1001 and lingering enabled

### Step 1: Create the Storage Directory Structure

```bash
# As root: create pool-specific subdirectories
sudo mkdir -p /srv/bareos-storage/volumes/{daily,weekly,monthly,yearly}
sudo chown -R bareos:bareos /srv/bareos-storage/
sudo chmod -R 750 /srv/bareos-storage/

# Set SELinux context
sudo semanage fcontext -a -t bareos_store_t \
  "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -RFv /srv/bareos-storage/volumes/

# Verify
ls -laZ /srv/bareos-storage/volumes/
```

### Step 2: Write the Pool Configuration

```bash
# Enter the Director config volume (accessible as bareos user)
BAREOS_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-director-config/_data"

# Write the GFS pools config
cat > "${BAREOS_CONFIG}/bareos-dir.d/pool/gfs-pools.conf" << 'POOLCONF'
Pool {
  Name                = "Daily"
  Pool Type           = Backup
  Label Format        = "Daily-${Year}-${Month:p/2/0/r}-${Day:p/2/0/r}-"
  Maximum Volumes     = 21
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 30 GB
  Volume Use Duration = 23 hours
  Volume Retention    = 8 days
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}
Pool {
  Name                = "Weekly"
  Pool Type           = Backup
  Label Format        = "Weekly-${Year}-W${Week:p/2/0/r}-"
  Maximum Volumes     = 10
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 100 GB
  Volume Use Duration = 7 days
  Volume Retention    = 35 days
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}
Pool {
  Name                = "Monthly"
  Pool Type           = Backup
  Label Format        = "Monthly-${Year}-${Month:p/2/0/r}-"
  Maximum Volumes     = 15
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 500 GB
  Volume Use Duration = 32 days
  Volume Retention    = 400 days
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}
Pool {
  Name                = "Yearly"
  Pool Type           = Backup
  Label Format        = "Yearly-${Year}-"
  Maximum Volumes     = 10
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 2 TB
  Volume Use Duration = 400 days
  Volume Retention    = 3650 days
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
}
Pool {
  Name      = "Scratch"
  Pool Type = Scratch
}
POOLCONF
```

### Step 3: Write the Schedule Configuration

```bash
cat > "${BAREOS_CONFIG}/bareos-dir.d/schedule/gfs-schedule.conf" << 'SCHEDCONF'
Schedule {
  Name = "GFS-Daily"
  Run = Level=Incremental Pool=Daily Mon-Sat at 23:00
}
Schedule {
  Name = "GFS-Weekly"
  Run = Level=Differential Pool=Weekly Second Sun at 23:00
  Run = Level=Differential Pool=Weekly Third  Sun at 23:00
  Run = Level=Differential Pool=Weekly Fourth Sun at 23:00
  Run = Level=Differential Pool=Weekly Fifth  Sun at 23:00
}
Schedule {
  Name = "GFS-Monthly"
  Run = Level=Full Pool=Monthly First Sun at 01:00
}
Schedule {
  Name = "GFS-Yearly"
  Run = Level=Full Pool=Yearly Dec Last Sun at 01:00
}
SCHEDCONF
```

### Step 4: Write the Job Configurations

```bash
cat > "${BAREOS_CONFIG}/bareos-dir.d/job/backup-gfs.conf" << 'JOBCONF'
Job {
  Name            = "Backup-Linux-Daily"
  Type            = Backup
  Level           = Incremental
  Client          = myserver-fd
  FileSet         = "LinuxAll-Advanced"
  Schedule        = "GFS-Daily"
  Storage         = FileStorage
  Pool            = Daily
  Messages        = Standard
  Priority        = 10
  Write Bootstrap = "/var/lib/bareos/myserver-daily.bsr"
}
Job {
  Name            = "Backup-Linux-Weekly"
  Type            = Backup
  Level           = Differential
  Client          = myserver-fd
  FileSet         = "LinuxAll-Advanced"
  Schedule        = "GFS-Weekly"
  Storage         = FileStorage
  Pool            = Weekly
  Messages        = Standard
  Priority        = 10
  Write Bootstrap = "/var/lib/bareos/myserver-weekly.bsr"
}
Job {
  Name            = "Backup-Linux-Monthly"
  Type            = Backup
  Level           = Full
  Client          = myserver-fd
  FileSet         = "LinuxAll-Advanced"
  Schedule        = "GFS-Monthly"
  Storage         = FileStorage
  Pool            = Monthly
  Messages        = Standard
  Priority        = 9
  Write Bootstrap = "/var/lib/bareos/myserver-monthly.bsr"
}
Job {
  Name            = "Backup-Linux-Yearly"
  Type            = Backup
  Level           = Full
  Client          = myserver-fd
  FileSet         = "LinuxAll-Advanced"
  Schedule        = "GFS-Yearly"
  Storage         = FileStorage
  Pool            = Yearly
  Messages        = Standard
  Priority        = 8
  Write Bootstrap = "/var/lib/bareos/myserver-yearly.bsr"
}
JOBCONF
```

### Step 5: Reload Bareos Director

```bash
# Reload configuration without restarting (no downtime)
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<'EOF'
reload
quit
EOF
```

Expected output: `3000 OK reload`

### Step 6: Verify Configuration in bconsole

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole
```

```
*show pools
*show schedules
*show jobs
*list volumes
```

You should see all four pools and four jobs listed. Volumes list will be empty until the first job runs.

### Step 7: Trigger a Manual Full to Seed the GFS Chain

```
*run job=Backup-Linux-Monthly level=Full yes
Job queued. JobId=1

*wait jobid=1
JobId=1  Job="Backup-Linux-Monthly.2025-07-04_01.00" ...

*list jobid=1
```

After this Full completes, Incrementals and Differentials will be able to reference it correctly.

---

[↑ Back to Table of Contents](#table-of-contents)

## 17. Lab 16-2: Force a Virtual Full and Verify in bconsole

This lab demonstrates creating a Virtual Full from an existing Full + Incrementals.

### Prerequisites

- At least one successful Full backup in the Daily or Weekly pool
- At least two successful Incremental backups after that Full

### Step 1: Verify the Backup Chain Exists

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole
```

```
*list jobs client=myserver-fd
+-------+------------------------+-----+-------+-----------+----------+-------+
| JobId | Name                   | Lev | Files | Bytes     | Status   | Finis |
+-------+------------------------+-----+-------+-----------+----------+-------+
|     1 | Backup-Linux-Monthly   | F   | 98234 | 4.23 GB   | OK       | ...   |
|     2 | Backup-Linux-Daily     | I   |   234 | 12.5 MB   | OK       | ...   |
|     3 | Backup-Linux-Daily     | I   |   189 | 8.3 MB    | OK       | ...   |
+-------+------------------------+-----+-------+-----------+----------+-------+
```

### Step 2: Add the Virtual Full Job

```bash
BAREOS_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-director-config/_data"

cat >> "${BAREOS_CONFIG}/bareos-dir.d/job/backup-gfs.conf" << 'VFJOB'

Job {
  Name            = "VirtualFull-Linux"
  Type            = Backup
  Level           = VirtualFull
  Client          = myserver-fd
  FileSet         = "LinuxAll-Advanced"
  Storage         = FileStorage
  Pool            = Weekly
  Messages        = Standard
  Priority        = 11
  Accurate        = yes
  Write Bootstrap = "/var/lib/bareos/myserver-vf.bsr"
}
VFJOB

# Reload the Director
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<< "reload"
```

### Step 3: Run the Virtual Full

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole
```

```
*run job=VirtualFull-Linux level=VirtualFull yes
Job queued. JobId=4

*wait jobid=4

*list jobid=4
```

Watch the job log. You will NOT see a "Connecting to Client" message — this confirms no network traffic to the client occurred. Instead you'll see messages like:

```
Start Backup JobId 4, Job=VirtualFull-Linux...
Using Device "FileStorage" to write.
Reading to pool "Weekly" and writing to pool "Weekly"
```

### Step 4: Verify in bconsole

```
# List all jobs — VirtualFull shows as Level=V
*list jobs client=myserver-fd
+-------+------------------------+-----+-------+-----------+
| JobId | Name                   | Lev | Files | Bytes     |
+-------+------------------------+-----+-------+-----------+
|     1 | Backup-Linux-Monthly   | F   | 98234 | 4.23 GB   |
|     2 | Backup-Linux-Daily     | I   |   234 | 12.5 MB   |
|     3 | Backup-Linux-Daily     | I   |   189 | 8.3 MB    |
|     4 | VirtualFull-Linux      | V   | 98657 | 4.25 GB   |
+-------+------------------------+-----+-------+-----------+

# Verify the Virtual Full is now the base for new Incrementals
*run job=Backup-Linux-Daily level=Incremental yes
```

The next Incremental will compare against JobId=4 (the Virtual Full), not the original Full.

---

[↑ Back to Table of Contents](#table-of-contents)

## 18. Lab 16-3: Configure a Copy Job to Duplicate Critical Backups

This lab sets up a Copy Job that duplicates the Weekly pool to a second pool called `Offsite-Weekly`, simulating an off-site copy.

### Step 1: Add the Offsite Pool

```bash
BAREOS_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-director-config/_data"

cat >> "${BAREOS_CONFIG}/bareos-dir.d/pool/gfs-pools.conf" << 'OFFSITEPOOL'

Pool {
  Name                = "Offsite-Weekly"
  Pool Type           = Backup
  Label Format        = "Offsite-W-${Year}-${Week:p/2/0/r}-"
  Maximum Volumes     = 20
  Maximum Volume Jobs = 1
  Maximum Volume Bytes = 200 GB
  Volume Retention    = 90 days
  Auto Prune          = yes
  Recycle             = yes
  Storage             = FileStorage
  # In a real scenario, this would point to a second Storage Daemon.
  # For this lab we use the same storage to demonstrate the mechanics.
}
OFFSITEPOOL
```

### Step 2: Add the Copy Job

```bash
cat >> "${BAREOS_CONFIG}/bareos-dir.d/job/backup-gfs.conf" << 'COPYJOB'

Job {
  Name            = "Copy-Weekly-to-Offsite"
  Type            = Copy
  Level           = Full
  Client          = myserver-fd
  FileSet         = "LinuxAll-Advanced"
  Schedule        = "GFS-Copy"
  Storage         = FileStorage
  Pool            = Weekly
  Next Pool       = Offsite-Weekly
  Messages        = Standard
  Priority        = 15
  Selection Type  = PoolUncopied
}
COPYJOB

cat >> "${BAREOS_CONFIG}/bareos-dir.d/schedule/gfs-schedule.conf" << 'COPYSCHED'

Schedule {
  Name = "GFS-Copy"
  # Run the copy job every Monday morning after weekend differentials complete
  Run = Level=Full Mon at 04:00
}
COPYSCHED
```

### Step 3: Reload and Run the Copy Job

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<< "reload"

XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole
```

```
*run job=Copy-Weekly-to-Offsite yes
Job queued. JobId=5

*wait jobid=5
*list jobid=5

# Verify the copy was written to the Offsite pool
*list volumes pool=Offsite-Weekly
```

### Step 4: Verify Both Copies Exist

```
*list jobs
```

You should see both the original Differential job (e.g., JobId=3) and the Copy job (JobId=5). The copied job will have a `Type=C` indicator and will reference the `Offsite-Weekly` volume.

To confirm you can restore from the copy:

```
*restore jobid=5
```

Bareos will find the data on the `Offsite-Weekly` volume.

---

[↑ Back to Table of Contents](#table-of-contents)

## 19. Summary

This chapter covered the complete lifecycle of backups in Bareos, from the moment data is written to a volume through pruning and recycling. The key takeaways are:

**Retention is a three-layer system**: File Retention, Job Retention, and Volume Retention must be configured consistently. Always ensure `File Retention <= Job Retention <= Volume Retention` to avoid catalog inconsistencies.

**Schedules are more than timers**: The Run directive in a Schedule resource can override Pool, Storage, and Level per execution. This makes it possible to implement a complete GFS rotation within a single Schedule resource or spread across multiple Jobs.

**Pools separate concerns**: Different tiers of your GFS rotation should use different Pools. This allows independent retention policies, separate storage devices, and clean volume management per tier.

**LabelFormat is essential for automation**: Without it, Bareos waits for manual volume labeling. Date-stamped labels with padding (`${Year}-${Month:p/2/0/r}`) produce human-readable, lexicographically sortable volume names.

**Virtual Full eliminates full-backup overhead**: By synthesizing a Full from Incrementals on the storage tier (not the network), Virtual Full lets you maintain a fresh full-backup baseline without the client overhead of a true Full backup.

**Copy and Migration Jobs enable off-site and tiered storage**: Copy Jobs duplicate without removing the original; Migration Jobs move and clean up. Both use `Next Pool` to direct the destination.

**SELinux must be considered at every step**: The storage directory at `/srv/bareos-storage/volumes` requires the `bareos_store_t` SELinux type. Always run `semanage fcontext` and `restorecon` before starting the Storage Daemon.

In the next chapter, we will cover monitoring and alerting — making sure you know immediately when a backup fails or when retention thresholds are approaching.

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
