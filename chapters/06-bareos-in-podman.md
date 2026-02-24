# Chapter 6: Deploying Bareos in Podman

## Table of Contents
1. [Deployment Architecture Overview](#1-deployment-architecture-overview)
2. [Directory and Secret Layout](#2-directory-and-secret-layout)
3. [Generating Secure Passwords](#3-generating-secure-passwords)
4. [Quadlet Network and Volume Definitions](#4-quadlet-network-and-volume-definitions)
5. [Deploying the MariaDB Catalog Container](#5-deploying-the-mariadb-catalog-container)
6. [Deploying the Bareos Storage Daemon Container](#6-deploying-the-bareos-storage-daemon-container)
7. [Deploying the Bareos Director Container](#7-deploying-the-bareos-director-container)
8. [Installing the File Daemon on the Host](#8-installing-the-file-daemon-on-the-host)
9. [Initializing the Catalog Database](#9-initializing-the-catalog-database)
10. [Starting All Services and Verifying](#10-starting-all-services-and-verifying)
11. [Connecting with bconsole](#11-connecting-with-bconsole)
12. [Lab 6-1: Full Deployment Walkthrough](#12-lab-6-1-full-deployment-walkthrough)
13. [Lab 6-2: Verifying Inter-Container Connectivity](#13-lab-6-2-verifying-inter-container-connectivity)
14. [Summary](#14-summary)

---

## 1. Deployment Architecture Overview

This chapter deploys the complete Bareos stack as rootless Podman containers managed by Quadlet. Here is what we will build:

```
/home/bareos/
├── .config/
│   ├── containers/systemd/         ← Quadlet unit files
│   │   ├── bareos.network
│   │   ├── bareos-db-data.volume
│   │   ├── bareos-config.volume
│   │   ├── bareos-db.container
│   │   ├── bareos-storage.container
│   │   └── bareos-director.container
│   └── bareos/
│       ├── db.env                  ← MariaDB credentials (mode 600)
│       └── bareos.env              ← Bareos shared passwords (mode 600)
├── .local/share/containers/       ← Podman image and volume storage
│
/srv/bareos-storage/
└── volumes/                        ← Bareos backup Volumes (on dedicated disk)

/etc/bareos/                        ← Bareos configuration (bind-mounted into Director)
├── bareos-dir.d/
├── bareos-sd.d/
└── bareos-fd.d/
```

### Service Dependencies

```
bareos-director  ──depends on──► bareos-storage
                 ──depends on──► bareos-db
                 ──depends on──► bareos-fd (host RPM service)

bareos-storage   ──depends on──► bareos.network (Quadlet)
bareos-db        ──depends on──► bareos.network (Quadlet)
```

Systemd/Quadlet automatically enforces these dependencies based on `After=` and `Requires=` directives.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Directory and Secret Layout

### Creating the Configuration Directory Structure

```bash
# Run as root (to create /etc/bareos owned by bareos user)
sudo mkdir -p /etc/bareos/{bareos-dir.d,bareos-sd.d,bareos-fd.d}
sudo mkdir -p /etc/bareos/bareos-dir.d/{catalog,client,console,director,fileset,job,jobdefs,messages,pool,profile,schedule,storage}
sudo mkdir -p /etc/bareos/bareos-sd.d/{device,director,messages,storage}
sudo mkdir -p /etc/bareos/bareos-fd.d/{client,director,messages}

# Own all config by the bareos user
sudo chown -R bareos:bareos /etc/bareos
sudo chmod -R 750 /etc/bareos
sudo chmod -R 640 /etc/bareos/bareos-dir.d /etc/bareos/bareos-sd.d /etc/bareos/bareos-fd.d

# Set correct SELinux context for Bareos config
sudo semanage fcontext -a -t bareos_etc_t "/etc/bareos(/.*)?"
sudo restorecon -Rv /etc/bareos

# Create the env file directory for the bareos user
sudo -u bareos mkdir -p /home/bareos/.config/bareos
sudo chmod 700 /home/bareos/.config/bareos

# Create the Quadlet directory
sudo -u bareos mkdir -p /home/bareos/.config/containers/systemd
```

### The Environment Files

We use environment files to keep secrets out of Quadlet unit files. These files are mode `600` and owned by `bareos`.

```bash
# Create the MariaDB credentials file
sudo -u bareos tee /home/bareos/.config/bareos/db.env > /dev/null <<'EOF'
MARIADB_ROOT_PASSWORD=CHANGEME_ROOT_STRONG_PASSWORD
MARIADB_DATABASE=bareos
MARIADB_USER=bareos
MARIADB_PASSWORD=CHANGEME_BAREOS_DB_PASSWORD
EOF
sudo chmod 600 /home/bareos/.config/bareos/db.env

# Create the Bareos daemon passwords file
sudo -u bareos tee /home/bareos/.config/bareos/bareos.env > /dev/null <<'EOF'
BAREOS_SD_PASSWORD=CHANGEME_SD_PASSWORD
BAREOS_FD_PASSWORD=CHANGEME_FD_PASSWORD
BAREOS_DIRECTOR_PASSWORD=CHANGEME_DIRECTOR_PASSWORD
BAREOS_MONITOR_PASSWORD=CHANGEME_MONITOR_PASSWORD
EOF
sudo chmod 600 /home/bareos/.config/bareos/bareos.env
```

> **Security**: Replace all `CHANGEME_*` values with strong random passwords in the next section. Never use these placeholder values.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Generating Secure Passwords

Generate cryptographically random passwords for all Bareos authentication:

```bash
# Generate strong passwords (each command produces one password)
# Run as any user — copy outputs to replace CHANGEME_ values above

# MariaDB root password (32 characters)
openssl rand -base64 32 | tr -d '=/+' | head -c 32

# MariaDB bareos user password
openssl rand -base64 32 | tr -d '=/+' | head -c 32

# Bareos Storage Daemon password
openssl rand -base64 32 | tr -d '=/+' | head -c 32

# Bareos File Daemon password
openssl rand -base64 32 | tr -d '=/+' | head -c 32

# Bareos Director/Console password
openssl rand -base64 32 | tr -d '=/+' | head -c 32

# Bareos Monitor password
openssl rand -base64 32 | tr -d '=/+' | head -c 32
```

Update `/home/bareos/.config/bareos/db.env` and `/home/bareos/.config/bareos/bareos.env` with the generated values.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Quadlet Network and Volume Definitions

### Network Definition

```bash
sudo -u bareos tee /home/bareos/.config/containers/systemd/bareos.network > /dev/null <<'EOF'
# bareos.network — Internal network for Bareos containers

[Network]
Driver=bridge
Subnet=10.89.10.0/24
Gateway=10.89.10.1
Label=app=bareos
Label=managed-by=quadlet
EOF
```

This creates a dedicated bridge network `bareos` with a known subnet. All Bareos containers join this network and can reach each other by container name.

### Volume Definitions

```bash
# MariaDB catalog data volume
sudo -u bareos tee /home/bareos/.config/containers/systemd/bareos-db-data.volume > /dev/null <<'EOF'
# bareos-db-data.volume — Persistent storage for the Bareos MariaDB catalog

[Volume]
Driver=local
Label=app=bareos
Label=component=catalog
EOF

# Bareos working data volume (bootstrap files, scripts, etc.)
sudo -u bareos tee /home/bareos/.config/containers/systemd/bareos-working.volume > /dev/null <<'EOF'
# bareos-working.volume — Bareos working directory (bootstrap files, etc.)

[Volume]
Driver=local
Label=app=bareos
Label=component=working
EOF
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Deploying the MariaDB Catalog Container

### Quadlet File for MariaDB

```bash
sudo -u bareos tee /home/bareos/.config/containers/systemd/bareos-db.container > /dev/null <<'EOF'
# bareos-db.container — MariaDB catalog database for Bareos

[Unit]
Description=Bareos Catalog Database (MariaDB)
Documentation=https://docs.bareos.org
After=network-online.target

[Container]
# Pin to a specific MariaDB version for reproducibility
Image=docker.io/library/mariadb:10.11

ContainerName=bareos-db
HostName=bareos-db

# Load credentials from environment file
EnvironmentFile=/home/bareos/.config/bareos/db.env

# Persistent storage for database files
Volume=bareos-db-data.volume:/var/lib/mysql:Z

# Connect to the Bareos internal network
Network=bareos.network

# Resource limits — MariaDB catalog uses moderate memory
Memory=1g

# Publish port only to localhost (not externally)
# Remove or change 127.0.0.1 if Director is on a different host
PublishPort=127.0.0.1:3306:3306

# Security hardening
NoNewPrivileges=true

# Health check — ensures MariaDB is ready before Director starts
HealthCmd=/usr/local/bin/healthcheck.sh --innodb_initialized
HealthInterval=10s
HealthTimeout=5s
HealthRetries=3
HealthStartPeriod=30s

# Labels for identification
Label=app=bareos
Label=component=catalog

[Service]
Restart=always
TimeoutStartSec=120
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF
```

### Why MariaDB 10.11?

MariaDB 10.11 is an LTS (Long Term Support) release with support until 2028. The Bareos catalog schema is tested against it, and it has excellent performance for the mixed read/write patterns of backup catalog operations.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Deploying the Bareos Storage Daemon Container

### Quadlet File for Storage Daemon

```bash
sudo -u bareos tee /home/bareos/.config/containers/systemd/bareos-storage.container > /dev/null <<'EOF'
# bareos-storage.container — Bareos Storage Daemon

[Unit]
Description=Bareos Storage Daemon
Documentation=https://docs.bareos.org
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-storage:24

ContainerName=bareos-storage
HostName=bareos-storage

# Bareos daemon passwords
EnvironmentFile=/home/bareos/.config/bareos/bareos.env

# Configuration from host (read-only in the container)
Volume=/etc/bareos/bareos-sd.d:/etc/bareos/bareos-sd.d:ro,Z

# Backup Volume storage — bind mount to dedicated disk
# :z (shared label) because the host also needs to access these files
Volume=/srv/bareos-storage/volumes:/var/lib/bareos/storage:z

# Working data (log files, state files)
Volume=bareos-working.volume:/var/lib/bareos:Z

# Connect to the Bareos internal network
Network=bareos.network

# Publish Storage Daemon port
PublishPort=9103:9103

# Resource limits
Memory=512m

# Security
NoNewPrivileges=true

# Labels
Label=app=bareos
Label=component=storage

[Service]
Restart=on-failure
TimeoutStartSec=60

[Install]
WantedBy=default.target
EOF
```

### Storage Daemon Configuration Files

Now create the actual Bareos configuration for the Storage Daemon:

```bash
# Storage Daemon identity
sudo -u bareos tee /etc/bareos/bareos-sd.d/storage/bareos-sd.conf > /dev/null <<'EOF'
Storage {
  Name = bareos-sd
  SDPort = 9103
  WorkingDirectory = /var/lib/bareos
  PidDirectory = /var/lib/bareos
  Maximum Concurrent Jobs = 20
  TLS Enable = No                 # We enable TLS in Chapter 15
}
EOF

# Authorize the Director to connect to this Storage Daemon
# The password must match the Director's Storage resource password
sudo -u bareos tee /etc/bareos/bareos-sd.d/director/bareos-dir.conf > /dev/null <<'EOF'
Director {
  Name = bareos-dir
  Password = "CHANGEME_SD_PASSWORD"   # Replace with your generated SD password
  Monitor = No
}
EOF

# Define the storage device (where to write Volumes)
sudo -u bareos tee /etc/bareos/bareos-sd.d/device/FileStorage.conf > /dev/null <<'EOF'
Device {
  Name = FileStorage
  Media Type = File
  Archive Device = /var/lib/bareos/storage
  LabelMedia = yes             # automatically label new volumes
  Random Access = Yes          # disk storage supports random access
  AutomaticMount = yes         # mount volumes automatically when needed
  RemovableMedia = no          # not removable (it's disk)
  AlwaysOpen = no              # don't keep the device open when idle

  # Maximum volume size: 10 GB
  # (larger volumes are harder to move/copy; multiple smaller volumes is better)
  Maximum Volume Size = 10 GB

  # Block size for data transfer
  # 512 KB is a good balance for disk-based storage
  Block Size = 512 KB
}
EOF

# Storage Daemon messages configuration
sudo -u bareos tee /etc/bareos/bareos-sd.d/messages/Daemon.conf > /dev/null <<'EOF'
Messages {
  Name = Daemon
  Syslog = all, !skipped, !saved, !audit
  Append = /var/log/bareos/bareos-sd.log = all, !skipped, !saved, !audit
}
EOF
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Deploying the Bareos Director Container

### Quadlet File for Director

```bash
sudo -u bareos tee /home/bareos/.config/containers/systemd/bareos-director.container > /dev/null <<'EOF'
# bareos-director.container — Bareos Director

[Unit]
Description=Bareos Director
Documentation=https://docs.bareos.org
After=network-online.target
# Wait for DB to be healthy before starting Director
After=bareos-db.service
After=bareos-storage.service
Requires=bareos-db.service
Requires=bareos-storage.service

[Container]
Image=docker.io/bareos/bareos-director:24

ContainerName=bareos-director
HostName=bareos-director

# Credentials from environment files
EnvironmentFile=/home/bareos/.config/bareos/bareos.env
EnvironmentFile=/home/bareos/.config/bareos/db.env

# Director configuration (read-only)
Volume=/etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z

# Working data: bootstrap files, state files
Volume=bareos-working.volume:/var/lib/bareos:Z

# Connect to the Bareos internal network
Network=bareos.network

# Expose Director port (for bconsole connections)
PublishPort=9101:9101

# The Director needs to resolve the SD and DB by container name
# (handled automatically by Quadlet network DNS)

# Resource limits
Memory=512m

# Security
NoNewPrivileges=true

# Labels
Label=app=bareos
Label=component=director

[Service]
Restart=on-failure
TimeoutStartSec=120

[Install]
WantedBy=default.target
EOF
```

### Director Configuration Files

These are the core Director configuration files. They reference passwords from environment variables set via `EnvironmentFile`.

**Director identity:**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/director/bareos-dir.conf > /dev/null <<'EOF'
Director {
  Name = bareos-dir
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  Maximum Concurrent Jobs = 10
  Password = "CHANGEME_DIRECTOR_PASSWORD"  # bconsole uses this
  Messages = Daemon
  Auditing = yes
}
EOF
```

**Catalog connection (connect to bareos-db container):**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf > /dev/null <<'EOF'
Catalog {
  Name = MyCatalog
  DBName = bareos
  DBUser = bareos
  DBPassword = "CHANGEME_BAREOS_DB_PASSWORD"  # matches db.env MARIADB_PASSWORD
  DBAddress = bareos-db     # container name, resolved by Quadlet network DNS
  DBPort = 3306
}
EOF
```

**Storage resource (connect to bareos-storage container):**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/storage/File.conf > /dev/null <<'EOF'
Storage {
  Name = File
  Address = bareos-storage   # container name, DNS-resolved within bareos.network
  SDPort = 9103
  Password = "CHANGEME_SD_PASSWORD"   # matches bareos-sd.d/director/bareos-dir.conf
  Device = FileStorage
  Media Type = File
  Maximum Concurrent Jobs = 10
}
EOF
```

**Messages configuration:**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/messages/Daemon.conf > /dev/null <<'EOF'
Messages {
  Name = Daemon
  Syslog = all, !skipped, !saved, !audit
  Append = /var/log/bareos/bareos-dir.log = all, !skipped, !saved, !audit
}

Messages {
  Name = Standard
  MailCommand = "/usr/lib/bareos/scripts/mail -h localhost -f bareos@localhost -s \"Bareos: %t %e of %c %l\" %r"
  OperatorCommand = "/usr/lib/bareos/scripts/mail -h localhost -f bareos@localhost -s \"Bareos: Intervention needed for %j\" %r"
  Mail = root@localhost = all, !skipped, !saved, !audit
  MailOnError = root@localhost = all
  Append = /var/log/bareos/bareos-dir.log = all, !skipped, !saved, !audit
  Console = all, !skipped, !saved, !audit
}
EOF
```

**Console access configuration:**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/console/admin-console.conf > /dev/null <<'EOF'
Console {
  Name = admin
  Password = "CHANGEME_DIRECTOR_PASSWORD"  # same as Director's Password
  Profile = operator
  TLS Enable = No
}
EOF
```

**Profile for operator access:**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/profile/operator.conf > /dev/null <<'EOF'
Profile {
  Name = operator
  Command ACL = !.bvfs_clear_cache, !.exit, !.sql, !configure, !create, !delete, !purge, !sqlquery, !umount, !unmount, *all*
  Catalog ACL = *all*
  Client ACL = *all*
  FileSet ACL = *all*
  Job ACL = *all*
  Plugin Options ACL = *all*
  Pool ACL = *all*
  Schedule ACL = *all*
  Storage ACL = *all*
  Where ACL = *all*
}
EOF
```

**Default Pool definitions (basic):**

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/pool/Full.conf > /dev/null <<'EOF'
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
EOF

sudo -u bareos tee /etc/bareos/bareos-dir.d/pool/Incremental.conf > /dev/null <<'EOF'
Pool {
  Name = Incremental
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 14 days
  Maximum Volume Bytes = 5 GB
  Maximum Volumes = 200
  Label Format = "Inc-"
}
EOF

sudo -u bareos tee /etc/bareos/bareos-dir.d/pool/Differential.conf > /dev/null <<'EOF'
Pool {
  Name = Differential
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 21 days
  Maximum Volume Bytes = 8 GB
  Maximum Volumes = 100
  Label Format = "Diff-"
}
EOF

# Scratch pool: a pool of unlabeled volumes that other pools can draw from
sudo -u bareos tee /etc/bareos/bareos-dir.d/pool/Scratch.conf > /dev/null <<'EOF'
Pool {
  Name = Scratch
  Pool Type = Scratch
}
EOF
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Installing the File Daemon on the Host

The File Daemon runs as an RPM service directly on the RHEL 10 host. It needs to access the host filesystem (including Podman volume paths) directly.

### Installing bareos-filedaemon

```bash
# Install the File Daemon package
sudo dnf install -y bareos-filedaemon

# The installation creates:
# /etc/bareos/bareos-fd.d/       ← configuration directory
# /usr/lib/systemd/system/bareos-fd.service  ← systemd unit
```

### File Daemon Configuration

**FD identity (client itself):**

```bash
sudo tee /etc/bareos/bareos-fd.d/client/myself.conf > /dev/null <<'EOF'
Client {
  Name = bareos-fd
  FDPort = 9102
  WorkingDirectory = /var/lib/bareos
  PidDirectory = /var/run/bareos
  Maximum Concurrent Jobs = 20
  TLS Enable = No
}
EOF
```

**Authorize the Director to connect:**

```bash
sudo tee /etc/bareos/bareos-fd.d/director/bareos-dir.conf > /dev/null <<'EOF'
Director {
  Name = bareos-dir
  Password = "CHANGEME_FD_PASSWORD"   # must match Director's Client resource password
  Monitor = No
}
EOF
```

**FD messages:**

```bash
sudo tee /etc/bareos/bareos-fd.d/messages/Daemon.conf > /dev/null <<'EOF'
Messages {
  Name = Daemon
  Syslog = all, !skipped, !saved, !audit
  Append = /var/log/bareos/bareos-fd.log = all, !skipped, !saved, !audit
}
EOF
```

### Register the Client in the Director

```bash
sudo -u bareos tee /etc/bareos/bareos-dir.d/client/bareos-fd.conf > /dev/null <<'EOF'
Client {
  Name = bareos-fd
  Address = 127.0.0.1     # FD is on the same host; connect via loopback
  FDPort = 9102
  Catalog = MyCatalog
  Password = "CHANGEME_FD_PASSWORD"   # must match FD's Director password
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes
}
EOF
```

### Enable and Start the File Daemon

```bash
# Fix SELinux context (the RPM should do this, but verify)
sudo restorecon -Rv /etc/bareos/bareos-fd.d

# Enable and start the file daemon
sudo systemctl enable --now bareos-fd

# Verify it's running
sudo systemctl status bareos-fd
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Initializing the Catalog Database

Before the Director starts for the first time, the MariaDB database must have the Bareos schema created.

```bash
# Step 1: Start only the database container first
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user daemon-reload

sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user start bareos-db.service

# Wait for MariaDB to be ready (watch health status)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash -c '
  until podman healthcheck run bareos-db 2>/dev/null | grep -q "healthy"; do
    echo "Waiting for MariaDB to be ready..."
    sleep 5
  done
  echo "MariaDB is ready!"
'
```

### Running the Bareos Schema Setup

The Bareos Director image includes scripts to initialize the database. We run them using a temporary Director container:

```bash
# Run the Bareos catalog creation script
# This connects to bareos-db and creates the bareos schema
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
  --network bareos.network \
  --env-file /home/bareos/.config/bareos/db.env \
  --env-file /home/bareos/.config/bareos/bareos.env \
  -v /etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z \
  docker.io/bareos/bareos-director:24 \
  /usr/lib/bareos/scripts/create_bareos_database

# Grant privileges
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
  --network bareos.network \
  --env-file /home/bareos/.config/bareos/db.env \
  -v /etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z \
  docker.io/bareos/bareos-director:24 \
  /usr/lib/bareos/scripts/grant_bareos_privileges
```

Expected output from `create_bareos_database`:
```
Creating MySQL database
Succeeded creating bareos database
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Starting All Services and Verifying

### Start All Bareos Services

```bash
# As root: export the bareos user's runtime dir for the following commands
# (or use: sudo machinectl shell bareos@)
BAREOS_UID=$(id -u bareos)
export XDG_RUNTIME_DIR=/run/user/${BAREOS_UID}

# Reload user systemd daemon to pick up all Quadlet files
sudo -u bareos XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} \
  systemctl --user daemon-reload

# Start all services (systemd will respect dependency ordering)
sudo -u bareos XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} \
  systemctl --user start bareos-db.service

# Wait for DB healthy
sleep 15

sudo -u bareos XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} \
  systemctl --user start bareos-storage.service

sleep 5

sudo -u bareos XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} \
  systemctl --user start bareos-director.service

# Enable all services to start at boot
sudo -u bareos XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} \
  systemctl --user enable bareos-db.service bareos-storage.service bareos-director.service
```

### Verifying Container Status

```bash
# Check all Bareos containers are running
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Expected output:
```
NAMES              STATUS                   PORTS
bareos-director    Up 2 minutes             0.0.0.0:9101->9101/tcp
bareos-storage     Up 3 minutes             0.0.0.0:9103->9103/tcp
bareos-db          Up 4 minutes (healthy)   127.0.0.1:3306->3306/tcp
```

### Checking Container Logs

```bash
# Director logs
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -n 50

# Storage Daemon logs
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-storage.service -n 50

# DB logs
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-db.service -n 50
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Connecting with bconsole

### Installing bconsole

```bash
# Install bconsole on the backup server
sudo dnf install -y bareos-bconsole
```

### bconsole Configuration

```bash
sudo tee /etc/bareos/bconsole.conf > /dev/null <<'EOF'
Director {
  Name = bareos-dir
  DIRport = 9101
  Address = 127.0.0.1
  Password = "CHANGEME_DIRECTOR_PASSWORD"  # matches Director's Password directive
  TLS Enable = No
}
EOF

sudo chown root:bareos /etc/bareos/bconsole.conf
sudo chmod 640 /etc/bareos/bconsole.conf
```

### First bconsole Connection

```bash
# Connect to the Director
bconsole

# Expected:
# Connecting to Director 127.0.0.1:9101
# 1000 OK: bareos-dir Version: 24.0.0
# *
```

### Verifying All Components

```
*status director

bareos-dir Version: 24.0.0
Daemon started, version 24.0.0
 Heap: heap=516,096 smbytes=192,717 max_bytes=220,101 bufs=143 max_bufs=145
 Sizeof: boffset_t=8 size_t=8 debug=0 trace=0 mode=0,0 bwlimit=0kB/s
 ...

*status storage=File

Storage Daemon bareos-sd is connected at bareos-storage:9103
...

*status client=bareos-fd

Connecting to Client bareos-fd at 127.0.0.1:9102
...
```

All three statuses should report successful connections.

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 6-1: Full Deployment Walkthrough

This lab consolidates all steps into a sequential deployment script. Use this when deploying on a fresh system.

```bash
#!/bin/bash
# lab-06-deploy-bareos.sh
# Full Bareos-in-Podman deployment script
# Run as root on a prepared RHEL 10 host (see Chapter 3)

set -euo pipefail

BAREOS_USER="bareos"
BAREOS_UID=$(id -u ${BAREOS_USER})
BAREOS_XDG="/run/user/${BAREOS_UID}"

bareos_run() {
  sudo -u "${BAREOS_USER}" XDG_RUNTIME_DIR="${BAREOS_XDG}" "$@"
}

echo "=== Deploying Bareos in Podman ==="

# Step 1: Pull images
echo "Pulling container images..."
bareos_run podman pull docker.io/bareos/bareos-director:24
bareos_run podman pull docker.io/bareos/bareos-storage:24
bareos_run podman pull docker.io/library/mariadb:10.11

# Step 2: Reload Quadlet units
echo "Loading Quadlet definitions..."
bareos_run systemctl --user daemon-reload

# Step 3: Start database
echo "Starting MariaDB catalog..."
bareos_run systemctl --user start bareos-db.service

echo "Waiting for MariaDB to become healthy (up to 60 seconds)..."
for i in $(seq 1 12); do
  if bareos_run podman healthcheck run bareos-db 2>/dev/null | grep -q "healthy"; then
    echo "MariaDB is healthy!"
    break
  fi
  echo "  Attempt $i/12 — waiting..."
  sleep 5
done

# Step 4: Initialize catalog schema
echo "Initializing Bareos catalog schema..."
bareos_run podman run --rm \
  --network bareos.network \
  --env-file /home/bareos/.config/bareos/db.env \
  --env-file /home/bareos/.config/bareos/bareos.env \
  -v /etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z \
  docker.io/bareos/bareos-director:24 \
  /usr/lib/bareos/scripts/create_bareos_database

bareos_run podman run --rm \
  --network bareos.network \
  --env-file /home/bareos/.config/bareos/db.env \
  -v /etc/bareos/bareos-dir.d:/etc/bareos/bareos-dir.d:ro,Z \
  docker.io/bareos/bareos-director:24 \
  /usr/lib/bareos/scripts/grant_bareos_privileges

# Step 5: Start Storage Daemon
echo "Starting Storage Daemon..."
bareos_run systemctl --user start bareos-storage.service
sleep 5

# Step 6: Start Director
echo "Starting Director..."
bareos_run systemctl --user start bareos-director.service
sleep 10

# Step 7: Enable all services
bareos_run systemctl --user enable bareos-db.service bareos-storage.service bareos-director.service

# Step 8: Verify
echo ""
echo "=== Verifying deployment ==="
bareos_run podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== Testing bconsole connection ==="
echo "status director" | bconsole | head -5

echo ""
echo "=== Deployment complete! ==="
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Lab 6-2: Verifying Inter-Container Connectivity

```bash
# Test 1: Director can reach the Storage Daemon
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director \
  nc -zv bareos-storage 9103
# Expected: Connection to bareos-storage 9103 port [tcp] succeeded!

# Test 2: Director can reach the Database
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director \
  nc -zv bareos-db 3306
# Expected: Connection to bareos-db 3306 port [tcp] succeeded!

# Test 3: Director can reach the File Daemon on the host
echo "status client" | bconsole | grep -E "FD|File Daemon|Connected|Version"

# Test 4: Storage Daemon can write to the volume path
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-storage \
  touch /var/lib/bareos/storage/.write-test && \
  echo "Storage write test: PASSED" || \
  echo "Storage write test: FAILED"

# Test 5: Catalog database connectivity from Director
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director \
  mysql -h bareos-db -u bareos -p"CHANGEME_BAREOS_DB_PASSWORD" \
  -e "SELECT COUNT(*) FROM Job;" bareos 2>/dev/null
# Expected: A numeric result (0 initially, before any jobs run)
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Summary

In this chapter you deployed the complete Bareos stack as rootless Podman containers:

- **Architecture**: Director + Storage Daemon + MariaDB in containers, File Daemon as a host RPM service. All containers on a dedicated Quadlet-managed bridge network.
- **Secrets management**: Passwords stored in mode-600 environment files, never in Quadlet unit files. All placeholder values must be replaced with generated random passwords.
- **MariaDB catalog**: Dedicated named volume for data persistence; health check ensures Director starts only when DB is ready.
- **Storage Daemon**: Bind-mounted to `/srv/bareos-storage/volumes` on the dedicated backup disk, using `:z` SELinux label for shared access.
- **Director**: Reads `/etc/bareos/bareos-dir.d/` as a read-only bind mount. Connects to SD and DB by container name (DNS-resolved within the Quadlet network).
- **File Daemon**: Installed via RPM, configured to authorize the containerized Director.
- **Catalog initialization**: Run `create_bareos_database` and `grant_bareos_privileges` scripts in a temporary Director container before the Director starts.
- **All services enabled**: `systemctl --user enable` ensures all containers start at boot via lingering.
- **bconsole**: Installed via RPM, connects to the Director on port 9101 for all operator interactions.

---

**Next Chapter:** [Chapter 7: Your First Backup Job](./07-first-backup-job.md)

---

[↑ Back to Table of Contents](#table-of-contents)
