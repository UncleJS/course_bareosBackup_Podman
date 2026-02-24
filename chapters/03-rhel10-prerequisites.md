# Chapter 3: RHEL 10 Prerequisites

## Table of Contents

- [1. System Requirements](#1-system-requirements)
  - [Hardware / VM Specifications](#hardware-vm-specifications)
  - [Why a Separate Backup Storage Disk?](#why-a-separate-backup-storage-disk)
  - [Software Prerequisites](#software-prerequisites)
- [2. RHEL 10 Subscription and Repository Setup](#2-rhel-10-subscription-and-repository-setup)
  - [Registering the System](#registering-the-system)
  - [Enabling Required Repositories](#enabling-required-repositories)
  - [Adding the Bareos Repository](#adding-the-bareos-repository)
  - [Updating the System](#updating-the-system)
- [3. Understanding SELinux on RHEL 10](#3-understanding-selinux-on-rhel-10)
  - [What SELinux Does](#what-selinux-does)
  - [SELinux Modes](#selinux-modes)
  - [SELinux and Podman on RHEL 10](#selinux-and-podman-on-rhel-10)
  - [Checking SELinux Denials](#checking-selinux-denials)
  - [SELinux Booleans for Bareos](#selinux-booleans-for-bareos)
- [4. Firewall Configuration with firewalld](#4-firewall-configuration-with-firewalld)
  - [Bareos Port Reference](#bareos-port-reference)
  - [Understanding firewalld Zones](#understanding-firewalld-zones)
  - [Why the File Daemon Port Matters on the Backup Server](#why-the-file-daemon-port-matters-on-the-backup-server)
  - [Creating a Custom Bareos Firewall Service](#creating-a-custom-bareos-firewall-service)
- [5. Creating a Dedicated Bareos System User](#5-creating-a-dedicated-bareos-system-user)
  - [Creating the User](#creating-the-user)
  - [Setting Up Subuid and Subgid Mappings](#setting-up-subuid-and-subgid-mappings)
  - [Why Subuid/Subgid Ranges Matter](#why-subuidsubgid-ranges-matter)
- [6. Enabling Lingering for Rootless Podman Services](#6-enabling-lingering-for-rootless-podman-services)
  - [Verifying the User's systemd Instance](#verifying-the-users-systemd-instance)
- [7. Storage Preparation](#7-storage-preparation)
  - [Identifying the Storage Disk](#identifying-the-storage-disk)
  - [Partitioning and Formatting](#partitioning-and-formatting)
  - [Creating the Mount Point and Mounting](#creating-the-mount-point-and-mounting)
  - [Setting Ownership and SELinux Context](#setting-ownership-and-selinux-context)
  - [Setting Up Podman Volume Root for the Bareos User](#setting-up-podman-volume-root-for-the-bareos-user)
- [8. Time Synchronization](#8-time-synchronization)
  - [Configuring chrony (RHEL 10 default NTP client)](#configuring-chrony-rhel-10-default-ntp-client)
  - [Configuring a Local NTP Server (for Air-Gapped Environments)](#configuring-a-local-ntp-server-for-air-gapped-environments)
- [9. Kernel and OS Tuning for Backup Workloads](#9-kernel-and-os-tuning-for-backup-workloads)
  - [File Descriptor Limits](#file-descriptor-limits)
  - [Virtual Memory Settings](#virtual-memory-settings)
  - [Disable Transparent Huge Pages (Optional but Recommended)](#disable-transparent-huge-pages-optional-but-recommended)
- [10. Installing Base Packages](#10-installing-base-packages)
  - [Verifying Rootless Podman Functionality](#verifying-rootless-podman-functionality)
- [11. Lab 3-1: Full Host Preparation Walkthrough](#11-lab-3-1-full-host-preparation-walkthrough)
- [12. Lab 3-2: Verifying the Environment](#12-lab-3-2-verifying-the-environment)
- [13. Summary](#13-summary)

## 1. System Requirements

Before installing anything, verify your host meets the minimum requirements for a Bareos backup server with Podman containers.

### Hardware / VM Specifications

| Resource | Minimum | Recommended | Notes |
|---|---|---|---|
| vCPUs | 2 | 4 | Concurrent backup jobs are CPU-bound during compression |
| RAM | 4 GB | 8 GB | MariaDB catalog + Director + Storage Daemon in containers |
| Root disk | 30 GB | 50 GB | OS + container images + Bareos binaries |
| Backup storage | 100 GB | 500 GB+ | Bareos Volumes; sized to your RPO × data size |
| Network | 100 Mbps | 1 Gbps | Backup throughput directly affects backup windows |

### Why a Separate Backup Storage Disk?

Do **not** store Bareos Volumes on the root disk. A runaway backup job that fills up `/` will crash all running services on the host. The dedicated backup storage disk is mounted separately:
- Prevents root disk exhaustion
- Allows independent growth and replacement
- Enables easy migration of Volumes to a larger disk later
- Can be formatted with a backup-optimized filesystem (XFS with appropriate block size)

### Software Prerequisites

| Requirement | Version | Purpose |
|---|---|---|
| RHEL | 10.x | Base OS |
| Podman | 5.x (bundled with RHEL 10) | Container runtime |
| systemd | 256+ (bundled) | Service manager and Quadlet |
| SELinux | enforcing | Mandatory access control |
| firewalld | active | Host firewall |
| chrony | active | Time synchronization |
| MariaDB client tools | 10.11+ | For catalog management |

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. RHEL 10 Subscription and Repository Setup

RHEL 10 requires an active subscription for package updates. For lab and development use, a free **Red Hat Developer** account provides a no-cost RHEL subscription.

### Registering the System

```bash
# Register with Red Hat Subscription Management
sudo subscription-manager register --username your@email.com --password yourpassword

# Automatically attach the best available subscription
sudo subscription-manager attach --auto

# Verify subscription status
sudo subscription-manager status
```

Expected output:
```
+-------------------------------------------+
   System Status Details
+-------------------------------------------+
Overall Status: Current
...
```

### Enabling Required Repositories

RHEL 10 uses **BaseOS** and **AppStream** repositories. Both must be enabled:

```bash
# Verify repositories are enabled
sudo subscription-manager repos --list-enabled | grep -E "BaseOS|AppStream"
```

If not enabled:
```bash
sudo subscription-manager repos \
  --enable=rhel-10-for-x86_64-baseos-rpms \
  --enable=rhel-10-for-x86_64-appstream-rpms
```

### Adding the Bareos Repository

Bareos provides an official RHEL repository. We will install Bareos 24 (current stable):

```bash
# Download the Bareos repository configuration for RHEL 10
sudo curl -fsSL \
  https://download.bareos.org/current/EL_10/repodata/bareos.repo \
  -o /etc/yum.repos.d/bareos.repo

# Verify the repo was added
sudo dnf repolist | grep bareos
```

> **Note:** Always use Bareos's official repository. Do not use EPEL or other third-party repositories for Bareos packages — version mismatches between Director, Storage Daemon, and File Daemon cause protocol incompatibilities.

### Updating the System

Before installing anything, bring the OS to the latest patch level:

```bash
sudo dnf update -y
sudo reboot
```

A reboot after a kernel update ensures you are running the latest kernel before configuring Podman (kernel features like user namespaces and cgroups v2 are kernel-dependent).

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Understanding SELinux on RHEL 10

SELinux is non-negotiable on RHEL 10. This section gives you the understanding you need to work *with* SELinux rather than fight it.

### What SELinux Does

Traditional Unix permissions (owner/group/mode) answer: *"Who is allowed to access this file?"*

SELinux adds a second question: *"Even if you have permission, is this type of process allowed to access this type of file in this way?"*

Every process runs with a **context** (label), and every file has a **context**. SELinux enforces a policy that defines which process contexts can access which file contexts with which operations.

Example:
```bash
# See the SELinux context of a process
ps -eZ | grep bareos
# Output: system_u:system_r:bareos_t:s0  ...

# See the SELinux context of a file
ls -Z /etc/bareos/bareos-dir.conf
# Output: system_u:object_r:bareos_etc_t:s0  ...
```

The `bareos_t` process context is only allowed to read files labeled `bareos_etc_t`. If a Bareos config file is accidentally created with the wrong label (e.g., `unlabeled_t`), Bareos will fail to read it even though POSIX permissions appear correct.

### SELinux Modes

```bash
# Check current mode
getenforce
# Possible outputs: Enforcing, Permissive, Disabled

# View detailed status
sestatus
```

| Mode | Behavior | Use in Production? |
|---|---|---|
| Enforcing | Policy violations are denied AND logged | Always |
| Permissive | Violations are logged but NOT denied | Only for debugging |
| Disabled | SELinux is turned off | Never |

```bash
# Temporarily switch to permissive (for debugging only — resets on reboot)
sudo setenforce 0

# Switch back to enforcing
sudo setenforce 1
```

**Never set `SELINUX=disabled` in `/etc/selinux/config`** on a production host. This disables SELinux permanently and removes a critical security layer.

### SELinux and Podman on RHEL 10

When Podman mounts a volume into a container, the files inside the container are accessed under the container's SELinux context (`container_t` by default). Host files that are labeled `user_home_t` or other non-container types will be denied.

The solution is volume mount options:
- `:z` — Relabels the volume to a shared container label (`container_file_t`). Multiple containers can access it.
- `:Z` — Relabels the volume to a private container label. Only one container can access it.

```bash
# Example: mount a host directory with correct SELinux relabeling
podman run -v /opt/bareos-data:/data:Z bareos/bareos-director
```

> **Warning:** Do not use `:z` or `:Z` on directories that other non-container processes need to access with their original labels. The relabeling is persistent.

### Checking SELinux Denials

When something fails mysteriously, check the SELinux audit log:

```bash
# View recent denials
sudo ausearch -m avc -ts recent

# View and explain denials with suggestions
sudo audit2why -a

# Generate a custom policy module to allow a denied operation
sudo audit2allow -a -M my-bareos-fix
sudo semodule -i my-bareos-fix.pp
```

We will use these tools throughout the course whenever SELinux is involved.

### SELinux Booleans for Bareos

Some SELinux behaviors can be toggled without writing custom policies:

```bash
# Allow network connections from bareos daemons
sudo setsebool -P bareos_use_network on

# List all bareos-related booleans
sudo getsebool -a | grep bareos
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Firewall Configuration with firewalld

RHEL 10 uses `firewalld` as its host firewall. Bareos daemons listen on specific TCP ports that must be opened.

### Bareos Port Reference

| Daemon | Default Port | Direction |
|---|---|---|
| Bareos Director | 9101/TCP | Clients connect to Director for console access |
| Bareos File Daemon | 9102/TCP | Director connects to File Daemons on clients |
| Bareos Storage Daemon | 9103/TCP | File Daemons connect to Storage Daemon |

### Understanding firewalld Zones

firewalld uses the concept of **zones** — named trust levels for network interfaces. The key zones are:

| Zone | Trust Level | Typical Use |
|---|---|---|
| `drop` | Lowest — all incoming dropped | Hostile networks |
| `block` | All incoming rejected (ICMP) | |
| `public` | Default — limited services allowed | Public internet interfaces |
| `internal` | Trusted internal network | LAN/data-center interfaces |
| `trusted` | All traffic allowed | Management interfaces |

For Bareos, we recommend assigning the server's primary network interface to the `internal` zone and opening Bareos ports there:

```bash
# Check current zone assignment for the active interface
sudo firewall-cmd --get-active-zones

# Assign interface to internal zone (replace ens3 with your interface name)
sudo firewall-cmd --permanent --zone=internal --add-interface=ens3

# Open Bareos Director port (for bconsole clients)
sudo firewall-cmd --permanent --zone=internal --add-port=9101/tcp

# Open Bareos Storage Daemon port (for File Daemons)
sudo firewall-cmd --permanent --zone=internal --add-port=9103/tcp

# Open Bareos File Daemon port (for the Director to connect back to this host)
sudo firewall-cmd --permanent --zone=internal --add-port=9102/tcp

# Reload to apply permanent rules
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --zone=internal --list-ports
```

### Why the File Daemon Port Matters on the Backup Server

Even if you run the Director and Storage Daemon on the same host (as we do in this course), the Director initiates connections *back to* the File Daemon running on that same host. The firewall must allow this loopback connection, or the Director will fail to connect with a cryptic timeout error.

```bash
# Allow loopback traffic (should be allowed by default, but verify)
sudo firewall-cmd --permanent --zone=trusted --add-interface=lo
sudo firewall-cmd --reload
```

### Creating a Custom Bareos Firewall Service

For reusability, define a named service:

```bash
# Create the service definition
sudo tee /etc/firewalld/services/bareos.xml > /dev/null <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Bareos</short>
  <description>Bareos Backup Archiving REcovery Open Sourced daemons</description>
  <port protocol="tcp" port="9101"/>
  <port protocol="tcp" port="9102"/>
  <port protocol="tcp" port="9103"/>
</service>
EOF

# Reload firewalld to recognize the new service
sudo firewall-cmd --reload

# Add the service to the internal zone
sudo firewall-cmd --permanent --zone=internal --add-service=bareos
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --zone=internal --list-services
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Creating a Dedicated Bareos System User

Running rootless Podman services under a dedicated system user provides:
- **Isolation**: The Bareos processes cannot affect other users' resources.
- **Auditability**: All Bareos activity in audit logs is attributed to one UID.
- **Security**: Compromise of a Bareos container grants only this user's privileges.

### Creating the User

```bash
# Create a system user 'bareos' with a home directory but no login shell
# UID 1001 is chosen for clarity; adjust for your environment
sudo useradd \
  --system \
  --uid 1001 \
  --create-home \
  --home-dir /home/bareos \
  --shell /sbin/nologin \
  --comment "Bareos Backup Service Account" \
  bareos

# Verify
id bareos
# Output: uid=1001(bareos) gid=1001(bareos) groups=1001(bareos)
```

### Setting Up Subuid and Subgid Mappings

Rootless Podman requires **subordinate UID/GID ranges** so that containers can have their own user namespace:

```bash
# Check if entries exist (they may be added automatically by useradd)
grep bareos /etc/subuid /etc/subgid

# If not present, add them manually
# Format: username:start-uid:count
# This grants UIDs 100000-165535 for the bareos user's containers
echo "bareos:100000:65536" | sudo tee -a /etc/subuid
echo "bareos:100000:65536" | sudo tee -a /etc/subgid

# Verify
grep bareos /etc/subuid /etc/subgid
```

### Why Subuid/Subgid Ranges Matter

When a rootless Podman container runs as `root` inside the container (UID 0), that maps to the `bareos` user's first subordinate UID (100000) on the host. A container running as UID 1000 inside maps to host UID 101000. This mapping means:

- Container processes cannot access files owned by other host users
- Container root cannot perform privileged operations on the host
- Different containers have different UID namespaces (security isolation)

This is explored in depth in Chapter 13.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Enabling Lingering for Rootless Podman Services

By default, a user's systemd session starts when they log in and stops when they log out. Since the `bareos` user never logs in (it has `/sbin/nologin`), its systemd session would never start — and neither would its Podman containers.

**Systemd lingering** solves this: it keeps the user's systemd session alive at boot, even without a login session.

```bash
# Enable lingering for the bareos user
sudo loginctl enable-linger bareos

# Verify
loginctl show-user bareos | grep Linger
# Output: Linger=yes

# Also verify the linger file exists
ls /var/lib/systemd/linger/bareos
```

Without this step, Bareos containers would not start at boot, and would stop when any SSH session as `bareos` closes.

### Verifying the User's systemd Instance

```bash
# Run a command as the bareos user using machinectl
sudo machinectl shell bareos@ /bin/bash -c "systemctl --user status"

# Or use su with XDG_RUNTIME_DIR set
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user status
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Storage Preparation

The backup storage disk must be properly formatted, mounted, and configured with the correct permissions and SELinux labels.

### Identifying the Storage Disk

```bash
# List all block devices
lsblk

# Example output:
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# sda      8:0    0   50G  0 disk
# └─sda1   8:1    0   50G  0 part /
# sdb      8:16   0  500G  0 disk        ← this is our backup storage disk
```

### Partitioning and Formatting

```bash
# Create a single partition spanning the entire disk
sudo parted /dev/sdb mklabel gpt
sudo parted /dev/sdb mkpart primary 0% 100%

# Format with XFS (recommended for Bareos on RHEL 10)
# XFS handles large files well and supports online resizing
sudo mkfs.xfs -L bareos-storage /dev/sdb1

# Verify
sudo blkid /dev/sdb1
```

**Why XFS for Bareos?**
- XFS handles large files (multi-GB backup Volumes) efficiently
- Excellent performance for sequential write workloads (which backup is)
- Supports online expansion if you add disk space later
- Mature, well-tested on RHEL
- `noatime` mount option dramatically improves performance on read-heavy catalogs

### Creating the Mount Point and Mounting

```bash
# Create the mount point
sudo mkdir -p /srv/bareos-storage

# Add to /etc/fstab for automatic mounting at boot
# Using UUID is more reliable than device names (which can change)
BACKUP_UUID=$(sudo blkid -s UUID -o value /dev/sdb1)

echo "UUID=${BACKUP_UUID}  /srv/bareos-storage  xfs  defaults,noatime  0  2" \
  | sudo tee -a /etc/fstab

# Mount it now without rebooting
sudo mount /srv/bareos-storage

# Verify
df -h /srv/bareos-storage
# Output: /dev/sdb1  500G  ... /srv/bareos-storage
```

### Setting Ownership and SELinux Context

```bash
# Create the directory structure
sudo mkdir -p /srv/bareos-storage/{volumes,archive}

# Give ownership to the bareos user
sudo chown -R bareos:bareos /srv/bareos-storage

# Set permissions: bareos user has full access, others have none
sudo chmod 750 /srv/bareos-storage
sudo chmod 750 /srv/bareos-storage/{volumes,archive}

# Set the correct SELinux context for Bareos storage
# bareos_store_t is the correct type for Bareos Volume storage
sudo semanage fcontext -a -t bareos_store_t "/srv/bareos-storage(/.*)?"
sudo restorecon -Rv /srv/bareos-storage

# Verify the context
ls -Z /srv/bareos-storage/
# Output: unconfined_u:object_r:bareos_store_t:s0 volumes
#         unconfined_u:object_r:bareos_store_t:s0 archive
```

### Setting Up Podman Volume Root for the Bareos User

The `bareos` user's Podman volumes and container storage need a defined location:

```bash
# Create the Podman storage directory for the bareos user
sudo mkdir -p /home/bareos/.local/share/containers
sudo chown -R bareos:bareos /home/bareos/.local

# Create the Quadlet units directory
sudo mkdir -p /home/bareos/.config/containers/systemd
sudo chown -R bareos:bareos /home/bareos/.config
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Time Synchronization

Bareos is extremely sensitive to clock skew. When the Director, Storage Daemon, and File Daemon clocks diverge by more than a few seconds:
- TLS certificate validation may fail
- Backup timestamp metadata becomes unreliable
- The Schedule may fire at unexpected times
- The catalog may record incorrect timestamps

**All hosts participating in a Bareos environment must have synchronized clocks.**

### Configuring chrony (RHEL 10 default NTP client)

```bash
# Check chrony status
sudo systemctl status chronyd

# View synchronization status
chronyc tracking

# View NTP sources being used
chronyc sources -v
```

### Configuring a Local NTP Server (for Air-Gapped Environments)

If your backup server has no internet access, configure it to use an internal NTP server:

```bash
sudo tee /etc/chrony.conf > /dev/null <<'EOF'
# Use your internal NTP server
server ntp.internal.company.com iburst prefer

# Allow synchronization if NTP server is unreachable (use local clock as fallback)
local stratum 10

# Set drift file location
driftfile /var/lib/chrony/drift

# Allow chrony to step the clock immediately on startup
makestep 1.0 3

# Log files
logdir /var/log/chrony
EOF

sudo systemctl restart chronyd
sudo systemctl enable chronyd

# Verify synchronization
chronyc tracking | grep "System time"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Kernel and OS Tuning for Backup Workloads

Default RHEL 10 settings are conservative. A few adjustments improve Bareos performance significantly.

### File Descriptor Limits

Bareos opens many file descriptors simultaneously during large backup jobs. The default system limit of 1024 is too low.

```bash
# Check current limits
ulimit -n

# Set permanent limits for the bareos user
sudo tee /etc/security/limits.d/bareos.conf > /dev/null <<'EOF'
# Bareos backup service limits
bareos soft nofile 65536
bareos hard nofile 65536
bareos soft nproc  4096
bareos hard nproc  4096
EOF

# For systemd services, set limits in the unit override (covered in Chapter 6)
```

### Virtual Memory Settings

```bash
# Reduce swappiness for the backup server
# (backups are sequential I/O — we don't want the kernel swapping working memory)
sudo tee /etc/sysctl.d/90-bareos.conf > /dev/null <<'EOF'
# Reduce swap usage for backup workloads
vm.swappiness = 10

# Increase dirty page ratio for better write buffering during large backups
vm.dirty_ratio = 30
vm.dirty_background_ratio = 10

# Increase max open files system-wide
fs.file-max = 500000

# Enable TCP window scaling for large file transfers
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF

sudo sysctl -p /etc/sysctl.d/90-bareos.conf
```

### Disable Transparent Huge Pages (Optional but Recommended)

THP can cause latency spikes during memory-intensive operations like database catalog operations:

```bash
sudo tee /etc/systemd/system/disable-thp.service > /dev/null <<'EOF'
[Unit]
Description=Disable Transparent Huge Pages
DefaultDependencies=false
After=sysinit.target local-fs.target
Before=basic.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=basic.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now disable-thp
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Installing Base Packages

Install the packages needed before Bareos itself:

```bash
# Update first
sudo dnf update -y

# Install essential tools
sudo dnf install -y \
  podman \
  podman-compose \
  container-selinux \
  slirp4netns \
  fuse-overlayfs \
  shadow-utils \
  policycoreutils-python-utils \
  setools-console \
  audit \
  firewalld \
  chrony \
  xfsprogs \
  lvm2 \
  vim \
  curl \
  wget \
  jq \
  openssl \
  nmap-ncat \
  tcpdump \
  bash-completion

# Enable and start essential services
sudo systemctl enable --now firewalld
sudo systemctl enable --now chronyd
sudo systemctl enable --now auditd

# Verify Podman installation
podman --version
# Expected: podman version 5.x.x
```

### Verifying Rootless Podman Functionality

```bash
# Test rootless Podman works for the bareos user
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm hello-world

# Expected: "Hello from Docker!" message (it's the same image, don't worry about the Docker branding)
```

If this fails with a namespace error:

```bash
# Ensure user namespaces are enabled
sudo sysctl -w user.max_user_namespaces=28633
echo "user.max_user_namespaces=28633" | sudo tee /etc/sysctl.d/99-user-namespaces.conf
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Lab 3-1: Full Host Preparation Walkthrough

This lab brings together all the steps above into a single ordered sequence. Run these commands on a fresh RHEL 10 system.

```bash
#!/bin/bash
# Lab 3-1: Bareos Host Preparation Script
# Run as a user with sudo privileges on a fresh RHEL 10 system

set -euo pipefail

echo "=== Step 1: Register RHEL subscription ==="
# Run interactively - replace with your credentials
# sudo subscription-manager register --username YOUR_EMAIL
# sudo subscription-manager attach --auto

echo "=== Step 2: Enable repositories and update ==="
sudo dnf update -y

echo "=== Step 3: Add Bareos repository ==="
sudo curl -fsSL \
  https://download.bareos.org/current/EL_10/repodata/bareos.repo \
  -o /etc/yum.repos.d/bareos.repo

echo "=== Step 4: Install base packages ==="
sudo dnf install -y \
  podman container-selinux slirp4netns fuse-overlayfs shadow-utils \
  policycoreutils-python-utils setools-console audit \
  firewalld chrony xfsprogs vim curl wget jq openssl nmap-ncat

echo "=== Step 5: Create bareos system user ==="
sudo useradd --system --uid 1001 --create-home \
  --home-dir /home/bareos \
  --shell /sbin/nologin \
  --comment "Bareos Backup Service Account" \
  bareos

echo "=== Step 6: Configure subuid/subgid ==="
grep -q bareos /etc/subuid || echo "bareos:100000:65536" | sudo tee -a /etc/subuid
grep -q bareos /etc/subgid || echo "bareos:100000:65536" | sudo tee -a /etc/subgid

echo "=== Step 7: Enable lingering ==="
sudo loginctl enable-linger bareos

echo "=== Step 8: Create directory structure ==="
sudo mkdir -p /home/bareos/.config/containers/systemd
sudo mkdir -p /home/bareos/.local/share/containers
sudo chown -R bareos:bareos /home/bareos

sudo mkdir -p /srv/bareos-storage/{volumes,archive}
sudo chown -R bareos:bareos /srv/bareos-storage
sudo chmod 750 /srv/bareos-storage /srv/bareos-storage/{volumes,archive}

echo "=== Step 9: SELinux context for storage ==="
sudo semanage fcontext -a -t bareos_store_t "/srv/bareos-storage(/.*)?"
sudo restorecon -Rv /srv/bareos-storage

echo "=== Step 10: Configure firewall ==="
sudo systemctl enable --now firewalld

sudo tee /etc/firewalld/services/bareos.xml > /dev/null <<'FWEOF'
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Bareos</short>
  <description>Bareos Backup daemons</description>
  <port protocol="tcp" port="9101"/>
  <port protocol="tcp" port="9102"/>
  <port protocol="tcp" port="9103"/>
</service>
FWEOF

sudo firewall-cmd --reload
sudo firewall-cmd --permanent --zone=internal --add-service=bareos
sudo firewall-cmd --reload

echo "=== Step 11: Kernel tuning ==="
sudo tee /etc/sysctl.d/90-bareos.conf > /dev/null <<'SYSCTL'
vm.swappiness = 10
vm.dirty_ratio = 30
vm.dirty_background_ratio = 10
fs.file-max = 500000
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
SYSCTL
sudo sysctl -p /etc/sysctl.d/90-bareos.conf

echo "=== Step 12: File descriptor limits ==="
sudo tee /etc/security/limits.d/bareos.conf > /dev/null <<'LIMITS'
bareos soft nofile 65536
bareos hard nofile 65536
bareos soft nproc  4096
bareos hard nproc  4096
LIMITS

echo "=== Step 13: Time synchronization ==="
sudo systemctl enable --now chronyd
chronyc tracking | grep -E "System time|Leap status"

echo ""
echo "=== Host preparation complete! ==="
echo "Next step: Run Lab 3-2 to verify the environment."
```

Save this as `/tmp/prepare-bareos-host.sh`, make it executable, and run it:

```bash
chmod +x /tmp/prepare-bareos-host.sh
sudo /tmp/prepare-bareos-host.sh
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 3-2: Verifying the Environment

After preparation, run these verification checks to confirm everything is correct before proceeding.

```bash
#!/bin/bash
# Lab 3-2: Environment Verification Checklist

PASS=0
FAIL=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "PASS" ]; then
    echo "  [PASS] $desc"
    ((PASS++))
  else
    echo "  [FAIL] $desc"
    ((FAIL++))
  fi
}

echo ""
echo "=== Bareos Host Environment Verification ==="
echo ""

# 1. RHEL 10
OS=$(grep -oP 'VERSION_ID="\K[^"]+' /etc/os-release)
[[ "$OS" == 10* ]] && check "RHEL 10 detected" PASS || check "RHEL 10 detected (found: $OS)" FAIL

# 2. SELinux enforcing
SEL=$(getenforce)
[[ "$SEL" == "Enforcing" ]] && check "SELinux is Enforcing" PASS || check "SELinux is Enforcing (is: $SEL)" FAIL

# 3. Firewalld active
systemctl is-active firewalld >/dev/null 2>&1 && check "firewalld is running" PASS || check "firewalld is running" FAIL

# 4. Bareos ports open
FW_OUT=$(sudo firewall-cmd --zone=internal --list-ports 2>/dev/null)
echo "$FW_OUT" | grep -q "9101/tcp" && check "Port 9101 open in firewall" PASS || check "Port 9101 open in firewall" FAIL
echo "$FW_OUT" | grep -q "9102/tcp" && check "Port 9102 open in firewall" PASS || check "Port 9102 open in firewall" FAIL
echo "$FW_OUT" | grep -q "9103/tcp" && check "Port 9103 open in firewall" PASS || check "Port 9103 open in firewall" FAIL

# 5. Bareos user exists
id bareos >/dev/null 2>&1 && check "bareos user exists" PASS || check "bareos user exists" FAIL

# 6. Subuid/subgid configured
grep -q bareos /etc/subuid && check "subuid configured for bareos" PASS || check "subuid configured for bareos" FAIL
grep -q bareos /etc/subgid && check "subgid configured for bareos" PASS || check "subgid configured for bareos" FAIL

# 7. Lingering enabled
loginctl show-user bareos 2>/dev/null | grep -q "Linger=yes" && check "Lingering enabled for bareos" PASS || check "Lingering enabled for bareos" FAIL

# 8. Storage mount exists
mountpoint -q /srv/bareos-storage && check "/srv/bareos-storage is mounted" PASS || check "/srv/bareos-storage is mounted" FAIL

# 9. Storage ownership
OWNER=$(stat -c '%U' /srv/bareos-storage 2>/dev/null)
[[ "$OWNER" == "bareos" ]] && check "bareos owns /srv/bareos-storage" PASS || check "bareos owns /srv/bareos-storage (owner: $OWNER)" FAIL

# 10. SELinux context on storage
FCTX=$(ls -Zd /srv/bareos-storage 2>/dev/null | awk '{print $1}')
echo "$FCTX" | grep -q "bareos_store_t" && check "SELinux context bareos_store_t on storage" PASS || check "SELinux context bareos_store_t on storage (got: $FCTX)" FAIL

# 11. Podman available
podman --version >/dev/null 2>&1 && check "Podman is installed" PASS || check "Podman is installed" FAIL

# 12. Rootless Podman for bareos user
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | \
  grep -q true && check "Rootless Podman works for bareos" PASS || check "Rootless Podman works for bareos" FAIL

# 13. chrony synchronized
chronyc tracking 2>/dev/null | grep -q "Leap status.*Normal" && check "chrony is synchronized" PASS || check "chrony is synchronized" FAIL

# 14. Bareos repo configured
dnf repolist 2>/dev/null | grep -q bareos && check "Bareos DNF repository configured" PASS || check "Bareos DNF repository configured" FAIL

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ $FAIL -eq 0 ]; then
  echo "All checks passed! Ready to proceed to Chapter 4."
else
  echo "Please fix the FAIL items before proceeding."
fi
```

Save as `/tmp/verify-bareos-host.sh`, run as root:
```bash
chmod +x /tmp/verify-bareos-host.sh
sudo /tmp/verify-bareos-host.sh
```

Expected output: `Results: 14 passed, 0 failed`

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Summary

In this chapter you prepared the RHEL 10 host for the Bareos deployment:

- **System requirements** assessed: CPU, RAM, root disk, dedicated backup storage disk, and network bandwidth.
- **Subscription and repositories** configured: RHEL 10 subscription, BaseOS/AppStream repos, and the official Bareos repository.
- **SELinux** understood: enforcing mode always, volume mount labels (`:z`/`:Z`), audit log reading with `ausearch` and `audit2allow`.
- **Firewall** configured: custom `bareos` service definition in firewalld with ports 9101, 9102, and 9103 open on the internal zone.
- **Dedicated `bareos` system user** created with subuid/subgid ranges and lingering enabled for rootless Podman.
- **Storage disk** formatted (XFS), mounted (`/srv/bareos-storage`), owned by `bareos`, and labeled `bareos_store_t` for SELinux.
- **Time synchronization** enforced via chrony — critical for all Bareos components.
- **Kernel tuning** applied: file descriptor limits, VM swappiness, network buffer sizes.
- **Verification script** confirms all 14 prerequisites are in place.

---

**Next Chapter:** [Chapter 4: Podman Primer for Sysadmins](./04-podman-primer.md)

---

[↑ Back to Table of Contents](#table-of-contents)
