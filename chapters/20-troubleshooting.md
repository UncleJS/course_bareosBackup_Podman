# Chapter 20: Troubleshooting Guide

> **Course:** Bareos Backup on RHEL 10 + Rootless Podman  
> **Environment:** RHEL 10, Bareos 24, rootless Podman, Quadlet/systemd, SELinux enforcing  
> **Bareos user:** `bareos` (UID 1001), sub-UIDs 100000–165535, linger enabled

---

## Table of Contents

- [1. Troubleshooting Philosophy](#1-troubleshooting-philosophy)
  - [The Three-Layer Rule](#the-three-layer-rule)
  - [A Fourth Layer: Container Internals](#a-fourth-layer-container-internals)
  - [The Golden Rule](#the-golden-rule)
- [2. Where All the Logs Are](#2-where-all-the-logs-are)
  - [2.1 systemd Journal (Daemon Logs)](#21-systemd-journal-daemon-logs)
  - [2.2 Bareos Job Log (Catalog)](#22-bareos-job-log-catalog)
  - [2.3 Bareos Configuration Validation Logs](#23-bareos-configuration-validation-logs)
  - [2.4 SELinux Audit Log](#24-selinux-audit-log)
- [3. Common Error: No Route to Client](#3-common-error-no-route-to-client)
  - [What It Looks Like](#what-it-looks-like)
  - [Root Causes and Diagnosis](#root-causes-and-diagnosis)
  - [Fix](#fix)
- [4. Common Error: Authorization Failure](#4-common-error-authorization-failure)
  - [What It Looks Like](#what-it-looks-like)
  - [Root Causes and Diagnosis](#root-causes-and-diagnosis)
  - [Fix](#fix)
- [5. Common Error: Cannot Open Volume](#5-common-error-cannot-open-volume)
  - [What It Looks Like](#what-it-looks-like)
  - [Root Causes and Diagnosis](#root-causes-and-diagnosis)
  - [Fix](#fix)
- [6. Common Error: Catalog Database Error](#6-common-error-catalog-database-error)
  - [What It Looks Like](#what-it-looks-like)
  - [Root Causes and Diagnosis](#root-causes-and-diagnosis)
  - [Fix](#fix)
- [7. Common Error: Max Concurrent Jobs Exceeded](#7-common-error-max-concurrent-jobs-exceeded)
  - [What It Looks Like](#what-it-looks-like)
  - [Explanation](#explanation)
  - [Fix](#fix)
- [8. Jobs Stuck Waiting](#8-jobs-stuck-waiting)
  - [Waiting for Storage Daemon](#waiting-for-storage-daemon)
  - [Waiting for Client](#waiting-for-client)
  - [Waiting for Mount](#waiting-for-mount)
- [9. SELinux Troubleshooting](#9-selinux-troubleshooting)
  - [Understanding AVC Denials](#understanding-avc-denials)
  - [Step-by-Step SELinux Diagnosis](#step-by-step-selinux-diagnosis)
  - [Common SELinux Fixes for Bareos + Podman](#common-selinux-fixes-for-bareos-podman)
- [10. Rootless Podman Troubleshooting](#10-rootless-podman-troubleshooting)
  - [Container Won't Start: Missing Linger](#container-wont-start-missing-linger)
  - [Container Won't Start: Wrong XDG_RUNTIME_DIR](#container-wont-start-wrong-xdg_runtime_dir)
  - [Container Won't Start: Missing subuid/subgid](#container-wont-start-missing-subuidsubgid)
  - [Container Exits Immediately](#container-exits-immediately)
- [11. Quadlet Troubleshooting](#11-quadlet-troubleshooting)
  - [Unit Not Generated](#unit-not-generated)
  - [Unit Generated But Fails to Start](#unit-generated-but-fails-to-start)
  - [Dependency Order Problems](#dependency-order-problems)
- [12. Volume Permission Problems](#12-volume-permission-problems)
  - [Files Owned by Wrong Sub-UID](#files-owned-by-wrong-sub-uid)
  - [Restores Landing as Wrong User](#restores-landing-as-wrong-user)
- [13. Network Troubleshooting](#13-network-troubleshooting)
  - [pasta/slirp4netns DNS Issues](#pastaslirp4netns-dns-issues)
  - [Port Conflicts](#port-conflicts)
  - [Container-to-Container Connectivity](#container-to-container-connectivity)
- [14. Catalog Inconsistencies and dbcheck](#14-catalog-inconsistencies-and-dbcheck)
  - [What Is a Catalog Inconsistency?](#what-is-a-catalog-inconsistency)
  - [Running dbcheck](#running-dbcheck)
  - [What dbcheck Checks](#what-dbcheck-checks)
- [15. Bareos Volume Labeling Problems](#15-bareos-volume-labeling-problems)
  - [What Is a Bareos Volume Label?](#what-is-a-bareos-volume-label)
  - [Diagnosing Label Problems](#diagnosing-label-problems)
  - [Relabeling a Volume](#relabeling-a-volume)
  - [Truncating a Volume](#truncating-a-volume)
  - [Manual Label Repair with bscrypto](#manual-label-repair-with-bscrypto)
- [16. Backup Runs But No Files Are Backed Up](#16-backup-runs-but-no-files-are-backed-up)
  - [What It Looks Like](#what-it-looks-like)
  - [Root Causes](#root-causes)
- [17. Large Backups Taking Too Long](#17-large-backups-taking-too-long)
  - [Spooling Full](#spooling-full)
  - [Catalog Query Slow](#catalog-query-slow)
  - [Network Saturated](#network-saturated)
- [18. Error: JobId Already Running After a Crash](#18-error-jobid-already-running-after-a-crash)
  - [What It Looks Like](#what-it-looks-like)
  - [Explanation](#explanation)
  - [Fix](#fix)
- [19. Recovery from a Killed Job](#19-recovery-from-a-killed-job)
  - [What State a Killed Job Leaves Behind](#what-state-a-killed-job-leaves-behind)
  - [Cleanup Procedure](#cleanup-procedure)
  - [Preventing Data Loss After a Kill](#preventing-data-loss-after-a-kill)
- [19b. Auto-Update Failures: Catalog Schema Mismatch](#19-auto-update-failures-catalog-schema-mismatch)
  - [Symptoms](#symptoms)
  - [Recovery Procedure](#recovery-procedure)
  - [Prevention](#prevention)
- [20. bconsole Diagnostic Commands Reference](#20-bconsole-diagnostic-commands-reference)
  - [status — Show Daemon Status](#status-show-daemon-status)
  - [list — Query the Catalog](#list-query-the-catalog)
  - [show — Display Configuration](#show-display-configuration)
  - [messages — Flush and Display Messages](#messages-flush-and-display-messages)
  - [estimate — Dry-Run a Backup](#estimate-dry-run-a-backup)
  - [query — Run Catalog Queries](#query-run-catalog-queries)
  - [run — Start Jobs](#run-start-jobs)
  - [restore — Interactive Restore Wizard](#restore-interactive-restore-wizard)
- [21. Lab 20-1: Diagnose an Authorization Failure](#21-lab-20-1-diagnose-an-authorization-failure)
  - [Prerequisites](#prerequisites)
  - [Step 1: Record the Current Password](#step-1-record-the-current-password)
  - [Step 2: Introduce a Wrong Password](#step-2-introduce-a-wrong-password)
  - [Step 3: Reload the Director](#step-3-reload-the-director)
  - [Step 4: Trigger a Backup and Observe the Error](#step-4-trigger-a-backup-and-observe-the-error)
  - [Step 5: Read the Job Log](#step-5-read-the-job-log)
  - [Step 6: Check the FD Journal](#step-6-check-the-fd-journal)
  - [Step 7: Restore the Correct Password](#step-7-restore-the-correct-password)
  - [What You Learned](#what-you-learned)
- [22. Lab 20-2: Create and Resolve a SELinux Denial](#22-lab-20-2-create-and-resolve-a-selinux-denial)
  - [Prerequisites](#prerequisites)
  - [Step 1: Create a Test Directory with Wrong Context](#step-1-create-a-test-directory-with-wrong-context)
  - [Step 2: Add a New Storage Device Pointing to This Directory](#step-2-add-a-new-storage-device-pointing-to-this-directory)
  - [Step 3: Restart the SD and Try to Use the New Device](#step-3-restart-the-sd-and-try-to-use-the-new-device)
  - [Step 4: Find the AVC Denial](#step-4-find-the-avc-denial)
  - [Step 5: Apply the Correct Context (The Right Fix)](#step-5-apply-the-correct-context-the-right-fix)
  - [Step 6: Generate an audit2allow Module (Demonstration)](#step-6-generate-an-audit2allow-module-demonstration)
  - [Step 7: Verify the Fix](#step-7-verify-the-fix)
- [23. Lab 20-3: Use dbcheck to Repair a Catalog Inconsistency](#23-lab-20-3-use-dbcheck-to-repair-a-catalog-inconsistency)
  - [Prerequisites](#prerequisites)
  - [Step 1: Find a Volume to "Lose"](#step-1-find-a-volume-to-lose)
  - [Step 2: Manually Delete the Volume File](#step-2-manually-delete-the-volume-file)
  - [Step 3: Note the Catalog Inconsistency](#step-3-note-the-catalog-inconsistency)
  - [Step 4: Update the Volume Status to Reflect the Loss](#step-4-update-the-volume-status-to-reflect-the-loss)
  - [Step 5: Stop the Director and Run dbcheck](#step-5-stop-the-director-and-run-dbcheck)
  - [Step 6: Restart and Verify](#step-6-restart-and-verify)
- [24. Quick-Reference Error Table](#24-quick-reference-error-table)
- [25. Diagnostic Decision Tree](#25-diagnostic-decision-tree)
- [26. Summary](#26-summary)

## 1. Troubleshooting Philosophy

Debugging a Bareos installation is a structured activity, not a guessing game. If you approach it randomly — restarting containers, changing passwords, tweaking firewall rules one by one without reading an error message — you will waste hours. The correct mental model is a layered investigation: start at the highest level of abstraction (the job log) and work downward toward the infrastructure (the OS, SELinux, the network) only when the upper layers cannot explain the problem.

### The Three-Layer Rule

**Layer 1 — Read the job log first.**  
Every Bareos job produces a detailed log stored in the catalog database. Before you do anything else, read it. The job log will almost always point directly at the error. You access it through `bconsole`:

```
*list joblog jobid=42
```

This produces a timestamped sequence of messages from the Director, Storage Daemon, and File Daemon as they coordinated the job. The last few lines before a failure almost always contain the exact error string.

**Layer 2 — Check the daemon logs second.**  
If the job log is insufficient (for example, the job never started, or the Director cannot reach the daemon to collect its log), move to the systemd journal for each daemon. These logs are verbose by default in Bareos 24 and will show connection attempts, TLS negotiation failures, resource-not-found errors, and internal state transitions.

**Layer 3 — Check SELinux third.**  
In a correctly configured RHEL 10 system with SELinux in enforcing mode, many mysterious failures — containers that refuse to bind a port, daemons that cannot read a config file, volumes that silently appear empty — are actually silent SELinux denials. The word "silent" is important: SELinux will block an action and log an AVC denial to the audit log, but the application sees only a generic "permission denied" error with no mention of SELinux. Always check the audit log when infrastructure-level failures make no sense.

### A Fourth Layer: Container Internals

Because Bareos runs inside Podman containers in this course, there is a fourth layer that sits between Layer 2 and Layer 3: the container runtime itself. A container might be running but the process inside it might have crashed. Always verify with `podman ps --all` that the container is actually in the `Up` state, not `Exited`.

### The Golden Rule

> **Read the error message.** The error message is not decorative. Bareos error messages are specific and actionable. Copy the exact error string and search for it in the official Bareos documentation and in the job log.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Where All the Logs Are

Understanding exactly where logs live — and how to read them — is the single most important skill for Bareos administration. There are four categories of logs in this environment.

### 2.1 systemd Journal (Daemon Logs)

All Bareos daemons run as Podman containers managed by systemd user services (Quadlet). Their stdout/stderr is captured by journald under the `bareos` user's session. To read them, you must either be the `bareos` user or use `sudo -u bareos` with the correct environment.

Always set `XDG_RUNTIME_DIR` when switching to the bareos user:

```bash
# Switch to bareos user with correct environment
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash

# Or use machinectl shell for a fully-initialized session
machinectl shell bareos@
```

Once you are in a bareos shell:

```bash
# Director daemon log — follow in real time
journalctl --user -u bareos-dir -f

# Director daemon log — last 200 lines
journalctl --user -u bareos-dir -n 200 --no-pager

# Storage Daemon log
journalctl --user -u bareos-sd -f

# File Daemon (client) log
journalctl --user -u bareos-fd -f

# MariaDB catalog database log
journalctl --user -u bareos-db -f

# All bareos-related units at once
journalctl --user -u 'bareos-*' -f

# Show logs since a specific time
journalctl --user -u bareos-dir --since "2026-02-24 10:00:00"

# Show logs between two timestamps
journalctl --user -u bareos-dir \
  --since "2026-02-24 10:00:00" \
  --until "2026-02-24 10:30:00"
```

### 2.2 Bareos Job Log (Catalog)

The job log is stored in the MariaDB catalog database and is accessible through `bconsole`. It contains messages that the Director, Storage Daemon, and File Daemon sent during a specific job run.

```bash
# Start bconsole (as bareos user)
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole

# Inside bconsole:

# List the last 10 jobs
*list jobs last=10

# Show the full log for a specific job
*list joblog jobid=42

# List jobs by status (T=Terminated normally, E=Error, f=fatal, A=Canceled)
*list jobs jobstatus=E

# Show job details (not the log, but the job record: files, bytes, errors)
*llist job jobid=42
```

The `list joblog` output is the primary diagnostic tool. An example of a failing job log looks like:

```
24-Feb 10:15 bareos-dir JobId 42: Start Backup JobId 42, Job=BackupClient1.2026-02-24_10.15.00_00
24-Feb 10:15 bareos-dir JobId 42: Using Device "FileStorage" to write.
24-Feb 10:15 bareos-dir JobId 42: Connecting to Client bareos-client1 at 192.168.1.50:9102
24-Feb 10:15 bareos-fd JobId 42: Fatal error: Failed to authenticate with Director at ...
24-Feb 10:15 bareos-dir JobId 42: Fatal error: Bad response to Hello command: ERR=...
```

Each line is timestamped and tagged with the daemon that produced it, making it easy to identify which component failed.

### 2.3 Bareos Configuration Validation Logs

Before the daemons even start, they validate their configuration files. Validation errors appear in the journal during startup:

```bash
# Check if the Director configuration is valid (dry run)
podman exec bareos-dir bareos-dir -t -c /etc/bareos/bareos-dir.d

# Check if the Storage Daemon configuration is valid
podman exec bareos-sd bareos-sd -t -c /etc/bareos/bareos-sd.d

# Check if the File Daemon configuration is valid
podman exec bareos-fd bareos-fd -t -c /etc/bareos/bareos-fd.d
```

The `-t` flag means "test configuration and exit". A clean configuration prints nothing and exits with code 0. An error prints the exact file and line number of the problem.

### 2.4 SELinux Audit Log

SELinux denials are written to `/var/log/audit/audit.log` (requires root) or are accessible via `ausearch` (which can be run by root or by users with the appropriate capabilities):

```bash
# Show AVC denials from the last 10 minutes (run as root)
ausearch -m avc -ts recent

# Show all AVC denials since boot
ausearch -m avc -ts boot

# Pipe through audit2why for human-readable explanations
ausearch -m avc -ts recent | audit2why

# Search for denials involving a specific process
ausearch -m avc -ts recent -c bareos-dir
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Common Error: No Route to Client

### What It Looks Like

In the job log:

```
Fatal error: bsock.c:NNNN Connecting to Client bareos-client1 at 192.168.1.50:9102 failed.
ERR=Connection refused
```

Or:

```
Fatal error: bsock.c:NNNN Connecting to Client bareos-client1 at 192.168.1.50:9102 failed.
ERR=No route to host
```

### Root Causes and Diagnosis

This error means the Director attempted a TCP connection to the File Daemon's address and port, and the connection was refused or the network path did not exist. There are five common causes:

**Cause 1: The File Daemon container is not running.**

```bash
# Check container status (as bareos user)
XDG_RUNTIME_DIR=/run/user/1001 podman ps --all --filter name=bareos-fd

# If it shows "Exited", check why
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-fd -n 50 --no-pager
```

**Cause 2: The address in the Client resource does not match the actual address.**

The Director's configuration for the client must use an address that is reachable from the Director container. Because all daemons run as rootless Podman containers in the same user's network namespace (via pasta/slirp4netns), they communicate via the host's loopback or via the Podman network bridge.

```bash
# Check how the FD port is published on the host
XDG_RUNTIME_DIR=/run/user/1001 podman port bareos-fd

# Should show something like:
# 9102/tcp -> 0.0.0.0:9102

# Check the Client resource in the Director config
podman exec bareos-dir grep -r "Address" /etc/bareos/bareos-dir.d/client/
```

If containers are on the same Podman network (e.g., `bareos-net`), they can address each other by container name. If they use host port publishing, they must use the host's IP or `host.containers.internal`.

**Cause 3: The host firewall is blocking port 9102.**

```bash
# Check firewall rules (run as root)
firewall-cmd --list-all

# The FD port (9102) must be open if the FD is on a different host
# For loopback/container-internal traffic, firewalld usually does not interfere
# but iptables rules might
iptables -L INPUT -n -v | grep 9102
```

**Cause 4: SELinux is blocking the connection.**

```bash
# Check for AVC denials related to network connections
ausearch -m avc -ts recent | grep "9102\|bareos"
```

**Cause 5: The wrong `FDAddress` or `FDPort` is set in the File Daemon's own configuration.**

```bash
# Check the FD's own self-description
podman exec bareos-fd grep -r "FDAddress\|FDPort" /etc/bareos/bareos-fd.d/
```

### Fix

1. Start the FD container if it is not running: `systemctl --user start bareos-fd`
2. Correct the `Address` in the Client resource to match where the FD is actually reachable
3. Open the firewall port if the FD is on a separate host
4. Fix SELinux denials with `audit2allow` (see Section 9)
5. Correct the `FDAddress` in the FD configuration and restart: `systemctl --user restart bareos-fd`

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Common Error: Authorization Failure

### What It Looks Like

```
Fatal error: Director authorization error at "bareos-fd:9102".
Most likely the passwords do not agree.
If you are using TLS, the TLS configuration may be incorrect.
```

Or in the FD journal:

```
ERR=Client rejected: Name or password is wrong, please see ...
```

### Root Causes and Diagnosis

Authorization in Bareos is mutual: the Director authenticates to the File Daemon, and the File Daemon authenticates back to the Director. The shared secret is the `Password` field in the `Client` resource (Director side) and the `Director` resource (FD side). They must match exactly, including case.

**Cause 1: Password mismatch.**

The most common cause. The password in `/etc/bareos/bareos-dir.d/client/bareos-client1.conf` does not match the password in `/etc/bareos/bareos-fd.d/director/bareos-dir.conf`.

```bash
# Check the password on the Director side
podman exec bareos-dir grep -A5 "Client {" /etc/bareos/bareos-dir.d/client/bareos-client1.conf

# Check the password on the FD side
podman exec bareos-fd grep -A5 "Director {" /etc/bareos/bareos-fd.d/director/bareos-dir.conf
```

**Cause 2: Name mismatch.**

The `Name` field in the Director's `Client` resource must match the `Name` field in the FD's own `FileDaemon` resource. These names are used as part of the authentication handshake.

```bash
# Director's view of the client name
podman exec bareos-dir grep "Name" /etc/bareos/bareos-dir.d/client/bareos-client1.conf

# FD's own name
podman exec bareos-fd grep "Name" /etc/bareos/bareos-fd.d/fileDaemon/bareos-fd.conf
```

**Cause 3: TLS mismatch.**

If TLS is enabled on one side but not the other, or if certificate validation fails, the authentication handshake will fail. Check the TLS configuration in both the Director's Client resource and the FD's Director resource.

```bash
# Look for TLS directives on both sides
podman exec bareos-dir grep -r "TLS\|tls" /etc/bareos/bareos-dir.d/client/
podman exec bareos-fd grep -r "TLS\|tls" /etc/bareos/bareos-fd.d/director/
```

### Fix

1. Generate a new random password: `openssl rand -base64 33`
2. Update the `Password` field in both the Director's Client resource and the FD's Director resource with the same value
3. Reload the Director: `XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir bareos-ctl-dir reload`
4. Restart the FD: `systemctl --user restart bareos-fd`

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Common Error: Cannot Open Volume

### What It Looks Like

```
3304 Error: Volume "Vol-0001" not in catalog.
```

Or:

```
3305 Error: Could not open: /srv/bareos-storage/volumes/Vol-0001, ERR=No such file or directory
```

Or:

```
3991 Bad label: Volume=Vol-0001 Expected=Vol-0002
```

### Root Causes and Diagnosis

**Cause 1: The volume file does not exist at the expected path.**

This happens when the storage volume path has changed (e.g., the Podman volume was recreated), or when the catalog records a path that was never actually created.

```bash
# Check what path the Storage Daemon expects
podman exec bareos-sd grep -r "Archive Device\|Device" /etc/bareos/bareos-sd.d/device/

# List the actual files present
ls -la /srv/bareos-storage/volumes/

# Check what volumes the catalog knows about
# (in bconsole)
*list volumes
```

**Cause 2: Volume label mismatch.**

Bareos writes a label to the beginning of every volume file. The label contains the volume name. If the file was copied, renamed, or truncated, the label may not match what the catalog expects.

```bash
# Read the label from a volume file (as bareos user, inside SD container)
podman exec bareos-sd bls -L /srv/bareos-storage/volumes/Vol-0001
```

**Cause 3: Wrong SELinux context on the volume path.**

The Storage Daemon process inside the container accesses the host path `/srv/bareos-storage/volumes` through a bind mount. If the SELinux context on this path is wrong, the SD will get a "permission denied" that looks identical to a missing-file error.

```bash
# Check the SELinux context on the storage path
ls -laZ /srv/bareos-storage/volumes/

# It should show: bareos_store_t (or container_file_t as a fallback)
# If it shows something else (e.g., default_t), fix it:
sudo semanage fcontext -a -t bareos_store_t "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -Rv /srv/bareos-storage/volumes/
```

### Fix

- If the volume file is missing, either restore it from another backup, or use `relabel` in bconsole to assign a new label to a blank file (see Section 15).
- If the label is mismatched, use `relabel` or the `truncate` command in bconsole to reset the volume.
- If it is a SELinux context problem, run `restorecon` as shown above.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Common Error: Catalog Database Error

### What It Looks Like

In the Director journal:

```
Could not open database "bareos": Error: Can't connect to MySQL server on '127.0.0.1' (111)
```

Or:

```
ERR=Access denied for user 'bareos'@'172.16.0.1' (using password: YES)
```

### Root Causes and Diagnosis

**Cause 1: The MariaDB container is not running.**

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman ps --all --filter name=bareos-db
# If "Exited", check the log:
journalctl --user -u bareos-db -n 100 --no-pager
```

**Cause 2: The Director is using the wrong credentials.**

The Director reads database credentials from the environment file `/home/bareos/.config/bareos/db.env`. If this file was edited incorrectly or if the MariaDB container was recreated with different credentials, they will not match.

```bash
# Check the credentials the Director is configured to use
# (These come from the env file mounted into the container)
ls -la /home/bareos/.config/bareos/db.env
# File must be mode 600 — if it is readable by others, fix it:
chmod 600 /home/bareos/.config/bareos/db.env

# Test the credentials manually
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-db \
  mysql -u bareos -p"$(grep BAREOS_DB_PASSWORD /home/bareos/.config/bareos/db.env | cut -d= -f2)" \
  -e "SELECT 1;" bareos
```

**Cause 3: The database has not been initialized.**

After a fresh deployment, `bareos_db_create` and `bareos_db_make_tables` must be run. If they were skipped or failed silently, the database schema will be missing.

```bash
# Run the initialization inside the Director container
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  /usr/lib/bareos/scripts/create_bareos_database
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  /usr/lib/bareos/scripts/make_bareos_tables
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  /usr/lib/bareos/scripts/grant_bareos_privileges
```

### Fix

1. Start the MariaDB container: `systemctl --user start bareos-db`
2. Wait 10–15 seconds for MariaDB to fully initialize before starting the Director
3. Fix credential mismatches by updating `db.env` and restarting the Director
4. Run database initialization scripts if the schema is missing

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Common Error: Max Concurrent Jobs Exceeded

### What It Looks Like

In the job log:

```
Job bareos-fd.2026-02-24_10.15 waiting execution of higher priority jobs
```

Or a job simply queues and never starts, and `status director` shows:

```
Waiting on max Client jobs: 2
```

### Explanation

Bareos has several concurrency limits that can cause jobs to wait:

- `Maximum Concurrent Jobs` in the `Job` resource: how many instances of that job can run simultaneously
- `Maximum Concurrent Jobs` in the `Client` resource: how many jobs can run against a single client at once
- `Maximum Concurrent Jobs` in the `Storage` resource: how many jobs can write to a single storage device at once
- `Maximum Jobs` in a `Schedule` resource's run line

These limits exist to prevent the Storage Daemon from being overwhelmed and to avoid thrashing the File Daemon's I/O subsystem.

```bash
# In bconsole, check what jobs are waiting and why
*status director
*list jobs jobstatus=W
```

### Fix

Increase the `Maximum Concurrent Jobs` value in the relevant resource. Be conservative — more concurrent jobs means more simultaneous I/O, which can make all jobs slower.

```
# In /etc/bareos/bareos-dir.d/client/bareos-client1.conf
Client {
  Name = bareos-client1
  ...
  Maximum Concurrent Jobs = 5    # increase from default of 1
}
```

After editing, reload the Director:

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir bareos-ctl-dir reload
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Jobs Stuck Waiting

### Waiting for Storage Daemon

A job shows status "W" (waiting) with the message "waiting for Storage Daemon". This means the Director has connected to the Storage Daemon and asked it to mount a volume or open a device, but the SD has not responded.

**Common causes:**
- The Storage Daemon container is not running or is unresponsive
- The storage device path is not mounted or is full
- Another job holds an exclusive lock on the storage device
- The maximum concurrent jobs for the Storage resource has been reached

```bash
# Check SD status
journalctl --user -u bareos-sd -n 50 --no-pager

# In bconsole
*status storage
*list volumes

# Check disk space on the storage path
df -h /srv/bareos-storage/volumes/
```

### Waiting for Client

A job shows "waiting for client" — the Director is trying to connect to the File Daemon but the FD has not accepted.

```bash
# Check FD status
journalctl --user -u bareos-fd -n 50 --no-pager

# Test TCP connectivity from the Director container to the FD
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  nc -zv bareos-client1 9102
```

### Waiting for Mount

The job is waiting for a volume to be mounted. This usually means the Storage Daemon is configured for a tape or optical device (not a file-based storage), or a manual mount is required. In our disk-based setup, this should not occur unless the `Automount` directive is `No`.

```bash
# In bconsole, mount the storage manually
*mount storage=FileStorage
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. SELinux Troubleshooting

SELinux is enforcing on RHEL 10. This is the correct and secure configuration. You should never set SELinux to permissive or disabled to "fix" a problem — doing so removes a critical security layer and masks the real issue. Instead, learn to diagnose and resolve SELinux denials properly.

### Understanding AVC Denials

An AVC (Access Vector Cache) denial is SELinux's way of saying: "Process X tried to perform operation Y on resource Z, and this is not permitted by the current policy." The denial is logged to the audit log at `/var/log/audit/audit.log`.

A raw AVC denial looks like this:

```
type=AVC msg=audit(1708772100.123:456): avc:  denied  { read } for  pid=12345
comm="bareos-sd" name="Vol-0001" dev="sda1" ino=67890
scontext=system_u:system_r:container_t:s0:c123,c456
tcontext=unconfined_u:object_r:default_t:s0
tclass=file permissive=0
```

Reading this: the process `bareos-sd` (running in a container with context `container_t`) tried to `read` a file called `Vol-0001` whose SELinux type is `default_t`. This was denied.

### Step-by-Step SELinux Diagnosis

```bash
# Step 1: Check for recent denials (run as root)
ausearch -m avc -ts recent

# Step 2: Get a human-readable explanation
ausearch -m avc -ts recent | audit2why

# Step 3: Generate a policy module to allow the denied operation
ausearch -m avc -ts recent | audit2allow -M bareos_local

# Step 4: Review what the policy module will allow (IMPORTANT — read this)
cat bareos_local.te

# Step 5: Install the policy module
semodule -i bareos_local.pp

# Verify it was installed
semodule -l | grep bareos_local
```

### Common SELinux Fixes for Bareos + Podman

**Fix 1: Wrong context on storage directory**

```bash
# Storage volumes must have bareos_store_t (or container_file_t for Podman volumes)
sudo semanage fcontext -a -t container_file_t "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -Rv /srv/bareos-storage/volumes/
```

**Fix 2: Wrong context on config files**

Config files mounted into containers must be readable by processes with `container_t` context:

```bash
# Named volume data directories are automatically labeled container_file_t
# But bind-mounted host paths need explicit labeling
ls -laZ /home/bareos/.config/bareos/
# Should show: system_u:object_r:container_file_t:s0 or similar
```

**Fix 3: Container cannot bind a port**

If a container cannot bind port 9101, 9102, or 9103, check if the port is in SELinux's allowed list for containers:

```bash
# Check if port 9101 is permitted for containers
semanage port -l | grep 9101

# If not, add it
sudo semanage port -a -t http_port_t -p tcp 9101
# Or more specifically for container ports:
sudo semanage port -a -t unreserved_port_t -p tcp 9101
```

**Fix 4: Using setsebool for Podman networking**

```bash
# Allow containers to connect to the network
sudo setsebool -P container_connect_any 1

# Allow containers to manage network namespaces
sudo setsebool -P virt_use_nfs 1
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Rootless Podman Troubleshooting

### Container Won't Start: Missing Linger

Rootless Podman containers managed by systemd user services require that "linger" is enabled for the user. Without linger, the user's systemd instance only runs when the user is actively logged in. When the user logs out, all their containers stop.

```bash
# Check if linger is enabled
loginctl show-user bareos | grep Linger
# Should show: Linger=yes

# If not enabled:
sudo loginctl enable-linger bareos

# Verify
ls /var/lib/systemd/linger/ | grep bareos
```

### Container Won't Start: Wrong XDG_RUNTIME_DIR

The `XDG_RUNTIME_DIR` environment variable tells systemd and Podman where the user's runtime socket directory is. For UID 1001, this must be `/run/user/1001`. If this variable is not set — for example, when running commands via `sudo` or `ssh` without a login shell — Podman cannot find the user's socket.

```bash
# Always set XDG_RUNTIME_DIR when running Podman as the bareos user
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps

# Or use machinectl shell for a proper login environment
machinectl shell bareos@

# Check that the runtime directory exists
ls -la /run/user/1001/
# Should contain: podman/ (a socket directory)
```

### Container Won't Start: Missing subuid/subgid

Rootless Podman uses subordinate UID/GID ranges to map container user IDs to host UIDs inside the user namespace. If the `bareos` user does not have a sub-UID range configured, Podman cannot create user namespaces and containers will fail with "newuidmap" errors.

```bash
# Check sub-UID assignment
grep bareos /etc/subuid
# Should show: bareos:100000:65536

grep bareos /etc/subgid
# Should show: bareos:100000:65536

# If missing, add them:
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 bareos

# After adding, reset the Podman user namespace
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman system migrate
```

### Container Exits Immediately

When a container starts and immediately exits (shown as `Exited (1)` or similar in `podman ps --all`), the cause is almost always inside the container. Check the container's output:

```bash
# Show logs from the last run of a container
XDG_RUNTIME_DIR=/run/user/1001 podman logs bareos-dir

# Show the exit code
XDG_RUNTIME_DIR=/run/user/1001 podman inspect bareos-dir \
  --format '{{.State.ExitCode}} {{.State.Error}}'

# Run the container interactively to see startup errors
XDG_RUNTIME_DIR=/run/user/1001 podman run --rm -it \
  --name bareos-dir-debug \
  -v bareos-dir-config:/etc/bareos:Z \
  docker.io/bareos/bareos-director:24 bash
```

Common causes of immediate exit:
- Configuration file syntax error (run with `-t` to test)
- Missing environment variable that the entrypoint script requires
- Database not yet available (timing issue — add `After=bareos-db.service` in the Quadlet)
- Permission error reading a mounted volume

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Quadlet Troubleshooting

Quadlet is the mechanism that translates `.container` files in `/home/bareos/.config/containers/systemd/` into systemd unit files. Understanding how this translation works is essential for debugging.

### Unit Not Generated

If you created or modified a `.container` file but `systemctl --user status bareos-dir` says the unit does not exist, Quadlet has not processed your file.

```bash
# Reload the systemd user daemon and Quadlet generator
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload

# Check if the unit now exists
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user list-unit-files | grep bareos

# If the unit still does not appear, check the Quadlet generator log
journalctl --user -xe | grep -i quadlet

# Verify the .container file syntax
XDG_RUNTIME_DIR=/run/user/1001 /usr/lib/systemd/system-generators/podman-system-generator \
  --user /home/bareos/.config/containers/systemd/ /tmp/quadlet-test/ /tmp/quadlet-test/
ls /tmp/quadlet-test/
```

The Quadlet generator writes the generated unit files to a temporary directory when invoked manually. If a `.container` file has a syntax error, the generator will skip it or produce an invalid unit.

### Unit Generated But Fails to Start

```bash
# Check the detailed status
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user status bareos-dir

# Check the journal for this specific unit
journalctl --user -u bareos-dir -n 100 --no-pager

# Common issues:
# - "Failed to pull image" — network issue or wrong image name
# - "Error: statfs ..." — volume path does not exist
# - "Error: ...permission denied" — SELinux or Unix permissions
```

### Dependency Order Problems

If the Director starts before MariaDB is ready, it will fail to connect to the database. Quadlet supports `After=` and `Requires=` directives to enforce startup order.

A correct `bareos-dir.container` should include:

```ini
[Unit]
Description=Bareos Director
After=bareos-db.service
Requires=bareos-db.service

[Container]
Image=docker.io/bareos/bareos-director:24
# ... rest of configuration
```

If MariaDB takes longer to initialize than expected (first run with data initialization), add a health check wait or use `podman healthcheck` to delay the Director's start.

```bash
# Check if the MariaDB container has a healthcheck passing
XDG_RUNTIME_DIR=/run/user/1001 podman healthcheck run bareos-db
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Volume Permission Problems

### Files Owned by Wrong Sub-UID

When Podman runs a container as a non-root user (rootless), the UIDs inside the container are mapped to sub-UIDs on the host. For the `bareos` user (UID 1001) with sub-UIDs 100000–165535:

- UID 0 (root) inside the container → UID 1001 on the host (the bareos user itself)
- UID 1 inside the container → UID 100000 on the host
- UID 1000 inside the container → UID 100999 on the host

The Bareos daemon processes inside containers typically run as UID 0 or a specific UID. Files written by these processes will be owned by the mapped host UID. If you inspect a named volume on the host, you will see files owned by these sub-UIDs:

```bash
# Inspect files in a named volume
ls -la ~/.local/share/containers/storage/volumes/bareos-dir-config/_data/

# Output might show:
# -rw-r--r-- 1 100000 100000  ... bareos-dir.conf
```

This is normal and expected. Do not `chown` these files to the `bareos` user — doing so will break the container's ability to read them.

### Restores Landing as Wrong User

When Bareos restores files, the File Daemon recreates them with the original UID/GID stored in the catalog. If the original files were owned by UID 1000 on the backup source, and the restore target system has a different UID 1000 (or no such UID), the restored files will appear to belong to "1000" (displayed as a number when there is no matching user).

```bash
# Check what UIDs are stored in a backup set (in bconsole)
*list files jobid=42

# To restore files as a specific user, use the "where" and "replace" options
# and then chown after restore
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Network Troubleshooting

### pasta/slirp4netns DNS Issues

Rootless Podman uses either `pasta` (default on RHEL 10) or `slirp4netns` for network emulation. These provide containers with outbound network access and port forwarding, but DNS resolution inside containers goes through a virtual nameserver.

If containers cannot resolve hostnames (e.g., cannot pull images or cannot reach services by name):

```bash
# Test DNS resolution inside a container
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  getent hosts mariadb.example.com

# Check the /etc/resolv.conf inside the container
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir cat /etc/resolv.conf

# If using a Podman network (bridge mode), check network DNS settings
XDG_RUNTIME_DIR=/run/user/1001 podman network inspect bareos-net
```

### Port Conflicts

If a container fails to start because its published port is already in use:

```bash
# Check what process is using port 9101
ss -tlnp | grep 9101
# Or
lsof -i :9101

# If another process owns it, either stop that process or change the host port
# in the Quadlet .container file:
# PublishPort=19101:9101  (use port 19101 on the host instead)
```

### Container-to-Container Connectivity

When multiple Bareos containers (Director, SD, FD) need to communicate with each other, they should be on the same Podman network. A Podman user-defined network allows containers to address each other by container name.

```bash
# Create a shared network (if not already created)
XDG_RUNTIME_DIR=/run/user/1001 podman network create bareos-net

# Check that all containers are on the network
XDG_RUNTIME_DIR=/run/user/1001 podman network inspect bareos-net

# Test connectivity between containers
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  ping -c 3 bareos-sd
```

In Quadlet `.container` files, add the network with:

```ini
[Container]
Network=bareos-net.network
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Catalog Inconsistencies and dbcheck

### What Is a Catalog Inconsistency?

The Bareos catalog is a relational database (MariaDB in our setup) that tracks every job, every file, every volume, and every restore session. Over time, especially after crashes, manual volume deletions, or database corruption, the catalog can develop inconsistencies — records that refer to non-existent objects, duplicate records, or orphaned entries.

Common symptoms:
- `list files` shows files that no longer exist on any volume
- `list volumes` shows volumes with status "Error" that are actually healthy
- `list jobs` shows jobs in a running state that clearly terminated long ago
- `restore` prompts for a volume that has been deleted

### Running dbcheck

`dbcheck` is a Bareos utility that scans the catalog and identifies (and optionally repairs) inconsistencies. Always run it with the Director stopped, since an active Director may be writing to the catalog simultaneously.

```bash
# Step 1: Stop the Director
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user stop bareos-dir

# Step 2: Run dbcheck in scan-only mode (no changes)
XDG_RUNTIME_DIR=/run/user/1001 podman run --rm \
  --env-file /home/bareos/.config/bareos/db.env \
  --network bareos-net \
  docker.io/bareos/bareos-director:24 \
  dbcheck -c /etc/bareos/bareos-dir.conf -B -d 50

# Step 3: Run dbcheck with automatic repairs
XDG_RUNTIME_DIR=/run/user/1001 podman run --rm \
  --env-file /home/bareos/.config/bareos/db.env \
  --network bareos-net \
  docker.io/bareos/bareos-director:24 \
  dbcheck -c /etc/bareos/bareos-dir.conf -B -f -v

# -B = batch mode (answer yes to all prompts)
# -f = fix inconsistencies
# -v = verbose output

# Step 4: Restart the Director
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-dir
```

### What dbcheck Checks

- Orphaned File entries (files not associated with any job)
- Duplicate records in the Path table
- Jobs in the catalog with no associated FileSet
- Clients in the catalog with no associated jobs
- Volume records with slot numbers that don't match the media changer

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Bareos Volume Labeling Problems

### What Is a Bareos Volume Label?

Every Bareos volume (file on disk, tape, etc.) begins with a software label written by the Storage Daemon. The label contains the volume name, pool name, and a creation timestamp. Bareos uses this label to verify that the correct volume is mounted before reading or writing backup data.

### Diagnosing Label Problems

```bash
# Read the label from a volume file (run inside the SD container)
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-sd \
  bls -L /srv/bareos-storage/volumes/Vol-0001

# Output shows the label contents:
# Volume Name:           Vol-0001
# Pool Name:             Full
# Pool Type:             Backup
# Creation Date/Time:    ...
```

If `bls` reports "no label" or "bad label", the volume label is corrupted or missing.

### Relabeling a Volume

**Warning:** Relabeling overwrites the existing label. If the volume contains backup data, that data will become unreadable. Only relabel volumes you are certain are empty or whose data you no longer need.

```bash
# In bconsole, relabel a volume
*relabel storage=FileStorage oldvolume=Vol-0001 volume=Vol-0001 pool=Full

# Bareos will ask for confirmation and write a new label
```

### Truncating a Volume

If a volume is in an error state but you want to reuse it:

```bash
# In bconsole
*truncate storage=FileStorage volume=Vol-0001

# This marks the volume as empty in the catalog and truncates the file
```

### Manual Label Repair with bscrypto

In rare cases where label corruption is partial, `bscrypto` can be used to inspect and repair cryptographic signatures on volumes. This is an advanced procedure:

```bash
# List volume signatures
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-sd \
  bscrypto -D /srv/bareos-storage/volumes/Vol-0001
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Backup Runs But No Files Are Backed Up

### What It Looks Like

The job completes with status "T" (terminated normally), but the job log shows:

```
JobId 42: No files found to backup
```

Or the job shows 0 files and 0 bytes:

```
  Files Examined:      0
  Files Backed Up:     0
  Bytes Backed Up:     0
```

### Root Causes

**Cause 1: FileSet Include path is wrong.**

The `Include` block in the FileSet resource specifies what directories to back up. If the path does not exist inside the File Daemon container (or on the backup client host), no files will be found.

```bash
# Check the FileSet definition
podman exec bareos-dir grep -r "Include\|File =" /etc/bareos/bareos-dir.d/fileset/

# Test what the FD can see
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-fd \
  ls -la /path/to/backup/
```

**Cause 2: All files are excluded by an Exclude rule.**

Check the `Exclude` block in the FileSet. Overly broad patterns can accidentally exclude everything:

```
FileSet {
  Name = "AllFiles"
  Include {
    Options { ... }
    File = /data
  }
  Exclude {
    File = /data   # This accidentally excludes everything!
  }
}
```

**Cause 3: The FD cannot read the files (permissions/SELinux).**

Even if the path exists, the FD process must have read permission. Check the FD journal for permission errors:

```bash
journalctl --user -u bareos-fd -n 100 --no-pager | grep -i "permission\|denied\|error"
```

**Cause 4: Accurate mode — incremental backup found nothing changed.**

If the backup is an Incremental job and no files have changed since the last Full backup, this is correct behavior, not an error.

```bash
# Check the job type
*list job jobid=42
# Look at the "Level" field: Full, Incremental, or Differential
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 17. Large Backups Taking Too Long

### Spooling Full

Bareos uses a spool file on the Director or Storage Daemon host to buffer backup data before writing it to the volume. If the spool area fills up, the backup pauses until space is available.

```bash
# Check spool usage
df -h /var/lib/bareos/spool/   # inside SD container
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-sd df -h /var/lib/bareos/

# Increase spool size in the Job resource:
# SpoolSize = 10G
# Or in the Device resource:
# Spool Directory = /srv/bareos-spool
# Maximum Spool Size = 50G
```

### Catalog Query Slow

As the catalog grows, queries for incremental backup file lists can become slow. Ensure the MariaDB container has adequate memory and that the catalog tables are indexed:

```bash
# Check MariaDB status
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-db \
  mysql -u bareos -p"${BAREOS_DB_PASSWORD}" bareos \
  -e "SHOW STATUS LIKE 'Innodb_buffer_pool%';"

# Run ANALYZE to update table statistics
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-db \
  mysql -u bareos -p"${BAREOS_DB_PASSWORD}" bareos \
  -e "ANALYZE TABLE File, Job, JobMedia, Media;"
```

### Network Saturated

If backup traffic is saturating the network, Bareos supports bandwidth limiting:

```bash
# In the Client resource:
# Maximum Bandwidth Per Job = 50 mb/s

# Or in bconsole, set it for a running job:
*setbandwidth client=bareos-client1 limit=50000
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 18. Error: JobId Already Running After a Crash

### What It Looks Like

After a system crash or forced container restart, trying to run a backup produces:

```
Fatal error: Job bareos-fd.2026-02-24_10.15 is already running. Terminating.
```

### Explanation

When Bareos crashes or is forcefully killed mid-job, the catalog retains the job record in a "Running" state. When the Director restarts and tries to run the same job, it sees the stale "Running" entry and refuses to start a new instance.

### Fix

```bash
# In bconsole, find the stale running job
*list jobs jobstatus=R

# Cancel the stale job (this updates the catalog record, not an actual running process)
*cancel jobid=42

# Or, if cancel doesn't work, use the purge command (destructive — use with care)
*purge jobs jobid=42

# After canceling, restart the backup normally
*run job=BackupClient1 level=Full yes
```

### Check for Stale Lock Files

In some cases the Director also leaves a runtime lock file in `/var/lib/bareos/` (inside the Director container). A stale lock file from a previous crash can prevent a new job from starting even after you cancel the catalog record:

```bash
# Check for stale .pid or lock files inside the Director container
podman exec bareos-director ls -la /var/lib/bareos/*.pid 2>/dev/null
podman exec bareos-director ls -la /var/lib/bareos/*.lck 2>/dev/null

# If a stale .pid file exists for the Director process that is no longer running:
podman exec bareos-director rm -f /var/lib/bareos/bareos-dir.9101.pid

# Restart the Director container to allow it to re-create the pid file cleanly
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart bareos-director
```

> Only remove a `.pid` file if you have confirmed the listed process is no longer running. Removing a `.pid` for a live process will cause the Director to lose track of its own state.

---

[↑ Back to Table of Contents](#table-of-contents)

## 19. Recovery from a Killed Job

### What State a Killed Job Leaves Behind

When a job is killed (container killed, host rebooted, OOM killer) mid-execution:

1. **Catalog state:** The job record remains in status "R" (running) or "C" (created) — a stale record
2. **Volume state:** The volume currently being written may be in an inconsistent state — partially written data
3. **File Daemon state:** The FD may hold open file handles that need to be cleaned up
4. **Storage Daemon state:** The SD may hold an exclusive lock on the volume

### Cleanup Procedure

```bash
# Step 1: Identify the killed job
*list jobs jobstatus=R

# Step 2: Cancel the stale job record
*cancel jobid=42

# Step 3: Check the volume that was being written
*list volumes
# Look for volumes in "Append" or "Error" state

# Step 4: If the volume is inconsistent, truncate it (if data loss is acceptable)
# or relabel it (see Section 15)
*truncate storage=FileStorage volume=Vol-0001

# Step 5: Run a new Full backup to ensure all data is protected
*run job=BackupClient1 level=Full yes
```

### Preventing Data Loss After a Kill

Bareos uses a feature called "accurate backup" and its own internal volume verification to detect partial writes. The first backup after a kill should be a Full backup, not Incremental — the Incremental mechanism relies on a valid previous backup existing.

---

[↑ Back to Table of Contents](#table-of-contents)

## 19. Auto-Update Failures: Catalog Schema Mismatch

`podman auto-update` can pull a new Bareos image that contains a **catalog schema migration** — a change to the MariaDB database structure. If this happens without manual intervention, the Director will refuse to start.

### Symptoms

```
bareos-director: dird/dbdriver.cc Could not open Catalog "MyCatalog"
bareos-director: dird/dbdriver.cc Database Version mismatch
```

Or in the journal:

```bash
journalctl --user -u bareos-director.service -n 30
# Look for: "Could not open Catalog" / "Version mismatch" / "update_bareos_tables"
```

The Director container restarts repeatedly and enters the `failed` systemd state.

### Recovery Procedure

```bash
# Step 1: Stop the Director (let the DB keep running)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user stop bareos-director.service

# Step 2: Confirm the error is a schema mismatch
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -n 50 --no-pager | grep -i "version\|mismatch\|catalog"

# Step 3: Run the catalog migration script
# This updates the DB schema to match the new Director image.
# The bareos-db container must be running.
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
    --network bareos-net \
    --env-file /home/bareos/.config/bareos/bareos.env \
    --env-file /home/bareos/.config/bareos/db.env \
    docker.io/bareos/bareos-director:24 \
    /usr/lib/bareos/scripts/update_bareos_tables

# Step 4: Restart the Director
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user start bareos-director.service

# Step 5: Verify
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec -it bareos-director bconsole -c /etc/bareos/bconsole.conf <<< "version"
```

If the migration script itself fails (e.g., due to a DB corruption), restore from the most recent `BackupCatalog` dump (see [Chapter 14](14-database-containers.md)) and then re-run the migration.

### Prevention

1. **Pin production images to digests** — use `Label=io.containers.autoupdate=registry` only in non-production environments (see [Chapter 12, Section 11](12-quadlet-systemd-integration.md#11-auto-update-with-podman-auto-update)).
2. **Always take a catalog backup before upgrading** — ensure `BackupCatalog` ran successfully within 24 hours before any planned upgrade.
3. **Read release notes** — check the Bareos changelog for mentions of "catalog migration" before pulling a new major version.

---

[↑ Back to Table of Contents](#table-of-contents)

## 20. bconsole Diagnostic Commands Reference

`bconsole` is the primary interactive interface to the Bareos Director. Below is a reference of the most useful diagnostic commands.

### status — Show Daemon Status

```
*status director          # Show Director's internal state, running jobs, queued jobs
*status storage           # Show Storage Daemon state, connected clients, mounted volumes
*status client            # Show File Daemon state, running jobs
*status all               # Show all daemons at once
```

### list — Query the Catalog

```
*list jobs                # All jobs
*list jobs last=10        # Last 10 jobs
*list jobs jobstatus=E    # Failed jobs (E=Error)
*list jobs jobstatus=R    # Running jobs
*list job jobid=42        # Details for a specific job
*list joblog jobid=42     # Full log output for a specific job
*list volumes             # All volumes in all pools
*list volumes pool=Full   # Volumes in the Full pool
*list media               # Detailed volume media info
*list clients             # All configured clients
*list filesets            # All configured filesets
*list files jobid=42      # Files backed up in job 42
```

### show — Display Configuration

```
*show job=BackupClient1   # Show the Job resource configuration
*show client=bareos-fd    # Show the Client resource
*show storage=FileStorage # Show the Storage resource
*show fileset=LinuxAll    # Show the FileSet resource
*show schedule=WeeklyCycle # Show the Schedule resource
*show all                 # Show all resources (verbose)
```

### messages — Flush and Display Messages

```
*messages                 # Show pending messages and clear them
```

### estimate — Dry-Run a Backup

```
# Estimate how many files and bytes a backup would involve without running it
*estimate job=BackupClient1 level=Full

# More detailed listing
*estimate job=BackupClient1 level=Full listing
```

### query — Run Catalog Queries

```
*query                    # Interactive menu of pre-built catalog queries
# Covers: job summary, volume usage, client activity, etc.
```

### run — Start Jobs

```
*run job=BackupClient1 level=Full yes      # Run a Full backup immediately
*run job=RestoreFiles yes                   # Run a restore job
```

### restore — Interactive Restore Wizard

```
*restore                  # Start the interactive restore menu
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 21. Lab 20-1: Diagnose an Authorization Failure

In this lab, you will intentionally introduce a password mismatch between the Director and the File Daemon, observe the error, and then fix it.

### Prerequisites

- Bareos is fully deployed and a successful backup has previously run
- You have `bconsole` access
- You are working as the `bareos` user with `XDG_RUNTIME_DIR=/run/user/1001`

### Step 1: Record the Current Password

```bash
# Find the current FD client password in the Director's config
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  grep -A 10 "Client {" /etc/bareos/bareos-dir.d/client/bareos-client1.conf | grep Password
```

Note the password value. You will restore it at the end.

### Step 2: Introduce a Wrong Password

Edit the Director-side client configuration to use a deliberately wrong password:

```bash
# Edit the Director's client config (inside the named volume)
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bash

# Inside the container:
vi /etc/bareos/bareos-dir.d/client/bareos-client1.conf
# Change the Password field to "WRONGPASSWORD"
exit
```

### Step 3: Reload the Director

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir bareos-ctl-dir reload
```

### Step 4: Trigger a Backup and Observe the Error

```bash
# Run a backup (it should fail)
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
run job=BackupClient1 level=Full yes
wait
messages
quit
EOF
```

### Step 5: Read the Job Log

```bash
# Find the failed job ID
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
list jobs last=5
quit
EOF

# Read the job log (replace 99 with actual job ID)
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
list joblog jobid=99
quit
EOF
```

**Expected output fragment:**
```
Fatal error: Director authorization error at "bareos-fd:9102".
Most likely the passwords do not agree.
```

### Step 6: Check the FD Journal

```bash
journalctl --user -u bareos-fd -n 30 --no-pager | grep -i "auth\|password\|error"
```

### Step 7: Restore the Correct Password

```bash
# Edit the config back to the original password
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bash -c \
  "vi /etc/bareos/bareos-dir.d/client/bareos-client1.conf"

# Reload
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir bareos-ctl-dir reload

# Verify with a successful backup
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
run job=BackupClient1 level=Full yes
wait
messages
quit
EOF
```

### What You Learned

- Authorization failures present a specific error message that clearly states "passwords do not agree"
- The job log is the first place to look — it tells you exactly which daemon rejected the connection
- The FD journal provides the other side of the story, confirming the rejection
- Fixing it requires updating only the credential that is wrong (one side) and reloading the Director

---

[↑ Back to Table of Contents](#table-of-contents)

## 22. Lab 20-2: Create and Resolve a SELinux Denial

In this lab, you will create a new directory, give it the wrong SELinux context, observe Bareos failing to write to it, and use `audit2allow` to generate a fix.

### Prerequisites

- Root access on the RHEL 10 host
- SELinux is in enforcing mode: `getenforce` should output `Enforcing`
- Bareos Storage Daemon is running

### Step 1: Create a Test Directory with Wrong Context

```bash
# Create a new storage directory as root
sudo mkdir -p /srv/bareos-test-storage
sudo chown -R bareos:bareos /srv/bareos-test-storage

# Check its current SELinux context
ls -laZ /srv/bareos-test-storage
# It will show default_t — the wrong context for Bareos storage
```

### Step 2: Add a New Storage Device Pointing to This Directory

```bash
# Create a new device config (inside the SD container's config volume)
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-sd bash

# Inside the container, create a new device config:
cat > /etc/bareos/bareos-sd.d/device/TestDevice.conf << 'EOF'
Device {
  Name = TestDevice
  Media Type = File
  Archive Device = /srv/bareos-test-storage
  LabelMedia = yes
  Random Access = Yes
  AutomaticMount = yes
  RemovableMedia = no
  AlwaysOpen = no
}
EOF
exit
```

### Step 3: Restart the SD and Try to Use the New Device

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart bareos-sd

# In bconsole, label a new volume in the test device
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
label storage=TestStorage volume=TestVol-0001 pool=Scratch
quit
EOF
```

This will fail. The SD will try to create the volume file, SELinux will deny it.

### Step 4: Find the AVC Denial

```bash
# As root, check for recent denials
sudo ausearch -m avc -ts recent | grep bareos-test

# Get a human-readable explanation
sudo ausearch -m avc -ts recent | audit2why
```

**Expected output:**
```
type=AVC ... avc: denied { write } for ... comm="bareos-sd" name="bareos-test-storage"
...
Was caused by:
  Missing type enforcement (TE) allow rule.
  You can use audit2allow to generate a loadable module to allow this access.
```

### Step 5: Apply the Correct Context (The Right Fix)

Rather than using `audit2allow` for this specific case (adding a policy exception), the correct fix is to label the directory with the proper SELinux context:

```bash
# Apply the correct context
sudo semanage fcontext -a -t container_file_t "/srv/bareos-test-storage(/.*)?"
sudo restorecon -Rv /srv/bareos-test-storage

# Verify
ls -laZ /srv/bareos-test-storage
# Should now show: container_file_t
```

### Step 6: Generate an audit2allow Module (Demonstration)

In cases where a correct policy type does not exist, `audit2allow` is the right tool:

```bash
# Generate a policy module
sudo ausearch -m avc -ts recent | audit2allow -M bareos_local_test

# Review what will be allowed (IMPORTANT: read this before installing)
cat bareos_local_test.te

# Install the module
sudo semodule -i bareos_local_test.pp

# Verify
sudo semodule -l | grep bareos_local_test
```

### Step 7: Verify the Fix

```bash
# Retry the volume labeling
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
label storage=TestStorage volume=TestVol-0001 pool=Scratch
quit
EOF

# It should succeed now
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 23. Lab 20-3: Use dbcheck to Repair a Catalog Inconsistency

In this lab, you will manually delete a volume file from disk (simulating a disk failure), then use `dbcheck` to identify and clean up the orphaned catalog records.

### Prerequisites

- At least one successful Full backup has been completed
- You know the name of a volume used in that backup (from `list volumes` in bconsole)

### Step 1: Find a Volume to "Lose"

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
list volumes
quit
EOF
```

Note a volume name — for example, `Full-Vol-0001`.

### Step 2: Manually Delete the Volume File

```bash
# WARNING: This destroys backup data. Only do this in the lab environment.
sudo rm /srv/bareos-storage/volumes/Full-Vol-0001

# Verify it is gone
ls /srv/bareos-storage/volumes/
```

### Step 3: Note the Catalog Inconsistency

```bash
# The catalog still thinks the volume exists
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
list volumes
quit
EOF
# The deleted volume still appears with "Append" or "Full" status
```

### Step 4: Update the Volume Status to Reflect the Loss

```bash
# Mark the volume as "Purged" in the catalog
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
update volume=Full-Vol-0001 volstatus=Purged
quit
EOF
```

### Step 5: Stop the Director and Run dbcheck

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user stop bareos-dir

# Run dbcheck in verbose scan mode first
XDG_RUNTIME_DIR=/run/user/1001 podman run --rm \
  --env-file /home/bareos/.config/bareos/db.env \
  --network bareos-net \
  -v bareos-dir-config:/etc/bareos:ro,Z \
  docker.io/bareos/bareos-director:24 \
  dbcheck -c /etc/bareos/bareos-dir.conf -v 2>&1 | head -100

# Now run with fixes enabled
XDG_RUNTIME_DIR=/run/user/1001 podman run --rm \
  --env-file /home/bareos/.config/bareos/db.env \
  --network bareos-net \
  -v bareos-dir-config:/etc/bareos:ro,Z \
  docker.io/bareos/bareos-director:24 \
  dbcheck -c /etc/bareos/bareos-dir.conf -B -f -v
```

### Step 6: Restart and Verify

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-dir

# Check the catalog is now consistent
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole <<EOF
list volumes
messages
quit
EOF
```

The deleted volume should either be gone from the catalog or marked in a state that reflects its absence.

---

[↑ Back to Table of Contents](#table-of-contents)

## 24. Quick-Reference Error Table

| Error Message | Most Likely Cause | Immediate Fix |
|---|---|---|
| `No route to client` / `Connection refused` | FD not running, wrong address | Start FD: `systemctl --user start bareos-fd` |
| `No route to client` / `No route to host` | Firewall blocking port 9102 | Open firewall or check container network |
| `Director authorization error` | Password mismatch | Match passwords in Director Client resource and FD Director resource |
| `Client rejected: Name or password is wrong` | Name or password mismatch | Check both `Name` and `Password` on both sides |
| `TLS ... error` | TLS config mismatch (one side enabled, other not) | Make TLS settings consistent on both sides |
| `Volume not in catalog` | Volume file exists but was never labeled | Run `label` in bconsole |
| `Could not open ... No such file or directory` | Volume file deleted or path changed | Recreate volume file or correct `Archive Device` path |
| `Bad label: Volume=X Expected=Y` | Volume file renamed or replaced | Run `relabel` in bconsole |
| `Can't connect to MySQL server` | MariaDB container not running | `systemctl --user start bareos-db` |
| `Access denied for user 'bareos'` | Wrong DB credentials | Fix `db.env` and restart Director |
| `No files found to backup` | FileSet path wrong or all files excluded | Check `Include` block in FileSet resource |
| `Waiting on max Client jobs` | `Maximum Concurrent Jobs` limit hit | Increase `Maximum Concurrent Jobs` in Client or Job resource |
| `Job already running` | Stale catalog record from crash | `cancel jobid=N` in bconsole |
| `Unit not found` (systemctl) | Quadlet not processed yet | `systemctl --user daemon-reload` |
| `newuidmap: ... not allowed` | Missing subuid/subgid for bareos user | `usermod --add-subuids 100000-165535 bareos` |
| `permission denied` (no SELinux context) | Wrong SELinux context on path | `restorecon -Rv <path>` or `semanage fcontext` |
| `XDG_RUNTIME_DIR not set` | Missing env var when using sudo | Always set `XDG_RUNTIME_DIR=/run/user/1001` |
| Container exits immediately | Config error, missing env var, or DB not ready | `podman logs <container>` to see startup error |
| `Linger=no` | loginctl linger not enabled | `sudo loginctl enable-linger bareos` |
| DNS fails inside container | pasta/slirp4netns DNS issue | Check `/etc/resolv.conf` inside container |
| `dbcheck` finds orphaned records | Volumes deleted outside Bareos | Run `dbcheck -B -f` with Director stopped |
| `Spooling full` | Backup larger than spool space | Increase `Maximum Spool Size` or add spool directory |
| `estimate` shows 0 files | FileSet path not visible to FD | Check FD's view of the path; check bind mounts |

---

[↑ Back to Table of Contents](#table-of-contents)

## 25. Diagnostic Decision Tree

The following ASCII art flowchart guides you through the most common failure scenarios. Start at the top and follow the branches.

```
                    ┌────────────────────────┐
                    │   BACKUP JOB FAILED    │
                    │   or won't start       │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼────────────┐
                    │  Run: list joblog      │
                    │  jobid=N in bconsole   │
                    └───────────┬────────────┘
                                │
              ┌─────────────────┼──────────────────┐
              │                 │                  │
    ┌─────────▼──────┐ ┌────────▼───────┐ ┌───────▼────────┐
    │  "No route to  │ │ "Authorization │ │ "Cannot open   │
    │   client"      │ │  error"        │ │  Volume"       │
    └────────┬───────┘ └───────┬────────┘ └──────┬─────────┘
             │                 │                  │
    ┌────────▼───────┐ ┌───────▼────────┐ ┌──────▼─────────┐
    │ Is FD running? │ │ Check password │ │ Does file exist│
    │ podman ps      │ │ on BOTH sides  │ │ on disk?       │
    └────────┬───────┘ └───────┬────────┘ └──────┬─────────┘
             │                 │                  │
        ┌────▼────┐       ┌────▼────┐        ┌───▼────┐
        │  No     │       │Match?   │        │  No    │
        │  Start  │       │  No     │        │ Label  │
        │  FD     │       │  Fix    │        │ or     │
        └────┬────┘       │  both   │        │ Relabel│
             │            └─────────┘        └────────┘
        ┌────▼────┐
        │  Yes    │
        │ Check   │
        │ address │
        └────┬────┘
             │
        ┌────▼──────────────┐
        │ Check firewall    │
        │ firewall-cmd list │
        └────┬──────────────┘
             │
        ┌────▼──────────────┐
        │ Check SELinux:    │
        │ ausearch -m avc   │
        │ -ts recent        │
        └───────────────────┘


                    ┌────────────────────────┐
                    │  CONTAINER WON'T START │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼────────────┐
                    │ podman ps --all        │
                    │ shows Exited?          │
                    └───────────┬────────────┘
                                │
                   ┌────────────▼───────────┐
                   │ podman logs <name>     │
                   └────────────┬───────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
┌────────▼────────┐  ┌──────────▼──────────┐ ┌────────▼────────┐
│ Config error    │  │ DB not available    │ │ Missing env var │
│ Run: bareos-dir │  │ Check bareos-db     │ │ Check env-file  │
│ -t to test cfg  │  │ systemctl status   │ │ permissions 600 │
└─────────────────┘  └─────────────────────┘ └─────────────────┘


                    ┌────────────────────────┐
                    │  QUADLET UNIT MISSING  │
                    └───────────┬────────────┘
                                │
               ┌────────────────▼───────────────┐
               │ systemctl --user daemon-reload  │
               └────────────────┬───────────────┘
                                │
               ┌────────────────▼───────────────┐
               │ systemctl --user list-unit-files│
               │ | grep bareos                  │
               └────────────────┬───────────────┘
                                │
                    ┌───────────▼────────────┐
                    │ Still missing?         │
                    │ Check .container file  │
                    │ syntax in:             │
                    │ ~/.config/containers/  │
                    │ systemd/               │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼────────────┐
                    │ Check Quadlet generator│
                    │ journalctl --user -xe  │
                    │ | grep -i quadlet      │
                    └────────────────────────┘


                    ┌────────────────────────┐
                    │   SELinux DENIAL       │
                    └───────────┬────────────┘
                                │
               ┌────────────────▼───────────────┐
               │ ausearch -m avc -ts recent      │
               │ | audit2why                     │
               └────────────────┬───────────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
┌────────▼────────┐  ┌──────────▼──────────┐ ┌────────▼────────┐
│ Wrong file type │  │ Port not allowed     │ │ No TE rule      │
│ semanage +      │  │ semanage port -a     │ │ audit2allow -M  │
│ restorecon      │  │ or setsebool         │ │ semodule -i     │
└─────────────────┘  └─────────────────────┘ └─────────────────┘
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 26. Summary

This chapter has given you a complete toolkit for diagnosing and resolving Bareos failures in a rootless Podman environment on RHEL 10. The key points to take away:

**Always start with the job log.** The Bareos job log is specific, timestamped, and actionable. Every Bareos diagnosis should begin with `list joblog jobid=N` in bconsole.

**The daemon journals are your second resource.** Use `journalctl --user -u bareos-dir` (and `-sd`, `-fd`, `-db`) to see what happened at the daemon level. Always set `XDG_RUNTIME_DIR=/run/user/1001` before running commands as the bareos user.

**SELinux is your friend, not your enemy.** A mysterious "permission denied" in a container is almost certainly a SELinux denial. Use `ausearch -m avc -ts recent | audit2why` to understand it, and `restorecon` or `semanage fcontext` to fix it. Never set SELinux to permissive.

**Rootless Podman has three prerequisites:** linger enabled (`loginctl enable-linger bareos`), `XDG_RUNTIME_DIR` set correctly, and sub-UIDs configured in `/etc/subuid` and `/etc/subgid`.

**Quadlet failures are usually syntax problems.** When a unit does not appear after `daemon-reload`, check the `.container` file syntax and run the Quadlet generator manually to see error output.

**`dbcheck` is the catalog repair tool.** Run it with the Director stopped, in `-v` mode first to assess damage, then with `-B -f` to repair it.

**The Quick-Reference Error Table** (Section 24) and the Diagnostic Decision Tree (Section 25) are your quick-lookup guides for the most common problems.

With the techniques in this chapter, you can confidently diagnose and resolve the full range of issues that arise in a production Bareos deployment.

---

[↑ Back to Table of Contents](#table-of-contents)
