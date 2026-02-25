# Chapter 2: Backup Fundamentals

## Table of Contents

- [1. Why Backups Fail (and How to Not Be a Statistic)](#1-why-backups-fail-and-how-to-not-be-a-statistic)
  - [The Top Causes of Backup Failure](#the-top-causes-of-backup-failure)
- [2. The Backup Triad: RPO, RTO, and Retention](#2-the-backup-triad-rpo-rto-and-retention)
  - [Recovery Point Objective (RPO)](#recovery-point-objective-rpo)
  - [Recovery Time Objective (RTO)](#recovery-time-objective-rto)
  - [Retention](#retention)
- [3. Backup Types: Full, Incremental, and Differential](#3-backup-types-full-incremental-and-differential)
  - [Full Backup](#full-backup)
  - [Incremental Backup](#incremental-backup)
  - [Differential Backup](#differential-backup)
  - [Choosing Between Incremental and Differential](#choosing-between-incremental-and-differential)
- [4. The 3-2-1 Rule and Beyond](#4-the-3-2-1-rule-and-beyond)
  - [The Classic 3-2-1 Rule](#the-classic-3-2-1-rule)
  - [Modern Extensions: 3-2-1-1-0](#modern-extensions-3-2-1-1-0)
  - [Implementing 3-2-1 with Bareos](#implementing-3-2-1-with-bareos)
- [5. Backup Strategies: Choosing the Right Rotation Scheme](#5-backup-strategies-choosing-the-right-rotation-scheme)
  - [Simple Daily Full (for Small Datasets)](#simple-daily-full-for-small-datasets)
  - [Weekly Full + Daily Incremental (Most Common)](#weekly-full-daily-incremental-most-common)
  - [GFS (Grandfather-Father-Son) Rotation](#gfs-grandfather-father-son-rotation)
- [6. What to Back Up: Data Classification](#6-what-to-back-up-data-classification)
  - [Tier 1: Critical — Must Always Be Backed Up](#tier-1-critical-must-always-be-backed-up)
  - [Tier 2: Important — Back Up if Storage Allows](#tier-2-important-back-up-if-storage-allows)
  - [Tier 3: Exclude — Do Not Back Up](#tier-3-exclude-do-not-back-up)
- [7. Consistency: The Silent Enemy of Good Backups](#7-consistency-the-silent-enemy-of-good-backups)
  - [The Problem with Live File Backups](#the-problem-with-live-file-backups)
  - [Solutions](#solutions)
- [8. Encryption and Security Considerations](#8-encryption-and-security-considerations)
  - [In-Transit Encryption](#in-transit-encryption)
  - [At-Rest Encryption](#at-rest-encryption)
  - [Access Control](#access-control)
- [9. Testing Your Backups: Restore Drills](#9-testing-your-backups-restore-drills)
  - [What to Test](#what-to-test)
  - [Documenting Restore Procedures](#documenting-restore-procedures)
- [10. How Bareos Implements These Concepts](#10-how-bareos-implements-these-concepts)
- [11. Lab 2-1: Planning Your Backup Strategy](#11-lab-2-1-planning-your-backup-strategy)
- [12. Summary](#12-summary)

## 1. Why Backups Fail (and How to Not Be a Statistic)

Before learning *how* to configure backups, it is worth understanding *why* backup systems fail in the real world. The uncomfortable truth is that most organizations that lose data had backups — they just did not work when needed.

### The Top Causes of Backup Failure

**1. Backups that were never tested**
A backup that has never been restored is a *theoretical* backup. Tape media degrades. Disk volumes fill up silently. Config changes break job definitions. The only way to know a backup works is to restore from it. Many organizations discover their backups are broken only during a real disaster.

**2. Backup jobs that silently fail**
A scheduled backup job that terminates with an error at 2 AM generates a log entry that nobody reads. Weeks later, the backup catalog is empty or stale. Always configure alerting so failed jobs send notifications.

**3. Backup storage on the same failure domain**
Backing up `/data` to `/backup` on the same disk protects you from accidental deletion but not from disk failure, ransomware, or physical disasters. The backup must live somewhere independent of the source.

**4. Incomplete FileSet definitions**
"We had backups of everything important" — but nobody had audited what "everything" meant. Application data in non-standard paths, database files, container volumes, and configuration files are commonly missed.

**5. Retention misconfiguration**
A retention period set too short means the backup you need — the file that was deleted three months ago — simply does not exist anymore. A retention period set too long means storage fills up and the backup system stops accepting new data.

**6. Catalog loss without a backup of the catalog itself**
The Bareos catalog database contains the index of every file backed up. Without it, you can still retrieve data from Volumes (using `bscan`), but the process is painful and slow. Always back up the catalog.

This course addresses every one of these failure modes explicitly.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. The Backup Triad: RPO, RTO, and Retention

These three concepts form the foundation of any backup strategy. Get them wrong, and your backup system is technically functional but practically useless.

### Recovery Point Objective (RPO)

**RPO** answers: *"How much data can we afford to lose?"*

If your RPO is 24 hours, you are accepting that in the worst case, you might lose up to 24 hours of changes. This drives your **backup frequency**:

| RPO | Minimum backup frequency |
|---|---|
| 24 hours | Daily backups |
| 4 hours | Every 4-hour incremental |
| 1 hour | Hourly incremental |
| Near-zero | Continuous replication (not a backup — a replica) |

A common mistake is confusing replication with backup. A replica (database replication, DRBD, ZFS send/receive) copies data changes in near-real-time — but it also replicates corruption and deletions in near-real-time. You need *both* replication for high availability *and* backups for point-in-time recovery.

### Recovery Time Objective (RTO)

**RTO** answers: *"How quickly must we be able to restore?"*

If your RTO is 4 hours, your entire restore procedure — including locating the backup, running the restore job, verifying data integrity, and restarting services — must complete in under 4 hours. This drives decisions about:

- **Restore speed**: Large datasets on slow backup media may not meet a tight RTO.
- **Catalog availability**: A lost catalog means slow manual recovery; always protect the catalog.
- **Automation**: Manual restore procedures are slower and more error-prone than scripted ones.
- **Restore destination**: Restoring to a standby server is faster than rebuilding the primary.

### Retention

**Retention** answers: *"How far back can we restore from?"*

Retention is driven by business requirements:
- **Ransomware recovery**: You may not notice ransomware for weeks. A 90-day retention lets you recover to a clean point before encryption began.
- **Compliance**: Some regulations (HIPAA, PCI-DSS, GDPR) require data retention for specific periods (1–7 years).
- **"What did this file look like last month?"**: Developers and users regularly need older versions of files.

In Bareos, retention is configured at multiple levels:
- **File Retention**: How long individual file records are kept in the Catalog.
- **Job Retention**: How long job records are kept in the Catalog.
- **Volume Retention**: How long a Volume (the actual backup data) is kept before being eligible for recycling.

> **Key insight:** Catalog retention and Volume retention are independent. You can prune Catalog records (to keep the database small) while retaining the actual data on the Volume.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Backup Types: Full, Incremental, and Differential

Understanding backup types is fundamental — they directly affect storage consumption, backup duration, and restore complexity.

### Full Backup

A **Full backup** copies *every file* in the FileSet, regardless of when it was last modified.

```
Day 1:  Full backup  ──► Volume-Full-01  (contains: file-A, file-B, file-C, file-D)
                          Storage: 100 GB
                          Duration: 2 hours
```

**Pros:**
- Self-contained: restore requires only this one backup
- Fastest restore (single source)
- Simple to reason about

**Cons:**
- Slowest to run (reads and writes everything)
- Most storage-intensive (stores unchanged files repeatedly)
- Network-intensive (all data traverses the backup network)

For most environments, a full backup is run **weekly** or **monthly**, with faster backup types filling in between.

### Incremental Backup

An **Incremental backup** copies only files that have changed since the **last backup of any type** (full *or* incremental).

```
Day 1:  Full backup       ──► Vol-Full-01    (A, B, C, D)       100 GB
Day 2:  Incremental       ──► Vol-Inc-02     (B changed)         2 GB
Day 3:  Incremental       ──► Vol-Inc-03     (A, D changed)      5 GB
Day 4:  Incremental       ──► Vol-Inc-04     (C changed)         1 GB
```

To restore the state as of Day 4, Bareos must apply:
`Full (Day 1)` + `Inc (Day 2)` + `Inc (Day 3)` + `Inc (Day 4)`

**Pros:**
- Very fast backups (only changed files)
- Minimal storage per backup window
- Low network overhead

**Cons:**
- Restore requires the full chain: all incrementals since the last full must be available
- More complex restore process
- A broken link in the chain (missing incremental) can make later restores impossible

How does Bareos know a file changed? It uses a combination of:
1. **Modification time (mtime)**: If mtime is newer than the last backup, the file is included.
2. **Checksum**: For higher accuracy, file checksums can be compared (slower but more reliable — catches files where content changed but mtime was manipulated).
3. **Accurate mode**: Bareos's "Accurate" job option maintains a per-file database between runs for precise change detection.

### Differential Backup

A **Differential backup** copies all files that have changed since the **last Full backup** (not since the last backup of any type).

```
Day 1:  Full backup       ──► Vol-Full-01    (A, B, C, D)       100 GB
Day 2:  Differential      ──► Vol-Diff-02    (B)                  2 GB
Day 3:  Differential      ──► Vol-Diff-03    (B, A, D)            7 GB
Day 4:  Differential      ──► Vol-Diff-04    (B, A, D, C)         8 GB
```

To restore as of Day 4: `Full (Day 1)` + `Diff (Day 4)` — only two pieces.

**Pros:**
- Faster restore than incremental (only two backup sets needed)
- Simpler restore chain

**Cons:**
- Grows larger each day (re-copies all changes since the last full)
- More storage than incremental

### Choosing Between Incremental and Differential

| Consideration | Prefer Incremental | Prefer Differential |
|---|---|---|
| Storage is expensive | ✓ | |
| Restore speed is critical | | ✓ |
| RTO is very tight | | ✓ |
| Many files change daily | ✓ | |
| Few files change but they're large | | ✓ |

In practice, a **hybrid schedule** is most common:
- Weekly Full on Sunday night
- Daily Differential or Incremental Mon–Sat
- Monthly Full kept for longer retention (archive pool)

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. The 3-2-1 Rule and Beyond

The **3-2-1 rule** is the most cited principle in backup design, and for good reason — it has saved countless organizations from disaster.

### The Classic 3-2-1 Rule

- **3** copies of the data (1 primary + 2 backups)
- **2** different storage media types (e.g., disk and tape, or local disk and cloud)
- **1** copy offsite (geographically separated from the primary)

Why three copies? Because simultaneous failures of two independent systems are rare. With only two copies (primary + one backup), a single additional failure during recovery (e.g., backup media fails while you are trying to restore after a primary failure) leaves you with nothing.

Why two media types? Because media failures can be systemic. If all your backups are on the same brand and batch of hard drives, a firmware bug might affect all of them simultaneously. Cloud + local disk is the modern equivalent.

Why one offsite? Fire, flood, and theft affect physical locations. An offsite copy is unaffected by local disasters.

### Modern Extensions: 3-2-1-1-0

As ransomware became a dominant threat, the rule evolved:

- **3** copies
- **2** different media
- **1** offsite
- **1** offline or immutable (air-gapped, or object-lock S3 bucket)
- **0** errors verified on restore

The **immutable** copy is the ransomware countermeasure: even if attackers compromise your systems and attempt to delete or encrypt backups, they cannot modify an immutable object-store bucket or an offline tape.

The **0 errors** component formalized what experienced administrators always knew: a backup is only as good as its last successful restore test.

### Implementing 3-2-1 with Bareos

In our course setup:
- **Copy 1**: Source data on the application host
- **Copy 2**: Bareos Volumes on local storage (the Bareos Storage Daemon)
- **Copy 3**: A Bareos **Copy Job** that duplicates Volumes to a second pool (remote S3, NFS, or a second host)

We cover Copy Jobs in [Chapter 16](./16-advanced-schedules-pools.md) (Advanced Scheduling and Pools).

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Backup Strategies: Choosing the Right Rotation Scheme

A rotation scheme defines *which* backup jobs run *when*, *how long* data is kept, and *when* old volumes are reused.

### Simple Daily Full (for Small Datasets)

```
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│ Sun  │ Mon  │ Tue  │ Wed  │ Thu  │ Fri  │ Sat  │
│ Full │ Full │ Full │ Full │ Full │ Full │ Full │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┘
Retention: 14 days
```
Simple and fast to restore but expensive on storage. Only practical for small datasets (< 10 GB).

### Weekly Full + Daily Incremental (Most Common)

```
┌──────┬──────┬──────┬──────┬──────┬──────┬──────┐
│ Sun  │ Mon  │ Tue  │ Wed  │ Thu  │ Fri  │ Sat  │
│ Full │ Inc  │ Inc  │ Inc  │ Inc  │ Inc  │ Inc  │
└──────┴──────┴──────┴──────┴──────┴──────┴──────┘
Full retention: 4 weeks
Incremental retention: 4 weeks
```
Good balance of storage efficiency and restore simplicity. The longest restore chain is 7 backup sets.

### GFS (Grandfather-Father-Son) Rotation

GFS is the gold standard for long-term retention with controlled storage growth.

```
Son     = Daily incrementals (kept 1–2 weeks)
Father  = Weekly fulls       (kept 1–3 months)
Grandfather = Monthly fulls  (kept 1–7 years)
```

In Bareos, GFS is implemented with multiple **Pools**:
- `Daily-Pool` — Volume retention: 14 days
- `Weekly-Pool` — Volume retention: 5 weeks
- `Monthly-Pool` — Volume retention: 13 months

A schedule triggers the right Job/Pool combination:
```
Monday–Saturday  → Incremental → Daily-Pool
Sunday           → Full        → Weekly-Pool
1st of month     → Full        → Monthly-Pool
```

We implement this in full in [Chapter 16](./16-advanced-schedules-pools.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. What to Back Up: Data Classification

One of the most common mistakes is backing up everything indiscriminately (wasting storage and time) or backing up too little (missing critical data).

### Tier 1: Critical — Must Always Be Backed Up

| Data Category | Examples |
|---|---|
| Application data | Databases, uploaded files, user content |
| Configuration files | `/etc`, app config dirs, Quadlet unit files |
| Secrets (encrypted) | TLS certificates, SSH keys, Vault data |
| Podman volumes | Named volumes, bind mounts for persistent workloads |
| The Bareos catalog | The MariaDB database that indexes all backups |
| Custom scripts | Cron jobs, automation scripts, deployment code |

### Tier 2: Important — Back Up if Storage Allows

| Data Category | Notes |
|---|---|
| Operating system files | Can be rebuilt from RPM, but takes time |
| Log files | Valuable for forensics; large; consider a separate log retention policy |
| Container images | Can be re-pulled, but local customizations may be lost |
| Package caches | Can be regenerated; low value |

### Tier 3: Exclude — Do Not Back Up

| Data Category | Why Exclude |
|---|---|
| `/proc`, `/sys`, `/dev` | Virtual kernel filesystems — not real files |
| `/tmp`, `/var/tmp` | Ephemeral by design; never needed in restore |
| `/run` | Runtime state; invalid after reboot |
| Swap files/partitions | Not restorable; rebuilt from scratch |
| Container overlay layers | Ephemeral; pull the image instead |
| Large binary build artifacts | Rebuild from source; not persistent data |

In Bareos, exclusions are defined in the `FileSet` resource using `Exclude` and `Wild` patterns:

```bareos
FileSet {
  Name = "Linux-Full"
  Include {
    Options {
      Signature = MD5
      Compression = LZ4
    }
    File = /
  }
  Exclude {
    File = /proc
    File = /sys
    File = /dev
    File = /tmp
    File = /var/tmp
    File = /run
    File = /var/cache/dnf
    File = /var/lib/containers/storage/overlay  # container image layers
  }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Consistency: The Silent Enemy of Good Backups

A backup of a running system is only useful if the data it captures is **consistent**. Consistency means the backed-up data represents a coherent state that can be successfully restored and used.

### The Problem with Live File Backups

Consider a MySQL database. Its data directory contains hundreds of files. During a backup:
1. The backup agent reads `ibdata1` (the tablespace).
2. MySQL writes a transaction, modifying `ib_logfile0`.
3. The backup agent reads `ib_logfile0` — but it now contains data referencing pages that were written to `ibdata1` *after* the backup agent read it.
4. The backed-up state is internally inconsistent. Restoring it may result in database corruption.

This problem affects any application that maintains state across multiple files: databases, mail servers, LDAP directories, and version control repositories.

### Solutions

**1. Application-Consistent Dumps**
The cleanest solution is to dump the application to a single, consistent file *before* backing it up:
- MySQL/MariaDB: `mysqldump` or `mariadb-dump`
- PostgreSQL: `pg_dump`
- MongoDB: `mongodump`

The dump is a complete, self-consistent snapshot. Back up the dump file, not the raw data directory.

**2. Filesystem Snapshots**
LVM snapshots or ZFS snapshots create a point-in-time view of the filesystem that does not change while the backup runs. Bareos can be configured to trigger a snapshot before the backup and release it afterward.

**3. Pre/Post Job Hooks**
Bareos supports `ClientRunBeforeJob` and `ClientRunAfterJob` scripts. These run on the client before and after the backup agent reads files. You can:
- Stop the application before backup (100% consistent, but causes downtime)
- Flush application buffers to disk (`FLUSH TABLES WITH READ LOCK` in MySQL)
- Create a snapshot before backup and release it after

**4. Application-Level Quiesce**
Some applications support a "hot backup" mode where they write a consistent snapshot on request:
- PostgreSQL has `pg_start_backup()` / `pg_stop_backup()`
- MySQL InnoDB is generally safe to back up without stopping if you use `--single-transaction` with mysqldump

We cover pre/post hooks deeply in [Chapter 10](./10-podman-hooks.md) and database container dumps in [Chapter 14](./14-database-containers.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Encryption and Security Considerations

Backup data is often the most sensitive data in an organization — it contains copies of everything, including secrets, credentials, and personal data. It must be protected accordingly.

### In-Transit Encryption

All data moving between Bareos components (File Daemon → Storage Daemon, Director → File Daemon) should be encrypted with TLS. In [Chapter 15](./15-tls-security.md), we configure mutual TLS with certificates for all daemon connections.

### At-Rest Encryption

Backup Volumes on disk are files. If an attacker gains physical access to the storage host, they can read those files. Options:

**1. Bareos PKI-based encryption**
Bareos supports encrypting backup data using an RSA public/private key pair. The public key encrypts data during backup; only the private key (which you keep secure) can decrypt it during restore. This is per-client encryption — even the Bareos administrator cannot read the data without the private key.

**2. Filesystem-level encryption**
Encrypt the Volume storage directory with LUKS (Linux Unified Key Setup) or fscrypt. This protects against physical theft of the disk.

**3. Object storage encryption**
If Volumes are stored on S3-compatible storage, enable bucket-level AES-256 encryption.

### Access Control

- The **bconsole** console authenticates with a password configured in the Director. Use strong passwords.
- Bareos supports **ACL-based Console configurations** that limit what each operator can do (e.g., restore-only access for helpdesk staff).
- Protect the `/etc/bareos/` directory: it contains passwords. Default permissions are `700` for the directory and `600` for files.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Testing Your Backups: Restore Drills

A backup strategy without a restore-testing plan is not a backup strategy — it is a hope strategy.

### What to Test

**1. Full File Restore**
Restore an entire FileSet to a scratch directory. Verify file counts, sizes, and checksums match the source.

**2. Single File Restore**
Use `bconsole` to search for and restore a specific file. Verify it is complete and intact. This is the most common real-world restore scenario.

**3. Database Restore**
If you back up database dumps, restore the dump to a test database instance and run basic queries. Verify data integrity.

**4. Catalog Recovery**
Simulate loss of the Bareos catalog database. Attempt to recover using `bscan` (which re-reads Volumes to rebuild the catalog). This tests your worst-case scenario.

**5. Full System Recovery**
Once per quarter (or more often for critical systems), perform a full system restore to a test VM. Measure the actual RTO — is it within your SLA?

### Documenting Restore Procedures

Every restore test should be documented:
- Date of test
- What was restored (file/directory/system)
- From which backup (date, job name, volume)
- Time taken (measure RTO)
- Any issues encountered
- Pass/Fail

This documentation serves two purposes: it proves to auditors that backups work, and it reveals trends (increasing restore times as datasets grow).

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. How Bareos Implements These Concepts

Now that you understand backup theory, here is a preview of how Bareos translates each concept into configuration.

| Concept | Bareos Implementation |
|---|---|
| RPO | `Schedule` resource: frequency of Job runs |
| RTO | Storage media type, network bandwidth, restore job priority |
| Retention | `File Retention`, `Job Retention`, `Volume Retention` in Pool/Client config |
| Full backup | `Level = Full` in Job definition |
| Incremental | `Level = Incremental` in Job definition |
| Differential | `Level = Differential` in Job definition |
| What to back up | `FileSet` resource: Include/Exclude patterns |
| Consistency | `ClientRunBeforeJob` / `ClientRunAfterJob` scripts |
| Encryption in transit | TLS configuration in daemon configs |
| Encryption at rest | PKI plugin or LUKS filesystem encryption |
| 3-2-1 rule | Multiple Pools + Copy Jobs to offsite storage |
| Restore testing | `restore` command in `bconsole` |
| Alerting | `Mail` and `MailOnError` in JobDefs |
| Catalog | MariaDB database managed by `bareos-dir` |

Every one of these will be configured with real, working examples in the coming chapters.

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Lab 2-1: Planning Your Backup Strategy

Before you touch a single config file, document your backup requirements. Use this worksheet.

```
=== Backup Strategy Planning Worksheet ===

1. What systems will be backed up?
   System 1: _________________________ (IP/hostname: _________)
   System 2: _________________________ (IP/hostname: _________)
   System 3: _________________________ (IP/hostname: _________)

2. For each system, what data is critical?
   System 1: _________________________________________________
   System 2: _________________________________________________
   System 3: _________________________________________________

3. What is the RPO requirement?
   [ ] 24 hours (daily backup is sufficient)
   [ ] 4 hours  (multiple backups per day needed)
   [ ] 1 hour   (continuous or hourly incremental needed)
   [ ] Other: _____________

4. What is the RTO requirement?
   [ ] 24 hours (next business day acceptable)
   [ ] 4 hours  (same-day restoration needed)
   [ ] 1 hour   (near-real-time recovery)
   [ ] Other: _____________

5. What retention periods are required?
   Daily backups retained for: _______ days
   Weekly backups retained for: _______ weeks
   Monthly backups retained for: _______ months

6. How much storage is available for backups?
   Local storage: _______ GB/TB
   Offsite/cloud: _______ GB/TB

7. Are there consistency requirements?
   [ ] Databases (MariaDB, PostgreSQL)
   [ ] Podman container volumes (need pre/post hooks)
   [ ] Custom applications with flush requirements

8. Are there compliance/regulatory requirements?
   [ ] HIPAA   [ ] PCI-DSS   [ ] GDPR   [ ] ISO 27001   [ ] Other: _______

9. What is your backup schedule target?
   [ ] Weekly Full + Daily Incremental
   [ ] Weekly Full + Daily Differential
   [ ] GFS (Grandfather-Father-Son)
   [ ] Other: _____________

10. Where will backup Volumes be stored?
    [ ] Local disk on backup server
    [ ] NFS mount
    [ ] S3-compatible object storage
    [ ] Tape library
    [ ] Other: _____________
```

Completing this worksheet before [Chapter 6](./06-bareos-in-podman.md) will make your Bareos configuration purposeful rather than copied from examples.

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Summary

In this chapter you learned:

- **Why backups fail**: untested procedures, silent job failures, same-failure-domain storage, incomplete FileSets, misconfigured retention, and unprotected catalogs.
- **RPO** defines how much data loss is acceptable and drives backup frequency. **RTO** defines how fast you must restore and drives storage and automation decisions. **Retention** defines how far back you need to recover.
- **Full backups** are self-contained but slow and storage-intensive. **Incremental backups** are fast and lean but require a complete chain for restore. **Differential backups** balance the two.
- The **3-2-1 rule** (3 copies, 2 media types, 1 offsite) is the minimum viable backup architecture. Modern additions include an immutable copy and zero-error-verified restores.
- **GFS rotation** (daily, weekly, monthly pools) provides long-term retention with controlled storage growth.
- **Consistency** matters: always dump databases before backing up data directories, and use pre/post hooks to quiesce applications.
- **Encryption** must cover both data in transit (TLS between Bareos daemons) and data at rest (PKI or LUKS).
- **Restore drills** are mandatory — a backup is only proven by a successful restore.

---

**Next Chapter:** [Chapter 3: RHEL 10 Prerequisites](./03-rhel10-prerequisites.md)

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 Jaco Steyn — Licensed under CC BY-SA 4.0
