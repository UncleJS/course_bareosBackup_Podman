# Chapter 12: Deep Dive into Quadlet and systemd Integration

## Table of Contents

- [1. What Is Quadlet? History and Motivation](#1-what-is-quadlet-history-and-motivation)
  - [The Problem That Quadlet Solves](#the-problem-that-quadlet-solves)
  - [Enter Quadlet](#enter-quadlet)
  - [Why Quadlet Is Better for Production](#why-quadlet-is-better-for-production)
- [2. The Four Quadlet Unit Types](#2-the-four-quadlet-unit-types)
  - [`.container` Units](#container-units)
  - [`.volume` Units](#volume-units)
  - [`.network` Units](#network-units)
  - [`.pod` Units](#pod-units)
- [3. Quadlet Lookup Paths: System vs. User (Rootless)](#3-quadlet-lookup-paths-system-vs-user-rootless)
  - [System-Wide Paths (root / system services)](#system-wide-paths-root-system-services)
  - [User (Rootless) Paths](#user-rootless-paths)
  - [Verifying the Path](#verifying-the-path)
- [4. How systemd --user Picks Up Quadlet Files](#4-how-systemd-user-picks-up-quadlet-files)
  - [The systemd Generator Mechanism](#the-systemd-generator-mechanism)
  - [The daemon-reload Workflow](#the-daemon-reload-workflow)
  - [Verifying Generator Output](#verifying-generator-output)
- [5. Dependency Ordering: After=, Requires=, Wants=](#5-dependency-ordering-after-requires-wants)
  - [`After=`](#after)
  - [`Requires=`](#requires)
  - [`Wants=`](#wants)
  - [`BindsTo=`](#bindsto)
  - [Bareos Dependency Graph](#bareos-dependency-graph)
  - [Waiting for Container Health](#waiting-for-container-health)
- [6. Complete Quadlet Stack for Bareos](#6-complete-quadlet-stack-for-bareos)
  - [Prerequisites](#prerequisites)
  - [File: `bareos-db.volume`](#file-bareos-dbvolume)
  - [File: `bareos-store.volume`](#file-bareos-storevolume)
  - [File: `bareos-net.network`](#file-bareos-netnetwork)
  - [File: `bareos-db.container`](#file-bareos-dbcontainer)
   - [File: `bareos-director.container`](#file-bareos-directorcontainer)
  - [File: `bareos-storage.container`](#file-bareos-storagecontainer)
  - [File: `bareos-fd.container`](#file-bareos-fdcontainer)
- [7. Volume Management: Named Volumes and Pre-Creation](#7-volume-management-named-volumes-and-pre-creation)
  - [Named Volumes vs. Bind Mounts](#named-volumes-vs-bind-mounts)
  - [Pre-Creating Named Volumes](#pre-creating-named-volumes)
  - [The Quadlet Volume Service Name Convention](#the-quadlet-volume-service-name-convention)
- [8. Network Isolation: Quadlet-Managed Networks](#8-network-isolation-quadlet-managed-networks)
  - [Why Network Isolation Matters](#why-network-isolation-matters)
  - [Container-to-Container DNS](#container-to-container-dns)
  - [The Network Service Name Convention](#the-network-service-name-convention)
- [9. Environment Files: Secrets via EnvironmentFile=](#9-environment-files-secrets-via-environmentfile)
  - [Why Not Embed Secrets in Quadlet Files?](#why-not-embed-secrets-in-quadlet-files)
  - [The `EnvironmentFile=` Directive](#the-environmentfile-directive)
  - [File: `/home/bareos/.config/bareos/db.env`](#file-homebareosconfigbareosdbenv)
  - [File: `/home/bareos/.config/bareos/bareos.env`](#file-homebareosconfigbareosbareosenv)
  - [Securing the Files](#securing-the-files)
- [10. Health Checks in Quadlet](#10-health-checks-in-quadlet)
  - [Why Health Checks Are Critical](#why-health-checks-are-critical)
  - [Quadlet Health Check Directives](#quadlet-health-check-directives)
  - [Health Check for MariaDB](#health-check-for-mariadb)
  - [Checking Health Status](#checking-health-status)
- [11. Auto-Update with podman auto-update](#11-auto-update-with-podman-auto-update)
  - [What Is podman auto-update?](#what-is-podman-auto-update)
  - [Enabling Auto-Update on a Container](#enabling-auto-update-on-a-container)
  - [The Auto-Update Systemd Timer](#the-auto-update-systemd-timer)
  - [Pinning an Image to a Digest](#pinning-an-image-to-a-digest)
- [12. Logging: journalctl for Container Units](#12-logging-journalctl-for-container-units)
  - [How Container Logs Flow to the Journal](#how-container-logs-flow-to-the-journal)
  - [Basic Log Commands](#basic-log-commands)
  - [Journal Output Formats](#journal-output-formats)
  - [Podman's Own Logging](#podmans-own-logging)
- [13. Debugging Failed Unit Starts](#13-debugging-failed-unit-starts)
  - [The Debugging Workflow](#the-debugging-workflow)
  - [Common Error Messages and Fixes](#common-error-messages-and-fixes)
- [14. Restart Policies](#14-restart-policies)
  - [`Restart=` Options](#restart-options)
  - [`RestartSec=`](#restartsec)
  - [`StartLimitIntervalSec=` and `StartLimitBurst=`](#startlimitintervalsec-and-startlimitburst)
- [Lab 12-1: Write the Full Quadlet Stack from Scratch](#lab-12-1-write-the-full-quadlet-stack-from-scratch)
  - [Prerequisites](#prerequisites)
  - [Step 1: Create the bareos user and set up directories](#step-1-create-the-bareos-user-and-set-up-directories)
  - [Step 2: Set up the storage path with correct SELinux type](#step-2-set-up-the-storage-path-with-correct-selinux-type)
  - [Step 3: Create the env files](#step-3-create-the-env-files)
  - [Step 4: Write all Quadlet files](#step-4-write-all-quadlet-files)
  - [Step 5: Pre-pull images](#step-5-pre-pull-images)
  - [Step 6: Reload and enable services](#step-6-reload-and-enable-services)
  - [Step 7: Verify the stack](#step-7-verify-the-stack)
- [Lab 12-2: Simulate a Crash and Observe Auto-Restart](#lab-12-2-simulate-a-crash-and-observe-auto-restart)
  - [Step 1: Record the current container ID](#step-1-record-the-current-container-id)
  - [Step 2: Simulate a crash](#step-2-simulate-a-crash)
  - [Step 3: Observe the restart](#step-3-observe-the-restart)
  - [Step 4: Verify service status after restart](#step-4-verify-service-status-after-restart)
- [Lab 12-3: Enable podman auto-update and Pin an Image Digest](#lab-12-3-enable-podman-auto-update-and-pin-an-image-digest)
  - [Step 1: Enable the auto-update timer](#step-1-enable-the-auto-update-timer)
  - [Step 2: Run auto-update manually and observe](#step-2-run-auto-update-manually-and-observe)
  - [Step 3: Pin the Director to the current digest](#step-3-pin-the-director-to-the-current-digest)
- [Summary](#summary)

## 1. What Is Quadlet? History and Motivation

### The Problem That Quadlet Solves

Before Quadlet existed, the recommended way to run Podman containers under systemd was to use `podman generate systemd`. You would start a container manually, run `podman generate systemd <container-name>`, and receive a generated `.service` file that you would copy into your systemd unit directory. This worked, but it had serious drawbacks:

- **Imperative, not declarative.** You had to create the container first, then generate the unit from it. If you wanted to change a mount path or an environment variable, you had to delete the container, recreate it with different arguments, and regenerate the unit file.
- **Fragile regeneration cycle.** Every change required destroying and recreating containers in a precise order to avoid stale state.
- **Hard to audit and version-control.** The generated unit files were verbose and contained embedded Podman command-line flags, making them difficult to read and review.
- **No lifecycle integration for volumes and networks.** The generated units could run a container, but creating volumes and networks was still a manual, out-of-band step.

### Enter Quadlet

Quadlet was originally a standalone project created by Alexander Larsson at Red Hat. It introduced the idea of writing *declarative* unit files — files that describe what you want, not how to build it — in a Podman-specific format. When first released as an external tool, Quadlet would read `.container` files and generate `.service` files from them.

Starting with **Podman 4.4** (shipped with RHEL 9.2 and later) and fully mature in **Podman 4.6+**, Quadlet was merged directly into Podman itself. The Quadlet generator is now built into the `podman` binary and is invoked automatically by systemd's generator infrastructure during `daemon-reload`. There is no separate `quadlet` binary to install — it just works.

The `podman generate systemd` command was deprecated in Podman 4.4 and is scheduled for removal. **Quadlet is the official, supported replacement.**

### Why Quadlet Is Better for Production

With Quadlet, you write a small, human-readable file like this:

```ini
[Container]
Image=docker.io/bareos/bareos-director:24
```

And systemd + Podman do the rest: pulling the image, creating the container with appropriate flags, managing the lifecycle, logging to the journal, and restarting on failure. The entire state of your container infrastructure is captured in a handful of plain text files that you can commit to git, review in pull requests, and apply idempotently.

This is the same philosophy as Kubernetes manifests, but for single-node or small-cluster use cases where Kubernetes would be overkill.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. The Four Quadlet Unit Types

Quadlet defines four unit types, each with its own file extension. Each maps to a native systemd concept and ultimately generates a transient `.service`, `.mount`, or other unit file behind the scenes.

### `.container` Units

A `.container` file describes a single container. It is the most commonly used Quadlet type and maps to a systemd `.service` unit. The generated service uses `podman run` to start the container and `podman stop` to stop it.

**Anatomy of a `.container` file:**

A `.container` file uses standard systemd INI syntax with two sections: the standard `[Unit]` and `[Service]` sections (for things systemd understands directly) and a special `[Container]` section (parsed by Quadlet's generator).

```ini
# Everything in [Unit] and [Service] is passed through verbatim to the
# generated .service file. Use these for systemd-native directives.
[Unit]
Description=My example container

[Container]
# The [Container] section is Quadlet-specific. Every key here controls
# how `podman run` is invoked.
Image=docker.io/example/app:latest
ContainerName=my-app

[Service]
Restart=on-failure

[Install]
WantedBy=default.target
```

The file is saved with a `.container` extension, e.g., `my-app.container`. systemd will generate a unit named `my-app.service` from it. You interact with the service using that `.service` name: `systemctl --user start my-app.service`.

**Key `[Container]` directives:**

| Directive | Description |
|---|---|
| `Image=` | The container image to run (required) |
| `ContainerName=` | Sets the `--name` flag for `podman run` |
| `Exec=` | Override the container's default command |
| `Environment=` | Set an environment variable (`KEY=VALUE`) |
| `EnvironmentFile=` | Source environment variables from a file |
| `Volume=` | Mount a volume or bind mount (`source:dest[:options]`) |
| `Network=` | Attach to a network by name or Quadlet network reference |
| `PublishPort=` | Publish a port (`host:container`) |
| `Label=` | Set a container label |
| `AddCapability=` | Add a Linux capability |
| `DropCapability=` | Drop a Linux capability |
| `User=` | Set the UID to run as inside the container |
| `HealthCmd=` | Health check command |
| `HealthInterval=` | How often to run the health check |
| `HealthStartPeriod=` | Grace period before health checks begin |
| `Notify=` | Whether the container uses `sd_notify` (`healthy` or `true`) |
| `AutoUpdate=` | Enable auto-update (`registry` or `local`) |
| `Pull=` | When to pull the image (`missing`, `always`, `never`) |

### `.volume` Units

A `.volume` file describes a named Podman volume. It generates a systemd `.service` unit that calls `podman volume create` if the volume does not already exist.

```ini
[Volume]
# Driver can be 'local' (default) or a plugin name.
Driver=local

# Labels applied to the volume.
Label=app=bareos
Label=component=database
```

The file name determines the volume name. A file named `bareos-db.volume` creates a volume named `bareos-db`. Other Quadlet units can reference it as `bareos-db.volume` in their `Volume=` directive.

### `.network` Units

A `.network` file describes a Podman network. It maps to a systemd service that calls `podman network create`.

```ini
[Network]
# The subnet to allocate from this network.
Subnet=10.89.1.0/24

# Enable DNS resolution between containers on this network.
DNS=true

# Labels for identification.
Label=app=bareos
```

The file `bareos-net.network` creates a network named `bareos-net`. Containers reference it as `bareos-net.network` in their `[Container]` `Network=` directive.

### `.pod` Units

A `.pod` file describes a Podman pod — a group of containers that share a network namespace (like a Kubernetes pod). Containers can be assigned to the pod using `Pod=` in their `.container` file.

```ini
[Pod]
PublishPort=9101:9101
Network=bareos-net.network
```

Pod units are less commonly used than individual container units because Quadlet's network management already provides container-to-container communication. However, they are useful when containers must share `localhost` (e.g., a sidecar container that communicates via loopback to the main container).

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Quadlet Lookup Paths: System vs. User (Rootless)

Quadlet files can live in several directories, and systemd knows which directories to search based on whether it is the system daemon or a user daemon.

### System-Wide Paths (root / system services)

When running as root (or managing system services), Quadlet reads from:

- `/etc/containers/systemd/` — administrator-managed units (highest priority)
- `/usr/share/containers/systemd/` — distribution-provided units (lowest priority)

System-wide Quadlet units are managed with `systemctl` (without `--user`) and run containers as root.

### User (Rootless) Paths

When running under `systemd --user`, Quadlet reads from:

- `~/.config/containers/systemd/` — the primary user directory
- `/etc/containers/systemd/users/<UID>/` — admin-set units for a specific user
- `/etc/containers/systemd/users/` — admin-set units for all users

For the `bareos` system user (UID 1001), the primary Quadlet directory is:

```
/home/bareos/.config/containers/systemd/
```

This is the directory where all Bareos Quadlet files will be placed throughout this course. The `systemd --user` instance for the `bareos` user scans this directory during `daemon-reload` and generates transient unit files from whatever `.container`, `.volume`, `.network`, and `.pod` files it finds.

> **Why this matters for security:** Because all Quadlet files live in the `bareos` home directory (mode 700, owned by `bareos:bareos`), no other unprivileged user can read or modify them. This is an important part of the defense-in-depth security model.

### Verifying the Path

```bash
# Switch to the bareos user
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash

# List the Quadlet directory
ls -la ~/.config/containers/systemd/

# Ask Podman where it expects Quadlet files
podman --help | grep -i quadlet
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. How systemd --user Picks Up Quadlet Files

Understanding *how* systemd processes Quadlet files helps you debug problems when a unit does not appear or fails to generate.

### The systemd Generator Mechanism

systemd has a concept called **generators**: programs that run before the main init sequence and produce transient unit files in a temporary directory. These generated units are treated exactly like hand-written unit files, but they live in `/run/` rather than `/etc/` or `/lib/`.

When you run `systemctl --user daemon-reload`, systemd:

1. Runs all generators registered for the user instance.
2. The Quadlet generator (`/usr/lib/systemd/user-generators/podman-user-generator` on RHEL 10) is one of those generators.
3. The generator scans all Quadlet lookup paths (see Section 3) and finds your `.container`, `.volume`, `.network`, and `.pod` files.
4. For each file found, it generates a transient `.service` unit (or `.mount` unit for volumes) and writes it to `/run/user/1001/systemd/generator/`.
5. systemd reads those generated units into its in-memory unit database.

You can inspect the generated output:

```bash
# After daemon-reload, look at generated units
ls /run/user/1001/systemd/generator/

# View the generated service file for bareos-director.container
cat /run/user/1001/systemd/generator/bareos-director.service
```

The generated file will look like a normal `.service` unit with `ExecStart=` containing a long `podman run` command. This is valuable for debugging — you can see exactly what command Quadlet constructed.

### The daemon-reload Workflow

Every time you add, modify, or remove a Quadlet file, you must run:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
```

This is equivalent to telling systemd: "Re-run all generators and reload my unit database." Without this step, systemd will not see your changes.

After a `daemon-reload`, you enable and start units as normal:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now bareos-director.service
```

> **Important:** The `.service` suffix in `systemctl` commands refers to the *generated* service, not the `.container` file. The generated service name always matches the Quadlet file name with the extension replaced by `.service`. So `bareos-director.container` → `bareos-director.service`.

### Verifying Generator Output

```bash
# Run the Quadlet generator manually to see what it would produce
# (useful for syntax checking before daemon-reload)
QUADLET_UNIT_DIRS=/home/bareos/.config/containers/systemd \
  /usr/lib/systemd/user-generators/podman-user-generator \
  /tmp/quadlet-out /tmp/quadlet-out /tmp/quadlet-out

ls /tmp/quadlet-out/
cat /tmp/quadlet-out/bareos-director.service
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Dependency Ordering: After=, Requires=, Wants=

Running multiple containers that depend on each other requires careful ordering. Bareos has a hard dependency chain:

```
MariaDB must be healthy → Bareos Director can start → Bareos Storage Daemon can connect
```

systemd provides several directives to express these relationships. They are placed in the `[Unit]` section of Quadlet files.

### `After=`

`After=unitA` means: "If both this unit and `unitA` are being started, start `unitA` first." It only defines *ordering* — it does not cause the listed unit to start. If `unitA` fails, this unit may still attempt to start.

```ini
[Unit]
After=bareos-db.service
```

### `Requires=`

`Requires=unitA` means: "This unit cannot start without `unitA`. If `unitA` fails or stops, stop this unit too." It is a strong dependency — both ordering *and* propagation of failures. If `unitA` is not already active, systemd will try to start it.

```ini
[Unit]
Requires=bareos-db.service
After=bareos-db.service
```

> **Best practice:** Always pair `Requires=` with `After=` to ensure both ordering and dependency. `Requires=` alone does not guarantee ordering.

### `Wants=`

`Wants=unitA` is a weak dependency. It means: "Try to start `unitA` alongside this unit, but do not fail if `unitA` cannot be started." This is appropriate for optional services (e.g., a metrics exporter that is nice-to-have but not critical).

### `BindsTo=`

`BindsTo=unitA` is even stronger than `Requires=`. If `unitA` stops *for any reason* (even a clean stop), this unit is also stopped immediately. This is appropriate for containers that are tightly coupled — a Bareos Director that cannot function without its database should use `BindsTo=` to ensure it is torn down when the database goes away.

> **Important:** `BindsTo=` defines a *teardown* relationship, not a *start ordering* relationship. It does **not** guarantee that `unitA` starts before this unit. Always pair `BindsTo=` with a corresponding `After=` on the same unit to enforce startup ordering:
>
> ```ini
> BindsTo=bareos-db.service
> After=bareos-db.service   # ← required for correct start order
> ```
>
> Without `After=`, systemd may attempt to start both units simultaneously, causing the Director to fail on first connect because the database is not yet ready.

### Bareos Dependency Graph

For the Bareos stack:

```
bareos-db-volume.service   ─┐
bareos-store-volume.service ─┼─ Wants → bareos-db.service
bareos-net-network.service  ─┘       ↓ (Requires + After)
                                bareos-director.service
                                       ↓ (Wants + After)
                               bareos-storage.service
                               bareos-fd.service
```

In practice, the `[Unit]` section of `bareos-director.container` should look like:

```ini
[Unit]
Description=Bareos Director
Requires=bareos-db.service bareos-net-network.service
After=bareos-db.service bareos-net-network.service
Wants=bareos-storage.service
```

### Waiting for Container Health

A critical subtlety: `After=bareos-db.service` ensures the MariaDB container *starts*, not that MariaDB is ready to accept connections. The database initialization takes several seconds. If the Director starts connecting before the database is ready, it will fail.

The solution is to configure a health check on the `bareos-db` container and then tell the Director to wait for that health check. We cover health checks in Section 10, but the key directive for the waiting side is:

```ini
[Unit]
# Wait for bareos-db to report healthy, not just started.
After=bareos-db.service
```

Combined with `Notify=healthy` on `bareos-db.container`, systemd will delay starting the Director until MariaDB's health check passes.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Complete Quadlet Stack for Bareos

This section presents the complete set of Quadlet files for the Bareos backup system. Each file is annotated line by line. All files live in `/home/bareos/.config/containers/systemd/`.

### Prerequisites

Before writing the Quadlet files, ensure:

1. The `bareos` user exists with UID 1001 and lingering is enabled.
2. The storage directory exists with the correct SELinux type.
3. The secret env files exist and are mode 600.

```bash
# Verify the bareos user
id bareos

# Verify lingering
loginctl show-user bareos | grep Linger

# Verify storage directory and SELinux context
ls -laZ /srv/bareos-storage/volumes

# Verify env files
ls -la /home/bareos/.config/bareos/
```

### File: `bareos-db.volume`

```ini
# /home/bareos/.config/containers/systemd/bareos-db.volume
#
# This file creates a named Podman volume called "bareos-db".
# Podman stores the volume data at:
#   ~/.local/share/containers/storage/volumes/bareos-db/_data/
#
# The volume persists across container restarts and removals.
# It holds the MariaDB data directory (all databases, WAL files, etc.)

[Volume]
# Use the default local driver, which stores data in Podman's
# volume directory inside the bareos home directory.
Driver=local

# Labels help you identify this volume's purpose when running
# `podman volume ls` or `podman volume inspect`.
Label=app=bareos
Label=component=database
Label=managed-by=quadlet
```

### File: `bareos-store.volume`

```ini
# /home/bareos/.config/containers/systemd/bareos-store.volume
#
# This volume is a bind-mount-backed volume pointing to the physical
# storage disk at /srv/bareos-storage/volumes. This directory must
# have the correct SELinux type (bareos_store_t) applied BEFORE
# starting the container.
#
# Unlike bareos-db.volume, this volume is backed by a specific
# host path rather than Podman's default volume storage. We achieve
# this using the "device" and "o" (options) mount options.

[Volume]
Driver=local

# Options to pass to `mount`. These are the same options you would
# use with `mount -t none -o bind,rw /src /dst`.
Options=bind
Device=/srv/bareos-storage/volumes

Label=app=bareos
Label=component=storage
Label=managed-by=quadlet
```

> **SELinux Note:** Because `/srv/bareos-storage/volumes` is a bind mount into the container, the directory must carry the `container_file_t` or a custom `bareos_store_t` type that is accessible to container processes. We will label it in Lab 12-1.

### File: `bareos-net.network`

```ini
# /home/bareos/.config/containers/systemd/bareos-net.network
#
# Creates an isolated Podman network named "bareos-net".
# All Bareos containers attach to this network, allowing them to
# reach each other by container name (DNS resolution is enabled).
# No external traffic can reach these containers unless a port
# is explicitly published with PublishPort= in a .container file.

[Network]
# The private subnet for this network. Choose a range that does
# not conflict with your host's network or other Podman networks.
# 10.89.1.0/24 is a good default for user networks.
Subnet=10.89.1.0/24

# Enable the embedded DNS server so containers can resolve each
# other by their ContainerName= values.
DNS=true

# Disable IPv6 for simplicity. Enable with IPv6=true if needed.
IPv6=false

Label=app=bareos
Label=managed-by=quadlet
```

### File: `bareos-db.container`

```ini
# /home/bareos/.config/containers/systemd/bareos-db.container
#
# Runs MariaDB as the Bareos metadata database.
# The Director stores job records, file catalog entries, and all
# backup metadata in this database. It MUST be running and healthy
# before the Director starts.

[Unit]
Description=Bareos Database (MariaDB)
# The volume and network must exist before this container starts.
# Quadlet generates <name>.service units for .volume and .network
# files, so we reference those generated service names here.
After=bareos-db-volume.service bareos-net-network.service
Requires=bareos-db-volume.service bareos-net-network.service

[Container]
Image=docker.io/library/mariadb:10.11

# Give the container a stable, human-readable name.
# This name is also the DNS hostname on the bareos-net network.
ContainerName=bareos-db

# Attach to the isolated bareos-net network.
# The .network suffix tells Quadlet to reference the bareos-net
# Quadlet-managed network (not an external Podman network).
Network=bareos-net.network

# Mount the named volume for persistent database storage.
# bareos-db.volume → volume name "bareos-db"
# /var/lib/mysql is where MariaDB stores its data files.
Volume=bareos-db.volume:/var/lib/mysql:Z

# Z (capital) = relabel the volume contents for SELinux with a
# SHARED label (svirt_sandbox_file_t with a shared MCS label).
# This allows multiple containers to access the same volume.
# Use z (lowercase) if only ONE container accesses this volume —
# it applies a private, per-container MCS label.

# Load database credentials from the env file.
# This file must exist and be mode 600 before starting the service.
EnvironmentFile=/home/bareos/.config/bareos/db.env

# Health check: run a simple SQL query every 10 seconds.
# The Director will wait for this check to pass before starting.
HealthCmd=/usr/local/bin/healthcheck.sh --connect --innodb_initialized
HealthInterval=10s
HealthStartPeriod=30s
HealthTimeout=5s
HealthRetries=3

# sd_notify: send READY=1 to systemd when the health check passes.
# This allows services with After= on this unit to wait for
# "healthy" rather than just "started".
Notify=healthy

# Auto-update policy: "registry" means check the registry for
# a newer image with the same tag and update if found.
Label=io.containers.autoupdate=registry

[Service]
Restart=on-failure
RestartSec=10s
# Increase the start timeout to allow for first-run DB initialization
# which can take 30-60 seconds on slow disks.
TimeoutStartSec=120

[Install]
WantedBy=default.target
```

### File: `bareos-director.container`

```ini
# /home/bareos/.config/containers/systemd/bareos-director.container
#
# The Bareos Director is the central controller of the backup system.
# It reads the backup configuration (jobs, schedules, file sets),
# communicates with File Daemons on client machines to initiate
# backups, and instructs the Storage Daemon where to write data.
# It stores all metadata (job records, file catalog) in MariaDB.

[Unit]
Description=Bareos Director
# The Director cannot function without the database.
# BindsTo= means: if bareos-db.service stops, stop this unit too.
BindsTo=bareos-db.service
After=bareos-db.service bareos-net-network.service
Requires=bareos-net-network.service

[Container]
Image=docker.io/bareos/bareos-director:24
ContainerName=bareos-director
Network=bareos-net.network

# Mount the Bareos configuration directory.
# /home/bareos/bareos-config/director/ is a host directory
# containing the Director's configuration files.
# :Z relabels it for SELinux (private container label).
Volume=/home/bareos/bareos-config/director:/etc/bareos:Z

# Load Director-specific environment variables.
# Contains BAREOS_DB_PASSWORD, BAREOS_DB_HOST, etc.
EnvironmentFile=/home/bareos/.config/bareos/bareos.env
EnvironmentFile=/home/bareos/.config/bareos/db.env

# The Director listens on port 9101 for File Daemon connections.
# We publish this port so external clients can connect.
PublishPort=9101:9101

# Health check: verify the Director's listener port is accepting TCP
# connections. A TCP check is more reliable than running bconsole
# inside the container — bconsole requires a valid config, TLS
# negotiation, and a working catalog connection to succeed, making it
# prone to false negatives during startup. A successful TCP connect on
# port 9101 confirms the Director process is alive and listening.
# (bconsole authentication errors would still leave the port open, so
# add bconsole-level monitoring separately if needed.)
HealthCmd=/bin/sh -c "exec 3<>/dev/tcp/127.0.0.1/9101 && echo OK && exec 3>&-"
HealthInterval=30s
HealthStartPeriod=60s
HealthTimeout=10s
HealthRetries=3

Notify=healthy

Label=io.containers.autoupdate=registry
Label=app=bareos
Label=component=director

[Service]
Restart=on-failure
RestartSec=15s
TimeoutStartSec=180

[Install]
WantedBy=default.target
```

### File: `bareos-storage.container`

```ini
# /home/bareos/.config/containers/systemd/bareos-storage.container
#
# The Bareos Storage Daemon receives backup data from File Daemons
# (via the Director's coordination) and writes it to storage volumes.
# In this setup the storage is on /srv/bareos-storage/volumes,
# bind-mounted via the bareos-store.volume Quadlet volume.

[Unit]
Description=Bareos Storage Daemon
# The SD needs the store volume and the network.
# It connects to the Director for authentication, but the Director
# connects back to the SD to send jobs, so we only need the network.
After=bareos-net-network.service bareos-store-volume.service
Requires=bareos-net-network.service bareos-store-volume.service

[Container]
Image=docker.io/bareos/bareos-storage:24
ContainerName=bareos-storage
Network=bareos-net.network

# Mount the persistent backup storage.
# The SD writes actual backup archives here.
Volume=bareos-store.volume:/var/lib/bareos/storage:Z

# Mount the SD configuration directory.
Volume=/home/bareos/bareos-config/storage:/etc/bareos:Z

EnvironmentFile=/home/bareos/.config/bareos/bareos.env

# The SD listens on 9103 for Director connections.
PublishPort=9103:9103

HealthCmd=/usr/local/bin/healthcheck.sh
HealthInterval=30s
HealthStartPeriod=45s

Label=io.containers.autoupdate=registry
Label=app=bareos
Label=component=storage-daemon

[Service]
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
```

### File: `bareos-fd.container`

```ini
# /home/bareos/.config/containers/systemd/bareos-fd.container
#
# The Bareos File Daemon (client) runs on the machine being backed up.
# In this containerized setup we run a local FD to back up the host
# filesystem and any other containers' data volumes.
# In production, FDs usually run on remote clients as separate
# containers or native packages — this is the local FD for the
# backup server itself.

[Unit]
Description=Bareos File Daemon (local client)
After=bareos-net-network.service
Requires=bareos-net-network.service
# The FD only needs to run when the Director wants to talk to it.
# It does not need to start before the Director.
Wants=bareos-director.service

[Container]
Image=docker.io/bareos/bareos-client:24
ContainerName=bareos-fd
Network=bareos-net.network

# Mount directories to be backed up.
# :ro = read-only; the FD only reads, never writes the source data.
Volume=/home/bareos:/backup/bareos-home:ro,Z
Volume=/etc:/backup/etc:ro,Z

# Mount hook scripts from host into the container (read-only).
# RunScript Command= paths are resolved inside the container, so scripts
# created at /etc/bareos/scripts/ on the host must be bind-mounted in.
# See Chapter 10, Section 3 for the full explanation.
Volume=/etc/bareos/scripts:/etc/bareos/scripts:ro,Z

# Mount the dump output directory with write access so hook scripts
# can create dump files that Bareos then reads for backup.
Volume=/var/tmp/bareos-dumps:/var/tmp/bareos-dumps:rw,Z

# Mount the FD configuration.
Volume=/home/bareos/bareos-config/filedaemon:/etc/bareos:Z

EnvironmentFile=/home/bareos/.config/bareos/bareos.env

# Mount the Podman socket so hook scripts can issue podman exec / pause / stop
# commands against the host container runtime (see Chapter 10, Section 3).
Volume=/run/user/1001/podman/podman.sock:/run/user/1001/podman/podman.sock:Z
Environment=CONTAINER_HOST=unix:///run/user/1001/podman/podman.sock

# The FD listens on 9102 for Director connections.
PublishPort=9102:9102

Label=io.containers.autoupdate=registry
Label=app=bareos
Label=component=file-daemon

[Service]
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
```

### File: `bareos-webui-config.volume`

The WebUI configuration volume holds the two INI files (`directors.ini` and `configuration.ini`) that the WebUI container reads on startup.

```ini
# /home/bareos/.config/containers/systemd/bareos-webui-config.volume
#
# Named volume for Bareos WebUI configuration.
# Populated with directors.ini and configuration.ini before first start.
# See Chapter 6, Section 12 for population commands.

[Volume]
Label=app=bareos
Label=component=webui-config
```

### File: `bareos-webui.container`

```ini
# /home/bareos/.config/containers/systemd/bareos-webui.container
#
# Bareos WebUI — the graphical management interface.
# Connects to the Director's console API on port 9101.
# Exposed on localhost:9100; place nginx in front for HTTPS.

[Unit]
Description=Bareos WebUI
Documentation=https://docs.bareos.org/IntroductionAndTutorial/BareosWebui.html
# The WebUI is useless without the Director — hard-depend on it.
After=bareos-director.service
Requires=bareos-director.service

[Container]
Image=docker.io/bareos/bareos-webui:24
ContainerName=bareos-webui

# Join the bareos network so the WebUI can reach the Director by container name.
Network=bareos-net.network

# Mount the config volume at the path the WebUI image expects.
Volume=bareos-webui-config:/etc/bareos-webui:Z

# Expose the WebUI on localhost only.
PublishPort=127.0.0.1:9100:80

Label=io.containers.autoupdate=registry
Label=app=bareos
Label=component=webui

[Service]
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
```

The complete Bareos Quadlet stack now consists of **seven units**:

| File | Type | Purpose |
|------|------|---------|
| `bareos-net.network` | Network | Isolated bridge for all Bareos containers |
| `bareos-db.volume` | Volume | MariaDB catalog data |
| `bareos-store.volume` | Volume | Backup archive storage |
| `bareos-webui-config.volume` | Volume | WebUI INI configuration files |
| `bareos-db.container` | Container | MariaDB catalog |
| `bareos-storage.container` | Container | Bareos Storage Daemon |
| `bareos-director.container` | Container | Bareos Director |
| `bareos-fd.container` | Container | Bareos File Daemon (local client) |
| `bareos-webui.container` | Container | Bareos WebUI (graphical interface) |

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Volume Management: Named Volumes and Pre-Creation

### Named Volumes vs. Bind Mounts

Podman (and Docker) support two main ways to persist container data:

**Named volumes** are managed by Podman's volume subsystem. Podman creates a directory under `~/.local/share/containers/storage/volumes/<name>/_data/` and mounts it into the container. You do not need to know the exact host path — Podman manages it. Named volumes are the preferred choice for container-internal data (like database files) because:

- Podman initializes the volume directory with correct permissions automatically.
- They are easy to back up and inspect with `podman volume export` / `podman volume import`.
- They survive `podman rm` (the container can be destroyed and recreated without data loss).

**Bind mounts** map a specific host directory into the container. They are appropriate when:

- The data must be accessible from the host directly (e.g., reading backup archives with host tools).
- The data lives on a specific device or filesystem (e.g., `/srv/bareos-storage` on a dedicated disk).
- You need fine-grained control over SELinux labels.

In our Bareos setup:
- `bareos-db.volume` → named volume (database files, managed by Podman)
- `bareos-store.volume` → bind-mount-backed volume pointing to `/srv/bareos-storage/volumes` (backup archives, accessible by host tools)

### Pre-Creating Named Volumes

Quadlet will create named volumes automatically when the `.volume` unit is started. However, you may want to pre-create them for two reasons:

1. To verify that the volume exists before starting the stack.
2. To pre-populate the volume with data (e.g., restoring a backup).

```bash
# Pre-create the named volume manually
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman volume create bareos-db

# Inspect the volume to find its path
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman volume inspect bareos-db

# The _data directory is where container writes go
ls ~/.local/share/containers/storage/volumes/bareos-db/_data/
```

### The Quadlet Volume Service Name Convention

When Quadlet processes a `.volume` file, it creates a systemd service unit whose name is the file's basename with `.service` appended and hyphens replacing dots in the volume name portion. Specifically:

| Quadlet file | Generated service | Volume name |
|---|---|---|
| `bareos-db.volume` | `bareos-db-volume.service` | `bareos-db` |
| `bareos-store.volume` | `bareos-store-volume.service` | `bareos-store` |

Use these `.service` names in `After=` and `Requires=` directives in your `.container` files.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Network Isolation: Quadlet-Managed Networks

### Why Network Isolation Matters

Without explicit network configuration, Podman assigns rootless containers to the default `podman` network, which:

- Allows all containers in your user namespace to communicate with each other, regardless of purpose.
- May conflict with other users' container networks.
- Is harder to reason about in security audits.

By creating a dedicated `bareos-net` network, we ensure:

- Only Bareos containers are attached to this network.
- Containers resolve each other by `ContainerName` via DNS (e.g., the Director connects to `bareos-db:3306`).
- The network is destroyed and recreated cleanly by Quadlet's lifecycle management.

### Container-to-Container DNS

When `DNS=true` is set in the `.network` file, Podman runs an embedded DNS server (via `aardvark-dns`) that listens inside the network. Each container's `ContainerName=` becomes its DNS hostname within the network.

For the Bareos stack, this means:

| Container | DNS hostname | Port |
|---|---|---|
| `bareos-db` | `bareos-db` | 3306 |
| `bareos-director` | `bareos-director` | 9101 |
| `bareos-storage` | `bareos-storage` | 9103 |
| `bareos-fd` | `bareos-fd` | 9102 |

In the Director's configuration file (`bareos-dir.conf`), you would write:
```
dbaddress = bareos-db
dbport = 3306
```

And the Director will resolve `bareos-db` to the MariaDB container's IP address on `bareos-net`.

### The Network Service Name Convention

| Quadlet file | Generated service | Network name |
|---|---|---|
| `bareos-net.network` | `bareos-net-network.service` | `bareos-net` |

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Environment Files: Secrets via EnvironmentFile=

### Why Not Embed Secrets in Quadlet Files?

Quadlet files live in `~/.config/containers/systemd/`. While this directory should be mode 700 (and you should verify this), there are several reasons not to put passwords directly in Quadlet files:

1. **Quadlet files are easy to accidentally commit to git.** Passwords in env files can be gitignored more reliably.
2. **Secrets rotation is easier** when the password lives in one place and multiple unit files reference it.
3. **Audit logging:** Changes to separate secret files can be logged separately from config changes.

### The `EnvironmentFile=` Directive

The `EnvironmentFile=` directive in a Quadlet `[Container]` section is equivalent to passing `--env-file` to `podman run`. It reads the file line by line, ignoring blank lines and lines starting with `#`, and sets each `KEY=VALUE` pair as an environment variable inside the container.

```ini
[Container]
EnvironmentFile=/home/bareos/.config/bareos/db.env
EnvironmentFile=/home/bareos/.config/bareos/bareos.env
```

Multiple `EnvironmentFile=` lines are allowed. Variables defined later override earlier ones.

### File: `/home/bareos/.config/bareos/db.env`

```bash
# /home/bareos/.config/bareos/db.env
# Mode: 600 (chmod 600 /home/bareos/.config/bareos/db.env)
# Owner: bareos:bareos
#
# Environment variables for the MariaDB container.
# These are read by both bareos-db.container and bareos-director.container.

# Root password for the MariaDB instance.
# Change this to a strong random value in production.
MARIADB_ROOT_PASSWORD=change-me-root-password

# The database that Bareos will use.
MARIADB_DATABASE=bareos

# The user that Bareos (Director) uses to connect to the database.
MARIADB_USER=bareos

# The password for the bareos database user.
MARIADB_PASSWORD=change-me-bareos-db-password

# Allow the bareos user to connect from any host (inside the container
# network). In production, restrict this to the Director's container IP.
MARIADB_HOST=%
```

### File: `/home/bareos/.config/bareos/bareos.env`

```bash
# /home/bareos/.config/bareos/bareos.env
# Mode: 600
# Owner: bareos:bareos
#
# Bareos-specific environment variables.
# Referenced by bareos-director.container, bareos-storage.container, bareos-fd.container

# Password that the Director uses to authenticate with the Storage Daemon.
BAREOS_SD_PASSWORD=change-me-sd-password

# Password that the Director uses to authenticate with the File Daemon.
BAREOS_FD_PASSWORD=change-me-fd-password

# Director's own password (used by bconsole to authenticate).
BAREOS_DIR_PASSWORD=change-me-dir-password

# Hostname of the database container (used by Director config).
BAREOS_DB_HOST=bareos-db

# Database name.
BAREOS_DB_NAME=bareos

# Database user.
BAREOS_DB_USER=bareos
```

### Securing the Files

```bash
# Create the config directory
install -d -m 700 /home/bareos/.config/bareos

# Set restrictive permissions on each env file
chmod 600 /home/bareos/.config/bareos/db.env
chmod 600 /home/bareos/.config/bareos/bareos.env

# Verify
ls -la /home/bareos/.config/bareos/
# Expected output:
# -rw------- 1 bareos bareos  512 Feb 24 10:00 bareos.env
# -rw------- 1 bareos bareos  256 Feb 24 10:00 db.env
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Health Checks in Quadlet

### Why Health Checks Are Critical

A container can be "running" (the process is alive) but completely non-functional (the application inside has crashed or is in a startup loop). systemd's `After=` directive only waits for a unit to *start*, not for the application inside to be *ready*.

Without health checks:
- The Director starts immediately after the MariaDB container starts.
- MariaDB takes 20-40 seconds to initialize its data directory on first run.
- The Director's database connection attempt fails.
- The Director either crashes or falls into a retry loop.

With health checks and `Notify=healthy`:
- systemd waits for MariaDB's health check to pass before starting the Director.
- The Director only connects when the database is genuinely ready.

### Quadlet Health Check Directives

```ini
[Container]
# The command to run inside the container. Exit code 0 = healthy.
# Use a command that exercises the actual application, not just
# "is the process running."
HealthCmd=mysqladmin ping -h localhost -u root -p${MARIADB_ROOT_PASSWORD}

# How often to run the health check.
HealthInterval=10s

# Grace period after container start before health checks begin.
# Give the application time to initialize before declaring it unhealthy.
HealthStartPeriod=30s

# How long to wait for the health check command to complete.
HealthTimeout=5s

# How many consecutive failures before the container is "unhealthy".
HealthRetries=3

# Tell systemd to delay activation until the health check passes.
# "healthy" = wait for HealthCmd to return 0 HealthRetries-consecutive times.
Notify=healthy
```

### Health Check for MariaDB

The official MariaDB image ships with a `healthcheck.sh` script:

```ini
HealthCmd=/usr/local/bin/healthcheck.sh --connect --innodb_initialized
```

`--connect` verifies that a TCP connection to port 3306 succeeds. `--innodb_initialized` verifies that InnoDB (the storage engine) has completed its initialization. Both conditions must be true before the health check passes.

### Checking Health Status

```bash
# View the health status of all running containers
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# Inspect health check history for a specific container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman inspect bareos-db \
  --format '{{json .State.Healthcheck}}' | python3 -m json.tool
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Auto-Update with podman auto-update

### What Is podman auto-update?

`podman auto-update` is a Podman command that checks whether the images used by running containers have been updated in their registries, and if so, pulls the new image and restarts the containers. This allows you to receive security patches and bug fixes automatically without manual intervention.

### Enabling Auto-Update on a Container

Add the `io.containers.autoupdate` label to a container:

```ini
[Container]
Label=io.containers.autoupdate=registry
```

The `registry` policy means: "Compare the running container's image digest with the latest digest for the same tag in the registry. If they differ, update."

### The Auto-Update Systemd Timer

Podman ships a systemd timer that runs `podman auto-update` on a schedule. For rootless containers:

```bash
# Enable the user-level auto-update timer
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now podman-auto-update.timer

# Check the timer schedule
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user list-timers podman-auto-update.timer

# Run auto-update manually
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman auto-update
```

### Pinning an Image to a Digest

In production, you typically do not want *any* image update to automatically roll out — you want to test new images in staging first. To prevent auto-update from replacing a known-good image, pin the container to a specific digest instead of a tag:

```bash
# Find the current digest of the Bareos Director image
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman inspect \
  docker.io/bareos/bareos-director:24 \
  --format '{{.Digest}}'
# Output: sha256:abc123...

# Edit bareos-director.container to pin to the digest
# Image=docker.io/bareos/bareos-director@sha256:abc123...
```

When an image is pinned to a digest, `podman auto-update` will skip it (it cannot "update" to a different digest of the same tag because the image reference is locked to a specific content hash).

To update a pinned container:
1. Test the new image in a staging environment.
2. Get the new image's digest.
3. Update the `Image=` line in the `.container` file.
4. Run `systemctl --user daemon-reload`.
5. Run `systemctl --user restart bareos-director.service`.

### Catalog Schema Incompatibility After Auto-Update

> **Warning: This is the most dangerous failure mode of automatic image updates in a Bareos deployment.**

When Bareos releases a new major version (e.g., 23.x → 24.x), the PostgreSQL/MariaDB catalog schema sometimes changes. If `podman auto-update` pulls a new image that expects a newer catalog schema, the Director will refuse to start or will crash shortly after start with an error such as:

```
bareos-director: dird/dbdriver.cc:1234 Could not open Catalog "MyCatalog", DB Version mismatch
```

**How to protect yourself:**

1. **Pin images to digests in production.** Use `Label=io.containers.autoupdate=registry` only in staging/development where schema migrations are expected. In production, pin to a digest as shown above.

2. **Always review the Bareos release notes** before upgrading. Look for any mention of "catalog migration" or `update_bareos_tables`.

3. **If auto-update fires unexpectedly and the Director fails to start**, the recovery procedure is:

   ```bash
   # Step 1: Stop the Director
   sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
     systemctl --user stop bareos-director.service

   # Step 2: Check the Director logs for the schema version error
   sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
     journalctl --user -u bareos-director.service -n 50 --no-pager

   # Step 3: Run the catalog migration script inside the Director container
   # (this upgrades the DB schema to match the new image)
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
   ```

4. **Take a catalog backup before any upgrade.** The `BackupCatalog` job (see [Chapter 14](14-database-containers.md)) provides a dump you can restore from if migration fails. See [Chapter 20, Section 19](20-troubleshooting.md#19-auto-update-failures-catalog-schema-mismatch) for the full troubleshooting procedure.

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Logging: journalctl for Container Units

### How Container Logs Flow to the Journal

When Quadlet-managed containers run under systemd, their stdout and stderr are automatically captured by the systemd journal. This is because the generated `.service` unit uses the default `StandardOutput=journal` setting. Container logs appear in the journal just like any other service's logs.

### Basic Log Commands

```bash
# Follow logs for the Director in real time
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -f

# Show the last 100 lines
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -n 100

# Show logs since a specific time
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service --since "2026-02-24 09:00:00"

# Show logs with full metadata (useful for debugging)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -o verbose | head -50

# Show logs for ALL bareos units at once
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u "bareos-*.service" -f
```

### Journal Output Formats

The `-o` flag controls the output format:

| Format | Description |
|---|---|
| `short` (default) | Timestamp + hostname + unit + message |
| `json` | Full structured JSON, one object per line |
| `json-pretty` | Pretty-printed JSON |
| `verbose` | All journal fields |
| `cat` | Message text only (no metadata) |

```bash
# Export logs in JSON for ingestion by a log aggregator
journalctl --user -u bareos-director.service -o json --no-pager > /tmp/bareos-director.json
```

### Podman's Own Logging

Podman also writes its own operational logs (image pulls, container lifecycle events) to the journal under a different unit. Use:

```bash
# See Podman's own debug output
journalctl --user --identifier=podman -f
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Debugging Failed Unit Starts

### The Debugging Workflow

When a unit fails to start, work through this checklist:

**Step 1: Check unit status**

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status bareos-director.service
```

This shows: whether the unit is active/failed, the last few log lines, the ExecStart command, and any error codes.

**Step 2: Check the journal for the full error**

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -n 50 --no-pager
```

**Step 3: Check the Quadlet-generated unit file**

```bash
cat /run/user/1001/systemd/generator/bareos-director.service
```

Verify that the `podman run` command in `ExecStart=` has all expected flags (volumes, networks, env files). If a Volume= or Network= reference is wrong, Quadlet may silently drop it or generate an invalid command.

**Step 4: Run the container manually**

Copy the `ExecStart=` line from the generated unit file and run it manually as the `bareos` user. This isolates whether the problem is with the container itself or with systemd/Quadlet integration:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm -it docker.io/bareos/bareos-director:24 bash
```

**Step 5: Check for SELinux denials**

```bash
# Check for AVC denials in the last 60 seconds
ausearch -m avc -ts recent | grep bareos

# Or use audit2why for a human-readable explanation
ausearch -m avc -ts recent | audit2why
```

**Step 6: Check image availability**

```bash
# Verify the image has been pulled
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman images | grep bareos

# Pull manually if needed
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman pull docker.io/bareos/bareos-director:24
```

**Step 7: Verify dependency units are healthy**

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status bareos-db.service bareos-net-network.service
```

### Common Error Messages and Fixes

| Error | Likely cause | Fix |
|---|---|---|
| `Failed to create container: ...network not found` | Network not created yet | Start `bareos-net-network.service` first |
| `Error: crun: ... permission denied` | SELinux denial on volume | Apply `:Z` or `chcon` to volume path |
| `container_linux.go: ... operation not permitted` | Missing capability | Add `AddCapability=` to `[Container]` |
| `Failed to parse environment file` | Bad format in env file | Check for Windows line endings, export statements |
| `generator: error loading ...container: ...` | Syntax error in Quadlet file | Check INI syntax; run generator manually |

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Restart Policies

### `Restart=` Options

The `[Service]` section's `Restart=` directive tells systemd when to restart a container after it exits:

| Value | Meaning |
|---|---|
| `no` | Never restart (default if not specified) |
| `on-success` | Restart only if the container exits with code 0 |
| `on-failure` | Restart if the container exits with a non-zero code |
| `on-abnormal` | Restart on non-zero exit, signals, or watchdog timeout |
| `always` | Always restart, regardless of exit code |

For production Bareos daemons, use `Restart=on-failure`. This catches crashes and OOM kills but does not create restart loops if you intentionally stop a service with `systemctl --user stop`.

### `RestartSec=`

`RestartSec=` sets the delay between restart attempts. A value of `10s` or `15s` prevents tight restart loops that can flood the journal and consume CPU:

```ini
[Service]
Restart=on-failure
RestartSec=15s
```

### `StartLimitIntervalSec=` and `StartLimitBurst=`

systemd's default start limit is 5 starts in 10 seconds. If a unit fails this many times in the interval, systemd stops trying to restart it and marks it as "failed" permanently. You need `systemctl --user reset-failed bareos-director.service` to allow it to restart again.

For services that have long initialization periods (like database containers), relax this limit:

```ini
[Unit]
StartLimitIntervalSec=300
StartLimitBurst=5
```

This allows up to 5 restart attempts over 5 minutes before giving up.

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 12-1: Write the Full Quadlet Stack from Scratch

This lab guides you through creating all Quadlet files on a fresh RHEL 10 system and bringing up the full Bareos stack.

### Prerequisites

- RHEL 10 system with Podman 4.6+ installed
- `bareos` user with UID 1001
- `loginctl enable-linger bareos` already run
- Sufficient disk space at `/srv/bareos-storage/volumes`

### Step 1: Create the bareos user and set up directories

```bash
# Create the bareos system user (if not already done)
sudo useradd --system --uid 1001 --create-home --home-dir /home/bareos \
    --shell /sbin/nologin --comment "Bareos Backup Service Account" bareos

# Enable lingering so containers survive logout
sudo loginctl enable-linger bareos

# Verify linger is enabled
loginctl show-user bareos | grep Linger
# Expected: Linger=yes

# Create Quadlet directory
sudo -u bareos mkdir -p /home/bareos/.config/containers/systemd

# Create Bareos config directories
sudo -u bareos mkdir -p /home/bareos/bareos-config/{director,storage,filedaemon}

# Create the secrets directory with restricted permissions
sudo -u bareos install -d -m 700 /home/bareos/.config/bareos
```

### Step 2: Set up the storage path with correct SELinux type

```bash
# Create the storage directory
sudo mkdir -p /srv/bareos-storage/volumes

# Set ownership to bareos user
sudo chown bareos:bareos /srv/bareos-storage/volumes

# Apply the container_file_t SELinux type so containers can write here.
# In production you would define a custom bareos_store_t type via a
# policy module, but container_file_t works for this lab.
sudo semanage fcontext -a -t container_file_t "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -Rv /srv/bareos-storage/volumes

# Verify
ls -laZ /srv/bareos-storage/volumes
# Expected: system_u:object_r:container_file_t:s0
```

### Step 3: Create the env files

```bash
# Create db.env
sudo -u bareos tee /home/bareos/.config/bareos/db.env > /dev/null << 'EOF'
MARIADB_ROOT_PASSWORD=BareosProd2026Root!
MARIADB_DATABASE=bareos
MARIADB_USER=bareos
MARIADB_PASSWORD=BareosProd2026DB!
MARIADB_HOST=%
EOF

# Create bareos.env
sudo -u bareos tee /home/bareos/.config/bareos/bareos.env > /dev/null << 'EOF'
BAREOS_SD_PASSWORD=BareosProd2026SD!
BAREOS_FD_PASSWORD=BareosProd2026FD!
BAREOS_DIR_PASSWORD=BareosProd2026DIR!
BAREOS_DB_HOST=bareos-db
BAREOS_DB_NAME=bareos
BAREOS_DB_USER=bareos
EOF

# Secure the files
sudo chmod 600 /home/bareos/.config/bareos/db.env
sudo chmod 600 /home/bareos/.config/bareos/bareos.env
sudo chown bareos:bareos /home/bareos/.config/bareos/db.env
sudo chown bareos:bareos /home/bareos/.config/bareos/bareos.env

# Verify permissions
ls -la /home/bareos/.config/bareos/
```

### Step 4: Write all Quadlet files

Write each file from Section 6 into `/home/bareos/.config/containers/systemd/`. The complete list:

```bash
# List the files to create
ls /home/bareos/.config/containers/systemd/
# bareos-db.volume
# bareos-store.volume
# bareos-net.network
# bareos-db.container
# bareos-director.container
# bareos-storage.container
# bareos-fd.container
```

Set correct ownership:

```bash
sudo chown -R bareos:bareos /home/bareos/.config/containers/
ls -la /home/bareos/.config/containers/systemd/
```

### Step 5: Pre-pull images

Pulling images can take several minutes. Do it before starting services to avoid timeout issues:

```bash
for image in \
  docker.io/library/mariadb:10.11 \
  docker.io/bareos/bareos-director:24 \
  docker.io/bareos/bareos-storage:24 \
  docker.io/bareos/bareos-client:24; do
  sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman pull "$image"
done
```

### Step 6: Reload and enable services

```bash
# Reload the user daemon (triggers Quadlet generator)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload

# Verify that the generated service files exist
ls /run/user/1001/systemd/generator/bareos-*.service

# Enable and start the full stack
# Start in dependency order: volumes and network first, then DB, then Director
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now \
  bareos-db-volume.service \
  bareos-store-volume.service \
  bareos-net-network.service

sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now \
  bareos-db.service

# Wait for MariaDB to become healthy (up to 120 seconds)
for i in $(seq 1 24); do
  status=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
    podman inspect bareos-db --format '{{.State.Health.Status}}' 2>/dev/null)
  echo "Attempt $i: MariaDB health = $status"
  [ "$status" = "healthy" ] && break
  sleep 5
done

# Start the Director (it will wait for DB health automatically via Notify=healthy)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now \
  bareos-director.service

# Start Storage Daemon and File Daemon
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now \
  bareos-storage.service \
  bareos-fd.service
```

### Step 7: Verify the stack

```bash
# Check all service statuses
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status bareos-db.service bareos-director.service bareos-storage.service bareos-fd.service

# Check container health
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

# Run bconsole to verify Director connectivity
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec -it bareos-director bconsole -c /etc/bareos/bconsole.conf
# Type: version
# Expected: Bareos bareos-director 24.x.x ...
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 12-2: Simulate a Crash and Observe Auto-Restart

This lab demonstrates that `Restart=on-failure` works correctly and that systemd restarts the container after an unexpected exit.

### Step 1: Record the current container ID

```bash
# Get the container ID before the simulated crash
BEFORE_ID=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect bareos-director --format '{{.Id}}')
echo "Container ID before crash: $BEFORE_ID"
```

### Step 2: Simulate a crash

```bash
# Kill the main process inside the container with SIGKILL
# SIGKILL cannot be caught, so the process exits with code 137 (128 + 9)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman kill --signal SIGKILL bareos-director

# Immediately watch the journal for restart events
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-director.service -f &
JOURNAL_PID=$!
```

### Step 3: Observe the restart

```bash
# Wait for systemd to detect the exit and restart the container
# The RestartSec=15s in the unit file means a 15-second delay
sleep 20

# Check if the container is running again with a NEW container ID
AFTER_ID=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect bareos-director --format '{{.Id}}' 2>/dev/null)

if [ "$BEFORE_ID" != "$AFTER_ID" ] && [ -n "$AFTER_ID" ]; then
  echo "SUCCESS: Container was restarted (new ID: $AFTER_ID)"
else
  echo "PROBLEM: Container did not restart or has same ID"
fi

kill $JOURNAL_PID 2>/dev/null
```

### Step 4: Verify service status after restart

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status bareos-director.service

# Check restart count
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user show bareos-director.service --property=NRestarts
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 12-3: Enable podman auto-update and Pin an Image Digest

### Step 1: Enable the auto-update timer

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user enable --now podman-auto-update.timer

# Verify the timer is active
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status podman-auto-update.timer
```

### Step 2: Run auto-update manually and observe

```bash
# Run auto-update in dry-run mode first
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman auto-update --dry-run

# Expected output: lists containers with io.containers.autoupdate=registry
# and shows whether an update is available
```

### Step 3: Pin the Director to the current digest

```bash
# Get the current image digest
DIGEST=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect docker.io/bareos/bareos-director:24 \
  --format '{{index .RepoDigests 0}}')
echo "Current digest: $DIGEST"
# Output: docker.io/bareos/bareos-director@sha256:abcdef1234...

# Edit the .container file to use the pinned digest
# Replace: Image=docker.io/bareos/bareos-director:24
# With:    Image=<DIGEST from above>
```

Edit `/home/bareos/.config/containers/systemd/bareos-director.container` and update the `Image=` line. Then:

```bash
# Reload daemon to pick up the change
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload

# Restart the Director with the pinned image
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart bareos-director.service

# Run auto-update again — the pinned container should be skipped
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman auto-update --dry-run
# Expected: bareos-director shows "pinned" or is not listed
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Summary

In this chapter, you learned:

- **What Quadlet is** and why it replaced `podman generate systemd` as the standard way to run containers under systemd. Quadlet is declarative, version-controllable, and directly integrated into Podman 4.4+.

- **The four unit types**: `.container` (runs a container as a systemd service), `.volume` (creates named volumes), `.network` (creates isolated networks), and `.pod` (groups containers sharing a network namespace).

- **Lookup paths**: rootless Quadlet files live at `~/.config/containers/systemd/` and are processed by the `podman-user-generator` during `systemctl --user daemon-reload`.

- **Dependency ordering** using `After=`, `Requires=`, `BindsTo=`, and `Wants=` to ensure the MariaDB container is healthy before the Director starts.

- **The complete Bareos Quadlet stack**: six files (two volumes, one network, three containers) that define the entire backup infrastructure declaratively.

- **Environment files** at mode 600 for secrets management, separating sensitive credentials from unit files.

- **Health checks** using `HealthCmd=`, `HealthInterval=`, `HealthStartPeriod=`, and `Notify=healthy` to delay service activation until applications are genuinely ready.

- **Auto-update** using `io.containers.autoupdate=registry` and `podman auto-update`, with digest pinning for production stability.

- **Logging** via `journalctl --user -u <service>` and debugging failed units by inspecting generated unit files, SELinux denials, and running containers manually.

- **Restart policies** using `Restart=on-failure` and `RestartSec=` to make services self-healing.

The labs gave you hands-on experience building the stack from scratch, testing auto-restart after simulated crashes, and enabling and testing the auto-update pipeline.

In the next chapter, we will go deeper into the rootless Podman security model — specifically the UID and sub-UID mapping that makes rootless containers safe, and the operational nuances that every administrator must understand.

---

[↑ Back to Table of Contents](#table-of-contents)
