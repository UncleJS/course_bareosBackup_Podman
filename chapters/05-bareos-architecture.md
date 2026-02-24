# Chapter 5: Bareos Architecture Deep Dive

## Table of Contents

- [1. The Three-Daemon Architecture](#1-the-three-daemon-architecture)
- [2. The Bareos Director](#2-the-bareos-director)
  - [What the Director Does](#what-the-director-does)
  - [Director Configuration File](#director-configuration-file)
- [3. The Bareos Storage Daemon](#3-the-bareos-storage-daemon)
  - [What the Storage Daemon Does](#what-the-storage-daemon-does)
  - [Storage Daemon Configuration](#storage-daemon-configuration)
  - [Volume File Format](#volume-file-format)
- [4. The Bareos File Daemon](#4-the-bareos-file-daemon)
  - [What the File Daemon Does](#what-the-file-daemon-does)
  - [File Daemon Installation](#file-daemon-installation)
- [5. The Bareos Catalog](#5-the-bareos-catalog)
  - [What the Catalog Stores](#what-the-catalog-stores)
  - [Catalog Database Choice](#catalog-database-choice)
  - [Catalog Schema Overview](#catalog-schema-overview)
  - [Protecting the Catalog](#protecting-the-catalog)
- [6. Bareos Console: bconsole and WebUI](#6-bareos-console-bconsole-and-webui)
  - [bconsole](#bconsole)
  - [Bareos WebUI](#bareos-webui)
- [7. Communication Flow: What Happens During a Backup](#7-communication-flow-what-happens-during-a-backup)
- [8. Communication Flow: What Happens During a Restore](#8-communication-flow-what-happens-during-a-restore)
- [9. Configuration File Structure](#9-configuration-file-structure)
  - [Resource Syntax](#resource-syntax)
  - [Configuration Validation](#configuration-validation)
- [10. Resource Definitions: The Building Blocks](#10-resource-definitions-the-building-blocks)
  - [Director Resource](#director-resource)
  - [Client Resource (File Daemon reference)](#client-resource-file-daemon-reference)
  - [Storage Resource (Storage Daemon reference)](#storage-resource-storage-daemon-reference)
  - [Pool Resource](#pool-resource)
  - [FileSet Resource](#fileset-resource)
  - [Schedule Resource](#schedule-resource)
  - [Job Resource](#job-resource)
  - [JobDefs Resource](#jobdefs-resource)
  - [Messages Resource](#messages-resource)
  - [Catalog Resource](#catalog-resource)
- [11. Authentication Between Daemons](#11-authentication-between-daemons)
  - [Password Matrix](#password-matrix)
  - [TLS Authentication (Chapter 15)](#tls-authentication-chapter-15)
- [12. Bareos Plugins Architecture](#12-bareos-plugins-architecture)
  - [File Daemon Plugins](#file-daemon-plugins)
  - [Storage Daemon Plugins](#storage-daemon-plugins)
  - [Installing Plugins](#installing-plugins)
- [13. Lab 5-1: Mapping the Architecture to Your Deployment](#13-lab-5-1-mapping-the-architecture-to-your-deployment)
- [14. Summary](#14-summary)

## 1. The Three-Daemon Architecture

Bareos is built around three cooperating daemons. Understanding what each does — and why it is a separate process — is the key to understanding every configuration file you will ever write.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Bareos Architecture Overview                     │
│                                                                     │
│  ┌──────────────────────────────────────────┐                      │
│  │            Bareos Director (bareos-dir)  │                      │
│  │                                          │                      │
│  │  • Orchestration brain                   │                      │
│  │  • Reads all configuration               │                      │
│  │  • Manages the job queue                 │                      │
│  │  • Writes to the Catalog                 │  Port 9101           │
│  │  • Accepts bconsole connections          │◄──── Operators       │
│  └────────────────┬───────────────┬─────────┘                      │
│                   │               │                                 │
│              Port 9102       Port 9103                              │
│                   │               │                                 │
│                   ▼               ▼                                 │
│  ┌────────────────────┐  ┌─────────────────────┐                  │
│  │  Bareos File       │  │  Bareos Storage      │                  │
│  │  Daemon (FD)       │  │  Daemon (SD)         │                  │
│  │  bareos-fd         │  │  bareos-sd           │                  │
│  │                    │  │                      │                  │
│  │  • Reads files     │──►  • Writes Volumes    │                  │
│  │    from client     │  │  • Labels Volumes    │                  │
│  │  • Sends to SD     │  │  • Manages pools     │                  │
│  │  • Runs scripts    │  │  • Reads for restore │                  │
│  └────────────────────┘  └──────────────────────┘                  │
│                                                                     │
│  ┌─────────────────────────────────────────────┐                   │
│  │         Bareos Catalog (MariaDB)             │                  │
│  │                                              │                  │
│  │  • Every file backed up → recorded here      │                  │
│  │  • Volume inventory                          │                  │
│  │  • Job history                               │                  │
│  │  • Pool and storage definitions              │                  │
│  └─────────────────────────────────────────────-┘                  │
└─────────────────────────────────────────────────────────────────────┘
```

The three daemons can run:
- All on the same host (our setup in this course)
- Director + Storage on one host, File Daemons on many client hosts
- Director on one host, multiple Storage Daemons on different hosts (distributed storage)
- Completely separated (Director, Storage, and File Daemons each on different hosts)

This flexibility is what makes Bareos scale from a single-server home lab to multi-site enterprise deployments.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. The Bareos Director

The Director (`bareos-dir`) is the central orchestration service. It is the only daemon that communicates with all other components. It never directly reads files from clients, and it never directly writes backup data — those responsibilities belong to the File Daemon and Storage Daemon respectively.

### What the Director Does

**Job scheduling:** The Director has an internal scheduler that triggers Jobs based on their Schedule definition. When a scheduled trigger fires, the Director:
1. Looks up the Job definition
2. Identifies the client (File Daemon address and port)
3. Identifies the Storage Daemon and Pool
4. Allocates a Volume from the Pool
5. Dispatches the job by contacting the File Daemon and Storage Daemon

**Catalog management:** Every significant event is recorded in the Catalog:
- Job start/end times and status
- Every file backed up (path, size, checksum, modification time, Volume location)
- Volume usage (how much data is on each Volume)
- Pool state (which Volumes are full, expired, or available)

**Access control:** The Director manages Console connections. Operators connect to the Director via `bconsole` or the WebUI. The Director enforces ACLs — an operator might have read-only access to job status, while another has full administrative access.

**Pruning and recycling:** The Director enforces retention policies. It periodically:
- Prunes expired Job and File records from the Catalog
- Marks expired Volumes as "Purged" (eligible for recycling)
- Recycles Purged Volumes back into the Pool for new data

### Director Configuration File

The Director's main configuration is `/etc/bareos/bareos-dir.conf` (or the include directory `/etc/bareos/bareos-dir.d/`). The modern Bareos default uses a split-directory structure:

```
/etc/bareos/bareos-dir.d/
├── catalog/
│   └── MyCatalog.conf          ← Catalog resource (MariaDB connection)
├── client/
│   └── bareos-fd.conf          ← File Daemon definitions (one per client)
├── console/
│   └── bareos-mon.conf         ← Console access definitions
├── director/
│   └── bareos-dir.conf         ← Director's own identity and global settings
├── fileset/
│   └── LinuxAll.conf           ← FileSet definitions (what to back up)
├── job/
│   ├── BackupClient1.conf      ← Job definitions
│   └── RestoreFiles.conf       ← Restore job template
├── jobdefs/
│   └── DefaultJob.conf         ← Shared job settings templates
├── messages/
│   └── Daemon.conf             ← Logging and email alert config
├── pool/
│   ├── Full.conf               ← Pool definitions
│   ├── Incremental.conf
│   └── Differential.conf
├── profile/
│   └── operator.conf           ← Console operator profiles
├── schedule/
│   └── WeeklyCycle.conf        ← Backup schedule definitions
└── storage/
    └── File.conf               ← Storage Daemon connection definitions
```

This split structure is the default on Bareos 23+. Each resource type lives in its own subdirectory. Bareos reads all `.conf` files in all subdirectories automatically.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. The Bareos Storage Daemon

The Storage Daemon (`bareos-sd`) is responsible for one thing: reading and writing backup data to storage media. It knows nothing about which files came from where — it simply receives a stream of data from the File Daemon and writes it to a Volume.

### What the Storage Daemon Does

**Volume management:** The Storage Daemon maintains a catalog of Volumes (the actual backup files on disk or tape). It:
- Labels new Volumes with Bareos-format headers
- Appends new backup streams to existing Volumes
- Tracks how much space is used on each Volume
- Reads Volume data back during restores

**Storage Device abstraction:** The Storage Daemon can write to many types of storage:
- **File devices**: Ordinary files on a filesystem (our primary use case)
- **Tape devices**: Physical tape drives (LTO, etc.)
- **Cloud storage**: S3-compatible object storage (requires plugin)
- **Dedup devices**: Bareos deduplication store
- **Autochanger**: Tape library with robotic arm

**Concurrent operations:** The Storage Daemon supports multiple simultaneous data streams (configurable with `Maximum Concurrent Jobs`). This allows multiple File Daemons to back up to the same Storage Daemon simultaneously, each writing to their own Volume.

### Storage Daemon Configuration

```
/etc/bareos/bareos-sd.d/
├── device/
│   └── FileStorage.conf        ← Storage Device definitions (where to write)
├── director/
│   └── bareos-dir.conf         ← Authorizes the Director to connect to this SD
├── messages/
│   └── Daemon.conf
└── storage/
    └── bareos-sd.conf          ← Storage Daemon identity
```

### Volume File Format

A Bareos Volume is not a special filesystem or proprietary format — it is a regular file (or tape) with a Bareos-defined structure:

```
┌─────────────────────────────────────────┐
│  Volume Header                          │
│  (Volume name, creation date, pool)     │
├─────────────────────────────────────────┤
│  Block 1                                │
│  ├── Block Header (checksum, length)    │
│  └── Record 1 (file data, attributes)  │
├─────────────────────────────────────────┤
│  Block 2                                │
│  └── Records (more file data)          │
├─────────────────────────────────────────┤
│  ...                                    │
├─────────────────────────────────────────┤
│  End-of-Volume marker                   │
└─────────────────────────────────────────┘
```

This format is designed for sequential access — ideal for tape, and efficient for spinning disk. For fast random-access restores, the Catalog provides the offset within the Volume where each file's data begins.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. The Bareos File Daemon

The File Daemon (`bareos-fd`) runs on every client machine that Bareos backs up. It is the component closest to the data.

### What the File Daemon Does

**File system traversal:** When a backup job runs, the Director tells the File Daemon to start a backup. The File Daemon traverses the FileSet (the list of directories to include/exclude), reads each file, computes checksums, records attributes (owner, permissions, timestamps, ACLs, xattrs), and streams the data to the Storage Daemon.

**Change detection:** For Incremental and Differential backups, the File Daemon compares file modification times (and optionally checksums) against the previous backup records from the Catalog. Only changed files are sent.

**Restore reception:** During a restore, the data flow reverses: the File Daemon receives data from the Storage Daemon and writes it to the local filesystem.

**Script execution:** The File Daemon executes `ClientRunBeforeJob` and `ClientRunAfterJob` scripts on the client, enabling database dumps, snapshots, and other pre/post-backup operations.

**Plugin support:** File Daemon plugins extend what Bareos can back up: MariaDB hot backups, PostgreSQL, LDAP, VMware, etc.

### File Daemon Deployment

In this course, the File Daemon runs as a **Podman container** (`bareos-client:24`) on the same host as the Director and Storage Daemon. It is managed by a Quadlet unit (`bareos-fd.container`) like every other Bareos component. The host filesystem is bind-mounted read-only at `/hostfs` inside the container, so FileSet paths use the `/hostfs/` prefix (e.g. `File = /hostfs/home`).

For backing up **remote client machines** (bare-metal servers, VMs, other Linux hosts), you would install the File Daemon via RPM on that client instead:

```bash
# On a remote RHEL 10 client — not needed for the course lab
sudo dnf install bareos-filedaemon

# Configuration
sudo vim /etc/bareos/bareos-fd.d/client/myself.conf
sudo vim /etc/bareos/bareos-fd.d/director/bareos-dir.conf

# Enable and start
sudo systemctl enable --now bareos-fd
```

The File Daemon only has two configuration concerns:
1. Its own identity (name, port, TLS settings)
2. Which Directors are authorized to connect to it (by name + password)

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. The Bareos Catalog

The Catalog is a relational database that serves as the index and inventory of everything Bareos has backed up. Without the Catalog, Bareos cannot perform selective restores efficiently (though it can laboriously re-read Volumes with `bscan` to rebuild it).

### What the Catalog Stores

**File records:** For every file backed up, the Catalog records:
- Full path and filename
- File size, owner, permissions, timestamps
- MD5/SHA1/SHA256 checksum
- Which Job backed it up
- Which Volume it lives on and at what byte offset

**Job records:** Start time, end time, job level (Full/Incremental/Differential), bytes transferred, files backed up, status (OK/Failed/Warning), and the client and Storage Daemon used.

**Volume records:** Volume name, Pool, status (Append/Full/Used/Purged/Recycled), creation date, last write date, bytes used, number of files, expiration date.

**Pool records:** Pool name, settings (retention periods, volume size limits, label format, recycle policy).

**Client records:** Client name, address, last backup time.

### Catalog Database Choice

Bareos supports:
- **MariaDB / MySQL** — our choice; best performance, most features
- **PostgreSQL** — excellent alternative, slightly more complex setup
- **SQLite** — only for testing; never use in production (locks under concurrent access)

MariaDB is preferred because:
- It is the default in RHEL 10 / Bareos documentation
- Bareos's included `bareos_catalog_backup.sh` script is optimized for MariaDB
- Performance is excellent for Catalog query patterns (sequential job writes, random file lookups)

### Catalog Schema Overview

The Catalog has approximately 20 tables. The most important:

| Table | Contents |
|---|---|
| `Job` | One row per backup/restore job |
| `File` | One row per file backed up (can be billions of rows) |
| `Filename` | Deduplicated filenames (avoid storing the same path string billions of times) |
| `Path` | Deduplicated directory paths |
| `JobMedia` | Mapping between Jobs and the Volumes they were written to |
| `Media` | One row per Volume (Volume inventory) |
| `Pool` | Pool definitions |
| `Client` | Client definitions |
| `Storage` | Storage Daemon definitions |
| `FileSet` | FileSet snapshots (the exact include/exclude state at backup time) |

The `File` table grows at approximately 1 row per backed-up file per job. For a client with 1 million files running daily incremental backups, the `File` table grows by roughly 10,000–100,000 rows per day (depending on the change rate). After a year, this can be tens or hundreds of millions of rows — MariaDB handles this well with proper indexing.

### Protecting the Catalog

The Catalog must be backed up. Bareos includes a built-in `BackupCatalog` job that:
1. Runs after all regular backup jobs complete
2. Dumps the MariaDB catalog to a file using `mysqldump` / `mariadb-dump`
3. Backs up that dump file to a Bareos Volume

Without a recent catalog backup:
- You cannot perform selective file restores
- Volume recycle decisions are lost (Volumes may be incorrectly reused)
- Job history is gone

We configure this in [Chapter 7](./07-first-backup-job.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Bareos Console: bconsole and WebUI

Operators interact with the Director through one of two interfaces.

### bconsole

`bconsole` is the command-line text interface. It connects to the Director on port 9101 and provides an interactive prompt for all Bareos operations.

```bash
# Connect to the local Director
bconsole

# Connect to a remote Director
bconsole -c /etc/bareos/bconsole.conf

# Non-interactive (single command)
echo "status director" | bconsole
```

Once connected:
```
Connecting to Director localhost:9101
1000 OK: bareos-dir Version: 24.0.0 (01 Jan 2025)
Enter a period to cancel a command.
*                           ← the bconsole prompt

*help                       ← list all commands
*status director            ← Director status
*status storage             ← Storage Daemon status
*status client              ← File Daemon status
*list jobs                  ← list recent jobs
*run                        ← run a job interactively
*restore                    ← start the restore wizard
*cancel jobid=42            ← cancel a running job
*label volume=Vol-001 pool=Full storage=File  ← label a new Volume
*quit                       ← exit
```

We use `bconsole` extensively throughout this course. It is the primary operational tool for Bareos.

### Bareos WebUI

The WebUI is a PHP-based web application that provides a graphical interface for job monitoring, restore operations, and day-to-day Bareos management. It connects to the Director's console API (port 9101) using a dedicated `Console` resource — exactly the same mechanism as `bconsole`, just over HTTP instead of a terminal.

```
Browser → bareos-webui (PHP/Apache inside container)
                ↓  port 9101
          Bareos Director
                ↓
          Catalog (MariaDB)
```

**Features:**
- Dashboard with live and historical job status
- Job run history, statistics, and log viewer
- Interactive file-tree browser for restore selection
- Volume, Pool, and Storage management
- Client and Schedule enable/disable
- Multi-Director support (connect to several Directors from one UI)

**Deployment model in this course:**

In keeping with the Podman-first approach of this course, the WebUI is deployed as a **rootless Podman container** managed by a Quadlet unit — not installed as an RPM with Apache on the host. The container image is:

```
docker.io/bareos/bareos-webui:24
```

It embeds Apache + PHP-FPM and exposes port 80 inside the container, which is mapped to `127.0.0.1:9100` on the host. An optional nginx reverse proxy in front adds HTTPS for remote access.

The WebUI requires:
1. A `Console` resource in the Director config with a dedicated password and the `webui-admin` profile.
2. A `directors.ini` configuration file inside the container that tells the WebUI how to reach the Director.
3. SELinux: no additional booleans needed because the WebUI runs inside a container that already has network access to the Director container via a shared Podman network.

> **Full installation walkthrough:** See [Chapter 17 — Monitoring and Alerting](17-monitoring-alerts.md), Section 6 and Lab 17-2 for the complete step-by-step Quadlet deployment with all configuration files.

> **Note:** This course teaches `bconsole` first because it works in any environment, reveals the underlying concepts directly, and is essential for scripting and automation. Once you are comfortable with `bconsole`, the WebUI's features are immediately intuitive.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Communication Flow: What Happens During a Backup

Understanding the exact sequence of events in a backup job is essential for troubleshooting. Let's trace a complete backup job:

```
Timeline of a Full Backup Job

T+0s   Director scheduler fires (or operator runs job manually)
       Director: "It's time to run BackupClient1"

T+1s   Director looks up the Job resource configuration
       Director: "Client = linux-host, Storage = File, Pool = Full"

T+2s   Director queries Catalog: "What was the last backup of linux-host?"
       Catalog returns: "Last Full on 2026-01-15, Job ID 142"

T+3s   Director contacts Storage Daemon on port 9103
       Director → SD: "I need a writable Volume from pool Full"
       SD → Director: "Use Volume Full-0003, currently 45% full"

T+4s   Director contacts File Daemon on port 9102
       Director → FD: "Start backup, send data to SD at 192.168.1.5:9103"
       Director → FD: "Use this FileSet: /home /etc /var/www"
       Director → FD: "Authentication bootstrap for SD: <token>"

T+5s   File Daemon connects directly to Storage Daemon on port 9103
       (The Director is NOT in the data path — data flows FD→SD directly)
       FD → SD: "I have data for Job ID 156, Volume Full-0003"

T+6s   File Daemon begins traversing the FileSet
       For each file: read → compress (LZ4) → compute checksum → stream to SD

T+...  Storage Daemon writes data to Volume Full-0003
       Every 30 seconds, SD sends progress to Director
       Director updates Catalog with progress

T+N    File Daemon finishes traversing all files
       FD → Director: "Backup complete. 524,288 files, 15.3 GB"
       FD → SD: "End of data stream"

T+N+1  Storage Daemon finalizes the Volume record
       SD → Director: "Session complete. 15.3 GB written to Full-0003"

T+N+2  Director updates Catalog:
       - Job record: status=OK, files=524288, bytes=15.3GB, end_time=...
       - File records: 524,288 rows inserted (path, name, attrs, Volume offset)
       - Volume record: bytes_used updated

T+N+3  Director runs configured Messages (email, log)
       "Job BackupClient1 completed successfully"

T+N+4  BackupCatalog job fires (if configured after regular backup)
       Dumps MariaDB catalog → backs it up to a Volume
```

**The key insight:** The Director orchestrates but data never flows through it. The **FD and SD communicate directly** for the data transfer. This design means the Director can orchestrate many simultaneous jobs without being a data bottleneck.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Communication Flow: What Happens During a Restore

```
Timeline of a Restore Job

T+0s   Operator runs: bconsole → restore

T+1s   Director prompts: "What do you want to restore?"
       Operator selects: "Files from BackupClient1, most recent backup"

T+2s   Director queries Catalog: "Which Job(s) contain the selected files?"
       Catalog returns: "Job 142 (Full), Job 150 (Incremental)"
       For incremental restores, Director selects the most recent version
       of each file across the job chain

T+3s   Director queries Catalog: "Which Volumes contain those jobs?"
       Catalog returns: "Full-0002 contains Job 142, Inc-0005 contains Job 150"

T+4s   Director contacts Storage Daemon:
       "Read from Volume Full-0002, then Inc-0005"
       "Send data to FD at 192.168.1.10:9102"

T+5s   Storage Daemon locates Volume files on disk
       SD opens Full-0002 and seeks to the offset for Job 142
       (The Catalog's byte offsets make this a direct seek, not a full scan)

T+6s   File Daemon receives connection from Storage Daemon
       FD is told: "Write restored files to /tmp/bareos-restores/ "
       (Or the original path, depending on restore options)

T+7s   Data flows: SD reads from Volume → FD writes to restore path
       FD verifies checksums as it writes
       FD restores file permissions, ownership, timestamps, ACLs

T+N    Restore complete
       Director updates Catalog with Restore job record
       Operator verifies restored files
```

**Restore to original path:** The FD writes directly to the original file paths, overwriting existing files. Use with caution — always restore to a temporary directory first to verify.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Configuration File Structure

Every Bareos configuration, across all three daemons, uses the same syntax: **resources**.

### Resource Syntax

```bareos
ResourceType {
  Name = "ResourceName"
  Directive1 = value
  Directive2 = "string value"
  Directive3 = Yes
  Directive4 = 30 days
  SubResource {
    SubDirective = value
  }
}
```

Rules:
- Resource names are case-sensitive
- String values are optionally quoted (required if they contain spaces or special characters)
- Boolean values: `Yes`/`No` (or `true`/`false`)
- Time values: `30 days`, `2 hours`, `15 minutes`
- Size values: `500 MB`, `2 GB`, `1 TB`
- Comments start with `#`
- `@/path/to/file` includes another configuration file

### Configuration Validation

Before restarting any daemon, always validate the configuration:

```bash
# Validate Director configuration
bareos-dir -t -c /etc/bareos

# Validate Storage Daemon configuration
bareos-sd -t -c /etc/bareos

# Validate File Daemon configuration
bareos-fd -t -c /etc/bareos
```

A configuration error here is much better than a crash at 2 AM.

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Resource Definitions: The Building Blocks

The Director uses many resource types. Here is the complete taxonomy:

### Director Resource
The Director's own identity:
```bareos
Director {
  Name = bareos-dir
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  Maximum Concurrent Jobs = 10
  Password = "DirectorPassword"  # bconsole uses this
  Messages = Daemon
  Auditing = yes
}
```

### Client Resource (File Daemon reference)
One per backed-up host:
```bareos
Client {
  Name = linux-client
  Address = 192.168.1.10
  FDPort = 9102
  Catalog = MyCatalog
  Password = "ClientPassword"  # must match FD's Director password
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes
}
```

### Storage Resource (Storage Daemon reference)
```bareos
Storage {
  Name = File
  Address = 192.168.1.5
  SDPort = 9103
  Password = "StoragePassword"  # must match SD's Director password
  Device = FileStorage
  Media Type = File
}
```

### Pool Resource
Defines how Volumes are managed:
```bareos
Pool {
  Name = Full
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 31 days
  Maximum Volume Bytes = 10 GB
  Maximum Volumes = 100
  Label Format = "Full-"
}
```

### FileSet Resource
Defines what to back up:
```bareos
FileSet {
  Name = "Linux-Standard"
  Include {
    Options {
      Signature = SHA256
      Compression = LZ4
      OneFs = yes         # don't cross filesystem boundaries
    }
    File = /home
    File = /etc
    File = /var/www
  }
  Exclude {
    File = /proc
    File = /sys
    File = /tmp
    File = /run
  }
}
```

### Schedule Resource
```bareos
Schedule {
  Name = "WeeklyBackup"
  Run = Level=Full        sun at 23:00
  Run = Level=Incremental mon-sat at 23:00
}
```

### Job Resource
Ties everything together:
```bareos
Job {
  Name = "BackupLinuxClient"
  Type = Backup
  Level = Incremental
  Client = linux-client
  FileSet = "Linux-Standard"
  Schedule = "WeeklyBackup"
  Storage = File
  Messages = Standard
  Pool = Incremental
  Full Backup Pool = Full
  Differential Backup Pool = Differential
  Priority = 10
  Write Bootstrap = "/var/lib/bareos/%c.bsr"
}
```

### JobDefs Resource
A template that multiple Jobs can inherit:
```bareos
JobDefs {
  Name = "DefaultJobDef"
  Type = Backup
  Messages = Standard
  Priority = 10
  Write Bootstrap = "/var/lib/bareos/%c.bsr"
}

Job {
  Name = "BackupClient1"
  JobDefs = "DefaultJobDef"  # inherits all DefaultJobDef settings
  Client = client1
  FileSet = "Linux-Standard"
  # override specific settings here
}
```

### Messages Resource
Controls logging and alerting:
```bareos
Messages {
  Name = Standard
  Mail = admin@company.com = all, !skipped, !saved, !audit
  MailOnError = oncall@company.com = all
  Append = "/var/log/bareos/bareos.log" = all, !skipped, !saved, !audit
  Console = all, !skipped, !saved, !audit
}
```

### Catalog Resource
```bareos
Catalog {
  Name = MyCatalog
  DBName = bareos
  DBUser = bareos
  DBPassword = "CatalogPassword"
  DBAddress = 127.0.0.1
  DBPort = 3306
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Authentication Between Daemons

Bareos uses **MD5-challenge-response authentication** between all components. Each connection is authenticated with a shared password configured in both endpoints.

### Password Matrix

| Connection | Password configured in |
|---|---|
| Director → File Daemon | Director's `Client` resource AND FD's `Director` resource |
| Director → Storage Daemon | Director's `Storage` resource AND SD's `Director` resource |
| Console → Director | Director's `Console` resource AND `bconsole.conf` |

**The passwords must match exactly (case-sensitive).** A mismatch results in:
```
Fatal error: Authorization key rejected by File daemon
```

### TLS Authentication (Chapter 15)

In addition to password authentication, Bareos 20+ supports TLS mutual certificate authentication. When TLS is configured, the certificate CN (Common Name) is also verified in addition to the password. We configure this in Chapter 15.

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Bareos Plugins Architecture

Bareos has a rich plugin system for both the File Daemon and the Storage Daemon.

### File Daemon Plugins

FD plugins extend what the File Daemon can back up. Important plugins:

**`python-fd`**: The Python plugin framework. Enables Python scripts to hook into backup events. Used for:
- MariaDB hot backups (using `mariabackup`)
- PostgreSQL backups (using `pg_dump`)
- Custom application integration

**`bareos-filedaemon-mariabackup-python-plugin`**: Hot-backup plugin for MariaDB/MySQL using `mariabackup`. Creates consistent, crash-safe backups without stopping MySQL.

**`bareos-filedaemon-ldap-python-plugin`**: LDAP directory backup plugin.

**`bareos-filedaemon-ovirt-plugin`**: VMware/oVirt virtual machine backup.

### Storage Daemon Plugins

SD plugins extend where data can be written:

**`bareos-storage-droplet`**: Write Volumes to S3-compatible object storage (AWS S3, MinIO, Ceph RadosGW).

**`bareos-storage-glusterfs`**: Write directly to a GlusterFS distributed filesystem.

### Installing Plugins

File Daemon plugins ship **inside the `bareos-client:24` container image** — no separate installation is needed for the course lab. The Python plugin framework and common database plugins are pre-installed.

For remote RPM-based clients you would install plugins separately:

```bash
# File daemon Python plugin framework (remote RPM clients only)
sudo dnf install bareos-filedaemon-python-plugins

# MariaDB hot backup plugin
sudo dnf install bareos-filedaemon-mariabackup-python-plugin

# S3 cloud storage plugin
sudo dnf install bareos-storage-droplet
```

Plugins are loaded via configuration in the daemon's config files. We use the Python FD plugin for database backups in [Chapter 14](./14-database-containers.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Lab 5-1: Mapping the Architecture to Your Deployment

Before writing any configuration, draw a map of your specific deployment. Use this template:

```
=== My Bareos Deployment Architecture ===

Backup Server Host:
  Hostname/IP: _______________________
  Role: Director + Storage Daemon (in containers)

  Container: bareos-director
    Listens: 9101/TCP (bconsole/WebUI)
    Connects to: bareos-storage:9103, bareos-db:3306

  Container: bareos-storage
    Listens: 9103/TCP (File Daemon data streams)
    Volumes directory: /srv/bareos-storage/volumes

  Container: bareos-db (MariaDB)
    Listens: 3306/TCP (internal only, not exposed)
    Data directory: named volume bareos-db-data

  File Daemon (RPM, on backup server itself):
    Listens: 9102/TCP
    Backs up: /etc, /home/bareos, Podman volumes

Client Hosts:
  Client 1:
    Hostname/IP: _______________________
    File Daemon port: 9102
    Data to back up: _______________________

  Client 2:
    Hostname/IP: _______________________
    File Daemon port: 9102
    Data to back up: _______________________

Podman Workloads on Backup Server (to be backed up):
  Container: ___________________
    Named volumes: ___________________
    Bind mounts: ___________________
    DB type (if any): ___________________

Storage:
  Volume storage path: /srv/bareos-storage/volumes
  Available disk space: _________ GB
  Backup storage disk: /dev/sdb1 (XFS, mounted at /srv/bareos-storage)

Schedule:
  RPO target: _______________________
  Backup window: _____________________ (e.g., nightly 23:00-06:00)
  Full backup day: ___________________
  Retention: Full _____ days / Incremental _____ days
```

Fill this in completely before proceeding to Chapter 6. Every value here maps directly to a Bareos configuration directive.

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Summary

In this chapter you learned the complete Bareos architecture:

- **Three daemons**: Director (orchestration), Storage Daemon (data storage), File Daemon (data reading). Each has a single, clear responsibility.
- **The Catalog** (MariaDB) is the brain's memory — without it, selective restores are impossible. Protect it by always running BackupCatalog.
- **Data flows directly FD→SD** during backup; the Director only orchestrates. This allows the Director to manage many simultaneous jobs without being a bottleneck.
- **Configuration is resource-based**: Director, Client, Storage, Pool, FileSet, Schedule, Job, JobDefs, Messages, and Catalog resources compose a complete backup strategy.
- **Passwords must match** on both sides of every connection. Mismatches cause `Authorization key rejected` errors.
- **Plugins extend Bareos**: Python FD plugins for database hot backups, SD plugins for cloud storage.
- **bconsole is the primary operator interface** — learn it before relying on the WebUI.
- The split configuration directory structure (`/etc/bareos/bareos-dir.d/`) separates resource types for maintainability.

---

**Next Chapter:** [Chapter 6: Deploying Bareos in Podman](./06-bareos-in-podman.md)

---

[↑ Back to Table of Contents](#table-of-contents)
