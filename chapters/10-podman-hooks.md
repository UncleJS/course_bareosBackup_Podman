# Chapter 10: Pre- and Post-Job Hooks for Container-Aware Backups

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
  - [Labeling the Podman socket for bareos-fd access](#labeling-the-podman-socket-for-bareos-fd-access)
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
3. Container restarts change the environment entirely — environment variables like `MYSQL_ROOT_PASSWORD` that were only present at container creation are gone unless re-injected.

### The solution: hooks

Bareos provides a **RunScript** mechanism that lets you run arbitrary shell commands or scripts before and after a backup job. This is how you solve the consistency problem:

**Before the backup:**
1. Run `mysqldump` inside the running MariaDB container to produce a complete, logically consistent SQL dump
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

    # Whether to run this script during a Dry Run
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
3. **To run `podman` commands against the host's running containers**, the script must either:
   - Be mounted into the bareos-fd container and call `podman` via the Podman socket, or
   - Use a bind-mounted Podman socket (`/run/user/1001/podman/podman.sock`) from the host

### The Podman socket approach

In a rootless Podman environment, the Podman daemon listens on a Unix socket at:

```
/run/user/1001/podman/podman.sock
```

This socket allows any process with filesystem access to it (and correct SELinux context) to send Podman API commands. The `podman` CLI uses this socket when the environment variable `DOCKER_HOST` points to it, or when `CONTAINER_HOST` is set, or simply when the socket is at the default location for the current user.

When your bareos-fd container has this socket bind-mounted, scripts running inside it can issue `podman pause`, `podman exec`, and other commands against the host's container runtime.

### Available environment variables

When Bareos executes a RunScript, it passes several environment variables that scripts can use:

```
BAREOS_JOB_NAME       = name of the current job (e.g., "backup-mariadb")
BAREOS_CLIENT_NAME    = name of the client resource
BAREOS_LEVEL          = backup level (Full, Incremental, Differential)
BAREOS_JOB_ID         = numeric job ID
BAREOS_SINCE          = datetime of last backup (for incremental)
BAREOS_PREVIOUS_JOB_ID = job ID of the last successful backup
```

You can use these in your scripts for naming dump files, conditional logic (e.g., only do a full dump on Full-level jobs), or logging.

### Working directory and PATH

The script's working directory is unspecified — do not rely on it. Always use absolute paths in hook scripts.

The `PATH` inside the bareos-fd container may not include all the directories you expect. Always specify the full path to binaries:

- Use `/usr/bin/podman` not just `podman`
- Use `/usr/bin/mysqldump` not just `mysqldump`

### Scripts must exist inside the bareos-fd container

This is the single most common source of confusion for new Bareos-on-Podman deployments:

> **The path in `Command = "/etc/bareos/scripts/..."` is a path *inside the bareos-fd container*, not on the host.**

When bareos-fd forks a child process to run your hook script, it resolves that path in the container's own filesystem namespace. A script that exists only on the host at `/etc/bareos/scripts/backup-mariadb.sh` is completely invisible to the container unless you bind-mount that directory in.

The recommended approach is to bind-mount the host's `/etc/bareos/scripts/` directory into `bareos-fd.container`:

```ini
# In /home/bareos/.config/containers/systemd/bareos-fd.container

[Container]
# ... other directives ...

# Bind-mount hook scripts from host into the container (read-only).
# Scripts created on the host at /etc/bareos/scripts/ are then
# available inside the container at /etc/bareos/scripts/ — the
# same path referenced in RunScript Command= directives.
Volume=/etc/bareos/scripts:/etc/bareos/scripts:ro,Z
```

The `:ro` flag makes the mount read-only (scripts should not modify themselves), and `:Z` applies the correct SELinux label for container access.

After adding this `Volume=` line, run:

```bash
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart bareos-fd.service
```

You can then verify the script is visible inside the container:

```bash
podman exec bareos-fd ls -l /etc/bareos/scripts/
```

> **Note:** The dump output directories (e.g., `/var/tmp/bareos-dumps/`) referenced in the scripts also need to be bind-mounted into `bareos-fd.container` with **write** access (`:rw,Z`), otherwise the script cannot create dump files:
>
> ```ini
> Volume=/var/tmp/bareos-dumps:/var/tmp/bareos-dumps:rw,Z
> ```

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

This is **not** the same as a clean shutdown. The data files may not be fully flushed. **Therefore, pausing is only useful when combined with a logical dump (mysqldump/pg_dump) taken before the pause.** The workflow is:

1. `mysqldump` → produces a clean SQL dump while the DB is still running
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
    --env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" \
    mariadb \
    mysqldump \
        --all-databases \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --flush-logs \
        --master-data=2 \
    > /var/tmp/bareos-dumps/mariadb-all-databases.sql
```

Breaking down the `mysqldump` flags:
- `--all-databases` — dump every database in the server
- `--single-transaction` — for InnoDB tables, start a consistent read transaction so the dump is point-in-time consistent without locking tables
- `--routines` — include stored procedures and functions
- `--triggers` — include triggers
- `--events` — include scheduled events
- `--flush-logs` — flush the binary log before dumping (useful for point-in-time recovery)
- `--master-data=2` — write the binary log position as a comment (useful for replication or PITR)

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

Notice that in the examples above, the output of `podman exec` is redirected to a file on the **host** (the machine running the hook script). The redirect `>` is processed by the shell running the hook script, not by the process inside the container. This means the dump file appears on the host filesystem, in a location that Bareos can then back up — which is exactly what we want.

If you need the dump file to appear inside the container for some reason, you would redirect inside the `podman exec` command:

```bash
/usr/bin/podman exec mariadb \
    sh -c 'mysqldump --all-databases > /tmp/dump.sql'
```

But for Bareos hooks, always redirect to a path on the host.

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

# Check dump directory
if [ ! -d "${DUMP_DIR}" ]; then
    log "Creating dump directory: ${DUMP_DIR}"
    mkdir -p "${DUMP_DIR}"
    # Apply SELinux label (see Section 11)
    /usr/sbin/restorecon -Rv "${DUMP_DIR}" 2>/dev/null || true
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

After running `mysqldump`, always verify that the output file is non-empty and appears valid:

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
    --env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" \
    "${CONTAINER_NAME}" \
    mysqldump --all-databases --single-transaction \
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
# It connects to the MariaDB container via the Podman socket and executes
# mysqldump inside the container to produce a consistent SQL dump.
#
# Requirements:
#   - Podman socket bind-mounted at /run/podman/podman.sock (inside container)
#     (host path: /run/user/1001/podman/podman.sock → mounted via bareos-fd.container)
#   - MYSQL_ROOT_PASSWORD environment variable set (via bareos-fd env config)
#   - Container named "mariadb" must be running
#
# Exit codes:
#   0 = success, backup can proceed
#   1 = failure, backup should be aborted
# =============================================================================

set -euo pipefail

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

# Verify MYSQL_ROOT_PASSWORD is set
if [ -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
    log "ERROR: MYSQL_ROOT_PASSWORD environment variable is not set"
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
log "Starting mysqldump to: ${DUMP_FILE}"

# Run mysqldump inside the MariaDB container. The output is redirected to
# a file on the host (the machine running this hook script). The MYSQL_PWD
# environment variable passes the password without exposing it in the
# process list (safer than --password= on the command line).
timeout "${DUMP_TIMEOUT}" "${PODMAN}" exec \
    --env "MYSQL_PWD=${MYSQL_ROOT_PASSWORD}" \
    "${CONTAINER_NAME}" \
    mysqldump \
        --all-databases \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --flush-logs \
        --comments \
        --dump-date \
    > "${DUMP_FILE}"

DUMP_EXIT=$?
if [ $DUMP_EXIT -ne 0 ]; then
    log "ERROR: mysqldump failed with exit code ${DUMP_EXIT}"
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

# Apply SELinux label (see Section 11 for full explanation)
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/backup-mariadb.sh
```

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
timeout "${DUMP_TIMEOUT}" "${PODMAN}" exec \
    --env "PGPASSWORD=${PG_PASSWORD}" \
    --user "${PG_USER}" \
    "${CONTAINER_NAME}" \
    pg_dumpall \
        --clean \
        --if-exists \
        --no-password \
    > "${DUMP_FILE}"

DUMP_EXIT=$?
if [ $DUMP_EXIT -ne 0 ]; then
    log "ERROR: pg_dumpall failed with exit code ${DUMP_EXIT}"
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
done < <(find "${DUMP_DIR}" -maxdepth 1 -type l ! -e -print0 2>/dev/null)

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

SELinux is the most common source of mysterious failures with Bareos hooks on RHEL. When a hook script fails silently, or when `podman exec` inside a hook returns "permission denied", SELinux is usually the cause. This section explains the labeling requirements thoroughly.

### Why SELinux matters for hooks

When bareos-fd executes a RunScript, it forks a child process that runs your script. SELinux tracks the security context (label) of every process and every file. For the execution to succeed, the SELinux policy must allow:

1. The bareos-fd process domain to execute the script file's type
2. The script (running in bareos-fd's domain) to read/write the dump directory
3. The script to open and use the Podman socket
4. The script to write to `/var/tmp/bareos-dumps/`

### Labeling hook script files

Hook scripts should be labeled with `bareos_script_exec_t` (if the Bareos SELinux policy defines this type) or `bin_t` as a fallback. On RHEL 10 with the standard `bareos` SELinux policy package:

```bash
# Check current label
ls -Z /etc/bareos/scripts/backup-mariadb.sh

# Apply the correct label
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/backup-mariadb.sh
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/backup-postgres.sh
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/cleanup-dumps.sh
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/unpause-containers.sh

# Make the label persistent across restorecon operations
sudo semanage fcontext -a -t bareos_script_exec_t \
    '/etc/bareos/scripts(/.*)?'

# Apply the policy to all files in the directory
sudo restorecon -Rv /etc/bareos/scripts/
```

### Labeling the dump directory

The dump directory at `/var/tmp/bareos-dumps/` needs to be writable by the bareos-fd process. The `/var/tmp/` directory has type `tmp_t` by default, which bareos-fd can write to. However, if you create a dedicated directory elsewhere, label it appropriately:

```bash
# Create the dump directory
sudo mkdir -p /var/tmp/bareos-dumps

# Set ownership
sudo chown bareos:bareos /var/tmp/bareos-dumps
sudo chmod 750 /var/tmp/bareos-dumps

# The default tmp_t type on /var/tmp/ is usually sufficient.
# Verify the label:
ls -Zd /var/tmp/bareos-dumps

# If it shows an unexpected type, restore it:
sudo restorecon -Rv /var/tmp/bareos-dumps
```

If you choose a path outside `/var/tmp/`, you will need to add a custom file context:

```bash
# Example: using /srv/bareos-dumps/ instead
sudo mkdir -p /srv/bareos-dumps
sudo semanage fcontext -a -t bareos_var_t '/srv/bareos-dumps(/.*)?'
sudo restorecon -Rv /srv/bareos-dumps
sudo chown bareos:bareos /srv/bareos-dumps
```

### Labeling the Podman socket for bareos-fd access

For hook scripts running inside the bareos-fd container to access the host Podman socket, the socket must be accessible. When you bind-mount the socket into the bareos-fd container via Quadlet, Podman handles much of this, but you may still need to set the socket's SELinux type:

```bash
# Check the socket's label
ls -Z /run/user/1001/podman/podman.sock

# The socket should have type container_runtime_t or user_runtime_t
# If you see an unexpected type, relabel:
sudo chcon -t container_runtime_t /run/user/1001/podman/podman.sock
```

### Diagnosing SELinux denials

When a hook fails with a mysterious "permission denied" or simply returns a non-zero exit code without explanation, check for SELinux denials:

```bash
# Show recent SELinux denials (run as root)
sudo ausearch -m avc -ts recent

# More readable format
sudo ausearch -m avc -ts recent | audit2why

# Check for denials in the last 10 minutes involving bareos
sudo ausearch -m avc -ts recent -c bareos 2>/dev/null

# Generate an allow rule suggestion (do NOT blindly apply in production)
sudo ausearch -m avc -ts recent | audit2allow
```

### The permissive debugging approach

If you cannot determine why a script is failing, temporarily set the bareos SELinux domain to permissive while testing:

```bash
# Set only the bareos_t domain to permissive (does not affect rest of system)
sudo semanage permissive -a bareos_t

# Test your hook script
sudo -u bareos /etc/bareos/scripts/backup-mariadb.sh

# Check what would have been denied
sudo ausearch -m avc -ts recent | grep bareos

# When done, remove the permissive exception
sudo semanage permissive -d bareos_t
```

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
*list jobs last=5
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

Create the log directory:

```bash
sudo mkdir -p /var/log/bareos/hooks
sudo chown bareos:bareos /var/log/bareos/hooks
sudo chmod 750 /var/log/bareos/hooks
sudo semanage fcontext -a -t bareos_log_t '/var/log/bareos/hooks(/.*)?'
sudo restorecon -Rv /var/log/bareos/hooks
```

### Log rotation

Add a logrotate configuration for hook logs:

```
# /etc/logrotate.d/bareos-hooks
/var/log/bareos/hooks/*.log {
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

# Apply SELinux labels
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/pause-test-nginx.sh
sudo chcon -t bareos_script_exec_t /etc/bareos/scripts/unpause-test-nginx.sh
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
    # Back up the nginx named volume data
    File = "/home/bareos/.local/share/containers/storage/volumes/test-nginx_data/_data"
  }

  Exclude {
    File = "/proc"
    File = "/sys"
    File = "/dev"
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
- The Bareos File Daemon has `MYSQL_ROOT_PASSWORD` available in its environment

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

# SELinux labels
sudo semanage fcontext -a -t bareos_script_exec_t '/etc/bareos/scripts(/.*)?'
sudo restorecon -Rv /etc/bareos/scripts/
```

### Step 2: Create the dump directory

```bash
sudo mkdir -p /var/tmp/bareos-dumps
sudo chown bareos:bareos /var/tmp/bareos-dumps
sudo chmod 750 /var/tmp/bareos-dumps

# The default tmp_t label on /var/tmp should be inherited
ls -Zd /var/tmp/bareos-dumps
```

### Step 3: Configure the Bareos Job with RunScript

```
#
# /etc/bareos/bareos-dir.d/job/backup-mariadb.conf
#
# Complete Bareos job configuration for MariaDB container backup.
# This job:
#   1. Runs mysqldump inside the container (ClientRunBeforeJob)
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
  # PRE-BACKUP: Run mysqldump inside the MariaDB container.
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

    # The SQL dump produced by the pre-backup hook
    # This is a symlink; Bareos will follow it to the actual timestamped file
    File = "/var/tmp/bareos-dumps/mariadb-latest.sql"

    # Also back up all timestamped dump files (belt-and-suspenders)
    File = "/var/tmp/bareos-dumps"

    # Raw MariaDB volume data (consistent because we paused the container)
    # Adjust this path to match your actual named volume
    File = "/home/bareos/.local/share/containers/storage/volumes/bareos_mariadb_data/_data"
  }

  Exclude {
    File = "/proc"
    File = "/sys"
    File = "/dev"
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

# Check that the dump file was created
ls -lh /var/tmp/bareos-dumps/

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
# Check the beginning of the dump file
head -5 /var/tmp/bareos-dumps/mariadb-latest.sql
# Expected output starts with:
# -- MySQL dump 10.19  Distrib ...
# -- Host: localhost    Database:
# ...

# Check the end of the dump file
tail -3 /var/tmp/bareos-dumps/mariadb-latest.sql
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
sudo restorecon /etc/bareos/scripts/backup-postgres.sh
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

    # SQL dump produced by the pre-backup hook
    File = "/var/tmp/bareos-dumps/postgres-latest.sql"
    File = "/var/tmp/bareos-dumps"

    # Raw PostgreSQL volume data
    File = "/home/bareos/.local/share/containers/storage/volumes/bareos_postgres_data/_data"
  }

  Exclude {
    File = "/proc"
    File = "/sys"
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

# Verify the dump was created and the job succeeded
ls -lh /var/tmp/bareos-dumps/postgres-*.sql
```

### Step 5: Test the PostgreSQL dump is restorable

```bash
# Start a temporary PostgreSQL container to test the restore
export XDG_RUNTIME_DIR=/run/user/1001
sudo -u bareos podman run --rm -it \
    --name postgres-restore-test \
    --env POSTGRES_PASSWORD=testpassword \
    --volume /var/tmp/bareos-dumps:/dumps:ro,Z \
    docker.io/library/postgres:16 \
    bash -c '
        # Start PostgreSQL in the background
        docker-entrypoint.sh postgres &
        sleep 5
        # Restore the dump
        PGPASSWORD=testpassword psql -U postgres < /dumps/postgres-latest.sql
        echo "Restore exit code: $?"
    '
```

The `:Z` mount option in the `--volume` flag tells Podman to automatically apply the correct SELinux label to the bind mount, allowing the container to read from it.

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Summary

In this chapter you learned why backup hooks are not optional when backing up containerized databases — they are the mechanism that transforms a crash-inconsistent snapshot into a reliable recovery artifact.

**Key concepts covered:**

- **The consistency problem**: Copying raw database files while the database is running produces unreliable backups. The solution is to use the database's own dump tools (`mysqldump`, `pg_dumpall`) to produce a logically consistent export, then back up that export.

- **Bareos RunScript**: The `RunScript` directive (and its shorthands `ClientRunBeforeJob` / `ClientRunAfterJob`) lets you run arbitrary scripts before and after a backup job, either on the client or on the Director.

- **Execution context**: Hook scripts run under the bareos-fd process identity. In a rootless Podman setup, they access containers via the Podman socket (`/run/podman/podman.sock` inside the bareos-fd container, bind-mounted from the host's `/run/user/1001/podman/podman.sock`).

- **Stop vs pause**: `podman stop` gives a clean shutdown but causes downtime. `podman pause` uses the cgroup freezer for near-zero-downtime freezing, but should be combined with a logical dump since the raw files may not be clean.

- **Robust scripts**: Always use `set -euo pipefail`, validate prerequisites, use traps for cleanup, verify dump output, and use timeouts.

- **SELinux**: Hook scripts need the `bareos_script_exec_t` type. Dump directories need to be writable by the bareos-fd domain. Use `ausearch -m avc` to diagnose denials.

- **Complete workflow (MariaDB)**:
  1. `ClientRunBeforeJob` → `backup-mariadb.sh` → runs `mysqldump` inside container → saves to `/var/tmp/bareos-dumps/`
  2. Bareos backs up the dump file + raw volume data
  3. `ClientRunAfterJob` → `cleanup-dumps.sh` → removes old dump files

**Next chapter**: [Chapter 11](./11-podman-image-export.md) covers backing up and restoring the container images themselves — ensuring you can not only restore your data but also recreate the exact container environment that ran it.

---

[↑ Back to Table of Contents](#table-of-contents)
