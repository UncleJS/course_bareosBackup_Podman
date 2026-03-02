# Chapter 1: What is Bareos and Why Use It?
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. What is Bareos?](#1-what-is-bareos)
  - [What Makes a Backup System "Enterprise-Grade"?](#what-makes-a-backup-system-enterprise-grade)
- [2. A Brief History: From Bacula to Bareos](#2-a-brief-history-from-bacula-to-bareos)
- [3. Why Bareos on RHEL 10?](#3-why-bareos-on-rhel-10)
  - [SELinux is Always On](#selinux-is-always-on)
  - [Podman is the First-Class Container Runtime](#podman-is-the-first-class-container-runtime)
  - [systemd is the Init and Service Manager](#systemd-is-the-init-and-service-manager)
  - [Active Directory / LDAP Integration](#active-directory-ldap-integration)
  - [Support Lifecycle](#support-lifecycle)
- [4. Bareos vs. the Alternatives](#4-bareos-vs-the-alternatives)
  - [Bareos vs. Amanda](#bareos-vs-amanda)
  - [Bareos vs. Restic](#bareos-vs-restic)
  - [Bareos vs. BorgBackup](#bareos-vs-borgbackup)
  - [Bareos vs. Veeam / Commvault / Veritas](#bareos-vs-veeam-commvault-veritas)
  - [When *Not* to Use Bareos](#when-not-to-use-bareos)
- [5. Why Run Bareos in Podman Containers?](#5-why-run-bareos-in-podman-containers)
  - [Traditional Approach: RPM Installation](#traditional-approach-rpm-installation)
  - [Container Approach: Podman + Quadlet](#container-approach-podman-quadlet)
  - [What About the File Daemon?](#what-about-the-file-daemon)
- [6. Course Roadmap and How to Use This Guide](#6-course-roadmap-and-how-to-use-this-guide)
  - [How to Use Each Chapter](#how-to-use-each-chapter)
  - [Prerequisites to Follow Along](#prerequisites-to-follow-along)
- [7. Lab 1-1: Setting Expectations — What You Will Build](#7-lab-1-1-setting-expectations-what-you-will-build)
- [8. Key Terminology Glossary](#8-key-terminology-glossary)
- [9. Summary](#9-summary)

## 1. What is Bareos?

**Bareos** (Backup Archiving REcovery Open Sourced) is a professional-grade, open-source network backup solution. At its core, Bareos allows you to:

- **Back up data** from one or many client machines (physical servers, virtual machines, containers) to a central storage location.
- **Catalog every file** it backs up so you can find and restore individual files or entire file systems later.
- **Automate retention** so that old backups are pruned and storage space is reclaimed automatically.
- **Restore data** selectively — a single file, a directory tree, or an entire disk — to the original location or somewhere else entirely.

Bareos is not a simple file-copy tool. It is a *full backup management framework*: it understands backup types (full, incremental, differential), rotation schedules, multiple storage backends (disk, tape, cloud), TLS-encrypted communications between components, role-based access control, and detailed job reporting. This makes it suitable for environments ranging from a single home server to multi-site enterprise deployments protecting terabytes of data.

### What Makes a Backup System "Enterprise-Grade"?

Many beginners start with simple approaches: `rsync`, `tar` cron jobs, or filesystem snapshots. These tools are fine for basic needs but lack:

| Feature | `rsync`/`tar` | Bareos |
|---|---|---|
| Centralized job management | No | Yes |
| Full/Incremental/Differential awareness | No | Yes |
| Automated retention and pruning | No | Yes |
| Per-file catalog with restore search | No | Yes |
| TLS-secured multi-host backup network | No | Yes |
| Parallel/concurrent backup jobs | No | Yes |
| Tape and cloud storage backends | No | Yes |
| Email reporting and alerting | No | Yes |
| Disaster recovery catalog rebuild | No | Yes |
| Pre/post job scripting hooks | No | Yes |

When you outgrow simple scripts, Bareos is the natural next step — and because it is open source, there are no license costs even at large scale.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. A Brief History: From Bacula to Bareos

To understand Bareos, you need to know its origins.

**Bacula** was created by Kern Sibbald in 2000 and became one of the most popular open-source backup systems in the world. It introduced the three-daemon architecture (Director, Storage Daemon, File Daemon) and the catalog-based approach that Bareos still uses today.

In **2010**, a group of Bacula community contributors grew frustrated with the pace of development and the increasing commercialization of Bacula Enterprise. They forked the Bacula codebase and created **Bareos** in **2012**. The Bareos project committed to:

- Remaining 100% open source (AGPL v3 license)
- Accepting community contributions freely
- Moving faster on bug fixes and new features
- Adding modern features: native S3 cloud storage, Gluster, Ceph, improved web UI (Bareos WebUI), Python plugin support, and more

Today, Bareos is actively maintained by Bareos GmbH & Co. KG (a German company) and a large open-source community. The current stable release line at the time of writing is **Bareos 23/24**, which supports RHEL 8, 9, and 10.

> **Compatibility Note:** Because Bareos and Bacula share the same protocol roots, Bareos File Daemons can communicate with Bacula Directors (with caveats) and vice versa. However, you should not mix versions carelessly in production.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Why Bareos on RHEL 10?

**Red Hat Enterprise Linux 10 (RHEL 10)** is the current enterprise Linux flagship. Choosing it as our platform is deliberate:

### SELinux is Always On
RHEL 10 ships with SELinux in **enforcing mode** by default. This is not optional in real-world enterprise environments. Throughout this course, every configuration will be SELinux-aware. You will learn to write correct file contexts, use `audit2allow` when needed, and never be tempted to use `setenforce 0` as a "fix".

### Podman is the First-Class Container Runtime
RHEL 10 has dropped Docker entirely. **Podman** is the default (and only) supported container runtime. This is actually an advantage: Podman is daemonless, rootless by default, and integrates natively with **systemd** through **Quadlet**. This course teaches you to leverage these strengths.

### systemd is the Init and Service Manager
Every long-running process — including Bareos daemons — will be managed as **systemd user services** via Quadlet. This gives you proper dependency management, restart policies, journal logging, and resource controls for free.

### Active Directory / LDAP Integration
RHEL 10 has mature `sssd` integration for enterprise authentication. While this course does not cover LDAP-backed Bareos Console access in detail, the foundation you build here is compatible.

### Support Lifecycle
RHEL 10's support lifecycle extends to the mid-2030s. Investing in RHEL 10-specific configuration knowledge is worthwhile.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Bareos vs. the Alternatives

When evaluating backup solutions, you will encounter several other options. Here is an honest comparison:

### Bareos vs. Amanda
**Amanda** (Advanced Maryland Automatic Network Disk Archiver) is another open-source backup system. It is older than Bacula and simpler in design.

| Aspect | Bareos | Amanda |
|---|---|---|
| Configuration complexity | Higher | Lower |
| Container-awareness | Good (via plugins) | Limited |
| Web UI | Yes (Bareos WebUI) | Community only |
| Tape support | Excellent | Excellent |
| Cloud storage | Native S3, Ceph | Limited |
| Active development | Very active | Slower pace |

Amanda is easier to learn but less flexible. Bareos wins for any production environment needing fine-grained control.

### Bareos vs. Restic
**Restic** is a modern, fast, deduplicating backup tool written in Go.

| Aspect | Bareos | Restic |
|---|---|---|
| Architecture | Client-server, centralized | Client-centric |
| Deduplication | Block-level (with plugins) | Content-defined chunking |
| Centralized management | Yes | No (each client self-manages) |
| Catalog / search | Full database catalog | Repository index only |
| Multi-client orchestration | Native | Requires wrapping scripts |
| Enterprise features | Full | Minimal |

Restic is excellent for individual server or developer workstation backups. It is not designed for centralised management of 50+ hosts. If you need to manage a fleet, Bareos is the correct tool.

### Bareos vs. BorgBackup
**BorgBackup** offers excellent deduplication and encryption but, like Restic, is client-centric with no native central management plane.

### Bareos vs. Veeam / Commvault / Veritas
These are commercial enterprise backup products. They offer polished GUIs and vendor support but cost significant money. Bareos provides comparable technical depth at zero license cost, making it the preferred choice for cost-conscious enterprises and open-source environments.

### When *Not* to Use Bareos
Be honest with yourself:

- If you are backing up **one laptop**, `restic` to a cloud bucket is simpler.
- If you need **immutable, ransomware-proof** backups, pair Bareos with an S3-compatible backend that has object lock, or use `restic` to Backblaze B2.
- If your team has **zero Linux CLI skills**, a GUI-first commercial product may reduce operational risk.

For everything else — multi-host Linux environments, containers, databases, RHEL production servers — Bareos is the right tool.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Why Run Bareos in Podman Containers?

This is the central architectural decision of this course. Let's justify it thoroughly.

### Traditional Approach: RPM Installation
Historically, Bareos is installed via RPM packages directly on the OS:
```
dnf install bareos-director bareos-storage bareos-filedaemon
```
This works, but has drawbacks:
- Bareos daemons run as system services alongside your other workloads.
- Updates require system-level package management.
- Multiple Bareos versions (e.g., for testing) cannot coexist.
- The MariaDB catalog database is a shared system resource.
- Moving the Bareos installation to another host requires careful reconfiguration.

### Container Approach: Podman + Quadlet
Running Bareos in containers addresses all of these:

**Isolation:** The Director, Storage Daemon, and Catalog database each run in their own container with defined resource limits. A runaway Bareos job cannot consume all system memory because `--memory` limits are enforced at the container level.

**Portability:** The entire Bareos stack (config + data volumes) can be moved to another host by copying volumes and Quadlet unit files. Disaster recovery of the backup system itself becomes straightforward.

**Version management:** You can run Bareos 23 and Bareos 24 side-by-side on the same host (different ports, different volumes) for testing migrations.

**Rootless security:** Running Bareos containers as a non-root `bareos` system user (using Podman's rootless mode) means that even if a container is compromised, the attacker has no host root access.

**Quadlet integration:** Podman Quadlet generates native systemd units from simple `.container` declarative files. You get systemd's full feature set — dependency ordering, restart policies, resource accounting, journal logging — without writing raw `[Service]` unit files by hand.

**SELinux compatibility:** Podman containers on RHEL 10 run with their own SELinux labels. Volumes are automatically relabeled (`:z` or `:Z` options), making SELinux compliance straightforward rather than a fight.

### What About the File Daemon?
The **Bareos File Daemon** (the component that runs on each client being backed up) can be deployed in two ways: installed directly on the client machine via RPM, or run as a Podman container alongside the other Bareos components. In this course we deploy the File Daemon as a **container** (`bareos-client:24`) on the same Podman host, which demonstrates backing up the host's own container volumes and is fully consistent with the course's container-first philosophy.

For backing up external client machines (bare-metal servers, VMs, etc.), you would install the File Daemon via RPM on that remote host — that pattern is standard and covered in the multi-client scenarios in later chapters.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Course Roadmap and How to Use This Guide

This course is structured as a **progressive journey**:

```
Beginner ──────────────────────────────────────────── Advanced
    │                                                      │
    ▼                                                      ▼
Ch 1-2          Ch 3-6           Ch 7-8        Ch 9-14        Ch 15-20
Concepts     Prerequisites    First Backup   Podman Focus   Production
& Theory     & Foundation     & Restore      Deep Dives     Hardening
```

### How to Use Each Chapter
Every chapter follows the same structure:
1. **Table of Contents** — jump links within the chapter
2. **Theory** — deep explanation of *why*, not just *how*
3. **Configuration walkthroughs** — annotated, complete config files
4. **Lab exercises** — step-by-step commands you run yourself
5. **Common mistakes** — pitfalls and how to avoid them
6. **Summary** — key takeaways
7. **Go to TOC** — link back to the chapter TOC

### Prerequisites to Follow Along
- A RHEL 10 system (physical, VM, or cloud instance) with at least:
  - 2 vCPUs
  - 4 GB RAM (8 GB recommended)
  - 50 GB root disk
  - 100 GB secondary disk (for Bareos storage volumes)
- A valid RHEL subscription (or a free Red Hat Developer account)
- Basic Linux CLI comfort: editing files with `vim`/`nano`, running commands as `sudo`, understanding file permissions

You do **not** need prior knowledge of Bareos, Podman, containers, or backup theory. This course starts from zero.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Lab 1-1: Setting Expectations — What You Will Build

By the end of this course, you will have built and understood every component of this architecture:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            RHEL 10 Host                                  │
│                                                                          │
│  ┌──────────────────── Podman (rootless, user: bareos) ───────────────┐  │
│  │                                                                    │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐ │  │
│  │  │   Bareos     │  │   Bareos     │  │   MariaDB                │ │  │
│  │  │  Director    │◄─►  Storage     │  │   Catalog (port 3306)    │ │  │
│  │  │  (port 9101) │  │  Daemon      │  │                          │ │  │
│  │  │              │  │  (port 9103) │  └──────────────────────────┘ │  │
│  │  └──────┬───────┘  └──────────────┘                               │  │
│  │         │  ▲                        ┌──────────────────────────┐  │  │
│  │         │  │ port 9101              │   Bareos WebUI           │  │  │
│  │         │  └────────────────────────┤   (port 80→host:9100)    │  │  │
│  │         │                           │   Browser interface      │  │  │
│  │         │  TCP 9102                 └──────────────────────────┘  │  │
│  │         ▼                                                          │  │
│  │  ┌──────────────────────────────────────────────────────────────┐ │  │
│  │  │   Bareos File Daemon (container: bareos-fd)                   │ │  │
│  │  │   /hostfs → accesses /data, Podman volumes, DB dumps          │ │  │
│  │  └──────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌───────────────────────── Podman Workloads ────────────────────────┐   │
│  │  web-app container  │  mariadb container  │  other-app container  │   │
│  │  (volume: app-data) │  (volume: db-data)  │  (volume: app2-data)  │   │
│  └───────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│  Your browser → http://localhost:9100 → WebUI → Director (port 9101)     │
└──────────────────────────────────────────────────────────────────────────┘
```

You will be able to:
- Run full, incremental, and differential backup jobs on a schedule
- Back up Podman container volumes safely, with pre/post hooks
- Dump MariaDB and PostgreSQL databases inside containers before backing them up
- Monitor job outcomes and receive email alerts on failures
- **Use the Bareos WebUI** to monitor jobs, browse backup history, and run restores from a browser at `http://localhost:9100`
- Perform a complete restore — including to a different path or client
- Recover from a catastrophic failure (lost Director host)
- Tune performance for large datasets
- Troubleshoot any common Bareos issue using logs and debug tools

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Key Terminology Glossary

Before diving in, establish this vocabulary. These terms appear throughout the course.

| Term | Definition |
|---|---|
| **Director** | The Bareos daemon that orchestrates everything: schedules jobs, directs File Daemons to send data to Storage Daemons, writes the catalog. |
| **Storage Daemon (SD)** | The Bareos daemon that receives backup data from File Daemons and writes it to storage (disk or tape). |
| **File Daemon (FD)** | The Bareos daemon installed on each client. It reads files from the client and sends them to the Storage Daemon. Also called the "client". |
| **Catalog** | A relational database (MariaDB in our setup) that records metadata about every file backed up: name, size, checksum, timestamps, which Volume it lives on. |
| **Volume** | A Bareos storage object — a file on disk (or a tape cartridge) that contains backup data. Volumes are labeled and tracked in the Catalog. |
| **Pool** | A named collection of Volumes with shared properties (retention period, volume size limits, label format). |
| **Job** | A single backup, restore, verify, or migrate operation as defined in the Director config. |
| **JobDefs** | A template of job settings that can be shared across multiple Job definitions. |
| **FileSet** | A definition of which files/directories to include or exclude from a backup. |
| **Schedule** | A timed trigger that causes the Director to run Jobs automatically. |
| **Retention** | How long Bareos keeps backup data before it is eligible for pruning/overwriting. |
| **bconsole** | The Bareos command-line console — the primary operator interface to the Director. |
| **Bareos WebUI** | A web-based graphical interface for Bareos. Runs as a Podman container (port 9100). Used for job monitoring, restore operations, and pool/volume management. Deployed in Chapter 6. |
| **Quadlet** | A systemd-native mechanism for managing Podman containers as systemd units via declarative `.container` files. |
| **Rootless Podman** | Running Podman containers under a non-root user account. Containers cannot gain root privileges on the host. |
| **SELinux** | Security-Enhanced Linux — mandatory access control built into RHEL. Always enforcing in this course. |

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Summary

In this chapter you learned:

- **Bareos** is a full-featured, open-source network backup framework descended from Bacula, actively maintained, and free to use at any scale.
- It provides capabilities far beyond simple scripts: centralized job management, per-file catalog, automated retention, TLS security, and more.
- **RHEL 10** is the target platform because it represents the current enterprise Linux standard, with Podman as the native container runtime and SELinux always enforced.
- **Running Bareos in Podman containers** provides isolation, portability, version flexibility, rootless security, and native systemd integration through Quadlet.
- The **File Daemon** runs as a container (`bareos-fd`) alongside the Director and Storage Daemon — with the host filesystem bind-mounted read-only so all local data is accessible for backup. Remote clients would install the FD via RPM.
- By the end of this course you will have built a complete, production-quality Bareos deployment protecting Podman container workloads on RHEL 10.

---

**Next Chapter:** [Chapter 2: Backup Fundamentals](./02-backup-concepts.md)

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
