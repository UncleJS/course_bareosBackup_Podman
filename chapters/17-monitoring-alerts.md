# Chapter 17: Monitoring, Alerting, and Reporting

## Table of Contents

- [1. Why Backup Monitoring is Mission-Critical](#1-why-backup-monitoring-is-mission-critical)
  - [Silent Failure Scenarios](#silent-failure-scenarios)
  - [The Minimum Viable Monitoring Stack](#the-minimum-viable-monitoring-stack)
- [2. Bareos Built-In Reporting: Job Summary Emails](#2-bareos-built-in-reporting-job-summary-emails)
  - [Anatomy of a Bareos Job Summary Email](#anatomy-of-a-bareos-job-summary-email)
  - [Mail-Always vs Mail-On-Error](#mail-always-vs-mail-on-error)
- [3. Configuring Messages Resources in Bareos](#3-configuring-messages-resources-in-bareos)
  - [Message Destination Types](#message-destination-types)
  - [Message Types](#message-types)
  - [Complete Messages Resource Configurations](#complete-messages-resource-configurations)
  - [Message Subject Line Customization](#message-subject-line-customization)
- [4. Setting Up Email Delivery from Containers](#4-setting-up-email-delivery-from-containers)
  - [Option A: msmtp (Recommended for Simple Setups)](#option-a-msmtp-recommended-for-simple-setups)
  - [Option B: Postfix on the Host as an SMTP Relay](#option-b-postfix-on-the-host-as-an-smtp-relay)
- [5. Bareos bconsole Status Commands](#5-bareos-bconsole-status-commands)
  - [Accessing bconsole](#accessing-bconsole)
  - [Director Status](#director-status)
  - [Storage Daemon Status](#storage-daemon-status)
  - [File Daemon (Client) Status](#file-daemon-client-status)
  - [Listing Jobs](#listing-jobs)
  - [Listing Volumes](#listing-volumes)
  - [Listing Files in a Job](#listing-files-in-a-job)
  - [The `messages` Command](#the-messages-command)
  - [Useful One-Liners for Scripts](#useful-one-liners-for-scripts)
- [6. Bareos WebUI: Deploying as a Quadlet Container](#6-bareos-webui-deploying-as-a-quadlet-container)
  - [Architecture](#architecture)
  - [Creating the WebUI Director User](#creating-the-webui-director-user)
  - [Quadlet File for bareos-webui](#quadlet-file-for-bareos-webui)
  - [WebUI Configuration File](#webui-configuration-file)
  - [Starting the WebUI Service](#starting-the-webui-service)
  - [Accessing the WebUI](#accessing-the-webui)
  - [Reverse Proxy with nginx for Remote Access](#reverse-proxy-with-nginx-for-remote-access)
- [7. Parsing Bareos Job Logs for Key Metrics](#7-parsing-bareos-job-logs-for-key-metrics)
  - [Log Location](#log-location)
  - [Key Metrics to Extract](#key-metrics-to-extract)
  - [Shell Script for Metric Extraction](#shell-script-for-metric-extraction)
- [8. Prometheus Integration: bareos-exporter](#8-prometheus-integration-bareos-exporter)
  - [What bareos-exporter Exposes](#what-bareos-exporter-exposes)
  - [Quadlet for bareos-exporter](#quadlet-for-bareos-exporter)
  - [Starting the Exporter](#starting-the-exporter)
  - [Prometheus Scrape Configuration](#prometheus-scrape-configuration)
  - [Prometheus Alert Rules for Bareos](#prometheus-alert-rules-for-bareos)
- [9. Grafana Dashboard for Bareos](#9-grafana-dashboard-for-bareos)
  - [Quadlet for Prometheus + Grafana Stack](#quadlet-for-prometheus-grafana-stack)
  - [Recommended Grafana Dashboard Panels](#recommended-grafana-dashboard-panels)
- [10. systemd Journal Monitoring](#10-systemd-journal-monitoring)
  - [Basic Journal Commands](#basic-journal-commands)
  - [Persistent Journal Configuration](#persistent-journal-configuration)
  - [Journal Pattern Alerting with systemd-journal-remote](#journal-pattern-alerting-with-systemd-journal-remote)
  - [Simple Journal-Based Alert Pattern](#simple-journal-based-alert-pattern)
- [11. Health Check Script for Bareos Director](#11-health-check-script-for-bareos-director)
  - [The Health Check Script](#the-health-check-script)
  - [systemd Service for Continuous Health Monitoring](#systemd-service-for-continuous-health-monitoring)
- [12. Alertmanager Integration for PagerDuty/Slack/Email](#12-alertmanager-integration-for-pagerdutyslackemail)
  - [Alertmanager Quadlet](#alertmanager-quadlet)
  - [Alertmanager Configuration](#alertmanager-configuration)
- [13. Backup SLA Reporting Script](#13-backup-sla-reporting-script)
  - [Scheduling the SLA Report](#scheduling-the-sla-report)
- [14. Centralized Syslog with rsyslog Forwarding](#14-centralized-syslog-with-rsyslog-forwarding)
  - [Configuring rsyslog on RHEL 10](#configuring-rsyslog-on-rhel-10)
- [15. SELinux: Allowing Email and Prometheus Ports](#15-selinux-allowing-email-and-prometheus-ports)
  - [Allow Container Connections to SMTP](#allow-container-connections-to-smtp)
  - [Allow Container Ports for Prometheus Exporter](#allow-container-ports-for-prometheus-exporter)
  - [Allow Grafana and Prometheus Ports](#allow-grafana-and-prometheus-ports)
  - [Allow Rootless Containers to Bind to Non-Privileged Ports](#allow-rootless-containers-to-bind-to-non-privileged-ports)
  - [Checking for SELinux Denials](#checking-for-selinux-denials)
  - [SELinux File Contexts for Monitoring Scripts](#selinux-file-contexts-for-monitoring-scripts)
- [16. Lab 17-1: Configure Email Summaries for Every Job](#16-lab-17-1-configure-email-summaries-for-every-job)
  - [Step 1: Prepare msmtp](#step-1-prepare-msmtp)
  - [Step 2: Write the Messages Resource Configuration](#step-2-write-the-messages-resource-configuration)
  - [Step 3: Ensure Jobs Reference the Standard Messages Resource](#step-3-ensure-jobs-reference-the-standard-messages-resource)
  - [Step 4: Reload and Test](#step-4-reload-and-test)
  - [Step 5: Verify Email Was Sent](#step-5-verify-email-was-sent)
- [17. Lab 17-2: Deploy bareos-webui as a Quadlet Container](#17-lab-17-2-deploy-bareos-webui-as-a-quadlet-container)
  - [Step 1: Create the WebUI Configuration Volume](#step-1-create-the-webui-configuration-volume)
  - [Step 2: Write Configuration Files](#step-2-write-configuration-files)
  - [Step 3: Add WebUI User to Director](#step-3-add-webui-user-to-director)
  - [Step 4: Write and Deploy the Quadlet File](#step-4-write-and-deploy-the-quadlet-file)
  - [Step 5: Verify Access](#step-5-verify-access)
- [18. Lab 17-3: Deploy bareos-exporter with Prometheus and Grafana](#18-lab-17-3-deploy-bareos-exporter-with-prometheus-and-grafana)
  - [Step 1: Create Required Volumes](#step-1-create-required-volumes)
  - [Step 2: Write Prometheus Configuration](#step-2-write-prometheus-configuration)
  - [Step 3: Deploy All Four Quadlet Services](#step-3-deploy-all-four-quadlet-services)
  - [Step 4: Start All Services](#step-4-start-all-services)
  - [Step 5: Verify Metrics Collection](#step-5-verify-metrics-collection)
  - [Step 6: Configure Grafana](#step-6-configure-grafana)
  - [Step 7: Verify Alertmanager (Optional)](#step-7-verify-alertmanager-optional)
- [19. Summary](#19-summary)

## 1. Why Backup Monitoring is Mission-Critical

A backup system that runs silently in the background and occasionally fails without anyone noticing is worse than no backup system at all. It creates a dangerous false sense of security: administrators believe data is protected when it is not.

### Silent Failure Scenarios

Silent failures in backup systems are alarmingly common. Here are real-world scenarios where backups fail without obvious indication:

**Scenario 1: The full disk that nobody noticed.**
The storage volume at `/srv/bareos-storage/volumes` fills up. The Storage Daemon marks jobs as failed. But because nobody configured email alerts, the failures accumulate for three months. When a ransomware attack hits, the team discovers the last successful backup was 90 days ago.

**Scenario 2: The credential rotation.**
A database password is rotated as part of a security audit. The Bareos File Daemon still uses the old password for the database pre-backup script. Every database backup silently captures an empty dump. Nobody checks the backup sizes. Six months later, a database corruption event reveals that all "backups" contain 0 bytes of database data.

**Scenario 3: The SELinux denial.**
A RHEL system upgrade changes SELinux policy. The File Daemon can no longer read a critical application directory because a new SELinux boolean was introduced. Backups complete without error — they just skip the denied files silently. `audit.log` has the answers, but nobody is monitoring it.

**Scenario 4: The growing incremental.**
An application starts generating large amounts of temporary data in a directory that is included in the FileSet. Incrementals that used to take 5 minutes now take 4 hours. They overlap with the next night's backup, causing jobs to queue. Eventually jobs start timing out. Storage fills faster than expected.

**Scenario 5: The missed window.**
A backup job is supposed to run at 23:00 every night. A system load spike (cron job, kernel update, antivirus scan) delays the job start by 2 hours. The job runs until 07:00, well into business hours, impacting system performance. Nobody has a report showing backup jobs that ran outside their scheduled window.

### The Minimum Viable Monitoring Stack

For a production Bareos deployment on RHEL 10 + Podman, you need at minimum:

1. **Email notification** for every job completion (success and failure)
2. **bconsole health check** integrated with your existing monitoring (Nagios, Zabbix, Prometheus)
3. **Job log retention** with search capability (systemd journal or syslog)
4. **Weekly SLA report** showing jobs that ran late, ran too long, or backed up fewer files than expected

Optional but strongly recommended:
- Prometheus metrics + Grafana dashboards
- Alertmanager for PagerDuty/Slack/email routing

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Bareos Built-In Reporting: Job Summary Emails

Bareos has a built-in mechanism to send email reports for every backup job. This is configured through the **Messages** resource. Before diving into the configuration, it helps to understand what the email report contains.

### Anatomy of a Bareos Job Summary Email

A typical email subject line looks like:

```
Bareos: myserver-fd-sd Full OK -- Files=98,234 Bytes=4,234,234,123 Termination: OK
```

The email body contains a complete job summary:

```
Bareos 24.0.1 (01Jun24): ...

  Build OS:               x86_64-pc-linux-gnu gnu
  JobId:                  42
  Job:                    Backup-Linux-Monthly.2025-07-06_01.00.01
  Backup Level:           Full
  Client:                 "myserver-fd" 24.0.1 (01Jun24) x86_64-pc-linux-gnu,gnu,...
  FileSet:                "LinuxAll-Advanced" 2025-06-01 12:00:01
  Pool:                   "Monthly" (From Job resource)
  Catalog:                "MyCatalog" (From Client resource)
  Storage:                "FileStorage" (From Job resource)
  Scheduled time:         06-Jul-2025 01:00:01
  Start time:             06-Jul-2025 01:00:15
  End time:               06-Jul-2025 02:34:56
  Elapsed time:           1 hour 34 mins 41 secs
  Priority:               9
  FD Files Written:       98,234
  SD Files Written:       98,234
  FD Bytes Written:       4,234,234,123 (4.234 GB)
  SD Bytes Written:       4,234,234,123 (4.234 GB)
  Rate:                   45,678 KB/s
  Software Compression:   GZIP 42.3%
  VSS:                    no
  Encryption:             no
  Accurate:               no
  Volume name(s):         Monthly-2025-07-0001
  Volume Session Id:      1
  Volume Session Time:    1720224015
  Last Volume Bytes:      4,234,234,123 (4.234 GB)
  Non-fatal FD errors:    0
  SD Errors:              0
  FD termination status:  OK
  SD termination status:  OK
  Termination:            Backup OK
```

### Mail-Always vs Mail-On-Error

Two common email strategies:

**`mail on all`** — sends an email for every job, regardless of outcome. This is appropriate for small environments where every job is reviewed. Becomes noise in large environments running hundreds of jobs daily.

**`mail on error`** — only sends email when a job ends with a non-OK status (errors, warnings, or cancellation). In large environments this is the preferred approach, combined with a weekly summary report.

**Best practice**: Configure `mail on error` for routine jobs and `mail always` for the Monthly/Yearly full backups.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. Configuring Messages Resources in Bareos

The **Messages** resource is one of the most important and most misunderstood resources in Bareos. It controls not just email, but all log destinations. Every Director, Storage Daemon, and File Daemon has its own Messages resource.

### Message Destination Types

| Destination | Syntax | Purpose |
|---|---|---|
| `mail` | `mail = addr = subject` | Send email to address with subject |
| `mail on error` | `mail on error = addr = subject` | Email only on error/warning |
| `mail on success` | `mail on success = addr = subject` | Email only on success |
| `append` | `append = /path/to/file = message-types` | Append to a log file |
| `file` | `file = /path/to/file = message-types` | Write to a log file (overwrite) |
| `syslog` | `syslog = facility.level` | Send to syslog |
| `director` | `director = name = message-types` | Forward to Director's messages |
| `stderr` | `stderr = message-types` | Write to stderr |
| `stdout` | `stdout = message-types` | Write to stdout |
| `catalog` | `catalog = message-types` | Store in catalog database |
| `console` | `console = message-types` | Display in bconsole |

### Message Types

| Type | Description |
|---|---|
| `info` | Informational messages |
| `warning` | Non-fatal warnings |
| `error` | Error messages |
| `fatal` | Fatal errors |
| `terminate` | Daemon termination messages |
| `debug` | Debug messages |
| `audit` | Security audit messages |
| `skipped` | Files skipped during backup |
| `restored` | Files restored |
| `notsaved` | Files that could not be saved |
| `all` | All message types |
| `!skipped` | All types EXCEPT skipped |

### Complete Messages Resource Configurations

```hcl
# /etc/bareos/bareos-dir.d/messages/Standard.conf
# ─────────────────────────────────────────────────────────────────
# Standard Messages resource for the Director.
# Used by most Jobs for normal operation.
# ─────────────────────────────────────────────────────────────────

Messages {
  Name = "Standard"

  # ── Mail Destinations ─────────────────────────────────────────

  # Send full job report email for every job.
  # Replace backup-alerts@example.com with your actual address.
  Mail = "backup-alerts@example.com" = all, !skipped, !restored
  # "all" includes info, warning, error, fatal, terminate, etc.
  # "!skipped" suppresses verbose "skipped files" lines which can
  # make the email very long for large FileSets with many exclusions.
  # "!restored" suppresses "file restored" lines during restore jobs.

  # Send a SECOND email only if there were errors.
  # This goes to a pager/on-call address that needs immediate attention.
  Mail On Error = "oncall@example.com" = error, fatal
  # Only sends if the job encountered actual errors — not just warnings.

  # ── Catalog ───────────────────────────────────────────────────

  # Store important messages in the catalog database.
  # This allows viewing them in bconsole and WebUI.
  Catalog = all, !skipped, !restored, !debug

  # ── Console Output ────────────────────────────────────────────

  # Display informational messages in bconsole during job execution.
  # Useful for interactive sessions — does not generate files/emails.
  Console = warning, error, fatal, terminate

  # ── Append to Log File ────────────────────────────────────────

  # Append all messages to a persistent log file inside the container.
  # This log is available via: podman exec bareos-dir cat /var/log/bareos/bareos.log
  Append = "/var/log/bareos/bareos.log" = all, !skipped, !restored

  # ── Operator Messages ─────────────────────────────────────────

  # Operator messages are sent for events requiring human action:
  # mount requests, tape changes, etc. In a disk-only setup these
  # are rare, but it's good practice to configure this destination.
  Operator = "backup-admin@example.com" = mount
  # "mount" means: a storage device needs to be mounted (volume needed).
}
```

```hcl
# /etc/bareos/bareos-dir.d/messages/Daemon.conf
# ─────────────────────────────────────────────────────────────────
# Messages resource for Director daemon-level events
# (startup, shutdown, config reload, etc.)
# ─────────────────────────────────────────────────────────────────

Messages {
  Name = "Daemon"

  # Email on daemon-level errors (Director crash, config error, etc.)
  Mail On Error = "backup-alerts@example.com" = error, fatal, terminate

  # Always write daemon events to the log
  Append = "/var/log/bareos/bareos.log" = all, !skipped, !restored

  # Store in catalog
  Catalog = all, !skipped, !restored

  Console = all, !skipped, !restored
}
```

```hcl
# /etc/bareos/bareos-sd.d/messages/Standard.conf
# ─────────────────────────────────────────────────────────────────
# Storage Daemon Messages resource.
# SD messages are forwarded to the Director by default.
# ─────────────────────────────────────────────────────────────────

Messages {
  Name = "Standard"

  # Forward all SD messages to the Director's logging system.
  # The Director then routes them according to its Messages resources.
  Director = bareos-dir = all
  # "bareos-dir" must match the Director's Name in bareos-sd.d/director/

  # Also log locally for debugging
  Append = "/var/log/bareos/bareos-sd.log" = all, !skipped, !restored
  Syslog = daemon.warning = error, fatal
}
```

```hcl
# /etc/bareos/bareos-fd.d/messages/Standard.conf
# ─────────────────────────────────────────────────────────────────
# File Daemon Messages resource.
# FD messages are forwarded to the Director.
# ─────────────────────────────────────────────────────────────────

Messages {
  Name = "Standard"

  Director = bareos-dir = all
  Append   = "/var/log/bareos/bareos-fd.log" = all, !skipped, !restored
  Syslog   = daemon.warning = error, fatal
}
```

### Message Subject Line Customization

You can customize the email subject using a format string. Add the `mail command` directive:

```hcl
# In the Director's bareos-dir.conf or a separate messages resource file:
Messages {
  Name = "Standard"
  # ...

  # Custom mail command — uses sendmail-compatible interface.
  # %r = recipient, %s = job status, %c = client name, %d = director name
  Mail Command = "/usr/sbin/sendmail -F \"Bareos\" -h %r"

  # Or with msmtp:
  Mail Command = "/usr/bin/msmtp -a default %r"

  # The subject line is built from the first line of the message body.
  # Bareos prepends it automatically. You can set a custom subject prefix
  # using the job name and status in the Mail destination:
  Mail = "backup-alerts@example.com" = all, !skipped
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Setting Up Email Delivery from Containers

Bareos containers need to send email via SMTP. Since the containers run rootless under the `bareos` user, we need a lightweight SMTP relay that can send email without running a full MTA daemon.

### Option A: msmtp (Recommended for Simple Setups)

`msmtp` is a minimal SMTP client that reads a config file and sends email. It is installed inside the Director container or available via a sidecar approach.

**Approach**: Create a custom Director image that includes msmtp, or inject the binary via a bind mount.

For this course, we use a bind mount to inject a pre-installed msmtp binary and configuration into the Director container.

```bash
# On the RHEL 10 host — install msmtp to a location we can bind into the container
sudo dnf install -y msmtp

# Create the msmtp config file for the bareos user
mkdir -p /home/bareos/.config/bareos/msmtp
cat > /home/bareos/.config/bareos/msmtp/msmtprc << 'MSMTPCONF'
# msmtp configuration for Bareos email delivery
# Permissions must be 600: chmod 600 ~/.config/bareos/msmtp/msmtprc

defaults
  auth           on
  tls            on
  tls_trust_file /etc/ssl/certs/ca-bundle.crt
  logfile        /var/log/bareos/msmtp.log

account        smtp-relay
  host           smtp.example.com
  port           587
  from           bareos@example.com
  user           bareos@example.com
  password       YOUR_SMTP_PASSWORD_HERE
  # Replace with your SMTP credentials.
  # For Gmail: use an App Password, not your regular password.
  # For Office 365: enable SMTP AUTH in Exchange admin, use port 587.

account default : smtp-relay
MSMTPCONF

chmod 600 /home/bareos/.config/bareos/msmtp/msmtprc
chown bareos:bareos /home/bareos/.config/bareos/msmtp/msmtprc
```

**Update the Director Quadlet to mount msmtp**:

```ini
# /home/bareos/.config/containers/systemd/bareos-dir.container
# (Add these lines to the existing [Container] section)

# Inject msmtp binary from host
Volume=/usr/bin/msmtp:/usr/bin/msmtp:ro,Z

# Inject msmtp configuration
Volume=/home/bareos/.config/bareos/msmtp/msmtprc:/etc/msmtprc:ro,Z

# Mount msmtp config to /root/.msmtprc as well (Bareos runs as root inside container)
Volume=/home/bareos/.config/bareos/msmtp/msmtprc:/root/.msmtprc:ro,Z
```

After updating the Quadlet, restart the Director:

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user restart bareos-dir
```

**Test email delivery from inside the container**:

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  sh -c 'echo "Test email from Bareos Director" | msmtp backup-alerts@example.com'
```

### Option B: Postfix on the Host as an SMTP Relay

For environments with an existing Postfix relay on RHEL 10, configure Bareos to use `localhost:25`.

```bash
# Install Postfix on RHEL 10 host
sudo dnf install -y postfix
sudo systemctl enable --now postfix

# Configure Postfix as a relay host
sudo postconf -e "relayhost = [smtp.example.com]:587"
sudo postconf -e "smtp_use_tls = yes"
sudo postconf -e "smtp_sasl_auth_enable = yes"
sudo postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
sudo postconf -e "smtp_sasl_security_options = noanonymous"

# Create SASL credentials file
echo "[smtp.example.com]:587 bareos@example.com:YOUR_PASSWORD" | \
  sudo tee /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd

# Reload Postfix
sudo postfix reload
```

Then update the Director container to use the host's Postfix. Since the container is in a Podman network, you need to use the host IP reachable from the container (`host.containers.internal`):

```hcl
# In bareos-dir.d/messages/Standard.conf
Messages {
  Name = "Standard"
  Mail Command = "/usr/sbin/sendmail -F Bareos -h %r"
  # sendmail inside the container should point to the host relay.
  # Add a SendMail binary or symlink that calls:
  #   /usr/bin/msmtp --host=host.containers.internal --port=25 %r
  ...
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Bareos bconsole Status Commands

`bconsole` is the primary command-line interface for the Bareos Director. Understanding its status commands is essential for day-to-day operations and troubleshooting.

### Accessing bconsole

```bash
# As bareos user
XDG_RUNTIME_DIR=/run/user/1001 podman exec -it bareos-dir bconsole
```

### Director Status

```
*status director
```

Output includes:
- Director version and start time
- Number of jobs running, waiting, and completed
- Scheduled jobs for the next 24 hours
- Memory usage
- Catalog connection status

```
The Director daemon is OK.

Director Version: 24.0.1 (01 Jun 2024) x86_64-pc-linux-gnu
Daemon started 06-Jul-2025 00:00:01. Jobs: run=42, running=0
 Heap: heap=356,352 smbytes=206,952 max_bytes=4,423,112 bufs=189 max_bufs=401
 Res: njobs=8 nclients=2 nstores=1 npools=5 ncats=1 nfsets=2 nscheds=5

Scheduled Jobs:
Level          Type     Pri  Scheduled          Job Name           Volume
===================================================================================
Incremental    Backup    10  07-Jul-2025 23:00  Backup-Linux-Daily  *
Differential   Backup    10  13-Jul-2025 23:00  Backup-Linux-Weekly *
Full           Backup     9  06-Jul-2025 01:00  Backup-Linux-Monthly*
====

Running Jobs:
No Jobs running.

No jobs are running.
====
```

### Storage Daemon Status

```
*status storage=FileStorage
```

Output shows:
- SD version and uptime
- All Device resources and their current status (Idle/Reading/Writing)
- Volume currently mounted in each device
- Current job being written (if any)

```
Connecting to Storage daemon FileStorage at bareos-sd:9103

bareos-sd Version: 24.0.1 (01 Jun 2024) x86_64-pc-linux-gnu
Daemon started 06-Jul-2025 00:00:05. Jobs: run=42, waiting=0, running=0

Device status:
Device "FileStorage" (/var/lib/bareos/storage) is not open.
   Available space: 487 GB

No jobs are running.
====
```

### File Daemon (Client) Status

```
*status client=myserver-fd
```

Output shows:
- FD version and uptime
- Currently running jobs (if any)
- Last job that ran on this client

### Listing Jobs

```
# All recent jobs (default: last 50)
*list jobs

# Filter by client
*list jobs client=myserver-fd

# Filter by status
*list jobs jobstatus=E     # Error jobs
*list jobs jobstatus=T     # Terminated OK
*list jobs jobstatus=W     # Terminated with warnings
*list jobs jobstatus=A     # Cancelled/Aborted

# Filter by time window
*list jobs days=7          # Jobs from last 7 days

# See details of a specific job
*list jobid=42
*list joblog jobid=42      # Full log of job 42
```

### Listing Volumes

```
# All volumes
*list volumes

# Volumes in a specific pool
*list volumes pool=Daily

# Details of a specific volume
*list volume=Daily-2025-07-04-0001
```

### Listing Files in a Job

```
# List files backed up in job 42
*list files jobid=42

# Query where a specific file was backed up
*query
```

### The `messages` Command

After running bconsole commands, pending messages (from running or recently completed jobs) can be displayed:

```
*messages
```

This shows any messages that haven't been delivered yet — useful during interactive sessions.

### Useful One-Liners for Scripts

```bash
# Check if Director is alive (returns 0 on success)
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<< "status director" | grep -q "daemon is OK"

# Count failed jobs in last 24 hours
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<< "list jobs days=1" | grep -c " E "

# Get last successful backup time for a client
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<< "list jobs client=myserver-fd jobstatus=T" | tail -3
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Bareos WebUI: Deploying as a Quadlet Container

Bareos WebUI is a PHP-based web application that provides a graphical interface for job monitoring, restore operations, and configuration review. It communicates with the Bareos Director's Director API (BSOCK on port 9101) using a dedicated WebUI user.

### Architecture

```
Browser → nginx → bareos-webui (PHP/Apache) → Director :9101
                                               ↓
                                          Catalog (MariaDB)
```

The WebUI itself is stateless — it simply translates web requests to bconsole API calls. All state lives in the Director/catalog.

### Creating the WebUI Director User

First, create a Console resource in the Director configuration that the WebUI will authenticate as:

```hcl
# /etc/bareos/bareos-dir.d/console/webui-admin.conf

Console {
  Name     = "admin"
  Password = "WebUI_Admin_Password_Change_Me"
  # This password is also set in the WebUI's configuration file.

  Profile  = "webui-admin"
  # Profiles define what commands the console can run.
  # "webui-admin" is a built-in profile that ships with Bareos.
}
```

```hcl
# /etc/bareos/bareos-dir.d/profile/webui-admin.conf
# This file is usually included with Bareos — verify it exists.

Profile {
  Name = "webui-admin"
  # Grants access to the commands needed by WebUI.
  Command ACL = !.bvfs_clear_cache, !.exit, !.sql, !configure, !create,
                !delete, !purge, !prune, !sqlquery, !umount, !unmount,
                *all*
  # Deny dangerous commands from the WebUI, allow everything else.

  Job ACL     = *all*
  Client ACL  = *all*
  Storage ACL = *all*
  Schedule ACL = *all*
  Pool ACL    = *all*
  FileSet ACL = *all*
  Catalog ACL = *all*
  Where ACL   = *all*
  Plugin Options ACL = *all*
}
```

After adding these files, reload the Director:

```bash
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<< "reload"
```

### Quadlet File for bareos-webui

```ini
# /home/bareos/.config/containers/systemd/bareos-webui.container
# ─────────────────────────────────────────────────────────────────
# Bareos WebUI container (Quadlet / systemd user service)
# Bareos 24 · RHEL 10 · Rootless Podman
# ─────────────────────────────────────────────────────────────────

[Unit]
Description=Bareos WebUI
Documentation=https://docs.bareos.org
After=network-online.target bareos-dir.service
Requires=bareos-dir.service
# WebUI depends on the Director being up.

[Container]
Image=docker.io/bareos/bareos-webui:24
ContainerName=bareos-webui

# Connect to the same Podman network as the Director so it can reach bareos-dir.
Network=bareos.network

# ── Volume Mounts ────────────────────────────────────────────────

# WebUI configuration volume (contains directors.ini and bareos.ini)
Volume=bareos-webui-config:/etc/bareos-webui:Z
# Named volume; data path:
# ~/.local/share/containers/storage/volumes/bareos-webui-config/_data/

# ── Environment ──────────────────────────────────────────────────

# Pass the Director connection details via environment variables.
# The WebUI image reads these to build its directors.ini automatically.
Environment=BAREOS_DIRECTOR_HOST=bareos-dir
Environment=BAREOS_DIRECTOR_PORT=9101
Environment=BAREOS_WEBUI_USER=admin
# Password comes from the secrets file (mode 600)
EnvironmentFile=/home/bareos/.config/bareos/bareos.env

# ── Port Publishing ───────────────────────────────────────────────

# Bind only to localhost — put a reverse proxy (nginx) in front for TLS.
# Direct exposure of HTTP to the network is a security risk.
PublishPort=127.0.0.1:9100:80

# ── Security ─────────────────────────────────────────────────────

# Drop all Linux capabilities the web server doesn't need.
PodmanArgs=--cap-drop=ALL --cap-add=CHOWN --cap-add=SETUID --cap-add=SETGID --cap-add=NET_BIND_SERVICE

[Service]
Restart=always
RestartSec=10
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
```

### WebUI Configuration File

The WebUI reads its Director connection settings from `/etc/bareos-webui/directors.ini`:

```ini
# ~/.local/share/containers/storage/volumes/bareos-webui-config/_data/directors.ini
# ─────────────────────────────────────────────────────────────────
# Bareos WebUI Director Configuration
# ─────────────────────────────────────────────────────────────────

[director1]
enabled           = "yes"
diraddress        = "bareos-dir"
# Container hostname within the bareos.network Podman network.

dirport           = 9101
# Director's console API port.

tls_verify_peer   = false
# For internal container-to-container communication, TLS peer
# verification can be relaxed. In production with external access,
# set up proper TLS certificates and enable this.

catalog           = "MyCatalog"
# The catalog name as defined in bareos-dir.d/catalog/

pam_console_name  = ""
pam_console_password = ""
# Leave empty if not using PAM authentication.
```

```ini
# ~/.local/share/containers/storage/volumes/bareos-webui-config/_data/bareos.ini
# ─────────────────────────────────────────────────────────────────
# WebUI application settings
# ─────────────────────────────────────────────────────────────────

[session]
# Session timeout in seconds (900 = 15 minutes)
timeout = 900

[tables]
# Number of rows per page in job/volume/client tables
pagination = 25

[theme]
name = "bareos"
# Available themes: bareos, default

[restore]
filetree_refresh_timeout = 120
# Timeout for file tree refresh during restore wizard (seconds).

[experimental]
maintabs = "off"
```

### Starting the WebUI Service

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now bareos-webui
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user status bareos-webui
```

### Accessing the WebUI

Navigate to `http://localhost:9100` in a browser on the RHEL 10 host. Log in with:
- Username: `admin`
- Password: the value of `BAREOS_WEBUI_PASSWORD` from `bareos.env`

### Reverse Proxy with nginx for Remote Access

For access from other machines with HTTPS:

```nginx
# /etc/nginx/conf.d/bareos-webui.conf
server {
    listen 443 ssl;
    server_name bareos.example.com;

    ssl_certificate     /etc/pki/tls/certs/bareos.crt;
    ssl_certificate_key /etc/pki/tls/private/bareos.key;

    location / {
        proxy_pass         http://127.0.0.1:9100;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Parsing Bareos Job Logs for Key Metrics

Raw job logs from Bareos contain valuable metrics. Whether you're building a custom dashboard, feeding data into a SIEM, or just auditing backups, knowing how to extract key fields is essential.

### Log Location

Job logs are stored in the Bareos catalog and also written to the log file inside the container:

```bash
# Read the Director log
XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  tail -100 /var/log/bareos/bareos.log

# Or via systemd journal (from the host)
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-dir --since "1 hour ago"
```

### Key Metrics to Extract

From the job summary email/log, the following fields are useful for monitoring:

| Field | Regex Pattern | Example Value |
|---|---|---|
| Job ID | `JobId:\s+(\d+)` | `42` |
| Job Status | `Termination:\s+(.+)` | `Backup OK` |
| Files Written | `FD Files Written:\s+([\d,]+)` | `98,234` |
| Bytes Written | `FD Bytes Written:\s+([\d,]+)` | `4,234,234,123` |
| Elapsed Time | `Elapsed time:\s+(.+)` | `1 hour 34 mins 41 secs` |
| Rate | `Rate:\s+([\d,]+) KB/s` | `45,678 KB/s` |
| Errors | `SD Errors:\s+(\d+)` | `0` |
| Non-fatal Errors | `Non-fatal FD errors:\s+(\d+)` | `0` |

### Shell Script for Metric Extraction

```bash
#!/usr/bin/env bash
# /home/bareos/scripts/extract-job-metrics.sh
# Extracts key metrics from a Bareos job log entry.
# Usage: ./extract-job-metrics.sh <jobid>

set -euo pipefail

JOBID="${1:?Usage: $0 <jobid>}"

# Get the job log from bconsole
JOB_LOG=$(XDG_RUNTIME_DIR=/run/user/1001 podman exec bareos-dir \
  bconsole <<EOF
list joblog jobid=${JOBID}
quit
EOF
)

# Extract fields
STATUS=$(echo "$JOB_LOG"    | grep -oP 'Termination:\s+\K.+')
FILES=$(echo "$JOB_LOG"     | grep -oP 'FD Files Written:\s+\K[\d,]+')
BYTES=$(echo "$JOB_LOG"     | grep -oP 'FD Bytes Written:\s+\K[\d,]+')
ELAPSED=$(echo "$JOB_LOG"   | grep -oP 'Elapsed time:\s+\K.+')
RATE=$(echo "$JOB_LOG"      | grep -oP 'Rate:\s+\K[\d,]+(?= KB/s)')
SD_ERRORS=$(echo "$JOB_LOG" | grep -oP 'SD Errors:\s+\K\d+')
FD_ERRORS=$(echo "$JOB_LOG" | grep -oP 'Non-fatal FD errors:\s+\K\d+')

echo "JobId:       ${JOBID}"
echo "Status:      ${STATUS}"
echo "Files:       ${FILES}"
echo "Bytes:       ${BYTES}"
echo "Elapsed:     ${ELAPSED}"
echo "Rate(KB/s):  ${RATE}"
echo "SD Errors:   ${SD_ERRORS}"
echo "FD Errors:   ${FD_ERRORS}"

# Exit with error if job failed
if [[ "$STATUS" != "Backup OK" ]]; then
  echo "ALERT: Job ${JOBID} did not complete successfully!"
  exit 1
fi
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Prometheus Integration: bareos-exporter

The `bareos-exporter` project exposes Bareos job and volume metrics as a Prometheus `/metrics` endpoint. This integrates Bareos into any existing Prometheus-based monitoring stack (Prometheus + Alertmanager + Grafana).

### What bareos-exporter Exposes

Key metrics exported:

| Metric | Labels | Description |
|---|---|---|
| `bareos_jobs_total` | `status`, `type`, `level` | Total jobs by outcome |
| `bareos_job_bytes` | `client`, `job_name` | Bytes backed up per job |
| `bareos_job_files` | `client`, `job_name` | Files backed up per job |
| `bareos_job_duration_seconds` | `client`, `job_name` | Job duration in seconds |
| `bareos_last_job_timestamp` | `client`, `job_name` | Unix timestamp of last job |
| `bareos_volume_bytes` | `pool`, `volume` | Bytes used per volume |
| `bareos_pool_volumes_total` | `pool`, `status` | Volume count per pool/status |

### Quadlet for bareos-exporter

```ini
# /home/bareos/.config/containers/systemd/bareos-exporter.container
# ─────────────────────────────────────────────────────────────────
# bareos-exporter: Prometheus metrics exporter for Bareos
# Project: https://github.com/vierbergenlars/bareos_exporter
#   (or whichever implementation you choose — several exist)
# ─────────────────────────────────────────────────────────────────

[Unit]
Description=Bareos Prometheus Exporter
After=bareos-dir.service bareos-db.service
Requires=bareos-dir.service

[Container]
Image=docker.io/barcus/bareos-exporter:latest
# Alternatively: ghcr.io/some-org/bareos-exporter:latest
# Pin to a specific version in production to avoid unexpected updates.
ContainerName=bareos-exporter

Network=bareos.network

# Connection details for the Bareos catalog database.
# The exporter queries the MariaDB catalog directly for efficiency.
Environment=BAREOS_DB_HOST=bareos-db
Environment=BAREOS_DB_PORT=3306
Environment=BAREOS_DB_NAME=bareos
Environment=BAREOS_DB_USER=bareos
EnvironmentFile=/home/bareos/.config/bareos/db.env
# db.env must contain: BAREOS_DB_PASSWORD=<password>
# Ensure this file is mode 600.

# The exporter listens on port 9625 by default.
PublishPort=127.0.0.1:9625:9625

[Service]
Restart=always
RestartSec=10
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
```

### Starting the Exporter

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now bareos-exporter

# Verify metrics endpoint
curl -s http://localhost:9625/metrics | head -40
```

### Prometheus Scrape Configuration

```yaml
# /home/bareos/prometheus/prometheus.yml
# ─────────────────────────────────────────────────────────────────
# Prometheus configuration for Bareos monitoring
# ─────────────────────────────────────────────────────────────────

global:
  scrape_interval:     60s   # Bareos metrics don't change frequently
  evaluation_interval: 60s
  external_labels:
    environment: 'production'
    host: 'bareos-server'

# Alertmanager connection (configured in Section 12)
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

# Load alert rules from files
rule_files:
  - "bareos_alerts.yml"

scrape_configs:
  # ── Bareos Exporter ──────────────────────────────────────────
  - job_name: 'bareos'
    scrape_interval: 60s
    scrape_timeout:  30s
    static_configs:
      - targets: ['localhost:9625']
        labels:
          service: 'bareos-backup'
    # Relabeling: keep all metrics, no filtering needed.
    # The exporter handles metric naming correctly.

  # ── Prometheus Self-Monitoring ───────────────────────────────
  - job_name: 'prometheus'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:9090']

  # ── Node Exporter (RHEL 10 host metrics) ────────────────────
  - job_name: 'node'
    scrape_interval: 15s
    static_configs:
      - targets: ['localhost:9100']
        labels:
          host: 'bareos-server'
```

### Prometheus Alert Rules for Bareos

```yaml
# /home/bareos/prometheus/bareos_alerts.yml
# ─────────────────────────────────────────────────────────────────
# Prometheus alert rules for Bareos backup monitoring
# ─────────────────────────────────────────────────────────────────

groups:
  - name: bareos_backup_alerts
    interval: 5m
    rules:

      # ── Job Failure Alert ──────────────────────────────────────
      - alert: BareosJobFailed
        expr: increase(bareos_jobs_total{status="Error"}[1h]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Bareos backup job failed"
          description: "{{ $value }} backup job(s) have failed in the last hour."

      # ── No Recent Backup Alert ─────────────────────────────────
      - alert: BareosNoRecentBackup
        expr: (time() - bareos_last_job_timestamp{status="OK"}) > 86400
        # Alert if the last successful job is more than 24 hours ago.
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "No successful Bareos backup in 24 hours"
          description: "Client {{ $labels.client }} has not had a successful backup for {{ $value | humanizeDuration }}."

      # ── Pool Volume Shortage ───────────────────────────────────
      - alert: BareosPoolRunningLow
        expr: bareos_pool_volumes_total{status="Purged"} < 2
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Bareos pool {{ $labels.pool }} has fewer than 2 recyclable volumes"
          description: "Pool {{ $labels.pool }} may run out of available volumes soon."

      # ── Large Backup Size Anomaly ─────────────────────────────
      - alert: BareosAbnormallyLargeBackup
        expr: |
          bareos_job_bytes
          > 2 * avg_over_time(bareos_job_bytes[7d])
        for: 0m
        labels:
          severity: warning
        annotations:
          summary: "Bareos backup size anomaly detected"
          description: "Job {{ $labels.job_name }} backed up {{ $value | humanizeBytes }}, more than 2x the 7-day average."

      # ── Exporter Down ─────────────────────────────────────────
      - alert: BareosExporterDown
        expr: up{job="bareos"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Bareos exporter is not responding"
          description: "The bareos-exporter at localhost:9625 is unreachable. Backup metrics are unavailable."
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Grafana Dashboard for Bareos

Grafana visualizes Prometheus metrics. The following describes the key panels for a Bareos operations dashboard.

### Quadlet for Prometheus + Grafana Stack

```ini
# /home/bareos/.config/containers/systemd/prometheus.container

[Unit]
Description=Prometheus Time Series Database
After=network-online.target

[Container]
Image=docker.io/prom/prometheus:latest
ContainerName=prometheus
Network=bareos.network

Volume=bareos-prometheus-config:/etc/prometheus:Z
Volume=bareos-prometheus-data:/prometheus:Z

PodmanArgs=--user=nobody

PublishPort=127.0.0.1:9090:9090

[Service]
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
```

```ini
# /home/bareos/.config/containers/systemd/grafana.container

[Unit]
Description=Grafana Dashboard
After=prometheus.service

[Container]
Image=docker.io/grafana/grafana-oss:latest
ContainerName=grafana
Network=bareos.network

Volume=bareos-grafana-data:/var/lib/grafana:Z

Environment=GF_SERVER_HTTP_PORT=3000
Environment=GF_SECURITY_ADMIN_USER=admin
Environment=GF_SECURITY_ADMIN_PASSWORD=GrafanaAdmin_ChangeMe
Environment=GF_ANALYTICS_REPORTING_ENABLED=false
# Disable telemetry — Grafana sends usage data to grafana.com by default.

PublishPort=127.0.0.1:3000:3000

[Service]
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
```

### Recommended Grafana Dashboard Panels

Once Grafana is running at `http://localhost:3000`, add Prometheus as a data source (`http://prometheus:9090` within the Podman network) and create a dashboard with these panels:

**Row 1: Current Status**

| Panel | Query | Visualization |
|---|---|---|
| Jobs in last 24h | `sum(increase(bareos_jobs_total[24h]))` | Stat (big number) |
| Failed jobs (24h) | `sum(increase(bareos_jobs_total{status="Error"}[24h]))` | Stat (red if > 0) |
| Total bytes backed up (7d) | `sum(increase(bareos_job_bytes[7d]))` | Stat |
| Last successful backup | `time() - max(bareos_last_job_timestamp{status="OK"})` | Stat (hours ago) |

**Row 2: Job History**

| Panel | Query | Visualization |
|---|---|---|
| Job success/failure over time | `rate(bareos_jobs_total[1h])` grouped by `status` | Time series |
| Backup size trend | `bareos_job_bytes` by `client` | Time series |
| Job duration trend | `bareos_job_duration_seconds` | Time series |

**Row 3: Storage**

| Panel | Query | Visualization |
|---|---|---|
| Volume status by pool | `bareos_pool_volumes_total` by `pool`, `status` | Bar chart |
| Bytes per pool | `sum(bareos_volume_bytes) by (pool)` | Pie chart |

**Grafana Provisioning** (load dashboard automatically on startup):

```yaml
# ~/.local/share/containers/storage/volumes/bareos-grafana-data/_data/provisioning/datasources/prometheus.yml

apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. systemd Journal Monitoring

All Bareos containers managed by Quadlet write their stdout/stderr to the systemd user journal. This means you can monitor Bareos using standard systemd tooling.

### Basic Journal Commands

```bash
# Follow live logs from the Director
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-dir -f

# View last 200 lines
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-dir -n 200

# Filter by time range
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-dir \
  --since "2025-07-06 00:00:00" --until "2025-07-06 06:00:00"

# Filter by priority (only errors and above)
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-dir -p err

# All Bareos-related units at once
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user \
  -u bareos-dir -u bareos-sd -u bareos-fd -u bareos-db -f

# Export as JSON for log aggregation pipelines
XDG_RUNTIME_DIR=/run/user/1001 journalctl --user -u bareos-dir \
  --since "1 hour ago" -o json | jq '.MESSAGE'
```

### Persistent Journal Configuration

By default on RHEL 10, user journals may not persist across reboots. Enable persistence:

```bash
# Create the persistent journal directory for the bareos user
mkdir -p /home/bareos/.config/systemd/journald.conf.d/
cat > /home/bareos/.config/systemd/journald.conf.d/persistent.conf << 'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
# Limit journal size to 500 MB to prevent disk exhaustion.
EOF
```

For system-level journal persistence (recommended):

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

### Journal Pattern Alerting with systemd-journal-remote

For centralizing logs to a remote journal server:

```bash
sudo dnf install -y systemd-journal-remote

# Configure forwarding from this host to a remote journal server
sudo tee /etc/systemd/journal-remote.conf << 'EOF'
[Remote]
Seal=false
ServerKeyFile=/etc/ssl/private/journal-remote.pem
ServerCertificateFile=/etc/ssl/certs/journal-remote.pem
TrustedCertificateFile=/etc/ssl/certs/ca-bundle.crt
EOF
```

### Simple Journal-Based Alert Pattern

A one-liner systemd service that alerts when specific patterns appear:

```ini
# /home/bareos/.config/systemd/user/bareos-journal-alert.service

[Unit]
Description=Monitor Bareos journal for errors and alert

[Service]
Type=simple
ExecStart=/home/bareos/scripts/journal-monitor.sh
Restart=on-failure
RestartSec=5
Environment=XDG_RUNTIME_DIR=/run/user/1001
```

```bash
#!/usr/bin/env bash
# /home/bareos/scripts/journal-monitor.sh
# Monitors the systemd journal for Bareos error patterns and sends alerts.

journalctl --user -u bareos-dir -u bareos-sd -f --output=cat | \
while IFS= read -r line; do
  if echo "$line" | grep -qiE "(error|fatal|failed|Termination: Backup Error)"; then
    echo "BAREOS ALERT: $line" | \
      msmtp backup-alerts@example.com <<< "Subject: Bareos Error Detected
From: bareos@example.com
To: backup-alerts@example.com

Bareos journal alert on $(hostname) at $(date):

$line
"
  fi
done
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Health Check Script for Bareos Director

A health check script that can be called by monitoring systems (Nagios, Zabbix, systemd watchdog) to verify the Director is operational.

### The Health Check Script

```bash
#!/usr/bin/env bash
# /home/bareos/scripts/bareos-healthcheck.sh
# ─────────────────────────────────────────────────────────────────
# Bareos Director health check script.
# Exit codes:
#   0 = OK (Director is healthy)
#   1 = WARNING (Director responding but issues detected)
#   2 = CRITICAL (Director not responding or catalog disconnected)
#
# Compatible with Nagios/NRPE plugin protocol.
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

CONTAINER="bareos-dir"
TIMEOUT=30

# ── 1. Check container is running ────────────────────────────────
if ! podman inspect --format '{{.State.Running}}' "${CONTAINER}" 2>/dev/null | grep -q "true"; then
  echo "CRITICAL: bareos-dir container is not running"
  exit 2
fi

# ── 2. Run bconsole status director ───────────────────────────────
STATUS_OUTPUT=$(timeout "${TIMEOUT}" podman exec "${CONTAINER}" \
  bconsole <<'EOF' 2>&1
status director
quit
EOF
)

if [[ $? -ne 0 ]]; then
  echo "CRITICAL: bconsole did not respond within ${TIMEOUT} seconds"
  exit 2
fi

# ── 3. Check Director response ────────────────────────────────────
if ! echo "${STATUS_OUTPUT}" | grep -q "daemon is OK"; then
  echo "CRITICAL: Director status check failed"
  echo "${STATUS_OUTPUT}" | tail -5
  exit 2
fi

# ── 4. Check for failed jobs in last hour ─────────────────────────
FAILED_JOBS=$(timeout "${TIMEOUT}" podman exec "${CONTAINER}" \
  bconsole <<'EOF' 2>&1
list jobs days=1
quit
EOF
| grep -c " E " || true)

if [[ "${FAILED_JOBS}" -gt 5 ]]; then
  echo "WARNING: ${FAILED_JOBS} jobs failed in the last 24 hours"
  exit 1
fi

# ── 5. Check scheduled jobs exist ────────────────────────────────
SCHED_COUNT=$(echo "${STATUS_OUTPUT}" | grep -c "Scheduled Jobs:" || true)
# Just verifies the section exists — a more complete check would
# verify specific named jobs appear.

# ── 6. All checks passed ─────────────────────────────────────────
RUNNING_JOBS=$(echo "${STATUS_OUTPUT}" | grep -oP 'run=\K\d+' | head -1)
echo "OK: Bareos Director is running. Jobs today: ${RUNNING_JOBS:-unknown}. Failed (24h): ${FAILED_JOBS}"
exit 0
```

```bash
chmod 750 /home/bareos/scripts/bareos-healthcheck.sh
```

### systemd Service for Continuous Health Monitoring

```ini
# /home/bareos/.config/systemd/user/bareos-healthcheck.service

[Unit]
Description=Bareos Director Health Check
After=bareos-dir.service

[Service]
Type=oneshot
ExecStart=/home/bareos/scripts/bareos-healthcheck.sh
```

```ini
# /home/bareos/.config/systemd/user/bareos-healthcheck.timer

[Unit]
Description=Run Bareos health check every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
```

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now bareos-healthcheck.timer
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Alertmanager Integration for PagerDuty/Slack/Email

Alertmanager receives alerts from Prometheus and routes them to the appropriate notification channels based on labels.

### Alertmanager Quadlet

```ini
# /home/bareos/.config/containers/systemd/alertmanager.container

[Unit]
Description=Prometheus Alertmanager
After=prometheus.service

[Container]
Image=docker.io/prom/alertmanager:latest
ContainerName=alertmanager
Network=bareos.network

Volume=bareos-alertmanager-config:/etc/alertmanager:Z

PublishPort=127.0.0.1:9093:9093

[Service]
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
```

### Alertmanager Configuration

```yaml
# ~/.local/share/containers/storage/volumes/bareos-alertmanager-config/_data/alertmanager.yml
# ─────────────────────────────────────────────────────────────────
# Alertmanager routing and notification configuration
# ─────────────────────────────────────────────────────────────────

global:
  resolve_timeout: 5m
  # How long to wait before sending a "resolved" notification.

  # Default SMTP settings (used by email receivers below)
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'bareos-alerts@example.com'
  smtp_auth_username: 'bareos-alerts@example.com'
  smtp_auth_password: 'YOUR_SMTP_PASSWORD'
  smtp_require_tls: true

# ── Routing Tree ─────────────────────────────────────────────────
route:
  # Default receiver for all alerts
  receiver: 'email-ops'
  group_by: ['alertname', 'service']
  group_wait:      30s    # Wait 30s before sending first alert in a group
  group_interval:  5m     # Wait 5m before sending update for ongoing group
  repeat_interval: 4h     # Resend if alert is still firing after 4 hours

  routes:
    # Critical alerts (job failures) → PagerDuty + email
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: true    # Also send to the next matching route

    - match:
        severity: critical
      receiver: 'email-ops'

    # Warnings → Slack + email
    - match:
        severity: warning
      receiver: 'slack-ops'
      continue: true

    - match:
        severity: warning
      receiver: 'email-ops'

# ── Inhibition Rules ─────────────────────────────────────────────
inhibit_rules:
  # If the exporter itself is down, suppress all Bareos alerts
  # (they'd all be false positives due to missing metrics)
  - source_match:
      alertname: 'BareosExporterDown'
    target_match_re:
      alertname: 'Bareos.*'
    equal: ['environment']

# ── Receivers ────────────────────────────────────────────────────
receivers:
  - name: 'email-ops'
    email_configs:
      - to: 'backup-ops@example.com'
        send_resolved: true
        headers:
          Subject: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }} - Bareos Alert'
        html: |
          {{ range .Alerts }}
          <b>Alert:</b> {{ .Annotations.summary }}<br>
          <b>Description:</b> {{ .Annotations.description }}<br>
          <b>Status:</b> {{ .Status }}<br>
          <b>Started:</b> {{ .StartsAt }}<br>
          {{ end }}

  - name: 'slack-ops'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#backup-alerts'
        send_resolved: true
        title: '[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
        text: |
          {{ range .Alerts }}
          *Summary:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          {{ end }}
        # Color the Slack attachment by severity
        color: '{{ if eq .Status "firing" }}{{ if eq (index .Alerts 0).Labels.severity "critical" }}danger{{ else }}warning{{ end }}{{ else }}good{{ end }}'

  - name: 'pagerduty-critical'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
        # PagerDuty Events API v1 key. Find in PagerDuty → Service → Integrations.
        send_resolved: true
        description: '{{ (index .Alerts 0).Annotations.summary }}'
        details:
          description: '{{ (index .Alerts 0).Annotations.description }}'
          environment: '{{ (index .Alerts 0).Labels.environment }}'
          host: '{{ (index .Alerts 0).Labels.host }}'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Backup SLA Reporting Script

This script queries the Bareos Director and produces an SLA report showing which jobs missed their backup window (ran late, ran too long, or have not run recently enough).

```bash
#!/usr/bin/env bash
# /home/bareos/scripts/bareos-sla-report.sh
# ─────────────────────────────────────────────────────────────────
# Bareos SLA (Service Level Agreement) Reporting Script.
#
# Checks each defined Job against configurable SLA thresholds:
#   - MAX_AGE_HOURS: Maximum hours since last successful backup
#   - MAX_DURATION_MINS: Maximum acceptable job duration
#   - MIN_FILES: Minimum files expected in a successful backup
#
# Sends an email report and exits non-zero if any SLA is violated.
#
# Usage:
#   ./bareos-sla-report.sh [--email recipient@example.com]
#   ./bareos-sla-report.sh --quiet   (no email, only exit code)
#
# Schedule this via systemd timer or cron to run daily.
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

export XDG_RUNTIME_DIR=/run/user/1001

# ── Configuration ─────────────────────────────────────────────────

REPORT_EMAIL="${REPORT_EMAIL:-backup-reports@example.com}"
BAREOS_CONTAINER="bareos-dir"
QUIET=false

# SLA thresholds — adjust to match your backup schedule.
# If a job has not run successfully within MAX_AGE_HOURS, it is in violation.
declare -A MAX_AGE_HOURS=(
  ["Backup-Linux-Daily"]=26      # Daily jobs: allow 26h (daily + 2h grace)
  ["Backup-Linux-Weekly"]=175    # Weekly jobs: allow ~7 days + 7h grace
  ["Backup-Linux-Monthly"]=760   # Monthly: ~31 days + 16h grace
)

declare -A MAX_DURATION_MINS=(
  ["Backup-Linux-Daily"]=120     # Max 2 hours for incremental
  ["Backup-Linux-Weekly"]=240    # Max 4 hours for differential
  ["Backup-Linux-Monthly"]=600   # Max 10 hours for full
)

declare -A MIN_FILES=(
  ["Backup-Linux-Daily"]=10      # At least 10 changed files (avoids empty incrementals)
  ["Backup-Linux-Weekly"]=100
  ["Backup-Linux-Monthly"]=1000
)

# ── Parse Arguments ───────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case $1 in
    --email) REPORT_EMAIL="$2"; shift 2 ;;
    --quiet) QUIET=true; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Helper Functions ──────────────────────────────────────────────

run_bconsole() {
  timeout 60 podman exec "${BAREOS_CONTAINER}" bconsole 2>/dev/null <<EOF
$1
quit
EOF
}

# ── Main Report Generation ────────────────────────────────────────

REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
VIOLATIONS=0
REPORT_BODY="Bareos SLA Report — ${REPORT_DATE}
Server: $(hostname)
================================================

"

for JOB_NAME in "${!MAX_AGE_HOURS[@]}"; do

  # Get the last successful job for this job name
  JOB_DATA=$(run_bconsole "list jobs days=30" | \
    grep " ${JOB_NAME} " | \
    grep " T " | \
    tail -1)

  if [[ -z "${JOB_DATA}" ]]; then
    VIOLATIONS=$((VIOLATIONS + 1))
    REPORT_BODY+="[VIOLATION] ${JOB_NAME}: No successful job found in last 30 days\n"
    continue
  fi

  # Extract fields from bconsole table output.
  # bconsole list jobs columns: JobId|Name|Client|StartTime|Duration|Files|Bytes|Status
  JOB_ID=$(echo "${JOB_DATA}"      | awk -F'|' '{print $1}' | tr -d ' ')
  START_TIME=$(echo "${JOB_DATA}"  | awk -F'|' '{print $4}' | tr -d ' ')
  DURATION=$(echo "${JOB_DATA}"    | awk -F'|' '{print $5}' | tr -d ' ')
  FILES=$(echo "${JOB_DATA}"       | awk -F'|' '{print $6}' | tr -d ' ,')

  # Convert start time to epoch seconds
  JOB_EPOCH=$(date -d "${START_TIME}" +%s 2>/dev/null || echo 0)
  NOW_EPOCH=$(date +%s)
  AGE_HOURS=$(( (NOW_EPOCH - JOB_EPOCH) / 3600 ))

  # Convert duration string (HH:MM:SS) to minutes
  DURATION_SECS=$(echo "${DURATION}" | awk -F: '{print ($1*3600)+($2*60)+$3}')
  DURATION_MINS=$(( DURATION_SECS / 60 ))

  JOB_STATUS="OK"
  JOB_NOTES=""

  # Check age SLA
  if [[ "${AGE_HOURS}" -gt "${MAX_AGE_HOURS[${JOB_NAME}]}" ]]; then
    JOB_STATUS="VIOLATION"
    JOB_NOTES+="  - Last successful backup was ${AGE_HOURS}h ago (max: ${MAX_AGE_HOURS[${JOB_NAME}]}h)\n"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi

  # Check duration SLA
  if [[ "${DURATION_MINS}" -gt "${MAX_DURATION_MINS[${JOB_NAME}]}" ]]; then
    JOB_STATUS="WARNING"
    JOB_NOTES+="  - Duration ${DURATION_MINS} min exceeded max ${MAX_DURATION_MINS[${JOB_NAME}]} min\n"
  fi

  # Check minimum files SLA
  if [[ -n "${FILES}" ]] && [[ "${FILES}" -lt "${MIN_FILES[${JOB_NAME}]}" ]]; then
    JOB_STATUS="WARNING"
    JOB_NOTES+="  - Only ${FILES} files backed up (min: ${MIN_FILES[${JOB_NAME}]})\n"
  fi

  REPORT_BODY+="[${JOB_STATUS}] ${JOB_NAME}\n"
  REPORT_BODY+="  JobId: ${JOB_ID} | Start: ${START_TIME} | Age: ${AGE_HOURS}h | Duration: ${DURATION_MINS}min | Files: ${FILES}\n"
  if [[ -n "${JOB_NOTES}" ]]; then
    REPORT_BODY+="${JOB_NOTES}"
  fi
  REPORT_BODY+="\n"

done

REPORT_BODY+="================================================\n"
REPORT_BODY+="Total SLA violations: ${VIOLATIONS}\n"

# ── Output Report ─────────────────────────────────────────────────

echo -e "${REPORT_BODY}"

if [[ "${QUIET}" == "false" ]]; then
  SUBJECT="Bareos SLA Report ${REPORT_DATE}"
  if [[ "${VIOLATIONS}" -gt 0 ]]; then
    SUBJECT="[VIOLATIONS: ${VIOLATIONS}] ${SUBJECT}"
  fi

  echo -e "Subject: ${SUBJECT}\nFrom: bareos@example.com\nTo: ${REPORT_EMAIL}\n\n${REPORT_BODY}" | \
    msmtp "${REPORT_EMAIL}" || echo "Warning: Failed to send report email"
fi

# Exit non-zero if violations were found (useful for Nagios/monitoring integration)
exit ${VIOLATIONS}
```

```bash
chmod 750 /home/bareos/scripts/bareos-sla-report.sh
```

### Scheduling the SLA Report

```ini
# /home/bareos/.config/systemd/user/bareos-sla-report.service

[Unit]
Description=Bareos Daily SLA Report

[Service]
Type=oneshot
ExecStart=/home/bareos/scripts/bareos-sla-report.sh --email backup-reports@example.com
Environment=XDG_RUNTIME_DIR=/run/user/1001
```

```ini
# /home/bareos/.config/systemd/user/bareos-sla-report.timer

[Unit]
Description=Run Bareos SLA report every morning at 07:00

[Timer]
OnCalendar=*-*-* 07:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
XDG_RUNTIME_DIR=/run/user/1001 systemctl --user enable --now bareos-sla-report.timer
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Centralized Syslog with rsyslog Forwarding

For environments with a centralized log server (Splunk, ELK stack, or a dedicated syslog aggregator), you can forward Bareos container logs from the RHEL 10 host via rsyslog.

### Configuring rsyslog on RHEL 10

```bash
sudo dnf install -y rsyslog
```

```bash
# /etc/rsyslog.d/30-bareos.conf
# ─────────────────────────────────────────────────────────────────
# Forward Bareos systemd unit logs to remote syslog server.
# ─────────────────────────────────────────────────────────────────

# Load systemd journal input module
module(load="imjournal" StateFile="imjournal.state")

# Filter messages from Bareos systemd units
# systemd unit name is in the _SYSTEMD_UNIT field
if $syslogtag contains "bareos" then {
  # Forward to remote syslog server using TCP (reliable delivery)
  action(
    type="omfwd"
    target="syslog.example.com"
    port="514"
    protocol="tcp"
    template="RSYSLOG_SyslogProtocol23Format"
  )
  # Also write locally for debugging
  action(type="omfile" file="/var/log/bareos-syslog.log")
  stop
}
```

For forwarding the systemd journal entries from Bareos containers specifically:

```bash
# /etc/rsyslog.d/31-bareos-journal.conf

# Read journal entries with CONTAINER_NAME=bareos-*
# Using the newer journal input format
input(type="imjournal" ratelimit.interval="0")

# Match container logs
if $!CONTAINER_NAME startswith "bareos" then {
  action(
    type="omfwd"
    target="syslog.example.com"
    port="6514"
    protocol="tcp"
    StreamDriverMode="1"
    StreamDriverAuthMode="anon"
  )
}
```

```bash
sudo systemctl restart rsyslog
sudo systemctl enable rsyslog
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. SELinux: Allowing Email and Prometheus Ports

Running Bareos in containers under SELinux enforcing mode requires careful attention to any network connections the containers make. The Director container needs to connect to SMTP (port 587), the exporter container needs to open port 9625, and the Grafana container needs port 3000.

### Allow Container Connections to SMTP

```bash
# Check current SELinux boolean for container network connections
getsebool container_manage_cgroup
getsebool container_connect_any

# Allow all containers to make network connections to any port
# (Use this if the specific policy below is insufficient)
sudo setsebool -P container_connect_any=1

# More restrictive: allow containers to connect to SMTP port 587
sudo semanage port -a -t smtp_port_t -p tcp 587
# Note: port 25 is already defined as smtp_port_t in most policies.
# Port 587 (SUBMISSION) may need to be added explicitly.

# Verify
sudo semanage port -l | grep smtp
```

### Allow Container Ports for Prometheus Exporter

```bash
# The bareos-exporter listens on port 9625
# This is an unprivileged port for rootless containers but may still
# need a SELinux port label for containers to bind to it.

# Add the port label
sudo semanage port -a -t http_port_t -p tcp 9625
# We use http_port_t as a general "web service" port type.

# If port 9625 already exists, use -m to modify:
sudo semanage port -m -t http_port_t -p tcp 9625

# Verify
sudo semanage port -l | grep 9625
```

### Allow Grafana and Prometheus Ports

```bash
# Port 3000 (Grafana)
sudo semanage port -a -t http_port_t -p tcp 3000

# Port 9090 (Prometheus)
sudo semanage port -a -t http_port_t -p tcp 9090

# Port 9100 (Bareos WebUI)
sudo semanage port -a -t http_port_t -p tcp 9100

# Port 9093 (Alertmanager)
sudo semanage port -a -t http_port_t -p tcp 9093
```

### Allow Rootless Containers to Bind to Non-Privileged Ports

By default, rootless containers cannot bind to ports below 1024. Ports 9xxx are all fine. If you encounter permission denied binding:

```bash
# Check net.ipv4.ip_unprivileged_port_start
sysctl net.ipv4.ip_unprivileged_port_start
# Default: 1024. Rootless containers can bind to 1024 and above.

# If needed, lower this threshold (requires root):
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.d/99-containers.conf
```

### Checking for SELinux Denials

If something isn't working, always check `audit.log` first:

```bash
# Check for recent AVC denials
sudo ausearch -m avc -ts recent

# Get a human-readable explanation and suggested fix
sudo audit2why -a | head -60

# Generate and apply a policy module from denials (use sparingly in production)
sudo audit2allow -a -M bareos-local
sudo semodule -i bareos-local.pp
```

### SELinux File Contexts for Monitoring Scripts

```bash
# Scripts in bareos home directory
sudo semanage fcontext -a -t bin_t "/home/bareos/scripts(/.*)?"
sudo restorecon -RFv /home/bareos/scripts/

# Log files written by scripts
sudo semanage fcontext -a -t var_log_t "/home/bareos/.local/share/containers/storage/volumes/bareos-director-log/_data(/.*)?"
sudo restorecon -RFv /home/bareos/.local/share/containers/storage/volumes/
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Lab 17-1: Configure Email Summaries for Every Job

This lab configures Bareos to send a detailed email summary for every completed backup job.

### Step 1: Prepare msmtp

```bash
# Ensure you are running as bareos user
sudo -u bareos -s

export XDG_RUNTIME_DIR=/run/user/1001

# Verify msmtp is accessible inside the container
podman exec bareos-dir which msmtp || \
  echo "msmtp not found in container — bind mount needed (see Section 4)"

# Test SMTP connectivity (replace with your actual SMTP server)
podman exec bareos-dir \
  sh -c 'echo -e "Subject: Bareos Test\n\nTest message" | msmtp backup-alerts@example.com'
```

If the test fails, review the msmtp configuration in `/home/bareos/.config/bareos/msmtp/msmtprc` and ensure the SMTP credentials are correct.

### Step 2: Write the Messages Resource Configuration

```bash
BAREOS_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-director-config/_data"

cat > "${BAREOS_CONFIG}/bareos-dir.d/messages/Standard.conf" << 'MSGCONF'
Messages {
  Name = "Standard"

  # Email for every job (success and failure)
  Mail = "backup-alerts@example.com" = all, !skipped, !restored

  # Additional email to on-call if there are errors
  Mail On Error = "oncall@example.com" = error, fatal

  # Store in catalog for WebUI visibility
  Catalog = all, !skipped, !restored

  # Write to log file
  Append = "/var/log/bareos/bareos.log" = all, !skipped, !restored

  # Show warnings and errors in bconsole
  Console = warning, error, fatal, terminate
}
MSGCONF
```

### Step 3: Ensure Jobs Reference the Standard Messages Resource

```bash
# Verify your job configurations reference the Messages resource
grep -r "Messages" "${BAREOS_CONFIG}/bareos-dir.d/job/"
# Every Job block should have: Messages = Standard
```

### Step 4: Reload and Test

```bash
# Reload Director
podman exec bareos-dir bconsole <<< "reload"

# Run a test job
podman exec -it bareos-dir bconsole
```

```
*run job=Backup-Linux-Daily level=Incremental yes
*wait
*messages
```

Wait for the job to complete. Check your email inbox. You should receive the full job summary email within a minute of job completion.

### Step 5: Verify Email Was Sent

```bash
# Check the msmtp log inside the container
podman exec bareos-dir cat /var/log/bareos/msmtp.log | tail -10
# Should show: host=smtp.example.com from=bareos@example.com to=backup-alerts@example.com ...
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 17. Lab 17-2: Deploy bareos-webui as a Quadlet Container

This lab deploys the Bareos WebUI and verifies it can connect to the Director.

### Step 1: Create the WebUI Configuration Volume

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Create the named volume for WebUI configuration
podman volume create bareos-webui-config

# Get the data path
WEBUI_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-webui-config/_data"
```

### Step 2: Write Configuration Files

```bash
# Write directors.ini
cat > "${WEBUI_CONFIG}/directors.ini" << 'DIRINI'
[director1]
enabled           = "yes"
diraddress        = "bareos-dir"
dirport           = 9101
tls_verify_peer   = false
catalog           = "MyCatalog"
pam_console_name  = ""
pam_console_password = ""
DIRINI

# Write bareos.ini
cat > "${WEBUI_CONFIG}/bareos.ini" << 'BARINI'
[session]
timeout = 900

[tables]
pagination = 25

[theme]
name = "bareos"

[restore]
filetree_refresh_timeout = 120

[experimental]
maintabs = "off"
BARINI
```

### Step 3: Add WebUI User to Director

```bash
BAREOS_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-director-config/_data"

# Write console (WebUI user) configuration
cat > "${BAREOS_CONFIG}/bareos-dir.d/console/webui-admin.conf" << 'CONSCONF'
Console {
  Name     = "admin"
  Password = "Change_This_Password_Now"
  Profile  = "webui-admin"
}
CONSCONF

# Reload Director to pick up new console user
podman exec bareos-dir bconsole <<< "reload"
```

### Step 4: Write and Deploy the Quadlet File

```bash
cat > /home/bareos/.config/containers/systemd/bareos-webui.container << 'QUADLET'
[Unit]
Description=Bareos WebUI
After=network-online.target bareos-dir.service
Requires=bareos-dir.service

[Container]
Image=docker.io/bareos/bareos-webui:24
ContainerName=bareos-webui
Network=bareos.network
Volume=bareos-webui-config:/etc/bareos-webui:Z
Environment=BAREOS_DIRECTOR_HOST=bareos-dir
Environment=BAREOS_DIRECTOR_PORT=9101
Environment=BAREOS_WEBUI_USER=admin
Environment=BAREOS_WEBUI_PASSWORD=Change_This_Password_Now
PublishPort=127.0.0.1:9100:80

[Service]
Restart=always
RestartSec=10
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
QUADLET

# Start the WebUI
systemctl --user daemon-reload
systemctl --user enable --now bareos-webui
systemctl --user status bareos-webui
```

### Step 5: Verify Access

```bash
# Check the container is running
podman ps | grep bareos-webui

# Test HTTP access
curl -s -o /dev/null -w "%{http_code}" http://localhost:9100/
# Expected: 200 or 302 (redirect to login)

# Check logs
journalctl --user -u bareos-webui -n 30
```

Open `http://localhost:9100` in a browser on the RHEL 10 host. Log in with username `admin` and the password you set. You should see the Bareos WebUI dashboard showing recent jobs.

---

[↑ Back to Table of Contents](#table-of-contents)

## 18. Lab 17-3: Deploy bareos-exporter with Prometheus and Grafana

This lab deploys the complete metrics stack: bareos-exporter, Prometheus, and Grafana.

### Step 1: Create Required Volumes

```bash
export XDG_RUNTIME_DIR=/run/user/1001

podman volume create bareos-prometheus-config
podman volume create bareos-prometheus-data
podman volume create bareos-grafana-data
podman volume create bareos-alertmanager-config

PROM_CONFIG="$HOME/.local/share/containers/storage/volumes/bareos-prometheus-config/_data"
```

### Step 2: Write Prometheus Configuration

```bash
cat > "${PROM_CONFIG}/prometheus.yml" << 'PROMCONF'
global:
  scrape_interval:     60s
  evaluation_interval: 60s

rule_files:
  - "bareos_alerts.yml"

scrape_configs:
  - job_name: 'bareos'
    scrape_interval: 60s
    static_configs:
      - targets: ['bareos-exporter:9625']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
PROMCONF

# Copy the alert rules (from Section 8) to the Prometheus config volume
cat > "${PROM_CONFIG}/bareos_alerts.yml" << 'ALERTCONF'
groups:
  - name: bareos_backup_alerts
    rules:
      - alert: BareosJobFailed
        expr: increase(bareos_jobs_total{status="Error"}[1h]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Bareos backup job failed"
          description: "{{ $value }} backup job(s) failed in the last hour."

      - alert: BareosNoRecentBackup
        expr: (time() - bareos_last_job_timestamp{status="OK"}) > 86400
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "No successful Bareos backup in 24 hours"
          description: "Last successful backup: {{ $value | humanizeDuration }} ago."

      - alert: BareosExporterDown
        expr: up{job="bareos"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Bareos exporter is down"
          description: "No metrics from bareos-exporter for 5 minutes."
ALERTCONF
```

### Step 3: Deploy All Four Quadlet Services

```bash
# bareos-exporter (Section 8's Quadlet file should already be written)
# Write it now if not already done:
cat > /home/bareos/.config/containers/systemd/bareos-exporter.container << 'QUADLET'
[Unit]
Description=Bareos Prometheus Exporter
After=bareos-dir.service bareos-db.service

[Container]
Image=docker.io/barcus/bareos-exporter:latest
ContainerName=bareos-exporter
Network=bareos.network
Environment=BAREOS_DB_HOST=bareos-db
Environment=BAREOS_DB_PORT=3306
Environment=BAREOS_DB_NAME=bareos
Environment=BAREOS_DB_USER=bareos
EnvironmentFile=/home/bareos/.config/bareos/db.env
PublishPort=127.0.0.1:9625:9625

[Service]
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
QUADLET

# prometheus.container
cat > /home/bareos/.config/containers/systemd/prometheus.container << 'QUADLET'
[Unit]
Description=Prometheus
After=bareos-exporter.service

[Container]
Image=docker.io/prom/prometheus:latest
ContainerName=prometheus
Network=bareos.network
Volume=bareos-prometheus-config:/etc/prometheus:Z
Volume=bareos-prometheus-data:/prometheus:Z
PublishPort=127.0.0.1:9090:9090

[Service]
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
QUADLET

# grafana.container
cat > /home/bareos/.config/containers/systemd/grafana.container << 'QUADLET'
[Unit]
Description=Grafana
After=prometheus.service

[Container]
Image=docker.io/grafana/grafana-oss:latest
ContainerName=grafana
Network=bareos.network
Volume=bareos-grafana-data:/var/lib/grafana:Z
Environment=GF_SERVER_HTTP_PORT=3000
Environment=GF_SECURITY_ADMIN_USER=admin
Environment=GF_SECURITY_ADMIN_PASSWORD=Grafana_ChangeMe
Environment=GF_ANALYTICS_REPORTING_ENABLED=false
PublishPort=127.0.0.1:3000:3000

[Service]
Restart=always
Environment=XDG_RUNTIME_DIR=/run/user/1001

[Install]
WantedBy=default.target
QUADLET
```

### Step 4: Start All Services

```bash
systemctl --user daemon-reload
systemctl --user enable --now bareos-exporter
systemctl --user enable --now prometheus
systemctl --user enable --now grafana

# Wait for containers to start
sleep 15

# Verify all are running
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "bareos-exporter|prometheus|grafana"
```

### Step 5: Verify Metrics Collection

```bash
# Check bareos-exporter metrics
curl -s http://localhost:9625/metrics | grep bareos_jobs_total

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | \
  python3 -c "import sys,json; targets=json.load(sys.stdin)['data']['activeTargets']; \
  [print(t['labels']['job'], t['health']) for t in targets]"
```

Expected output:
```
bareos  up
prometheus  up
```

### Step 6: Configure Grafana

1. Open `http://localhost:3000` in a browser. Log in with `admin` / `Grafana_ChangeMe`.
2. Navigate to **Configuration** → **Data Sources** → **Add data source**.
3. Select **Prometheus**. Set URL to `http://prometheus:9090`. Click **Save & Test**.
4. Navigate to **Dashboards** → **Import**.
5. Look for community Bareos dashboards on grafana.com (search for "Bareos") or create panels manually using the queries from Section 9.

### Step 7: Verify Alertmanager (Optional)

If you deployed Alertmanager:

```bash
# Check Alertmanager UI
curl -s http://localhost:9093/-/healthy
# Expected: OK

# Trigger a test alert
curl -s -XPOST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Test alert from lab"}}]'
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 19. Summary

This chapter covered the complete monitoring and alerting stack for a production Bareos deployment on RHEL 10 + Podman. The key takeaways are:

**Silent failures are the greatest risk**: A backup system that fails quietly is dangerous. Configure email notification (`mail on error` at minimum) for every job before your system goes into production. This is not optional.

**Messages resources are the email routing system**: Every Bareos daemon (Director, Storage Daemon, File Daemon) has its own Messages resource. They use `director =` directives to forward messages upward to the Director, which does the actual sending. Understanding the message type selectors (`all`, `!skipped`, `error`, `fatal`) is essential for controlling notification volume.

**msmtp is the right tool for container email**: Rather than running a full MTA inside the container, bind-mounting msmtp from the host gives you a lightweight, configurable SMTP client that works with any external relay.

**bconsole is your primary diagnostic tool**: `status director`, `list jobs`, `list volumes`, and `list joblog jobid=N` answer 90% of diagnostic questions. Wrapping these in health check scripts gives you integration with external monitoring systems.

**bareos-webui adds a human-friendly view**: Deploying it as a Quadlet container with a dedicated Console user gives operators a graphical interface for job monitoring and restore operations without requiring bconsole access.

**Prometheus + Grafana provides long-term visibility**: The bareos-exporter translates Bareos catalog data into Prometheus metrics. Combined with Alertmanager, this gives you proactive alerting for missed backups, job failures, pool exhaustion, and performance anomalies.

**The SLA reporting script closes the loop**: Automated daily SLA reports that compare actual backup behavior against defined thresholds catch slow degradation that might not trigger real-time alerts — such as gradually increasing backup duration or slowly declining file counts.

**SELinux must be configured before network connections work**: The `container_connect_any` boolean or specific port type assignments (`smtp_port_t` for SMTP, `http_port_t` for monitoring ports) must be set before containers can make external network connections. Always check `ausearch -m avc -ts recent` when troubleshooting connectivity.

In the next chapter, we will cover disaster recovery scenarios — restoring from backups when the Bareos Director itself has been lost, and strategies for protecting the catalog database.

---

[↑ Back to Table of Contents](#table-of-contents)
