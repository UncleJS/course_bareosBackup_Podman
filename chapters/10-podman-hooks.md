# Chapter 10: Pre- and Post-Job Hooks for Container-Aware Backups
[![CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [1. Why Hooks Matter — The Consistency Problem for Live Containers](#1-why-hooks-matter-the-consistency-problem-for-live-containers)
  - [The database crash-consistency problem](#the-database-crash-consistency-problem)
  - [The container layer makes it worse](#the-container-layer-makes-it-worse)
  - [The solution: hooks](#the-solution-hooks)
- [2. The Bareos RunScript Mechanism](#2-the-bareos-runscript-mechanism)
  - [The four RunScript run-when values](#the-four-runscript-run-when-values)
  - [RunScript block syntax](#runscript-block-syntax)
  - [The shorthand directives](#the-shorthand-directives)
  - [Multiple RunScript blocks](#multiple-runscript-blocks)
- [3. Hook Execution Context](#3-hook-execution-context)
  - [Who runs the script?](#who-runs-the-script)
  - [The Podman socket approach](#the-podman-socket-approach)
  - [Available environment variables](#available-environment-variables)
  - [Working directory and PATH](#working-directory-and-path)
  - [Script must be executable](#script-must-be-executable)
- [4. Stopping vs Pausing a Container Before Backup](#4-stopping-vs-pausing-a-container-before-backup)
  - [Stopping a container (`podman stop`)](#stopping-a-container-podman-stop)
  - [Restarting after a stop](#restarting-after-a-stop)
- [5. Freezing with `podman pause` for Minimal Downtime](#5-freezing-with-podman-pause-for-minimal-downtime)
  - [Why pause is better for databases](#why-pause-is-better-for-databases)
  - [The pause/unpause commands](#the-pauseunpause-commands)
  - [Verifying pause succeeded](#verifying-pause-succeeded)
- [6. Database Dump Hooks via `podman exec`](#6-database-dump-hooks-via-podman-exec)
  - [`podman exec` syntax](#podman-exec-syntax)
  - [MariaDB dump command](#mariadb-dump-command)
  - [PostgreSQL dump command](#postgresql-dump-command)
  - [The output redirection problem](#the-output-redirection-problem)
- [7. Writing Robust Hook Scripts](#7-writing-robust-hook-scripts)
  - [Principle 1: Exit immediately on any error](#principle-1-exit-immediately-on-any-error)
  - [Principle 2: Log everything](#principle-2-log-everything)
  - [Principle 3: Validate prerequisites before doing anything](#principle-3-validate-prerequisites-before-doing-anything)
  - [Principle 4: Use a trap to handle unexpected failures](#principle-4-use-a-trap-to-handle-unexpected-failures)
  - [Principle 5: Verify the dump output](#principle-5-verify-the-dump-output)
  - [Principle 6: Use timeouts](#principle-6-use-timeouts)
- [8. MariaDB Dump Hook Script](#8-mariadb-dump-hook-script)
  - [Making the script executable and setting ownership](#making-the-script-executable-and-setting-ownership)
- [9. PostgreSQL Dump Hook Script](#9-postgresql-dump-hook-script)
- [10. Cleanup Hooks: Removing Temp Dump Files After Backup](#10-cleanup-hooks-removing-temp-dump-files-after-backup)
  - [Unpause hook (when using pause/unpause workflow)](#unpause-hook-when-using-pauseunpause-workflow)
- [11. SELinux: Labeling Hook Scripts and Temp Directories](#11-selinux-labeling-hook-scripts-and-temp-directories)
  - [Why SELinux matters for hooks](#why-selinux-matters-for-hooks)
  - [Labeling hook script files](#labeling-hook-script-files)
  - [Labeling the dump directory](#labeling-the-dump-directory)
  - [Diagnosing SELinux denials](#diagnosing-selinux-denials)
  - [The permissive debugging approach](#the-permissive-debugging-approach)
- [12. Logging Hook Output](#12-logging-hook-output)
  - [Where stdout and stderr go](#where-stdout-and-stderr-go)
  - [Viewing hook output in bconsole](#viewing-hook-output-in-bconsole)
  - [Sending hook output to a dedicated log file](#sending-hook-output-to-a-dedicated-log-file)
  - [Log rotation](#log-rotation)
- [13. Lab 10-1: Pause/Resume a Container Around a Backup Job](#13-lab-10-1-pauseresume-a-container-around-a-backup-job)
  - [Prerequisites](#prerequisites)
  - [Step 1: Start a test container](#step-1-start-a-test-container)
  - [Step 2: Create pause/unpause hook scripts](#step-2-create-pauseunpause-hook-scripts)
  - [Step 3: Configure the Bareos Job](#step-3-configure-the-bareos-job)
  - [Step 4: Create the FileSet](#step-4-create-the-fileset)
  - [Step 5: Reload and run the job](#step-5-reload-and-run-the-job)
  - [Step 6: Verify the container unpaused](#step-6-verify-the-container-unpaused)
- [14. Lab 10-2: Full MariaDB Dump Hook](#14-lab-10-2-full-mariadb-dump-hook)
  - [Prerequisites](#prerequisites)
  - [Step 1: Install the dump hook scripts](#step-1-install-the-dump-hook-scripts)
  - [Step 2: Create the dump directory](#step-2-create-the-dump-directory)
  - [Step 3: Configure the Bareos Job with RunScript](#step-3-configure-the-bareos-job-with-runscript)
  - [Step 4: Configure the FileSet to include the dump](#step-4-configure-the-fileset-to-include-the-dump)
  - [Step 5: Run the job and verify the dump is included](#step-5-run-the-job-and-verify-the-dump-is-included)
  - [Step 6: Verify the dump is valid SQL](#step-6-verify-the-dump-is-valid-sql)
- [15. Lab 10-3: PostgreSQL Dump Hook](#15-lab-10-3-postgresql-dump-hook)
  - [Step 1: Install the PostgreSQL hook script](#step-1-install-the-postgresql-hook-script)
  - [Step 2: Configure the Bareos Job](#step-2-configure-the-bareos-job)
  - [Step 3: Configure the FileSet](#step-3-configure-the-fileset)
  - [Step 4: Run and verify](#step-4-run-and-verify)
  - [Step 5: Test the PostgreSQL dump is restorable](#step-5-test-the-postgresql-dump-is-restorable)
- [16. Summary](#16-summary)

## 1. Why Hooks Matter — The Consistency Problem for Live Containers

When you back up a running application, you are taking a snapshot of data that may be changing at the exact moment the backup tool reads it. For static files — configuration, logs, static web assets — this is usually acceptable. A slightly inconsistent log file is not catastrophic. But for databases, message queues, and applications that maintain internal state spread across multiple files, an inconsistent backup is worse than no backup at all.

### The database crash-consistency problem

A relational database like MariaDB or PostgreSQL does not store all your data in one file. It maintains:

- **Data files** — the actual table storage (InnoDB `.ibd` files, PostgreSQL relation files)
- **Write-ahead logs (WAL) / redo logs** — a journal of recent changes not yet flushed to data files
- **Control files / pg_control** — metadata about what state the database is in
- **Undo segments** — for transactions in flight

At any given moment, the data files are in a state that is only consistent *relative to* what the WAL says. If you copy the data files at 14:00:01 and the WAL files at 14:00:02, the WAL may already reflect writes that the data files do not. When you try to restore from such a backup, the database engine will attempt crash recovery, find inconsistencies, and either refuse to start or, worse, silently produce corrupt data.

This is called **crash-inconsistent** backup, and it is the default outcome if you point Bareos at `/var/lib/mysql` and let it run while MariaDB is live.

### The container layer makes it worse

When your database runs in a container, the situation has additional complexity:

1. The data is stored in a **named volume** (e.g., `bareos_mariadb_data`). Bareos can see this volume's path on disk, but it cannot know whether the database engine has flushed its buffers.
2. The container filesystem is managed by the container runtime. Writes from inside the container may be in the page cache and not yet reflected in the files Bareos reads.
3. Container restarts change the environment entirely — environment variables like `MARIADB_ROOT_PASSWORD` that were only present at container creation are gone unless re-injected.

### The solution: hooks

Bareos provides a **RunScript** mechanism that lets you run arbitrary shell commands or scripts before and after a backup job. This is how you solve the consistency problem:

**Before the backup:**
1. Run `mariadb-dump` inside the running MariaDB container to produce a complete, logically consistent SQL dump
2. Write the dump to a directory that Bareos will include in its FileSet
3. Optionally pause or stop the container so no new writes happen while Bareos copies the volume files

**After the backup:**
1. Resume or start the container
2. Remove the temporary dump file (optional, to save space)

With hooks in place, your backup contains a **guaranteed-consistent** dump file, regardless of what state the underlying volume files are in.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. The Bareos RunScript Mechanism

Bareos provides four hook points around every backup job, each corresponding to a specific combination of **when** (before or after) and **where** (on the client or on the director).

### The four RunScript run-when values

| Directive | Runs on | Runs when | Typical use |
|-----------|---------|-----------|-------------|
| `ClientRunBeforeJob` | File Daemon | Before file transfer starts | Dump databases, pause containers |
| `ClientRunAfterJob` | File Daemon | After file transfer completes | Resume containers, delete temp files |
| `RunBeforeJob` | Director | Before the job is dispatched | Notify Slack, update inventory |
| `RunAfterJob` | Director | After the job completes | Email results, trigger dependent jobs |

The most important distinction is **where** the script runs. `ClientRunBeforeJob` and `ClientRunAfterJob` run on the machine where the **File Daemon (bareos-fd)** is running — that is, on the client being backed up. This is essential: if your MariaDB container is on host A, the dump script must run on host A (where the `podman` binary is and where the container is running).

`RunBeforeJob` and `RunAfterJob` run on the **Director** machine. The Director does not have access to the client's filesystem or containers. These hooks are appropriate for orchestration tasks, not for data preparation.

### RunScript block syntax

A `RunScript` block lives inside a `Job` resource in the Bareos Director configuration. Here is the complete syntax with all available options:

```
Job {
  Name = "backup-mariadb"
  # ... other job options ...

  RunScript {
    # The shell command or path to a script to execute
    Command = "/etc/bareos/scripts/backup-mariadb.sh"

    # When to run: Before or After
    RunsWhen = Before

    # Where to run: Client or Director
    RunsOnClient = yes

    # What to do if this script returns a non-zero exit code:
    #   yes  = abort the job entirely (treat as fatal)
    #   no   = log the failure but continue the job
    FailJobOnError = yes

    # For After-scripts: whether to run on job success and/or failure.
    #   RunsOnSuccess = yes  → run when the job succeeds
    #   RunsOnFailure = no   → do NOT run when the job fails
    RunsOnSuccess = yes
    RunsOnFailure = no
  }
}
```

### The shorthand directives

Bareos also provides shorthand directives that expand into `RunScript` blocks internally. These are convenient for simple one-liner commands:

```
Job {
  Name = "backup-mariadb"

  # Equivalent to RunScript { Command="..."; RunsWhen=Before; RunsOnClient=yes; FailJobOnError=yes }
  ClientRunBeforeJob = "/etc/bareos/scripts/backup-mariadb.sh"

  # Equivalent to RunScript { Command="..."; RunsWhen=After; RunsOnClient=yes; FailJobOnError=no }
  ClientRunAfterJob  = "/etc/bareos/scripts/cleanup-dumps.sh"
}
```

The shorthand versions have slightly different defaults for `FailJobOnError` — `ClientRunBeforeJob` defaults to failing the job on error (which is usually what you want for a pre-backup dump), while `ClientRunAfterJob` defaults to not failing the job on error (cleanup failures should not invalidate an otherwise good backup).

### Multiple RunScript blocks

You can have multiple `RunScript` blocks in a single job, and they execute in the order they appear in the configuration file:

```
Job {
  Name = "backup-full-stack"

  RunScript {
    Command    = "/etc/bareos/scripts/backup-mariadb.sh"
    RunsWhen   = Before
    RunsOnClient = yes
    FailJobOnError = yes
  }

  RunScript {
    Command    = "/etc/bareos/scripts/backup-redis.sh"
    RunsWhen   = Before
    RunsOnClient = yes
    FailJobOnError = yes
  }

  RunScript {
    Command    = "/etc/bareos/scripts/cleanup-dumps.sh"
    RunsWhen   = After
    RunsOnClient = yes
    FailJobOnError = no
  }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Hook Execution Context

Understanding the execution context of hook scripts is critical to writing scripts that actually work. Several common mistakes stem from assuming the wrong context.

### Who runs the script?

The script is executed by the **bareos-fd** (File Daemon) process. In a rootless Podman setup, bareos-fd runs inside a container as the `bareos` user (UID 1001). When it executes a `ClientRunBeforeJob` script, that script runs with the identity of the bareos-fd process.

This has important implications:

1. **The script runs as UID 1001** (the `bareos` system user), not as root.
2. **The script has access to whatever the bareos-fd container can access** — its mounts, its environment variables, its network.
3. **To run `podman` commands against the host's running containers**, the script talks to the host's Podman through the host Podman socket, which Chapter 6 bind-mounts into the bareos-fd container.

### The Podman socket approach

On the **host**, the rootless `bareos` user's Podman API socket lives at:

```
/run/user/1001/podman/podman.sock
```

Chapter 6 bind-mounts that host socket into the bareos-fd container at a fixed in-container path. This is the single `Volume=` line from the `bareos-fd.container` unit:

```ini
# In /home/bareos/.config/containers/systemd/bareos-fd.container
Volume=/run/user/1001/podman/podman.sock:/run/podman/podman.sock
```

So **inside the container the socket is always `/run/podman/podman.sock`**, regardless of the host path. Every hook script that calls `podman` must point the CLI at this in-container socket by exporting `CONTAINER_HOST` near the top:

```bash
export CONTAINER_HOST=unix:///run/podman/podman.sock
```

Setting `CONTAINER_HOST` switches the `podman` CLI into **remote mode** automatically — it stops looking for a local runtime and instead speaks the Podman API over the named socket. With this in place, scripts running inside bareos-fd can issue `podman pause`, `podman exec`, and other commands against the host's container runtime.

### Adding the `podman` CLI to the File Daemon image

There is one catch: the stock `docker.io/bareos/bareos-client:24` image does **not** ship the `podman` CLI, so the hook scripts have nothing to run. Build a small derived image that adds it.

Create a `Containerfile`:

```dockerfile
FROM docker.io/bareos/bareos-client:24
# Install the Podman client so hook scripts can talk to the host socket.
RUN dnf -y install podman && dnf clean all
```

Build and tag it:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 \
  podman build -t localhost/bareos-fd-podman:24 .
```

Then override the File Daemon's image without editing the Chapter 6 unit, using a systemd **drop-in**. Drop-ins are covered in [Chapter 12](./12-quadlet-systemd-deep-dive.md); create `~/.config/containers/systemd/bareos-fd.container.d/10-image.conf`:

```ini
[Container]
Image=localhost/bareos-fd-podman:24
```

Reload and restart the File Daemon so it picks up the derived image:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart bareos-fd.service
```

### Available environment variables

When Bareos executes a RunScript, it can pass several environment variables that scripts may use:

```
BAREOS_JOB_NAME       = name of the current job (e.g., "backup-mariadb")
BAREOS_CLIENT_NAME    = name of the client resource
BAREOS_LEVEL          = backup level (Full, Incremental, Differential)
BAREOS_JOB_ID         = numeric job ID
BAREOS_SINCE          = datetime of last backup
BAREOS_PREVIOUS_JOB_ID = job ID of the last successful backup
```

Not all of these are populated in every context. Several are only set in specific job contexts or for specific levels — for example, `BAREOS_SINCE` and `BAREOS_PREVIOUS_JOB_ID` are only meaningful for Incremental/Differential levels where a prior backup exists, and some variables are populated only for After-scripts (where the final job status is known) rather than Before-scripts. Always default-guard them in scripts (e.g., `${BAREOS_LEVEL:-unknown}`) rather than assuming they are set.

You can use these in your scripts for naming dump files, conditional logic (e.g., only do a full dump on Full-level jobs), or logging.

### Working directory and PATH

The script's working directory is unspecified — do not rely on it. Always use absolute paths in hook scripts.

The `PATH` inside the bareos-fd container may not include all the directories you expect. Always specify the full path to the binaries the **hook script itself** runs — chiefly `podman`:

- Use `/usr/bin/podman` not just `podman`

(The `mariadb-dump` / `pg_dumpall` binaries run *inside the database container* via `podman exec`, so they resolve against that container's `PATH`, not the FD's.)

### Scripts must exist inside the bareos-fd container

This is the single most common source of confusion for new Bareos-on-Podman deployments:

> **The path in `Command = "/etc/bareos/scripts/..."` is a path *inside the bareos-fd container*, not on the host.**

When bareos-fd forks a child process to run your hook script, it resolves that path in the container's own filesystem namespace. A script that exists only on the host is invisible to the container unless that directory is mounted in.

Chapter 6 already mounts the host's `/etc/bareos/scripts/` directory into `bareos-fd.container` read-only, so you do **not** need to add a `Volume=` line for it here. This is the line from the Chapter 6 unit:

```ini
# In /home/bareos/.config/containers/systemd/bareos-fd.container
# Hook scripts; created on the host at /etc/bareos/scripts/ and visible
# inside the container at the same path — the path used in Command=.
Volume=/etc/bareos/scripts:/etc/bareos/scripts:ro,z
```

The `:ro` flag makes the mount read-only (scripts should not modify themselves), and the lowercase `:z` applies a **shared** `container_file_t` label to the host directory so the container can read it (a shared label is correct here because the same directory is mounted into more than one Bareos container). Because the host directory carries `container_file_t`, no manual SELinux labeling of the script files is required.

You can verify the script is visible inside the container:

```bash
podman exec bareos-fd ls -l /etc/bareos/scripts/
```

> **Note on dump output locations:** The dump directory (e.g., `/var/tmp/bareos-dumps/`) referenced in the scripts is a path **inside the bareos-fd container**. The hook script (running as the FD) writes the dump there, and the same FD reads it back when it backs the file up — both the writer and the reader are the File Daemon, so this is an FD-internal path with **no `/hostfs/` prefix**. Only paths that point at the *host* filesystem use the `/hostfs/` prefix (as established in Chapter 6). The FD shares the `bareos-working` volume at `/var/lib/bareos`; if you prefer the dumps to survive container restarts, point `DUMP_DIR` at a subdirectory there (e.g. `/var/lib/bareos/dumps`) instead of the container's ephemeral `/var/tmp`.

### Script must be executable

The hook script file must have the executable bit set (`chmod +x`) and must be readable and executable by UID 1001. If SELinux is enforcing (which it always is in this course), the file must also carry the correct SELinux type. We cover this in detail in Section 11.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Stopping vs Pausing a Container Before Backup

When you need to ensure no new writes happen to a container's data during backup, you have two choices: **stop** the container or **pause** it.

### Stopping a container (`podman stop`)

`podman stop <container>` sends `SIGTERM` to the container's init process, waits for a graceful shutdown timeout (default 10 seconds), then sends `SIGKILL` if the process has not exited.

**Advantages:**
- The container is fully stopped. All database file handles are closed, all buffers are flushed. The on-disk state is completely consistent.
- Bareos can safely copy the raw data files (e.g., the InnoDB tablespace) because no process has them open.

**Disadvantages:**
- The service is down during the entire backup. For large databases, this could mean minutes or hours of unavailability.
- The container must be explicitly restarted after the backup, which requires a `ClientRunAfterJob` hook that runs even if the backup fails.

**When to use:** For small databases, development environments, or services where brief downtime is acceptable.

```bash
# In your hook script:
/usr/bin/podman stop --time 30 mariadb
```

The `--time 30` flag gives the container 30 seconds to shut down gracefully before SIGKILL.

### Restarting after a stop

If you stop a container before backup, you **must** restart it after — even if the backup fails. Bareos's `RunsOnFailure` option controls whether a `RunScript` block executes when the job fails:

```
RunScript {
  Command      = "/etc/bareos/scripts/start-mariadb.sh"
  RunsWhen     = After
  RunsOnClient = yes
  RunsOnSuccess = yes
  RunsOnFailure = yes   # <-- critical: restart even on backup failure
  FailJobOnError = no
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Freezing with `podman pause` for Minimal Downtime

`podman pause <container>` uses Linux's **cgroup freezer** to suspend all processes inside the container. The container is still "running" from the operating system's perspective — its memory is intact, its file descriptors are open, its network connections are maintained — but all CPU execution is suspended. No new writes can happen because no code is running.

### Why pause is better for databases

When you pause a database container:
1. All in-flight transactions are frozen mid-execution
2. No new writes occur
3. The database files on disk are in whatever state they were when the pause happened

This is **not** the same as a clean shutdown. The data files may not be fully flushed. **Therefore, pausing is only useful when combined with a logical dump (mariadb-dump/pg_dump) taken before the pause.** The workflow is:

1. `mariadb-dump` → produces a clean SQL dump while the DB is still running
2. `podman pause mariadb` → freeze the container so no more writes happen while Bareos copies the volume
3. Bareos backs up both the SQL dump file AND the raw volume data
4. `podman unpause mariadb` → resume the container

The SQL dump is your primary recovery artifact. The raw volume copy is a secondary option if you need to restore to an exact point in time without replaying SQL.

### The pause/unpause commands

```bash
# Pause all processes in the container
/usr/bin/podman pause mariadb

# Resume all processes
/usr/bin/podman unpause mariadb

# Check container status (should show "paused")
/usr/bin/podman ps --format "{{.Names}} {{.Status}}"
```

### Verifying pause succeeded

Always check the exit code and verify the container is actually paused before proceeding:

```bash
/usr/bin/podman pause mariadb
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to pause container mariadb" >&2
    exit 1
fi

STATUS=$(/usr/bin/podman inspect --format "{{.State.Status}}" mariadb)
if [ "$STATUS" != "paused" ]; then
    echo "ERROR: Container mariadb is in state '$STATUS', expected 'paused'" >&2
    exit 1
fi
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Database Dump Hooks via `podman exec`

The cleanest way to produce a consistent database dump is to run the dump tool **inside the running container** using `podman exec`. This approach:

1. Uses the database client tools that are already present in the container image (no need to install them on the host)
2. Connects to the database via the container's localhost, bypassing any network firewall rules
3. Runs as the same user context that the database itself uses inside the container

### `podman exec` syntax

```bash
podman exec [OPTIONS] CONTAINER COMMAND [ARGS...]
```

Key options:
- `--env VAR=value` — set environment variables (use this for passwords)
- `--user user` — run command as a specific user inside the container
- `--workdir /path` — set working directory inside container

### MariaDB dump command

```bash
/usr/bin/podman exec \
    mariadb \
    mariadb-dump \
        --password="${MARIADB_ROOT_PASSWORD}" \
        --all-databases \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --source-data=2 \
    > /var/tmp/bareos-dumps/mariadb-all-databases.sql
```

> The MariaDB 24-series image ships the `mariadb-dump` and `mariadb` client binaries. The old `mysqldump` / `mysql` names still exist as compatibility symlinks, but we use the `mariadb-*` names throughout this chapter.

Breaking down the `mariadb-dump` flags:
- `--all-databases` — dump every database in the server
- `--single-transaction` — for InnoDB tables, start a consistent read transaction so the dump is point-in-time consistent without locking the tables for the duration of the dump
- `--routines` — include stored procedures and functions
- `--triggers` — include triggers
- `--events` — include scheduled events
- `--source-data=2` — write the binary log coordinates into the dump as a comment (useful for replication or point-in-time recovery). On MariaDB 10.11+ this is the current spelling; the older `--master-data=2` is a deprecated alias.

> **Not fully lock-free:** `--single-transaction` alone is lock-free for InnoDB, but capturing the binlog coordinates for `--source-data` requires a brief global read lock (`FLUSH TABLES WITH READ LOCK`) at the very start of the dump so the coordinates line up with a single consistent snapshot. The lock is released as soon as the transaction's snapshot is established — typically a fraction of a second — but it is not zero. If you do not need binlog coordinates, drop `--source-data=2` for a genuinely lock-free dump.

### PostgreSQL dump command

```bash
/usr/bin/podman exec \
    --env PGPASSWORD="${PG_PASSWORD}" \
    --user postgres \
    postgres \
    pg_dumpall \
        --clean \
        --if-exists \
    > /var/tmp/bareos-dumps/postgres-all-databases.sql
```

`pg_dumpall` (rather than `pg_dump`) dumps all databases including roles and tablespace definitions, producing a complete server-level dump.

### The output redirection problem

Notice that in the examples above, the output of `podman exec` is redirected to a file in the filesystem of **the shell running the hook script** — that is, inside the `bareos-fd` container, since the hook runs there. The redirect `>` is processed by that outer shell, not by the process inside the database container. This means the dump file lands at `/var/tmp/bareos-dumps/...` in the FD's own filesystem, exactly where the FileSet then reads it back (no `/hostfs/` prefix — see the note in Section 3).

If you instead need the dump file to appear inside the *database* container, you would redirect inside the `podman exec` command:

```bash
/usr/bin/podman exec mariadb \
    sh -c 'mariadb-dump --all-databases > /tmp/dump.sql'
```

But for Bareos hooks, always redirect to the FD-local dump directory so the File Daemon can back it up.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Writing Robust Hook Scripts

A hook script that partially succeeds can be worse than one that completely fails, because Bareos may proceed to back up inconsistent data while you believe the dump was successful. Robust hook scripts follow these principles.

### Principle 1: Exit immediately on any error

Use `set -euo pipefail` at the top of every hook script:

```bash
#!/bin/bash
set -euo pipefail
```

- `set -e` — exit immediately if any command returns a non-zero exit code
- `set -u` — treat unset variables as errors
- `set -o pipefail` — if any command in a pipeline fails, the pipeline's exit code is the failing command's exit code (without this, `false | true` returns 0)

### Principle 2: Log everything

Every significant action should be logged with a timestamp. Bareos captures hook script output and includes it in the job log, so your log messages will be visible in `bconsole` and job reports:

```bash
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting MariaDB dump"
log "Container: ${CONTAINER_NAME}"
log "Dump target: ${DUMP_DIR}"
```

### Principle 3: Validate prerequisites before doing anything

Before running the dump, check that:
- The container is running
- The target dump directory exists and is writable
- Required environment variables are set

```bash
# Check container is running
STATUS=$(/usr/bin/podman inspect --format '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")
if [ "$STATUS" != "running" ]; then
    log "ERROR: Container '${CONTAINER_NAME}' is not running (status: ${STATUS})"
    exit 1
fi

# Check dump directory (this path is inside the bareos-fd container; the
# container is label-disabled, so no SELinux relabel is needed — see Section 11)
if [ ! -d "${DUMP_DIR}" ]; then
    log "Creating dump directory: ${DUMP_DIR}"
    mkdir -p "${DUMP_DIR}"
fi
```

### Principle 4: Use a trap to handle unexpected failures

A `trap` command lets you run cleanup code if the script exits unexpectedly. This is critical for ensuring that a paused container gets unpaused even if the dump command fails:

```bash
CONTAINER_PAUSED=false

cleanup() {
    local exit_code=$?
    if [ "$CONTAINER_PAUSED" = "true" ]; then
        log "Cleanup: unpausing container ${CONTAINER_NAME}"
        /usr/bin/podman unpause "${CONTAINER_NAME}" || true
    fi
    exit $exit_code
}
trap cleanup EXIT
```

### Principle 5: Verify the dump output

After running `mariadb-dump`, always verify that the output file is non-empty and appears valid:

```bash
if [ ! -s "${DUMP_FILE}" ]; then
    log "ERROR: Dump file is empty: ${DUMP_FILE}"
    exit 1
fi

# Check that the dump ends with the expected footer
if ! tail -5 "${DUMP_FILE}" | grep -q "Dump completed"; then
    log "WARNING: Dump file may be incomplete (no completion marker found)"
fi

log "Dump file size: $(du -sh "${DUMP_FILE}" | cut -f1)"
```

### Principle 6: Use timeouts

Long-running dump commands can stall indefinitely if the database is hung. Use `timeout` to prevent the hook from blocking the backup job forever:

```bash
timeout 3600 /usr/bin/podman exec \
    --env MYSQL_PWD="${MARIADB_ROOT_PASSWORD}" \
    "${CONTAINER_NAME}" \
    mariadb-dump --all-databases --single-transaction \
    > "${DUMP_FILE}"
```

This allows the dump up to 1 hour (3600 seconds) before killing it and returning an error.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. MariaDB Dump Hook Script

Below is a complete, production-ready hook script for dumping a MariaDB container before backup. Save this file at `/etc/bareos/scripts/backup-mariadb.sh` on the **host** (it will be accessible inside `bareos-fd` via the bind mount described in Section 3).

```bash
#!/bin/bash
# =============================================================================
# /etc/bareos/scripts/backup-mariadb.sh
#
# Bareos pre-backup hook: dump all MariaDB databases to a temp directory.
#
# This script runs as a ClientRunBeforeJob hook inside the bareos-fd container.
# It connects to the MariaDB container via the host Podman socket and executes
# mariadb-dump inside the container to produce a consistent SQL dump.
#
# Requirements:
#   - Podman socket bind-mounted at /run/podman/podman.sock (inside container)
#     (host path: /run/user/1001/podman/podman.sock → mounted via bareos-fd.container)
#   - MARIADB_ROOT_PASSWORD environment variable set (via bareos-fd env config)
#   - Container named "mariadb" must be running
#
# Exit codes:
#   0 = success, backup can proceed
#   1 = failure, backup should be aborted
# =============================================================================

set -euo pipefail

# Point the podman CLI at the host's Podman API socket (mounted by bareos-fd).
# Setting CONTAINER_HOST switches podman into remote mode automatically.
export CONTAINER_HOST=unix:///run/podman/podman.sock

# ---------------------------------------------------------------------------
# Configuration — adjust these variables for your environment
# ---------------------------------------------------------------------------
CONTAINER_NAME="mariadb"
DUMP_DIR="/var/tmp/bareos-dumps"
DUMP_FILE="${DUMP_DIR}/mariadb-all-databases-$(date '+%Y%m%d-%H%M%S').sql"
LATEST_LINK="${DUMP_DIR}/mariadb-latest.sql"
DUMP_TIMEOUT=3600   # seconds before the dump is killed
PODMAN="/usr/bin/podman"

# ---------------------------------------------------------------------------
# Logging helper
# ---------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [backup-mariadb] $*"
}

# ---------------------------------------------------------------------------
# Trap for cleanup on unexpected exit
# ---------------------------------------------------------------------------
CONTAINER_PAUSED=false

cleanup() {
    local exit_code=$?
    if [ "$CONTAINER_PAUSED" = "true" ]; then
        log "Trap cleanup: unpausing container '${CONTAINER_NAME}'"
        "${PODMAN}" unpause "${CONTAINER_NAME}" 2>/dev/null || \
            log "WARNING: Failed to unpause container during cleanup"
    fi
    if [ $exit_code -ne 0 ]; then
        log "Script exiting with error (exit code: ${exit_code})"
    fi
    exit $exit_code
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
log "=== Bareos MariaDB Pre-Backup Hook Starting ==="
log "Job:    ${BAREOS_JOB_NAME:-unknown}"
log "Level:  ${BAREOS_LEVEL:-unknown}"
log "Client: ${BAREOS_CLIENT_NAME:-unknown}"

# Verify podman is available
if ! command -v "${PODMAN}" >/dev/null 2>&1; then
    log "ERROR: podman binary not found at ${PODMAN}"
    exit 1
fi

# Verify the MariaDB container is running
STATUS=$("${PODMAN}" inspect --format '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")
if [ "$STATUS" != "running" ]; then
    log "ERROR: Container '${CONTAINER_NAME}' is not running (status: '${STATUS}')"
    log "Available containers:"
    "${PODMAN}" ps -a --format "  {{.Names}} [{{.Status}}]" 2>/dev/null || true
    exit 1
fi
log "Container '${CONTAINER_NAME}' is running"

# Verify MARIADB_ROOT_PASSWORD is set
if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
    log "ERROR: MARIADB_ROOT_PASSWORD environment variable is not set"
    log "Set it in the bareos-fd container environment or via bareos-fd.conf"
    exit 1
fi

# Create dump directory if it does not exist
if [ ! -d "${DUMP_DIR}" ]; then
    log "Creating dump directory: ${DUMP_DIR}"
    mkdir -p "${DUMP_DIR}"
fi

# Ensure dump directory is writable
if [ ! -w "${DUMP_DIR}" ]; then
    log "ERROR: Dump directory is not writable: ${DUMP_DIR}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Run the database dump
# ---------------------------------------------------------------------------
log "Starting mariadb-dump to: ${DUMP_FILE}"

# Run mariadb-dump inside the MariaDB container. The output is redirected to
# a file in the bareos-fd container's own filesystem (where this hook runs),
# which the File Daemon then backs up. The MYSQL_PWD environment variable
# passes the password without exposing it in the process list (safer than
# --password= on the command line).
#
# Under `set -e` we must check the dump in the same compound command: a
# separate `DUMP_EXIT=$?` line would never run if the dump failed, because
# the failing pipeline would already have aborted the script. The `if !`
# form keeps error handling inline while letting us clean up on failure.
if ! timeout "${DUMP_TIMEOUT}" "${PODMAN}" exec \
    --env "MYSQL_PWD=${MARIADB_ROOT_PASSWORD}" \
    "${CONTAINER_NAME}" \
    mariadb-dump \
        --all-databases \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --source-data=2 \
        --comments \
        --dump-date \
    > "${DUMP_FILE}"; then
    log "ERROR: mariadb-dump failed"
    # Remove potentially incomplete dump file
    rm -f "${DUMP_FILE}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Validate the dump output
# ---------------------------------------------------------------------------
if [ ! -s "${DUMP_FILE}" ]; then
    log "ERROR: Dump file is empty: ${DUMP_FILE}"
    rm -f "${DUMP_FILE}"
    exit 1
fi

DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)
log "Dump completed successfully"
log "Dump file: ${DUMP_FILE}"
log "Dump size: ${DUMP_SIZE}"

# Create/update a stable symlink so the Bareos FileSet can always reference
# the same path regardless of the timestamp in the filename
ln -sf "${DUMP_FILE}" "${LATEST_LINK}"
log "Updated symlink: ${LATEST_LINK} -> ${DUMP_FILE}"

# ---------------------------------------------------------------------------
# Optional: pause the container to prevent writes during backup
# Uncomment the following block if you want to also back up the raw volume
# files in a frozen state. The cleanup hook (ClientRunAfterJob) will unpause.
# ---------------------------------------------------------------------------
# log "Pausing container '${CONTAINER_NAME}' to prevent writes during backup"
# "${PODMAN}" pause "${CONTAINER_NAME}"
# CONTAINER_PAUSED=true
# PAUSE_STATUS=$("${PODMAN}" inspect --format '{{.State.Status}}' "${CONTAINER_NAME}")
# if [ "$PAUSE_STATUS" != "paused" ]; then
#     log "ERROR: Container is in state '${PAUSE_STATUS}', expected 'paused'"
#     exit 1
# fi
# log "Container paused successfully"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "=== Bareos MariaDB Pre-Backup Hook Completed Successfully ==="
exit 0
```

### Making the script executable and setting ownership

```bash
# Set ownership and permissions
sudo chown bareos:bareos /etc/bareos/scripts/backup-mariadb.sh
sudo chmod 750 /etc/bareos/scripts/backup-mariadb.sh
```

No manual SELinux labeling of the script is needed: Chapter 6 mounts
`/etc/bareos/scripts` into the containers with `:z`, which gives the host
directory the shared `container_file_t` type the File Daemon can read and
execute. See Section 11 for the full SELinux picture.

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. PostgreSQL Dump Hook Script

```bash
#!/bin/bash
# =============================================================================
# /etc/bareos/scripts/backup-postgres.sh
#
# Bareos pre-backup hook: dump all PostgreSQL databases to a temp directory.
#
# This script runs as a ClientRunBeforeJob hook inside the bareos-fd container.
# It uses pg_dumpall inside the PostgreSQL container via podman exec to produce
# a complete server-level dump including roles, tablespaces, and all databases.
#
# Requirements:
#   - Podman socket bind-mounted at /run/podman/podman.sock (inside container)
#     (host path: /run/user/1001/podman/podman.sock → mounted via bareos-fd.container)
#   - POSTGRES_PASSWORD or PGPASSWORD environment variable set
#   - Container named "postgres" must be running
#
# Exit codes:
#   0 = success, backup can proceed
#   1 = failure, backup should be aborted
# =============================================================================

set -euo pipefail

# Point the podman CLI at the host's Podman API socket (mounted by bareos-fd).
# Setting CONTAINER_HOST switches podman into remote mode automatically.
export CONTAINER_HOST=unix:///run/podman/podman.sock

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CONTAINER_NAME="postgres"
PG_USER="postgres"
DUMP_DIR="/var/tmp/bareos-dumps"
DUMP_FILE="${DUMP_DIR}/postgres-all-databases-$(date '+%Y%m%d-%H%M%S').sql"
LATEST_LINK="${DUMP_DIR}/postgres-latest.sql"
DUMP_TIMEOUT=3600
PODMAN="/usr/bin/podman"

# ---------------------------------------------------------------------------
# Logging helper
# ---------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [backup-postgres] $*"
}

# ---------------------------------------------------------------------------
# Trap for cleanup
# ---------------------------------------------------------------------------
CONTAINER_PAUSED=false

cleanup() {
    local exit_code=$?
    if [ "$CONTAINER_PAUSED" = "true" ]; then
        log "Trap cleanup: unpausing container '${CONTAINER_NAME}'"
        "${PODMAN}" unpause "${CONTAINER_NAME}" 2>/dev/null || true
    fi
    exit $exit_code
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
log "=== Bareos PostgreSQL Pre-Backup Hook Starting ==="
log "Job:    ${BAREOS_JOB_NAME:-unknown}"
log "Level:  ${BAREOS_LEVEL:-unknown}"

# Verify podman is available
if ! command -v "${PODMAN}" >/dev/null 2>&1; then
    log "ERROR: podman binary not found at ${PODMAN}"
    exit 1
fi

# Verify the PostgreSQL container is running
STATUS=$("${PODMAN}" inspect --format '{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "missing")
if [ "$STATUS" != "running" ]; then
    log "ERROR: Container '${CONTAINER_NAME}' is not running (status: '${STATUS}')"
    exit 1
fi
log "Container '${CONTAINER_NAME}' is running"

# Verify PGPASSWORD is set
PG_PASSWORD="${PGPASSWORD:-${POSTGRES_PASSWORD:-}}"
if [ -z "${PG_PASSWORD}" ]; then
    log "ERROR: Neither PGPASSWORD nor POSTGRES_PASSWORD environment variable is set"
    exit 1
fi

# Create dump directory if needed
if [ ! -d "${DUMP_DIR}" ]; then
    mkdir -p "${DUMP_DIR}"
fi

if [ ! -w "${DUMP_DIR}" ]; then
    log "ERROR: Dump directory is not writable: ${DUMP_DIR}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Check PostgreSQL is accepting connections
# ---------------------------------------------------------------------------
log "Checking PostgreSQL connectivity..."
if ! timeout 30 "${PODMAN}" exec \
    --env "PGPASSWORD=${PG_PASSWORD}" \
    --user "${PG_USER}" \
    "${CONTAINER_NAME}" \
    pg_isready --quiet; then
    log "ERROR: PostgreSQL is not accepting connections"
    exit 1
fi
log "PostgreSQL is ready"

# ---------------------------------------------------------------------------
# Run pg_dumpall
# ---------------------------------------------------------------------------
log "Starting pg_dumpall to: ${DUMP_FILE}"

# pg_dumpall produces a complete server-level dump:
#   --clean       = include DROP statements before CREATE (idempotent restore)
#   --if-exists   = use IF EXISTS on DROP statements (avoids errors on fresh restore)
#   --no-password = do not prompt for password (use PGPASSWORD env var instead)
# Under `set -e` we check the exit status inline with `if !`: a separate
# `DUMP_EXIT=$?` line would never run on failure, since the failing pipeline
# would already have aborted the script.
if ! timeout "${DUMP_TIMEOUT}" "${PODMAN}" exec \
    --env "PGPASSWORD=${PG_PASSWORD}" \
    --user "${PG_USER}" \
    "${CONTAINER_NAME}" \
    pg_dumpall \
        --clean \
        --if-exists \
        --no-password \
    > "${DUMP_FILE}"; then
    log "ERROR: pg_dumpall failed"
    rm -f "${DUMP_FILE}"
    exit 1
fi

# ---------------------------------------------------------------------------
# Validate dump output
# ---------------------------------------------------------------------------
if [ ! -s "${DUMP_FILE}" ]; then
    log "ERROR: Dump file is empty"
    rm -f "${DUMP_FILE}"
    exit 1
fi

DUMP_SIZE=$(du -sh "${DUMP_FILE}" | cut -f1)
log "Dump completed. File: ${DUMP_FILE}, Size: ${DUMP_SIZE}"

ln -sf "${DUMP_FILE}" "${LATEST_LINK}"
log "Updated symlink: ${LATEST_LINK}"

# ---------------------------------------------------------------------------
# Optional: per-database dumps in custom format (more flexible for restore)
# Uncomment to also produce compressed .dump files per database
# ---------------------------------------------------------------------------
# log "Producing per-database custom-format dumps..."
# "${PODMAN}" exec \
#     --env "PGPASSWORD=${PG_PASSWORD}" \
#     --user "${PG_USER}" \
#     "${CONTAINER_NAME}" \
#     psql --no-password --tuples-only \
#         -c "SELECT datname FROM pg_database WHERE datistemplate = false" \
# | while read -r dbname; do
#     dbname=$(echo "${dbname}" | xargs)
#     [ -z "${dbname}" ] && continue
#     log "  Dumping database: ${dbname}"
#     DBFILE="${DUMP_DIR}/postgres-${dbname}-$(date '+%Y%m%d-%H%M%S').dump"
#     timeout "${DUMP_TIMEOUT}" "${PODMAN}" exec \
#         --env "PGPASSWORD=${PG_PASSWORD}" \
#         --user "${PG_USER}" \
#         "${CONTAINER_NAME}" \
#         pg_dump --format=custom --compress=9 "${dbname}" \
#         > "${DBFILE}"
#     log "  Dumped ${dbname}: $(du -sh "${DBFILE}" | cut -f1)"
# done

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
log "=== Bareos PostgreSQL Pre-Backup Hook Completed Successfully ==="
exit 0
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Cleanup Hooks: Removing Temp Dump Files After Backup

After Bareos has backed up the dump files, they should be removed from the temporary directory to reclaim disk space. This is done with a `ClientRunAfterJob` hook.

```bash
#!/bin/bash
# =============================================================================
# /etc/bareos/scripts/cleanup-dumps.sh
#
# Bareos post-backup hook: remove temporary database dump files.
#
# This script runs as a ClientRunAfterJob hook. It removes dump files older
# than KEEP_HOURS hours from the dump directory. The "latest" symlinks are
# also cleaned up.
#
# This script intentionally does NOT exit with a non-zero code on failure,
# because a cleanup failure should not invalidate an otherwise good backup.
# =============================================================================

set -uo pipefail   # Note: NOT -e (we want to continue on errors)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DUMP_DIR="/var/tmp/bareos-dumps"
KEEP_HOURS=24    # Keep dump files younger than this many hours

# ---------------------------------------------------------------------------
# Logging helper
# ---------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [cleanup-dumps] $*"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "=== Bareos Post-Backup Cleanup Starting ==="
log "Job:   ${BAREOS_JOB_NAME:-unknown}"
log "Level: ${BAREOS_LEVEL:-unknown}"

if [ ! -d "${DUMP_DIR}" ]; then
    log "Dump directory does not exist, nothing to clean: ${DUMP_DIR}"
    exit 0
fi

# Remove files older than KEEP_HOURS
log "Removing dump files older than ${KEEP_HOURS} hours from ${DUMP_DIR}"
REMOVED=0

# Use a while loop with find's -print0 to handle filenames with spaces
while IFS= read -r -d '' file; do
    log "  Removing: ${file}"
    rm -f "${file}" && REMOVED=$((REMOVED + 1)) || \
        log "  WARNING: Failed to remove ${file}"
done < <(find "${DUMP_DIR}" -maxdepth 1 \
    -type f \
    -name "*.sql" \
    -mmin "+$((KEEP_HOURS * 60))" \
    -print0 2>/dev/null)

# Also remove dangling symlinks
while IFS= read -r -d '' link; do
    log "  Removing dangling symlink: ${link}"
    rm -f "${link}" || true
done < <(find "${DUMP_DIR}" -maxdepth 1 -xtype l -print0 2>/dev/null)

log "Cleanup completed. Removed ${REMOVED} file(s)."
log "=== Bareos Post-Backup Cleanup Done ==="
exit 0
```

### Unpause hook (when using pause/unpause workflow)

If you enabled the pause block in the MariaDB dump script, you need a corresponding unpause hook:

```bash
#!/bin/bash
# /etc/bareos/scripts/unpause-containers.sh
# Runs as ClientRunAfterJob to unpause any containers paused by pre-hooks.
set -uo pipefail

# Talk to the host Podman via the mounted socket (remote mode).
export CONTAINER_HOST=unix:///run/podman/podman.sock

CONTAINERS_TO_UNPAUSE="mariadb"  # space-separated list
PODMAN="/usr/bin/podman"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [unpause] $*"; }

log "Unpausing containers: ${CONTAINERS_TO_UNPAUSE}"
for container in ${CONTAINERS_TO_UNPAUSE}; do
    STATUS=$("${PODMAN}" inspect --format '{{.State.Status}}' "${container}" 2>/dev/null || echo "missing")
    if [ "$STATUS" = "paused" ]; then
        "${PODMAN}" unpause "${container}" && log "  Unpaused: ${container}" || \
            log "  WARNING: Failed to unpause: ${container}"
    else
        log "  Container '${container}' is not paused (status: ${STATUS}), skipping"
    fi
done
exit 0
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. SELinux: Labeling Hook Scripts and Temp Directories

SELinux can be a source of mysterious failures with Bareos hooks on RHEL, but in the container-based setup of this course the labeling story is much simpler than the classic RPM deployment. This section explains what actually matters when the File Daemon runs inside a Podman container.

### Why SELinux matters for hooks

When bareos-fd executes a RunScript, it forks a child process that runs your script **inside the bareos-fd container**. SELinux tracks the security context (label) of every process and file. For the hook to work, the policy must allow:

1. The File Daemon to read and execute the script file
2. The script to read/write the dump directory inside the container
3. The script to open and use the mounted Podman socket

The container model handles most of this automatically. The `bareos-fd` container runs with `SecurityLabelDisable=true` (set in Chapter 6), so the File Daemon process is not confined by a per-container SELinux type — there is no `bareos_t` domain or `bareos_script_exec_t` script type to manage. Those types belong to the **RPM** packaging of Bareos and do not apply to the container workflow; do not try to `chcon`/`semanage` them here.

### Labeling hook script files

Hook scripts live on the **host** in `/etc/bareos/scripts/`, which Chapter 6 mounts into the containers with the `:z` flag. That flag tells Podman to apply the shared `container_file_t` type to the directory and its contents, which is exactly the type a container process needs to read and execute the files. So once the scripts are in that directory with the executable bit set, no manual labeling is required:

```bash
# Verify the host directory carries the shared container label.
ls -Z /etc/bareos/scripts/
# Each file should show ...:container_file_t:... (applied by the :z mount)

# If a file was created after the volume was first labeled and shows the
# wrong type, re-trigger the relabel by restarting the container, or label
# the host directory to match:
sudo chcon -Rt container_file_t /etc/bareos/scripts/
```

### Labeling the dump directory

In this course the dump directory (`/var/tmp/bareos-dumps/`) lives **inside the bareos-fd container**, written and read back by the same File Daemon process. Because the container is label-disabled, no host-side SELinux labeling of that path is needed. If you instead point `DUMP_DIR` at the shared `bareos-working` volume (`/var/lib/bareos/...`), Podman already labels that named volume with `container_file_t`, so it stays writable with no extra steps.

You only deal with host SELinux labels when a path genuinely lives on the **host** and is mounted in — and in that case the `:z`/`:Z` mount flag does the labeling for you, as shown for the restore-test container in Lab 10-3.

### Diagnosing SELinux denials

If a hook fails with a mysterious "permission denied", check the host audit log for denials (containerized processes still log AVCs to the host):

```bash
# Show recent SELinux denials (run as root)
sudo ausearch -m avc -ts recent

# More readable explanation of each denial
sudo ausearch -m avc -ts recent | audit2why

# Narrow to container-runtime denials
sudo ausearch -m avc -ts recent -c conmon 2>/dev/null
```

The most common real denial in this workflow is a container being unable to read a bind-mounted host path — the fix is to add the missing `:z` (shared) or `:Z` (private) flag to that `Volume=` line, not to write a custom policy module.

### The permissive debugging approach

If you cannot determine why a mount or socket access is being denied, you can temporarily put the whole system in permissive mode to confirm SELinux is the cause, then revert immediately:

```bash
# Confirm SELinux is the culprit (logs denials but does not block them)
sudo setenforce 0

# Re-run the job, then inspect what would have been denied
sudo ausearch -m avc -ts recent

# Restore enforcing mode as soon as you have the answer
sudo setenforce 1
```

Use this only as a diagnostic. The real fix is almost always a corrected `:z`/`:Z` mount flag, never a permanent permissive domain.

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Logging Hook Output

Understanding where hook output goes is important for debugging and auditing.

### Where stdout and stderr go

When bareos-fd runs a hook script:
- **stdout** (file descriptor 1) is captured by bareos-fd and included in the **job log**, which is stored in the Bareos catalog database and viewable via `bconsole`.
- **stderr** (file descriptor 2) is also captured and included in the job log, usually marked as warnings or errors.

This means every `echo` or `log` call in your hook script appears in the Bareos job report. This is convenient for debugging, but be careful about logging sensitive information (passwords, secret keys) — it would end up in the Bareos catalog.

### Viewing hook output in bconsole

```
*list jobs limit=5
*messages
*show job=<jobid>
```

Or to see the complete job log including script output:

```
*list joblog jobid=<jobid>
```

### Sending hook output to a dedicated log file

If you want a persistent log file in addition to the Bareos job log (useful for operations that happen between Bareos runs):

```bash
LOGFILE="/var/log/bareos/hooks/backup-mariadb.log"
exec > >(tee -a "${LOGFILE}") 2>&1
```

Put this at the top of your script, after the `log()` function definition. It redirects both stdout and stderr to both the terminal (which bareos-fd captures) and the log file simultaneously.

Note that this path is **inside the bareos-fd container** (the FD process writes it). Point it at a directory on the shared `bareos-working` volume if you want the logs to survive container restarts, e.g. `/var/lib/bareos/hooks/`. Create it inside the container:

```bash
podman exec bareos-fd mkdir -p /var/lib/bareos/hooks
```

The `bareos-working` named volume is already labeled `container_file_t` by Podman, so no host-side SELinux labeling is needed.

### Log rotation

If you keep hook logs on the `bareos-working` volume, add a logrotate snippet **inside the bareos-fd container** (the path is container-internal). For example, mount a small logrotate config via the scripts directory or bake it into the derived image, pointing at the volume path:

```
# logrotate config (container-internal path)
/var/lib/bareos/hooks/*.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 640 bareos bareos
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Lab 10-1: Pause/Resume a Container Around a Backup Job

This lab demonstrates the pause/unpause workflow using a simple container. You will configure a Bareos job that pauses an nginx container before backup and unpauses it afterward.

### Prerequisites

- Bareos Director, Storage Daemon, and File Daemon are running as rootless Podman containers (UID 1001)
- The bareos-fd container has the Podman socket bind-mounted
- `XDG_RUNTIME_DIR=/run/user/1001` is set in the bareos user's environment

### Step 1: Start a test container

As the `bareos` user (or via `sudo -u bareos` / `machinectl shell bareos@`):

```bash
# Set the required runtime dir
export XDG_RUNTIME_DIR=/run/user/1001

# Pull and start a simple test container
podman run -d \
    --name test-nginx \
    --publish 8080:80 \
    docker.io/library/nginx:latest

# Verify it is running
podman ps --filter name=test-nginx
```

### Step 2: Create pause/unpause hook scripts

```bash
# Create scripts directory if it does not exist
sudo mkdir -p /etc/bareos/scripts

# Create the pause script
sudo tee /etc/bareos/scripts/pause-test-nginx.sh > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail
export CONTAINER_HOST=unix:///run/podman/podman.sock
PODMAN="/usr/bin/podman"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [pause-nginx] $*"; }
log "Pausing container test-nginx"
"${PODMAN}" pause test-nginx
STATUS=$("${PODMAN}" inspect --format '{{.State.Status}}' test-nginx)
log "Container status: ${STATUS}"
[ "$STATUS" = "paused" ] || { log "ERROR: Expected paused, got ${STATUS}"; exit 1; }
log "Pause successful"
EOF

# Create the unpause script
sudo tee /etc/bareos/scripts/unpause-test-nginx.sh > /dev/null << 'EOF'
#!/bin/bash
set -uo pipefail
export CONTAINER_HOST=unix:///run/podman/podman.sock
PODMAN="/usr/bin/podman"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [unpause-nginx] $*"; }
log "Unpausing container test-nginx"
"${PODMAN}" unpause test-nginx || log "WARNING: unpause returned non-zero"
STATUS=$("${PODMAN}" inspect --format '{{.State.Status}}' test-nginx 2>/dev/null || echo "unknown")
log "Container status: ${STATUS}"
exit 0
EOF

# Make both scripts executable
sudo chmod 750 /etc/bareos/scripts/pause-test-nginx.sh
sudo chmod 750 /etc/bareos/scripts/unpause-test-nginx.sh
sudo chown bareos:bareos /etc/bareos/scripts/*.sh

# No SELinux labeling needed: the :z mount on /etc/bareos/scripts (Chapter 6)
# already gives these files the shared container_file_t type. See Section 11.
```

### Step 3: Configure the Bareos Job

Create a job configuration file at `/etc/bareos/bareos-dir.d/job/backup-test-nginx.conf`:

```
#
# /etc/bareos/bareos-dir.d/job/backup-test-nginx.conf
#
# Job to back up the test-nginx container with pause/unpause hooks.
#
Job {
  Name                = "backup-test-nginx"
  JobDefs             = "DefaultJob"
  Client              = "bareos-fd"
  FileSet             = "FileSet-nginx-data"
  Storage             = "File"
  Pool                = "Full"
  Schedule            = "WeeklyCycle"
  Type                = Backup
  Level               = Incremental

  # Pause the container before backup starts
  RunScript {
    Command        = "/etc/bareos/scripts/pause-test-nginx.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  # Unpause the container after backup completes (runs on success AND failure)
  RunScript {
    Command        = "/etc/bareos/scripts/unpause-test-nginx.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = yes   # Always unpause, even if backup fails
    FailJobOnError = no    # Unpause failure should not fail the job
  }
}
```

### Step 4: Create the FileSet

```
#
# /etc/bareos/bareos-dir.d/fileset/fileset-nginx-data.conf
#
FileSet {
  Name = "FileSet-nginx-data"

  Include {
    Options {
      Signature   = SHA1
      Compression = GZIP
    }
    # Back up the nginx named volume data. This is a HOST path read by the
    # File Daemon, so it carries the /hostfs/ prefix (Chapter 6 convention).
    File = "/hostfs/home/bareos/.local/share/containers/storage/volumes/test-nginx_data/_data"
  }

  Exclude {
    File = "/hostfs/proc"
    File = "/hostfs/sys"
    File = "/hostfs/dev"
  }
}
```

### Step 5: Reload and run the job

```bash
# Reload the Bareos Director configuration
sudo -u bareos bconsole << 'EOF'
reload
status director
EOF

# Run the job
sudo -u bareos bconsole << 'EOF'
run job=backup-test-nginx level=Full yes
wait
messages
EOF
```

### Step 6: Verify the container unpaused

```bash
export XDG_RUNTIME_DIR=/run/user/1001
sudo -u bareos podman inspect --format '{{.State.Status}}' test-nginx
# Expected output: running
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Lab 10-2: Full MariaDB Dump Hook

In this lab you will configure the complete MariaDB dump workflow: the pre-backup dump hook, the Bareos Job configuration, and the post-backup cleanup hook.

### Prerequisites

- A MariaDB container named `mariadb` is running (from earlier chapters)
- The Bareos File Daemon has `MARIADB_ROOT_PASSWORD` available in its environment (the variable name used in `db.env`)

### Step 1: Install the dump hook scripts

```bash
# Create scripts directory
sudo mkdir -p /etc/bareos/scripts

# Copy the backup-mariadb.sh script from Section 8 above
# (Use your text editor or heredoc to create the file)
sudo vim /etc/bareos/scripts/backup-mariadb.sh
# ... paste the script from Section 8 ...

# Copy the cleanup-dumps.sh script from Section 10 above
sudo vim /etc/bareos/scripts/cleanup-dumps.sh

# Set permissions
sudo chown -R bareos:bareos /etc/bareos/scripts/
sudo chmod 750 /etc/bareos/scripts/backup-mariadb.sh
sudo chmod 750 /etc/bareos/scripts/cleanup-dumps.sh

# No SELinux labeling needed: Chapter 6 mounts /etc/bareos/scripts with :z,
# which gives the directory the shared container_file_t type the FD can read.
```

### Step 2: Create the dump directory

The dump directory lives **inside the bareos-fd container** — that is where the hook script writes and where the FD reads it back. The script creates it automatically on first run (`mkdir -p "${DUMP_DIR}"`), but you can pre-create it to confirm it is writable:

```bash
podman exec bareos-fd mkdir -p /var/tmp/bareos-dumps
podman exec bareos-fd ls -ld /var/tmp/bareos-dumps
```

Because the container runs with `SecurityLabelDisable=true`, no host-side SELinux labeling of this path is required. (If you want the dumps to survive container restarts, point `DUMP_DIR` at the `bareos-working` volume instead, e.g. `/var/lib/bareos/dumps`.)

### Step 3: Configure the Bareos Job with RunScript

```
#
# /etc/bareos/bareos-dir.d/job/backup-mariadb.conf
#
# Complete Bareos job configuration for MariaDB container backup.
# This job:
#   1. Runs mariadb-dump inside the container (ClientRunBeforeJob)
#   2. Backs up the SQL dump file + the raw volume data
#   3. Removes old dump files after backup (ClientRunAfterJob)
#
Job {
  Name      = "backup-mariadb"
  JobDefs   = "DefaultJob"
  Client    = "bareos-fd"
  FileSet   = "FileSet-mariadb"
  Storage   = "File"
  Pool      = "Full"
  Schedule  = "WeeklyCycle"
  Type      = Backup

  # -------------------------------------------------------------------------
  # PRE-BACKUP: Run mariadb-dump inside the MariaDB container.
  # FailJobOnError = yes means: if the dump fails, abort the backup.
  # We do NOT want to back up a database that we couldn't dump.
  # -------------------------------------------------------------------------
  RunScript {
    Command        = "/etc/bareos/scripts/backup-mariadb.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  # -------------------------------------------------------------------------
  # POST-BACKUP: Clean up old dump files.
  # FailJobOnError = no means: cleanup failure does not fail the backup job.
  # RunsOnFailure = no means: don't clean up if the backup failed
  #   (you may want to inspect the dump manually).
  # -------------------------------------------------------------------------
  RunScript {
    Command        = "/etc/bareos/scripts/cleanup-dumps.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = no
    FailJobOnError = no
  }
}
```

### Step 4: Configure the FileSet to include the dump

```
#
# /etc/bareos/bareos-dir.d/fileset/fileset-mariadb.conf
#
FileSet {
  Name = "FileSet-mariadb"

  Include {
    Options {
      Signature   = SHA1
      Compression = GZIP
    }

    # The SQL dump produced by the pre-backup hook. This path is INSIDE the
    # bareos-fd container (the FD wrote it and reads it back), so it has NO
    # /hostfs/ prefix — it matches DUMP_DIR in backup-mariadb.sh exactly.
    File = "/var/tmp/bareos-dumps"

    # Raw MariaDB volume data (consistent because we paused the container).
    # This is a HOST path, so it carries the /hostfs/ prefix. Adjust to match
    # your actual named volume.
    File = "/hostfs/home/bareos/.local/share/containers/storage/volumes/bareos_mariadb_data/_data"
  }

  Exclude {
    File = "/hostfs/proc"
    File = "/hostfs/sys"
    File = "/hostfs/dev"
  }
}
```

### Step 5: Run the job and verify the dump is included

```bash
# Start the job
sudo -u bareos bconsole << 'EOF'
run job=backup-mariadb level=Full yes
wait
messages
EOF

# Check that the dump file was created (inside the bareos-fd container)
podman exec bareos-fd ls -lh /var/tmp/bareos-dumps/

# Verify the backup includes the dump file
sudo -u bareos bconsole << 'EOF'
list files jobid=<your-jobid>
EOF

# The output should include lines like:
# /var/tmp/bareos-dumps/mariadb-all-databases-20260224-140000.sql
# /var/tmp/bareos-dumps/mariadb-latest.sql
```

### Step 6: Verify the dump is valid SQL

```bash
# Check the beginning of the dump file (it lives inside the FD container)
podman exec bareos-fd head -5 /var/tmp/bareos-dumps/mariadb-latest.sql
# Expected output starts with a MariaDB dump header, e.g.:
# -- MariaDB dump 10.19  Distrib 10.11.x-MariaDB ...
# -- Host: localhost    Database:
# ...

# Check the end of the dump file
podman exec bareos-fd tail -3 /var/tmp/bareos-dumps/mariadb-latest.sql
# Expected output ends with:
# -- Dump completed on 2026-02-24 14:00:xx
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Lab 10-3: PostgreSQL Dump Hook

This lab follows the same structure as Lab 10-2 but for PostgreSQL. Assuming you have a PostgreSQL container named `postgres` running.

### Step 1: Install the PostgreSQL hook script

```bash
sudo vim /etc/bareos/scripts/backup-postgres.sh
# ... paste the script from Section 9 above ...

sudo chown bareos:bareos /etc/bareos/scripts/backup-postgres.sh
sudo chmod 750 /etc/bareos/scripts/backup-postgres.sh
# No SELinux relabel needed — the :z mount on /etc/bareos/scripts handles it.
```

### Step 2: Configure the Bareos Job

```
#
# /etc/bareos/bareos-dir.d/job/backup-postgres.conf
#
Job {
  Name      = "backup-postgres"
  JobDefs   = "DefaultJob"
  Client    = "bareos-fd"
  FileSet   = "FileSet-postgres"
  Storage   = "File"
  Pool      = "Full"
  Schedule  = "WeeklyCycle"
  Type      = Backup

  RunScript {
    Command        = "/etc/bareos/scripts/backup-postgres.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  RunScript {
    Command        = "/etc/bareos/scripts/cleanup-dumps.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = no
    FailJobOnError = no
  }
}
```

### Step 3: Configure the FileSet

```
#
# /etc/bareos/bareos-dir.d/fileset/fileset-postgres.conf
#
FileSet {
  Name = "FileSet-postgres"

  Include {
    Options {
      Signature   = SHA1
      Compression = GZIP
    }

    # SQL dump produced by the pre-backup hook. FD-internal path, no /hostfs/.
    File = "/var/tmp/bareos-dumps"

    # Raw PostgreSQL volume data — HOST path, so it carries the /hostfs/ prefix.
    File = "/hostfs/home/bareos/.local/share/containers/storage/volumes/bareos_postgres_data/_data"
  }

  Exclude {
    File = "/hostfs/proc"
    File = "/hostfs/sys"
  }
}
```

### Step 4: Run and verify

```bash
sudo -u bareos bconsole << 'EOF'
run job=backup-postgres level=Full yes
wait
messages
EOF

# Verify the dump was created (inside the bareos-fd container) and the job succeeded
podman exec bareos-fd ls -lh /var/tmp/bareos-dumps/postgres-latest.sql
```

### Step 5: Test the PostgreSQL dump is restorable

```bash
# Copy the dump out of the bareos-fd container to a host path the test
# container can mount (the dump lives inside bareos-fd, not on the host).
export XDG_RUNTIME_DIR=/run/user/1001
sudo -u bareos mkdir -p /tmp/pg-restore-test
sudo -u bareos podman cp \
    bareos-fd:/var/tmp/bareos-dumps/postgres-latest.sql \
    /tmp/pg-restore-test/postgres-latest.sql

# Start a temporary PostgreSQL container to test the restore (no -it: this
# is non-interactive). Wait for the server with pg_isready instead of a
# fixed sleep, which is racy on slower hosts.
sudo -u bareos podman run --rm \
    --name postgres-restore-test \
    --env POSTGRES_PASSWORD=testpassword \
    --volume /tmp/pg-restore-test:/dumps:ro,Z \
    docker.io/library/postgres:16 \
    bash -c '
        # Start PostgreSQL in the background
        docker-entrypoint.sh postgres &
        # Wait until it is accepting connections (max ~30s)
        for i in $(seq 1 30); do
            pg_isready -q && break
            sleep 1
        done
        # Restore the dump
        PGPASSWORD=testpassword psql -U postgres < /dumps/postgres-latest.sql
        echo "Restore exit code: $?"
    '
```

The `:Z` mount option in the `--volume` flag tells Podman to apply a private SELinux label to the bind mount, allowing the container to read from it.

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Summary

In this chapter you learned why backup hooks are not optional when backing up containerized databases — they are the mechanism that transforms a crash-inconsistent snapshot into a reliable recovery artifact.

**Key concepts covered:**

- **The consistency problem**: Copying raw database files while the database is running produces unreliable backups. The solution is to use the database's own dump tools (`mariadb-dump`, `pg_dumpall`) to produce a logically consistent export, then back up that export.

- **Bareos RunScript**: The `RunScript` directive (and its shorthands `ClientRunBeforeJob` / `ClientRunAfterJob`) lets you run arbitrary scripts before and after a backup job, either on the client or on the Director.

- **Execution context**: Hook scripts run under the bareos-fd process identity, inside the FD container. They reach the host's Podman by exporting `CONTAINER_HOST=unix:///run/podman/podman.sock` (which switches the CLI to remote mode) and talking to the socket mounted at `/run/podman/podman.sock` inside the container, bind-mounted from the host's `/run/user/1001/podman/podman.sock`. The stock `bareos-client:24` image lacks the `podman` CLI, so a derived image (`localhost/bareos-fd-podman:24`) adds it, wired in via a systemd drop-in.

- **Stop vs pause**: `podman stop` gives a clean shutdown but causes downtime. `podman pause` uses the cgroup freezer for near-zero-downtime freezing, but should be combined with a logical dump since the raw files may not be clean.

- **Robust scripts**: Always use `set -euo pipefail`, validate prerequisites, use traps for cleanup, verify dump output, and use timeouts.

- **SELinux**: In the container workflow there is no `bareos_t` domain or `bareos_script_exec_t` type to manage — the FD container is label-disabled, and the `:z` mount on `/etc/bareos/scripts` gives the scripts the shared `container_file_t` type. The real fix for a denial is almost always a corrected `:z`/`:Z` mount flag, not a custom policy. Use `ausearch -m avc` to diagnose.

- **Complete workflow (MariaDB)**:
  1. `ClientRunBeforeJob` → `backup-mariadb.sh` → runs `mariadb-dump` inside container → saves to `/var/tmp/bareos-dumps/`
  2. Bareos backs up the dump file + raw volume data
  3. `ClientRunAfterJob` → `cleanup-dumps.sh` → removes old dump files

**Next chapter**: [Chapter 11](./11-podman-image-export.md) covers backing up and restoring the container images themselves — ensuring you can not only restore your data but also recreate the exact container environment that ran it.

---

[↑ Back to Table of Contents](#table-of-contents)

© 2026 UncleJS — Licensed under CC BY-NC-SA 4.0
