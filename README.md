# Bareos Backup on RHEL 10 + Rootless Podman

**A Complete Hands-On Course**

---

## Table of Contents

1. [About This Course](#about-this-course)
2. [Prerequisites](#prerequisites)
3. [Lab Environment](#lab-environment)
4. [Course Chapter Index](#course-chapter-index)
5. [Chapter Summary Table](#chapter-summary-table)
6. [Quick Reference](#quick-reference)
7. [Key Concepts Glossary](#key-concepts-glossary)

---

## About This Course

This course teaches you how to deploy, configure, operate, and troubleshoot a production-grade [Bareos](https://www.bareos.com/) backup system on Red Hat Enterprise Linux 10 using rootless Podman containers managed by systemd user services (Quadlet).

Bareos (Backup Archiving REcovery Open Sourced) is an enterprise-class, open-source network backup solution derived from Bacula. It protects files, databases, and application data across multiple clients, stores backups on disk or tape, and provides a rich catalog for tracking every file ever backed up.

Running Bareos inside Podman containers — rather than as native RPM-installed daemons — gives you several advantages: clean version management, easy upgrades and rollbacks, isolation between the backup infrastructure and the host OS, and the ability to co-locate Bareos with the containerized applications it protects. Using rootless Podman adds a further security layer: the Bareos processes never run as root on the host.

### What This Course Covers

- The theoretical foundations of backup strategies (full, incremental, differential, retention)
- RHEL 10 system preparation: users, SELinux, firewall, storage, sub-UIDs
- Podman fundamentals as applied to backup infrastructure
- Bareos architecture: Director, Storage Daemon, File Daemon, Catalog
- Complete deployment of all Bareos components as Quadlet-managed containers
- Protecting files, Podman volumes, database containers, and container images
- TLS encryption between all Bareos daemons
- Advanced scheduling, pool management, and retention policies
- Monitoring, alerting, and disaster recovery
- Performance tuning for large environments
- Comprehensive troubleshooting with SELinux-aware diagnosis

### Who This Course Is For

This course is designed for Linux system administrators and DevOps engineers who:
- Are responsible for backup and recovery in environments running RHEL 8/9/10
- Are deploying or migrating to Podman-based container workloads
- Want to replace aging backup solutions (Amanda, rsync scripts, Bacula) with a modern, supportable platform
- Need to understand SELinux well enough to operate containers safely

No prior Bareos or Bacula experience is required. Familiarity with basic Linux administration (file permissions, systemd, firewall-cmd) is assumed.

---

## Prerequisites

### Knowledge Prerequisites

Before starting this course, you should be comfortable with the following:

| Topic | Expected Proficiency |
|---|---|
| Linux command line | Confident with files, permissions, pipes, redirection |
| systemd | Can start/stop/enable services, read journal output |
| Networking basics | TCP/IP, ports, firewall concepts |
| File systems | Mount points, disk usage, permissions |
| Text editors | Can use `vi` or `nano` to edit configuration files |
| Basic scripting | Can read and modify shell scripts |

You do **not** need prior experience with:
- Bareos or Bacula
- Podman or Docker
- SELinux policy management (the course teaches what you need)
- MariaDB/MySQL administration (covered where needed)

### Software Prerequisites

- A RHEL 10 (or CentOS Stream 10 / AlmaLinux 10 / Rocky Linux 10) installation, either physical hardware, a VM, or a cloud instance
- Internet access from the lab machine to pull container images from `docker.io`
- A user account with `sudo` privileges to perform initial system setup
- At least 20 GB of free disk space for backup storage and container images

### Recommended but Optional

- A second RHEL 10 machine to act as a backup client (you can use the same machine in a pinch, with the FD container representing a "remote" client)
- Access to a MariaDB client on your workstation for inspecting the catalog from outside the containers

---

## Lab Environment

### Hardware/VM Specifications

The following is the minimum recommended specification for the lab host. You can use a virtual machine in VirtualBox, VMware, KVM/QEMU, or any cloud provider.

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 vCPUs | 4 vCPUs |
| RAM | 4 GB | 8 GB |
| OS disk | 20 GB | 40 GB |
| Backup storage disk | 20 GB | 100 GB (separate partition or volume) |
| Network | 1 NIC with host-only or NAT | 2 NICs (one for management, one for backup traffic) |

### Operating System

```
RHEL 10 (or compatible)
SELinux: Enforcing
Firewalld: Active
```

Verify your environment:

```bash
# Check OS version
cat /etc/redhat-release

# Check SELinux status (must be Enforcing)
getenforce

# Check firewall status
firewall-cmd --state
```

### The bareos System User

All Bareos containers run under a dedicated system account named `bareos`. This user owns all containers, volumes, and configuration files. It never logs in interactively during normal operation but must have a loginctl linger session to keep its systemd user instance alive after logout.

```bash
# Create the bareos user (UID 1001)
sudo useradd -u 1001 -m -s /sbin/nologin -c "Bareos Backup Service" bareos

# Assign subordinate UID/GID ranges (required for rootless Podman user namespaces)
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 bareos

# Verify sub-UID assignment
grep bareos /etc/subuid /etc/subgid
# Expected:
#   /etc/subuid:bareos:100000:65536
#   /etc/subgid:bareos:100000:65536

# Enable linger so the systemd user session persists without an active login
sudo loginctl enable-linger bareos

# Verify linger is enabled
loginctl show-user bareos | grep Linger
# Expected: Linger=yes
```

### Backup Storage

The Bareos Storage Daemon writes backup volumes to `/srv/bareos-storage/volumes`. This path is bind-mounted into the SD container. It must have the correct SELinux context and sufficient disk space.

```bash
# Create the storage directory
sudo mkdir -p /srv/bareos-storage/volumes
sudo chown -R bareos:bareos /srv/bareos-storage
sudo chmod 750 /srv/bareos-storage

# Apply the correct SELinux context
sudo semanage fcontext -a -t container_file_t "/srv/bareos-storage(/.*)?"
sudo restorecon -Rv /srv/bareos-storage

# Verify the context
ls -laZ /srv/bareos-storage/
```

### Quadlet File Location

All Quadlet container unit files for the `bareos` user live at:

```
/home/bareos/.config/containers/systemd/
```

Named Podman volume data is stored at:

```
~/.local/share/containers/storage/volumes/<volume-name>/_data/
```

### Network Layout

```
┌─────────────────────────────────────────────────────────┐
│  RHEL 10 Host (lab machine)                             │
│                                                         │
│  ┌──────────────────────────────────────────────┐      │
│  │  bareos user namespace (rootless Podman)     │      │
│  │                                              │      │
│  │  ┌──────────────┐    ┌──────────────┐        │      │
│  │  │ bareos-dir   │    │  bareos-db   │        │      │
│  │  │ Director     │◄──►│  MariaDB     │        │      │
│  │  │ :9101        │    │  :3306       │        │      │
│  │  └──────┬───────┘    └──────────────┘        │      │
│  │         │                                    │      │
│  │  ┌──────▼───────┐    ┌──────────────┐        │      │
│  │  │ bareos-sd    │    │  bareos-fd   │        │      │
│  │  │ Storage      │    │  File Daemon │        │      │
│  │  │ :9103        │    │  :9102       │        │      │
│  │  └──────────────┘    └──────────────┘        │      │
│  └──────────────────────────────────────────────┘      │
│                                                         │
│  /srv/bareos-storage/volumes  (backup data)             │
│  /home/bareos/.config/bareos/ (secrets/env files)       │
└─────────────────────────────────────────────────────────┘
```

### Secrets and Credentials

Sensitive values (database passwords, Bareos daemon passwords) are stored in mode-600 environment files:

```
/home/bareos/.config/bareos/db.env      — MariaDB credentials
/home/bareos/.config/bareos/bareos.env  — Bareos daemon passwords
```

These files are passed to containers via `EnvironmentFile=` in Quadlet unit files. They must never be world-readable:

```bash
chmod 600 /home/bareos/.config/bareos/db.env
chmod 600 /home/bareos/.config/bareos/bareos.env
```

---

## Course Chapter Index

### Part 1: Foundations

| Chapter | Title | File |
|---|---|---|
| 1 | Introduction to Bareos and Backup Fundamentals | [chapters/01-introduction.md](chapters/01-introduction.md) |
| 2 | Core Backup Concepts | [chapters/02-backup-concepts.md](chapters/02-backup-concepts.md) |
| 3 | RHEL 10 Prerequisites and Setup | [chapters/03-rhel10-prerequisites.md](chapters/03-rhel10-prerequisites.md) |
| 4 | Podman Primer for Backup Engineers | [chapters/04-podman-primer.md](chapters/04-podman-primer.md) |
| 5 | Bareos Architecture Deep Dive | [chapters/05-bareos-architecture.md](chapters/05-bareos-architecture.md) |

### Part 2: Deployment

| Chapter | Title | File |
|---|---|---|
| 6 | Running Bareos in Podman Containers | [chapters/06-bareos-in-podman.md](chapters/06-bareos-in-podman.md) |
| 7 | Your First Backup Job | [chapters/07-first-backup-job.md](chapters/07-first-backup-job.md) |
| 8 | Restoring Files and Directories | [chapters/08-restore.md](chapters/08-restore.md) |

### Part 3: Advanced Backup Targets

| Chapter | Title | File |
|---|---|---|
| 9 | Backing Up Podman Volumes | [chapters/09-podman-volume-backups.md](chapters/09-podman-volume-backups.md) |
| 10 | Pre- and Post-Job Hooks | [chapters/10-podman-hooks.md](chapters/10-podman-hooks.md) |
| 11 | Backing Up Container Images | [chapters/11-podman-image-export.md](chapters/11-podman-image-export.md) |
| 12 | Quadlet and systemd Integration | [chapters/12-quadlet-systemd-integration.md](chapters/12-quadlet-systemd-integration.md) |
| 13 | Rootless Podman Security Model | [chapters/13-rootless-podman-specifics.md](chapters/13-rootless-podman-specifics.md) |
| 14 | Backing Up Database Containers | [chapters/14-database-containers.md](chapters/14-database-containers.md) |

### Part 4: Operations and Hardening

| Chapter | Title | File |
|---|---|---|
| 15 | TLS Encryption and Certificates | [chapters/15-tls-security.md](chapters/15-tls-security.md) |
| 16 | Advanced Schedules and Pools | [chapters/16-advanced-schedules-pools.md](chapters/16-advanced-schedules-pools.md) |
| 17 | Monitoring and Alerting | [chapters/17-monitoring-alerts.md](chapters/17-monitoring-alerts.md) |
| 18 | Disaster Recovery | [chapters/18-disaster-recovery.md](chapters/18-disaster-recovery.md) |
| 19 | Performance Tuning | [chapters/19-performance-tuning.md](chapters/19-performance-tuning.md) |
| 20 | Troubleshooting Guide | [chapters/20-troubleshooting.md](chapters/20-troubleshooting.md) |

---

## Chapter Summary Table

| # | Title | Key Topics | Difficulty |
|---|---|---|---|
| 1 | Introduction to Bareos and Backup Fundamentals | What Bareos is, history, components overview, why containerized deployment, course roadmap | Beginner |
| 2 | Core Backup Concepts | Full/incremental/differential backups, retention policies, RPO vs RTO, backup windows, deduplication, encryption at rest | Beginner |
| 3 | RHEL 10 Prerequisites and Setup | bareos user creation, sub-UIDs, SELinux contexts, firewalld rules, storage partitioning, NTP | Beginner |
| 4 | Podman Primer for Backup Engineers | Rootless vs rootful, namespaces, volumes, networks, pasta, `podman run`, `podman exec`, `podman logs` | Beginner |
| 5 | Bareos Architecture Deep Dive | Director, Storage Daemon, File Daemon, Catalog, Console; resource types; job lifecycle; data flow | Intermediate |
| 6 | Running Bareos in Podman Containers | Quadlet `.container` files, MariaDB setup, database initialization, env files, named volumes, service dependencies | Intermediate |
| 7 | Your First Backup Job | FileSet, Schedule, Pool, Job resources; running a Full backup; reading job logs; verifying in catalog | Beginner |
| 8 | Restoring Files and Directories | `restore` command in bconsole, restore wizard, `where` parameter, replace modes, restoring to alternate client | Beginner |
| 9 | Backing Up Podman Volumes | Volume export patterns, `podman volume export`, bind-mounting volumes into FD, catalog tracking, restore strategy | Intermediate |
| 10 | Pre- and Post-Job Hooks | `RunScript` directive, shell scripts in containers, stopping/starting application containers before backup, `ClientRunBeforeJob` | Intermediate |
| 11 | Backing Up Container Images | `podman save`, exporting to tar archives, FileSet targeting tar files, restoring images with `podman load` | Intermediate |
| 12 | Quadlet and systemd Integration | Quadlet generator, `.container` `.network` `.volume` files, `After=` / `Requires=`, `HealthCmd=`, drop-in overrides | Intermediate |
| 13 | Rootless Podman Security Model | User namespaces, UID mapping, sub-UID ranges, capabilities, seccomp, SELinux MCS labels, `--userns=keep-id` | Advanced |
| 14 | Backing Up Database Containers | MariaDB `mysqldump` in pre-job hooks, PostgreSQL `pg_dump`, MongoDB `mongodump`, verifying dump integrity | Advanced |
| 15 | TLS Encryption and Certificates | Bareos TLS architecture, generating a CA + daemon certificates with `openssl`, configuring TLS in Director/SD/FD, verifying TLS | Advanced |
| 16 | Advanced Schedules and Pools | Full/Differential/Incremental schedule design, pool definitions, volume retention, recycling, pool-per-client patterns | Advanced |
| 17 | Monitoring and Alerting | `mail` command in Job resources, Bareos WebUI setup, Prometheus exporter, Grafana dashboard, failure alerting | Intermediate |
| 18 | Disaster Recovery | Recovery scenarios (host failure, catalog loss, volume corruption), bootstrap files, bare-metal restore procedure, testing DR | Advanced |
| 19 | Performance Tuning | Parallel jobs, spooling configuration, catalog query optimization, network bandwidth tuning, compression settings | Advanced |
| 20 | Troubleshooting Guide | Job log analysis, daemon logs, SELinux AVC diagnosis, Quadlet failures, dbcheck, authorization errors, volume problems | All levels |

---

## Quick Reference

This section provides copy-paste commands for the most frequent operational tasks. All commands assume you are working as the `bareos` user with `XDG_RUNTIME_DIR=/run/user/1001` set, or that you have opened a shell with `machinectl shell bareos@`.

### Entering the bareos User Environment

```bash
# Option A: machinectl (full login environment, recommended)
machinectl shell bareos@

# Option B: sudo with correct XDG_RUNTIME_DIR
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash
```

### systemctl — Managing Bareos Services

```bash
# Check status of all Bareos services
systemctl --user status bareos-{dir,sd,fd,db}

# Start all services
systemctl --user start bareos-db bareos-dir bareos-sd bareos-fd

# Stop all services (reverse order)
systemctl --user stop bareos-fd bareos-sd bareos-dir bareos-db

# Restart a single service
systemctl --user restart bareos-dir

# Enable a service to start at boot (linger must be enabled)
systemctl --user enable bareos-dir

# Reload Quadlet after editing .container files
systemctl --user daemon-reload

# List all Bareos-related units
systemctl --user list-unit-files | grep bareos
```

### podman — Container Management

```bash
# List running containers
podman ps

# List all containers including stopped
podman ps --all

# View container logs
podman logs bareos-dir
podman logs -f bareos-dir          # Follow in real time

# Execute a command inside a container
podman exec bareos-dir bareos-dir -t   # Test Director config
podman exec -it bareos-dir bash        # Interactive shell

# Check published ports
podman port bareos-fd

# Inspect a named volume
podman volume inspect bareos-dir-config

# List all volumes
podman volume ls

# Check container networks
podman network ls
podman network inspect bareos-net

# Pull the latest Bareos images
podman pull docker.io/bareos/bareos-director:24
podman pull docker.io/bareos/bareos-storage:24
podman pull docker.io/bareos/bareos-client:24
podman pull docker.io/library/mariadb:10.11
```

### bconsole — Bareos Console Commands

```bash
# Open bconsole
podman exec -it bareos-dir bconsole
```

Inside bconsole:

```
# === Job Operations ===
*run job=BackupClient1 level=Full yes          # Run a Full backup immediately
*run job=BackupClient1 level=Incremental yes   # Run Incremental
*cancel jobid=42                               # Cancel a running job
*wait jobid=42                                 # Wait for a job to complete

# === Status ===
*status director                               # Director internal state
*status storage                                # Storage Daemon state
*status client                                 # File Daemon state
*status all                                    # All daemons

# === Catalog Queries ===
*list jobs last=10                             # Last 10 jobs
*list jobs jobstatus=E                         # Failed jobs
*list jobs jobstatus=R                         # Running jobs
*list joblog jobid=42                          # Full log for job 42
*list volumes                                  # All backup volumes
*list volumes pool=Full                        # Volumes in Full pool
*list clients                                  # All clients
*list files jobid=42                           # Files in a job

# === Configuration ===
*show job=BackupClient1                        # Show job config
*show client=bareos-fd                         # Show client config
*show storage=FileStorage                      # Show storage config
*show fileset=LinuxAll                         # Show fileset config

# === Volume Management ===
*label storage=FileStorage volume=Vol-0001 pool=Full  # Label new volume
*relabel storage=FileStorage oldvolume=V1 volume=V1   # Relabel existing
*truncate storage=FileStorage volume=Vol-0001          # Truncate volume
*update volume=Vol-0001 volstatus=Purged               # Update volume status
*mount storage=FileStorage                             # Mount storage
*unmount storage=FileStorage                           # Unmount storage

# === Restore ===
*restore                                       # Interactive restore wizard
*estimate job=BackupClient1 level=Full listing # Dry-run estimate

# === Maintenance ===
*messages                                      # Show pending messages
*prune jobs client=bareos-fd yes               # Prune old job records
*purge jobs client=bareos-fd yes               # Purge (delete) job records
*quit                                          # Exit bconsole
```

### journalctl — Reading Logs

```bash
# Real-time Director log
journalctl --user -u bareos-dir -f

# Last 100 lines of Storage Daemon log
journalctl --user -u bareos-sd -n 100 --no-pager

# All Bareos daemons since a timestamp
journalctl --user -u 'bareos-*' --since "2026-02-24 08:00"

# Show logs for a specific boot
journalctl --user -u bareos-dir -b 0          # Current boot
journalctl --user -u bareos-dir -b -1         # Previous boot
```

### SELinux Diagnostics

```bash
# Check SELinux status
getenforce
sestatus

# Find recent AVC denials (run as root)
ausearch -m avc -ts recent

# Get human-readable explanation
ausearch -m avc -ts recent | audit2why

# Generate and install a policy module
ausearch -m avc -ts recent | audit2allow -M bareos_local
semodule -i bareos_local.pp

# Fix file context
restorecon -Rv /srv/bareos-storage/volumes/
semanage fcontext -a -t container_file_t "/srv/bareos-storage(/.*)?"
restorecon -Rv /srv/bareos-storage/
```

---

## Key Concepts Glossary

### Bareos-Specific Terms

**Bareos Director (DIR)**  
The central controlling daemon of a Bareos installation. The Director orchestrates all backup and restore jobs: it reads the configuration, connects to clients (File Daemons), instructs the Storage Daemon where to write data, and updates the catalog. There is exactly one Director per Bareos installation.

**Storage Daemon (SD)**  
The Bareos daemon responsible for writing backup data to storage media (disk files, tape). It receives data from the File Daemon (via the Director's coordination) and writes it to volumes. It also reads volumes during restore operations.

**File Daemon (FD)**  
Also called the "client". The File Daemon runs on the machine being backed up. It reads the files specified in the FileSet, optionally compresses and encrypts them, and sends the data to the Storage Daemon. Every machine that Bareos protects must run a File Daemon.

**Catalog**  
The relational database (MariaDB in this course) that stores metadata about every job, every file, every volume, and every restore. The catalog is what makes Bareos's powerful restore capabilities possible — you can browse the catalog to find any version of any file ever backed up. The catalog does not store the actual file data; it stores only metadata.

**Job**  
A single backup or restore operation. A Job resource in the Director configuration ties together a Client, a FileSet, a Schedule, a Pool, and a Storage resource. When a job runs, Bareos creates a JobId in the catalog and logs all activity against it.

**FileSet**  
A configuration resource that defines what files to include in or exclude from a backup. A FileSet contains one or more `Include` blocks (paths to back up) and optional `Exclude` blocks (paths to skip). FileSet options control compression, checksumming, and file attribute handling.

**Pool**  
A collection of backup volumes that share the same retention policy, volume naming pattern, and media type. Common pools are `Full` (for Full backups, longer retention), `Incremental`, and `Scratch` (unlabeled volumes waiting to be used).

**Volume**  
A single storage unit — a file on disk or a physical tape — to which Bareos writes backup data. Every volume begins with a Bareos software label containing the volume name and pool. A single volume can contain data from multiple jobs.

**Schedule**  
A configuration resource that defines when jobs run. A schedule contains `Run` directives that specify time, day, backup level (Full, Incremental, Differential), and pool.

**Bootstrap File**  
A plain-text file generated by Bareos that contains the exact list of volumes and byte ranges needed to restore a specific set of data. The bootstrap file is the key artifact for disaster recovery — you need it (and the volumes it references) to restore without a catalog.

**bconsole**  
The Bareos command-line console. It connects to the Director over a TCP connection (authenticated with a password) and provides an interactive shell for running jobs, querying the catalog, managing volumes, and diagnosing problems.

**Full Backup**  
A backup that copies all files in the FileSet regardless of whether they have changed since the last backup. The baseline for all subsequent Incremental and Differential backups.

**Incremental Backup**  
A backup that copies only files that have changed since the last backup of any level (Full, Differential, or Incremental). The fastest and smallest backup type, but requires all previous Incrementals plus the last Full to perform a complete restore.

**Differential Backup**  
A backup that copies all files that have changed since the last Full backup. Larger than Incremental but simpler to restore from (only the last Full plus the last Differential are needed).

**Retention Period**  
The length of time Bareos keeps job records and volume data before they are eligible to be pruned (removed from the catalog) and recycled (volumes overwritten).

### Podman and Container Terms

**Rootless Podman**  
Running Podman containers as a non-root user. Container processes are mapped to sub-UIDs in the user's namespace on the host. Rootless containers cannot bind privileged ports (below 1024) and have a more restricted set of capabilities, which makes them more secure.

**Quadlet**  
A systemd integration layer for Podman, introduced in Podman 4.4. Quadlet reads `.container`, `.network`, and `.volume` files from standard systemd generator directories and translates them into systemd unit files at `daemon-reload` time. This is the preferred way to manage persistent Podman containers as system services.

**Named Volume**  
A Podman-managed storage volume identified by a name (e.g., `bareos-dir-config`). Podman stores named volume data at `~/.local/share/containers/storage/volumes/<name>/_data/` for rootless containers. Named volumes survive container removal and are the correct way to persist configuration and data.

**sub-UID / sub-GID**  
Ranges of host UIDs and GIDs assigned to a regular user, used by rootless Podman to create user namespaces. A container running as UID 0 inside the namespace appears as the owning user (UID 1001 for `bareos`) on the host. Configured in `/etc/subuid` and `/etc/subgid`.

**pasta**  
The default network backend for rootless Podman on RHEL 10 (replaced slirp4netns). `pasta` provides each rootless container with access to the host's network stack, port forwarding, and DNS resolution via a lightweight userspace network stack.

**linger**  
A systemd feature controlled by `loginctl enable-linger <user>`. When linger is enabled for a user, their systemd user instance starts at boot and remains running even when no interactive session is open. Required for Bareos containers to start automatically and run continuously.

**XDG_RUNTIME_DIR**  
An environment variable pointing to the user's runtime directory, typically `/run/user/<UID>`. Podman and systemd --user use this directory for their Unix domain sockets. Must be set explicitly when running commands via `sudo` or in non-login shells.

### SELinux Terms

**SELinux Context (Label)**  
A metadata tag attached to every file, process, and network port, consisting of `user:role:type:level`. The `type` component (e.g., `container_file_t`, `bareos_store_t`) is what most SELinux policy rules act on.

**AVC Denial**  
An Access Vector Cache denial — SELinux's record of a blocked operation. Logged to the audit log at `/var/log/audit/audit.log`. Use `ausearch -m avc` to find them and `audit2why` to interpret them.

**restorecon**  
A command that resets the SELinux context of a file or directory to the context specified by the active policy's file context database. Use `restorecon -Rv <path>` after changing file contexts with `semanage fcontext`.

**semanage fcontext**  
A command for managing the SELinux file context database — the persistent mapping of file paths to SELinux types. Add an entry with `semanage fcontext -a -t <type> <path_regex>`, then apply it with `restorecon`.

**audit2allow**  
A tool that reads AVC denial messages and generates a SELinux Type Enforcement (TE) policy module that would allow the denied operations. Use it when `restorecon` cannot solve the problem (i.e., when no suitable existing type exists for the file).

**Enforcing Mode**  
SELinux's active mode: all policy violations are blocked and logged. The correct production mode. Never change to Permissive or Disabled to work around a problem.

---

## Recommended Learning Path

If you are completely new to Bareos and Podman, follow the chapters in order. The course is designed so that each chapter builds on the previous one.

If you have experience with Bareos but are new to Podman and rootless containers, you may skim Chapters 1–2 and focus on Chapters 3–6, 12, and 13.

If you have experience with Podman but are new to Bareos, read Chapters 1–2 carefully for the concepts, then Chapters 5–8 for the configuration model, then continue in order.

If you are looking for help with a specific problem, go directly to [Chapter 20: Troubleshooting Guide](chapters/20-troubleshooting.md).

---

## Container Image Reference

All container images used in this course:

| Component | Image | Version Tag |
|---|---|---|
| Bareos Director | `docker.io/bareos/bareos-director` | `24` |
| Bareos Storage Daemon | `docker.io/bareos/bareos-storage` | `24` |
| Bareos File Daemon (client) | `docker.io/bareos/bareos-client` | `24` |
| MariaDB (Catalog) | `docker.io/library/mariadb` | `10.11` |

Pull all images before starting Chapter 6:

```bash
# As the bareos user
podman pull docker.io/bareos/bareos-director:24
podman pull docker.io/bareos/bareos-storage:24
podman pull docker.io/bareos/bareos-client:24
podman pull docker.io/library/mariadb:10.11
```

---

[Back to Table of Contents](#table-of-contents)
