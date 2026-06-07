# Chapter 19: Performance Tuning and Optimization
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. Understanding Bareos Performance Bottlenecks](#1-understanding-bareos-performance-bottlenecks)
  - [Bottleneck 1: Network](#bottleneck-1-network)
  - [Bottleneck 2: Disk I/O](#bottleneck-2-disk-io)
  - [Bottleneck 3: CPU (Compression and Encryption)](#bottleneck-3-cpu-compression-and-encryption)
  - [Bottleneck 4: Catalog (MariaDB)](#bottleneck-4-catalog-mariadb)
- [2. Measuring Current Performance](#2-measuring-current-performance)
  - [Step 1: Get Job Statistics from bconsole](#step-1-get-job-statistics-from-bconsole)
  - [Step 2: Measure Disk I/O During a Backup](#step-2-measure-disk-io-during-a-backup)
  - [Step 3: Measure Network Throughput](#step-3-measure-network-throughput)
  - [Step 4: Record Your Baseline](#step-4-record-your-baseline)
- [3. Parallel Jobs: Maximum Concurrent Jobs](#3-parallel-jobs-maximum-concurrent-jobs)
  - [How the Three Limits Interact](#how-the-three-limits-interact)
  - [Director Configuration](#director-configuration)
  - [Storage Daemon Configuration](#storage-daemon-configuration)
  - [File Daemon (Client) Configuration](#file-daemon-client-configuration)
  - [Per-Job Concurrent Job Limits](#per-job-concurrent-job-limits)
- [4. Simultaneous Jobs: Backing Up Multiple Clients in Parallel](#4-simultaneous-jobs-backing-up-multiple-clients-in-parallel)
  - [Configuring Multiple Clients](#configuring-multiple-clients)
  - [Schedule Multiple Clients to Run at the Same Time](#schedule-multiple-clients-to-run-at-the-same-time)
- [5. Backup Window Planning](#5-backup-window-planning)
  - [Staggering Start Times](#staggering-start-times)
  - [Separating Full and Incremental Schedules](#separating-full-and-incremental-schedules)
  - [Estimating Job Duration](#estimating-job-duration)
- [6. Compression: LZ4 vs GZIP, When It Helps and When It Hurts](#6-compression-lz4-vs-gzip-when-it-helps-and-when-it-hurts)
  - [When Compression Helps](#when-compression-helps)
  - [When Compression Hurts](#when-compression-hurts)
  - [LZ4 vs GZIP](#lz4-vs-gzip)
  - [FileSet Configuration for Compression](#fileset-configuration-for-compression)
  - [Testing Compression Ratios](#testing-compression-ratios)
- [7. FileSet Options: Sparse, ReadFifo, NoAtime, MTU Tuning](#7-fileset-options-sparse-readfifo-noatime-mtu-tuning)
  - [Sparse Files](#sparse-files)
  - [ReadFifo](#readfifo)
  - [NoAtime](#noatime)
  - [Checking Mount Options](#checking-mount-options)
- [8. Storage Daemon Device Performance](#8-storage-daemon-device-performance)
  - [Complete Optimized Device Configuration](#complete-optimized-device-configuration)
  - [Separate Devices for Different Storage Classes](#separate-devices-for-different-storage-classes)
- [9. Spooling: What It Is and When to Use It](#9-spooling-what-it-is-and-when-to-use-it)
  - [The Problem Spooling Solves](#the-problem-spooling-solves)
  - [How Spooling Works](#how-spooling-works)
  - [When NOT to Use Spooling](#when-not-to-use-spooling)
  - [Storage Daemon Spooling Configuration](#storage-daemon-spooling-configuration)
  - [Quadlet Volume Mount for Spool on Fast SSD](#quadlet-volume-mount-for-spool-on-fast-ssd)
  - [Director Job-Level Spooling](#director-job-level-spooling)
  - [Setting Up the Spool Directory](#setting-up-the-spool-directory)
- [10. Rootless Podman and cgroup v2 Resource Constraints](#10-rootless-podman-and-cgroup-v2-resource-constraints)
  - [Verifying cgroup v2 Is Active](#verifying-cgroup-v2-is-active)
  - [Understanding Why Resource Limits Matter](#understanding-why-resource-limits-matter)
  - [Applying Limits via Podman CLI (Temporary, for Testing)](#applying-limits-via-podman-cli-temporary-for-testing)
  - [Applying Limits Persistently in Quadlet Files](#applying-limits-persistently-in-quadlet-files)
- [11. MariaDB Catalog Tuning](#11-mariadb-catalog-tuning)
  - [Creating a Custom MariaDB Configuration File](#creating-a-custom-mariadb-configuration-file)
  - [Mounting the Config File in the Bareos-DB Quadlet](#mounting-the-config-file-in-the-bareos-db-quadlet)
  - [Applying the Configuration](#applying-the-configuration)
- [12. Network: TCP Tuning for Large Backup Transfers](#12-network-tcp-tuning-for-large-backup-transfers)
  - [Checking Current TCP Buffer Sizes](#checking-current-tcp-buffer-sizes)
  - [Applying TCP Tuning for Backup Workloads](#applying-tcp-tuning-for-backup-workloads)
  - [Bareos-Level Network Buffer Size](#bareos-level-network-buffer-size)
  - [Jumbo Frames (9000 MTU)](#jumbo-frames-9000-mtu)
- [13. Volume Auto-labeling and Pre-labeling](#13-volume-auto-labeling-and-pre-labeling)
  - [Auto-labeling Configuration](#auto-labeling-configuration)
  - [Pre-labeling Volumes in Advance](#pre-labeling-volumes-in-advance)
- [14. Storage Device Multiplexing](#14-storage-device-multiplexing)
- [15. Incremental Backup Optimization](#15-incremental-backup-optimization)
  - [Check File Changes Directive](#check-file-changes-directive)
  - [Accurate Mode at the Job Level](#accurate-mode-at-the-job-level)
  - [I/O Priority for the File Daemon](#io-priority-for-the-file-daemon)
- [16. Bareos Director Performance Directives](#16-bareos-director-performance-directives)
  - [Catalog Pruning](#catalog-pruning)
- [17. Container Resource Limits in Quadlet](#17-container-resource-limits-in-quadlet)
- [18. Lab 19-1: Measure Baseline Backup Throughput](#18-lab-19-1-measure-baseline-backup-throughput)
  - [Step 1: Prepare a Benchmark FileSet](#step-1-prepare-a-benchmark-fileset)
  - [Step 2: Create the Benchmark Job](#step-2-create-the-benchmark-job)
  - [Step 3: Run the Baseline Backup](#step-3-run-the-baseline-backup)
  - [Step 4: Extract Throughput Metrics](#step-4-extract-throughput-metrics)
- [19. Lab 19-2: Enable LZ4 Compression and Measure Improvement](#19-lab-19-2-enable-lz4-compression-and-measure-improvement)
  - [Step 1: Update the FileSet to Use LZ4](#step-1-update-the-fileset-to-use-lz4)
  - [Step 2: Reload the Director and Run the Benchmark Again](#step-2-reload-the-director-and-run-the-benchmark-again)
  - [Step 3: Compare Results](#step-3-compare-results)
- [20. Lab 19-3: Configure Spooling and Measure Improvement](#20-lab-19-3-configure-spooling-and-measure-improvement)
  - [Step 1: Create the Spool Directory](#step-1-create-the-spool-directory)
  - [Step 2: Update the Storage Daemon Configuration](#step-2-update-the-storage-daemon-configuration)
  - [Step 3: Update the Quadlet to Mount the Spool Directory](#step-3-update-the-quadlet-to-mount-the-spool-directory)
  - [Step 4: Update the Job to Enable Spooling](#step-4-update-the-job-to-enable-spooling)
  - [Step 5: Restart Services and Run the Benchmark](#step-5-restart-services-and-run-the-benchmark)
  - [Step 6: Compare](#step-6-compare)
- [21. Summary](#21-summary)

## 1. Understanding Bareos Performance Bottlenecks

Performance tuning begins with understanding *where* time goes. In a Bareos backup job, data flows through a pipeline:

```
[Client filesystem]
       |
       v  (read by File Daemon)
[File Daemon]
       |
       v  (network transfer)
[Storage Daemon]
       |
       v  (write to volume file)
[Disk / volume]
       |
       v  (job metadata written by Director)
[Catalog — MariaDB]
```

At every link in this chain, you can have a bottleneck. Tuning the wrong link wastes effort. The four possible bottlenecks are:

### Bottleneck 1: Network

Network bandwidth limits the maximum sustained throughput between the File Daemon and the Storage Daemon. A gigabit LAN gives you a theoretical maximum of ~125 MB/s. After TCP overhead and encryption, real-world throughput is often 60–90 MB/s. If you are backing up over a WAN or VPN, this can drop to 10–50 MB/s or lower.

**Signs you are network-bound**: CPU on both the client and storage host is low. `iotop` shows the storage disk write speed is well below its maximum. `iftop` or `nethogs` shows a network interface saturated.

### Bottleneck 2: Disk I/O

If the disk on the client side cannot deliver data fast enough (read bottleneck) or the disk on the storage side cannot write fast enough (write bottleneck), the network sits idle waiting. A spinning HDD backs up at 80–150 MB/s sequentially; an NVMe SSD can deliver 2,000–7,000 MB/s. If your backup volume is on a slow HDD, that disk is almost certainly your bottleneck when backing up fast SSDs.

**Signs you are disk I/O bound**: CPU is low on all hosts. Network utilization is well below maximum. `iostat -xz 1` shows 100% utilization on a specific device.

### Bottleneck 3: CPU (Compression and Encryption)

If you enable GZIP compression at high levels (level 6+) on a large job, the CPU on the File Daemon becomes the bottleneck. The CPU spends all its time compressing data faster than the disk can deliver it. LZ4 compression is 5–10× faster than GZIP at similar compression ratios on typical mixed data, and it almost never becomes the CPU bottleneck.

**Signs you are CPU-bound**: CPU on the File Daemon host is at or near 100%. Network and disk I/O are both underutilized.

### Bottleneck 4: Catalog (MariaDB)

As your backup history grows, every job completion requires inserting file metadata records into MariaDB. A job that backs up 1,000,000 files inserts 1,000,000 rows into the `File` table. With a misconfigured MariaDB (too little InnoDB buffer pool, no proper indexes), this can take minutes to hours and stalls the next job from starting.

**Signs you are catalog-bound**: The backup completes quickly but the job status stays in `R` (Running) or `f` (finishing) for a long time. `top` on the MariaDB container shows high CPU. `SHOW PROCESSLIST` in MariaDB shows long-running INSERT queries.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Measuring Current Performance

You cannot tune what you have not measured. Before making any changes, establish a baseline.

### Step 1: Get Job Statistics from bconsole

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'

# In bconsole, list recent jobs with their byte counts and durations:
*list jobs

# For detailed stats on a specific job (the job log prints a "Rate:" line
# in KB/s at the end — the simplest per-job throughput figure):
*list joblog jobid=<job_id>

# For aggregate totals across all jobs:
*list jobtotals

# The bconsole "*" prompt does NOT accept bare SQL. To run a raw query,
# use the sqlquery command (interactive) or the dot form:
*sqlquery
SELECT JobId, Name, JobBytes, JobFiles,
  (JobBytes / NULLIF(UNIX_TIMESTAMP(RealEndTime) - UNIX_TIMESTAMP(RealStartTime), 0)) AS bytes_per_sec
FROM Job WHERE JobStatus='T' ORDER BY RealEndTime DESC LIMIT 20;

# Single-line form:
*.sql query="SELECT JobId, Name, JobBytes FROM Job WHERE JobStatus='T' ORDER BY RealEndTime DESC LIMIT 20;"
```

You can also run the same query directly against the catalog from the host
shell (no bconsole), reading the password from `db.env`:

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  source ~/.config/bareos/db.env
  podman exec bareos-db mariadb -u bareos -p"$MARIADB_PASSWORD" bareos -e "
    SELECT JobId, Name, JobBytes, JobFiles,
      (JobBytes / NULLIF(UNIX_TIMESTAMP(RealEndTime) - UNIX_TIMESTAMP(RealStartTime), 0)) AS bytes_per_sec
    FROM Job WHERE JobStatus=\"T\" ORDER BY RealEndTime DESC LIMIT 20;"
'
```

The `JobBytes` column divided by the job duration (in seconds) gives you bytes per second. Convert to MB/s by dividing by 1,048,576. The `Rate:` line in the job log gives the same figure directly in KB/s.

### Step 2: Measure Disk I/O During a Backup

```bash
# Install sysstat for iostat and iotop (both are in the RHEL 10 base repos)
dnf install -y sysstat iotop-ng

# Watch disk I/O every second during a running backup job
# On the host running the Storage Daemon container:
iostat -xz 1

# The key columns in iostat output:
# r/s       - reads per second
# w/s       - writes per second
# rMB/s     - read throughput in MB/s
# wMB/s     - write throughput in MB/s
# %util     - percentage of time the device was busy (100% = saturated)
# await     - average I/O wait time in milliseconds

# Watch which processes are doing the most I/O
sudo iotop -o -d 2

# Watch I/O specifically inside the bareos-storage container
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman stats bareos-storage --no-stream
'
```

### Step 3: Measure Network Throughput

```bash
# iftop, nload, and nethogs are NOT in the RHEL 10 base repos — they live
# in EPEL. Enable EPEL first:
dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm

# Install iftop for real-time bandwidth monitoring
dnf install -y iftop

# Monitor the primary network interface during a backup
sudo iftop -i eth0

# Or use nload for a simpler graph (also from EPEL)
dnf install -y nload
nload eth0

# For a quick point-in-time measurement, use ss:
ss -s
# Look at "TCP: ... estab" — the number of established connections

# Measure the actual TCP transfer rate for a running backup:
# Find the bareos-storage container's PID
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman inspect bareos-storage --format "{{.State.Pid}}"
'
# Use nethogs to see per-process bandwidth (also an EPEL package):
sudo nethogs
```

### Step 4: Record Your Baseline

Create a simple benchmark record before any tuning:

```bash
# Record current performance metrics
cat >> /home/bareos/.config/bareos/performance-log.txt << EOF
Date: $(date)
Test job: BackupLocalHost Full
Job bytes: X GB
Job duration: X minutes
Throughput: X MB/s
Disk util on SD: X%
CPU on FD host: X%
Network saturation: X%
Compression: none/LZ4/GZIP
Spooling: disabled/enabled
Notes: Baseline before tuning
EOF
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Parallel Jobs: Maximum Concurrent Jobs

By default, Bareos runs one job at a time. Every component — the Director, the Storage Daemon, and each File Daemon — has a `Maximum Concurrent Jobs` directive that controls how many jobs it will handle simultaneously. If you want to run five backup jobs in parallel, all three components must allow at least five concurrent connections.

### How the Three Limits Interact

Think of `Maximum Concurrent Jobs` as a set of independent gates. All three gates must be open for a job to flow through:

1. The **Director** gate: if the Director is already running its maximum, it queues the next job.
2. The **Storage Daemon** gate: if the SD is already at its maximum, the job waits for a free storage slot.
3. The **File Daemon** gate: if the client is already backing up (e.g., a VM running another job), the new job waits.

### Director Configuration

```
# /etc/bareos/bareos-dir.conf (inside the director container)
# (the Director config lives in the host directory /etc/bareos/bareos-dir.d,
#  bind-mounted read-only into the container — see Chapter 6)

Director {
  Name = bareos-dir
  DIRport = 9101
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  WorkingDirectory = "/var/lib/bareos"
  PidDirectory = "/var/run/bareos"

  # Maximum Concurrent Jobs controls JOB PARALLELISM: how many backup/restore
  # jobs the Director will run at the same time. This is the directive that
  # actually limits parallel backups.
  # Start conservatively (5–10) and increase once you have verified
  # the system is not resource-constrained at lower levels.
  Maximum Concurrent Jobs = 20

  # Maximum Connections is a DIFFERENT thing: it caps the number of network
  # connections (consoles, bconsole sessions, and daemon-to-daemon control
  # connections) the Director will accept — not the number of jobs. Raise it
  # if you have many simultaneous bconsole/Web UI sessions plus running jobs.
  Maximum Connections = 50

  Password = "DIRECTOR-PASSWORD"
  Messages = Daemon
  Statistics Retention = 12 months
  Auditing = yes
}
```

### Storage Daemon Configuration

```
# /etc/bareos/bareos-sd.conf (inside the storage container)
# (the SD config lives in the host directory /etc/bareos/bareos-sd.d,
#  bind-mounted read-only into the container — see Chapter 6)

Storage {
  Name = bareos-sd
  SDPort = 9103
  WorkingDirectory = "/var/lib/bareos"
  PidDirectory = "/var/run/bareos"

  # The Storage Daemon gate.
  # This controls how many simultaneous streams it will write to storage.
  # Rule of thumb: set this equal to the number of physical disks you are
  # writing to, multiplied by 2 (for read + write headroom).
  Maximum Concurrent Jobs = 20
}

Device {
  Name = FileStorage
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage

  # How many jobs can simultaneously use THIS specific device.
  # For a single-disk setup, 1–4 is typical.
  # For an SSD or RAID volume, 4–8 is reasonable.
  Maximum Concurrent Jobs = 4

  # (See Section 8 for more Device performance directives)
}
```

### File Daemon (Client) Configuration

```
# /etc/bareos/bareos-fd.conf (inside the client container)
# ~/.local/share/containers/storage/volumes/bareos-fd-config/_data/bareos-fd.conf

FileDaemon {
  Name = bareos-fd
  FDport = 9102
  WorkingDirectory = /var/lib/bareos
  PidDirectory = /var/run/bareos

  # The client gate.
  # If this is a dedicated backup client with no other workload,
  # setting this to 4–8 allows multiple jobs to run against it.
  # If the client is a production server, keep it at 1–2 to avoid
  # impacting application performance.
  Maximum Concurrent Jobs = 4
}
```

### Per-Job Concurrent Job Limits

You can also set per-job limits at the Job Definition level. Our lab has a
single client, `bareos-fd`, backed up by the `BackupLocalHost` job; the
`BackupClient1` example below illustrates a multi-client environment with
its own client (`client1-fd`) and is not meant to be run as-is:

```
# /etc/bareos/bareos-dir.d/job/BackupClient1.conf

Job {
  Name = "BackupClient1"
  Type = Backup
  Client = client1-fd
  FileSet = "Full Set"
  Schedule = "WeeklyCycle"
  Storage = File        # the Storage resource defined in Chapter 6
  Messages = Standard
  Pool = Full

  # This job itself should not run more than once at a time.
  # (Prevents a situation where two schedulings of the same job overlap.)
  Maximum Concurrent Jobs = 1
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Simultaneous Jobs: Backing Up Multiple Clients in Parallel

Once you have raised the `Maximum Concurrent Jobs` limits, multiple clients can back up at the same time. This dramatically improves backup window efficiency: instead of backing up 10 clients sequentially (10× the backup window), you back them up in parallel (roughly 1× the backup window, bounded by the slowest client and your storage I/O capacity).

### Configuring Multiple Clients

Each client that backs up in parallel needs its own Client resource and Job resource:

```
# /etc/bareos/bareos-dir.d/client/webserver-fd.conf
Client {
  Name = webserver-fd
  Address = 192.168.1.20
  FDPort = 9102
  Catalog = MyCatalog
  Password = "WEBSERVER-PASSWORD"
  Maximum Concurrent Jobs = 2
  File Retention = 90 days
  Job Retention = 12 months
  AutoPrune = yes
}

# /etc/bareos/bareos-dir.d/client/dbserver-fd.conf
Client {
  Name = dbserver-fd
  Address = 192.168.1.21
  FDPort = 9102
  Catalog = MyCatalog
  Password = "DBSERVER-PASSWORD"
  Maximum Concurrent Jobs = 2
  File Retention = 90 days
  Job Retention = 12 months
  AutoPrune = yes
}
```

### Schedule Multiple Clients to Run at the Same Time

```
# /etc/bareos/bareos-dir.d/schedule/NightlyParallel.conf
#
# This schedule runs all jobs at 02:00 simultaneously.
# Because Maximum Concurrent Jobs is set high enough on the Director
# and Storage Daemon, they will run in parallel.

Schedule {
  Name = "NightlyParallel"
  Run = Full 1st sun at 02:00
  Run = Incremental mon-sat at 02:00
}
```

Assign this schedule to multiple jobs:

```
# /etc/bareos/bareos-dir.d/job/BackupWebserver.conf
Job {
  Name = "BackupWebserver"
  Schedule = "NightlyParallel"
  Client = webserver-fd
  # ... other directives ...
}

# /etc/bareos/bareos-dir.d/job/BackupDBServer.conf
Job {
  Name = "BackupDBServer"
  Schedule = "NightlyParallel"
  Client = dbserver-fd
  # ... other directives ...
}
```

Both jobs start at 02:00 and run concurrently.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Backup Window Planning

The "backup window" is the period of time during which you run backup jobs. It is usually the overnight period when application load is low. Good backup window planning prevents I/O contention between concurrent jobs and ensures all jobs finish before the business day begins.

### Staggering Start Times

If you have 20 clients that all start at 02:00, there is a burst of initial I/O as all 20 File Daemons start scanning their filesystems. Staggering start times by 5–10 minutes distributes the catalog update load:

```
# /etc/bareos/bareos-dir.d/schedule/StaggeredNightly.conf
Schedule {
  Name = "StaggeredNightly"
  # Group A: light clients, start first
  Run = Full 1st sun at 02:00
  Run = Incremental mon-sat at 02:00
}

Schedule {
  Name = "StaggeredNightlyGroupB"
  # Group B: medium clients, start 10 minutes later
  Run = Full 1st sun at 02:10
  Run = Incremental mon-sat at 02:10
}

Schedule {
  Name = "StaggeredNightlyGroupC"
  # Group C: large clients (DBs, file servers), start last
  Run = Full 1st sun at 02:20
  Run = Incremental mon-sat at 02:20
}
```

### Separating Full and Incremental Schedules

Full backups are much larger and slower than incrementals. Running a Full backup on one client while running Incrementals on five others can saturate your storage:

```
# Give Full backups a different time slot to avoid contention
Schedule {
  Name = "WeeklyFull"
  Run = Full sun at 01:00    # Dedicated slot for large Full backups
}

Schedule {
  Name = "DailyIncremental"
  Run = Incremental mon-sat at 02:30  # Incrementals start after Fulls finish
}
```

### Estimating Job Duration

Use historical job data to predict how long jobs will take:

This is a raw catalog query, so run it directly against MariaDB rather than
at the bconsole `*` prompt (which does not accept bare SQL):

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  source ~/.config/bareos/db.env
  podman exec bareos-db mariadb -u bareos -p"$MARIADB_PASSWORD" bareos -e "
    SELECT
      Name,
      AVG(JobBytes / 1048576) AS avg_mb,
      AVG(TIMESTAMPDIFF(SECOND, RealStartTime, RealEndTime)) AS avg_seconds,
      AVG((JobBytes / 1048576) / NULLIF(TIMESTAMPDIFF(SECOND, RealStartTime, RealEndTime), 0)) AS avg_mb_per_sec
    FROM Job
    WHERE JobStatus = \"T\" AND Type = \"B\" AND Level = \"F\"
    GROUP BY Name
    ORDER BY avg_mb DESC;"
'
```

(Inside bconsole you could run the same query with `sqlquery` or
`.sql query="…"`.)

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Compression: LZ4 vs GZIP, When It Helps and When It Hurts

Compression is one of the most impactful tuning knobs in Bareos, but it must be applied thoughtfully. The wrong compression setting can make backups significantly *slower* without reducing storage usage.

### When Compression Helps

Compression helps when your data is highly compressible:
- Plain text files (logs, configuration files, source code): 3–10× compression ratio
- XML and JSON data: 3–8× compression ratio
- Uncompressed databases (SQL dumps): 5–15× compression ratio
- Office documents (.docx, .xlsx, .pptx — these are ZIP files internally): minimal benefit

### When Compression Hurts

Compression hurts when your data is already compressed or is inherently incompressible:
- JPEG, PNG, WebP images: compressor burns CPU, achieves < 1% savings
- MP4, MKV, MP3 media files: same — already compressed
- Compressed archives (.gz, .bz2, .xz, .zip, .7z): re-compressing compressed data makes it *larger*
- Encrypted files: encryption output is indistinguishable from random data — incompressible
- Pre-compressed database formats (some MySQL/MariaDB table formats)

### LZ4 vs GZIP

The throughput figures below are approximate, order-of-magnitude numbers
for typical modern CPUs and mixed data — actual rates vary widely with CPU,
data type, and core count. The relationship (LZ4 is roughly an order of
magnitude faster than GZIP) is what matters, not the exact numbers.

| Property | LZ4 | GZIP (level 6) |
|---|---|---|
| Speed (compression) | ~500 MB/s per core (approx.) | ~50 MB/s per core (approx.) |
| Speed (decompression) | ~2000 MB/s per core (approx.) | ~200 MB/s per core (approx.) |
| Compression ratio (text) | 2–4× | 3–6× |
| CPU cost | Very low | Moderate–High |
| Best for | All workloads as default | Archival, maximum space savings |

**Recommendation**: Use LZ4 as your default. It is almost never the bottleneck and provides meaningful space savings on text data without any noticeable CPU impact. Upgrade to GZIP only for long-term archival volumes where you prioritize space over speed, and only after confirming the CPU is not already the bottleneck.

### FileSet Configuration for Compression

```
# /etc/bareos/bareos-dir.d/fileset/WebServerFiles.conf
#
# Smart compression: use LZ4 for everything, but exclude file types
# that are already compressed.

FileSet {
  Name = "WebServerFiles"

  Include {
    Options {
      Signature = SHA1        # Use SHA1 for integrity (faster than MD5 for large files)
      Compression = LZ4       # LZ4 compression — fast, low CPU, good ratio on text

      # These file types are already compressed. Trying to compress them again
      # wastes CPU and sometimes makes them larger. Use regex to exclude them.
      Wild = "*.jpg"
      Wild = "*.jpeg"
      Wild = "*.png"
      Wild = "*.gif"
      Wild = "*.webp"
      Wild = "*.mp4"
      Wild = "*.mkv"
      Wild = "*.mp3"
      Wild = "*.gz"
      Wild = "*.bz2"
      Wild = "*.xz"
      Wild = "*.zip"
      Wild = "*.7z"
    }

    # For all other file types (text, configs, logs, source code),
    # apply LZ4 compression as defined above.
    File = /var/www/html
    File = /etc
    File = /home
  }

  # Separately include already-compressed files WITHOUT compression
  Include {
    Options {
      Signature = SHA1
      # No Compression directive — these files are backed up as-is
    }
    File = /var/media
    File = /srv/downloads
  }

  Exclude {
    File = /proc
    File = /sys
    File = /dev
    File = /run
    File = /tmp
    File = /var/tmp
  }
}
```

### Testing Compression Ratios

After a backup job completes, you want to know how much space compression
actually saved. Bareos does not store a "compression ratio" column, so any
SQL that derives one from `JobBytes` alone is just multiplying by a constant
— it tells you nothing. The honest method is to compare `JobBytes` (the
amount of data read from the client) against the actual volume file size
growth on disk:

```bash
# Note the JobBytes for the job (from "list jobs" in bconsole)
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
list jobs
EOF
'

# Then check how much the volume files grew on disk
ls -la /srv/bareos-storage/volumes/

# compression_ratio = JobBytes / (volume_bytes_written)
# ratio > 1.0 means compression saved space
# ratio < 1.0 means compression made things worse (rare, but possible)
```

`JobBytes` is the uncompressed size read from the client; the on-disk volume
holds the compressed (and deduplicated, if any) result, so the difference is
the real saving.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. FileSet Options: Sparse, ReadFifo, NoAtime, MTU Tuning

The `Options` block inside a `FileSet` `Include` stanza controls how the File Daemon reads files. Several options have significant performance implications.

### Sparse Files

```
FileSet {
  Name = "VMImages"
  Include {
    Options {
      Signature = SHA1
      # Sparse = yes tells the File Daemon to detect and skip zero-filled
      # regions in files (sparse files).
      # This is CRITICAL for VM disk images, database files, and log files
      # that pre-allocate space. Without this, Bareos reads and transmits
      # gigabytes of zeros.
      # Example: a 100 GB VM disk that is only 10 GB utilized will back up
      # as ~10 GB with Sparse = yes, vs ~100 GB without it.
      Sparse = yes

      Compression = LZ4
    }
    File = /var/lib/libvirt/images
    File = /srv/vm-disks
  }
}
```

### ReadFifo

```
FileSet {
  Name = "DatabaseDump"
  Include {
    Options {
      Signature = SHA1
      # ReadFifo = yes tells the File Daemon to read from named pipes (FIFOs).
      # This is used when you set up a database dump script that writes
      # to a FIFO, allowing Bareos to stream the dump without writing it
      # to disk first.
      # Without ReadFifo, Bareos backs up the FIFO file itself (zero bytes),
      # not the data flowing through it.
      ReadFifo = yes
    }
    File = /tmp/mysql-backup-fifo
  }
}
```

### NoAtime

```
FileSet {
  Name = "FullSet"
  Include {
    Options {
      Signature = SHA1
      Compression = LZ4

      # NoAtime = yes prevents the File Daemon from updating the access time
      # (atime) when it reads a file during backup.
      # Normally, reading a file updates its atime. This causes the filesystem
      # to write metadata for every file read, doubling I/O for no benefit.
      # With NoAtime, reads are truly read-only and do not trigger filesystem
      # writes. This can improve backup throughput by 10–30% on large FileSets
      # with many small files.
      # Note: requires the filesystem to be mounted with the relatime or
      # noatime mount option for this to take effect. Check /proc/mounts.
      NoAtime = yes

      # CheckFileChanges = yes is an alternative change detection method.
      # See Section 15 for details.
      CheckFileChanges = yes
    }
    File = /home
    File = /etc
    File = /var/www
  }
}
```

### Checking Mount Options

```bash
# Verify that your filesystem is mounted with relatime or noatime
grep -E "noatime|relatime" /proc/mounts

# If not set, add it to /etc/fstab for persistence:
# UUID=xxx  /  xfs  defaults,relatime  0 1

# Or set it temporarily:
sudo mount -o remount,relatime /
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Storage Daemon Device Performance

The `Device` resource inside `bareos-sd.conf` controls how the Storage Daemon interacts with the underlying storage. These are the highest-impact tuning parameters.

### Complete Optimized Device Configuration

```
# /etc/bareos/bareos-sd.conf (inside the storage container)
# (the SD config lives in the host directory /etc/bareos/bareos-sd.d,
#  bind-mounted read-only into the container — see Chapter 6)

Device {
  Name = FileStorage
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage    # Maps to /srv/bareos-storage/volumes/ on host

  # === Block Size Tuning ===
  #
  # MaximumBlockSize controls the maximum size of a Bareos block written
  # to the volume file. The default is 64 KB. Increasing this to 1 MB
  # reduces the number of block headers and dramatically improves
  # sequential write throughput on spinning HDDs and network storage.
  # For SSDs and NVMe, the impact is smaller but still positive.
  # The value must be a multiple of 512 bytes.
  #
  # CRITICAL: Block size is baked into the volume format. A volume written
  # with one block size can only be read back by a device configured with a
  # compatible block size. NEVER change Maximum Block Size on a device that
  # already has labelled/written volumes — doing so makes those volumes
  # unreadable (restores fail). Only set this on a fresh device/pool before
  # any volume is written, and keep it consistent for the life of that pool.
  Maximum Block Size = 1048576         # 1 MB block size

  # Leave Minimum Block Size at its default. There is no general benefit to
  # raising it for disk-based File devices, and (like the maximum) changing
  # it breaks compatibility with existing volumes.

  # === Volume Size Limits ===
  #
  # MaximumVolumeSize limits how large a single volume file can grow.
  # Smaller volumes (50–100 GB) are easier to manage, transfer, and
  # restore from. Larger volumes (500 GB+) reduce catalog overhead.
  # For disk-based storage, 50–100 GB per volume is a good balance.
  Maximum Volume Size = 50G

  # === Volume Count Limits ===
  #
  # MaximumVolumes in the Pool (see Pool resource) controls how many
  # volumes exist at once. Combined with VolumeRetention, this limits
  # how much disk space Bareos uses automatically.
  # (Set in Pool resource, not Device — see Section 13.)

  # === Concurrent Jobs on This Device ===
  #
  # How many jobs can simultaneously write to this device.
  # For a single HDD, 1 is optimal (HDDs hate random I/O).
  # For an SSD, 4–8 is reasonable.
  # For a RAID or NVMe device, 4–16.
  Maximum Concurrent Jobs = 4

  # === I/O Mode ===
  #
  # Drives block-level I/O behavior.
  # For file devices, the default is fine. No change needed.

  # === Auto-label ===
  # (Set in Pool resource — see Section 13.)

  # === Spool Data ===
  # (See Section 9 for SpoolData configuration.)

  # Always Open = yes keeps the device descriptor open between jobs.
  # This avoids the overhead of reopening the device for each job.
  # Recommended for disk devices.
  Always Open = yes

  # Collect Device Statistics = yes enables detailed per-device metrics
  # viewable in bconsole with "show devices".
  Collect Device Statistics = yes
  Collect Job Statistics = yes
}
```

### Separate Devices for Different Storage Classes

If you have both fast SSD storage and slower HDD storage, define separate Device resources and route jobs to each based on their priority:

```
# Device on fast SSD (for recent/important backups)
Device {
  Name = SSDStorage
  DeviceType = File
  MediaType = SSD
  ArchiveDevice = /var/lib/bareos/storage/ssd
  Maximum Block Size = 1048576
  Maximum Volume Size = 100G
  Maximum Concurrent Jobs = 8
  Always Open = yes
}

# Device on slow HDD (for long-term archive backups)
Device {
  Name = HDDStorage
  DeviceType = File
  MediaType = HDD
  ArchiveDevice = /var/lib/bareos/storage/hdd
  Maximum Block Size = 1048576
  Maximum Volume Size = 200G
  Maximum Concurrent Jobs = 2
  Always Open = yes
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Spooling: What It Is and When to Use It

Spooling is widely misunderstood. It is a powerful technique in the *right*
scenario, but it does **not** universally speed up backups — and for the
single-job disk-to-disk setup in this course it usually does not speed up
the job at all. Understand what it actually does before enabling it.

There are two independent kinds of spooling in Bareos, and they help in
different situations:

- **Data spooling** (`Spool Data = yes`): the Storage Daemon writes the job's
  data to a spool file first, then de-spools it to the final volume.
- **Attribute spooling** (`Spool Attributes = yes`): the file metadata
  records are buffered and inserted into the catalog in one batch at the end
  of the job instead of trickling in during the backup.

### The Problem Data Spooling Solves (Tape and Concurrency)

Data spooling exists primarily for **tape** and for **interleaving
concurrent jobs onto a single sequential device**:

- **Tape shoe-shining.** A tape drive must stream continuously. If the data
  source can't keep the drive fed, the drive stops, rewinds, and repositions
  ("shoe-shining"), which is slow and wears the tape. Spooling to disk first,
  then de-spooling at full speed, keeps the tape streaming.
- **Interleaving / fragmentation.** When several jobs write to one device at
  the same time, their blocks interleave on the volume. Spooling each job to
  its own spool file and de-spooling them one at a time keeps each job's data
  contiguous on the volume, which makes later restores faster.

```
Tape without spooling (shoe-shining):
  FD/network deliver in bursts → tape drive starves, stops, repositions
  Effective tape throughput collapses far below the drive's rated speed

Tape with data spooling:
  Job data lands on disk spool first
  → de-spool streams to tape at full rated speed, no repositioning
```

### Why Data Spooling Usually Does NOT Help Single-Job Disk-to-Disk

For a single job writing to a **disk** volume (this course's setup), data
spooling generally does **not** make the job faster, and can make it slower:

- The data is written **twice** (once to the spool, once to the final volume)
  and read back once during de-spool. That is extra I/O, not less.
- De-spooling happens **inside the job** — the job is not reported complete,
  and `wait` does not return, until de-spooling finishes. So the wall-clock
  time of `run` + `wait` *includes* the de-spool. Spooling does not let the
  next job start "early"; that is a tape/concurrency benefit, not a
  disk-single-job one.
- If your final volume is on the same disk as the spool, you have simply
  doubled the write load on one device.

The honest expectation for the disk-to-disk lab later in this chapter is:
spooling will likely be **neutral or slightly slower** for a single job,
unless you are observing interleaving with concurrent jobs.

### What Genuinely Helps Disk-to-Disk: Spool Attributes

The knob that reliably helps disk-to-disk catalog performance is
**`Spool Attributes = yes`**. Instead of inserting file records into MariaDB
one stream at a time during the backup, the File Daemon's attribute records
are spooled and then **batch-inserted** at the end of the job. For jobs with
many files this dramatically cuts the catalog-update phase (the time a job
spends "finishing" after the data is already written). Attribute spooling is
also enabled automatically when `Spool Data = yes`, but you can — and for
disk-to-disk should — enable it on its own.

### When NOT to Use Data Spooling

- For single-job disk-to-disk backups (it adds an extra write + read).
- When your final backup storage is already as fast as, or faster than, the
  spool device.
- When you do not have sufficient fast storage for the spool (the spool must
  be large enough to hold a job's data, bounded by `Maximum Job Spool Size`).
- When you are near disk capacity on the spool device.

Reach for data spooling when you are writing to tape, or interleaving many
concurrent jobs onto one device. Otherwise, enable `Spool Attributes` and
skip data spooling.

### Storage Daemon Spooling Configuration

```
# /etc/bareos/bareos-sd.conf

Device {
  Name = FileStorage
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage    # Slow HDD or NAS

  # SpoolDirectory is where the spool files are written.
  # Point this to your fastest storage (SSD, NVMe).
  # The spool directory must have enough free space for the concurrent
  # jobs' data. Rule of thumb: Maximum Job Spool Size × Maximum Concurrent Jobs.
  Spool Directory = /var/lib/bareos/spool    # Map to fast SSD via volume mount

  # Maximum Spool Size caps the TOTAL spool space this device may use across
  # all jobs at once. It is the device-level guard rail that stops a busy
  # night from filling the spool disk.
  Maximum Spool Size = 40G

  # Maximum Job Spool Size caps how much spool space a SINGLE job may use.
  # When a job hits this limit, the SD de-spools that job's data to the
  # volume to free space, then continues spooling. (The Director's
  # per-job "Spool Size" directive does the same thing from the Job side.)
  Maximum Job Spool Size = 20G

  Maximum Block Size = 1048576
  Maximum Concurrent Jobs = 4
  Always Open = yes
}
```

### Quadlet Volume Mount for Spool on Fast SSD

On the host, you need a separate volume or bind-mount for the spool directory. Add it to the Storage Daemon Quadlet:

```
# /home/bareos/.config/containers/systemd/bareos-storage.container
[Unit]
Description=Bareos Storage Daemon
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-storage:24

Volume=/etc/bareos/bareos-sd.d:/etc/bareos/bareos-sd.d:ro,Z
Volume=bareos-working.volume:/var/lib/bareos

# Slow HDD storage — final destination for volumes
Volume=/srv/bareos-storage/volumes:/var/lib/bareos/storage:z

# Fast SSD spool — temporary holding area during active backups.
# /srv/bareos-spool is a separate mount on an SSD or NVMe device.
# The :z suffix applies the correct SELinux label for container access.
Volume=/srv/bareos-spool:/var/lib/bareos/spool:z

Network=bareos.network
PublishPort=9103:9103

[Service]
Restart=always

[Install]
WantedBy=default.target
```

### Director Job-Level Spooling

You can also enable or disable spooling per-job in the Director. This
`BackupClient1` example illustrates a multi-client environment (client
`client1-fd`); in our single-client lab the equivalent job is
`BackupLocalHost` against `bareos-fd`:

```
# /etc/bareos/bareos-dir.d/job/BackupClient1.conf

Job {
  Name = "BackupClient1"
  Type = Backup
  Client = client1-fd
  FileSet = "Full Set"
  Storage = File          # the Storage resource defined in Chapter 6
  Pool = Full
  Messages = Standard
  Schedule = "WeeklyCycle"

  # SpoolAttributes = yes batches the file attribute records and inserts
  # them into the catalog in one pass at the end of the job. This is the
  # setting that reliably helps disk-to-disk jobs with many files — enable
  # it on its own, even when you are NOT using data spooling.
  Spool Attributes = yes

  # SpoolData = yes enables DATA spooling for this job: the SD writes the
  # job's data to the spool first, then de-spools to the volume.
  # Only worthwhile for tape, or for interleaving concurrent jobs onto one
  # device. For single-job disk-to-disk it adds an extra write + read and
  # de-spooling happens before the job completes, so it usually does NOT
  # speed the job up (see "When NOT to Use Data Spooling" above).
  Spool Data = yes

  # SpoolSize limits how much spool space this single job can use.
  # If the job exceeds this size, Bareos de-spools what is buffered to the
  # final volume to free space, then continues spooling.
  Spool Size = 20G
}
```

### Setting Up the Spool Directory

```bash
# On the RHEL 10 host, create the spool directory on your SSD:
mkdir -p /srv/bareos-spool

# Set ownership
chown bareos:bareos /srv/bareos-spool

# Set SELinux context (container_file_t — same type as the storage directory)
semanage fcontext -a -t container_file_t "/srv/bareos-spool(/.*)?"
restorecon -Rv /srv/bareos-spool/

# Verify the context
ls -laZ /srv/bareos-spool/
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Rootless Podman and cgroup v2 Resource Constraints

RHEL 10 uses cgroup v2 by default. Rootless Podman can apply cgroup v2 resource limits to containers, allowing you to prevent Bareos containers from starving other workloads on a shared host.

### Verifying cgroup v2 Is Active

```bash
# Check the cgroup version
stat -fc %T /sys/fs/cgroup
# If the output is "cgroup2fs", you are on v2. Good.
# If it shows "tmpfs", you are on v1 — cgroup v2 features will not work.

# Check that the bareos user can use resource controls
sudo -u bareos bash -c '
  cat /proc/self/cgroup
'
# Should show cgroup v2 paths
```

### Understanding Why Resource Limits Matter

Without limits, a Full backup job that reads a large filesystem can:
- Consume all available CPU cores (if GZIP compression is on)
- Consume all available RAM (if many files are cached in the page cache)
- Saturate disk I/O, impacting other applications

Setting limits is a trade-off: lower limits protect other workloads but extend the backup window.

> **Rootless caveat — swap limits may be unenforced.** Setting a memory *and*
> swap limit (`--memory-swap` / `MemorySwap=`) for a **rootless** container
> requires the `memory` controller — and on some setups the `memory.swap.max`
> file — to be delegated to your user slice under cgroup v2. If your user
> slice does not have the memory controller delegated, Podman accepts the
> flag but the swap limit is silently **not enforced** (you may see a warning
> like "Your kernel does not support swap limit capabilities"). Check what is
> delegated with `cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/cgroup.controllers`;
> if `memory` is missing, enable delegation (e.g. a drop-in for
> `user@<uid>.service` with `Delegate=memory pids cpu`) or simply set
> `Memory=` alone and leave swap at the host default. Plain `--memory` /
> `Memory=` (without a swap value) is far more widely enforced.

### Applying Limits via Podman CLI (Temporary, for Testing)

```bash
# Limit the bareos-storage container to 2 CPU cores and 2 GB RAM
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman update \
    --cpus 2 \
    --memory 2g \
    --memory-swap 4g \
    bareos-storage
'

# Verify
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman inspect bareos-storage --format "{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}}"
'
```

### Applying Limits Persistently in Quadlet Files

Quadlet files accept `podman run`-compatible resource directives in the `[Container]` section. These are permanently applied every time the service starts.

```
# /home/bareos/.config/containers/systemd/bareos-storage.container
[Unit]
Description=Bareos Storage Daemon
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-storage:24

Volume=/etc/bareos/bareos-sd.d:/etc/bareos/bareos-sd.d:ro,Z
Volume=bareos-working.volume:/var/lib/bareos
Volume=/srv/bareos-storage/volumes:/var/lib/bareos/storage:z
Volume=/srv/bareos-spool:/var/lib/bareos/spool:z

Network=bareos.network
PublishPort=9103:9103

# === Resource Limits ===
#
# Memory: Hard limit. If the container exceeds this, the OOM killer
# terminates it. Set this generously (at least 512 MB for the SD,
# more if spooling large jobs).
Memory=2G

# MemorySwap: Total memory + swap. Setting it equal to Memory
# disables swap for this container (recommended for predictable performance).
MemorySwap=2G

# CPUWeight: Relative CPU weight on cgroup v2. Default is 100, range 1-10000.
# Setting it to 50 means this container gets half the CPU time of a container
# at the default 100 when the CPU is contested. During off-peak hours when
# nothing else is running, it still gets 100% of the CPU.
# (CPUShares is the legacy cgroup v1 directive — default 1024 — which Podman
# maps onto CPUWeight for compatibility; since this host is cgroup v2, use
# CPUWeight directly.)
CPUWeight=50

# CPUQuota: Hard CPU cap as a percentage of one core.
# "200%" means this container can use at most 2 full CPU cores.
# Remove this if you want backups to run as fast as possible
# and do not share the host with other applications.
# CPUQuota=200%

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```
# /home/bareos/.config/containers/systemd/bareos-director.container
[Unit]
Description=Bareos Director
After=bareos-db.service
Requires=bareos-db.service

[Container]
Image=docker.io/bareos/bareos-director:24

Volume=/etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z
Volume=bareos-working.volume:/var/lib/bareos

EnvironmentFile=/home/bareos/.config/bareos/bareos.env

Network=bareos.network
PublishPort=127.0.0.1:9101:9101

# Director is mostly idle (coordinator), so modest limits are fine
Memory=512M
MemorySwap=512M
CPUWeight=25

[Service]
Restart=always
TimeoutStartSec=120

[Install]
WantedBy=default.target
```

```
# /home/bareos/.config/containers/systemd/bareos-db.container
[Unit]
Description=Bareos MariaDB Catalog Database
After=network-online.target

[Container]
Image=docker.io/library/mariadb:10.11

Volume=bareos-db-data.volume:/var/lib/mysql
EnvironmentFile=/home/bareos/.config/bareos/db.env
Network=bareos.network

# MariaDB benefits most from generous memory allocation.
# The InnoDB buffer pool (configured below) should fit within this limit.
# A good rule: Memory = InnoDB buffer pool size × 1.3 (for overhead).
Memory=2G
MemorySwap=2G
CPUWeight=50

[Service]
Restart=always
TimeoutStartSec=180

[Install]
WantedBy=default.target
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. MariaDB Catalog Tuning

The Catalog database is the bottleneck when running jobs with millions of files. Tuning MariaDB is one of the highest-impact changes you can make if you observe slow job completion (jobs that back up quickly but take a long time to update the catalog).

### Creating a Custom MariaDB Configuration File

MariaDB inside the container reads configuration from `/etc/mysql/conf.d/`. Mount a custom configuration file via the volume:

```bash
# Create the custom config directory on the host (inside the volume's _data)
sudo -u bareos bash -c '
  MYSQL_CONF=$(podman volume inspect bareos-db-data --format "{{.Mountpoint}}")/../conf.d
  # Actually, we mount it as a bind mount. Create it at a known path:
  mkdir -p /home/bareos/.config/bareos/mysql-conf.d
'

# Write the tuning configuration
cat > /home/bareos/.config/bareos/mysql-conf.d/bareos-tuning.cnf << 'EOF'
# /etc/mysql/conf.d/bareos-tuning.cnf
# MariaDB tuning for Bareos catalog workloads.
# Mounted read-only into the bareos-db container.

[mysqld]

# === InnoDB Buffer Pool ===
#
# This is the single most important MariaDB tuning parameter.
# The InnoDB buffer pool is the in-memory cache for table data and indexes.
# When a job inserts file records, MariaDB checks the buffer pool first.
# If the relevant index pages are not in cache, it reads from disk (slow).
# A larger buffer pool means fewer disk reads.
#
# Sizing rule: set to 70–80% of the RAM available to the MariaDB container.
# With a 2 GB container memory limit → 1.4–1.6 GB is appropriate.
# With a 4 GB container memory limit → 2.8–3.2 GB is appropriate.
# For large catalogs (10M+ files), plan for 4–8 GB and set the container
# memory limit accordingly (add 20% headroom above the buffer pool size
# for connection threads, sort buffers, and the OS page cache).
#
# The example below uses 1G, which suits a 1.5–2 GB container limit.
# Adjust to match your actual container --memory= setting.
innodb_buffer_pool_size = 1G

# For buffer pools larger than 1 GB, split into multiple instances
# to reduce contention. One instance per GB is a good rule.
innodb_buffer_pool_instances = 1

# === InnoDB Log File Size ===
#
# The InnoDB redo log (transaction log) records changes before committing
# to the data files. A larger log file means fewer checkpoint flushes,
# improving write throughput for bulk INSERT operations (like catalog
# updates with millions of file records).
#
# Size it to your WRITE workload, not as a fixed fraction of the buffer pool.
# The redo log needs to be large enough to absorb the writes generated
# between checkpoints without forcing aggressive flushing. For Bareos's
# write-heavy, bulk-insert catalog workload, larger is better — a few hundred
# MB to a couple of GB is typical; the trade-off is longer crash recovery and
# more disk space. (MariaDB 10.11 still uses innodb_log_file_size; on some
# newer engines this was folded into a single innodb_redo_log_capacity, but
# 10.11 — the version used in this course — keeps innodb_log_file_size.)
# Start at 512M for a busy catalog and raise it if you still see frequent
# checkpoint flushing under load.
innodb_log_file_size = 512M

# === InnoDB Flush Method ===
#
# O_DIRECT bypasses the OS page cache for InnoDB data files.
# This avoids double-buffering (data cached both in InnoDB and OS cache).
# Recommended when innodb_buffer_pool_size is large.
innodb_flush_method = O_DIRECT

# === InnoDB Flush at Transaction Commit ===
#
# Controls how often InnoDB flushes the log to disk.
# 2 = flush once per second (not per transaction). This risks losing
#     up to 1 second of transactions on a crash, but dramatically
#     improves write throughput for bulk INSERTs.
# 1 = flush on every commit (fully ACID, slowest for bulk writes)
# 0 = never flush (fastest, but risky — use only in testing)
#
# For Bareos catalog updates, losing 1 second of data means re-running
# the backup job — an acceptable trade-off. Use value 2 for production.
innodb_flush_log_at_trx_commit = 2

# === Table Open Cache ===
#
# Bareos uses many tables. A larger cache means fewer open/close operations.
table_open_cache = 2000
table_definition_cache = 1000

# === Sort Buffer and Join Buffer ===
#
# Larger sort buffers improve ORDER BY and GROUP BY query performance.
# Bareos's bconsole "list jobs" queries use these extensively.
sort_buffer_size = 4M
join_buffer_size = 4M
read_rnd_buffer_size = 4M

# === Query Cache ===
#
# The query cache is disabled in MariaDB 10.6+ by default (and removed
# in 10.9+). Do not configure it — it causes contention under write load.
# query_cache_type = 0
# query_cache_size = 0

# === Slow Query Log ===
#
# Enable this to identify slow Catalog queries during a backup.
# Disable in production once tuning is complete, as it adds I/O overhead.
slow_query_log = 1
slow_query_log_file = /var/lib/mysql/slow-queries.log
long_query_time = 2    # Log queries taking longer than 2 seconds

# === Max Connections ===
#
# Bareos Director opens multiple connections to MariaDB.
# Set this to (Maximum Concurrent Jobs × 2) + 10 as a safe minimum.
max_connections = 100

# === Thread Cache ===
#
# Reuse threads for new connections rather than creating/destroying them.
# Reduces latency for the rapid connection cycling during job cataloging.
thread_cache_size = 20

# === Aria / MyISAM (for legacy tables) ===
#
# Some Bareos internal tables use Aria or MyISAM. Keep key_buffer_size small
# since Bareos primarily uses InnoDB.
key_buffer_size = 64M
EOF

chown bareos:bareos /home/bareos/.config/bareos/mysql-conf.d/bareos-tuning.cnf
```

### Mounting the Config File in the Bareos-DB Quadlet

```
# /home/bareos/.config/containers/systemd/bareos-db.container
[Unit]
Description=Bareos MariaDB Catalog Database
After=network-online.target

[Container]
Image=docker.io/library/mariadb:10.11

Volume=bareos-db-data.volume:/var/lib/mysql

# Mount the custom tuning configuration read-only.
# :ro means the container cannot modify it.
# :z applies the SELinux label for container access.
Volume=/home/bareos/.config/bareos/mysql-conf.d:/etc/mysql/conf.d:ro,z

EnvironmentFile=/home/bareos/.config/bareos/db.env
Network=bareos.network

Memory=2G
MemorySwap=2G
CPUWeight=50

HealthCmd=mysqladmin --user=root --password=${MARIADB_ROOT_PASSWORD} ping --silent
HealthInterval=30s
HealthRetries=5
HealthStartPeriod=60s

[Service]
Restart=always
TimeoutStartSec=180

[Install]
WantedBy=default.target
```

### Applying the Configuration

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload
  systemctl --user restart bareos-db.service
  sleep 20
  # Verify the new settings were applied
  podman exec bareos-db mysql \
    --user=root \
    --password=$(grep MARIADB_ROOT_PASSWORD ~/.config/bareos/db.env | cut -d= -f2) \
    -e "SHOW VARIABLES LIKE \"innodb_buffer_pool_size\";"
'
# Expected: innodb_buffer_pool_size  1073741824 (= 1 GB)
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Network: TCP Tuning for Large Backup Transfers

For large backups running over a LAN, TCP buffer sizes significantly impact throughput. The Linux kernel's default TCP buffer sizes were designed for internet latency, not local LAN transfers.

> **Host-level changes required:** `sysctl` settings affect the kernel of the host machine, not individual containers. These commands **must be run on the host** with `sudo` (or as `root`). They cannot be applied from inside a Podman container — rootless containers do not have the `CAP_SYS_ADMIN` capability needed to modify kernel parameters. Apply these settings on the host that runs the Bareos Storage Daemon container, as the SD container inherits the host's TCP stack.

### Checking Current TCP Buffer Sizes

```bash
# Current TCP receive buffer
cat /proc/sys/net/core/rmem_max
# Default is often 212992 bytes (~207 KB) — small for a 10 Gbps LAN

# Current TCP send buffer
cat /proc/sys/net/core/wmem_max

# Current TCP auto-tuning range
cat /proc/sys/net/ipv4/tcp_rmem
# Format: min default max
```

### Applying TCP Tuning for Backup Workloads

```bash
# Create a sysctl configuration file for Bareos-specific network tuning
# Run this on the HOST as root/sudo — not inside a container
sudo bash -c "cat > /etc/sysctl.d/80-bareos-network.conf << 'EOF'
# TCP buffer tuning for large backup data transfers
# These settings increase the maximum TCP window size, allowing the
# kernel to buffer more data in flight and sustaining higher throughput
# on a fast LAN (1 Gbps or 10 Gbps).

# Maximum socket receive buffer: 128 MB
net.core.rmem_max = 134217728

# Maximum socket send buffer: 128 MB
net.core.wmem_max = 134217728

# TCP receive buffer auto-tuning: min=4KB, default=128KB, max=128MB
net.ipv4.tcp_rmem = 4096 131072 134217728

# TCP send buffer auto-tuning: min=4KB, default=128KB, max=128MB
net.ipv4.tcp_wmem = 4096 131072 134217728

# Enable TCP window scaling (allows windows > 65535 bytes)
# Required for any buffer size above 64 KB to be effective.
net.ipv4.tcp_window_scaling = 1

# Number of packets in the NIC transmit queue before throttling.
# Higher values reduce drops on burst traffic.
net.core.netdev_max_backlog = 5000

# Enable selective ACK (SACK) for better loss recovery
net.ipv4.tcp_sack = 1

# Enable TCP timestamps for better RTT estimation
net.ipv4.tcp_timestamps = 1
EOF
"

# Apply immediately without rebooting (host sudo required)
sudo sysctl --load /etc/sysctl.d/80-bareos-network.conf

# Verify
sysctl net.core.rmem_max
```

### Bareos-Level Network Buffer Size

The sysctl settings above raise the *kernel's* TCP buffer ceilings. Bareos
has its own application-level companion directive, **`Maximum Network Buffer
Size`**, which sets the size of the read/write buffer the daemon uses for its
socket I/O. Raising it lets each transfer move larger chunks per system call,
which complements the larger TCP windows. Set it on **both** the File Daemon
and the Storage Daemon — the two sides negotiate and use the smaller of the
two values, so a large value on only one end has no effect.

```
# /etc/bareos/bareos-fd.conf  (Client resource — the connection to the Director)
Client {
  Name = bareos-fd
  # ... other directives ...
  Maximum Network Buffer Size = 1048576   # 1 MB
}

# /etc/bareos/bareos-sd.conf  (Storage resource)
Storage {
  Name = bareos-sd
  # ... other directives ...
  Maximum Network Buffer Size = 1048576   # 1 MB
}
```

The default (64 KB) is fine for most LANs; raise it together with the TCP
sysctls only when you are pushing large streams over a fast (10 GbE+) link
and have confirmed the network — not disk or CPU — is the bottleneck.

### Jumbo Frames (9000 MTU)

If your network infrastructure supports jumbo frames (MTU 9000), enabling them reduces CPU overhead for large transfers by putting more data per packet:

```bash
# Check the current MTU on the network interface
ip link show eth0 | grep mtu

# Enable jumbo frames (requires switch/router support — verify first!)
ip link set eth0 mtu 9000

# Make persistent in RHEL 10:
nmcli connection modify "Wired connection 1" 802-3-ethernet.mtu 9000
nmcli connection up "Wired connection 1"

# Verify inside containers (Podman inherits the host MTU for bridge networks)
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage ip link show eth0
'
```

**Warning**: Jumbo frames must be supported end-to-end. If any device in the path does not support them, packets are fragmented or dropped, which can cause worse performance than standard 1500-byte MTU.

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Volume Auto-labeling and Pre-labeling

Every Bareos volume must be labeled before it can be written to. If Bareos needs a new volume and none are available, the job pauses and waits for an operator to label one — potentially blocking your entire backup window.

### Auto-labeling Configuration

```
# /etc/bareos/bareos-dir.d/pool/Full.conf
#
# The Pool resource defines a collection of volumes with the same
# retention and labeling policies.

Pool {
  Name = Full
  Pool Type = Backup
  Recycle = yes                   # Reuse expired volumes automatically
  AutoPrune = yes                 # Remove expired volume records from catalog
  Volume Retention = 365 days     # Keep Full backup volumes for 1 year

  # MaximumVolumes limits how many volumes exist in this pool at once.
  # When all volumes are Full and none have expired, new jobs fail.
  # Set this based on your expected data volume and retention period.
  Maximum Volumes = 100

  # LabelFormat tells Bareos the naming convention for new volumes.
  # The %% expands to a zero-padded sequence number.
  # Example: "Full-" produces Full-0001, Full-0002, ...
  Label Format = "Full-"

  # AutoLabel is the most important setting for unattended operation.
  # When Bareos needs a new volume and none are available, instead of
  # pausing and waiting for an operator, it automatically creates and
  # labels a new volume file.
  #
  # The value specifies which media type triggers auto-labeling.
  # Set it to your MediaType (e.g., "File" for disk-based storage).
  AutoLabel = File
}

Pool {
  Name = Incremental
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 30 days      # Keep Incrementals for 30 days
  Maximum Volumes = 200
  Label Format = "Incr-"
  AutoLabel = File
}

Pool {
  Name = Differential
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 90 days
  Maximum Volumes = 50
  Label Format = "Diff-"
  AutoLabel = File
}
```

### Pre-labeling Volumes in Advance

You can also pre-label volumes interactively in bconsole, which avoids the runtime overhead of on-demand labeling:

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'

# In bconsole, label 10 new volumes in the Full pool:
# (File is the Storage resource defined in Chapter 6.)
*label storage=File pool=Full
# Bareos prompts for a volume name. Type: Full-0001
# Repeat for Full-0002 through Full-0010

# Or use the "label barcodes" command with a list file for bulk labeling:
*label barcodes storage=File pool=Full

# After labeling, verify:
*list volumes pool=Full
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Storage Device Multiplexing

If you have multiple physical disks or separate storage paths, you can define multiple `Device` resources on a single Storage Daemon. Bareos then distributes jobs across devices, achieving parallel writes:

```
# /etc/bareos/bareos-sd.conf — multiple devices

Device {
  Name = FileStorage1
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage/disk1
  Maximum Block Size = 1048576
  Maximum Concurrent Jobs = 4
  Always Open = yes
}

Device {
  Name = FileStorage2
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage/disk2
  Maximum Block Size = 1048576
  Maximum Concurrent Jobs = 4
  Always Open = yes
}

Device {
  Name = FileStorage3
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage/disk3
  Maximum Block Size = 1048576
  Maximum Concurrent Jobs = 4
  Always Open = yes
}
```

Each device needs its own mount in the Storage Daemon Quadlet:

```
# bareos-storage.container [Container] section additions:
Volume=/srv/bareos-storage/disk1:/var/lib/bareos/storage/disk1:z
Volume=/srv/bareos-storage/disk2:/var/lib/bareos/storage/disk2:z
Volume=/srv/bareos-storage/disk3:/var/lib/bareos/storage/disk3:z
```

The Director's Storage resource references all three devices via `AutoChanger`:

```
# /etc/bareos/bareos-dir.d/storage/MultiDisk.conf
Storage {
  Name = MultiDisk
  Address = bareos-sd
  SDPort = 9103
  Password = "SD-PASSWORD"
  Device = FileStorage1
  Device = FileStorage2
  Device = FileStorage3
  Media Type = File

  # With multiple devices, the Director can send concurrent jobs to different
  # devices, achieving true parallel writes to separate disks.
  Maximum Concurrent Jobs = 12    # 4 per device × 3 devices
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Incremental Backup Optimization

Incremental backups rely on change detection: Bareos must determine which files have changed since the last backup. The default method is to compare the file's `mtime` (modification time) and `ctime` (change time). This is fast but not completely reliable — certain operations (like `rsync --checksum`) change file content without updating mtime.

### Check File Changes Directive

The `CheckFileChanges` option in the FileSet makes the File Daemon check file modification time before and after reading it, detecting files modified *during* the backup:

```
FileSet {
  Name = "FullSet"
  Include {
    Options {
      Signature = SHA1
      Compression = LZ4
      NoAtime = yes

      # CheckFileChanges = yes detects files that were modified during the
      # backup scan. Without this, you might back up a partially-written file.
      # It adds a small overhead (a second stat() call per file) but prevents
      # silently inconsistent backups on active systems.
      Check File Changes = yes

      # Accurate = yes enables accurate mode for incremental backups.
      # In accurate mode, the File Daemon receives the file list from the
      # previous backup and holds it in memory to compare against the current
      # scan. This catches renamed and deleted files, which normal mode misses.
      # WARNING: the in-memory accurate list lives on the FILE DAEMON (the
      # client), not the Director. For FileSets with millions of files this
      # can consume significant RAM on the client being backed up — size the
      # bareos-fd container's Memory= accordingly and monitor it after enabling.
      # Accurate = yes  (set this at the Job level, not FileSet level)
    }
    File = /home
    File = /etc
    File = /var/www
  }
}
```

### Accurate Mode at the Job Level

```
# /etc/bareos/bareos-dir.d/job/BackupClient1.conf
Job {
  Name = "BackupClient1"
  Type = Backup
  Client = client1-fd
  FileSet = "Full Set"
  Storage = File          # the Storage resource defined in Chapter 6
  Pool = Full
  Messages = Standard
  Schedule = "WeeklyCycle"

  # Accurate = yes enables accurate incremental/differential backups.
  # Bareos sends the previous backup's file list to the File Daemon, which
  # compares it (in memory, on the client) against the current scan. Files
  # that were deleted on the client are marked as deleted in the Catalog
  # (important for bare-metal and full system restores).
  # Remember the memory cost lands on the client (bareos-fd), not the Director.
  Accurate = yes
}
```

### I/O Priority for the File Daemon

Bareos has no configuration directive for the File Daemon's I/O priority — you
control it at the **OS level** instead, using the Linux I/O scheduler
(`ionice`). On production servers, run the File Daemon process in the *idle*
I/O class so it only consumes disk bandwidth when no application needs it.

The clean way to do this for our containerised, systemd-managed FD is a
**drop-in** on the `bareos-fd` service that wraps the container's main process
with an idle I/O scheduling class:

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  mkdir -p ~/.config/systemd/user/bareos-fd.service.d
  cat > ~/.config/systemd/user/bareos-fd.service.d/10-ioprio.conf <<EOF
[Service]
# Run the File Daemon in the idle I/O class (class 3): it gets disk I/O
# only when no other process on the host wants it. This keeps backups
# from impacting production application latency.
IOSchedulingClass=idle
EOF
  systemctl --user daemon-reload
  systemctl --user restart bareos-fd.service
'
```

`IOSchedulingClass=idle` maps to `ionice -c3`. If you want a "best-effort but
low" priority instead of fully idle, use `IOSchedulingClass=best-effort` with
`IOSchedulingPriority=7` (7 is the lowest best-effort level).

> Note: I/O priority is only honoured by I/O schedulers that support it (e.g.
> BFQ). On a host using the `none`/`mq-deadline` scheduler the idle class has
> little effect — verify with `cat /sys/block/<dev>/queue/scheduler`.

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Bareos Director Performance Directives

The Director itself has several configuration options that affect overall system performance.

```
# /etc/bareos/bareos-dir.conf

Director {
  Name = bareos-dir
  DIRport = 9101
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  WorkingDirectory = "/var/lib/bareos"
  PidDirectory = "/var/run/bareos"

  # Maximum Concurrent Jobs caps JOB PARALLELISM (how many jobs run at once).
  Maximum Concurrent Jobs = 20

  # Maximum Connections caps incoming network CONNECTIONS (consoles, Web UI,
  # daemon control connections) — not jobs. These two limit different things;
  # raise both if you run many parallel jobs alongside several open consoles.
  Maximum Connections = 50

  Password = "DIRECTOR-PASSWORD"
  Messages = Daemon

  # === Catalog database connections ===
  #
  # There is no "DB Max Connections" directive on the Director resource.
  # The Director manages a small internal connection pool per Catalog and
  # opens connections to MariaDB as jobs need them. You do not size this from
  # the Director; instead make sure MariaDB's own max_connections (set in the
  # bareos-tuning.cnf in Section 11) is comfortably higher than your peak
  # concurrent job count so the Director never gets refused a connection.

  # === Statistics Retention ===
  #
  # Statistics Retention controls how long job summary statistics are kept.
  # After this period, old statistics records are pruned from the Catalog.
  # This prevents the Statistics table from growing indefinitely.
  # Shorter retention = smaller catalog = faster queries.
  Statistics Retention = 12 months

  # === File Retention and Job Retention ===
  #
  # These are defaults applied to all clients that don't override them.
  # File Retention controls how long file records stay in the Catalog.
  # After expiry, file records are removed (but the volume files remain
  # on disk — you can still restore using bootstrap files).
  # Shorter file retention dramatically reduces catalog size.
  File Retention = 90 days

  # Job Retention controls how long job records stay in the Catalog.
  # Job records are smaller than file records, so keep them longer.
  Job Retention = 12 months

  # === Heartbeat Interval ===
  #
  # How often the Director sends a heartbeat to connected File Daemons
  # to keep TCP connections alive across firewalls and NAT.
  Heartbeat Interval = 5 minutes

  # === Secure Erase Command ===
  #
  # When Bareos needs to delete temporary files (like spool files after
  # de-spooling), this command is used. The default is simply "rm".
  # For high-security environments, replace with "shred -u".
  # Secure Erase Command = "/usr/bin/shred -u"
}
```

### Catalog Pruning

Regular catalog pruning keeps the database small and queries fast. Configure automatic pruning:

```
# In the Director configuration, ensure AutoPrune is enabled globally
# or per-client. Auto-pruning runs at the end of each job.

Client {
  Name = client1-fd
  Address = 192.168.1.20
  FDPort = 9102
  Catalog = MyCatalog
  Password = "CLIENT-PASSWORD"

  # AutoPrune = yes runs automatic pruning of expired records after each job.
  AutoPrune = yes

  # These retention periods govern what AutoPrune removes.
  File Retention = 90 days
  Job Retention = 12 months

  # Volume Retention is set in the Pool, not here.
}
```

Run manual catalog pruning from bconsole when needed. In our single-client
lab the client is `bareos-fd`:

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
prune files client=bareos-fd yes
prune jobs client=bareos-fd yes
prune volume pool=Full yes
EOF
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 17. Container Resource Limits in Quadlet

This section consolidates all container resource limit directives for the complete Bareos Quadlet setup, with full annotations. These are the recommended production-ready settings for a host with 8 GB RAM and 4 CPU cores dedicated to Bareos.

```
# /home/bareos/.config/containers/systemd/bareos-db.container
[Unit]
Description=Bareos MariaDB Catalog Database
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/library/mariadb:10.11
Volume=bareos-db-data.volume:/var/lib/mysql
Volume=/home/bareos/.config/bareos/mysql-conf.d:/etc/mysql/conf.d:ro,z
EnvironmentFile=/home/bareos/.config/bareos/db.env
Network=bareos.network
HealthCmd=mysqladmin --user=root --password=${MARIADB_ROOT_PASSWORD} ping --silent
HealthInterval=30s
HealthRetries=5
HealthStartPeriod=60s

# MariaDB gets the most memory — its InnoDB buffer pool is the key resource
Memory=3G
MemorySwap=3G
# Give the DB high CPU priority during catalog update bursts
CPUWeight=100

[Service]
Restart=always
TimeoutStartSec=180

[Install]
WantedBy=default.target
```

```
# /home/bareos/.config/containers/systemd/bareos-director.container
[Unit]
Description=Bareos Director
After=bareos-db.service
Requires=bareos-db.service

[Container]
Image=docker.io/bareos/bareos-director:24
Volume=/etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z
Volume=bareos-working.volume:/var/lib/bareos
EnvironmentFile=/home/bareos/.config/bareos/bareos.env
Network=bareos.network
PublishPort=127.0.0.1:9101:9101

# Director is mostly I/O wait and coordination — needs less CPU/RAM
Memory=1G
MemorySwap=1G
CPUWeight=50

[Service]
Restart=always
TimeoutStartSec=120

[Install]
WantedBy=default.target
```

```
# /home/bareos/.config/containers/systemd/bareos-storage.container
[Unit]
Description=Bareos Storage Daemon
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-storage:24
Volume=/etc/bareos/bareos-sd.d:/etc/bareos/bareos-sd.d:ro,Z
Volume=bareos-working.volume:/var/lib/bareos
Volume=/srv/bareos-storage/volumes:/var/lib/bareos/storage:z
Volume=/srv/bareos-spool:/var/lib/bareos/spool:z
Network=bareos.network
PublishPort=9103:9103

# Storage Daemon needs memory for spool buffers and block I/O
Memory=2G
MemorySwap=2G
# Relatively high CPU share for compression during de-spooling
CPUWeight=75

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```
# /home/bareos/.config/containers/systemd/bareos-fd.container
[Unit]
Description=Bareos File Daemon (Client)
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-client:24
Volume=bareos-fd-config.volume:/etc/bareos
Network=bareos.network
PublishPort=9102:9102

# File Daemon reads client data — needs enough memory for compression buffers
Memory=512M
MemorySwap=512M
CPUWeight=25

[Service]
Restart=always

[Install]
WantedBy=default.target
```

After updating Quadlet files, always reload and restart:

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload
  systemctl --user restart bareos-db.service
  sleep 10
  systemctl --user restart bareos-director.service bareos-storage.service bareos-fd.service
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 18. Lab 19-1: Measure Baseline Backup Throughput

**Objective**: Establish a measurable baseline before any tuning so you can quantify the impact of each change.

**Prerequisites**: Bareos is running with at least one completed Full backup job.

### Step 1: Prepare a Benchmark FileSet

Create a FileSet of known data for reproducible measurements:

The benchmark directory is created on the host at `/tmp/bareos-bench`. The
File Daemon runs as the `bareos-fd` container with the host mounted read-only
at `/hostfs`, so the FileSet in Step 2 references it as `/hostfs/tmp/bareos-bench`.

```bash
# Create a benchmark directory with known content
sudo -u bareos bash -c '
  mkdir -p /tmp/bareos-bench/text
  mkdir -p /tmp/bareos-bench/binary

  # Generate ~1 GB of COMPRESSIBLE text data.
  # /dev/urandom is incompressible, so we build highly compressible text:
  # repeat a "log line" until each file is ~64 MB, across 16 files = ~1 GB.
  echo "Generating ~1 GB compressible text benchmark data..."
  line="2026-01-01 00:00:00 INFO  request handled ok user=alice path=/api/v1/items status=200 latency_ms=12 "
  block=""
  # Build a ~1 MB block in memory first (fast), then write it 64x per file.
  for n in $(seq 1 8000); do block="${block}${line}"; done
  for i in $(seq 1 16); do
    : > /tmp/bareos-bench/text/file-${i}.log
    for j in $(seq 1 64); do
      printf "%s" "${block}" >> /tmp/bareos-bench/text/file-${i}.log
    done
  done

  # Generate 100 MB of incompressible binary data
  echo "Generating 100 MB binary benchmark data..."
  dd if=/dev/urandom bs=1M count=100 of=/tmp/bareos-bench/binary/random.bin 2>&1
  echo "Benchmark data ready."
  du -sh /tmp/bareos-bench/      # expect ~1.1 GB total
'
```

### Step 2: Create the Benchmark Job

```
# /etc/bareos/bareos-dir.d/fileset/BenchmarkSet.conf
FileSet {
  Name = "BenchmarkSet"
  Include {
    Options {
      Signature = SHA1
      # NO compression for baseline — we add it in Lab 19-2
    }
    # /hostfs prefix: the FD container sees the host at /hostfs (Chapter 6)
    File = /hostfs/tmp/bareos-bench
  }
}
```

```
# /etc/bareos/bareos-dir.d/job/BenchmarkJob.conf
Job {
  Name = "BenchmarkJob"
  Type = Backup
  Level = Full
  Client = bareos-fd
  FileSet = "BenchmarkSet"
  Storage = File          # the Storage resource defined in Chapter 6
  Pool = Default
  Messages = Standard
  # No Schedule — run manually from bconsole
}
```

### Step 3: Run the Baseline Backup

```bash
# In one terminal, start monitoring
iostat -xz 1 > /tmp/iostat-baseline.log &
IOSTAT_PID=$!

# In another terminal, run the backup
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
run job=BenchmarkJob yes
wait
list jobs
EOF
'

# Stop monitoring
kill $IOSTAT_PID
```

### Step 4: Extract Throughput Metrics

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
list jobs
EOF
'

# Find the benchmark job's ID and record:
# - jobbytes (bytes backed up)
# - realstarttime and realendtime (job duration)
# Calculate: throughput = jobbytes / duration_seconds / 1048576 MB/s

# Also check disk I/O during the job:
grep -A2 "sda\|nvme" /tmp/iostat-baseline.log | head -20

# Record your baseline in the performance log
cat >> /home/bareos/.config/bareos/performance-log.txt << EOF
Date: $(date)
Test: Lab 19-1 Baseline
Compression: None
Spooling: Disabled
Notes: Baseline measurement before tuning
EOF
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 19. Lab 19-2: Enable LZ4 Compression and Measure Improvement

**Objective**: Enable LZ4 compression on the BenchmarkSet and compare throughput and volume size against the baseline.

### Step 1: Update the FileSet to Use LZ4

```bash
# Edit the BenchmarkSet FileSet to add LZ4 compression
# (the Director config lives in the host directory /etc/bareos/bareos-dir.d)
sudo tee /etc/bareos/bareos-dir.d/fileset/BenchmarkSet.conf > /dev/null << EOF
FileSet {
  Name = "BenchmarkSet"
  Include {
    Options {
      Signature = SHA1
      Compression = LZ4       # Enable LZ4 compression
      NoAtime = yes           # Do not update file access times during backup
    }
    File = /hostfs/tmp/bareos-bench
  }
}
EOF
```

### Step 2: Reload the Director and Run the Benchmark Again

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  # Reload Director configuration
  podman exec bareos-director bconsole <<EOF
reload
EOF
'

# Start I/O monitoring
iostat -xz 1 > /tmp/iostat-lz4.log &
IOSTAT_PID=$!

# Run the backup
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
run job=BenchmarkJob level=Full yes
wait
list jobs
EOF
'

kill $IOSTAT_PID
```

### Step 3: Compare Results

```bash
# Get job stats for both runs from bconsole
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
list jobs
EOF
'

# Compare:
# 1. jobbytes: total bytes sent over the network (lower = more compression)
# 2. job duration: time from start to finish
# 3. Throughput (MB/s)

# Also compare volume file sizes on disk:
ls -la /srv/bareos-storage/volumes/Default-* | tail -5

# Record results
cat >> /home/bareos/.config/bareos/performance-log.txt << EOF
Date: $(date)
Test: Lab 19-2 LZ4 Compression
Compression: LZ4
Notes: Compare jobbytes and volume size vs baseline
EOF
```

**Expected results**:
- Text data: 30–60% smaller volume files, slightly faster backup (less data to transfer)
- Binary/random data: similar or slightly larger volume files, similar throughput
- CPU usage: minimal increase (LZ4 is very fast)

---

[↑ Back to Table of Contents](#table-of-contents)

## 20. Lab 19-3: Configure Spooling and Measure Improvement

**Objective**: Enable data spooling and attribute spooling on a single
disk-to-disk job and measure what each actually does. The goal here is to
*correct a common misconception*: for a single disk-to-disk job, data
spooling does not shorten the job — de-spooling happens before the job ends,
so `wait` already includes it. You should expect data spooling to be neutral
or slightly slower, while `Spool Attributes = yes` is what actually trims the
catalog-update phase.

### Step 1: Create the Spool Directory

```bash
# Create the spool directory (simulate a fast SSD as a separate path)
sudo mkdir -p /srv/bareos-spool
sudo chown bareos:bareos /srv/bareos-spool
sudo chmod 750 /srv/bareos-spool

# Apply SELinux context
sudo semanage fcontext -a -t container_file_t "/srv/bareos-spool(/.*)?"
sudo restorecon -Rv /srv/bareos-spool/

# Verify
ls -laZ /srv/bareos-spool/
```

### Step 2: Update the Storage Daemon Configuration

```bash
# Update the Device resource to add spooling
# (the SD config lives in the host directory /etc/bareos/bareos-sd.d)
sudo tee /etc/bareos/bareos-sd.d/device/FileStorage.conf > /dev/null << EOF
Device {
  Name = FileStorage
  DeviceType = File
  MediaType = File
  ArchiveDevice = /var/lib/bareos/storage

  # Enable spooling: job data is written to the fast spool directory first,
  # then de-spooled to the final storage location as part of the job.
  Spool Directory = /var/lib/bareos/spool

  Maximum Block Size = 1048576
  Maximum Concurrent Jobs = 4
  Always Open = yes
}
EOF
```

### Step 3: Update the Quadlet to Mount the Spool Directory

```bash
# Update the bareos-storage.container Quadlet to mount the spool directory
QUADLET_FILE="/home/bareos/.config/containers/systemd/bareos-storage.container"

# Add the spool volume mount (if not already present)
sudo -u bareos bash -c "
  if ! grep -q bareos-spool '${QUADLET_FILE}'; then
    sed -i '/^Volume=.*storage:z/a Volume=/srv/bareos-spool:/var/lib/bareos/spool:z' '${QUADLET_FILE}'
    echo 'Added spool volume mount to Quadlet.'
  else
    echo 'Spool mount already present.'
  fi
"
```

### Step 4: Update the Job to Enable Spooling

```bash
# (the Director config lives in the host directory /etc/bareos/bareos-dir.d)
sudo tee /etc/bareos/bareos-dir.d/job/BenchmarkJob.conf > /dev/null << EOF
Job {
  Name = "BenchmarkJob"
  Type = Backup
  Level = Full
  Client = bareos-fd
  FileSet = "BenchmarkSet"
  Storage = File          # the Storage resource defined in Chapter 6
  Pool = Default
  Messages = Standard

  # Spool Attributes batches the catalog inserts — this is the part that
  # genuinely helps a disk-to-disk job with many files.
  Spool Attributes = yes

  # Spool Data is included here so you can OBSERVE its effect. For this
  # single-job disk-to-disk benchmark expect it to be neutral or slightly
  # slower (extra write + read, and de-spool happens before the job ends).
  Spool Data = yes
  Spool Size = 10G
}
EOF
```

### Step 5: Restart Services and Run the Benchmark

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload
  systemctl --user restart bareos-storage.service
  sleep 5
  podman exec bareos-director bconsole <<EOF
reload
EOF
'

# Run the spooled backup
time sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
run job=BenchmarkJob level=Full yes
wait
list jobs
EOF
'
```

### Step 6: Compare (and interpret honestly)

Compare the `time` wall-clock for the `run` + `wait` sequence against your
baseline (Lab 19-1). For this **single job writing to disk**, do **not**
expect data spooling to be faster:

- De-spooling runs **inside** the job. The job is not reported terminated —
  and `wait` does not return — until the spool has been flushed to the final
  volume. So the `run` + `wait` time *includes* the de-spool. There is no
  "finish early, de-spool in the background" effect for a single disk job.
- Because the data is written twice (to spool, then to volume) and read back
  once, the total time is typically **equal to or slightly longer** than the
  no-spool baseline. If your spool and final volume share the same physical
  disk, expect it to be slower.

Check the job log for the two phases — you will see the data phase, then a
separate de-spool ("Committing spooled data") phase, then attribute spooling:

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<EOF
list joblog jobid=<the-benchmark-jobid>
EOF
'
# Look for: "Spooling data ...", "Committing spooled data to Volume ...",
# and a final attribute-insert/"Sending spooled attrs" line.

# Where spooling DOES help on disk-to-disk: the catalog phase.
# With Spool Attributes = yes the file records are batch-inserted at the end
# instead of trickling in, which shortens the time a many-file job spends
# "finishing". To see the data-spool benefit for real, you would write to
# TAPE, or run several BenchmarkJob copies concurrently and observe that each
# job's blocks stay contiguous on the volume (better restore performance).

# Record results
cat >> /home/bareos/.config/bareos/performance-log.txt << EOF
Date: $(date)
Test: Lab 19-3 Spooling Enabled
Spooling: Data + Attributes (spool to /srv/bareos-spool)
Notes: Expect data-spool neutral/slower for single disk job; attr spooling
       trims the catalog phase. Compare run+wait time vs Lab 19-1 baseline.
EOF

# Check spool usage after the job
ls -la /srv/bareos-spool/
# The spool files should be gone (de-spooled into the final volume already,
# since de-spooling completed before the job — and "wait" — returned).
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 21. Summary

Performance tuning Bareos is a systematic process: measure first, identify the bottleneck, apply a targeted change, measure again. In this chapter you learned:

- **Identify the bottleneck** before tuning. Check CPU, disk I/O, network, and catalog (MariaDB) to find which is limiting throughput. Tuning the wrong resource wastes time.
- **Maximum Concurrent Jobs** must be raised on the Director, Storage Daemon, and each File Daemon. All three gates must be open for parallel jobs to work.
- **LZ4 compression** is the best default: extremely fast, low CPU overhead, meaningful space savings on text and log data. Use GZIP only for archival where maximum compression ratio matters more than speed.
- **FileSet options** — `Sparse`, `NoAtime`, `CheckFileChanges` — have immediate impact on backup time with no infrastructure changes required.
- **MaximumBlockSize = 1 MB** on the Storage Daemon Device resource dramatically improves sequential write throughput on spinning HDDs.
- **Data spooling** primarily benefits tape (it keeps the drive streaming and avoids shoe-shining) and interleaving concurrent jobs onto one device (it keeps each job contiguous). For a single disk-to-disk job it adds an extra write + read and de-spools before the job ends, so it is usually neutral or slightly slower — not a speed-up. The spooling knob that *does* reliably help disk-to-disk is **`Spool Attributes = yes`**, which batches catalog inserts and shortens the catalog-update phase.
- **cgroup v2 resource limits** in Quadlet files protect other workloads on shared hosts without requiring any kernel-level changes — `Memory=`, `MemorySwap=` (subject to the rootless swap-delegation caveat), and the cgroup-v2-native `CPUWeight=` are all you need.
- **MariaDB tuning** — `innodb_buffer_pool_size`, `innodb_flush_log_at_trx_commit = 2`, and `innodb_log_file_size` — transforms catalog update performance for jobs with millions of files.
- **Auto-labeling** (`AutoLabel = File` in the Pool) eliminates manual intervention and backup window interruptions caused by unlabeled volumes.
- **TCP buffer tuning** (host sysctls), the Bareos-level `Maximum Network Buffer Size` on both FD and SD, and optionally jumbo frames improve network throughput for large backup streams across a LAN.

The three labs give you a repeatable measurement framework. Run Lab 19-1 first, record the baseline, then apply each optimization from subsequent sections and re-run the benchmark. Keep the performance log updated — after six months of incremental tuning, you will have a clear record of what worked, what did not, and by how much.

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
