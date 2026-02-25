# Chapter 8: Restoring Data

## Table of Contents

- [1. The Restore Philosophy: Test Before You Need It](#1-the-restore-philosophy-test-before-you-need-it)
- [2. How Bareos Restores Work Internally](#2-how-bareos-restores-work-internally)
  - [Critical Point: Multiple Jobs in One Restore](#critical-point-multiple-jobs-in-one-restore)
- [3. The bconsole Restore Wizard](#3-the-bconsole-restore-wizard)
  - [Starting the Restore](#starting-the-restore)
- [3b. The WebUI Restore Browser](#3b-the-webui-restore-browser)
  - [Navigating the File Tree](#navigating-the-file-tree)
  - [Running the Restore from WebUI](#running-the-restore-from-webui)
  - [The Bvfs Cache](#the-bvfs-cache)
- [4. Restore Selection Methods](#4-restore-selection-methods)
  - [Selecting by Directory (most common)](#selecting-by-directory-most-common)
  - [Selecting Specific Files](#selecting-specific-files)
  - [Find Files by Pattern](#find-files-by-pattern)
  - [Mark/Unmark Entire Tree](#markunmark-entire-tree)
- [5. Restore to Original Path vs. Alternate Path](#5-restore-to-original-path-vs-alternate-path)
  - [Restore Options Explained](#restore-options-explained)
- [6. Partial Restores: Single Files and Directories](#6-partial-restores-single-files-and-directories)
  - [Restoring a Single File via bconsole](#restoring-a-single-file-via-bconsole)
  - [Restoring to See "What Did This File Look Like Last Week?"](#restoring-to-see-what-did-this-file-look-like-last-week)
- [7. Restoring from an Incremental Chain](#7-restoring-from-an-incremental-chain)
- [8. The Restore Job Resource](#8-the-restore-job-resource)
- [9. Restoring to a Different Client](#9-restoring-to-a-different-client)
  - [Requirements](#requirements)
  - [Interactive Restore to a Different Client](#interactive-restore-to-a-different-client)
  - [Non-Interactive (Scripted)](#non-interactive-scripted)
- [10. Verifying Restored Data](#10-verifying-restored-data)
  - [File Count and Size Comparison](#file-count-and-size-comparison)
  - [Checksum Verification](#checksum-verification)
  - [Using Bareos Verify](#using-bareos-verify)
- [11. Restoring Without the Catalog: Using bscan and bextract](#11-restoring-without-the-catalog-using-bscan-and-bextract)
  - [bscan: Rebuilding the Catalog from Volumes](#bscan-rebuilding-the-catalog-from-volumes)
  - [bextract: Extracting Files Without the Catalog](#bextract-extracting-files-without-the-catalog)
  - [bls: Listing Volume Contents](#bls-listing-volume-contents)
- [12. Lab 8-1: Full Directory Restore Walkthrough](#12-lab-8-1-full-directory-restore-walkthrough)
- [13. Lab 8-2: Selective File Restore](#13-lab-8-2-selective-file-restore)
- [14. Lab 8-3: Restore to Alternate Path](#14-lab-8-3-restore-to-alternate-path)
- [15. Summary](#15-summary)

## 1. The Restore Philosophy: Test Before You Need It

Restoring data is the entire point of a backup system, yet it is the most frequently neglected operation. The consequences of discovering a broken restore procedure during a real disaster are catastrophic.

**Rule**: Run a restore drill at least once per month. Document the results. Time the restore and verify the restored data against the source.

Specifically, for each critical system:
1. Restore to an alternate path (never overwrite live data during testing)
2. Verify file counts and sizes match expectations
3. Verify file contents using checksums
4. For databases: import the dump and run queries
5. For application configs: verify the application starts correctly with the restored config

This chapter gives you all the tools to perform these drills efficiently.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. How Bareos Restores Work Internally

Understanding the restore mechanism prevents surprises. The restore process is the reverse of backup:

```
Restore Data Flow

Director
  │
  ├── Query Catalog: "Which jobs contain /home/alice/documents/?"
  ├── Query Catalog: "Which Volumes contain those jobs?"
  ├── Instruct Storage Daemon: "Read from Volume Inc-0042, seek to offset 1,234,567"
  │
  └── Instruct File Daemon: "Receive data and write to /tmp/bareos-restores/home/alice/"

Storage Daemon (bareos-storage container)
  │
  ├── Open Volume file: /srv/bareos-storage/volumes/Inc-0042
  ├── Seek to offset 1,234,567 (catalog provides exact position)
  └── Stream data directly to File Daemon

File Daemon (container: bareos-fd)
  │
  ├── Receive data stream from Storage Daemon
  ├── Verify checksums
  ├── Write files to restore path
  └── Restore file permissions, ownership, timestamps, ACLs, xattrs
```

### Critical Point: Multiple Jobs in One Restore

When restoring files that span multiple backup jobs (e.g., a Full backup plus several Incrementals), Bareos:

1. Queries the Catalog to find the **most recent version** of each file
2. Identifies which job (and therefore which Volume) contains each file's latest version
3. Reads from **multiple Volumes** in a single restore operation

This is completely transparent to you in the `restore` wizard. Bareos handles the complexity of assembling the correct version of each file automatically.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. The bconsole Restore Wizard

The `restore` command in bconsole is an interactive wizard. It walks you through:
1. Which client's data to restore
2. Which backup time/job to restore from
3. Which specific files to include
4. Where to restore to
5. Confirmation before execution

### Starting the Restore

```
*restore
```

The wizard presents selection mode options:

```
To select the JobIds, you have the following choices:
     1: List last 20 Jobs run
     2: List Jobs where a given File is saved
     3: Enter list of comma separated JobIds to select
     4: Enter SQL list command
     5: Select the most recent backup for a client
     6: Select backup for a client before a specified time
     7: Enter a list of files to restore
     8: Enter a list of files to restore before a specified time
     9: Find the JobIds of the most recent backup for a client
    10: Find the JobIds for a backup for a client before a specified time
    11: Enter a list of directories to restore for found JobIds
    12: Select full restore to a specified Job date
    13: Cancel
Select item:  (1-13):
```

For most restores, **option 5** (most recent backup for a client) is the right starting point:

```
Select item:  (1-13): 5

Defined Clients:
     1: bareos-fd
Select the Client (1-1): 1
```

Bareos then builds a virtual filesystem representing the most recent state of all backed-up files:

```
Building directory tree for JobId(s) 1,2,3,4,5 ...
 89,412 files inserted into the tree.

You are now entering file selection mode where you add (mark) and
remove (unmark) files to be restored. No files are initially added.
Done adding files: 89,412 files, including directories.

cwd is: /
$ help

  Command    Description
  =======    ===========
  cd         change current directory
  count      count marked files in and below the current directory
  dir        list current directory
  done       leave file selection mode
  estimate   estimate restore size
  find       find files by pattern
  ls         list current directory
  lsmark     list currently marked files
  mark       mark file to be restored
  markdir    mark all files in directory tree to be restored
  pwd        print current working directory
  unmark     unmark file to be restored
  unmarkdir  unmark all files in directory tree
  quit       quit without doing restore
  ?          print help
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 3b. The WebUI Restore Browser

The Bareos WebUI provides a **graphical file-tree browser** for restores. It is the recommended interface for day-to-day file-level restores — it is faster to navigate than the bconsole wizard and does not require memorising commands.

The file-tree browser is powered by the **Bvfs (Bareos Virtual Filesystem) cache**, a set of Catalog tables that the Director populates after each backup job. If the cache is stale or empty, the browser will be slow or show no files.

### Navigating the File Tree

1. Log in to the WebUI at `http://localhost:9100/bareos-webui`
2. Go to **Restore** in the left sidebar
3. Select the **Client** to restore from (e.g., `bareos-fd`)
4. Select the **Backup Job** or a point-in-time — the WebUI shows the most recent available backup
5. A file-tree appears. Navigate by clicking directories, or use the search box to find files by name
6. Tick the checkboxes next to files or directories you want to restore. Use the top-level checkbox to select everything
7. Click **Restore** when your selection is complete

### Running the Restore from WebUI

In the **Restore** dialog that appears:

| Field | Recommended value |
|-------|-------------------|
| **Client** | The client that will receive the files (can differ from the backup client) |
| **Restore Location** | `/tmp/bareos-restores` for test restores; `/` for full DR restores |
| **Replace** | `never` for test restores (skip files that already exist); `always` for DR |
| **Restore Job** | Leave as default (`RestoreFiles`) |

Click **Run Restore**. The job appears in **Jobs → Running** and then in **Jobs → All Jobs** when complete.

### The Bvfs Cache

The Bvfs cache must be populated for the file browser to work. If you see an empty tree or very slow loading after a large backup, rebuild the cache:

```bash
# Rebuild Bvfs cache for all jobs
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< ".bvfs_update"

# Or rebuild only for a specific client
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< ".bvfs_update client=bareos-fd"
```

To keep the cache always current, add a `RunScript` to your backup jobs (see [Chapter 17](./17-monitoring-alerts.md)):

```
RunScript {
  Runs When   = After
  Runs On Client = No
  Command     = ".bvfs_update"
}
```

> **Note:** The bconsole wizard (Section 3) and the WebUI browser (this section) both trigger the same restore mechanism in the Director. Use whichever you prefer — the outcome is identical.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Restore Selection Methods

Inside the `restore` file selection shell, use these commands to select files:

### Selecting by Directory (most common)

```bash
# Navigate to the directory you want to restore
$ cd /home/alice

# Mark all files in this directory and all subdirectories
$ mark *

# Verify what's marked
$ count
50 files marked to be restored.

# Or mark a specific subdirectory
$ mark documents/

# Exit selection and proceed to restore
$ done
```

### Selecting Specific Files

```bash
$ cd /etc
$ ls
# Shows all files in /etc as of the backed-up state

# Mark specific files
$ mark passwd
$ mark shadow
$ mark sudoers

$ lsmark
/etc/passwd
/etc/shadow
/etc/sudoers
```

### Find Files by Pattern

```bash
# Find all .conf files anywhere
$ find *.conf
# Lists all matching files in the tree

# Mark all found results
$ mark *.conf
```

### Mark/Unmark Entire Tree

```bash
# Mark everything (full restore)
$ cd /
$ mark *
$ count
89,412 files marked

# Or unmark everything and start over
$ unmark *
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Restore to Original Path vs. Alternate Path

**Never restore to the original path during a drill.** Always restore to an alternate path first:

```
After file selection, Bareos asks:

Bootstrap records written to /var/lib/bareos/bareos.restore.1.bsr
The restore job will require the following Volumes:

   Full-0001
   Inc-0003

2,048 files selected to be restored.

Run Restore job
JobName:    RestoreFiles
Bootstrap:  /var/lib/bareos/bareos.restore.1.bsr
Where:      /tmp/bareos-restores     ← THIS is the restore destination
Replace:    Always
FileSet:    LinuxAll
Backup Client:  bareos-fd
Restore Client: bareos-fd
Storage:    File
JobId:      *None*
When:       2026-02-24 23:15:00
Catalog:    MyCatalog
Priority:   10
Plugin Options: *None*
OK to run? (yes/mod/no):
```

The `Where:` field is where restored files will be written. By default Bareos uses `/tmp/bareos-restores`. You can change this:

```
OK to run? (yes/mod/no): mod

Parameters to modify:
     1: Level
     2: Storage
     3: Job
     4: FileSet
     5: Restore Client
     6: When
     7: Priority
     8: Bootstrap
     9: Where
    10: File Relocation
    11: Replace
    12: JobId
    13: Plugin Options

Select parameter to modify (1-13): 9

Please enter the full path prefix for restore (/ for none): /mnt/restore-test
```

### Restore Options Explained

**Where**: The path prefix. Bareos strips the original path and prepends this:
- `Where = /tmp/bareos-restores` → `/etc/passwd` is restored to `/tmp/bareos-restores/etc/passwd`
- `Where = /` → Restore to original path (live restore — use with extreme caution)
- `Where = /mnt/restore-test` → Restore to an alternate mount

**Replace**: What to do if the file already exists at the destination:
- `Always` — Always overwrite (default for recovery situations)
- `IfNewer` — Overwrite only if the backup version is newer
- `IfOlder` — Overwrite only if the backup version is older
- `Never` — Never overwrite (safe for testing: restored files are not written if they already exist at the destination)

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Partial Restores: Single Files and Directories

### Restoring a Single File via bconsole

```
*restore
Select item: 2   ← "List Jobs where a given File is saved"

Enter filename (no path): passwd

+--------+---------------------+-------+-----------+
| JobId  | StartTime           | Level | Name      |
+--------+---------------------+-------+-----------+
| 5      | 2026-02-24 23:00:05 | I     | BackupLocalHost |
| 1      | 2026-02-18 23:00:05 | F     | BackupLocalHost |
+--------+---------------------+-------+-----------+

# Select the JobId containing the version you want
Enter the JobId(s), comma separated: 1

$ find /etc/passwd
/etc/passwd

$ mark /etc/passwd
1 file marked.

$ done
```

### Restoring to See "What Did This File Look Like Last Week?"

This is one of the most common real-world restore requests:

```
*restore
Select item: 6   ← "Select backup for a client before a specified time"

Enter date as YYYY-MM-DD HH:MM:SS: 2026-02-17 23:59:59

# Bareos selects the most recent backup BEFORE the specified date
# The virtual filesystem shows the state of files at that point in time

$ cd /home/alice/documents
$ ls
# Shows the directory as it existed on 2026-02-17

$ mark important-report.docx
$ done
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Restoring from an Incremental Chain

When you select "most recent backup" and the most recent backup is an Incremental, Bareos automatically walks the backup chain:

```
Full backup (Job 1, Sunday):    /home/alice/ — 1000 files
Incremental (Job 2, Monday):    /home/alice/doc1.txt changed
Incremental (Job 3, Tuesday):   /home/alice/doc2.txt changed
Incremental (Job 4, Wednesday): /home/alice/doc3.txt changed

Restore as of Wednesday = Job1 (most files) + Job2 (doc1.txt) + Job3 (doc2.txt) + Job4 (doc3.txt)
```

Bareos resolves this automatically — you just say "restore the most recent backup" and it figures out which version of each file to retrieve from which job and volume.

You can see the job chain in the restore output:

```
Building directory tree for JobId(s) 1,2,3,4 ...
 1,003 files inserted into the tree and 3 files updated.
```

The "3 files updated" means 3 files from the incremental jobs replaced older versions from the full backup in the virtual tree.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. The Restore Job Resource

The Director needs a `Restore` job defined to handle restore operations. Bareos creates a default one during installation:

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/RestoreFiles.conf > /dev/null <<'EOF'
Job {
  Name = "RestoreFiles"
  Type = Restore
  Client = bareos-fd
  Storage = File
  FileSet = "LinuxAll"    # not actually used in restore — the bootstrap drives it
  Pool = Incremental      # not used; volumes are determined by bootstrap
  Messages = Standard
  Where = /tmp/bareos-restores    # default restore path
}
EOF
```

The `Where` directive here is the default. Operators can always override it interactively in the restore wizard or with the `mod` option.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Restoring to a Different Client

A common disaster recovery scenario: the original client is destroyed, and you need to restore its data to a new host. Bareos supports this with the **Restore Client** option.

### Requirements

1. The new host must have the Bareos File Daemon installed and configured to accept the Director's connection (via RPM for a remote host, or via the `bareos-client:24` container for a Podman host)
2. The restore path must exist and be writable on the new client
3. File ownership after restore will use the UIDs/GIDs as stored in the backup; these must make sense on the new host

### Interactive Restore to a Different Client

```
*restore

[select files]

OK to run? (yes/mod/no): mod

Select parameter to modify (1-13): 5   ← "Restore Client"

The defined Restore Clients are:
     1: bareos-fd       (original)
     2: new-server-fd   (new host — must be defined in Director config)

Select Restore Client: 2
```

### Non-Interactive (Scripted)

```
*restore client=bareos-fd restoreclient=new-server-fd
         where=/data/restored
         select all done yes
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Verifying Restored Data

After every restore, verify the data:

### File Count and Size Comparison

```bash
# Compare source directory file count
find /etc -type f | wc -l
# Expected: e.g., 1,547

# Compare restored directory file count
find /tmp/bareos-restores/etc -type f | wc -l
# Expected: same as source

# Compare total sizes
du -sh /etc
# Expected: e.g., 45M

du -sh /tmp/bareos-restores/etc
# Expected: approximately same (minor differences acceptable for /proc-derived files)
```

### Checksum Verification

```bash
# Generate checksums of a sample of source files
find /home/alice/documents -name "*.docx" -exec md5sum {} \; > /tmp/source-checksums.txt

# Generate checksums of same files restored
find /tmp/bareos-restores/home/alice/documents -name "*.docx" -exec md5sum {} \; \
  | sed 's|/tmp/bareos-restores||' > /tmp/restored-checksums.txt

# Compare
diff /tmp/source-checksums.txt /tmp/restored-checksums.txt
# Expected: no output (files are identical)
```

### Using Bareos Verify

Bareos has a built-in `Verify` job type that compares the current filesystem against a previous backup:

```bareos
Job {
  Name = "VerifyBackup"
  Type = Verify
  Level = VolumeToCatalog    # Compare Volume contents against Catalog records
  Client = bareos-fd
  FileSet = "RHEL10-Standard"
  Messages = Standard
  Storage = File
  Pool = Full
  JobId = 0                  # 0 = most recent backup
}
```

Verify levels:
- `InitCatalog` — Record current file attributes in Catalog (baseline for future verification)
- `Catalog` — Compare current filesystem attributes to Catalog records
- `VolumeToCatalog` — Read Volume and compare contents to Catalog
- `DiskToCatalog` — Compare current disk files to Catalog records
- `Data` — Verify Volume data integrity (full re-read of backup data)

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Restoring Without the Catalog: Using bscan and bextract

If you lose both the Catalog database and the Catalog backup, you can still recover data from the raw Volume files using two low-level tools.

### bscan: Rebuilding the Catalog from Volumes

`bscan` reads Bareos Volume files and (re-)populates the Catalog with the records it finds:

```bash
# Inside the Storage Daemon container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-storage \
  bscan \
    -c /etc/bareos \
    -d 10 \
    -n bareos \
    -u bareos \
    -p "CHANGEME_BAREOS_DB_PASSWORD" \
    -m \
    -s \
    FileStorage
```

`bscan` parameters:
- `-c` — Config file path
- `-d 10` — Debug level (0-200; 10 gives informative output)
- `-n` — Database name
- `-u` — Database user
- `-p` — Database password
- `-m` — Update volume dates in Catalog
- `-s` — Update Volume record in Catalog

This can take hours for large Volumes (it reads every byte) but reconstructs a complete Catalog. After it finishes, normal `restore` operations work again.

### bextract: Extracting Files Without the Catalog

`bextract` reads Volume files and extracts data without needing the Catalog at all:

```bash
# Extract all files from a Volume to a directory
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-storage \
  bextract \
    -c /etc/bareos \
    -V Full-0001 \
    /srv/bareos-storage/volumes \
    /tmp/emergency-restore

# Extract only specific files using a bootstrap
bextract \
  -c /etc/bareos \
  -b /var/lib/bareos/bareos-fd.bsr \
  /srv/bareos-storage/volumes \
  /tmp/emergency-restore
```

`bextract` is the "break glass in emergency" tool. It works even with no Catalog, no bootstrap file — just the raw Volume files on disk.

### bls: Listing Volume Contents

Before extracting, use `bls` to see what is in a Volume:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-storage \
  bls \
    -c /etc/bareos \
    -V Full-0001 \
    /srv/bareos-storage/volumes

# Output:
# bls: butil.c:304 Using Device "FileStorage" to read.
# Volume Full-0001 contains:
# JobId: 1  Job: BackupLocalHost.2026-02-18_23.00.05_03
#   Client: bareos-fd  Pool: Full  FileSet: RHEL10-Standard
#   2026-02-18 23:15:22
#  89,412 files
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 8-1: Full Directory Restore Walkthrough

This lab shows both the `bconsole` restore wizard and the **WebUI restore browser**. Both produce the same result.

```bash
# Step 1: Create test data to restore
sudo mkdir -p /tmp/restore-lab-source
sudo tee /tmp/restore-lab-source/testfile1.txt > /dev/null <<'EOF'
This is test file 1 for restore lab
EOF
sudo tee /tmp/restore-lab-source/testfile2.txt > /dev/null <<'EOF'
This is test file 2 for restore lab
Contains: important data
EOF

# Step 2: Modify the FileSet to include /tmp/restore-lab-source
# (For this lab only — add to Include block)
# Add: File = /tmp/restore-lab-source

# Step 3: Run a Full backup including the test data
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'EOF'
reload
run job=BackupLocalHost level=Full yes
wait
messages
quit
EOF

# Step 4: Record the JobId of the backup
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<< "list jobs"

# Step 5: Delete the original data (simulating a disaster)
sudo rm -rf /tmp/restore-lab-source
echo "Source data deleted. Starting restore..."
```

**Restore Option A — bconsole wizard:**

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'EOF'
restore
5
1
cd /tmp/restore-lab-source
mark *
done
mod
9
/tmp/restore-lab-destination
yes
wait
messages
quit
EOF
```

**Restore Option B — WebUI browser:**

1. Open `http://localhost:9100/bareos-webui` → **Restore**
2. Select client `bareos-fd`, choose the most recent Full backup
3. Navigate to `/tmp/restore-lab-source` and tick the directory checkbox
4. Click **Restore**, set Restore Location to `/tmp/restore-lab-destination`, Replace = `never`
5. Click **Run Restore** and wait for the job to complete in **Jobs → All Jobs**

```bash
# Step 7: Verify restoration (same regardless of which method you used)
ls -la /tmp/restore-lab-destination/tmp/restore-lab-source/
cat /tmp/restore-lab-destination/tmp/restore-lab-source/testfile1.txt

echo ""
echo "Restore lab complete!"

# Cleanup
sudo rm -rf /tmp/restore-lab-source /tmp/restore-lab-destination
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Lab 8-2: Selective File Restore

```bash
# Create multiple files in a test directory
mkdir -p /tmp/selective-restore-test
for i in $(seq 1 10); do
  echo "Content of file $i" > /tmp/selective-restore-test/file${i}.txt
done

# Run a backup
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'EOF'
run job=BackupLocalHost level=Full yes
wait
quit
EOF
```

**Restore Option A — bconsole wizard (restore only file5.txt):**

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'BEOF'
restore
5
1

cd /tmp/selective-restore-test
ls

mark file5.txt
lsmark

done
mod
9
/tmp/selective-destination

yes
wait
messages
quit
BEOF
```

**Restore Option B — WebUI browser:**

1. Open **Restore** → select client → select the Full backup job
2. Navigate to `/tmp/selective-restore-test`
3. Tick **only** `file5.txt` — leave all other files unticked
4. Click **Restore**, set Restore Location to `/tmp/selective-destination`, Replace = `never`, click **Run Restore**

```bash
# Verify: only file5.txt should be present
ls -la /tmp/selective-destination/tmp/selective-restore-test/
# Expected: only file5.txt

# Cleanup
rm -rf /tmp/selective-restore-test /tmp/selective-destination
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Lab 8-3: Restore to Alternate Path

This lab demonstrates recovering `/etc/hosts` to a test directory — safe because it does not overwrite the live file.

**Restore Option A — bconsole wizard:**

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bconsole <<'BEOF'
restore
5
1

cd /etc
ls hosts

mark hosts
lsmark
# Shows: /etc/hosts

done
mod
9
/tmp/etc-recovery-test

yes
wait
messages
quit
BEOF
```

**Restore Option B — WebUI browser:**

1. Open **Restore** → select client → select the most recent Full backup
2. Navigate to `/etc` in the file tree
3. Tick `hosts`
4. Click **Restore**, set Restore Location to `/tmp/etc-recovery-test`, Replace = `never`, click **Run Restore**

```bash
# Verify the file was restored (same for both methods)
ls -la /tmp/etc-recovery-test/etc/hosts
cat /tmp/etc-recovery-test/etc/hosts

# Compare with the live file
diff /etc/hosts /tmp/etc-recovery-test/etc/hosts
# Expected: no differences (assuming hosts hasn't changed since backup)

echo "Restore to alternate path: SUCCESS"

# Cleanup
rm -rf /tmp/etc-recovery-test
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Summary

In this chapter you mastered Bareos restore operations:

- **The restore philosophy**: Test restores regularly, document results, and time them. A backup is only proven by a successful restore.
- **Internal mechanics**: The Director queries the Catalog for file locations and Volume offsets, then instructs the SD to stream data directly to the FD. Data never flows through the Director.
- **Multiple-job restores**: When restoring from an incremental chain, Bareos assembles the most recent version of each file from the correct job automatically.
- **The bconsole wizard**: `restore` in bconsole provides an interactive virtual filesystem browser. `cd`, `mark`, `unmark`, `find`, and `done` navigate and select files. Essential for scripted and emergency restores.
- **The WebUI restore browser**: A graphical file-tree browser at **Restore** in the WebUI. The recommended interface for day-to-day restores. Powered by the Bvfs cache — run `.bvfs_update` if the tree is empty or slow.
- **Restore destination**: Always use `Where = /tmp/bareos-restores` or a custom alternate path during tests. Use `Where = /` only for real disaster recovery.
- **Restoring to a different client**: Set `Restore Client` to a different host via `mod` in the wizard, or via the Client field in the WebUI restore dialog.
- **Verification**: Always verify restored data with file count comparisons, checksum matching, and `diff`.
- **bscan and bextract**: Emergency tools for recovering data when the Catalog is lost. `bscan` rebuilds the Catalog from Volumes; `bextract` extracts files directly without any Catalog.

---

**Next Chapter:** [Chapter 9: Backing Up Podman Volumes](./09-podman-volume-backups.md)

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 Jaco Steyn — Licensed under CC BY-SA 4.0
