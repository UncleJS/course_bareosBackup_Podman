# Chapter 9: Backing Up Podman Volumes

## Table of Contents

- [1. Why Container Volume Backup is Different](#1-why-container-volume-backup-is-different)
  - [The Indirection Problem](#the-indirection-problem)
  - [The Moving Target Problem](#the-moving-target-problem)
  - [The Rootless UID Problem](#the-rootless-uid-problem)
- [2. Named Volumes: Location and Structure](#2-named-volumes-location-and-structure)
  - [What's in the Volume Storage Path?](#whats-in-the-volume-storage-path)
  - [SELinux Context of Named Volumes](#selinux-context-of-named-volumes)
- [3. Bind Mounts: Direct Path Backups](#3-bind-mounts-direct-path-backups)
  - [Preferred Pattern for Production](#preferred-pattern-for-production)
- [4. The UID Mapping Problem](#4-the-uid-mapping-problem)
  - [Understanding the Mapping](#understanding-the-mapping)
  - [How bareos-fd Gets Access](#how-bareos-fd-gets-access)
  - [Granting SELinux Access to Named Volume Files](#granting-selinux-access-to-named-volume-files)
- [5. Strategy 1: Back Up Named Volume Data Directly](#5-strategy-1-back-up-named-volume-data-directly)
  - [Pros and Cons](#pros-and-cons)
  - [When to Use](#when-to-use)
- [6. Strategy 2: Export Volume Data via a Sidecar Container](#6-strategy-2-export-volume-data-via-a-sidecar-container)
  - [Pros and Cons](#pros-and-cons)
  - [When to Use](#when-to-use)
- [7. Strategy 3: Podman Volume Export (podman volume export)](#7-strategy-3-podman-volume-export-podman-volume-export)
  - [Importing During Restore](#importing-during-restore)
  - [Integrating with Bareos: Pre-Job Script](#integrating-with-bareos-pre-job-script)
- [8. FileSet Configuration for Container Volumes](#8-fileset-configuration-for-container-volumes)
  - [Discovering All Named Volumes](#discovering-all-named-volumes)
- [9. Consistency Considerations for Volume Backups](#9-consistency-considerations-for-volume-backups)
  - [Applications That Write Continuously](#applications-that-write-continuously)
  - [Applications That Use SQLite](#applications-that-use-sqlite)
  - [Applications With Their Own Backup Mechanisms](#applications-with-their-own-backup-mechanisms)
- [10. Restoring to a Named Volume](#10-restoring-to-a-named-volume)
  - [Restore to a Temporary Path, Then Import](#restore-to-a-temporary-path-then-import)
  - [Restore via podman volume import (export strategy)](#restore-via-podman-volume-import-export-strategy)
- [11. Lab 9-1: Backing Up a Named Volume](#11-lab-9-1-backing-up-a-named-volume)
- [12. Lab 9-2: Backing Up a Bind-Mounted Application](#12-lab-9-2-backing-up-a-bind-mounted-application)
- [13. Lab 9-3: Restoring a Named Volume](#13-lab-9-3-restoring-a-named-volume)
- [14. Summary](#14-summary)

## 1. Why Container Volume Backup is Different

Containers introduce a fundamental shift in how persistent data is organized. On a traditional server, you know exactly where application data lives: `/var/www/html`, `/var/lib/mysql`, `/opt/appname/data`. Backup is straightforward — add those paths to your FileSet.

With containers, the situation is more complex:

### The Indirection Problem

A container's filesystem is ephemeral. The interesting data lives in **volumes** that are mounted into the container. Those volumes might be:

1. **Named volumes**: Managed by Podman, stored in `~/.local/share/containers/storage/volumes/<volume-name>/_data/`
2. **Bind mounts**: A specific host directory mounted into the container
3. **tmpfs**: Ephemeral in-memory storage — by definition not persistent

If you back up `/var/lib/containers/storage/overlay` (the container overlay filesystem), you get a mess of layered image data that is not meaningful for restore purposes. What you need is the **volume data** — the actual application state.

### The Moving Target Problem

When containers are updated, removed, and recreated, the data in named volumes persists but the container instance changes. The Bareos FileSet must target the volume paths, not the container-specific paths.

### The Rootless UID Problem

In rootless Podman, files inside a named volume are owned by the container's mapped UIDs, not the host user's UID. The Bareos File Daemon (running on the host) must be able to read those files. This requires understanding the UID mapping and either running the FD with appropriate privileges or pre-staging data.

We cover this in depth in this chapter and [Chapter 13](./13-rootless-podman-specifics.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Named Volumes: Location and Structure

When the `bareos` user creates a named volume:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume create myapp-data

# Volume created: myapp-data
```

Podman stores the volume at:
```
/home/bareos/.local/share/containers/storage/volumes/myapp-data/_data/
```

Let's verify:
```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume inspect myapp-data --format '{{.Mountpoint}}'

# Output:
# /home/bareos/.local/share/containers/storage/volumes/myapp-data/_data
```

### What's in the Volume Storage Path?

```
/home/bareos/.local/share/containers/storage/volumes/
├── myapp-data/
│   ├── _data/            ← ACTUAL data written by the container
│   │   ├── config.json
│   │   ├── uploads/
│   │   └── state.db
│   └── locks/            ← Podman lock files (NOT needed in backup)
├── bareos-db-data/
│   └── _data/            ← MariaDB data files
└── bareos-working/
    └── _data/            ← Bareos working data
```

**The `_data/` subdirectory is what you back up.** The `locks/` directory contains Podman runtime lock files and should be excluded.

### SELinux Context of Named Volumes

Named volumes are automatically labeled `container_file_t` by Podman:

```bash
ls -Zd /home/bareos/.local/share/containers/storage/volumes/myapp-data/_data
# Output: system_u:object_r:container_file_t:s0  _data/
```

The Bareos File Daemon, running as root (via `bareos-fd` systemd service), needs read access to `container_file_t` labeled files. By default, the `bareos_t` SELinux context has this permission, but verify:

```bash
# Check if bareos_t can read container_file_t
sesearch --allow --source bareos_t --target container_file_t --class file --perm read
```

If not permitted, add a custom SELinux module (covered in [Chapter 13](./13-rootless-podman-specifics.md)).

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Bind Mounts: Direct Path Backups

Bind mounts are host directories that are mounted into a container. They live at known, stable host paths:

```bash
# Example: a web application using a bind mount
podman run -d \
  --name webapp \
  -v /opt/webapp-data:/app/data:Z \
  docker.io/myapp:latest
```

The application data lives at `/opt/webapp-data/` on the host — a completely normal host directory. Back it up exactly as you would any other directory:

```bareos
FileSet {
  Name = "WebApp-BindMount"
  Include {
    Options { Signature = SHA256; Compression = ZSTD }
    File = /opt/webapp-data
  }
}
```

**Bind mounts are the simplest case.** There is no UID mapping complexity — the files are owned by the host UID that the container runs as (or root if the container runs as root). The Bareos FD reads them like any other host files.

### Preferred Pattern for Production

For applications where the host path matters (e.g., you need to find and inspect the data without running the container), use bind mounts rather than named volumes:

```
/srv/                               ← on the dedicated data disk
├── webapp/
│   ├── data/                       ← container bind mount: -v /srv/webapp/data:/app/data
│   ├── config/                     ← container bind mount: -v /srv/webapp/config:/etc/app
│   └── uploads/                    ← container bind mount: -v /srv/webapp/uploads:/uploads
└── mariadb/
    └── data/                       ← MariaDB bind mount: -v /srv/mariadb/data:/var/lib/mysql
```

In your Bareos FileSet:
```bareos
FileSet {
  Name = "Application-Data"
  Include {
    Options { Signature = SHA256; Compression = ZSTD; AclSupport = yes; XattrSupport = yes }
    File = /srv/webapp
    File = /srv/mariadb
  }
  Exclude {
    File = /srv/mariadb/data/mysql_upgrade_info  # non-critical runtime file
  }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. The UID Mapping Problem

This is the most important concept in Podman volume backup. Get it wrong and the File Daemon silently skips files it cannot read.

### Understanding the Mapping

When a rootless container writes a file as container-root (UID 0), that UID maps to the first subordinate UID of the Podman user. For the `bareos` user with sub-UID range `100000-165535`:

```
Container UID 0  (root)       → Host UID 100000
Container UID 1               → Host UID 100001
Container UID 1000 (appuser)  → Host UID 101000
...
```

Files in a named volume are owned by `100000` on the host:

```bash
ls -lan /home/bareos/.local/share/containers/storage/volumes/myapp-data/_data/
# Output: drwxr-xr-x. 2 100000 100000  ...  _data/
#          -rw-r--r--. 1 100000 100000  ...  config.json
```

The Bareos File Daemon runs as the `bareos` system user (UID 1001). It tries to read files owned by UID 100000. Since 100000 ≠ 1001, the FD must rely on:
- **Other permissions** (the world-readable bit on the files), or
- **DAC override via `bareos_t` SELinux context**, or
- **Running the FD as root** (the default for `bareos-fd` systemd service)

### How bareos-fd Gets Access

The `bareos-fd` RPM service runs as **root** by default (unlike the containers). This is intentional — the File Daemon needs to access all files on the client, including those owned by any UID. Check:

```bash
systemctl cat bareos-fd | grep User
# If blank: runs as root (default)
# If "User = bareos": runs as the bareos user
```

When running as root, the FD can read any file regardless of ownership. However, SELinux still applies — even root cannot access `container_file_t` files if the SELinux policy does not permit it.

### Granting SELinux Access to Named Volume Files

```bash
# Allow bareos_t to read container_file_t files
sudo tee /tmp/bareos-container-access.te > /dev/null <<'EOF'
module bareos-container-access 1.0;

require {
  type bareos_t;
  type container_file_t;
  class file { open read getattr };
  class dir { open read search getattr };
}

allow bareos_t container_file_t:file { open read getattr };
allow bareos_t container_file_t:dir { open read search getattr };
EOF

sudo checkmodule -M -m -o /tmp/bareos-container-access.mod /tmp/bareos-container-access.te
sudo semodule_package -o /tmp/bareos-container-access.pp -m /tmp/bareos-container-access.mod
sudo semodule -i /tmp/bareos-container-access.pp

# Verify the policy was loaded
sudo semodule -l | grep bareos-container
```

This policy module allows the `bareos_t` process context to read files and directories labeled `container_file_t`. This is the correct, minimal SELinux fix.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Strategy 1: Back Up Named Volume Data Directly

The simplest strategy: add the named volume's `_data` path to the Bareos FileSet.

```bareos
FileSet {
  Name = "Podman-Named-Volumes"
  Include {
    Options {
      Signature = SHA256
      Compression = ZSTD
      AclSupport = yes
      XattrSupport = yes
    }

    # Back up all named volumes for the bareos user
    # The _data subdirectory contains the actual application data
    File = /home/bareos/.local/share/containers/storage/volumes/myapp-data/_data
    File = /home/bareos/.local/share/containers/storage/volumes/webapp-uploads/_data
    File = /home/bareos/.local/share/containers/storage/volumes/bareos-db-data/_data

  }
  Exclude {
    # Exclude Podman lock files — these are runtime state, not persistent data
    Wild = "*/locks/*"
  }
}
```

### Pros and Cons

**Pros:**
- Simple: no extra tooling or scripts
- Files are backed up as they are
- Incremental backups work correctly (changed files detected by mtime/checksum)

**Cons:**
- Files may be in an inconsistent state if the container is actively writing
- Files are owned by subordinate UIDs (100000+) — may confuse administrators looking at the catalog

### When to Use

Use this strategy for:
- Stateless or low-write applications (static web content, config files)
- Applications with their own internal consistency mechanisms (LevelDB, SQLite with WAL mode)
- When a pre/post hook ([Chapter 10](./10-podman-hooks.md)) will quiesce the application before backup

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Strategy 2: Export Volume Data via a Sidecar Container

A **sidecar container** is a temporary container that mounts the same volume as the application, creates a consistent export (e.g., a tar archive), and writes it to a location the FD can access.

```bash
#!/bin/bash
# pre-backup-myapp.sh — run as ClientRunBeforeJob

set -euo pipefail

VOLUME_NAME="myapp-data"
EXPORT_DIR="/tmp/bareos-volume-exports"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

mkdir -p "${EXPORT_DIR}"

# Stop the application container to ensure consistency
podman stop myapp 2>/dev/null || true

# Run a sidecar to create a tar archive of the volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/$(id -u bareos) \
  podman run --rm \
    --user root \
    -v "${VOLUME_NAME}:/source:ro,Z" \
    -v "${EXPORT_DIR}:/output:Z" \
    docker.io/library/alpine:3.19 \
    tar -czf "/output/${VOLUME_NAME}-${TIMESTAMP}.tar.gz" -C /source .

# Restart the application container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/$(id -u bareos) \
  podman start myapp 2>/dev/null || true

echo "Volume export created: ${EXPORT_DIR}/${VOLUME_NAME}-${TIMESTAMP}.tar.gz"
```

The FileSet then backs up the export directory:

```bareos
FileSet {
  Name = "Volume-Exports"
  Include {
    Options { Signature = SHA256 }
    File = /tmp/bareos-volume-exports
  }
}
```

### Pros and Cons

**Pros:**
- The tar archive is owned by the host user (not subordinate UIDs)
- The archive is a consistent, portable snapshot of the volume
- No SELinux complexity — the export is in a normal host directory

**Cons:**
- Requires a pre-backup script (stop container → export → start container)
- The application has downtime during export
- Two copies of the data exist briefly (volume + export)
- Storage overhead of the tar archive

### When to Use

Use this strategy when:
- The application cannot be safely backed up live
- You need a truly consistent snapshot
- The volume data is complex (many interdependent files)

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Strategy 3: Podman Volume Export (podman volume export)

Podman 4.0+ includes a `podman volume export` command that creates a tar archive of a named volume:

```bash
# Export a named volume to a tar file
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume export myapp-data \
  --output /tmp/bareos-volume-exports/myapp-data.tar

# Or pipe directly (no intermediate file needed for streaming backup)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume export myapp-data | \
  gzip > /tmp/bareos-volume-exports/myapp-data.tar.gz
```

The exported tar contains all files from the volume, owned by UID 0 (root) inside the archive.

### Importing During Restore

```bash
# On restore: import back into a named volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume import myapp-data /tmp/bareos-volume-exports/myapp-data.tar
```

> **Important**: `podman volume import` **replaces** the entire volume content. Make sure the target volume exists and is not currently in use by a running container.

### Integrating with Bareos: Pre-Job Script

```bash
#!/bin/bash
# /usr/local/bin/bareos-export-volumes.sh

set -euo pipefail

BAREOS_USER="bareos"
BAREOS_XDG="/run/user/$(id -u ${BAREOS_USER})"
EXPORT_DIR="/var/lib/bareos/volume-exports"

mkdir -p "${EXPORT_DIR}"

# List of named volumes to export (space-separated)
VOLUMES="myapp-data webapp-uploads app-config"

for VOL in ${VOLUMES}; do
  echo "Exporting volume: ${VOL}"
  sudo -u "${BAREOS_USER}" XDG_RUNTIME_DIR="${BAREOS_XDG}" \
    podman volume export "${VOL}" \
    --output "${EXPORT_DIR}/${VOL}.tar"
  echo "  Exported to ${EXPORT_DIR}/${VOL}.tar ($(du -sh "${EXPORT_DIR}/${VOL}.tar" | cut -f1))"
done

echo "All volumes exported to ${EXPORT_DIR}"
```

Configure this as a `ClientRunBeforeJob` in the backup job:

```bareos
Job {
  Name = "BackupContainerVolumes"
  JobDefs = "StandardBackup"
  Client = bareos-fd
  FileSet = "Volume-Exports-FileSet"
  Schedule = "WeeklyBackup"
  ClientRunBeforeJob = "/usr/local/bin/bareos-export-volumes.sh"
  ClientRunAfterJob = "/usr/local/bin/bareos-cleanup-exports.sh"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. FileSet Configuration for Container Volumes

A comprehensive FileSet that handles both named volumes and bind mounts:

```bareos
FileSet {
  Name = "Container-Data-Complete"

  Include {
    Options {
      Signature = SHA256
      Compression = ZSTD
      AclSupport = yes
      XattrSupport = yes
      OneFs = yes
    }

    # --- Bind mount paths (host directories, normal ownership) ---
    File = /srv/webapp/data
    File = /srv/webapp/uploads
    File = /srv/webapp/config

    # --- Named volume data (subordinate UID ownership) ---
    File = /home/bareos/.local/share/containers/storage/volumes/myapp-data/_data
    File = /home/bareos/.local/share/containers/storage/volumes/app-config/_data

    # --- Volume exports (if using export strategy) ---
    File = /var/lib/bareos/volume-exports

  }

  Exclude {
    # Podman runtime lock files
    Wild = "*/locks/*"
    # Podman overlay layers (not persistent data)
    Wild = "*/overlay/*"
    # Log files (if not needed)
    Wild = "*.log"
    Wild = "*.log.*"
  }
}
```

### Discovering All Named Volumes

To avoid missing volumes, use a dynamic discovery script:

```bash
#!/bin/bash
# discover-container-volumes.sh
# Run to generate a list of all named volume paths

BAREOS_USER="bareos"
BAREOS_XDG="/run/user/$(id -u ${BAREOS_USER})"

echo "# Auto-discovered named volume paths"
echo "# Generated: $(date)"
echo ""

sudo -u "${BAREOS_USER}" XDG_RUNTIME_DIR="${BAREOS_XDG}" \
  podman volume ls --format '{{.Name}}' | while read -r VOLNAME; do
    MOUNTPOINT=$(sudo -u "${BAREOS_USER}" XDG_RUNTIME_DIR="${BAREOS_XDG}" \
      podman volume inspect "${VOLNAME}" --format '{{.Mountpoint}}')
    echo "File = ${MOUNTPOINT}"
  done
```

Run this periodically and update your FileSet configuration when new volumes are discovered.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Consistency Considerations for Volume Backups

### Applications That Write Continuously

Web applications, log aggregators, and monitoring agents write continuously. For these, a live backup captures a consistent state because:
- Individual files are atomic (a complete write to a file is always consistent)
- Application-level consistency doesn't require file-level consistency

However, if the application maintains state across multiple files (like a database), live backup is problematic. For those cases, use pre/post hooks ([Chapter 10](./10-podman-hooks.md)).

### Applications That Use SQLite

SQLite is common in containerized applications (e.g., Nextcloud, Gitea, Vaultwarden). SQLite with WAL (Write-Ahead Logging) mode is safe to back up live because:
- WAL mode writes new data to a separate WAL file
- The main database file remains consistent
- SQLite can recover from a mid-write backup

Verify WAL mode is enabled:
```bash
# Inside the container
sqlite3 /app/data/app.db "PRAGMA journal_mode;"
# Output: wal  ← safe to backup live

# If output is "delete" (the default), WAL is not enabled
sqlite3 /app/data/app.db "PRAGMA journal_mode=WAL;"
```

### Applications With Their Own Backup Mechanisms

Some containerized applications provide built-in backup commands:
- Nextcloud: `php occ maintenance:mode --on` before backup
- Gitea: `gitea admin git repositories delete` (not backup, but has `dump`)
- Vaultwarden: exports to a ZIP archive

Use `ClientRunBeforeJob` to trigger these before Bareos reads the files.

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Restoring to a Named Volume

After restoring volume data from a backup, you need to put it back into the named volume.

### Restore to a Temporary Path, Then Import

```bash
# Step 1: Restore using bconsole to a temporary location
bconsole <<'EOF'
restore
5
1
cd /home/bareos/.local/share/containers/storage/volumes/myapp-data/_data
mark *
done
mod
9
/tmp/volume-restore-temp
yes
wait
quit
EOF

# Step 2: Stop the container using this volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman stop myapp

# Step 3: Clear the volume and restore the data
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
    -v myapp-data:/target:Z \
    -v /tmp/volume-restore-temp/home/bareos/.local/share/containers/storage/volumes/myapp-data/_data:/source:ro,Z \
    alpine sh -c "rm -rf /target/* && cp -a /source/. /target/"

# Step 4: Restart the container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman start myapp

# Step 5: Verify
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec myapp ls /app/data/

# Step 6: Cleanup
rm -rf /tmp/volume-restore-temp
```

### Restore via podman volume import (export strategy)

If you used the `podman volume export` strategy, restore is simpler:

```bash
# Restore the archive from Bareos to a temp path
bconsole <<'EOF'
restore
5
1
cd /var/lib/bareos/volume-exports
mark myapp-data.tar
done
mod
9
/tmp/volume-tar-restore
yes
wait
quit
EOF

# Stop the container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman stop myapp

# Import the tar back into the volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume import myapp-data \
  /tmp/volume-tar-restore/var/lib/bareos/volume-exports/myapp-data.tar

# Restart
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman start myapp

# Cleanup
rm -rf /tmp/volume-tar-restore
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Lab 9-1: Backing Up a Named Volume

```bash
# Step 1: Create a test application with a named volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash << 'SHELL'
# Create a named volume
podman volume create testapp-data

# Run a container that writes data to the volume
podman run --rm \
  -v testapp-data:/data:Z \
  alpine sh -c "
    mkdir -p /data/config /data/uploads
    echo '{\"key\":\"value\"}' > /data/config/app.json
    echo 'important document content' > /data/uploads/doc1.txt
    echo 'another file' > /data/uploads/doc2.txt
    ls -la /data/
  "
SHELL

# Step 2: Find the volume data path
VOLUME_PATH=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume inspect testapp-data --format '{{.Mountpoint}}')
echo "Volume data path: ${VOLUME_PATH}"

# Step 3: Verify FD can read the files (must be running as root)
ls -lan "${VOLUME_PATH}"

# Step 4: Create a FileSet for this volume
sudo -u bareos tee /etc/bareos/bareos-dir.d/fileset/TestAppVolume.conf > /dev/null <<FEOF
FileSet {
  Name = "TestApp-Volume"
  Include {
    Options {
      Signature = SHA256
      Compression = ZSTD
    }
    File = ${VOLUME_PATH}
  }
}
FEOF

# Step 5: Create a job for this backup
sudo -u bareos tee /etc/bareos/bareos-dir.d/job/BackupTestApp.conf > /dev/null <<JEOF
Job {
  Name = "BackupTestApp"
  JobDefs = "StandardBackup"
  Client = bareos-fd
  FileSet = "TestApp-Volume"
  Schedule = "WeeklyBackup"
}
JEOF

# Step 6: Reload and run
echo "reload" | bconsole
bconsole <<'EOF'
run job=BackupTestApp level=Full yes
wait
messages
quit
EOF

echo "Backup of named volume complete!"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 9-2: Backing Up a Bind-Mounted Application

```bash
# Step 1: Create a bind-mount-based application
sudo mkdir -p /srv/testwebapp/{data,config,logs}
sudo tee /srv/testwebapp/config/app.conf > /dev/null <<'EOF'
server_name = testwebapp
port = 8080
data_dir = /app/data
EOF
sudo tee /srv/testwebapp/data/users.json > /dev/null <<'EOF'
{"users": [{"id": 1, "name": "Alice"}, {"id": 2, "name": "Bob"}]}
EOF
sudo chown -R bareos:bareos /srv/testwebapp

# Step 2: Run a container using bind mounts
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run -d \
  --name testwebapp \
  -v /srv/testwebapp/config:/app/config:Z \
  -v /srv/testwebapp/data:/app/data:Z \
  alpine sleep infinity

# Step 3: Create the FileSet (simple — it's just host paths)
sudo -u bareos tee /etc/bareos/bareos-dir.d/fileset/BindMountApp.conf > /dev/null <<'FEOF'
FileSet {
  Name = "BindMount-WebApp"
  Include {
    Options {
      Signature = SHA256
      Compression = ZSTD
      AclSupport = yes
      XattrSupport = yes
    }
    File = /srv/testwebapp/config
    File = /srv/testwebapp/data
  }
  Exclude {
    File = /srv/testwebapp/logs   # logs managed separately
  }
}
FEOF

# Step 4: Run the backup
echo "reload" | bconsole
bconsole <<'EOF'
run job=BackupLocalHost level=Full yes
wait
messages
quit
EOF

# Step 5: Verify backed-up files
echo "list files jobid=latest" | bconsole | grep testwebapp

# Cleanup
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman rm -f testwebapp
sudo rm -rf /srv/testwebapp
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Lab 9-3: Restoring a Named Volume

```bash
# Prerequisite: Lab 9-1 has been run (testapp-data volume backup exists)

VOLUME_PATH=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume inspect testapp-data --format '{{.Mountpoint}}' 2>/dev/null || echo "NOT_FOUND")

# Step 1: Simulate data loss
if [ "${VOLUME_PATH}" != "NOT_FOUND" ]; then
  echo "Deleting volume data (simulating disaster)..."
  sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman volume rm testapp-data
fi

# Step 2: Recreate the empty volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman volume create testapp-data
NEW_VOLUME_PATH=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume inspect testapp-data --format '{{.Mountpoint}}')

echo "New (empty) volume path: ${NEW_VOLUME_PATH}"
ls -la "${NEW_VOLUME_PATH}"

# Step 3: Restore the backup
bconsole <<'BEOF'
restore
5
1

cd ${VOLUME_PATH}
mark *
lsmark

done
mod
9
/tmp/volume-restore-lab

yes
wait
messages
quit
BEOF

# Step 4: Copy restored data into the volume
sudo cp -a \
  "/tmp/volume-restore-lab${VOLUME_PATH}/." \
  "${NEW_VOLUME_PATH}/"

# Step 5: Fix ownership (must be owned by sub-UID 100000 for rootless container access)
BAREOS_SUBUID=$(grep bareos /etc/subuid | cut -d: -f2)
sudo chown -R ${BAREOS_SUBUID}:${BAREOS_SUBUID} "${NEW_VOLUME_PATH}"

# Step 6: Verify the data is back
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
  -v testapp-data:/data:ro,Z \
  alpine sh -c "echo '=== Restored volume contents ==='; find /data -type f -exec echo {} \;"

echo ""
echo "Restore of named volume complete!"

# Cleanup
rm -rf /tmp/volume-restore-lab
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman volume rm testapp-data
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Summary

In this chapter you learned the full spectrum of Podman volume backup strategies:

- **Named volumes vs. bind mounts**: Named volumes live in `~/.local/share/containers/storage/volumes/<name>/_data/`. Bind mounts live at explicit host paths and are simplest to back up.
- **The UID mapping problem**: Files in named volumes are owned by subordinate UIDs (100000+). The `bareos-fd` service running as root can read them, but SELinux policy may block access. A custom SELinux module grants `bareos_t` read access to `container_file_t` files.
- **Strategy 1 (direct path backup)**: Add `_data` paths to the FileSet. Simple, works for live backups of stateless applications.
- **Strategy 2 (sidecar export)**: A temporary container exports the volume to a tar file, which is then backed up. Good for complex, stateful applications.
- **Strategy 3 (`podman volume export`)**: Podman's built-in export command creates a portable tar archive. Simplest restore path via `podman volume import`.
- **FileSet design**: Include `_data` subdirectories and volume export directories; exclude `locks/` and `overlay/` subdirectories.
- **Consistency**: Use pre/post hooks for databases, enable SQLite WAL mode for live-safe backups, or use application-provided maintenance mode.
- **Restore**: Restore to a temp path, then copy into the volume with correct UID ownership (subordinate UID range), or use `podman volume import` for the export strategy.

---

**Next Chapter:** [Chapter 10: Container Pre/Post Hooks](./10-podman-hooks.md)

---

[↑ Back to Table of Contents](#table-of-contents)
