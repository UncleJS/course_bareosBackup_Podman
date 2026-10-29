# Chapter 21: Host File Daemon with CAP_DAC_READ_SEARCH
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. Why Leave the File Daemon on the Host?](#1-why-leave-the-file-daemon-on-the-host)
  - [Three Deployment Patterns](#three-deployment-patterns)
  - [The Hybrid Model This Chapter Teaches](#the-hybrid-model-this-chapter-teaches)
- [2. CAP_DAC_READ_SEARCH Deep Dive](#2-cap_dac_read_search-deep-dive)
  - [DAC Reminder](#dac-reminder)
  - [CAP_DAC_READ_SEARCH vs CAP_DAC_OVERRIDE](#cap_dac_read_search-vs-cap_dac_override)
  - [Why Backup Agents Use It](#why-backup-agents-use-it)
- [3. Prerequisites](#3-prerequisites)
- [4. Install the Host File Daemon](#4-install-the-host-file-daemon)
- [5. systemd Hardening with Ambient Capabilities](#5-systemd-hardening-with-ambient-capabilities)
  - [Drop-in Unit](#drop-in-unit)
  - [Verify Capabilities](#verify-capabilities)
  - [SELinux Notes for the Host FD](#selinux-notes-for-the-host-fd)
- [6. Wire the Host FD to the Container Director](#6-wire-the-host-fd-to-the-container-director)
  - [File Daemon Configuration](#file-daemon-configuration)
  - [Director Client Resource](#director-client-resource)
  - [Addressing: How the Container Reaches the Host](#addressing-how-the-container-reaches-the-host)
  - [FileSets Without /hostfs](#filesets-without-hostfs)
- [7. Retire or Coexist with the Container FD](#7-retire-or-coexist-with-the-container-fd)
  - [Recommended: One Host FD for This Machine](#recommended-one-host-fd-for-this-machine)
  - [Hook Strategy Without a Container FD](#hook-strategy-without-a-container-fd)
- [8. Restore Implications](#8-restore-implications)
- [9. Lab 21-1: Install and Harden the Host FD](#9-lab-21-1-install-and-harden-the-host-fd)
- [10. Lab 21-2: Register, Back Up, and Restore](#10-lab-21-2-register-back-up-and-restore)
- [11. Common Mistakes](#11-common-mistakes)
- [12. Summary](#12-summary)

---

## 1. Why Leave the File Daemon on the Host?

Chapters 6–20 deploy the **entire** Bareos stack — including the File Daemon — as rootless Podman containers. That design is excellent for a lab and for protecting container volumes when the FD mounts the host at `/hostfs` and disables SELinux labeling (`SecurityLabelDisable=true`).

It has trade-offs for backing up a production host OS:

| Concern | Container FD + `/hostfs` | Host FD |
|---|---|---|
| Path prefix in catalog | `/hostfs/etc/...` | `/etc/...` |
| SELinux on the FD process | Labeling often disabled for `/` | Native `bareos_t` policy |
| Reading root-only files as non-root | Relies on mount + label disable | `CAP_DAC_READ_SEARCH` |
| Podman socket for hooks | Easy (socket bind-mount) | Run hooks on the host |
| Blast radius if FD is compromised | Full host read via `/hostfs` + socket | Host process with one capability |

### Three Deployment Patterns

1. **Container FD + `/:/hostfs:ro` + `SecurityLabelDisable=true`** (Chapter 6 default)  
   Everything stays in Quadlet. FileSets use `/hostfs/...`. Simple for the course lab; SELinux confinement of the FD is weakened by design.

2. **Host FD running as root**  
   Classic RPM install. Can read everything. No fine-grained capability story. Acceptable on locked-down clients, but over-privileged for a dedicated backup service account.

3. **Host FD as non-root + `CAP_DAC_READ_SEARCH`** (this chapter)  
   File Daemon installed from RPM, managed by **host** systemd, running as `bareos` (or a dedicated FD user), with **only** the capability needed to traverse directories and read files regardless of DAC mode bits. Director, Storage Daemon, catalog, and WebUI remain containers.

### The Hybrid Model This Chapter Teaches

```
┌─────────────────────────────────────────────────────────────┐
│  RHEL 10 Host                                               │
│                                                             │
│  ┌─ rootless Quadlet (user bareos) ──────────────────────┐  │
│  │  bareos-director :9101                                 │  │
│  │  bareos-storage  :9103                                 │  │
│  │  bareos-db       :3306                                 │  │
│  │  bareos-webui    :9100                                 │  │
│  └───────────────────────────┬────────────────────────────┘  │
│                              │ Director → FD :9102            │
│                              ▼                                │
│  ┌─ host systemd ─────────────────────────────────────────┐  │
│  │  bareos-fd.service  (RPM)                               │  │
│  │  User=bareos                                            │  │
│  │  AmbientCapabilities=CAP_DAC_READ_SEARCH                │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                             │
│  /srv/bareos-storage/volumes  ← still bind-mounted into SD  │
└─────────────────────────────────────────────────────────────┘
```

**Fully container-based Bareos control plane. Only the File Daemon runs on the host** — specifically so it can hold `CAP_DAC_READ_SEARCH` in the **initial** (host) user namespace, where that capability actually affects host DAC checks.

> **Important:** Capabilities granted *inside* a rootless container apply inside the container user namespace. They do **not** give a container process host-wide DAC bypass. That is why “add `CAP_DAC_READ_SEARCH` to the Quadlet FD” is not a substitute for a host FD. See [Chapter 13](./13-rootless-podman-specifics.md) for user-namespace capability scoping.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. CAP_DAC_READ_SEARCH Deep Dive

### DAC Reminder

Linux Discretionary Access Control (DAC) is the familiar owner/group/other permission model (`chmod`, `chown`). A process running as UID 1001 (`bareos`) cannot normally read `/etc/shadow` (mode `000`) or traverse a directory mode `700` owned by another user.

### CAP_DAC_READ_SEARCH vs CAP_DAC_OVERRIDE

| Capability | Effect |
|---|---|
| `CAP_DAC_READ_SEARCH` | Bypass DAC checks for **reading** files and **searching** (traversing) directories |
| `CAP_DAC_OVERRIDE` | Bypass DAC checks for read, write, and execute |

Backup agents need to **read** every file in a FileSet and **walk** the directory tree. They do not need to rewrite arbitrary host files during a backup. Prefer **`CAP_DAC_READ_SEARCH`** over `CAP_DAC_OVERRIDE` or full root.

Restore that must overwrite root-owned files still requires write privilege (root, `CAP_DAC_OVERRIDE`, or restore-to-alternate-path as non-root). Lab restores in this chapter use an alternate `Where=` path the `bareos` user can write.

### Why Backup Agents Use It

- Run the FD as a dedicated non-root account.
- Grant one ambient capability via systemd so children inherit it.
- Bound the capability set so the process cannot gain unrelated privileges.
- Keep SELinux enforcing (`bareos_t`) instead of disabling labels for a container that mounts `/`.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Prerequisites

Before this chapter you need:

1. The Chapter 6 stack running: **Director, Storage Daemon, MariaDB, WebUI** as Quadlet containers under user `bareos`.
2. Matching Bareos **24** packages on the host for the File Daemon (same major as `docker.io/bareos/bareos-*:24`).
3. The Bareos repository configured (see [Chapter 3](./03-rhel10-prerequisites.md)).
4. Firewall allowing Director → FD on `9102/tcp` and FD → SD on `9103/tcp` (Lab 3-1 / host firewalld).
5. Willingness to **stop the Quadlet `bareos-fd` container** for this host once the host FD takes over (recommended path).

You do **not** need to reinstall Director, SD, DB, or WebUI.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Install the Host File Daemon

Install only the client package on the backup server (or any host you want to protect with this pattern):

```bash
# As a sudo-capable admin — not inside a container
sudo dnf install -y bareos-filedaemon

# Confirm version family matches the container images (24.x)
rpm -q bareos-filedaemon
```

The RPM ships:

- Binary: typically `/usr/sbin/bareos-fd`
- Config drop-ins: `/etc/bareos/bareos-fd.d/`
- Unit: `bareos-fd.service` (system systemd, not `--user`)

The existing `bareos` user from Chapter 3 (UID 1001) is reused so ownership of `/srv/bareos-storage` and Quadlet home stay consistent. If your RPM creates a different FD user, either align UIDs or run the FD as that user and grant it read of the paths you back up (capability still required for foreign-owned files).

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. systemd Hardening with Ambient Capabilities

### Drop-in Unit

Do not replace the entire vendor unit unless you must. Use a drop-in:

```bash
sudo mkdir -p /etc/systemd/system/bareos-fd.service.d
sudo tee /etc/systemd/system/bareos-fd.service.d/10-capabilities.conf > /dev/null <<'EOF'
[Service]
# Run as the course bareos account (adjust if your RPM uses a different user)
User=bareos
Group=bareos

# Grant read/search bypass in the host user namespace; keep the bound set tight
AmbientCapabilities=CAP_DAC_READ_SEARCH
CapabilityBoundingSet=CAP_DAC_READ_SEARCH

# Prevent gaining further privileges after start
NoNewPrivileges=true

# Harden process environment (safe defaults for a network daemon)
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
ReadWritePaths=/var/lib/bareos /var/run/bareos /var/log/bareos
EOF

sudo systemctl daemon-reload
```

> **Note on `NoNewPrivileges` and ambient capabilities:** systemd raises ambient capabilities before applying `NoNewPrivileges`. If the service fails to start with capability errors, temporarily comment `NoNewPrivileges=true`, confirm with `getpcaps`, then re-enable and retest. Prefer keeping it on once verified.

Reload and start:

```bash
sudo systemctl enable --now bareos-fd.service
sudo systemctl status bareos-fd.service --no-pager
```

### Verify Capabilities

```bash
# PID of bareos-fd
pid=$(pgrep -n bareos-fd)
echo "PID=$pid"
# Expect dac_read_search in the ambient and permitted sets
getpcaps "$pid"
# Or:
grep Cap /proc/"$pid"/status
```

You should see `dac_read_search` present. If the capability is missing, the drop-in was not loaded (`systemctl cat bareos-fd.service`) or the binary cleared ambient capabilities — check package docs and that you are inspecting the host process, not a leftover container.

### SELinux Notes for the Host FD

With the RPM installed, SELinux types such as `bareos_t` become relevant (see Chapter 3’s RPM aside). Useful checks:

```bash
# Process context
ps -eZ | grep bareos-fd

# Booleans shipped with Bareos policy (names vary by package)
getsebool -a | grep bareos || true

# Recent denials while a job runs
sudo ausearch -m avc -ts recent | grep bareos || true
```

Unlike the container FD, you should **not** set `SecurityLabelDisable` — there is no Podman label to disable. Fix denials with `restorecon`, `semanage fcontext`, or a minimal `audit2allow` module as in Chapter 20.

Reading Podman named-volume `_data` directories labeled `container_file_t` may still need a small custom policy if you backup those paths from the host FD. Prefer dumping databases via hooks (Chapter 10/14) into a path the FD is allowed to read.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Wire the Host FD to the Container Director

Director still owns Clients, Jobs, FileSets, and Schedules. Only the **Client address** and **FD config** change.

### File Daemon Configuration

Edit the host FD resources (paths may be split across drop-in files):

```bash
# Identity — /etc/bareos/bareos-fd.d/client/myself.conf
sudo tee /etc/bareos/bareos-fd.d/client/myself.conf > /dev/null <<'EOF'
Client {
  Name = bareos-fd-host
  Maximum Concurrent Jobs = 10
  TLS Enable = No
}
EOF

# Authorized Director — password MUST match Director Client resource
sudo tee /etc/bareos/bareos-fd.d/director/bareos-dir.conf > /dev/null <<'EOF'
Director {
  Name = bareos-dir
  Password = "CHANGEME_FD_PASSWORD"   # same as Director Client Password
  TLS Enable = No
}
EOF

sudo chown -R bareos:bareos /etc/bareos/bareos-fd.d
sudo systemctl restart bareos-fd.service
```

Use the same password you stored in `/home/bareos/.config/bareos/bareos.env` / Director client config from Chapter 6 (or generate a new shared secret and update both sides).

> **Lab only:** `TLS Enable = No` above is for first wiring. Before treating this hybrid layout as production, apply [Chapter 15](./15-tls-security.md) to the host FD certificates and the Director `Client` / Storage resources so DIR↔FD and FD→SD are encrypted with `TLS Require = yes`.

### Director Client Resource

On the Director host bind-mount (`/etc/bareos/bareos-dir.d/client/`):

```bash
sudo tee /etc/bareos/bareos-dir.d/client/bareos-fd-host.conf > /dev/null <<'EOF'
Client {
  Name = bareos-fd-host
  Address = host.containers.internal
  FDPort = 9102
  Password = "CHANGEME_FD_PASSWORD"
  Catalog = MyCatalog
  TLS Enable = No
}
EOF
```

Reload the Director configuration (or restart the Quadlet unit):

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  systemctl --user restart bareos-director.service
```

If you previously registered a Client named `bareos-fd` pointing at the container, either remove that resource or leave it disabled so jobs do not target the wrong endpoint.

### Addressing: How the Container Reaches the Host

The Director container must resolve an address that lands on the **host** listener for `bareos-fd` (port 9102):

| Address choice | When to use |
|---|---|
| `host.containers.internal` | Podman provides this gateway to the host (pasta / host-gateway). Preferred in this course. |
| Host primary IP | Works across networks; open firewalld accordingly |
| `127.0.0.1` from Director | Only if the FD listens on loopback **and** the Director shares that namespace — **not** true for a separate container. Do not use `127.0.0.1` as `Client.Address` from the Director container. |

Publish or bind the host FD:

```bash
# Confirm FD listens on 9102
ss -lntp | grep 9102
```

Ensure firewalld allows Director traffic to 9102 (Chapter 3). The Storage Daemon should remain published so the **host** FD can connect outbound to SD port 9103 (Chapter 6 publishes `9103:9103`). Point the Director `Storage` resource at the SD container name as before; the FD uses the SD address the Director sends (often the SD’s reachable IP/DNS). If jobs fail at “connect to storage”, give the host an address for the SD — commonly the host IP where 9103 is published, not the Quadlet-only DNS name `bareos-storage` (that name resolves only inside the `bareos` network).

**Practical pattern for hybrid stacks:**

1. Keep Director → Client using `host.containers.internal:9102`.
2. In the Director `Storage` resource used by host-FD jobs, set `Address` to an IP/DNS the **host** can reach (host IP or a split DNS name), while container-to-container jobs can keep using `bareos-storage`.

Example Storage resource for host-FD jobs:

```conf
Storage {
  Name = File-HostReachable
  Address = 192.0.2.10          # host IP where SD PublishPort=9103 is exposed
  Password = "CHANGEME_SD_PASSWORD"
  Device = FileStorage
  Media Type = File
  TLS Enable = No
}
```

### FileSets Without /hostfs

Host FD paths are real host paths:

```conf
FileSet {
  Name = RHEL10-Host-Standard
  Include {
    Options {
      Signature = SHA1
      Compression = LZ4
      OneFS = no
    }
    File = /etc
    File = /home
    File = /var/log
  }
  Exclude {
    File = /var/lib/bareos
    File = /home/bareos/.local/share/containers
  }
}
```

Do **not** prefix with `/hostfs`. Catalog entries will look like `/etc/hosts`, matching Chapter 8 restores without File Relocation to strip `hostfs`.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Retire or Coexist with the Container FD

### Recommended: One Host FD for This Machine

```bash
# As bareos user
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 bash -c '
  systemctl --user stop bareos-fd.service
  systemctl --user disable bareos-fd.service
'
# Optional: rename/move the Quadlet file so it is not regenerated as WantedBy=default.target
sudo -u bareos mv \
  /home/bareos/.config/containers/systemd/bareos-fd.container \
  /home/bareos/.config/containers/systemd/bareos-fd.container.disabled
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
```

Free host port 9102 for the RPM service if the container had `PublishPort=127.0.0.1:9102:9102`.

### Hook Strategy Without a Container FD

Chapters 10 and 14 mount the Podman socket into the **container** FD. With a host FD:

- Place `ClientRunBeforeJob` / `ClientRunAfterJob` scripts under `/etc/bareos/scripts/` on the **host**.
- Run them as the `bareos` user so they can talk to the rootless Podman socket:

```bash
# Example snippet inside a host hook
export XDG_RUNTIME_DIR=/run/user/1001
export CONTAINER_HOST=unix:///run/user/1001/podman/podman.sock
podman exec bareos-db mariadb-dump ...
```

Prefer **one** FD per host. A second Client that is only the old container FD is useful only during migration.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Restore Implications

| Topic | Container FD (Ch 6–8) | Host FD (this chapter) |
|---|---|---|
| Catalog path | `/hostfs/etc/hosts` | `/etc/hosts` |
| `Where=/tmp/restore` | Creates `.../hostfs/etc/hosts` | Creates `.../etc/hosts` |
| File Relocation | Often strip `^/hostfs` | Usually unnecessary |
| Overwrite live system files | FD container may lack write to host | Host FD needs write DAC or restore to alternate path |

Smoke-test restores with `Where=/tmp/bareos-restores` owned by `bareos`. Production in-place restores may need a temporary privilege escalation or a root-assisted copy from the restore tree.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Lab 21-1: Install and Harden the Host FD

**Goal:** Install `bareos-filedaemon`, apply the capability drop-in, verify `CAP_DAC_READ_SEARCH`, and confirm the service listens on 9102.

1. Install the package and show the version:
   ```bash
   sudo dnf install -y bareos-filedaemon
   rpm -q bareos-filedaemon
   ```
2. Create `/etc/systemd/system/bareos-fd.service.d/10-capabilities.conf` as in Section 5.
3. `sudo systemctl daemon-reload && sudo systemctl enable --now bareos-fd`
4. Run `getpcaps $(pgrep -n bareos-fd)` and confirm `dac_read_search`.
5. Run `ss -lntp | grep 9102` and `systemctl is-active bareos-fd`.
6. Stop the Quadlet container FD (Section 7) so only the host service owns 9102.

**Pass criteria:** Active host unit, capability present, port 9102 listening, container FD stopped.

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Lab 21-2: Register, Back Up, and Restore

**Goal:** Register `bareos-fd-host` with the container Director, run a Full job of a small host path, restore without `/hostfs` relocation.

1. Configure FD `myself.conf` / `director/bareos-dir.conf` and Director `client/bareos-fd-host.conf` (Section 6). Use a reachable Storage address for the host.
2. Add a Job and FileSet (example):
   ```conf
   FileSet {
     Name = Lab21-EtcHosts
     Include {
       Options { Signature = SHA1 }
       File = /etc/hosts
     }
   }
   Job {
     Name = BackupHostEtc
     Client = bareos-fd-host
     JobDefs = StandardBackup
     FileSet = Lab21-EtcHosts
     Storage = File-HostReachable
   }
   ```
   Adjust `JobDefs` / `Storage` names to match your Chapter 7/6 resources.
3. Reload/restart Director; in bconsole:
   ```
   status client=bareos-fd-host
   run job=BackupHostEtc level=Full yes
   wait
   list joblog jobid=<N>
   ```
4. Confirm the job log shows files under `/etc/hosts` (not `/hostfs/etc/hosts`).
5. Restore:
   ```
   restore client=bareos-fd-host file=/etc/hosts select current all done where=/tmp/bareos-restores yes
   ```
6. Verify:
   ```bash
   diff -u /etc/hosts /tmp/bareos-restores/etc/hosts
   ```

**Pass criteria:** Director status OK to host FD; Full job terminates `T`; restore tree has `/tmp/bareos-restores/etc/hosts` with matching content.

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Common Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Capability not ambient | Job fails with “Permission denied” on `/etc/shadow` or mode `700` dirs | Check drop-in with `systemctl cat`; `getpcaps`; ensure `AmbientCapabilities=` |
| Director `Address = bareos-fd` | Timeout / connection refused after container FD stopped | Use `host.containers.internal` or host IP |
| Director `Address = 127.0.0.1` | Connects to Director’s own loopback inside the container | Never use loopback for host FD from a container |
| FileSet still uses `/hostfs/...` | Empty backup or “file not found” | Use real host paths |
| SD address only valid on Quadlet DNS | FD cannot connect to storage | Publish 9103; Storage `Address` = host-reachable IP |
| Container and host FD both bound to 9102 | One fails to start | Stop Quadlet `bareos-fd` |
| Expecting container caps to bypass host DAC | Still permission denied from Quadlet FD | Caps in user namespace ≠ host DAC; use this chapter’s host FD |
| SELinux AVC on `bareos_t` | Silent denials / EACCES | `ausearch` / `audit2why`; do not `setenforce 0` |
| In-place restore as `bareos` | Cannot overwrite root files | Restore to `/tmp/...` then copy with privilege |

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Summary

- **Hybrid architecture:** Director, Storage Daemon, MariaDB, and WebUI stay rootless Quadlet containers. **Only the File Daemon** runs on the host as an RPM systemd service.
- **`CAP_DAC_READ_SEARCH`** lets a non-root FD traverse and read host files without full root and without `/hostfs` + `SecurityLabelDisable`.
- **systemd drop-ins** set `AmbientCapabilities` and a tight `CapabilityBoundingSet`.
- **Director wiring** uses a host-reachable Client address; FileSets use real paths; Storage addresses must be reachable from the host FD.
- **Restores** no longer need `/hostfs` File Relocation.
- **Hooks** move to host scripts with `XDG_RUNTIME_DIR` and the rootless Podman socket.

This pattern is the production-oriented alternative to Chapter 6’s container FD for protecting the host OS while keeping Bareos’s control plane fully containerized.

---

**Previous Chapter:** [Chapter 20: Troubleshooting Guide](./20-troubleshooting.md)

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
