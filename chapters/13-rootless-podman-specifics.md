# Chapter 13: Rootless Podman — Security Model and Operational Nuances

## Table of Contents

- [1. What "Rootless" Means](#1-what-rootless-means)
  - [The Traditional Model: Root-Owned Containers](#the-traditional-model-root-owned-containers)
  - [The Rootless Model](#the-rootless-model)
  - [What Rootless Podman Cannot Do](#what-rootless-podman-cannot-do)
- [2. UID Mapping Deep Dive](#2-uid-mapping-deep-dive)
  - [The Problem: Namespaced UIDs](#the-problem-namespaced-uids)
  - [The /etc/subuid and /etc/subgid Files](#the-etcsubuid-and-etcsubgid-files)
  - [Verifying the Setup](#verifying-the-setup)
  - [How the Mapping Works Step by Step](#how-the-mapping-works-step-by-step)
  - [Numeric Example: bareos User (UID 1001)](#numeric-example-bareos-user-uid-1001)
  - [The Full Mapping Table for Reference](#the-full-mapping-table-for-reference)
- [3. Why Sub-UID Mapping Matters for Backups](#3-why-sub-uid-mapping-matters-for-backups)
  - [The Backup Problem](#the-backup-problem)
  - [Best Practice for Bareos Container Backups](#best-practice-for-bareos-container-backups)
  - [Files Owned by 100000+ on the Host](#files-owned-by-100000-on-the-host)
- [4. Reading /proc/self/uid_map](#4-reading-procselfuid_map)
  - [The File Format](#the-file-format)
  - [Reading the Map for a Running Container](#reading-the-map-for-a-running-container)
  - [Cross-Checking with the Running Process](#cross-checking-with-the-running-process)
  - [The GID Map](#the-gid-map)
- [5. Capabilities in Rootless Containers](#5-capabilities-in-rootless-containers)
  - [Linux Capabilities: A Quick Primer](#linux-capabilities-a-quick-primer)
  - [Capabilities in Rootless Containers](#capabilities-in-rootless-containers)
  - [Checking Container Capabilities](#checking-container-capabilities)
  - [Dropping Capabilities for Hardening](#dropping-capabilities-for-hardening)
  - [What a Rootless Container Absolutely Cannot Do](#what-a-rootless-container-absolutely-cannot-do)
- [6. Network Stack: pasta, slirp4netns, and Container Networking](#6-network-stack-pasta-slirp4netns-and-container-networking)
  - [Why Rootless Networking Is Different](#why-rootless-networking-is-different)
  - [pasta: The Modern Default](#pasta-the-modern-default)
  - [Port Binding: Only Above 1024](#port-binding-only-above-1024)
  - [Container-to-Container Networking in Rootless Mode](#container-to-container-networking-in-rootless-mode)
  - [slirp4netns: The Legacy Backend](#slirp4netns-the-legacy-backend)
- [7. The Podman Socket and DOCKER_HOST](#7-the-podman-socket-and-docker_host)
  - [The Podman Socket](#the-podman-socket)
  - [Using DOCKER_HOST to Point Tools at the User Socket](#using-docker_host-to-point-tools-at-the-user-socket)
  - [Security Implications of the Socket](#security-implications-of-the-socket)
- [8. XDG Paths: Runtime, Config, and Data Directories](#8-xdg-paths-runtime-config-and-data-directories)
  - [What Are XDG Paths?](#what-are-xdg-paths)
  - [XDG_RUNTIME_DIR in Detail](#xdg_runtime_dir-in-detail)
  - [XDG_DATA_HOME and Container Storage](#xdg_data_home-and-container-storage)
  - [Why XDG Paths Must Be Set Correctly](#why-xdg-paths-must-be-set-correctly)
- [9. Lingering: Containers That Survive Logout](#9-lingering-containers-that-survive-logout)
  - [The Problem Without Lingering](#the-problem-without-lingering)
  - [Enabling Lingering](#enabling-lingering)
  - [What Lingering Does](#what-lingering-does)
  - [Verifying Boot Behavior](#verifying-boot-behavior)
- [10. Running Commands as the bareos User from Root](#10-running-commands-as-the-bareos-user-from-root)
  - [Method 1: sudo -u bareos with Explicit XDG Variables](#method-1-sudo-u-bareos-with-explicit-xdg-variables)
  - [Method 2: machinectl shell](#method-2-machinectl-shell)
  - [Method 3: su -s /bin/bash bareos](#method-3-su-s-binbash-bareos)
  - [Useful One-Liners for Bareos Administration](#useful-one-liners-for-bareos-administration)
- [11. SELinux and Rootless Podman](#11-selinux-and-rootless-podman)
  - [SELinux Must Be Enforcing](#selinux-must-be-enforcing)
  - [Container Processes and SELinux Types](#container-processes-and-selinux-types)
  - [Volume Labeling: :z vs. :Z](#volume-labeling-z-vs-z)
  - [unconfined_u vs. system_u Contexts](#unconfined_u-vs-system_u-contexts)
  - [Diagnosing SELinux Denials](#diagnosing-selinux-denials)
- [12. Storage Backends: fuse-overlayfs vs. Native Overlay](#12-storage-backends-fuse-overlayfs-vs-native-overlay)
  - [What Is the Overlay Filesystem?](#what-is-the-overlay-filesystem)
  - [fuse-overlayfs: The Userspace Fallback](#fuse-overlayfs-the-userspace-fallback)
  - [Native Overlay with User Namespace Support](#native-overlay-with-user-namespace-support)
  - [Verifying the Backend in Use](#verifying-the-backend-in-use)
  - [The VFS Fallback](#the-vfs-fallback)
- [13. Resource Limits: Cgroups v2 and systemd User Slices](#13-resource-limits-cgroups-v2-and-systemd-user-slices)
  - [Cgroups v2 and Rootless Containers](#cgroups-v2-and-rootless-containers)
  - [Enabling Cgroup Delegation](#enabling-cgroup-delegation)
  - [systemd User Slice Limits](#systemd-user-slice-limits)
  - [Per-Container Resource Limits](#per-container-resource-limits)
  - [Checking Resource Usage](#checking-resource-usage)
- [14. Secrets Management Without Root](#14-secrets-management-without-root)
  - [The Problem with Secrets in Container Environments](#the-problem-with-secrets-in-container-environments)
  - [Approach 1: Mode-600 Environment Files (This Course's Approach)](#approach-1-mode-600-environment-files-this-courses-approach)
  - [Approach 2: Podman Secrets](#approach-2-podman-secrets)
  - [Approach 3: HashiCorp Vault (Advanced)](#approach-3-hashicorp-vault-advanced)
- [15. Common Rootless Pitfalls and Their Fixes](#15-common-rootless-pitfalls-and-their-fixes)
  - [Pitfall 1: "Permission denied" on Volume Mount](#pitfall-1-permission-denied-on-volume-mount)
  - [Pitfall 2: Containers Die on Logout](#pitfall-2-containers-die-on-logout)
  - [Pitfall 3: "cannot bind to address" on Port Below 1024](#pitfall-3-cannot-bind-to-address-on-port-below-1024)
  - [Pitfall 4: "Cannot find subuid/subgid for user"](#pitfall-4-cannot-find-subuidsubgid-for-user)
  - [Pitfall 5: AVC Denial for bareos-store Volume](#pitfall-5-avc-denial-for-bareos-store-volume)
  - [Pitfall 6: Quadlet Files Not Picked Up After daemon-reload](#pitfall-6-quadlet-files-not-picked-up-after-daemon-reload)
  - [Pitfall 7: Container Cannot Reach Other Containers by Name](#pitfall-7-container-cannot-reach-other-containers-by-name)
  - [Pitfall 8: Missing XDG_RUNTIME_DIR in Scripts](#pitfall-8-missing-xdg_runtime_dir-in-scripts)
- [Lab 13-1: Inspect UID Mapping for a Running Bareos Container](#lab-13-1-inspect-uid-mapping-for-a-running-bareos-container)
  - [Step 1: Start the Bareos stack (if not already running)](#step-1-start-the-bareos-stack-if-not-already-running)
  - [Step 2: Inspect UID mapping for the database container](#step-2-inspect-uid-mapping-for-the-database-container)
  - [Step 3: Find the UID of the MariaDB process](#step-3-find-the-uid-of-the-mariadb-process)
  - [Step 4: Verify on the host filesystem](#step-4-verify-on-the-host-filesystem)
  - [Step 5: Verify the host process listing](#step-5-verify-the-host-process-listing)
  - [Step 6: Examine the Director container mapping](#step-6-examine-the-director-container-mapping)
- [Lab 13-2: Diagnose and Fix a SELinux Denial for a Rootless Container Volume](#lab-13-2-diagnose-and-fix-a-selinux-denial-for-a-rootless-container-volume)
  - [Step 1: Create a host directory with incorrect SELinux context](#step-1-create-a-host-directory-with-incorrect-selinux-context)
  - [Step 2: Try to mount the directory into a container](#step-2-try-to-mount-the-directory-into-a-container)
  - [Step 3: Check for the AVC denial](#step-3-check-for-the-avc-denial)
  - [Step 4: Fix with :Z volume relabeling](#step-4-fix-with-z-volume-relabeling)
  - [Step 5: Verify the relabeled context](#step-5-verify-the-relabeled-context)
  - [Step 6: Apply a persistent fix for the bareos storage path](#step-6-apply-a-persistent-fix-for-the-bareos-storage-path)
- [Lab 13-3: Verify Lingering and Test Container Auto-Start After Reboot](#lab-13-3-verify-lingering-and-test-container-auto-start-after-reboot)
  - [Step 1: Confirm current state](#step-1-confirm-current-state)
  - [Step 2: Simulate a logout by killing the session](#step-2-simulate-a-logout-by-killing-the-session)
  - [Step 3: Reboot test (perform when maintenance window allows)](#step-3-reboot-test-perform-when-maintenance-window-allows)
  - [Step 4: Test what happens without lingering (informational — do not do this in production)](#step-4-test-what-happens-without-lingering-informational-do-not-do-this-in-production)
  - [Step 5: Add a boot verification script](#step-5-add-a-boot-verification-script)
- [Summary](#summary)

## 1. What "Rootless" Means

### The Traditional Model: Root-Owned Containers

In the traditional container model (early Docker, pre-2018), the container daemon ran as `root`. When you ran `docker run`, the Docker daemon (owned by root) created the container, set up namespaces, configured networking with kernel-level bridges and `iptables` rules, and started the container process. The container's filesystem was owned by root. The container's network interfaces were root-owned. All of this required root privilege.

This was convenient — root can do anything — but it created a serious security problem: **the attack surface of the entire host was exposed through the Docker socket**. If a container escaped its namespace (through a kernel vulnerability), it was already running as root and could access any file on the host, read kernel memory, load kernel modules, and own the system entirely.

### The Rootless Model

"Rootless" means that both the container *runtime* (the process that creates and manages containers) and the container *processes themselves* run without any root privileges. Specifically:

- The `podman` process runs as a normal unprivileged user (e.g., `bareos`, UID 1001).
- There is no daemon: Podman is a fork-exec model where each `podman run` spawns a container runtime (`crun` or `runc`) as a child of the `podman` process, inheriting the user's UID.
- Container isolation is achieved through Linux *user namespaces*, which allow a process to have a remapped set of UIDs/GIDs within an isolated namespace — without having those privileges on the host.
- Networking uses a user-space network stack (pasta or slirp4netns) instead of kernel-level bridge interfaces.
- SELinux policy further constrains what containers can do, even within their user namespace.

### What Rootless Podman Cannot Do

Rootless containers cannot:

- Bind to host ports below 1024 (these require `CAP_NET_BIND_SERVICE`, which is restricted to the initial user namespace). Bareos uses ports 9101, 9102, 9103 — all safely above 1024.
- Load kernel modules.
- Modify host network configuration.
- Access host devices (block devices, GPU, etc.) without explicit delegation.
- Write to host paths outside the user's home directory without explicit bind mounts and correct SELinux labels.

In exchange, if a container process escapes its namespace, it is still constrained to what the `bareos` user can do on the host — which is very little.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. UID Mapping Deep Dive

This is the most important concept to understand for rootless containers. Get this wrong, and you will spend hours debugging permission errors, backup failures, and mysterious "Operation not permitted" errors.

### The Problem: Namespaced UIDs

Linux processes are identified by a UID. When a process inside a container runs as UID 0 (root), it needs *some* privilege to manipulate its own files. But if that UID 0 maps directly to UID 0 on the host, the container has real root access.

User namespaces solve this by creating a *mapping* between UIDs inside the namespace (container UIDs) and UIDs outside the namespace (host UIDs). Inside the container, the process sees itself as UID 0. On the host, the kernel maps that UID 0 to a different, unprivileged UID — in our case, somewhere in the range 100000–165535.

### The /etc/subuid and /etc/subgid Files

These two files define which UIDs and GIDs each user is allowed to allocate as their "subordinate" IDs — the pool of host UIDs that the user can map into container namespaces.

#### `/etc/subuid`

```
# Format: username:start_uid:count
# This means: user 'bareos' owns a range of 65536 subordinate UIDs
# starting at 100000 and ending at 165535 (inclusive).
bareos:100000:65536
```

Each entry allocates a contiguous range. The count should be at least 65536 (2^16) to support a full UID namespace.

#### `/etc/subgid`

```
# Format: username:start_gid:count
bareos:100000:65536
```

Same format as subuid, but for group IDs.

### Verifying the Setup

```bash
# Check the bareos user's subordinate UID range
grep bareos /etc/subuid
# Expected: bareos:100000:65536

grep bareos /etc/subgid
# Expected: bareos:100000:65536

# If these lines are missing, add them:
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 bareos

# Verify with getsubids (Podman ships this utility)
getsubids bareos
# Expected: 0: bareos 100000 65536
```

### How the Mapping Works Step by Step

When the `bareos` user (host UID 1001) starts a rootless container, Podman calls `newuidmap` and `newgidmap` (setuid helpers) to configure the user namespace with the following mapping:

| Inside container (container UID) | Outside container (host UID) | Count |
|---|---|---|
| 0 | 1001 | 1 |
| 1 | 100000 | 65535 |

Let's unpack this table carefully:

**Row 1:** Container UID 0 (root inside the container) maps to host UID 1001 (the `bareos` user). This is a 1:1 mapping covering only one UID (the `bareos` user's own UID).

- If a file inside the container is owned by UID 0 (created by root inside the container), the kernel stores it on the host as owned by UID 1001 (bareos).
- This means the `bareos` user can read and write files created by the container's root process.

**Row 2:** Container UIDs 1 through 65535 map to host UIDs 100000 through 165535. This is a 65535:65535 range mapping.

- If a container process runs as UID 33 (the `www-data` user inside many containers), the kernel stores its files as host UID 100032 (= 100000 + 33 - 1).
- If a container process runs as UID 999 (common for application users like `mysql`, `postgres`), files are owned by host UID 100998 (= 100000 + 999 - 1).

### Numeric Example: bareos User (UID 1001)

Let us trace through the exact mappings for the MariaDB container. MariaDB runs its database processes as UID 999 inside the container (the `mysql` user in many Linux distributions).

```
Container UID 999
       ↓
Applies mapping row 2: container UID 1 → host UID 100000, count 65535
       ↓
host_uid = 100000 + (container_uid - 1)
         = 100000 + (999 - 1)
         = 100000 + 998
         = 100998
```

So the MariaDB data files written inside the container (owned by container UID 999) appear on the host filesystem as owned by host UID **100998**.

```bash
# Verify this on a running system
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-db id
# Output: uid=999(mysql) gid=999(mysql) groups=999(mysql)

# On the host, look at the volume's data directory
ls -la ~/.local/share/containers/storage/volumes/bareos-db/_data/
# Expected: files owned by 100998, not by mysql or bareos
```

Similarly, if the Bareos Director process inside its container runs as UID 0 (root):

```
Container UID 0
       ↓
Applies mapping row 1: container UID 0 → host UID 1001 (bareos), count 1
       ↓
host_uid = 1001
```

Files created by the Director's root process inside the container appear on the host as owned by `bareos` (UID 1001). This is intuitive and expected.

Now, if a container process runs as UID 1 (which is unusual but possible):

```
Container UID 1
       ↓
Applies mapping row 2: container UID 1 → host UID 100000, count 65535
       ↓
host_uid = 100000 + (1 - 1) = 100000
```

Files created by container UID 1 appear on the host as owned by UID 100000.

### The Full Mapping Table for Reference

| Container UID | Host UID | Notes |
|---|---|---|
| 0 | 1001 | Container root = bareos user on host |
| 1 | 100000 | Start of sub-UID range |
| 33 | 100032 | www-data inside container |
| 999 | 100998 | mysql/postgres service user inside container |
| 1000 | 100999 | First normal user inside container |
| 65535 | 165534 | End of mappable range |
| >65535 | unmapped | Cannot be created inside this namespace |

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Why Sub-UID Mapping Matters for Backups

### The Backup Problem

When Bareos backs up files, it records the ownership of each file (UID/GID) in the file catalog so that it can restore them with the correct ownership. But the UID numbers it sees depend on *from where* it observes the filesystem.

**Scenario 1: Backing up container data from inside the container**

If the Bareos File Daemon runs inside the same container namespace as the application it is backing up, it sees UIDs as the container sees them:
- MariaDB files owned by UID 999 (mysql inside container)
- The FD records ownership as UID 999 in the catalog
- On restore, Bareos sets ownership to UID 999 — which is mysql inside the container. This is correct.

**Scenario 2: Backing up container volume data from the host**

If the Bareos File Daemon runs on the *host* (or in a different container with host namespacing) and reads the volume data directly from the host path:
- MariaDB files appear owned by UID 100998 on the host
- The FD records ownership as UID 100998 in the catalog
- On restore to the same host, Bareos would try to `chown` files to UID 100998 — which may or may not be correct depending on the restore context

This is a subtle but critical issue. **Always be aware of which UID namespace you are in when doing backup operations.**

### Best Practice for Bareos Container Backups

Run the Bareos File Daemon **inside** the container namespace (using `podman exec` or as a co-located container on the same network) so that it sees the application's UIDs in the container's namespace. This ensures backup catalogs record the logically meaningful UIDs (e.g., 999 for mysql) rather than the host namespace UIDs (100998).

For backing up the host filesystem itself (not container data), run the FD on the host with its native UID perspective, or use the `bareos-fd` container with host path bind mounts and no user namespace remapping.

### Files Owned by 100000+ on the Host

After running a rootless Bareos stack, you may notice files with UIDs in the 100000–165535 range:

```bash
# List files with unusual UIDs in the volume storage
ls -laZ ~/.local/share/containers/storage/volumes/bareos-db/_data/ | head -20
# You will see entries like:
# -rw-r----- 1 100998 100998 ... ibdata1
# drwxr-xr-x 2 100998 100998 ... bareos/
```

This is normal and expected. Do not `chown` these files to fix "permission errors" — doing so would break the UID mapping and corrupt the container's view of its own files. The kernel's user namespace mapping handles the translation transparently.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Reading /proc/self/uid_map

The kernel exposes the active UID mapping for each process in a pseudo-file at `/proc/<pid>/uid_map`. Reading this file lets you verify exactly how UIDs are mapped for any container process.

### The File Format

Each line in `/proc/<pid>/uid_map` contains three numbers:

```
<start_in_ns> <start_on_host> <count>
```

- `start_in_ns`: The first UID *inside* the user namespace (container-side UID)
- `start_on_host`: The first UID *outside* the user namespace (host-side UID) that corresponds to `start_in_ns`
- `count`: How many consecutive UIDs this entry covers

### Reading the Map for a Running Container

```bash
# Get the PID of the bareos-db container's main process
CONTAINER_PID=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect bareos-db --format '{{.State.Pid}}')
echo "Container main PID: $CONTAINER_PID"

# Read the UID map for that process
cat /proc/$CONTAINER_PID/uid_map
```

Expected output (two lines):

```
         0       1001          1
         1     100000      65535
```

Interpreting this output:

**Line 1:** `0  1001  1`
- Container UID 0 (root inside the container) corresponds to host UID 1001 (bareos).
- Only 1 UID is in this mapping entry.

**Line 2:** `1  100000  65535`
- Container UID 1 corresponds to host UID 100000.
- 65535 UIDs are mapped in this entry (container UIDs 1–65535 → host UIDs 100000–165534).

### Cross-Checking with the Running Process

```bash
# Check the UID of the main process inside the container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-db id
# Output (example): uid=999(mysql) gid=999(mysql)

# Check the same process from the host perspective
# The host sees it as UID 100998 (100000 + 999 - 1)
ps aux | grep "mysql" | head -5
# USER field should show the numeric UID 100998 or the sub-UID username
```

### The GID Map

An identical mapping exists for group IDs:

```bash
# Read the GID map
cat /proc/$CONTAINER_PID/gid_map
# Output:
#          0       1001          1
#          1     100000      65535
```

The GID mapping follows exactly the same pattern as the UID mapping, using the `/etc/subgid` allocation.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Capabilities in Rootless Containers

### Linux Capabilities: A Quick Primer

Traditional Unix has a binary privilege model: either you are root (omnipotent) or you are not. Linux capabilities break root's powers into fine-grained units. Each capability allows a specific set of privileged operations. A process can be granted individual capabilities without being fully root.

Examples of capabilities relevant to containers:

| Capability | What it allows |
|---|---|
| `CAP_NET_BIND_SERVICE` | Bind to ports below 1024 |
| `CAP_SYS_ADMIN` | Mount filesystems, namespace operations |
| `CAP_CHOWN` | Change file ownership |
| `CAP_DAC_OVERRIDE` | Bypass file read/write/execute permission checks |
| `CAP_SETUID` | Set arbitrary UIDs |
| `CAP_NET_ADMIN` | Configure network interfaces |
| `CAP_SYS_PTRACE` | Trace/debug other processes |

### Capabilities in Rootless Containers

A rootless container has capabilities, but they are **capabilities within the container's user namespace**. This is a critical distinction:

- Inside the container, the process may have `CAP_SYS_ADMIN` (allowing it to, say, mount filesystems inside the container).
- But from the host's perspective, the process is running as UID 1001 (bareos) with no special host privileges.
- The kernel enforces that user-namespace capabilities cannot be used to affect the host outside the namespace.

By default, Podman grants rootless containers a set of "safe" capabilities defined in `/etc/containers/containers.conf`. These include `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_FOWNER`, `CAP_FSETID`, `CAP_KILL`, `CAP_NET_BIND_SERVICE`, and a few others.

### Checking Container Capabilities

```bash
# Check the capabilities of the Bareos Director container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect bareos-director --format '{{.HostConfig.CapAdd}} / {{.HostConfig.CapDrop}}'

# Or from inside the container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director capsh --print
```

### Dropping Capabilities for Hardening

Bareos daemons do not need many capabilities. For production hardening, explicitly drop all capabilities and add back only what is needed:

```ini
# In bareos-director.container [Container] section:
# Drop everything, then add only what Bareos needs.
DropCapability=all
AddCapability=CAP_SETUID
AddCapability=CAP_SETGID
AddCapability=CAP_NET_BIND_SERVICE
```

Be conservative. Test in staging before applying to production, as missing capabilities will cause the container to fail with "Operation not permitted" errors.

### What a Rootless Container Absolutely Cannot Do

Regardless of capability configuration:

- **It cannot modify the host network.** No adding routes, no modifying iptables on the host, no binding to host interfaces directly.
- **It cannot load kernel modules** (`insmod`, `modprobe`).
- **It cannot change the system time** (no `CAP_SYS_TIME` in the host namespace).
- **It cannot read other users' memory** (no cross-user ptrace).
- **It cannot access raw disk devices** without explicit device delegation.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Network Stack: pasta, slirp4netns, and Container Networking

### Why Rootless Networking Is Different

Rootful containers use kernel-level networking: bridge interfaces, virtual Ethernet pairs (veth), and `iptables`/`nftables` NAT rules. Creating these structures requires root privilege (specifically `CAP_NET_ADMIN` in the initial user namespace).

Rootless containers cannot create kernel network interfaces. Instead, they use a *user-space network stack* that simulates networking entirely in user-space processes.

### pasta: The Modern Default

Since Podman 4.0+ and RHEL 10, the default user-space network backend for rootless containers is **pasta** (the "Pasta network stack"). Pasta is a successor to slirp4netns with better performance and a simpler architecture.

How pasta works:
1. When a rootless container starts, Podman forks a `pasta` process.
2. `pasta` creates a tap interface inside the container's network namespace.
3. `pasta` runs in the host's network namespace and forwards packets between the container's tap interface and the host's real network stack.
4. From the container's perspective, it has a normal network interface with an IP address. All traffic is forwarded through `pasta`.

The performance overhead of pasta is small for typical backup workloads (a few percent CPU for packet forwarding), but it is measurably higher than kernel-level networking for high-throughput scenarios.

### Port Binding: Only Above 1024

Because rootless containers use pasta for networking, they can bind to *any* port inside the container. However, to *publish* that port to the host (making it accessible from outside), the host-side port must be above 1024.

**This is not a problem for Bareos:**
- Port 9101 (Director): host port > 1024 ✓
- Port 9102 (File Daemon): host port > 1024 ✓
- Port 9103 (Storage Daemon): host port > 1024 ✓

If you needed a port below 1024 (e.g., port 443 for HTTPS), you would need to either:
- Use a port above 1024 and set up a redirect with firewalld.
- Set the `net.ipv4.ip_unprivileged_port_start` sysctl to a lower value: `sysctl -w net.ipv4.ip_unprivileged_port_start=443`.

### Container-to-Container Networking in Rootless Mode

When multiple rootless containers are connected to the same Podman network (as our Bareos containers are on `bareos-net`), they communicate *through pasta* using the user-space stack. Each container gets its own IP address on the network's subnet (10.89.1.0/24 in our case), and the embedded `aardvark-dns` service resolves container names.

Packets between containers on the same rootless network flow through pasta, not through a kernel bridge. This means:

1. Two containers talking to each other on `bareos-net` go: container A → pasta → container B. This is faster than going out to the host network and back, but slower than a kernel bridge.

2. For Bareos's typical workload (metadata queries from Director to MariaDB, job coordination), this performance difference is negligible.

```bash
# Verify containers can reach each other by name
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director ping -c 3 bareos-db

# Check the IP addresses assigned on bareos-net
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman network inspect bareos-net \
  --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
```

### slirp4netns: The Legacy Backend

`slirp4netns` is the predecessor to pasta. It is still available and can be selected explicitly, but pasta is preferred for new deployments. You may encounter references to slirp4netns in older documentation and tutorials. On RHEL 10, the default is pasta.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. The Podman Socket and DOCKER_HOST

### The Podman Socket

Like Docker, Podman can expose a Unix socket that accepts Docker-compatible API requests. Unlike Docker, the Podman socket is per-user (not a system-wide daemon socket), which aligns with the rootless model.

For the `bareos` user, the socket lives at:

```
/run/user/1001/podman/podman.sock
```

The socket is served by a systemd socket-activated service:

```bash
# Enable the user-level Podman socket
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user enable --now podman.socket

# Verify the socket exists
ls -la /run/user/1001/podman/podman.sock

# Test the socket with curl
curl --unix-socket /run/user/1001/podman/podman.sock \
  http://localhost/v4.0/libpod/info
```

### Using DOCKER_HOST to Point Tools at the User Socket

Many tools that work with containers (Compose, monitoring tools, CI systems) use the `DOCKER_HOST` environment variable to find the container API. You can point them at the Podman user socket:

```bash
export DOCKER_HOST=unix:///run/user/1001/podman/podman.sock

# Now docker-compatible tools work without Docker installed
docker ps        # Actually calls Podman via the socket
docker images    # Same
```

This is particularly useful if you want to use `docker-compose` (or `podman-compose`) with the rootless Bareos stack during development.

### Security Implications of the Socket

The Podman user socket is only accessible to the user who owns it (and root). The socket file's permissions:

```bash
ls -la /run/user/1001/podman/podman.sock
# srwxrwxrwx. 1 bareos bareos ... /run/user/1001/podman/podman.sock
```

Although the socket shows world-readable/writable permissions, the `/run/user/1001/` directory itself is mode 700, owned by `bareos`. Other users cannot traverse into this directory to reach the socket. Only the `bareos` user and `root` can access the socket.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. XDG Paths: Runtime, Config, and Data Directories

### What Are XDG Paths?

XDG stands for *X Desktop Group* (now the freedesktop.org organization), which defined a standard for where applications should store their files on Linux. While originally intended for desktop applications, these standards are also followed by Podman and systemd user services.

The three relevant XDG variables are:

| Variable | Default value for bareos (UID 1001) | Purpose |
|---|---|---|
| `XDG_RUNTIME_DIR` | `/run/user/1001` | Temporary runtime files (sockets, locks, ephemeral data) |
| `XDG_CONFIG_HOME` | `/home/bareos/.config` | Application configuration |
| `XDG_DATA_HOME` | `/home/bareos/.local/share` | Application data (container images, volumes) |

### XDG_RUNTIME_DIR in Detail

`XDG_RUNTIME_DIR` is the most operationally important variable. Podman uses it for:

- **The Podman socket:** `/run/user/1001/podman/podman.sock`
- **Container lock files:** `/run/user/1001/containers/`
- **systemd socket communication:** `/run/user/1001/systemd/`

**Critical:** `XDG_RUNTIME_DIR` is set automatically when a user logs in interactively (via SSH or console). However, when you switch to the `bareos` user using `sudo -u bareos` or `su - bareos`, the variable is often *not* set unless you explicitly provide it. This is why every `sudo -u bareos` command in this course includes `XDG_RUNTIME_DIR=/run/user/1001`.

```bash
# Wrong - XDG_RUNTIME_DIR is not set
sudo -u bareos podman ps
# Error: could not get runtime directory

# Correct - explicitly provide the runtime dir
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps
```

### XDG_DATA_HOME and Container Storage

Podman stores all container images, layers, and named volumes under `XDG_DATA_HOME`:

```
/home/bareos/.local/share/containers/storage/
├── overlay/              # Container image layers (overlay filesystem)
│   ├── images/           # Image manifests and metadata
│   └── <layer-id>/       # Individual overlay layers
└── volumes/              # Named volume data
    ├── bareos-db/
    │   └── _data/        # MariaDB data files
    └── bareos-store/
        └── _data/        # Backup archives (bind mount)
```

Understanding this path structure is essential for:
- Locating backup data for disaster recovery.
- Estimating disk usage (`du -sh /home/bareos/.local/share/containers/storage/`).
- Cleaning up stale images and containers.

### Why XDG Paths Must Be Set Correctly

When the `bareos` user's systemd instance starts a Quadlet-managed container, systemd sets `XDG_RUNTIME_DIR` automatically (because it is the user's systemd instance). But in scripts, cron jobs, or SSH sessions, you must set it manually.

A useful pattern for scripts that manage Bareos containers:

```bash
#!/bin/bash
# /usr/local/bin/bareos-admin.sh
# Helper script for administering the Bareos container stack.
# Can be run by root or the bareos user.

export XDG_RUNTIME_DIR=/run/user/1001
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus

# Now run commands as bareos
sudo -u bareos -E podman ps
sudo -u bareos -E systemctl --user status bareos-director.service
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Lingering: Containers That Survive Logout

### The Problem Without Lingering

Linux's login system (PAM and systemd) manages per-user session resources. When you log in, systemd creates a "user slice" with a `systemd --user` instance for you. When you log out (the last session closes), systemd tears down the user slice — including all user-owned processes. This means that if the `bareos` user is not currently logged in, any containers started by the `bareos` user would be killed.

For a backup server, the `bareos` user is a system account that is *never* interactively logged in. Without lingering, the Bareos containers would never start at boot (because there is no login session to create the user slice) and would be killed any time an administrator's `sudo -u bareos` session ends.

### Enabling Lingering

Lingering tells systemd to keep the user's `systemd --user` instance alive even when no interactive session is open:

```bash
# Enable lingering for the bareos user (run as root)
loginctl enable-linger bareos

# Verify
loginctl show-user bareos | grep Linger
# Expected: Linger=yes

# Also view the linger file directly
ls /var/lib/systemd/linger/
# Expected: bareos  (a file with the bareos username exists)
```

### What Lingering Does

With lingering enabled:

1. When the system boots, systemd starts the `bareos` user's `systemd --user` instance automatically (even before any login).
2. All units with `WantedBy=default.target` in the `[Install]` section are started at boot.
3. When an administrator's `sudo -u bareos` session ends, the user slice *stays alive*.
4. The containers keep running until explicitly stopped or the system shuts down.

Without lingering:

1. At boot, no user-space containers start (the user slice does not exist).
2. The only way to start containers is to `sudo -u bareos` and start them manually — but they die as soon as the session ends.
3. The system is not a viable backup server.

### Verifying Boot Behavior

```bash
# Check whether the bareos user slice is active
systemctl status user@1001.service

# Expected output when lingering is enabled and containers are running:
# ● user@1001.service - User Manager for UID 1001
#    Loaded: loaded (/usr/lib/systemd/system/user@.service; ...)
#    Active: active (running) since ...
#    Tasks: 45 (limit: 2048)
#    ...
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Running Commands as the bareos User from Root

In production, the `bareos` user is a system account with no password and no interactive login shell. Administrators must use one of two approaches to run commands in the bareos user's context.

### Method 1: sudo -u bareos with Explicit XDG Variables

```bash
# Run a single Podman command as bareos
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps

# Run a systemctl --user command as bareos
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user status bareos-director.service

# Run an interactive shell as bareos (for debugging sessions)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1001/bus bash
```

The `-u bareos` flag switches to the bareos user. The `XDG_RUNTIME_DIR=` variable must be explicitly provided because `sudo` does not normally inherit the target user's environment variables (it starts a clean environment).

### Method 2: machinectl shell

`machinectl shell` is a cleaner way to get a fully-initialized session as another user. Unlike `sudo -u`, it sets up the complete PAM session including all XDG variables, the DBus session bus, and the user's environment:

```bash
# Start a full interactive session as bareos
machinectl shell bareos@

# Inside the bareos shell, all variables are set correctly
echo $XDG_RUNTIME_DIR    # /run/user/1001
echo $DBUS_SESSION_BUS_ADDRESS  # unix:path=/run/user/1001/bus
podman ps                 # Works without extra variables
systemctl --user status   # Works correctly
```

`machinectl shell` is the recommended approach for interactive debugging sessions. Use `sudo -u bareos XDG_RUNTIME_DIR=...` for non-interactive scripted commands.

### Method 3: su -s /bin/bash bareos

If `machinectl` is not available (unusual on RHEL 10):

```bash
su -s /bin/bash - bareos
```

The `-` flag sources the user's profile, which may set `XDG_RUNTIME_DIR` if the bareos user's `.bash_profile` is configured correctly. However, this is less reliable than `machinectl shell`.

### Useful One-Liners for Bareos Administration

```bash
# View all running bareos containers
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps --filter label=app=bareos

# Restart the entire Bareos stack
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user restart bareos-db.service bareos-director.service bareos-storage.service bareos-fd.service

# Show disk usage of all bareos volumes
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume ls --filter label=app=bareos --format "{{.Name}}" | \
  xargs -I{} sh -c 'echo "Volume: {}"; du -sh ~/.local/share/containers/storage/volumes/{}/_data/'

# Enter the Director container for interactive debugging
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec -it bareos-director bash

# Run bconsole
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec -it bareos-director bconsole
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. SELinux and Rootless Podman

### SELinux Must Be Enforcing

RHEL 10 ships with SELinux in enforcing mode by default, and it must remain that way for Bareos in production. SELinux enforcing provides an independent layer of access control that limits what a compromised container can do, even if it escapes its user namespace.

```bash
# Always verify SELinux is enforcing
getenforce
# Expected: Enforcing

# Never set permissive for production troubleshooting —
# use audit2why to understand denials without disabling SELinux
```

### Container Processes and SELinux Types

Each container process runs under a specific SELinux type (the third component of the SELinux security context, e.g., `system_u:system_r:container_t:s0:c123,c456`).

For rootless containers on RHEL 10:

- Container processes run under the `container_t` type (the main container process type).
- They are assigned a unique *Multi-Category Security* (MCS) label (e.g., `s0:c123,c456`) when the container starts. This label is randomly generated and unique per container.
- Two containers with different MCS labels cannot access each other's files, even if the file permissions would otherwise allow it. SELinux denies the access at the kernel level.

```bash
# See the SELinux context of processes inside a running container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director ps -efZ | head -10
# Output includes: system_u:system_r:container_t:s0:c234,c567

# See the SELinux context from the host
ps -efZ | grep bareos-director | head -5
```

### Volume Labeling: :z vs. :Z

When you bind-mount a host directory into a container, SELinux may block the container from reading or writing it because the host directory's label does not match what container processes are allowed to access.

The solution is to relabel the mount target. Podman provides two options:

#### `:z` (shared label, lowercase z)

Relabels the directory and all its contents with a *shared* MCS label (`s0`). This means **all containers** that use `:z` on the same path can access it. The label applied is `system_u:object_r:container_file_t:s0`.

Use `:z` when multiple containers need to share the same data.

```ini
Volume=bareos-db.volume:/var/lib/mysql:z
```

**Warning:** `:z` changes the SELinux label permanently on the host path. If you later mount the same directory without `:z`, the host process may not be able to access it until you relabel it with `restorecon`.

#### `:Z` (private label, uppercase Z)

Relabels the directory with the *container's specific* MCS label. Only this container can access the relabeled files. The label applied is `system_u:object_r:container_file_t:s0:c123,c456` (the container's unique MCS pair).

Use `:Z` when only one container accesses this data (the usual case for per-container config directories and database volumes).

```ini
Volume=/home/bareos/bareos-config/director:/etc/bareos:Z
```

#### When Not to Use :z or :Z

Do not use `:z` or `:Z` on:

- System directories that need their original SELinux labels for host processes (e.g., `/etc`, `/var/log`)
- Directories shared between containers *and* host processes — the relabeling will break host access

For these cases, pre-label the directory with `chcon` or `semanage fcontext` and `restorecon`:

```bash
# Apply container_file_t to the storage directory
sudo semanage fcontext -a -t container_file_t "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -Rv /srv/bareos-storage/volumes

# Now the directory is accessible to containers without :Z relabeling
# (though :Z would also work, it would override this label with the container's MCS label)
```

### unconfined_u vs. system_u Contexts

Files created by the `bareos` user on the host have the context `unconfined_u:object_r:<type>:s0`. Files managed by system services typically have `system_u:object_r:<type>:s0`.

The container runtime expects `container_file_t` as the type for files that containers access. The user and role components (`unconfined_u` vs `system_u`) typically do not matter for container access decisions — it is the type component that SELinux policy checks.

```bash
# Check the SELinux context of the Quadlet directory
ls -laZ /home/bareos/.config/containers/systemd/
# Expected: unconfined_u:object_r:container_config_t:s0 (or similar)

# Check the SELinux context of the storage volume
ls -laZ /srv/bareos-storage/volumes/
# Expected: system_u:object_r:container_file_t:s0
```

### Diagnosing SELinux Denials

```bash
# View all recent AVC (access vector cache) denials
ausearch -m avc -ts recent

# Get a human-readable explanation
ausearch -m avc -ts recent | audit2why

# Generate a policy module to allow the denied operation
# (useful for understanding, not for blind application to production)
ausearch -m avc -ts recent | audit2allow -M bareos-local
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Storage Backends: fuse-overlayfs vs. Native Overlay

### What Is the Overlay Filesystem?

Container images consist of layers. Each layer represents a set of file changes (additions, modifications, deletions) on top of the previous layer. When a container is created, these layers are stacked together using an *overlay filesystem* — a Linux kernel feature that presents multiple directories as a single unified view, without copying any data.

For rootless containers, the overlay implementation matters because unprivileged processes cannot use the kernel's native `overlayfs` mount system call without specific kernel capabilities.

### fuse-overlayfs: The Userspace Fallback

`fuse-overlayfs` implements the overlay filesystem in user space using FUSE (Filesystem in Userspace). It does not require special kernel privileges — any user can use it. This was the default for rootless containers on older kernels (pre-5.12).

> **RHEL 10 note:** On RHEL 10 (kernel 6.x), `fuse-overlayfs` is a fallback only. RHEL 10's kernel fully supports native unprivileged overlayfs, so `fuse-overlayfs` is not needed or used under normal circumstances. You may encounter references to `fuse-overlayfs` in older documentation, RHEL 8/9 guides, or when running rootless containers on a non-RHEL kernel below 5.11. For RHEL 10, expect and verify `overlay` (native), not `fuse-overlayfs`.

Characteristics:
- **Universally available**: Works on any kernel that supports FUSE.
- **Slower**: Every filesystem operation goes through a FUSE daemon process, adding context switch overhead.
- **Compatible**: Works with all container workloads.

### Native Overlay with User Namespace Support

Starting with Linux kernel 5.11 (backported to RHEL 9 and 10 kernels), the kernel supports unprivileged `overlayfs` mounts when the process is inside a user namespace. This is called "native overlay" or "overlayfs in user namespaces."

With this kernel support, Podman can use the kernel's overlayfs directly without FUSE, even for rootless containers.

Characteristics:
- **Faster**: Direct kernel filesystem operations, no FUSE overhead.
- **Default on RHEL 10**: The RHEL 10 kernel supports unprivileged overlayfs.
- **Same semantics**: Same overlay behavior as the FUSE version.

### Verifying the Backend in Use

```bash
# Check which storage driver Podman is using
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman info | grep -A3 "graphDriverName"
# Expected on RHEL 10: overlay (not vfs or fuse-overlayfs)

# Check the full storage configuration
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman info --format json | \
  python3 -m json.tool | grep -A10 '"store"'
```

### The VFS Fallback

If neither native overlay nor fuse-overlayfs is available, Podman falls back to the `vfs` driver, which copies every layer completely instead of using overlay semantics. This is extremely slow and space-inefficient. You should never see `vfs` on a properly configured RHEL 10 system.

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Resource Limits: Cgroups v2 and systemd User Slices

### Cgroups v2 and Rootless Containers

Linux control groups (cgroups) limit the resources (CPU, memory, I/O) available to a process or group of processes. Cgroups v2 is the modern unified hierarchy, and RHEL 9 and 10 use cgroups v2 exclusively.

For rootless containers to use cgroup-based resource limits (setting memory limits, CPU quotas, etc. on containers), the kernel must *delegate* cgroup management to the user's unprivileged processes. This delegation is configured in systemd.

### Enabling Cgroup Delegation

On RHEL 10 with systemd 252+, cgroup delegation for user services is enabled by default. You can verify:

```bash
# Check the cgroup delegation setting for user services
cat /sys/fs/cgroup/user.slice/user-1001.slice/cgroup.controllers
# Expected to include: cpuset cpu io memory pids

# If empty or missing controllers, enable delegation
sudo mkdir -p /etc/systemd/system/user@.service.d/
sudo tee /etc/systemd/system/user@.service.d/delegate.conf > /dev/null << 'EOF'
[Service]
Delegate=yes
EOF
sudo systemctl daemon-reload
```

### systemd User Slice Limits

The `bareos` user's processes run inside a systemd user slice: `user.slice/user-1001.slice/`. You can set resource limits on this slice to prevent Bareos containers from consuming all system resources.

```bash
# Set memory limit for the bareos user slice (4GB total)
sudo mkdir -p /etc/systemd/system/user-1001.slice.d/
sudo tee /etc/systemd/system/user-1001.slice.d/limits.conf > /dev/null << 'EOF'
[Slice]
MemoryMax=4G
CPUQuota=200%
TasksMax=1024
EOF

sudo systemctl daemon-reload

# Verify the limits are applied
systemctl show user-1001.slice --property=MemoryMax,CPUQuota
```

### Per-Container Resource Limits

Resource limits can also be set per-container in Quadlet files:

```ini
# In bareos-db.container [Container] section:
# Limit MariaDB to 1GB of memory and 1 CPU core
PodmanArgs=--memory=1g --cpus=1.0
```

Or in the `[Service]` section for systemd-level limits:

```ini
[Service]
# Limit the number of open file descriptors (important for databases)
LimitNOFILE=65536
# Limit the number of processes/threads
LimitNPROC=4096
```

### Checking Resource Usage

```bash
# View real-time resource usage for all bareos containers
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman stats --no-stream \
  --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# View cgroup stats for the bareos user slice
systemd-cgtop user-1001.slice
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Secrets Management Without Root

### The Problem with Secrets in Container Environments

Secrets (passwords, API keys, TLS certificates) must be injected into containers without:
- Hard-coding them in container images (they would be visible in `podman history`).
- Putting them in Quadlet files committed to git.
- Making them readable by other users or processes.

### Approach 1: Mode-600 Environment Files (This Course's Approach)

The simplest and most portable approach: store secrets in files with restrictive permissions, owned by the container-running user.

```bash
# The db.env file from earlier in this course
ls -la /home/bareos/.config/bareos/db.env
# -rw------- 1 bareos bareos 256 Feb 24 10:00 db.env

# The file is read by the container via EnvironmentFile= in the Quadlet unit
# The container inherits the environment variables at startup
# The variables are accessible inside the container as normal env vars
```

**Advantages:**
- Simple. No external tools required.
- Mode-600 means only the `bareos` user (and root) can read it.
- Easy to rotate: update the file and restart the service.

**Disadvantages:**
- The secret is in a plain text file on disk.
- Root can always read it.
- No audit trail for secret access.

### Approach 2: Podman Secrets

Podman has a built-in secrets manager that stores secrets in an encrypted form under `~/.local/share/containers/storage/secrets/`:

```bash
# Create a Podman secret from a value
printf 'BareosProd2026DB!' | \
  sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman secret create bareos-db-password -

# List secrets
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman secret ls

# Reference the secret in a Quadlet file
# In [Container] section:
# Secret=bareos-db-password,type=env,target=MARIADB_PASSWORD
```

The secret is mounted into the container either as a file at `/run/secrets/<name>` or as an environment variable (using `type=env`).

**Advantages:**
- Secrets are not in plain text files.
- The secret value is stored in Podman's secrets store (encrypted at rest if a GPG key is configured).
- Rotation is possible without rewriting files.

**Disadvantages:**
- The encryption key is derived from the user's login credentials — if root can access the bareos home directory, it can also read the secrets store.
- Less portable (tools other than Podman cannot read these secrets).

### Approach 3: HashiCorp Vault (Advanced)

For enterprise environments, HashiCorp Vault provides a proper secrets manager with:
- Role-based access control for who can read which secrets.
- Full audit logging of every secret access.
- Dynamic secrets (short-lived credentials generated on demand).
- Integration with Kubernetes, cloud providers, and more.

A full Vault integration is beyond the scope of this course, but the pattern is:
1. A startup script (or init container) requests a secret from Vault using the container's identity.
2. The script writes the secret to a tmpfs mount inside the container.
3. The application reads the secret from the tmpfs.
4. The secret is never stored on the host disk.

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Common Rootless Pitfalls and Their Fixes

### Pitfall 1: "Permission denied" on Volume Mount

**Symptom:** Container fails to start with: `Error: crun: mount /home/bareos/data:/app/data: permission denied: OCI permission denied`

**Root Cause:** The host directory being mounted into the container has an SELinux label that container processes cannot access (e.g., `unconfined_u:object_r:user_home_t:s0` instead of `container_file_t`).

**Fix:**

```bash
# Option 1: Add :Z to the Volume= directive in the Quadlet file
# Volume=/home/bareos/data:/app/data:Z
# This relabels the directory with the container's MCS label.

# Option 2: Pre-label the directory with semanage
sudo semanage fcontext -a -t container_file_t "/home/bareos/data(/.*)?"
sudo restorecon -Rv /home/bareos/data
```

### Pitfall 2: Containers Die on Logout

**Symptom:** Bareos containers stop running after you log out of the `bareos` user session.

**Root Cause:** Lingering is not enabled. When the last session for the `bareos` user closes, systemd kills the user slice and all processes in it.

**Fix:**

```bash
sudo loginctl enable-linger bareos
loginctl show-user bareos | grep Linger
# Expected: Linger=yes
```

### Pitfall 3: "cannot bind to address" on Port Below 1024

**Symptom:** Container fails with: `Error: listen tcp 0.0.0.0:80: bind: permission denied`

**Root Cause:** Rootless containers cannot publish ports below 1024 by default.

**Fix:**

```bash
# Option 1: Use a port above 1024
# PublishPort=8080:80   instead of PublishPort=80:80

# Option 2: Lower the unprivileged port start threshold (system-wide change)
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
# Make it permanent:
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-rootless-ports.conf
sudo sysctl --system
```

For Bareos, all ports are above 1024, so this pitfall does not apply.

### Pitfall 4: "Cannot find subuid/subgid for user"

**Symptom:** `podman run` fails with: `Error: could not find available subuids for user bareos in /etc/subuid`

**Root Cause:** The `bareos` user does not have a subordinate UID range allocated in `/etc/subuid`.

**Fix:**

```bash
# Add the sub-UID range
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 bareos

# Verify
grep bareos /etc/subuid /etc/subgid

# Restart the user session context
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman system migrate
```

### Pitfall 5: AVC Denial for bareos-store Volume

**Symptom:** Bareos Storage Daemon cannot write backup archives, journal shows SELinux AVC denial.

**Root Cause:** `/srv/bareos-storage/volumes` has the wrong SELinux type.

**Fix:**

```bash
# Check the current type
ls -laZ /srv/bareos-storage/volumes/
# If you see var_t, home_root_t, or unlabeled_t — that's the problem.

# Fix: Apply container_file_t
sudo semanage fcontext -a -t container_file_t "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -Rv /srv/bareos-storage/volumes/

# Verify
ls -laZ /srv/bareos-storage/volumes/
# Expected: system_u:object_r:container_file_t:s0
```

### Pitfall 6: Quadlet Files Not Picked Up After daemon-reload

**Symptom:** You wrote a `.container` file but after `daemon-reload`, the service does not appear in `systemctl --user list-units`.

**Root Cause:** Either a syntax error in the Quadlet file, or the file is not in the correct directory.

**Fix:**

```bash
# Run the Quadlet generator manually to get error output
QUADLET_UNIT_DIRS=/home/bareos/.config/containers/systemd \
  /usr/lib/systemd/user-generators/podman-user-generator \
  /tmp/q-out /tmp/q-out /tmp/q-out 2>&1

# Check for error messages
ls /tmp/q-out/
cat /tmp/q-out/*.service 2>/dev/null || echo "No output files generated"

# Common syntax mistakes:
# - Using tabs instead of spaces for indentation (INI format uses = not :)
# - Missing [Unit] or [Container] section header
# - File extension is .containers instead of .container (must be singular)
# - File is not owned by bareos: chown bareos:bareos *.container
```

### Pitfall 7: Container Cannot Reach Other Containers by Name

**Symptom:** `bareos-director` cannot connect to `bareos-db` using the hostname `bareos-db`.

**Root Cause:** Either the containers are not on the same Quadlet network, or the network's `DNS=true` is missing.

**Fix:**

```bash
# Verify both containers are on bareos-net
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman network inspect bareos-net

# If a container is missing, check its Network= directive
grep Network /home/bareos/.config/containers/systemd/bareos-director.container
# Expected: Network=bareos-net.network

# Test DNS resolution from inside the Director container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director nslookup bareos-db
```

### Pitfall 8: Missing XDG_RUNTIME_DIR in Scripts

**Symptom:** Scripts calling `systemctl --user` or `podman` fail with `Failed to connect to bus: No such file or directory`.

**Root Cause:** `XDG_RUNTIME_DIR` is not set in the script's environment.

**Fix:**

```bash
# Add to the top of any script that manages Bareos containers
export XDG_RUNTIME_DIR=/run/user/$(id -u bareos)
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 13-1: Inspect UID Mapping for a Running Bareos Container

This lab gives you hands-on experience reading and interpreting UID maps for the running Bareos containers.

### Step 1: Start the Bareos stack (if not already running)

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user start bareos-db.service bareos-director.service
```

### Step 2: Inspect UID mapping for the database container

```bash
# Get the PID of the bareos-db container's initial process
DB_PID=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect bareos-db --format '{{.State.Pid}}')
echo "Database container PID: $DB_PID"

# Read the UID map
echo "=== UID Map for bareos-db (PID $DB_PID) ==="
cat /proc/$DB_PID/uid_map

# Read the GID map
echo "=== GID Map for bareos-db ==="
cat /proc/$DB_PID/gid_map
```

Expected output:

```
=== UID Map for bareos-db (PID 3421) ===
         0       1001          1
         1     100000      65535

=== GID Map for bareos-db ===
         0       1001          1
         1     100000      65535
```

### Step 3: Find the UID of the MariaDB process

```bash
# Check what UID MariaDB runs as inside the container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-db id
# Expected: uid=999(mysql) gid=999(mysql)

# Now calculate what host UID that maps to
# Using mapping row 2: host_uid = 100000 + (container_uid - 1)
# = 100000 + (999 - 1) = 100998
EXPECTED_HOST_UID=$((100000 + 999 - 1))
echo "Expected host UID for container's mysql (999): $EXPECTED_HOST_UID"
```

### Step 4: Verify on the host filesystem

```bash
# List the volume data directory and check file ownership
VOLUME_PATH=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman volume inspect bareos-db --format '{{.Mountpoint}}')
echo "Volume path: $VOLUME_PATH"

ls -lan $VOLUME_PATH | head -10
# You should see files owned by UID 100998 (or 1001 for root-created files)
```

### Step 5: Verify the host process listing

```bash
# Find the mysqld process and confirm the host UID
ps aux | grep mysqld | grep -v grep
# The USER column should show 100998 (or the numeric ID if no username is mapped)
```

### Step 6: Examine the Director container mapping

```bash
# Get Director container PID
DIR_PID=$(sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman inspect bareos-director --format '{{.State.Pid}}')

# Read the map
cat /proc/$DIR_PID/uid_map

# Check the UID of the Director process inside the container
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman exec bareos-director id
# If the Director runs as UID 0 (root inside container),
# on the host it maps to UID 1001 (bareos)

# Verify: on the host the Director process should show as UID 1001
ps aux | grep bareos-director | grep -v grep
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 13-2: Diagnose and Fix a SELinux Denial for a Rootless Container Volume

This lab intentionally creates a SELinux denial, teaches you to identify it, and walks through the fix.

### Step 1: Create a host directory with incorrect SELinux context

```bash
# Create a test directory with the wrong SELinux context
sudo mkdir -p /tmp/bareos-test-vol
sudo chown bareos:bareos /tmp/bareos-test-vol

# Check its current SELinux context
ls -laZ /tmp/bareos-test-vol
# The /tmp directory has tmp_t context, which containers cannot access
```

### Step 2: Try to mount the directory into a container

```bash
# Attempt to run a container with this directory mounted (no :Z flag)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
  -v /tmp/bareos-test-vol:/data \
  docker.io/library/mariadb:10.11 \
  touch /data/test-file

# This should fail with a permission error or produce an AVC denial
```

### Step 3: Check for the AVC denial

```bash
# Search for recent AVC denials
sudo ausearch -m avc -ts recent 2>/dev/null | tail -30

# Get a human-readable explanation
sudo ausearch -m avc -ts recent 2>/dev/null | audit2why
# Expected: SELinux is denying container access to tmp_t

# Also check the audit log directly
sudo grep "avc:" /var/log/audit/audit.log | tail -10
```

### Step 4: Fix with :Z volume relabeling

```bash
# Re-run the container with :Z to relabel the volume
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman run --rm \
  -v /tmp/bareos-test-vol:/data:Z \
  docker.io/library/mariadb:10.11 \
  touch /data/test-file

echo "Exit code: $?"
# Expected: 0 (success)

# Verify the test file was created
ls -laZ /tmp/bareos-test-vol/
# The test-file should exist and the directory now has container_file_t label
```

### Step 5: Verify the relabeled context

```bash
# Check the new SELinux context
ls -laZ /tmp/bareos-test-vol/
# Expected: the _data directory now has something like:
# system_u:object_r:container_file_t:s0:c<mcs-pair>

# The context includes the MCS label pair unique to the container that created it
# This means ONLY that specific container can access it with :Z
# To make it accessible to other containers, use :z (lowercase)
```

### Step 6: Apply a persistent fix for the bareos storage path

```bash
# For production, permanently label the storage path
sudo semanage fcontext -a -t container_file_t "/srv/bareos-storage/volumes(/.*)?"
sudo restorecon -Rv /srv/bareos-storage/volumes/

# Verify the label survives a restorecon
ls -laZ /srv/bareos-storage/volumes/
# Expected: system_u:object_r:container_file_t:s0

# Now containers can access this path without :Z
# (though you can still use :Z for additional MCS isolation)
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 13-3: Verify Lingering and Test Container Auto-Start After Reboot

This lab confirms that the Bareos containers start automatically at boot (via lingering + systemd user units) and that they survive simulated logouts.

### Step 1: Confirm current state

```bash
# Check that all bareos services are currently running
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status bareos-db.service bareos-director.service --no-pager

# Confirm lingering is enabled
loginctl show-user bareos | grep Linger
# Expected: Linger=yes

# Confirm services are enabled (not just started)
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user is-enabled bareos-db.service bareos-director.service bareos-storage.service bareos-fd.service
# Expected: enabled (for all four)
```

### Step 2: Simulate a logout by killing the session

Instead of rebooting (which takes time), simulate the effect of a logout by checking that the user slice persists without an active session:

```bash
# Check if the bareos user has any active sessions
loginctl show-user bareos --property=Sessions
# For a system account with no active sessions, Sessions= should be empty

# Verify the user slice is still running (kept alive by linger)
systemctl status user@1001.service
# Expected: active (running) — even with no active sessions
```

### Step 3: Reboot test (perform when maintenance window allows)

When you have a maintenance window:

```bash
# Record container IDs before reboot
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps \
  --format "{{.Names}}: {{.ID}}" > /tmp/pre-reboot-containers.txt
cat /tmp/pre-reboot-containers.txt

# Initiate reboot
sudo systemctl reboot
```

After the system comes back up (typically 1-3 minutes):

```bash
# Check whether the containers started automatically
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 podman ps \
  --format "{{.Names}}: {{.Status}}"

# Check the journal for startup messages
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  journalctl --user -u bareos-db.service --since "boot" -n 30

# Verify all services are active
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user status bareos-db.service bareos-director.service bareos-storage.service bareos-fd.service
```

### Step 4: Test what happens without lingering (informational — do not do this in production)

```bash
# INFORMATIONAL ONLY — do not run on a production system
# This demonstrates what would happen without linger

# Disable lingering
# sudo loginctl disable-linger bareos

# Wait for the user slice to stop (or kill it manually)
# sudo systemctl stop user@1001.service

# Containers would stop immediately when the slice dies
# podman ps would show no bareos containers

# Re-enable lingering
# sudo loginctl enable-linger bareos
# sudo systemctl start user@1001.service
# sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-db.service bareos-director.service
```

### Step 5: Add a boot verification script

For production systems, create a simple health check script to run after every boot:

```bash
sudo tee /usr/local/bin/check-bareos-health.sh > /dev/null << 'SCRIPT'
#!/bin/bash
# Health check script for the Bareos container stack
# Run after boot or any maintenance window

export XDG_RUNTIME_DIR=/run/user/$(id -u bareos 2>/dev/null || echo 1001)

echo "=== Bareos Container Health Check ==="
echo "Timestamp: $(date)"
echo ""

echo "--- Linger Status ---"
loginctl show-user bareos 2>/dev/null | grep Linger

echo ""
echo "--- Running Containers ---"
sudo -u bareos XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  podman ps --filter label=app=bareos \
  --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"

echo ""
echo "--- Service Status Summary ---"
for svc in bareos-db bareos-director bareos-storage bareos-fd; do
  status=$(sudo -u bareos XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
    systemctl --user is-active ${svc}.service 2>/dev/null)
  echo "  $svc: $status"
done
SCRIPT

sudo chmod +x /usr/local/bin/check-bareos-health.sh

# Run the check
/usr/local/bin/check-bareos-health.sh
```

---

[↑ Back to Table of Contents](#table-of-contents)

## Summary

In this chapter, you gained a thorough understanding of the rootless Podman security model and its operational implications for the Bareos backup system.

**UID Mapping** is the foundation of rootless security. For the `bareos` user (UID 1001) with sub-UIDs 100000–165535:
- Container UID 0 (root inside the container) maps to host UID 1001 (bareos).
- Container UID 1 maps to host UID 100000, and this 1:1 mapping continues through the sub-UID range.
- The MariaDB process running as container UID 999 appears as host UID 100998.
- Files in named volumes show these sub-UIDs when inspected from the host.

**Backup implications:** Always be aware of which UID namespace you observe data from. Run the File Daemon inside the container namespace for consistent ownership records.

**Capabilities:** Rootless containers have capabilities scoped to their user namespace. They cannot affect the host even with `CAP_SYS_ADMIN`. Drop unnecessary capabilities for defense in depth.

**Networking:** Rootless containers use pasta (user-space network stack) instead of kernel bridges. Bareos's ports (9101-9103) are all above 1024, so there are no port-binding restrictions to work around.

**XDG paths and lingering:** Always set `XDG_RUNTIME_DIR=/run/user/1001` when running commands as the bareos user from root via `sudo`. Enable lingering with `loginctl enable-linger bareos` so containers survive logouts and start at boot.

**SELinux:** Always enforcing. Use `:Z` for private volume relabeling and `:z` for shared volumes. Use `semanage fcontext` + `restorecon` for persistent labels on important paths like `/srv/bareos-storage/volumes`. Diagnose denials with `ausearch | audit2why`.

**Storage:** RHEL 10's kernel supports native overlay in user namespaces, giving rootless containers near-native filesystem performance without FUSE overhead.

**Secrets:** Mode-600 environment files owned by the `bareos` user provide adequate secret protection for most deployments. Podman secrets provide a slightly stronger model. Consider HashiCorp Vault for enterprise-grade requirements.

**Common pitfalls** to remember: missing lingering, wrong SELinux labels on volumes, absent sub-UID allocations, missing `XDG_RUNTIME_DIR` in scripts, and containers not configured to the right Quadlet network.

The labs gave you hands-on practice reading `/proc/self/uid_map` to verify UID mappings, diagnosing and fixing SELinux denials on volume mounts, and verifying that lingering correctly enables boot-time container auto-start.

With this knowledge, you have a complete mental model of how rootless Podman works — from kernel namespaces to filesystem labels to network stacks — enabling you to confidently diagnose and resolve any operational issue in your Bareos deployment.

---

[↑ Back to Table of Contents](#table-of-contents)
