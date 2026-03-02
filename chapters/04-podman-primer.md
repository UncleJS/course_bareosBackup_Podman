# Chapter 4: Podman Primer for Sysadmins
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. What is Podman and How Does it Differ from Docker?](#1-what-is-podman-and-how-does-it-differ-from-docker)
  - [The Docker Architecture Problem](#the-docker-architecture-problem)
  - [The Podman Architecture](#the-podman-architecture)
  - [OCI Compliance](#oci-compliance)
  - [Command Compatibility](#command-compatibility)
- [2. Container Concepts Every Sysadmin Must Know](#2-container-concepts-every-sysadmin-must-know)
  - [Images vs. Containers](#images-vs-containers)
  - [Image Layers](#image-layers)
  - [Container Isolation](#container-isolation)
- [3. Rootless Containers: Security by Architecture](#3-rootless-containers-security-by-architecture)
  - [How Rootless Containers Work](#how-rootless-containers-work)
  - [The Practical Impact](#the-practical-impact)
  - [What Rootless Containers Cannot Do](#what-rootless-containers-cannot-do)
  - [Storage for Rootless Podman](#storage-for-rootless-podman)
- [4. Podman Networking Deep Dive](#4-podman-networking-deep-dive)
  - [Default Network: pasta (RHEL 10 / Podman 5)](#default-network-pasta-rhel-10-podman-5)
  - [Named Networks for Inter-Container Communication](#named-networks-for-inter-container-communication)
  - [Pod Networking](#pod-networking)
  - [Host Network Mode](#host-network-mode)
- [5. Volumes and Persistent Storage](#5-volumes-and-persistent-storage)
  - [The Three Volume Types](#the-three-volume-types)
  - [Volume Ownership and UID Mapping](#volume-ownership-and-uid-mapping)
- [6. Podman and SELinux: Working Together](#6-podman-and-selinux-working-together)
  - [Container Default Labels](#container-default-labels)
  - [Volume Label Options](#volume-label-options)
  - [Named Volumes and SELinux](#named-volumes-and-selinux)
- [7. Quadlet: Systemd-Native Container Management](#7-quadlet-systemd-native-container-management)
  - [What is Quadlet?](#what-is-quadlet)
  - [File Locations](#file-locations)
  - [Anatomy of a `.container` File](#anatomy-of-a-container-file)
  - [Available Quadlet Directives](#available-quadlet-directives)
  - [`.volume` and `.network` Files](#volume-and-network-files)
- [8. Podman Pods: Grouping Related Containers](#8-podman-pods-grouping-related-containers)
  - [Pod Quadlet File](#pod-quadlet-file)
- [9. Container Registries and Image Management](#9-container-registries-and-image-management)
  - [Configuring Registries](#configuring-registries)
  - [Pulling the Bareos Images](#pulling-the-bareos-images)
  - [Pinning Image Versions](#pinning-image-versions)
  - [Updating Container Images](#updating-container-images)
- [10. Lab 4-1: Running Your First Rootless Container](#10-lab-4-1-running-your-first-rootless-container)
- [11. Lab 4-2: Creating a Quadlet Service](#11-lab-4-2-creating-a-quadlet-service)
- [12. Lab 4-3: Persistent Volume Demonstration](#12-lab-4-3-persistent-volume-demonstration)
- [13. Summary](#13-summary)

## 1. What is Podman and How Does it Differ from Docker?

**Podman** (Pod Manager) is a daemonless, open-source container engine developed by Red Hat. On RHEL 10, it is the default (and only) supported container runtime. Docker is not available and is not supported on RHEL 10.

### The Docker Architecture Problem

Docker uses a client-server architecture with a persistent daemon (`dockerd`) running as root:

```
┌─────────────────────────────────────────────────────┐
│                    Docker Architecture               │
│                                                     │
│  docker CLI  ──── UNIX socket ──►  dockerd (root)   │
│                                         │           │
│                                    containers       │
│                                  (all run as root   │
│                                   on the host)      │
└─────────────────────────────────────────────────────┘
```

Problems with this design:
1. `dockerd` runs as root. If it is compromised, the attacker has root on the host.
2. Anyone in the `docker` group has effective root access (via `docker run -v /:/host`).
3. All Docker commands require this root daemon to be running.
4. A daemon crash takes all containers down.

### The Podman Architecture

Podman is daemonless:

```
┌─────────────────────────────────────────────────────┐
│                    Podman Architecture               │
│                                                     │
│  podman CLI  ──── fork/exec ──►  container process  │
│  (user X)                        (runs as user X,   │
│                                   or mapped UID)     │
│                                                     │
│  podman CLI  ──── fork/exec ──►  container process  │
│  (user Y)                        (runs as user Y,   │
│                                   or mapped UID)     │
└─────────────────────────────────────────────────────┘
```

Each `podman` command directly forks and execs the container. No daemon is involved. This means:
- No single point of failure
- Containers run as the invoking user (rootless)
- No privileged daemon listening on a socket
- Container isolation is handled by Linux namespaces and cgroups, not a privileged intermediary

### OCI Compliance

Both Docker and Podman are OCI (Open Container Initiative) compliant. This means:
- Container images built with Docker run on Podman (and vice versa)
- Podman uses `docker.io` images, `quay.io` images, and any OCI-compliant registry
- Most `docker run` commands work as-is with `podman run` (just replace `docker` with `podman`)

### Command Compatibility

For users coming from Docker:

| Docker Command | Podman Equivalent |
|---|---|
| `docker run` | `podman run` |
| `docker build` | `podman build` |
| `docker pull` | `podman pull` |
| `docker ps` | `podman ps` |
| `docker exec` | `podman exec` |
| `docker logs` | `podman logs` |
| `docker volume` | `podman volume` |
| `docker network` | `podman network` |
| `docker-compose` | `podman-compose` or Quadlet (preferred) |

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Container Concepts Every Sysadmin Must Know

### Images vs. Containers

A **container image** is a read-only, layered filesystem containing an application and all its dependencies. Think of it as a template.

A **container** is a running instance of an image. Multiple containers can run from the same image simultaneously, and changes made inside a container do not affect the image.

```bash
# Pull an image from a registry
podman pull docker.io/library/alpine:3.19

# Run a container from that image
podman run --name my-alpine alpine:3.19 echo "Hello from container"

# Run it interactively
podman run -it --name my-shell alpine:3.19 /bin/sh

# List running containers
podman ps

# List all containers (including stopped)
podman ps -a

# Remove a container
podman rm my-alpine
```

### Image Layers

Container images are composed of **layers**. Each instruction in a `Dockerfile` (or `Containerfile`) creates a new layer:

```
┌──────────────────────────┐
│  Layer 4: App code       │  ← top (writable by container)
├──────────────────────────┤
│  Layer 3: App config     │
├──────────────────────────┤
│  Layer 2: Python runtime │
├──────────────────────────┤
│  Layer 1: Base OS (RHEL) │  ← bottom (read-only)
└──────────────────────────┘
```

When a container writes to a file in a read-only layer, Podman uses **copy-on-write (CoW)**: the file is copied to the container's writable layer before modification. This keeps the underlying image intact.

Layers are cached locally. If you pull five images that all share the same `ubi9` base layer, that layer is downloaded only once.

### Container Isolation

Containers are isolated using Linux kernel features:

| Mechanism | What it Isolates |
|---|---|
| **Namespaces** | PID, network, mount, UTS (hostname), IPC, user, cgroup |
| **Cgroups v2** | CPU, memory, I/O limits per container |
| **Seccomp** | Restricts which system calls the container can make |
| **Capabilities** | Fine-grained POSIX capabilities (drop root's dangerous capabilities) |
| **SELinux** | File and process access control beyond POSIX permissions |

This is *not* a VM — the container shares the host kernel. Containers provide process isolation, not hardware virtualization. A container with a crafted kernel exploit can potentially escape to the host. Defense in depth (rootless, SELinux, seccomp, read-only images) mitigates this risk.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Rootless Containers: Security by Architecture

Rootless Podman is the default and correct way to run containers on RHEL 10. Understanding it deeply is essential for Bareos deployment.

### How Rootless Containers Work

When a non-root user runs `podman run`, the process uses **user namespaces** to create an isolated user ID space:

```
Outside container (host view):    Inside container (container view):
  bareos (UID 1001)                    root (UID 0)
  subordinate UID 100000               UID 1 (maps to 100001 on host)
  subordinate UID 100001               UID 2 (maps to 100002 on host)
  ...                                  ...
  subordinate UID 165535               UID 65535 (maps to 165535 on host)
```

The container sees itself as having a full range of UIDs (0–65535). The host sees all of those mapped to the `bareos` user's subordinate UID range (100000–165535). At no point does any container process run as a real privileged UID on the host.

### The Practical Impact

```bash
# Inside the container: appears to be running as root
podman run --rm alpine id
# Output: uid=0(root) gid=0(root) groups=0(root),65533(nobody),65534(nogroup)

# But on the host, the container process is a non-root UID
# (view from another terminal while container runs)
ps -eZ | grep "podman\|conmon"
# The process context shows: user_u:user_r:container_t:...
# UID shown as: 100000 (the first subordinate UID)
```

### What Rootless Containers Cannot Do

- Cannot bind to privileged ports (< 1024) — Bareos uses ports 9101-9103, which are fine
- Cannot write to files owned by other host users
- Cannot load kernel modules
- Cannot access raw network sockets (for most purposes)
- Cannot modify the host network interface configuration

All of these are either irrelevant for Bareos or are desirable security restrictions.

### Storage for Rootless Podman

Each user gets their own isolated container storage under `~/.local/share/containers/`:

```
/home/bareos/.local/share/containers/
├── storage/
│   ├── overlay/          ← container image layers (overlay filesystem)
│   ├── overlay-images/   ← image manifests and metadata
│   ├── overlay-containers/ ← running/stopped container state
│   └── volumes/          ← named volumes
```

```bash
# As bareos user: inspect storage configuration
podman info --format '{{.Store.GraphRoot}}'
# Output: /home/bareos/.local/share/containers/storage
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Podman Networking Deep Dive

Networking in rootless Podman differs from traditional Docker, and understanding it is critical for Bareos inter-container communication.

### Default Network: pasta (RHEL 10 / Podman 5)

Podman 5.x on RHEL 10 uses **pasta** (not slirp4netns) as the default rootless network mode. Pasta is a high-performance userspace network implementation that:

- Provides IP connectivity between containers and the host
- Allows containers to reach the internet via NAT
- Allows the host to reach containers via port forwarding

```bash
# Run a container with a port exposed (host port 8080 → container port 80)
podman run -d -p 8080:80 --name web nginx

# The container is reachable on the host at localhost:8080
curl http://localhost:8080
```

### Named Networks for Inter-Container Communication

For Bareos, the Director, Storage Daemon, and Catalog database containers must communicate with each other. The correct approach is a **named Podman network**:

```bash
# Create a named network for the Bareos stack
podman network create bareos-net

# Containers on the same named network can reach each other by container name
podman run -d --network bareos-net --name bareos-db mariadb:10.11
podman run -d --network bareos-net --name bareos-dir \
  -e DB_HOST=bareos-db \     # resolve container name
  bareos/bareos-director

# Verify network
podman network inspect bareos-net
```

When containers are on the same named network, Podman provides automatic DNS resolution: a container named `bareos-db` is reachable at hostname `bareos-db` from other containers on the same network.

### Pod Networking

A **Podman Pod** groups multiple containers that share a network namespace. This is similar to a Kubernetes Pod:

```bash
# Create a pod (all containers share localhost)
podman pod create --name bareos-pod -p 9101:9101 -p 9103:9103

# Add containers to the pod
podman run -d --pod bareos-pod --name bareos-db mariadb:10.11
podman run -d --pod bareos-pod --name bareos-dir bareos/bareos-director

# Inside the pod, bareos-dir reaches bareos-db at 127.0.0.1:3306
```

We use Pods for the Bareos stack in [Chapter 6](./06-bareos-in-podman.md).

### Host Network Mode

For maximum performance (no NAT overhead), containers can use the host's network directly:

```bash
podman run --network host bareos/bareos-director
```

In host network mode, the container shares the host's network namespace entirely. The container's port 9101 *is* the host's port 9101. This is the highest-performance option but reduces isolation.

> **For Bareos**: We use named networks for isolation and clarity, falling back to host networking only when performance is critically impacted.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Volumes and Persistent Storage

This is one of the most important topics for running Bareos in containers. All Bareos configuration, catalog data, and backup Volumes must persist across container restarts and image updates.

### The Three Volume Types

**Named Volumes** (recommended for persistent application data):
```bash
# Create a named volume
podman volume create bareos-config

# Use it in a container
podman run -v bareos-config:/etc/bareos bareos/bareos-director

# Inspect where the data lives on the host
podman volume inspect bareos-config
# Data lives at: /home/bareos/.local/share/containers/storage/volumes/bareos-config/_data/
```

Named volumes are managed by Podman. They persist even after the container is removed. This is the correct choice for application configuration and state.

**Bind Mounts** (recommended when host path matters):
```bash
# Mount a specific host directory into the container
podman run -v /srv/bareos-storage/volumes:/var/lib/bareos/storage:Z \
  bareos/bareos-storage
```

Bind mounts are the correct choice for Bareos Volume storage because:
- The storage path is on the dedicated backup disk (`/srv/bareos-storage`)
- The storage must survive container and volume removal
- Other host tools (e.g., backup-of-backup scripts) can access it directly

**Tmpfs** (for temporary, in-memory storage):
```bash
podman run --tmpfs /tmp:rw,noexec,nosuid,size=128m myapp
```

Used for truly ephemeral data. Not relevant for Bareos persistent state.

### Volume Ownership and UID Mapping

This is a critical gotcha for rootless containers. When Podman creates a container with UID mapping, files inside the container appear to be owned by container-UID 0 (root), but on the host they are owned by the `bareos` user's subordinate UID range.

```bash
# Example: Write a file inside a container as container-root
podman run --rm -v /tmp/test-vol:/data:Z alpine sh -c "echo hello > /data/test.txt && ls -la /data/"
# Inside container: -rw-r--r-- 1 root root ...

# On the host: owned by subordinate UID (maps to 'bareos' user's first sub-UID)
ls -la /tmp/test-vol/
# On host: -rw-r--r-- 1 100000 100000 ...
```

For Bareos backup Volumes stored at `/srv/bareos-storage`:

```bash
# The bind-mounted directory must be owned by the sub-UID
# that the container's process UID maps to.

# Option 1: Pre-create the directory owned by bareos (UID 1001)
# and use --userns=keep-id so container UID matches host UID
podman run --userns=keep-id \
  -v /srv/bareos-storage/volumes:/var/lib/bareos:Z \
  bareos/bareos-storage

# Option 2: Let the container run as its default UID and
# chown the host directory to the mapped sub-UID
# (determined from Bareos container image's internal bareos UID)
```

We solve this definitively in [Chapter 6](./06-bareos-in-podman.md) and revisit it in [Chapter 13](./13-rootless-podman-specifics.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Podman and SELinux: Working Together

On RHEL 10 with SELinux enforcing, every container file access is subject to SELinux policy checks. Understanding this prevents hours of debugging mysterious permission failures.

### Container Default Labels

All Podman containers run with the SELinux type `container_t`:

```bash
# While a container is running, see its process context
podman exec mycontainer cat /proc/1/attr/current
# Output: system_u:system_r:container_t:s0:c123,c456
```

The `c123,c456` part is the MCS (Multi-Category Security) label — each container gets a unique random pair, preventing one container from accessing another's files even if they're on the same host.

### Volume Label Options

When a container accesses a bind-mounted host directory, SELinux checks if `container_t` is allowed to access the directory's label. It usually isn't — host files are typically labeled `user_home_t`, `var_t`, etc., which `container_t` cannot read.

The solution is the `:z` and `:Z` volume options:

```bash
# :z — Relabel to shared container label (container_file_t)
# Use when: multiple containers need to access the same bind mount
podman run -v /srv/bareos-storage/volumes:/var/lib/bareos:z bareos/bareos-storage

# :Z — Relabel to private container label (container_file_t with unique MCS pair)
# Use when: only one container accesses this bind mount
podman run -v /srv/bareos-storage/volumes:/var/lib/bareos:Z bareos/bareos-storage
```

> **Warning:** `:Z` relabeling is permanent. If you later want the host to access that directory with non-container tools, you must manually restore the SELinux context with `restorecon`.

> **Warning:** Never use `:z` or `:Z` on system directories like `/home`, `/etc`, or `/var`. Relabeling them will break the host.

### Named Volumes and SELinux

Podman named volumes are stored in `~/.local/share/containers/storage/volumes/`, which is automatically labeled `container_file_t`. Named volumes do not require `:z`/`:Z` — they work with SELinux out of the box.

This is another reason to prefer named volumes for application configuration data (Bareos config files) and use bind mounts only for the actual storage directory.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Quadlet: Systemd-Native Container Management

Quadlet is the feature that makes running Bareos in containers on RHEL 10 production-quality. Without Quadlet, you would need to write complex systemd unit files by hand or rely on `podman generate systemd` (deprecated in Podman 5). Quadlet automates this.

### What is Quadlet?

Quadlet is a **systemd generator** that reads declarative `.container`, `.volume`, `.network`, and `.pod` files and generates native systemd unit files from them.

When systemd boots (or when you run `systemctl --user daemon-reload`), it runs Quadlet as a generator. Quadlet reads your `.container` files and creates the corresponding `.service` unit files automatically. You never write raw `[Service]` blocks for container management.

### File Locations

| Scope | Directory |
|---|---|
| System-wide (root) | `/etc/containers/systemd/` |
| Per-user (rootless) | `~/.config/containers/systemd/` |

For the `bareos` user:
```
/home/bareos/.config/containers/systemd/
├── bareos-db.container
├── bareos-director.container
├── bareos-storage.container
├── bareos.network
└── bareos-config.volume
```

### Anatomy of a `.container` File

A `.container` file looks like a simplified systemd unit with a `[Container]` section:

```ini
# /home/bareos/.config/containers/systemd/hello.container

[Unit]
Description=Hello World Container
After=network-online.target

[Container]
Image=docker.io/library/alpine:3.19
Exec=/bin/sh -c "echo Hello from Quadlet && sleep 3600"
ContainerName=hello-quadlet

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
```

When systemd processes this file, it generates a unit named `hello.service` (derived from the filename). You manage it like any other service:

```bash
# Reload daemon after adding/editing Quadlet files
systemctl --user daemon-reload

# Start the container
systemctl --user start hello.service

# Check status
systemctl --user status hello.service

# View logs
journalctl --user -u hello.service -f

# Stop
systemctl --user stop hello.service

# Enable at boot
systemctl --user enable hello.service
```

### Available Quadlet Directives

The `[Container]` section supports a rich set of directives that mirror `podman run` options:

```ini
[Container]
Image=docker.io/library/mariadb:10.11
ContainerName=bareos-db
HostName=bareos-db

# Environment variables
Environment=MARIADB_ROOT_PASSWORD=secret
EnvironmentFile=/home/bareos/.config/bareos/db.env

# Volumes
Volume=bareos-db-data.volume:/var/lib/mysql:Z
Volume=/srv/bareos-storage/volumes:/var/lib/bareos:z

# Network
Network=bareos.network

# Ports
PublishPort=9101:9101

# Resource limits
Memory=512m
CPUQuota=100%

# Security
NoNewPrivileges=true
ReadOnlyRootfs=true

# Labels
Label=app=bareos
Label=component=database

# User
User=999:999
```

### `.volume` and `.network` Files

Quadlet also manages volumes and networks declaratively:

```ini
# bareos-db-data.volume
[Volume]
Driver=local
Label=app=bareos
```

```ini
# bareos.network
[Network]
Driver=bridge
Subnet=10.89.0.0/24
Gateway=10.89.0.1
Label=app=bareos
```

These are referenced by name in `.container` files (without the `.volume` or `.network` extension).

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Podman Pods: Grouping Related Containers

A **Podman Pod** is a group of containers that share a network namespace, IPC namespace, and optionally other namespaces. All containers in a pod reach each other via `localhost`.

Pods map directly to Kubernetes Pods, making knowledge of Podman Pods valuable for future Kubernetes migrations.

### Pod Quadlet File

```ini
# /home/bareos/.config/containers/systemd/bareos.pod
[Unit]
Description=Bareos Backup Stack Pod

[Pod]
PodName=bareos
PublishPort=9101:9101
PublishPort=9103:9103

[Install]
WantedBy=default.target
```

Containers join the pod with the `Pod=` directive:

```ini
[Container]
Image=docker.io/library/mariadb:10.11
Pod=bareos.pod   ← references the .pod file
```

Inside the pod, the MariaDB container is reachable at `127.0.0.1:3306` from any other container in the same pod.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Container Registries and Image Management

### Configuring Registries

Podman uses `/etc/containers/registries.conf` (system) or `~/.config/containers/registries.conf` (user) to configure which registries to search:

```ini
# /home/bareos/.config/containers/registries.conf
[registries.search]
registries = ['docker.io', 'quay.io', 'registry.access.redhat.com']

[registries.block]
registries = []
```

### Pulling the Bareos Images

The official Bareos images are hosted on Docker Hub:

```bash
# As the bareos user
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash

# Pull the main Bareos images
podman pull docker.io/bareos/bareos-director:latest
podman pull docker.io/bareos/bareos-storage:latest
podman pull docker.io/bareos/bareos-client:latest
podman pull docker.io/library/mariadb:10.11

# List local images
podman images

# Inspect an image (useful for seeing entry points, exposed ports, default env vars)
podman inspect docker.io/bareos/bareos-director:latest | jq '.[0].Config'
```

### Pinning Image Versions

In production, **never use `:latest`**. Pin to a specific version:

```bash
# Use version-pinned tags for reproducible deployments
podman pull docker.io/bareos/bareos-director:24
```

```ini
# In Quadlet files, use pinned versions
[Container]
Image=docker.io/bareos/bareos-director:24
```

This ensures updates are intentional and tested, not automatic.

### Updating Container Images

```bash
# Pull updated image (while the old container still runs)
podman pull docker.io/bareos/bareos-director:24

# Restart the service — Quadlet/systemd will use the new image
systemctl --user restart bareos-director.service
```

Because volumes store all persistent data, updating the container image does not affect Bareos configuration or catalog data.

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Lab 4-1: Running Your First Rootless Container

Practice the fundamentals as the `bareos` user before deploying the full stack.

```bash
# Switch to bareos user context
sudo machinectl shell bareos@

# --- Inside bareos user session ---

# Verify rootless setup
podman info | grep -E "rootless|graphRoot|runRoot"

# Run a simple container
podman run --rm alpine echo "I am rootless"

# Run an interactive container
podman run -it --rm alpine sh
  # Inside: whoami → root (but it's container root, not host root)
  # Inside: cat /proc/1/uid_map → shows the UID mapping
  # Inside: exit

# Run a container with a named volume
podman volume create test-data
podman run --rm -v test-data:/data alpine sh -c \
  "echo 'Persistent data' > /data/hello.txt && cat /data/hello.txt"

# The data persists after the container exits
podman run --rm -v test-data:/data alpine cat /data/hello.txt
# Output: Persistent data

# Clean up
podman volume rm test-data

# Exit bareos user session
exit
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Lab 4-2: Creating a Quadlet Service

Create a real Quadlet-managed service as the `bareos` user.

```bash
# Switch to bareos user
sudo machinectl shell bareos@

# Create the Quadlet directory (if not already done)
mkdir -p ~/.config/containers/systemd

# Write a simple test Quadlet container file
cat > ~/.config/containers/systemd/test-nginx.container <<'EOF'
[Unit]
Description=Test Nginx Container
After=network-online.target

[Container]
Image=docker.io/library/nginx:alpine
ContainerName=test-nginx
PublishPort=8080:80
Volume=nginx-html.volume:/usr/share/nginx/html:Z
NoNewPrivileges=true

[Service]
Restart=on-failure
TimeoutStartSec=60

[Install]
WantedBy=default.target
EOF

# Write the volume Quadlet file
cat > ~/.config/containers/systemd/nginx-html.volume <<'EOF'
[Volume]
Label=test=true
EOF

# Reload the user systemd daemon so it picks up the new files
systemctl --user daemon-reload

# Start the service
systemctl --user start test-nginx.service

# Check status
systemctl --user status test-nginx.service

# View logs
journalctl --user -u test-nginx.service --no-pager

# Test it
curl http://localhost:8080

# Check the generated unit file (Quadlet creates this automatically)
cat ~/.config/systemd/user/test-nginx.service
# Note: this file is GENERATED — never edit it directly

# Stop and disable
systemctl --user stop test-nginx.service
systemctl --user disable test-nginx.service

# Remove the test files
rm ~/.config/containers/systemd/test-nginx.container
rm ~/.config/containers/systemd/nginx-html.volume
systemctl --user daemon-reload

exit
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Lab 4-3: Persistent Volume Demonstration

This lab demonstrates why bind mounts are necessary for Bareos storage and how UID mapping affects file ownership.

```bash
sudo machinectl shell bareos@

# Create a test bind mount directory
# (simulating /srv/bareos-storage/volumes)
mkdir -p /tmp/bareos-vol-test

# Run a container that writes data to the bind mount
podman run --rm \
  -v /tmp/bareos-vol-test:/data:Z \
  alpine sh -c "
    echo 'Test backup data' > /data/backup-volume.001
    ls -la /data/
    cat /proc/1/uid_map
  "

# On the host: see how file ownership looks
ls -lan /tmp/bareos-vol-test/
# The files are owned by the bareos user's subordinate UID (e.g., 100000)

# The --userns=keep-id option maps container UID to the same host UID
podman run --rm \
  --userns=keep-id \
  -v /tmp/bareos-vol-test:/data:Z \
  alpine sh -c "
    echo 'Test data with keep-id' > /data/backup-volume.002
    ls -lan /data/
    id
  "

# With keep-id, files are owned by the bareos user (UID 1001) on the host
ls -lan /tmp/bareos-vol-test/

# Clean up
rm -rf /tmp/bareos-vol-test
exit
```

**Key takeaway:** The Bareos Storage Daemon container must be configured with `--userns=keep-id` OR the storage directory must be pre-owned by the mapped sub-UID. We handle this properly in [Chapter 6](./06-bareos-in-podman.md).

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Summary

In this chapter you learned the Podman fundamentals required for the Bareos deployment:

- **Podman vs Docker**: Podman is daemonless, each user manages their own containers, no privileged daemon exists. This makes rootless containers practical and secure.
- **Container concepts**: Images are immutable templates, containers are running instances. Layers, CoW, namespaces, and cgroups provide isolation.
- **Rootless containers**: User namespace UID mapping means container-root is never host-root. Essential for security on RHEL 10.
- **Networking**: Named networks for inter-container DNS resolution, Pods for shared-localhost communication, host networking for maximum performance.
- **Volumes**: Named volumes for application config/state (automatically SELinux-labeled), bind mounts for Bareos storage (where the host path matters).
- **SELinux with Podman**: `:z` (shared) and `:Z` (private) volume options relabel bind mounts for container access. Named volumes work automatically.
- **Quadlet**: Declarative `.container`, `.volume`, `.network`, and `.pod` files that systemd generates native service units from. The production-ready way to manage containers on RHEL 10.
- **Image management**: Pin versions in production, pull images explicitly, store in the bareos user's local container storage.

---

**Next Chapter:** [Chapter 5: Bareos Architecture Deep Dive](./05-bareos-architecture.md)

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
