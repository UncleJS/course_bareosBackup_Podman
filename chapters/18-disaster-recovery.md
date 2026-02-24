# Chapter 18: Disaster Recovery — Restoring Everything from Scratch

## Table of Contents

- [1. Disaster Recovery Philosophy: RTO, RPO, and the 3-2-1 Rule](#1-disaster-recovery-philosophy-rto-rpo-and-the-3-2-1-rule)
  - [The 3-2-1 Rule](#the-3-2-1-rule)
  - [What "Disaster" Means in a Podman Context](#what-disaster-means-in-a-podman-context)
- [2. What You Need to Recover Bareos](#2-what-you-need-to-recover-bareos)
  - [Leg 1: The Bareos Storage Volumes](#leg-1-the-bareos-storage-volumes)
  - [Leg 2: The Catalog Database](#leg-2-the-catalog-database)
  - [Leg 3: The Bareos Configuration](#leg-3-the-bareos-configuration)
  - [Summary Table](#summary-table)
- [3. Protecting the Catalog: Your Most Critical Asset](#3-protecting-the-catalog-your-most-critical-asset)
  - [The BackupCatalog Job](#the-backupcatalog-job)
  - [Catalog FileSet](#catalog-fileset)
  - [Where the Catalog Dump Lands on the Host](#where-the-catalog-dump-lands-on-the-host)
- [4. The Bootstrap File: Catalog-Independent Restore](#4-the-bootstrap-file-catalog-independent-restore)
  - [What a Bootstrap File Looks Like](#what-a-bootstrap-file-looks-like)
  - [Where Bareos Writes Bootstrap Files](#where-bareos-writes-bootstrap-files)
- [5. Scenario 1: Restore Single Files to a Running System](#5-scenario-1-restore-single-files-to-a-running-system)
  - [The Standard Restore Path](#the-standard-restore-path)
  - [Restore Job Resource for Single-File Restores](#restore-job-resource-for-single-file-restores)
  - [Verifying the Restore](#verifying-the-restore)
- [6. Scenario 2: Restore All Container Volumes to a Rebuilt Host](#6-scenario-2-restore-all-container-volumes-to-a-rebuilt-host)
  - [Identifying What Needs to Be Restored](#identifying-what-needs-to-be-restored)
  - [Step-by-Step: Restoring Named Volumes](#step-by-step-restoring-named-volumes)
- [7. Scenario 3: Total Loss — Rebuilding Bareos from Scratch](#7-scenario-3-total-loss-rebuilding-bareos-from-scratch)
- [8. Step-by-Step Total Rebuild Procedure](#8-step-by-step-total-rebuild-procedure)
  - [8a. Install RHEL 10, Create bareos User, Enable Lingering](#8a-install-rhel-10-create-bareos-user-enable-lingering)
  - [8b. Restore Storage Volumes to /srv/bareos-storage/volumes](#8b-restore-storage-volumes-to-srvbareos-storagevolumes)
  - [8c. Restore the Catalog Database](#8c-restore-the-catalog-database)
  - [8d. Pull Bareos Images and Write Quadlet Files](#8d-pull-bareos-images-and-write-quadlet-files)
  - [8e. Initialize the New Director with the Restored Catalog](#8e-initialize-the-new-director-with-the-restored-catalog)
  - [8f. Verify All Volumes and Jobs in bconsole](#8f-verify-all-volumes-and-jobs-in-bconsole)
  - [8g. Run a Test Restore of a Specific File](#8g-run-a-test-restore-of-a-specific-file)
- [9. Bootstrap Files for Catalog-Independent Restore](#9-bootstrap-files-for-catalog-independent-restore)
  - [Method 1: bextract with a Bootstrap File](#method-1-bextract-with-a-bootstrap-file)
  - [Method 2: bscan — Rebuilding the Catalog from Volume Files](#method-2-bscan-rebuilding-the-catalog-from-volume-files)
- [10. Restoring to a Different Hostname or IP Address](#10-restoring-to-a-different-hostname-or-ip-address)
  - [Director on a New Hostname](#director-on-a-new-hostname)
  - [Client on a New IP Address](#client-on-a-new-ip-address)
  - [Updating Catalog Records for a Renamed Client](#updating-catalog-records-for-a-renamed-client)
- [11. Testing Your DR Plan: The DR Drill Procedure](#11-testing-your-dr-plan-the-dr-drill-procedure)
  - [Quarterly DR Drill Checklist](#quarterly-dr-drill-checklist)
- [12. Documenting Your Recovery Runbook](#12-documenting-your-recovery-runbook)
  - [Runbook Template](#runbook-template)
- [Contact Information](#contact-information)
- [System Inventory](#system-inventory)
- [Credential Locations](#credential-locations)
- [Recovery Steps](#recovery-steps)
- [Verification Checklist](#verification-checklist)
  - [Where to Store the Runbook](#where-to-store-the-runbook)
- [13. Offsite Storage: Syncing Volumes with rsync and rclone](#13-offsite-storage-syncing-volumes-with-rsync-and-rclone)
  - [rsync to a Remote Server](#rsync-to-a-remote-server)
  - [rclone to Cloud Object Storage (S3-compatible)](#rclone-to-cloud-object-storage-s3-compatible)
- [14. SELinux: Re-labeling After Restoring Files](#14-selinux-re-labeling-after-restoring-files)
  - [Understanding SELinux Contexts in Restores](#understanding-selinux-contexts-in-restores)
  - [Re-labeling After Restore](#re-labeling-after-restore)
  - [Checking for SELinux Denials After Restore](#checking-for-selinux-denials-after-restore)
- [15. Lab 18-1: Full Catalog Backup and Restore on the Same Host](#15-lab-18-1-full-catalog-backup-and-restore-on-the-same-host)
  - [Step 1: Run the BackupCatalog Job](#step-1-run-the-backupcatalog-job)
  - [Step 2: Locate the Catalog Dump](#step-2-locate-the-catalog-dump)
  - [Step 3: Simulate Catalog Loss](#step-3-simulate-catalog-loss)
  - [Step 4: Restore the Catalog](#step-4-restore-the-catalog)
  - [Step 5: Restart and Verify](#step-5-restart-and-verify)
- [16. Lab 18-2: Simulate Total Loss and Rebuild from Backup](#16-lab-18-2-simulate-total-loss-and-rebuild-from-backup)
- [17. Lab 18-3: Restore a Single File Using a Bootstrap File](#17-lab-18-3-restore-a-single-file-using-a-bootstrap-file)
- [18. Summary](#18-summary)

## 1. Disaster Recovery Philosophy: RTO, RPO, and the 3-2-1 Rule

Before touching a single configuration file, you need to understand *why* you are doing all of this. Disaster recovery is not just a technical exercise — it is a business commitment. Two concepts define that commitment:

**Recovery Time Objective (RTO)** is the maximum amount of time your organization can tolerate being without access to data or services after a disaster. If your RTO is four hours, you must be able to restore operations within four hours of an incident. Every decision you make about your Bareos setup — how often you run jobs, where you store catalog backups, whether you keep a cold-standby host ready — should be measured against this number.

**Recovery Point Objective (RPO)** is the maximum amount of data loss your organization can accept, measured in time. An RPO of 24 hours means you are willing to lose at most one day of data. This drives your backup frequency: if you run nightly full backups and your RPO is 24 hours, you are compliant. If your RPO is one hour, you need hourly incrementals.

Neither RTO nor RPO has a universally correct value. A home lab has an RTO of "whenever I feel like fixing it" and an RPO of "last week's backup is fine." A financial system might have an RTO of 15 minutes and an RPO of zero (requiring real-time replication). Know your numbers before you design your recovery procedures.

### The 3-2-1 Rule

The 3-2-1 rule is the most widely cited guideline in backup strategy. It states:

- **3** copies of your data
- **2** different storage media types
- **1** copy offsite

Applied to Bareos: your primary backup data lives on the Bareos Storage Daemon volume (copy 1, on local disk). You replicate those volumes to a NAS or object store (copy 2, different device). You also send a copy offsite — either to a remote server, cloud storage, or a physical tape shipped off-premises (copy 3, offsite).

For the Catalog specifically, the rule is even stricter: the Catalog is the *index* of your backups. Without it, you cannot easily find what you backed up or run a standard restore job. You should treat the Catalog database dump as a critical artifact and include it in your primary backup job, then also copy it to your offsite location.

### What "Disaster" Means in a Podman Context

In our setup, "disaster" has a specific meaning. Your Bareos system runs as rootless Podman containers under the `bareos` user. A "disaster" could be:

- **Disk failure**: the physical disk holding `/srv/bareos-storage/volumes` dies
- **Accidental deletion**: someone removes a named container volume or a Quadlet file
- **Host failure**: the entire RHEL 10 host is unrecoverable (hardware failure, ransomware, etc.)
- **Container corruption**: a MariaDB container crashes mid-transaction, corrupting the catalog database
- **Configuration loss**: the `/home/bareos/.config/` tree is deleted

Each scenario requires a different recovery approach. This chapter covers all of them, from the simplest (restoring a single file) to the most complex (rebuilding the entire host from scratch).

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. What You Need to Recover Bareos

To fully restore a Bareos system, you need three distinct pieces of data. Think of them as a three-legged stool — remove any one leg and recovery becomes significantly harder:

### Leg 1: The Bareos Storage Volumes

These are the actual files on disk — typically stored at `/srv/bareos-storage/volumes/` — that contain the backed-up data in Bareos's internal format. Each volume file is a sequence of Bareos blocks containing data from one or more backup jobs. They are named things like `Full-0001`, `Incr-0042`, etc.

Without the volumes, you have no data to restore. These are your primary concern when it comes to storage capacity and disk health.

### Leg 2: The Catalog Database

The Catalog is a MariaDB database (named `bareos` by convention) that stores metadata about every job Bareos has ever run: which files were backed up, which volume they are on, what block offset within that volume each file lives at, file attributes (owner, permissions, modification time), and the relationships between full and incremental backups.

When you run `restore` in bconsole and browse a file tree from six months ago, you are querying the Catalog. When Bareos needs to find a specific file across thousands of volumes, it queries the Catalog. Without the Catalog, Bareos cannot perform a standard restore job — you must fall back to the bootstrap method (see Section 4).

### Leg 3: The Bareos Configuration

This includes everything under `/home/bareos/.config/bareos/` and `/home/bareos/.config/containers/systemd/` — your Director configuration, Storage Daemon configuration, Client (File Daemon) configuration, Pool definitions, Job definitions, FileSet definitions, and Schedule definitions. Without the configuration, you cannot reconnect a new Director to your existing storage volumes.

The configuration is usually the smallest and easiest piece to protect — a few kilobytes of text files that can be committed to a git repository or emailed to yourself. Do not neglect it.

### Summary Table

| Asset | Location | Size | Criticality |
|---|---|---|---|
| Storage volumes | `/srv/bareos-storage/volumes/` | GBs to TBs | Cannot restore data without them |
| Catalog database | MariaDB volume `bareos-db-data` | MBs to GBs | Cannot run standard restore without it |
| Bareos config | `/home/bareos/.config/bareos/` | KBs | Cannot reconnect Director without it |
| Quadlet files | `/home/bareos/.config/containers/systemd/` | KBs | Needed to restart containers |
| Env/secret files | `/home/bareos/.config/bareos/*.env` | Bytes | Needed for DB passwords |

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Protecting the Catalog: Your Most Critical Asset

The Catalog is the most fragile piece of your backup system because it lives in a running database container that can be corrupted by a crash, an out-of-disk-space event, or an unexpected container stop. A corrupt or missing Catalog means you must either restore it from a backup or perform a time-consuming catalog-less restore using bootstrap files.

### The BackupCatalog Job

Bareos ships with a built-in job definition called `BackupCatalog`. This job uses the `MakeBootstrapFile` directive and a pre-script that calls `mysqldump` (or the Bareos-provided `make_catalog_backup.pl` script) to dump the Catalog to a file, then backs up that file as a regular Bareos job.

Here is a complete, annotated Director configuration for catalog protection:

```
# /home/bareos/.config/bareos/bareos-dir.d/job/BackupCatalog.conf
#
# This job backs up the Bareos catalog database.
# It MUST run after all other backup jobs complete each day.
# The "Priority = 11" ensures it runs last (lower number = higher priority;
# all normal jobs use Priority = 10 by default).

Job {
  Name = "BackupCatalog"
  JobDefs = "DefaultJob"
  Level = Full                    # Always Full — the catalog changes every day
  FileSet = "Catalog"             # Special FileSet that includes the dump file
  Schedule = "WeeklyCycleAfterBackup"
  Storage = File1
  Messages = Daemon
  Pool = Default
  Priority = 11                   # Run AFTER all other jobs
  # This directive tells Bareos to write a bootstrap file for THIS job.
  # That bootstrap file is then mailed to the admin (see Messages resource).
  # With this bootstrap file you can restore the catalog even without a
  # running Director.
  Write Bootstrap = "/var/lib/bareos/%n.bsr"
  # The RunScript runs BEFORE the job to dump the database to a flat file.
  # The File Daemon on the Director host will then pick up that file.
  RunScript {
    Options = "Fail Job on Error"
    RunsOnClient = no             # Run on the Director host, not a remote client
    RunsWhen = Before
    # make_catalog_backup.pl is provided by the bareos-tools package.
    # It calls mysqldump internally using the credentials from /etc/bareos/
    Command = "/usr/lib/bareos/scripts/make_catalog_backup.pl MyCatalog"
  }
  # After the backup completes, clean up the temporary dump file.
  RunScript {
    RunsOnSuccess = yes
    RunsOnFailure = no
    RunsOnClient  = no
    RunsWhen = After
    Command = "/usr/lib/bareos/scripts/delete_catalog_backup MyCatalog"
  }
}
```

Because we are running inside a container, the `make_catalog_backup.pl` script needs to connect to MariaDB. The simplest approach is to run the dump *from inside the Director container* using environment variables already present there.

Here is the preferred containerized approach — a shell wrapper script you mount into the Director container:

```bash
#!/bin/bash
# /home/bareos/.config/bareos/scripts/dump-catalog.sh
#
# Dumps the Bareos MariaDB catalog to a flat SQL file.
# This script runs inside the bareos-director container.
# It reads credentials from environment variables injected
# via the bareos.env file (see Quadlet configuration).
#
# The output file is written to the bareos-dir-config volume
# so the File Daemon can pick it up.

set -euo pipefail

DUMP_DIR="/etc/bareos/catalog-backup"
DUMP_FILE="${DUMP_DIR}/bareos-catalog-$(date +%Y%m%d-%H%M%S).sql.gz"

mkdir -p "${DUMP_DIR}"

# Use the variables injected from the env file:
# DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
echo "Dumping catalog to ${DUMP_FILE} ..."
mysqldump \
  --host="${DB_HOST:-bareos-db}" \
  --port="${DB_PORT:-3306}" \
  --user="${DB_USER:-bareos}" \
  --password="${DB_PASSWORD}" \
  --single-transaction \   # Consistent snapshot without locking tables
  --routines \             # Include stored procedures
  --triggers \             # Include triggers
  "${DB_NAME:-bareos}" \
  | gzip -6 > "${DUMP_FILE}"

echo "Catalog dump complete: ${DUMP_FILE}"

# Keep only the last 7 daily dumps to avoid filling the volume
find "${DUMP_DIR}" -name "bareos-catalog-*.sql.gz" \
  -mtime +7 -delete

echo "Old dumps pruned."
```

Make the script executable and mount it into the container via the Quadlet file:

```bash
chmod 750 /home/bareos/.config/bareos/scripts/dump-catalog.sh
```

### Catalog FileSet

```
# /home/bareos/.config/bareos/bareos-dir.d/fileset/Catalog.conf
#
# This FileSet tells Bareos which files constitute the "catalog backup."
# It points to the dump directory where dump-catalog.sh writes its output.

FileSet {
  Name = "Catalog"
  Include {
    Options {
      Signature = MD5         # Checksums for integrity verification
      Compression = GZIP      # Compress the (already gzipped) SQL — small gain
    }
    # The dump directory inside the Director container, which is backed by
    # the bareos-dir-config named volume on the host.
    File = "/etc/bareos/catalog-backup"
  }
}
```

### Where the Catalog Dump Lands on the Host

Because the Director container mounts the `bareos-dir-config` named volume at `/etc/bareos/`, and that volume's data lives at:

```
~/.local/share/containers/storage/volumes/bareos-dir-config/_data/
```

The dump file is accessible on the host at:

```
/home/bareos/.local/share/containers/storage/volumes/bareos-dir-config/_data/catalog-backup/bareos-catalog-YYYYMMDD-HHMMSS.sql.gz
```

This means you can also copy it manually at any time without entering the container:

```bash
# Copy the latest catalog dump to a safe location (run as bareos user)
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  LATEST=$(ls -t ~/.local/share/containers/storage/volumes/bareos-dir-config/_data/catalog-backup/*.sql.gz | head -1)
  cp "$LATEST" /srv/bareos-storage/catalog-backup/
  echo "Copied: $LATEST"
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. The Bootstrap File: Catalog-Independent Restore

The bootstrap file (`.bsr` extension) is Bareos's emergency restore mechanism. It is a plain-text file that tells the Storage Daemon exactly which tape blocks (or disk offsets) contain a specific job's data — without needing to query the Catalog at all.

Think of it as a physical address book: instead of looking up a name in a directory (the Catalog), you go straight to the building and apartment number written in the book.

### What a Bootstrap File Looks Like

```
# Example bootstrap file for a Full backup job
# Generated by Bareos Director automatically after each job
# Location in container: /var/lib/bareos/BackupCatalog.bsr
# Location on host: ~/.local/share/containers/storage/volumes/bareos-dir-state/_data/BackupCatalog.bsr

Volume="Full-0001"
MediaType="File"
VolSessionId=3
VolSessionTime=1708945200
VolAddr=0-2147483648
FileIndex=1-157
Count=157
```

Each line means:
- `Volume`: the volume file name in `/srv/bareos-storage/volumes/`
- `MediaType`: must match the Storage Daemon Device definition
- `VolSessionId` / `VolSessionTime`: together uniquely identify a backup job session
- `VolAddr`: byte range within the volume file to read
- `FileIndex`: which file records within that session to extract
- `Count`: total number of files

### Where Bareos Writes Bootstrap Files

Bareos writes bootstrap files for jobs that include `Write Bootstrap = "/var/lib/bareos/%n.bsr"` in the Job definition (where `%n` is the job name). The default location inside the Director container is `/var/lib/bareos/`. On the host, that maps to the `bareos-dir-state` named volume:

```
~/.local/share/containers/storage/volumes/bareos-dir-state/_data/
```

You should configure Bareos to email the bootstrap file to an administrator after each important job. This way, even if the entire host is destroyed, you have the bootstrap files in your inbox and can perform a catalog-less restore on any new host.

To enable bootstrap email, add to your Messages resource:

```
# /home/bareos/.config/bareos/bareos-dir.d/messages/Standard.conf

Messages {
  Name = Standard
  # ... other directives ...

  # Mail the bootstrap file to the admin after every successful job.
  # The %b macro expands to the bootstrap file path.
  Mail Command = "/usr/sbin/bsmtp -h localhost -f \"\(Bareos\) %r\" -s \"Bareos: %t %e of %c %l\" %r"
  Mail On Success = yes
  Operator Command = "/usr/sbin/bsmtp -h localhost -f \"\(Bareos\) %r\" -s \"Bareos: Intervention needed for %j\" %r"
  Operator = "bareos-admin@example.com"
  Mail = "bareos-admin@example.com"

  # Attach the bootstrap file to the completion email
  # (set in Job definition with: Write Bootstrap = ...)
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Scenario 1: Restore Single Files to a Running System

This is the most common recovery operation. Everything is running, the Catalog is intact, and a user accidentally deleted a file or needs an older version.

### The Standard Restore Path

```bash
# 1. Open bconsole inside the running Director container
sudo -u bareos bash -c 'XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-director bconsole'

# 2. At the bconsole prompt, start a restore
*restore

# 3. Bareos presents a menu. Choose option 5 (Select Files from most recent backup)
#    or option 3 (Enter list of comma separated JobIds to select) for a specific date.
#
# The interactive menu looks like:
#
# To select the JobIds, you have the following choices:
#     1: List last 20 Jobs run
#     2: List Jobs where a given File is saved
#     3: Enter list of comma separated JobIds to select
#     4: Enter SQL list command
#     5: Select the most recent backup for a client
#     6: Select backup for a client before a specified time
#     7: Enter a list of files to restore
#     8: Enter a list of files to restore before a specified time
#     9: Find the JobIds of the most recent backup for a client
#    10: Find the JobIds for a backup for a client before a specified time
#    11: Enter a list of directories to restore for found JobIds
#    12: Select full restore to a specified Job date
#    13: Cancel
# Select item:  (1-13):

# 4. After selecting the job, you enter a file browser (the "mark" interface).
#    Navigate to the file you want and mark it:

$ ls                     # list current directory
$ cd var/www/html        # navigate into a subdirectory
$ mark index.html        # mark this file for restore
$ ls -marked             # verify your selections
$ done                   # proceed

# 5. Bareos asks for restore parameters.
#    IMPORTANT: by default it restores to the ORIGINAL path.
#    To restore to a different path (recommended for safety), set:
*restore ... where=/tmp/bareos-restore
```

### Restore Job Resource for Single-File Restores

You can also define a dedicated restore job in the Director config:

```
# /home/bareos/.config/bareos/bareos-dir.d/job/RestoreFiles.conf
#
# This job definition is used for all file restore operations.
# It is normally triggered interactively via bconsole, not scheduled.

Job {
  Name = "RestoreFiles"
  Type = Restore
  Client = bareos-fd                  # The client where files will be restored
  Storage = File1
  FileSet = "Full Set"                # Must match the FileSet used during backup
  Pool = Default
  Messages = Standard
  # Where= overrides the restore path. Leaving it blank restores to original paths.
  # Setting it here provides a safe default; you can override at restore time.
  Where = /tmp/bareos-restore
}
```

### Verifying the Restore

```bash
# After the restore job completes, check the output
*list jobid=<restore_job_id>
*list files jobid=<restore_job_id>

# On the host, verify the restored file
ls -la /tmp/bareos-restore/

# Check file ownership and SELinux context
ls -laZ /tmp/bareos-restore/var/www/html/index.html

# If SELinux context is wrong, re-label:
sudo restorecon -Rv /tmp/bareos-restore/

# Move the file to its final destination
sudo mv /tmp/bareos-restore/var/www/html/index.html /var/www/html/
sudo restorecon /var/www/html/index.html
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Scenario 2: Restore All Container Volumes to a Rebuilt Host

This scenario covers a partial disaster: the RHEL 10 host is intact and RHEL is reinstalled, but all container data (named volumes) is lost. You have backups of both the storage volumes and the Catalog.

### Identifying What Needs to Be Restored

The named volumes in your Bareos setup are:

| Volume Name | Contents | Mount Point in Container |
|---|---|---|
| `bareos-db-data` | MariaDB database files | `/var/lib/mysql` |
| `bareos-dir-config` | Director config + catalog dumps | `/etc/bareos` |
| `bareos-dir-state` | Director state + bootstrap files | `/var/lib/bareos` |
| `bareos-sd-config` | Storage Daemon config | `/etc/bareos` |
| `bareos-fd-config` | File Daemon config | `/etc/bareos` |

The storage volumes at `/srv/bareos-storage/volumes/` are on a separate disk mount and may or may not have survived. If they survived, you only need to restore the named volumes. If they are also lost, proceed to Scenario 3.

### Step-by-Step: Restoring Named Volumes

```bash
# Assume you are logged in as root on the rebuilt RHEL 10 host.
# The bareos user already exists (UID 1001) and lingering is enabled.
# You have a tarball of each volume's _data directory from your backup.

# 1. Re-create the Podman volumes (this creates the directory structure)
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  for vol in bareos-db-data bareos-dir-config bareos-dir-state bareos-sd-config bareos-fd-config; do
    podman volume create "$vol"
    echo "Created volume: $vol"
  done
'

# 2. Restore each volume's data from your backup tarballs
#    (adjust the source path to wherever your backup tarballs live)
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  BACKUP_SOURCE="/mnt/backup-drive/bareos-volumes"

  for vol in bareos-db-data bareos-dir-config bareos-dir-state bareos-sd-config bareos-fd-config; do
    DATA_DIR=$(podman volume inspect "$vol" --format "{{.Mountpoint}}")
    echo "Restoring $vol to $DATA_DIR ..."
    tar -xzf "${BACKUP_SOURCE}/${vol}.tar.gz" -C "$DATA_DIR"
    echo "Done: $vol"
  done
'

# 3. Fix ownership — all files must be owned by bareos (UID 1001)
sudo chown -R 1001:1001 \
  /home/bareos/.local/share/containers/storage/volumes/

# 4. Fix SELinux contexts on the volume directories
sudo restorecon -Rv \
  /home/bareos/.local/share/containers/storage/volumes/

# 5. Restore the Quadlet files
sudo -u bareos bash -c '
  cp /mnt/backup-drive/bareos-config/quadlet/*.container \
     ~/.config/containers/systemd/
  cp /mnt/backup-drive/bareos-config/quadlet/*.network \
     ~/.config/containers/systemd/
'

# 6. Restore env/secret files
sudo -u bareos bash -c '
  cp /mnt/backup-drive/bareos-config/env/db.env ~/.config/bareos/db.env
  cp /mnt/backup-drive/bareos-config/env/bareos.env ~/.config/bareos/bareos.env
  chmod 600 ~/.config/bareos/db.env ~/.config/bareos/bareos.env
'

# 7. Reload systemd and start services
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload
  systemctl --user start bareos-db.service
  sleep 15  # Give MariaDB time to initialize from restored data
  systemctl --user start bareos-director.service
  systemctl --user start bareos-storage.service
  systemctl --user start bareos-fd.service
'

# 8. Verify services
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user status bareos-db.service bareos-director.service \
    bareos-storage.service bareos-fd.service
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Scenario 3: Total Loss — Rebuilding Bareos from Scratch

This is the worst case: the host is completely unrecoverable. You have:
- Your Bareos storage volumes backed up offsite (or on a separate disk)
- A catalog database dump (`.sql.gz` file) from the last successful `BackupCatalog` job
- Your configuration files (checked into git, or stored offsite)

The goal: rebuild an identical Bareos Director on a new host, import the old catalog, reconnect it to the old storage volumes, and verify you can restore any file from the old backups.

The detailed procedure follows in Section 8.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Step-by-Step Total Rebuild Procedure

This is the most important section of this chapter. Read it carefully, then follow the steps in order. Every command is copy-paste ready.

### 8a. Install RHEL 10, Create bareos User, Enable Lingering

```bash
# On the new RHEL 10 host, logged in as root:

# 1. Ensure the system is up to date
dnf update -y

# 2. Install required packages
dnf install -y \
  podman \          # Container runtime
  systemd \         # Already installed, but ensure it is current
  policycoreutils-python-utils \  # semanage, audit2allow
  rsync \           # For pulling data from offsite
  mariadb \         # Client tools (mysql CLI) for catalog verification
  tar \             # For extracting volume archives
  gzip

# 3. Create the bareos system user with UID 1001.
#    The --system flag creates a system account (no home dir by default,
#    no aging). We explicitly set a home directory because rootless Podman
#    needs one for its configuration and storage.
sudo useradd \
  --system \
  --uid 1001 \
  --create-home \
  --home-dir /home/bareos \
  --shell /sbin/nologin \
  --comment "Bareos Backup Service Account" \
  bareos

# 4. Verify the UID
id bareos
# Expected output: uid=1001(bareos) gid=1001(bareos) groups=1001(bareos)

# 5. Set up subordinate UID/GID ranges for rootless Podman.
#    These allow the bareos user's containers to map to a large UID range
#    for user namespace isolation.
echo "bareos:100000:65536" >> /etc/subuid
echo "bareos:100000:65536" >> /etc/subgid

# Verify
grep bareos /etc/subuid /etc/subgid
# Expected:
# /etc/subuid:bareos:100000:65536
# /etc/subgid:bareos:100000:65536

# 6. Enable lingering for the bareos user.
#    Without this, the bareos user's systemd session (and all containers)
#    would stop when the last login session ends.
#    With lingering enabled, systemd starts the user session at boot
#    and keeps it running permanently.
loginctl enable-linger bareos

# Verify
loginctl show-user bareos | grep Linger
# Expected: Linger=yes

# 7. Set XDG_RUNTIME_DIR for the bareos user.
#    This environment variable tells Podman and systemd --user where to
#    find the runtime socket. Without it, rootless Podman cannot find
#    the systemd socket and will fail silently.
#    We set it persistently in the bareos user's environment.
mkdir -p /home/bareos/.config/environment.d/
cat > /home/bareos/.config/environment.d/bareos.conf << 'EOF'
XDG_RUNTIME_DIR=/run/user/1001
EOF
chown -R bareos:bareos /home/bareos/.config/

# 8. Start the bareos user's systemd session immediately
#    (normally done on first login, but we need it now)
machinectl shell bareos@ /bin/bash -c 'systemctl --user status'
# If this works without error, the user session is active.

# 9. Create required directories
mkdir -p /srv/bareos-storage/volumes
chown bareos:bareos /srv/bareos-storage
chown bareos:bareos /srv/bareos-storage/volumes

# 10. Set SELinux context on the storage directory.
#     bareos_store_t is the correct type for Bareos storage volumes.
#     If this type is not available in your policy, use container_file_t
#     as a fallback, but bareos_store_t is preferred for tighter confinement.
semanage fcontext -a -t bareos_store_t "/srv/bareos-storage/volumes(/.*)?"
restorecon -Rv /srv/bareos-storage/volumes/

# Verify
ls -laZ /srv/bareos-storage/
```

### 8b. Restore Storage Volumes to /srv/bareos-storage/volumes

The "storage volumes" are the actual `.vol` or named-file Bareos volume files that contain your backed-up data. In our setup they live at `/srv/bareos-storage/volumes/`.

```bash
# Scenario A: Volumes are on a separate disk that survived the disaster.
# The disk is already mounted at /srv/bareos-storage/. Nothing to do here.
# Verify:
ls -la /srv/bareos-storage/volumes/
# You should see files like: Full-0001, Full-0002, Incr-0001, etc.

# Scenario B: Volumes need to be pulled from an offsite rsync target.
# Replace OFFSITE_HOST and OFFSITE_PATH with your actual values.
OFFSITE_HOST="backup.example.com"
OFFSITE_PATH="/exports/bareos-volumes/"

rsync \
  --archive \           # Preserve permissions, timestamps, symlinks, etc.
  --verbose \           # Show progress
  --progress \          # Per-file progress
  --checksum \          # Verify integrity by checksum, not just mtime+size
  --human-readable \
  "bareos@${OFFSITE_HOST}:${OFFSITE_PATH}" \
  /srv/bareos-storage/volumes/

# Scenario C: Volumes are in a tar archive on a backup drive.
tar \
  --extract \
  --gzip \
  --verbose \
  --file=/mnt/backup-drive/bareos-storage-volumes-YYYYMMDD.tar.gz \
  --directory=/srv/bareos-storage/volumes/

# After restoring by any method:
# Fix ownership
chown -R bareos:bareos /srv/bareos-storage/volumes/

# Fix permissions — volume files should be readable only by bareos
chmod -R 660 /srv/bareos-storage/volumes/
chmod 750 /srv/bareos-storage/volumes/

# Fix SELinux context
restorecon -Rv /srv/bareos-storage/volumes/

# Verify the label
ls -laZ /srv/bareos-storage/volumes/ | head -5
# Expect: system_u:object_r:bareos_store_t:s0
```

### 8c. Restore the Catalog Database

The Catalog dump is a gzipped SQL file created by the `BackupCatalog` job. You need to restore it into a fresh MariaDB container.

```bash
# 1. Create the required directories for bareos user config
sudo -u bareos mkdir -p /home/bareos/.config/bareos
sudo -u bareos mkdir -p /home/bareos/.config/containers/systemd

# 2. Restore secret/env files from backup.
#    These contain DB_PASSWORD and other credentials.
#    They MUST have mode 600 — MariaDB and Bareos will refuse to start
#    if these files are world-readable.
cp /mnt/backup-drive/bareos-config/env/db.env /home/bareos/.config/bareos/db.env
cp /mnt/backup-drive/bareos-config/env/bareos.env /home/bareos/.config/bareos/bareos.env
chown bareos:bareos /home/bareos/.config/bareos/db.env
chown bareos:bareos /home/bareos/.config/bareos/bareos.env
chmod 600 /home/bareos/.config/bareos/db.env
chmod 600 /home/bareos/.config/bareos/bareos.env

# Verify contents (without revealing the password)
sudo -u bareos cat /home/bareos/.config/bareos/db.env
# Expected lines (values will vary):
# MARIADB_ROOT_PASSWORD=<redacted>
# MARIADB_DATABASE=bareos
# MARIADB_USER=bareos
# MARIADB_PASSWORD=<redacted>

# 3. Write the MariaDB Quadlet file (minimal, for initial restore)
cat > /home/bareos/.config/containers/systemd/bareos-db.container << 'EOF'
[Unit]
Description=Bareos MariaDB Catalog Database
After=network-online.target
Wants=network-online.target

[Container]
# Use the official MariaDB 10.11 LTS image
Image=docker.io/library/mariadb:10.11

# The named volume that stores the database files.
# On a fresh host this volume is empty; we will import the dump below.
Volume=bareos-db-data.volume:/var/lib/mysql:z

# Inject database credentials from the mode-600 env file.
# The :z suffix tells Podman to set the SELinux label automatically.
EnvironmentFile=/home/bareos/.config/bareos/db.env

# Expose MariaDB only on the container network, not on the host.
  # Other Bareos containers reach it via the 'bareos' network.
Network=bareos.network

# Health check: verify MariaDB is accepting connections.
HealthCmd=mysqladmin --user=root --password=${MARIADB_ROOT_PASSWORD} ping --silent
HealthInterval=30s
HealthRetries=5
HealthStartPeriod=60s

[Service]
Restart=always
TimeoutStartSec=180

[Install]
WantedBy=default.target
EOF

# 4. Write the network Quadlet file
cat > /home/bareos/.config/containers/systemd/bareos.network << 'EOF'
[Network]
# An isolated bridge network for all Bareos containers.
# Containers on this network can reach each other by container name.
Driver=bridge
Subnet=172.20.0.0/24
Gateway=172.20.0.1
EOF

# 5. Write the volume Quadlet file for the database
cat > /home/bareos/.config/containers/systemd/bareos-db-data.volume << 'EOF'
[Volume]
# This declares the named volume. Podman creates it if it doesn't exist.
# The actual data lives at:
# ~/.local/share/containers/storage/volumes/bareos-db-data/_data/
Label=app=bareos
Label=component=database
EOF

# 6. Fix ownership of all config files
chown -R bareos:bareos /home/bareos/.config/

# 7. Start the database container
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload
  systemctl --user start bareos-db.service
  echo "Waiting for MariaDB to be ready..."
  sleep 20
  systemctl --user status bareos-db.service
'

# 8. Verify MariaDB is running
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-db mysqladmin \
    --user=root \
    --password=$(grep MARIADB_ROOT_PASSWORD ~/.config/bareos/db.env | cut -d= -f2) \
    ping
'
# Expected: mysqld is alive

# 9. Import the catalog dump
#    Locate your catalog dump file (from the BackupCatalog job)
CATALOG_DUMP="/mnt/backup-drive/catalog/bareos-catalog-YYYYMMDD-HHMMSS.sql.gz"

# Read the DB password from the env file
DB_PASS=$(sudo -u bareos grep MARIADB_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)
ROOT_PASS=$(sudo -u bareos grep MARIADB_ROOT_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)

# Copy the dump into the container (or pipe it directly)
sudo -u bareos bash -c "
  XDG_RUNTIME_DIR=/run/user/1001
  # Create the bareos database if it doesn't exist yet
  podman exec bareos-db mysql \
    --user=root \
    --password='${ROOT_PASS}' \
    -e 'CREATE DATABASE IF NOT EXISTS bareos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'

  # Import the dump
  echo 'Importing catalog dump — this may take several minutes...'
  zcat '${CATALOG_DUMP}' | podman exec -i bareos-db mysql \
    --user=bareos \
    --password='${DB_PASS}' \
    bareos

  echo 'Catalog import complete.'
"

# 10. Verify the import
sudo -u bareos bash -c "
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-db mysql \
    --user=bareos \
    --password='${DB_PASS}' \
    bareos \
    -e 'SELECT COUNT(*) as total_jobs FROM Job; SELECT COUNT(*) as total_files FROM File LIMIT 1;'
"
# You should see a non-zero job count
```

### 8d. Pull Bareos Images and Write Quadlet Files

```bash
# 1. Pull all required images as the bareos user
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  echo "Pulling Bareos images..."
  podman pull docker.io/bareos/bareos-director:24
  podman pull docker.io/bareos/bareos-storage:24
  podman pull docker.io/bareos/bareos-client:24
  podman pull docker.io/bareos/bareos-webui:24
  echo "All images pulled."
  podman images
'

# 2. Write the Director Quadlet file
cat > /home/bareos/.config/containers/systemd/bareos-director.container << 'EOF'
[Unit]
Description=Bareos Director
After=bareos-db.service
Requires=bareos-db.service

[Container]
Image=docker.io/bareos/bareos-director:24

# Configuration volume — restored from backup in the previous steps.
# Contains bareos-dir.conf and all .d/ subdirectories.
Volume=bareos-dir-config.volume:/etc/bareos:z

# State volume — contains bootstrap files and Director internal state.
Volume=bareos-dir-state.volume:/var/lib/bareos:z

# Inject credentials
EnvironmentFile=/home/bareos/.config/bareos/bareos.env

# Connect to the bareos network so it can reach bareos-db by hostname
Network=bareos.network

# bconsole port — exposed on localhost only for security
PublishPort=127.0.0.1:9101:9101

[Service]
Restart=always
TimeoutStartSec=120

[Install]
WantedBy=default.target
EOF

# 3. Write the Storage Daemon Quadlet file
cat > /home/bareos/.config/containers/systemd/bareos-storage.container << 'EOF'
[Unit]
Description=Bareos Storage Daemon
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-storage:24

# Storage Daemon configuration volume
Volume=bareos-sd-config.volume:/etc/bareos:z

# The storage volumes directory — this is where backup data lives.
# This bind-mount points to the directory we restored in step 8b.
# The :z suffix relabels the directory for SELinux container access.
Volume=/srv/bareos-storage/volumes:/var/lib/bareos/storage:z

Network=bareos.network

# Storage Daemon port — accessible from the network for File Daemons
PublishPort=9103:9103

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF

# 4. Write the File Daemon (client) Quadlet file
cat > /home/bareos/.config/containers/systemd/bareos-fd.container << 'EOF'
[Unit]
Description=Bareos File Daemon (Client)
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-client:24
ContainerName=bareos-fd

Volume=bareos-fd-config:/etc/bareos:Z

# Host filesystem — read-only; FileSet paths use /hostfs/ prefix
Volume=/:/hostfs:ro,z

# Podman socket — allows hook scripts to manage containers
Volume=/run/user/1001/podman/podman.sock:/run/podman/podman.sock:z

Network=bareos.network

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF

# 5. Write the WebUI Quadlet file
cat > /home/bareos/.config/containers/systemd/bareos-webui.container << 'EOF'
[Unit]
Description=Bareos WebUI
Documentation=https://docs.bareos.org/IntroductionAndTutorial/BareosWebui.html
After=network-online.target bareos-director.service
Requires=bareos-director.service

[Container]
Image=docker.io/bareos/bareos-webui:24
ContainerName=bareos-webui

# WebUI config volume — restored from backup below (directors.ini, configuration.ini)
Volume=bareos-webui-config.volume:/etc/bareos-webui:Z

# Bind to loopback only; use nginx for HTTPS remote access (see Chapter 17)
PublishPort=127.0.0.1:9100:80

Network=bareos.network

[Service]
Restart=on-failure
RestartSec=10
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
EOF

# 6. Restore the Bareos configuration from backup into the named volumes.
#    If the volumes were already restored in step 8b, skip this.
#    If you are working from a config backup (e.g., git repo):

sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001

  # Create volumes if they do not exist
  for vol in bareos-dir-config bareos-dir-state bareos-sd-config bareos-fd-config bareos-webui-config; do
    podman volume create "$vol" 2>/dev/null || true
  done

  # Restore Director config
  DIR_CONFIG=$(podman volume inspect bareos-dir-config --format "{{.Mountpoint}}")
  cp -r /mnt/backup-drive/bareos-config/director/* "$DIR_CONFIG/"

  # Restore Storage Daemon config
  SD_CONFIG=$(podman volume inspect bareos-sd-config --format "{{.Mountpoint}}")
  cp -r /mnt/backup-drive/bareos-config/storage/* "$SD_CONFIG/"

  # Restore File Daemon config
  FD_CONFIG=$(podman volume inspect bareos-fd-config --format "{{.Mountpoint}}")
  cp -r /mnt/backup-drive/bareos-config/client/* "$FD_CONFIG/"

  # Restore WebUI config (directors.ini, configuration.ini)
  # These files are small and should be in your config backup.
  WEBUI_CONFIG=$(podman volume inspect bareos-webui-config --format "{{.Mountpoint}}")
  if [ -d /mnt/backup-drive/bareos-config/webui ]; then
    cp -r /mnt/backup-drive/bareos-config/webui/* "$WEBUI_CONFIG/"
    echo "WebUI config restored from backup."
  else
    echo "WARNING: No webui config backup found at /mnt/backup-drive/bareos-config/webui"
    echo "You will need to recreate directors.ini and configuration.ini manually."
    echo "See Chapter 6, Section 12 for the correct content."
  fi

  echo "Configuration restored."
'

# 6. Fix ownership of all restored configs inside volumes
sudo chown -R 1001:1001 \
  /home/bareos/.local/share/containers/storage/volumes/

# 7. Fix SELinux labels
sudo restorecon -Rv \
  /home/bareos/.local/share/containers/storage/

chown -R bareos:bareos /home/bareos/.config/
```

### 8e. Initialize the New Director with the Restored Catalog

```bash
# 1. Start all services
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload

  echo "Starting Storage Daemon..."
  systemctl --user start bareos-storage.service
  sleep 5

  echo "Starting File Daemon..."
  systemctl --user start bareos-fd.service
  sleep 5

  echo "Starting Director..."
  systemctl --user start bareos-director.service
  sleep 10

  echo "Starting WebUI..."
  systemctl --user start bareos-webui.service
  sleep 5

  echo "Service status:"
  systemctl --user status bareos-db.service bareos-director.service \
    bareos-storage.service bareos-fd.service bareos-webui.service --no-pager
'

# 2. Check Director logs for errors
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  journalctl --user -u bareos-director.service -n 50 --no-pager
'
# Look for lines like:
# "bareos-dir: Successfully connected to Database"
# "bareos-dir: Startup OK"
# Any "ERROR" or "Fatal" lines need to be resolved before proceeding.

# 3. Test bconsole connectivity
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'
# At the bconsole prompt, type:
# *status director
# You should see the Director status with no errors.
# *quit to exit.

# 4. Verify the WebUI is accessible
curl -sI http://localhost:9100/ | head -3
# Expected: HTTP/1.1 200 OK  or  302 Found (redirect to /bareos-webui/auth/login)
# If the WebUI is not responding, check its logs:
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-webui.service -n 30 --no-pager
```

### 8f. Verify All Volumes and Jobs in bconsole

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'
```

Run these commands inside bconsole:

```
# List all media (volumes) known to the catalog
*list volumes

# Expected output: a table of all volume names, pool, status, bytes
# Status should be "Full" or "Used" for volumes with data.
# If you see "Error" status, the volume file may be missing or unreadable.

# List the most recent 20 jobs
*list jobs

# Verify that job records exist and have status T (Terminated OK)

# List all clients
*list clients

# Check a specific client's most recent backup
*list joblog jobid=<most_recent_full_job_id>

# Verify a specific volume is readable by the Storage Daemon
*label barcodes
# (Skip this — we are using existing volumes, not labeling new ones)

# Update the volume catalog status based on what is actually on disk.
# This is important after moving storage to a new host.
*update volume=Full-0001 volstatus=Used

# Or update all volumes in a pool at once:
*update slots storage=File1 drive=0
```

If `list volumes` shows volumes with status `Error`, it means the Storage Daemon cannot find the physical file. Verify:

```bash
# Check that the volume file exists on the host
ls -la /srv/bareos-storage/volumes/Full-0001

# Check the Storage Daemon can see it
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage ls -la /var/lib/bareos/storage/
'

# Verify SELinux isn't blocking access
sudo ausearch -m avc -ts recent | grep bareos
```

### 8g. Run a Test Restore of a Specific File

```bash
# 1. Open bconsole
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'

# 2. Start a restore and select a specific file
*restore client=bareos-fd select current all done

# The above command:
# - client=bareos-fd: restore to the bareos-fd client
# - select current: select the most recent backup
# - all done: select all files (use the interactive browser to narrow down)

# 3. Override the restore path for safety
# When bconsole asks "Run Restore job?", set:
*mod
# Then modify:
# Where: /tmp/test-restore

# 4. Confirm and run
*yes

# 5. Monitor the restore job
*wait jobid=<restore_job_id>
*list joblog jobid=<restore_job_id>

# 6. Verify the restored file on the host
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-fd ls -la /tmp/test-restore/
'
```

A successful test restore confirms:
- The Catalog is intact and correctly references volume locations
- The Storage Daemon can read the restored volume files
- The File Daemon can receive and write the data
- The Director correctly orchestrates the entire process

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Bootstrap Files for Catalog-Independent Restore

When the Catalog is unavailable or corrupted, bootstrap files are your lifeline. The `bextract` and `bscan` utilities work directly with volume files, bypassing the Director entirely.

> **Container context:** `bextract` and `bscan` are part of the `bareos-storage` container image. You run them via `podman exec bareos-storage bextract …`. All paths in these commands are **paths inside the container** — for example `/var/lib/bareos/storage` is the container's bind-mounted storage volume, and `/tmp/bextract-output` is a path inside the container's filesystem.
>
> Before running `bextract`, stop the Director to ensure no jobs are active, but **keep the `bareos-storage` container running** so you can exec into it. If you want to run `bextract` with the SD fully stopped (e.g., to avoid any file locking), start a one-shot container with the same volume mounts instead of `podman exec`.

### Method 1: bextract with a Bootstrap File

```bash
# This runs directly against the Storage Daemon volume files.
# No Director, no Catalog, no network connections needed.
# You only need: the volume file(s) and the bootstrap file.

# Copy the bootstrap file to the host (from email, git, or offsite backup)
cp /mnt/backup-drive/bootstrap/BackupCatalog.bsr /tmp/

# Run bextract inside the Storage Daemon container
# -b: bootstrap file
# -V: volume name (the file in /var/lib/bareos/storage/)
# The last two arguments are: storage_device output_directory
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage bextract \
    -b /tmp/BackupCatalog.bsr \
    -V Full-0001 \
    /var/lib/bareos/storage \
    /tmp/bextract-output
'

# View the extracted files
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage ls -la /tmp/bextract-output/
'
```

### Method 2: bscan — Rebuilding the Catalog from Volume Files

If you have the volume files but no catalog dump, `bscan` can rebuild the catalog by reading every block in every volume and reconstructing the job and file records.

**Warning**: `bscan` can take hours or days on large volumes. Use the catalog dump if at all possible.

```bash
# bscan reads volume files and populates a new (empty) catalog database.
# Run this BEFORE starting the Director.

sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001

  # Read the DB password from the env file
  DB_PASS=$(grep MARIADB_PASSWORD ~/.config/bareos/db.env | cut -d= -f2)

  # Scan a single volume
  podman exec bareos-storage bscan \
    -B \
    -u bareos \
    -p "${DB_PASS}" \
    -n bareos \
    -h bareos-db \
    -V Full-0001 \
    FileStorage

  # To scan ALL volumes in the storage directory:
  for vol in $(ls /srv/bareos-storage/volumes/); do
    echo "Scanning volume: $vol"
    podman exec bareos-storage bscan \
      -B \
      -u bareos \
      -p "${DB_PASS}" \
      -n bareos \
      -h bareos-db \
      -V "$vol" \
      FileStorage
  done
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Restoring to a Different Hostname or IP Address

When you rebuild on a new host with a different hostname or IP, Bareos's Catalog records still reference the old hostname. This causes connection failures and name mismatch errors. Here is how to handle each case.

### Director on a New Hostname

The Director's own name is defined in `bareos-dir.conf`. If you change it, all Client and Storage Daemon configurations that reference the Director by name must also be updated.

```
# /etc/bareos/bareos-dir.conf (inside the director container)
Director {
  Name = bareos-dir        # Keep this name unchanged if possible
  DIRport = 9101
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  WorkingDirectory = "/var/lib/bareos"
  PidDirectory = "/var/run/bareos"
  Maximum Concurrent Jobs = 10
  Password = "DIRECTOR-PASSWORD"  # Must match bareos-fd.conf and bareos-sd.conf
  Messages = Daemon
}
```

If you must use a new hostname, update the Name directive and then update all Client and Storage Daemon configurations to reference the new Director name.

### Client on a New IP Address

If the backed-up client machine has a new IP address, update the Address directive in its Client resource in the Director config:

```
# /etc/bareos/bareos-dir.d/client/client1-fd.conf
Client {
  Name = client1-fd
  Address = 192.168.1.150    # Updated to new IP address
  FDPort = 9102
  Catalog = MyCatalog
  Password = "CLIENT-FD-PASSWORD"
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes
}
```

### Updating Catalog Records for a Renamed Client

If the client's hostname changed and its File Daemon now presents a different name, you need to update the Catalog so old job records remain queryable under the new name:

```bash
# In bconsole, update the client name in the catalog
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'

# At bconsole prompt:
*update client
# Follow the interactive prompts to select the client and update its name.

# Alternatively, use SQL directly (use with extreme caution):
# podman exec bareos-db mysql --user=bareos --password=... bareos \
#   -e "UPDATE Client SET Name='new-client-fd' WHERE Name='old-client-fd';"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Testing Your DR Plan: The DR Drill Procedure

A backup system you have never tested is not a backup system — it is a hope. You must perform DR drills regularly. Here is a structured drill procedure.

> **Critical: Run DR drills on a spare/staging host, not on production.**
>
> The drill procedure below intentionally destroys the catalog database to simulate a failure. If run on your production backup server, you will interrupt active backup jobs and temporarily lose catalog access for all clients. Always provision a separate test host, copy the catalog dump and volume files there, and perform the drill in that isolated environment. Only the final "restore and verify" phase of the drill should touch real backup data (read-only from the backup volumes).

### Quarterly DR Drill Checklist

**Before the Drill** (schedule a maintenance window):
- [ ] Notify stakeholders that a DR drill will occur
- [ ] Document the current state: number of jobs, bytes protected, volume count
- [ ] Take a manual catalog dump: `podman exec bareos-director /etc/bareos/scripts/dump-catalog.sh`
- [ ] Note the most recent successful Full backup job ID

**During the Drill**:

```bash
# 1. Simulate catalog loss by stopping the database and renaming the volume
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user stop bareos-director.service bareos-db.service
  DATA=$(podman volume inspect bareos-db-data --format "{{.Mountpoint}}")
  mv "$DATA" "${DATA}.bak"
  mkdir -p "$DATA"
  systemctl --user start bareos-db.service
  sleep 15
  echo "Catalog wiped. MariaDB is running with an empty database."
'

# 2. Import the catalog dump (practicing the recovery procedure)
# (Follow steps 8c above)

# 3. Start the Director and verify jobs are visible
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user start bareos-director.service
  sleep 10
  podman exec -it bareos-director bconsole <<< "list jobs"
'

# 4. Perform a test restore of a specific file
# (Follow steps 8g above)

# 5. Verify the restored file matches the original
sha256sum /original/path/to/file
sha256sum /tmp/test-restore/original/path/to/file
# Hashes must match.
```

**After the Drill**:
- [ ] Record the actual RTO (how long the drill took)
- [ ] Document any steps that failed or were unclear
- [ ] Update the runbook with lessons learned
- [ ] Restore the original database (rename the `.bak` directory back)

```bash
# Restore the original database after the drill
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user stop bareos-director.service bareos-db.service
  DATA=$(podman volume inspect bareos-db-data --format "{{.Mountpoint}}")
  rm -rf "$DATA"
  mv "${DATA}.bak" "$DATA"
  systemctl --user start bareos-db.service bareos-director.service
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Documenting Your Recovery Runbook

A runbook is a step-by-step guide written *before* a disaster, stored *outside* the system that might fail. Here is what your Bareos runbook must contain:

### Runbook Template

```markdown
# Bareos Disaster Recovery Runbook
Last updated: YYYY-MM-DD
Tested: YYYY-MM-DD (DR drill result: RTO=Xh Xm)

[↑ Back to Table of Contents](#table-of-contents)

## Contact Information
- Primary admin: Name, phone, email
- Secondary admin: Name, phone, email
- Offsite storage contact: Name, phone

[↑ Back to Table of Contents](#table-of-contents)

## System Inventory
- Director hostname: bareos.example.com
- Director IP: 192.168.1.10
- bareos user UID: 1001
- Storage location: /srv/bareos-storage/volumes/
- Catalog DB name: bareos
- Bareos Director image: docker.io/bareos/bareos-director:24
- Storage Daemon image: docker.io/bareos/bareos-storage:24
- File Daemon image: docker.io/bareos/bareos-client:24
- MariaDB image: docker.io/library/mariadb:10.11

[↑ Back to Table of Contents](#table-of-contents)

## Credential Locations
- DB env file: /home/bareos/.config/bareos/db.env (encrypted backup at: ...)
- Bareos env file: /home/bareos/.config/bareos/bareos.env (encrypted backup at: ...)
- Configuration backup: git repo at git@github.com:org/bareos-config.git

[↑ Back to Table of Contents](#table-of-contents)

## Recovery Steps
1. (Reference Section 8 of Chapter 18)
2. ...

[↑ Back to Table of Contents](#table-of-contents)

## Verification Checklist
- [ ] All services running: systemctl --user status bareos-*.service
- [ ] Catalog accessible: bconsole list jobs
- [ ] Storage volumes visible: bconsole list volumes
- [ ] Test restore successful: bconsole restore ...
```

### Where to Store the Runbook

- Printed copy in the server room
- PDF on a USB drive kept offsite
- In the company wiki (accessible without VPN)
- Emailed to all admins quarterly

The one place *not* to store it: only on the server that might be down when you need it.

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Offsite Storage: Syncing Volumes with rsync and rclone

### rsync to a Remote Server

```bash
# Create a cron job (as bareos user) to sync volumes nightly
sudo -u bareos crontab -e
# Add:
# 0 3 * * * XDG_RUNTIME_DIR=/run/user/1001 /home/bareos/.config/bareos/scripts/sync-offsite.sh

# /home/bareos/.config/bareos/scripts/sync-offsite.sh
cat > /home/bareos/.config/bareos/scripts/sync-offsite.sh << 'EOF'
#!/bin/bash
# Sync Bareos storage volumes to offsite server
set -euo pipefail

OFFSITE_HOST="backup.example.com"
OFFSITE_USER="bareos-sync"
OFFSITE_PATH="/exports/bareos-volumes/"
LOCAL_VOLUMES="/srv/bareos-storage/volumes/"
LOG_FILE="/var/log/bareos-sync.log"

echo "$(date): Starting offsite sync..." >> "$LOG_FILE"

rsync \
  --archive \
  --delete \           # Remove files on destination that no longer exist locally
  --checksum \         # Verify by checksum (slower but safer)
  --human-readable \
  --log-file="$LOG_FILE" \
  --timeout=300 \
  "${LOCAL_VOLUMES}" \
  "${OFFSITE_USER}@${OFFSITE_HOST}:${OFFSITE_PATH}"

echo "$(date): Offsite sync complete." >> "$LOG_FILE"
EOF

chmod 750 /home/bareos/.config/bareos/scripts/sync-offsite.sh
```

### rclone to Cloud Object Storage (S3-compatible)

```bash
# Install rclone
dnf install -y rclone

# Configure rclone for your cloud provider (interactive)
sudo -u bareos bash -c 'rclone config'
# Follow the prompts to add your S3/B2/Wasabi/etc. remote.
# Name it "bareos-offsite"

# Sync volumes to cloud (run as bareos user, nightly via cron)
sudo -u bareos bash -c '
rclone sync \
  /srv/bareos-storage/volumes/ \
  bareos-offsite:my-bucket/bareos-volumes/ \
  --transfers=4 \
  --checkers=8 \
  --progress \
  --log-file=/var/log/bareos-rclone.log \
  --log-level=INFO
'

# Also sync the catalog dump
sudo -u bareos bash -c '
rclone sync \
  ~/.local/share/containers/storage/volumes/bareos-dir-config/_data/catalog-backup/ \
  bareos-offsite:my-bucket/bareos-catalog/ \
  --include="*.sql.gz" \
  --log-file=/var/log/bareos-rclone.log \
  --log-level=INFO
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. SELinux: Re-labeling After Restoring Files

SELinux is always enforcing in our setup. After restoring files from backup, their SELinux context labels may be wrong — Bareos stores them as file attributes, but the restored location may require different labels than the original.

### Understanding SELinux Contexts in Restores

When Bareos backs up a file, it stores the SELinux extended attributes (the `security.selinux` xattr). When it restores the file, it attempts to restore those attributes. However, if:
- The restore target path is different from the original
- The restored file is on a filesystem that was freshly formatted
- The policy on the new host differs from the old host

...the stored context may be wrong or absent.

### Re-labeling After Restore

```bash
# After a restore to /tmp/bareos-restore, re-label everything
# according to the policy's default contexts for those paths
sudo restorecon -Rv /tmp/bareos-restore/

# For specific directories that have known correct contexts:
# Example: restoring /var/www/html/
sudo restorecon -Rv /var/www/html/

# For the Bareos storage directory itself:
sudo restorecon -Rv /srv/bareos-storage/

# After restoring container volumes:
sudo restorecon -Rv /home/bareos/.local/share/containers/storage/volumes/

# Verify the context of a specific file
ls -laZ /var/www/html/index.html
# Expected: system_u:object_r:httpd_sys_content_t:s0

# If a file has the wrong context and you know the correct one:
chcon -t httpd_sys_content_t /var/www/html/index.html
# But prefer restorecon over chcon — restorecon is persistent across relabels.
```

### Checking for SELinux Denials After Restore

```bash
# Check the audit log for denials related to restored files
sudo ausearch -m avc -ts today | grep -E "bareos|restore"

# Generate a human-readable policy recommendation
sudo audit2allow -a -l

# Example: if Bareos's File Daemon can't read a restored file:
sudo ausearch -m avc -ts recent | audit2allow -M bareos-restore-local
sudo semodule -i bareos-restore-local.pp
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Lab 18-1: Full Catalog Backup and Restore on the Same Host

**Objective**: Verify that your `BackupCatalog` job works and that you can restore the Catalog from the backup on the same host.

**Prerequisites**: Bareos is running, at least one `Full` backup job has completed successfully.

### Step 1: Run the BackupCatalog Job

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec -it bareos-director bconsole
'

# In bconsole:
*run job=BackupCatalog yes
*wait
*list joblog jobid=<catalog_backup_job_id>
```

Verify the job completed with status `T` (Terminated OK).

### Step 2: Locate the Catalog Dump

```bash
sudo -u bareos bash -c '
  ls -la ~/.local/share/containers/storage/volumes/bareos-dir-config/_data/catalog-backup/
'
# You should see a file like: bareos-catalog-20260224-030000.sql.gz
```

### Step 3: Simulate Catalog Loss

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user stop bareos-director.service bareos-db.service
'

# Rename (not delete) the database volume to simulate loss
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  DATA=$(podman volume inspect bareos-db-data --format "{{.Mountpoint}}")
  sudo mv "$DATA" "${DATA}.lab-backup"
  sudo mkdir -p "$DATA"
  sudo chown bareos:bareos "$DATA"
'

sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user start bareos-db.service
  sleep 20
  echo "Database restarted with empty catalog"
'
```

### Step 4: Restore the Catalog

```bash
CATALOG_DUMP=$(sudo -u bareos ls ~/.local/share/containers/storage/volumes/bareos-dir-config/_data/catalog-backup/*.sql.gz | tail -1)
DB_PASS=$(sudo -u bareos grep MARIADB_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)
ROOT_PASS=$(sudo -u bareos grep MARIADB_ROOT_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)

sudo -u bareos bash -c "
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-db mysql --user=root --password='${ROOT_PASS}' \
    -e 'CREATE DATABASE IF NOT EXISTS bareos CHARACTER SET utf8mb4;'
  zcat '${CATALOG_DUMP}' | podman exec -i bareos-db mysql \
    --user=bareos --password='${DB_PASS}' bareos
  echo 'Catalog restored.'
"
```

### Step 5: Restart and Verify

```bash
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user start bareos-director.service
  sleep 10
  podman exec bareos-director bconsole <<< "list jobs"
'
# Verify that all previous jobs are visible in the output.

# Clean up: remove the simulated-loss backup
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  DATA=$(podman volume inspect bareos-db-data --format "{{.Mountpoint}}")
  sudo rm -rf "${DATA}.lab-backup"
'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Lab 18-2: Simulate Total Loss and Rebuild from Backup

**Objective**: Completely remove all Bareos containers and named volumes, then rebuild from scratch using offsite backups.

**Prerequisites**: You have completed Lab 18-1. You have copies of your catalog dump, volume files, configuration files, and env files in a separate location (e.g., `/mnt/lab-backup/`).

```bash
# --- PREPARATION: Copy all assets to the "offsite" location ---
sudo mkdir -p /mnt/lab-backup/{volumes,catalog,config/env,config/quadlet}

# Copy storage volumes
sudo rsync -av /srv/bareos-storage/volumes/ /mnt/lab-backup/volumes/

# Copy catalog dump
sudo -u bareos bash -c '
  cp ~/.local/share/containers/storage/volumes/bareos-dir-config/_data/catalog-backup/*.sql.gz \
     /mnt/lab-backup/catalog/
'

# Copy config
sudo -u bareos bash -c '
  cp ~/.config/bareos/db.env /mnt/lab-backup/config/env/
  cp ~/.config/bareos/bareos.env /mnt/lab-backup/config/env/
  cp ~/.config/containers/systemd/*.container /mnt/lab-backup/config/quadlet/
  cp ~/.config/containers/systemd/*.network /mnt/lab-backup/config/quadlet/
  cp ~/.config/containers/systemd/*.volume /mnt/lab-backup/config/quadlet/
'

echo "Assets backed up to /mnt/lab-backup/"

# --- SIMULATE TOTAL LOSS ---
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  echo "Stopping all services..."
  systemctl --user stop bareos-director.service bareos-storage.service \
    bareos-fd.service bareos-db.service 2>/dev/null || true

  echo "Removing all containers..."
  podman rm -f bareos-director bareos-storage bareos-fd bareos-db 2>/dev/null || true

  echo "Removing all named volumes..."
  for vol in bareos-db-data bareos-dir-config bareos-dir-state bareos-sd-config bareos-fd-config; do
    podman volume rm "$vol" 2>/dev/null || true
  done

  echo "Removing Quadlet files..."
  rm -f ~/.config/containers/systemd/bareos-*.container
  rm -f ~/.config/containers/systemd/bareos-*.network
  rm -f ~/.config/containers/systemd/bareos-*.volume
  rm -f ~/.config/bareos/db.env ~/.config/bareos/bareos.env

  systemctl --user daemon-reload
  echo "Total loss simulated."
'

# Wipe the storage volumes too
sudo rm -rf /srv/bareos-storage/volumes/*
echo "Storage volumes wiped."

# --- REBUILD FROM BACKUP ---
# Now follow the complete procedure from Section 8:
# 8a: User already exists, lingering already enabled. Re-create storage dir:
sudo mkdir -p /srv/bareos-storage/volumes
sudo chown bareos:bareos /srv/bareos-storage/volumes
sudo semanage fcontext -a -t bareos_store_t "/srv/bareos-storage/volumes(/.*)?" 2>/dev/null || true
sudo restorecon -Rv /srv/bareos-storage/volumes/

# 8b: Restore storage volumes
sudo rsync -av /mnt/lab-backup/volumes/ /srv/bareos-storage/volumes/
sudo chown -R bareos:bareos /srv/bareos-storage/volumes/
sudo restorecon -Rv /srv/bareos-storage/volumes/

# 8c: Restore env files and start DB (follow procedure above)
sudo cp /mnt/lab-backup/config/env/db.env /home/bareos/.config/bareos/db.env
sudo cp /mnt/lab-backup/config/env/bareos.env /home/bareos/.config/bareos/bareos.env
sudo chown bareos:bareos /home/bareos/.config/bareos/db.env \
  /home/bareos/.config/bareos/bareos.env
sudo chmod 600 /home/bareos/.config/bareos/db.env \
  /home/bareos/.config/bareos/bareos.env

# 8d: Restore Quadlet files
sudo -u bareos bash -c '
  cp /mnt/lab-backup/config/quadlet/*.container ~/.config/containers/systemd/
  cp /mnt/lab-backup/config/quadlet/*.network ~/.config/containers/systemd/
  cp /mnt/lab-backup/config/quadlet/*.volume ~/.config/containers/systemd/
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user daemon-reload
  systemctl --user start bareos-db.service
  sleep 20
'

# Import catalog
CATALOG_DUMP=$(ls /mnt/lab-backup/catalog/*.sql.gz | tail -1)
DB_PASS=$(sudo -u bareos grep MARIADB_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)
ROOT_PASS=$(sudo -u bareos grep MARIADB_ROOT_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)
sudo -u bareos bash -c "
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-db mysql --user=root --password='${ROOT_PASS}' \
    -e 'CREATE DATABASE IF NOT EXISTS bareos CHARACTER SET utf8mb4;'
  zcat '${CATALOG_DUMP}' | podman exec -i bareos-db mysql \
    --user=bareos --password='${DB_PASS}' bareos
"

# Start remaining services
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  systemctl --user start bareos-storage.service bareos-fd.service bareos-director.service
  sleep 10
  echo "Services status:"
  systemctl --user status bareos-director.service --no-pager
'

# Verify
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-director bconsole <<< "list jobs"
'
echo "Rebuild complete. Verify all jobs are visible above."
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 17. Lab 18-3: Restore a Single File Using a Bootstrap File

**Objective**: Restore a file from a Bareos volume using only a bootstrap file — no running Director or Catalog required.

**Prerequisites**: You have a `.bsr` file (from email, git, or `~/.local/share/containers/storage/volumes/bareos-dir-state/_data/`), and the corresponding volume file exists in `/srv/bareos-storage/volumes/`.

```bash
# 1. Identify the bootstrap file for the job you want to restore
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  ls ~/.local/share/containers/storage/volumes/bareos-dir-state/_data/*.bsr
'
# Example output: /home/bareos/.local/.../bareos-dir-state/_data/BackupClient1.bsr

# 2. View the bootstrap file to understand what volume and files it references
sudo -u bareos cat ~/.local/share/containers/storage/volumes/bareos-dir-state/_data/BackupClient1.bsr

# 3. Verify the referenced volume file exists
ls -la /srv/bareos-storage/volumes/Full-0001

# 4. Copy the bootstrap file into the Storage Daemon container
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman cp \
    ~/.local/share/containers/storage/volumes/bareos-dir-state/_data/BackupClient1.bsr \
    bareos-storage:/tmp/restore.bsr
'

# 5. Create an output directory inside the Storage Daemon container
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage mkdir -p /tmp/bsr-restore
'

# 6. Run bextract using the bootstrap file
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage bextract \
    -b /tmp/restore.bsr \
    /var/lib/bareos/storage \
    /tmp/bsr-restore
'
# bextract will print each file as it extracts it.
# Expected output:
# bextract: butil.c:304 Using device: "/var/lib/bareos/storage" for reading.
# 1 file(s) restored.

# 7. View the extracted files
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman exec bareos-storage find /tmp/bsr-restore -type f
'

# 8. Copy the extracted files to the host
sudo -u bareos bash -c '
  XDG_RUNTIME_DIR=/run/user/1001
  podman cp bareos-storage:/tmp/bsr-restore /tmp/lab18-3-output
'

# 9. Verify the restored file(s)
ls -la /tmp/lab18-3-output/
# Fix SELinux context on the restored files
sudo restorecon -Rv /tmp/lab18-3-output/

echo "Bootstrap restore complete. Files are in /tmp/lab18-3-output/"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 18. Summary

Disaster recovery is not a feature you add after everything else works — it is the core purpose of a backup system. In this chapter you learned:

- **RTO and RPO** define your recovery requirements. Design your backup frequency and DR procedures around these numbers before writing a single line of configuration.
- **Three critical assets**: storage volumes, the Catalog, and configuration files. All three must be protected, ideally offsite.
- **The Catalog is your most fragile asset**. The `BackupCatalog` job must run daily, and its output must be stored somewhere other than the Director host. Bootstrap files and email delivery of `.bsr` files provide a second line of defense.
- **Bootstrap files** (`bextract`, `bscan`) let you recover data even when the entire Director and Catalog are gone. They are your emergency fallback.
- **Total rebuild** from scratch follows a specific order: host + user setup → storage volumes → Catalog database → images + Quadlet files → Director initialization → verification → test restore. Following this order prevents dependency failures.
- **SELinux** must be addressed at every stage of recovery. Use `restorecon -Rv` after restoring any files, and check `ausearch -m avc` if anything fails to start.
- **DR drills** are mandatory. An untested recovery plan is not a plan. Schedule quarterly drills, measure your actual RTO, and update your runbook based on what you learn.
- **The runbook** must exist on paper and in a location that does not depend on the system that might be down. Print it, store it offsite, email it to all admins.

The most important thing you can do right now is run Lab 18-1 and Lab 18-2. Do not wait for a real disaster to discover that your catalog dumps are empty or your volume files are unreadable. Test everything today.

---

[↑ Back to Table of Contents](#table-of-contents)
