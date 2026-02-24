# Chapter 11: Backing Up and Restoring Podman Container Images

## Table of Contents

- [1. Why Back Up Images? Reproducibility vs Registry Availability](#1-why-back-up-images-reproducibility-vs-registry-availability)
  - [The registry availability problem](#the-registry-availability-problem)
  - [The reproducibility problem](#the-reproducibility-problem)
  - [The air-gapped environment problem](#the-air-gapped-environment-problem)
  - [What you are actually archiving](#what-you-are-actually-archiving)
  - [When image backup is optional](#when-image-backup-is-optional)
- [2. `podman save` — OCI Tarball Format and Options](#2-podman-save-oci-tarball-format-and-options)
  - [Basic syntax](#basic-syntax)
  - [Output format](#output-format)
  - [Formats: OCI vs Docker](#formats-oci-vs-docker)
  - [Saving multiple images in one archive](#saving-multiple-images-in-one-archive)
  - [Checking image size before saving](#checking-image-size-before-saving)
  - [Compressing the archive](#compressing-the-archive)
- [3. `podman export` vs `podman save` — Containers vs Images](#3-podman-export-vs-podman-save-containers-vs-images)
  - [`podman save` — saves an image](#podman-save-saves-an-image)
  - [`podman export` — exports a container's filesystem](#podman-export-exports-a-containers-filesystem)
  - [Summary table](#summary-table)
- [4. Image Naming and Tagging Strategy for Backup](#4-image-naming-and-tagging-strategy-for-backup)
  - [Recommended naming convention](#recommended-naming-convention)
  - [Encoding the image digest in the filename](#encoding-the-image-digest-in-the-filename)
  - [Metadata file](#metadata-file)
- [5. Integrating Image Exports into Bareos: RunScript + FileSet Approach](#5-integrating-image-exports-into-bareos-runscript-fileset-approach)
  - [Job configuration overview](#job-configuration-overview)
- [6. Where to Save the Tarball](#6-where-to-save-the-tarball)
  - [Option A: `/var/tmp/bareos-image-exports/` (recommended for most setups)](#option-a-vartmpbareos-image-exports-recommended-for-most-setups)
  - [Option B: Dedicated mount point](#option-b-dedicated-mount-point)
  - [Option C: Bareos named volume path](#option-c-bareos-named-volume-path)
  - [Sizing guidance](#sizing-guidance)
- [7. SELinux Labeling of Export Directories](#7-selinux-labeling-of-export-directories)
  - [Default `/var/tmp/` behavior](#default-vartmp-behavior)
  - [Creating the export directory with correct labels](#creating-the-export-directory-with-correct-labels)
  - [Custom path labeling](#custom-path-labeling)
  - [Bind mounts in Quadlet containers](#bind-mounts-in-quadlet-containers)
- [8. Automating Image List Discovery](#8-automating-image-list-discovery)
  - [Basic image enumeration](#basic-image-enumeration)
  - [Filtering out intermediate and dangling images](#filtering-out-intermediate-and-dangling-images)
  - [Getting the image ID and digest alongside the name](#getting-the-image-id-and-digest-alongside-the-name)
  - [Filtering by label](#filtering-by-label)
  - [Filtering by repository prefix](#filtering-by-repository-prefix)
  - [Generating safe filenames from image names](#generating-safe-filenames-from-image-names)
- [9. Restoring Images with `podman load`](#9-restoring-images-with-podman-load)
  - [Basic syntax](#basic-syntax)
  - [What `podman load` outputs](#what-podman-load-outputs)
  - [Loading a multi-image archive](#loading-a-multi-image-archive)
  - [Verifying the loaded image](#verifying-the-loaded-image)
  - [Loading images as a different user](#loading-images-as-a-different-user)
- [10. Restoring Images on a Fresh Host — The Full Workflow](#10-restoring-images-on-a-fresh-host-the-full-workflow)
  - [Prerequisites for the new host](#prerequisites-for-the-new-host)
  - [Step 1: Restore Bareos backup to staging area](#step-1-restore-bareos-backup-to-staging-area)
  - [Step 2: Load each image archive](#step-2-load-each-image-archive)
  - [Step 3: Restore Quadlet configuration files](#step-3-restore-quadlet-configuration-files)
  - [Step 4: Restore volume data](#step-4-restore-volume-data)
  - [Step 5: Reload systemd and start services](#step-5-reload-systemd-and-start-services)
  - [Step 6: Verify service health](#step-6-verify-service-health)
- [11. Registry vs Local Archive Tradeoffs](#11-registry-vs-local-archive-tradeoffs)
  - [Using a private registry as your archive](#using-a-private-registry-as-your-archive)
  - [Using local archives (Bareos-managed)](#using-local-archives-bareos-managed)
  - [Recommended hybrid approach](#recommended-hybrid-approach)
- [12. Combining Image Backup with Volume Backup for a Complete Container Backup](#12-combining-image-backup-with-volume-backup-for-a-complete-container-backup)
  - [The complete FileSet for a full container backup](#the-complete-fileset-for-a-full-container-backup)
  - [Job combining image export + database dump](#job-combining-image-export-database-dump)
- [13. Quadlet: How Image Archives Work with Quadlet-Managed Containers](#13-quadlet-how-image-archives-work-with-quadlet-managed-containers)
  - [How Quadlet finds images at startup](#how-quadlet-finds-images-at-startup)
  - [Pinning to a specific image digest in Quadlet](#pinning-to-a-specific-image-digest-in-quadlet)
  - [Quadlet and image pull policies](#quadlet-and-image-pull-policies)
  - [Quadlet file backup as part of image backup job](#quadlet-file-backup-as-part-of-image-backup-job)
- [14. Lab 11-1: Export a Single Image and Add It to a Bareos FileSet](#14-lab-11-1-export-a-single-image-and-add-it-to-a-bareos-fileset)
  - [Prerequisites](#prerequisites)
  - [Step 1: Create the export directory](#step-1-create-the-export-directory)
  - [Step 2: Export the bareos-director image manually](#step-2-export-the-bareos-director-image-manually)
  - [Step 3: Configure the Bareos FileSet](#step-3-configure-the-bareos-fileset)
  - [Step 4: Create a Bareos Job for image backup](#step-4-create-a-bareos-job-for-image-backup)
  - [Step 5: Run the job and verify](#step-5-run-the-job-and-verify)
- [15. Lab 11-2: Automate Multi-Image Export with a RunScript Hook](#15-lab-11-2-automate-multi-image-export-with-a-runscript-hook)
  - [The complete `export-images.sh` script](#the-complete-export-imagessh-script)
  - [The cleanup script for image exports](#the-cleanup-script-for-image-exports)
  - [Install and configure the scripts](#install-and-configure-the-scripts)
  - [Configure the Bareos Job with the export hook](#configure-the-bareos-job-with-the-export-hook)
  - [Run the automated job](#run-the-automated-job)
- [16. Lab 11-3: Restore an Image on a Fresh Machine and Restart the Container](#16-lab-11-3-restore-an-image-on-a-fresh-machine-and-restart-the-container)
  - [Scenario](#scenario)
  - [Step 1: Prepare the fresh host](#step-1-prepare-the-fresh-host)
  - [Step 2: Install and configure the Bareos File Daemon on the restore target](#step-2-install-and-configure-the-bareos-file-daemon-on-the-restore-target)
  - [Step 3: Restore the image archive from Bareos](#step-3-restore-the-image-archive-from-bareos)
  - [Step 4: Locate the restored archive](#step-4-locate-the-restored-archive)
  - [Step 5: Load the image into Podman](#step-5-load-the-image-into-podman)
  - [Step 6: Verify the digest matches the metadata](#step-6-verify-the-digest-matches-the-metadata)
  - [Step 7: Restore Quadlet configuration](#step-7-restore-quadlet-configuration)
  - [Step 8: Start the container using the restored image](#step-8-start-the-container-using-the-restored-image)
  - [Step 9: Confirm the image matches the backup](#step-9-confirm-the-image-matches-the-backup)
- [17. Summary](#17-summary)

## 1. Why Back Up Images? Reproducibility vs Registry Availability

When people first start using containers, they often assume that container images are disposable — if you lose the local copy, you just pull it from the registry again. This assumption is reasonable in many development environments but becomes a liability in production, especially in backup and disaster recovery scenarios.

### The registry availability problem

Consider what happens during a disaster recovery event:

1. Your host machine has failed catastrophically
2. You are restoring from a Bareos backup to a new host
3. The restore runs at 03:00 on a Sunday morning when you are racing to restore SLAs

Now your restore script tries to pull `docker.io/bareos/bareos-director:24` and encounters:
- The registry is rate-limiting your IP (Docker Hub has anonymous pull limits)
- Your network path to the registry is degraded as part of the same incident
- The tag `24` has been updated and the new image has a bug
- Docker Hub has an outage (this has happened multiple times)

In each of these scenarios, having a local archive of the exact image you were running means the difference between a smooth restore and a multi-hour incident.

### The reproducibility problem

Container images with mutable tags (`latest`, version numbers like `24`) can change over time. The image behind `docker.io/bareos/bareos-director:24` today is not guaranteed to be identical to the image behind that tag in six months. If your configuration or data was tuned to a specific version, restoring with a newer image may produce unexpected behavior.

By archiving the actual image layers you were running, you preserve the exact software environment, byte-for-byte. Combined with a database dump and volume backup from Chapter 10, this gives you a fully reproducible system.

### The air-gapped environment problem

Many enterprise environments do not have outbound internet access from production servers. These **air-gapped** environments cannot pull images from public registries at all. Every image must be delivered through an approved internal process. In such environments, local image archives are the only mechanism for getting images onto recovery hosts.

### What you are actually archiving

A container image is a stack of **layers**: read-only filesystem deltas that the container runtime assembles into a virtual filesystem at container startup. Each layer is a gzipped tar archive of filesystem changes. The full image includes:
- A manifest file describing the layers and their order
- Each layer as a compressed tar
- A configuration JSON describing environment variables, exposed ports, the default command, and other metadata

When you run `podman save`, all of this is bundled into a standard OCI Image Layout archive (or Docker-format archive) that can be loaded back on any OCI-compatible runtime.

### When image backup is optional

Not every image needs to be backed up locally. Good candidates for **skipping** local image backup:
- Images from a private internal registry that you control (the registry is your archive)
- Images you build locally via `podman build` that have their Containerfile in version control (you can always rebuild)
- Base OS images (`ubi9`, `alpine`) where you actively want the latest security-patched version

Good candidates for **always** backing up locally:
- Custom-built images with business logic embedded
- Third-party images with specific version requirements
- Images on hosts without internet access
- Images that took a long time to build (e.g., ML model images)

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. `podman save` — OCI Tarball Format and Options

`podman save` is the primary tool for exporting container images to a portable archive file. It writes to a tar archive that can be copied to another machine and loaded with `podman load`.

### Basic syntax

```bash
podman save [OPTIONS] IMAGE[:TAG] [IMAGE[:TAG]...]
```

### Output format

By default, `podman save` produces output to stdout, which you redirect to a file:

```bash
podman save docker.io/bareos/bareos-director:24 > bareos-director-24.tar
```

Or use the `--output` flag:

```bash
podman save --output bareos-director-24.tar docker.io/bareos/bareos-director:24
```

### Formats: OCI vs Docker

Podman supports two archive formats:

**OCI archive (default):**
```bash
podman save --format oci-archive --output bareos-director-24.tar docker.io/bareos/bareos-director:24
```
- Compliant with the OCI Image Spec
- Portable to any OCI-compliant runtime (Podman, Buildah, containerd, etc.)
- The recommended format for long-term archival

**Docker archive format:**
```bash
podman save --format docker-archive --output bareos-director-24.tar docker.io/bareos/bareos-director:24
```
- Compatible with Docker's image format
- Useful if you need to load the image into a Docker daemon
- Required for some legacy tools that do not understand OCI format

For Bareos backup purposes, use `oci-archive`. It is the most portable and future-proof format.

### Saving multiple images in one archive

You can save multiple images into a single OCI archive (multi-image OCI archive):

```bash
podman save \
    --format oci-archive \
    --output all-bareos-images.tar \
    docker.io/bareos/bareos-director:24 \
    docker.io/bareos/bareos-storage:24 \
    docker.io/bareos/bareos-client:24 \
    docker.io/library/mariadb:10.11
```

This is efficient in terms of storage when images share common layers — the shared layers appear only once in the archive.

### Checking image size before saving

Before committing to backing up images, check their sizes:

```bash
# List all images with sizes
export XDG_RUNTIME_DIR=/run/user/1001
podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

Image archives are roughly the same size as the uncompressed image data (the layers are already compressed within the OCI format). A MariaDB image might be 400 MB; the bareos-director image might be 200 MB. Plan your storage accordingly.

### Compressing the archive

The tar file from `podman save` already contains gzip-compressed layers, so additional compression yields minimal benefit. Avoid wrapping it in gzip unless disk space is extremely tight:

```bash
# This provides minimal compression benefit and wastes CPU:
podman save docker.io/bareos/bareos-director:24 | gzip > bareos-director-24.tar.gz

# This is usually good enough:
podman save --output bareos-director-24.tar docker.io/bareos/bareos-director:24
```

Bareos itself applies compression to backed-up files (configured via `Compression = GZIP` in the FileSet), so the file will be compressed in the backup stream regardless.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. `podman export` vs `podman save` — Containers vs Images

The distinction between `podman export` and `podman save` is one of the most common sources of confusion for people new to containers. They produce similar-looking tar archives but contain fundamentally different data.

### `podman save` — saves an image

`podman save` exports a **container image** — the static, layered definition of a container's filesystem, plus its metadata (environment variables, entrypoint, labels, etc.). This archive:
- Contains all image layers
- Contains the image manifest and configuration JSON
- Does **not** contain any runtime state (which processes are running, current network connections)
- Can be loaded back on any machine with `podman load`
- Is the correct tool for disaster recovery archival

### `podman export` — exports a container's filesystem

`podman export` exports a **running or stopped container's** filesystem as a flat tar archive. This archive:
- Contains a single flat tar of the container's merged filesystem (all layers + any changes made at runtime)
- Does **not** contain image metadata (tags, labels, configuration)
- Does **not** contain layer information — it is a "flattened" image with no history
- Can be imported with `podman import`, but the result lacks important metadata and cannot be loaded with `podman load`
- Is useful for extracting specific files from a container, not for backup archival

### Summary table

| Feature | `podman save` | `podman export` |
|---------|---------------|-----------------|
| Operates on | Image | Running/stopped container |
| Output format | OCI archive with layers | Flat tar |
| Contains metadata | Yes (config, tags, labels) | No |
| Contains layer history | Yes | No (flattened) |
| Restores with | `podman load` | `podman import` |
| Suitable for backup | **Yes** | Only for file extraction |
| Preserves image name/tag | Yes | No |

**Rule of thumb**: For Bareos backup purposes, always use `podman save`. You will be grateful for this choice when you need to restore.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Image Naming and Tagging Strategy for Backup

When archiving images, the filename you choose for the archive matters more than it might seem. A filename that encodes the image name, tag, and date makes it easy to find the right archive during restore.

### Recommended naming convention

```
{repository}-{name}-{tag}-{YYYYMMDD}.tar
```

Examples:
```
bareos-bareos-director-24-20260224.tar
library-mariadb-10.11-20260224.tar
mycompany-myapp-v2.3.1-20260224.tar
```

The repository prefix (`bareos`, `library`, `mycompany`) distinguishes images from the same registry that have the same name in different namespaces.

### Encoding the image digest in the filename

An image tag like `24` is a mutable pointer — the same tag can point to different images over time. The image **digest** (a SHA256 hash of the manifest) is immutable and uniquely identifies a specific image version:

```bash
# Get the image digest
podman inspect --format '{{.Digest}}' docker.io/bareos/bareos-director:24
# sha256:a3b9c1d2e4f5...

# Use the first 12 characters of the digest in the filename
DIGEST=$(podman inspect --format '{{.Digest}}' docker.io/bareos/bareos-director:24 | cut -c8-19)
echo "${DIGEST}"  # a3b9c1d2e4f5 (first 12 chars after "sha256:")
```

A filename like `bareos-director-24-20260224-a3b9c1d2e4f5.tar` tells you:
- The image name and tag
- When it was archived
- The exact image version (via the digest prefix)

### Metadata file

For each archive, write a companion metadata file:

```bash
cat > "bareos-director-24-20260224.meta" << EOF
image_name: docker.io/bareos/bareos-director:24
image_tag: 24
image_digest: sha256:a3b9c1d2e4f5...
archive_date: 2026-02-24T14:00:00Z
archive_host: backup-server.example.com
bareos_job: backup-container-images
EOF
```

This metadata file is small (a few hundred bytes) and makes it trivial to identify what is in an archive without loading it.

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Integrating Image Exports into Bareos: RunScript + FileSet Approach

The integration pattern for image backups is identical to the database dump pattern from Chapter 10:

1. A `RunScript { RunsWhen = Before }` hook exports images to a staging directory
2. The Bareos FileSet includes that staging directory
3. Bareos backs up the exported tar files
4. A `RunScript { RunsWhen = After }` hook optionally cleans up old archives

This approach keeps the image export process separate from the Bareos file transfer, which means:
- Bareos does not need to "understand" container images — it just backs up tar files
- The export script can apply business logic (skip certain images, compress, deduplicate)
- Failures in the export step abort the backup, preventing you from recording an incomplete backup as successful

### Job configuration overview

```
Job {
  Name    = "backup-container-images"
  JobDefs = "DefaultJob"
  Client  = "bareos-fd"
  FileSet = "FileSet-container-images"
  Storage = "File"
  Pool    = "Full"
  Type    = Backup

  # Export images to staging directory before backup
  RunScript {
    Command        = "/etc/bareos/scripts/export-images.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  # Clean up old image archives after successful backup
  RunScript {
    Command        = "/etc/bareos/scripts/cleanup-image-exports.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = no
    FailJobOnError = no
  }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. Where to Save the Tarball

The staging directory for image archives needs to satisfy several requirements:
- Large enough to hold all image archives simultaneously
- Writable by UID 1001 (the bareos user)
- Visible to the Bareos File Daemon (either on the host or bind-mounted into the bareos-fd container)
- Accessible by `podman save` (which runs as UID 1001 in the rootless environment)
- Properly labeled for SELinux

### Option A: `/var/tmp/bareos-image-exports/` (recommended for most setups)

```bash
sudo mkdir -p /var/tmp/bareos-image-exports
sudo chown bareos:bareos /var/tmp/bareos-image-exports
sudo chmod 750 /var/tmp/bareos-image-exports
```

**Pros:** `/var/tmp/` persists across reboots (unlike `/tmp/`), has the `tmp_t` SELinux type which bareos-fd can access, and is a conventional location for temporary data.

**Cons:** Content is on the root filesystem. If your OS partition is small, large image archives may fill it.

### Option B: Dedicated mount point

If image archives are large (multi-GB), dedicate a separate filesystem:

```bash
# Assuming /dev/sdb1 is a dedicated partition
sudo mkfs.xfs /dev/sdb1
sudo mkdir -p /srv/bareos-image-exports
echo "/dev/sdb1 /srv/bareos-image-exports xfs defaults 0 0" | sudo tee -a /etc/fstab
sudo mount /srv/bareos-image-exports
sudo chown bareos:bareos /srv/bareos-image-exports
sudo chmod 750 /srv/bareos-image-exports
sudo semanage fcontext -a -t bareos_var_t '/srv/bareos-image-exports(/.*)?'
sudo restorecon -Rv /srv/bareos-image-exports
```

### Option C: Bareos named volume path

The image archives can be stored in a named Podman volume that the bareos-fd container already has access to:

```bash
# As the bareos user
export XDG_RUNTIME_DIR=/run/user/1001
podman volume create bareos-image-exports

# The volume data is stored at:
# ~/.local/share/containers/storage/volumes/bareos-image-exports/_data/
```

This is convenient because the bareos-fd container can access the volume directly. The downside is that the data is stored inside the container storage, which may complicate space management.

### Sizing guidance

Calculate your required space:

```bash
export XDG_RUNTIME_DIR=/run/user/1001
# Sum of all image sizes:
podman images --format "{{.Size}}" | \
    awk '{
        if ($1 ~ /GB$/) { sub(/GB$/, "", $1); total += $1 * 1024 }
        else if ($1 ~ /MB$/) { sub(/MB$/, "", $1); total += $1 }
    } END { printf "Total: %.0f MB\n", total }'
```

You need enough space for **two generations** of archives (current + previous) to handle the case where the new export fails and you need to fall back to the previous one. Add 20% buffer for overhead.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. SELinux Labeling of Export Directories

The export process involves two separate processes that each need access to the staging directory:

1. **The export script** (`/etc/bareos/scripts/export-images.sh`) runs in the bareos-fd domain and writes image archives to the staging directory
2. **Bareos-fd** reads those archives to include them in the backup stream

Both processes run as UID 1001 in the `bareos_t` SELinux domain (or the domain of the bareos-fd container). The staging directory must be writable by this domain.

### Default `/var/tmp/` behavior

The `/var/tmp/` directory and its contents have type `tmp_t`. The `bareos_t` domain is generally allowed to read and write `tmp_t` files. Verify this:

```bash
# Check what SELinux rules allow bareos_t to do with tmp_t
sudo sesearch --allow --source bareos_t --target tmp_t 2>/dev/null | head -20
```

If you see `write`, `create`, `unlink` in the output, you're fine.

### Creating the export directory with correct labels

```bash
# Create the export directory
sudo mkdir -p /var/tmp/bareos-image-exports

# Set ownership to bareos user
sudo chown bareos:bareos /var/tmp/bareos-image-exports
sudo chmod 750 /var/tmp/bareos-image-exports

# Verify the SELinux label (should inherit tmp_t from parent)
ls -Zd /var/tmp/bareos-image-exports
# Expected: system_u:object_r:tmp_t:s0 /var/tmp/bareos-image-exports

# If label is wrong, restore it:
sudo restorecon -Rv /var/tmp/bareos-image-exports
```

### Custom path labeling

If you use a path outside `/var/tmp/`, add a permanent file context:

```bash
# For /srv/bareos-image-exports/
sudo semanage fcontext -a -t bareos_var_t \
    '/srv/bareos-image-exports(/.*)?'

# Apply the new policy
sudo restorecon -Rv /srv/bareos-image-exports

# Verify
ls -Zd /srv/bareos-image-exports
# Expected: system_u:object_r:bareos_var_t:s0 /srv/bareos-image-exports
```

### Bind mounts in Quadlet containers

When you bind-mount the export directory into a container (e.g., to run `podman save` from a script that runs inside a container), use the `:Z` or `:z` suffix:

```ini
# In your Quadlet container file:
# :Z  = private, unshared label (container gets its own copy of the context)
# :z  = shared label (multiple containers can access)
Volume=/var/tmp/bareos-image-exports:/image-exports:Z
```

The `:Z` option automatically runs `chcon` on the host directory to assign it the container's private label type (`container_file_t` or similar). This is the recommended approach for bind mounts in rootless Podman.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Automating Image List Discovery

Rather than hardcoding a list of images in your export script, use `podman images` to discover what images are currently present and export all of them (or filter them with business logic).

### Basic image enumeration

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# List all images as "repository:tag" pairs
podman images --format "{{.Repository}}:{{.Tag}}"

# Example output:
# docker.io/bareos/bareos-director:24
# docker.io/bareos/bareos-storage:24
# docker.io/bareos/bareos-client:24
# docker.io/library/mariadb:10.11
# <none>:<none>   ← dangling image, skip this
```

### Filtering out intermediate and dangling images

Dangling images (those with no name/tag, usually leftover build cache) are not useful to back up and can be quite large. Filter them out:

```bash
podman images \
    --filter "dangling=false" \
    --format "{{.Repository}}:{{.Tag}}"
```

### Getting the image ID and digest alongside the name

```bash
podman images \
    --filter "dangling=false" \
    --format "{{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Digest}}"
```

### Filtering by label

If you want only images that have been explicitly tagged for backup, add a `backup=true` label when pulling or building:

```bash
# Tag an image with a backup label
podman image tag docker.io/bareos/bareos-director:24 bareos-director:backup

# Filter for images with a specific label
podman images --filter "label=backup=yes" --format "{{.Repository}}:{{.Tag}}"
```

### Filtering by repository prefix

Only export images from specific registries:

```bash
podman images --format "{{.Repository}}:{{.Tag}}" | \
    grep -E '^(docker\.io/bareos|docker\.io/library/mariadb)'
```

### Generating safe filenames from image names

Image names contain slashes and colons that are not valid in filenames. Use `sed` or `tr` to sanitize:

```bash
IMAGE="docker.io/bareos/bareos-director:24"

# Replace / and : with - 
# docker.io/bareos/bareos-director:24 → docker.io-bareos-bareos-director-24
SAFE_NAME=$(echo "${IMAGE}" \
    | sed 's|docker\.io/||' \
    | tr '/: ' '---')
echo "${SAFE_NAME}"  # bareos-bareos-director-24
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Restoring Images with `podman load`

`podman load` is the inverse of `podman save`. It reads an OCI archive (or Docker archive) and imports the image into the local container storage.

### Basic syntax

```bash
podman load --input bareos-director-24-20260224.tar

# Or from stdin:
podman load < bareos-director-24-20260224.tar
```

### What `podman load` outputs

```
Getting image source signatures
Copying blob sha256:a1b2c3d4e5f6 done
Copying blob sha256:f6e5d4c3b2a1 done
Copying config sha256:1234567890ab done
Writing manifest to image destination
Loaded image: docker.io/bareos/bareos-director:24
```

The `Loaded image:` line confirms the full name and tag of the restored image. This name is preserved from the original `podman save` command.

### Loading a multi-image archive

If you saved multiple images in a single archive:

```bash
podman load --input all-bareos-images-20260224.tar
# Loads all images from the archive in sequence
```

### Verifying the loaded image

After loading, verify the image is present and the digest matches:

```bash
# List images (the newly loaded image should appear)
podman images

# Check that the digest matches your records
podman inspect --format '{{.Digest}}' docker.io/bareos/bareos-director:24

# Compare with your metadata file
grep image_digest bareos-director-24-20260224.meta
```

### Loading images as a different user

In a rootless Podman setup, images are stored per-user. When you load an image as the `bareos` user (UID 1001), it goes into that user's container storage, not root's. Make sure you load with the correct user:

```bash
# As bareos user
export XDG_RUNTIME_DIR=/run/user/1001
sudo -u bareos podman load --input /path/to/archive.tar

# Verify it loaded into bareos's storage
sudo -u bareos podman images
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Restoring Images on a Fresh Host — The Full Workflow

The real test of your image backup is whether you can restore a running service on a host that has never seen these images. This section walks through the complete restore procedure.

### Prerequisites for the new host

Before starting the restore:

1. **RHEL 10 installed** with Podman and Quadlet support
2. **`bareos` user created** with UID 1001 and the correct sub-UID/GID ranges:

```bash
# Create the bareos user on the new host
sudo useradd \
    --uid 1001 \
    --create-home \
    --shell /bin/bash \
    --comment "Bareos backup system user" \
    bareos

# Configure sub-UID and sub-GID ranges
echo "bareos:100000:65536" | sudo tee -a /etc/subuid
echo "bareos:100000:65536" | sudo tee -a /etc/subgid

# Enable linger so user services start at boot without login
sudo loginctl enable-linger bareos

# Verify linger is enabled
loginctl show-user bareos | grep Linger
# Linger=yes
```

3. **`XDG_RUNTIME_DIR` is correct** for the bareos user:

```bash
# Verify the runtime directory exists (systemd creates it on login or with linger)
ls -ld /run/user/1001
# drwx------. 3 bareos bareos 80 Feb 24 14:00 /run/user/1001
```

### Step 1: Restore Bareos backup to staging area

Use `bconsole` to restore the image archive files from the Bareos backup:

```bash
sudo -u bareos bconsole << 'EOF'
restore
5
jobid=<last-image-backup-jobid>
mark /var/tmp/bareos-image-exports
done
yes
EOF
```

Bareos will restore the files to the configured restore prefix (e.g., `/tmp/bareos-restores/var/tmp/bareos-image-exports/`).

### Step 2: Load each image archive

```bash
export XDG_RUNTIME_DIR=/run/user/1001
RESTORE_DIR="/tmp/bareos-restores/var/tmp/bareos-image-exports"

# Load all image archives
for archive in "${RESTORE_DIR}"/*.tar; do
    echo "Loading image from: ${archive}"
    sudo -u bareos podman load --input "${archive}"
    echo "Loaded: ${archive}"
done

# Verify all images loaded
sudo -u bareos podman images
```

### Step 3: Restore Quadlet configuration files

Your Quadlet `.container`, `.volume`, and `.network` files should also be in the Bareos backup (from the FileSet covering `/home/bareos/.config/containers/systemd/`):

```bash
# Restore Quadlet configs
sudo bconsole << 'EOF'
restore
5
jobid=<last-config-backup-jobid>
mark /home/bareos/.config/containers/systemd
done
yes
EOF

# Copy to correct location
cp -r /tmp/bareos-restores/home/bareos/.config /home/bareos/
chown -R bareos:bareos /home/bareos/.config
```

### Step 4: Restore volume data

Restore the database volumes (covered in Chapter 10's database backup approach):

```bash
# Restore MariaDB volume data
sudo bconsole << 'EOF'
restore
5
jobid=<last-data-backup-jobid>
mark /home/bareos/.local/share/containers/storage/volumes/bareos_mariadb_data/_data
done
yes
EOF

# Copy to named volume location
export XDG_RUNTIME_DIR=/run/user/1001
sudo -u bareos podman volume create bareos_mariadb_data

VOLUME_DATA="/home/bareos/.local/share/containers/storage/volumes/bareos_mariadb_data/_data"
sudo cp -r /tmp/bareos-restores${VOLUME_DATA}/. "${VOLUME_DATA}/"
sudo chown -R bareos:bareos "${VOLUME_DATA}"
```

### Step 5: Reload systemd and start services

```bash
# Reload systemd to pick up Quadlet files
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload

# Start the services
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-mariadb
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-director
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-storage
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user start bareos-fd

# Verify services are running
sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user status 'bareos-*'
```

### Step 6: Verify service health

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Check container status
sudo -u bareos podman ps

# Check Bareos Director is accepting connections
sudo -u bareos podman exec bareos-director bconsole -c /etc/bareos/bconsole.conf << 'EOF'
status director
EOF

# Check MariaDB is accepting connections
sudo -u bareos podman exec bareos-mariadb \
    mysql -u root --password="${MYSQL_ROOT_PASSWORD}" -e "SHOW DATABASES;"
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Registry vs Local Archive Tradeoffs

The question of whether to use a registry or local archives for image backup does not have a single right answer. The best strategy depends on your operational context.

### Using a private registry as your archive

A private registry (such as Quay.io, Harbor, or a self-hosted Docker Distribution registry) stores images in a format optimized for fast push/pull operations. Images pushed to a registry are immediately available to any authorized host.

**Advantages of registry-based archival:**
- Deduplication at the layer level (layers shared between images are stored once)
- Fast pull operations compared to extracting tar archives
- Built-in access control, audit logging, and vulnerability scanning (with enterprise registries)
- Easier to manage across many hosts

**Disadvantages:**
- The registry itself is a single point of failure — if it goes down during a DR event, you cannot pull images
- Requires network access from the restore target to the registry
- Additional infrastructure to maintain

### Using local archives (Bareos-managed)

Storing image archives as files in your Bareos backup set means they travel with the rest of your backup data — they are deduplicated, compressed, and stored in Bareos volumes, potentially offsite.

**Advantages:**
- The image archive is part of the same backup job as the data, ensuring they are always synchronized
- Works in air-gapped environments
- No additional infrastructure required

**Disadvantages:**
- Tar archives are not as efficient as registry storage for images with shared layers (unless you save multiple images in a single archive)
- Restore requires extracting from Bareos first, then loading — two steps instead of one `podman pull`

### Recommended hybrid approach

Use both:
1. **Primary**: Push images to a private internal registry. This is your fast-path for normal operations and routine restore.
2. **Secondary**: Export image archives as part of your Bareos backup. This is your fallback for air-gapped restore, registry unavailability, or point-in-time recovery.

The secondary archive adds relatively little overhead (the export script runs in minutes, Bareos compresses the files) but dramatically improves your disaster recovery resilience.

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. Combining Image Backup with Volume Backup for a Complete Container Backup

A container is defined by three things:
1. **The image** — the software, its configuration, its filesystem layout
2. **The volume data** — the persistent data the container writes (databases, uploaded files, logs)
3. **The runtime configuration** — environment variables, published ports, network settings (encoded in Quadlet `.container` files)

A complete backup captures all three. This chapter focuses on (1). Chapter 10 covered (2). Together, they give you (1) + (2). For (3), you need to back up the Quadlet configuration files.

### The complete FileSet for a full container backup

```
#
# /etc/bareos/bareos-dir.d/fileset/fileset-complete-container-backup.conf
#
FileSet {
  Name = "FileSet-complete-container-backup"

  Include {
    Options {
      Signature   = SHA1
      Compression = GZIP
      # Follow symlinks (important for the "latest" dump symlinks from Chapter 10)
      OneFS       = no
    }

    # 1. IMAGE ARCHIVES (populated by export-images.sh RunScript hook)
    File = "/var/tmp/bareos-image-exports"

    # 2. VOLUME DATA — MariaDB
    File = "/home/bareos/.local/share/containers/storage/volumes/bareos_mariadb_data/_data"

    # 3. VOLUME DATA — Bareos Director catalog
    File = "/home/bareos/.local/share/containers/storage/volumes/bareos_director_config/_data"

    # 4. RUNTIME CONFIGURATION — Quadlet files
    File = "/home/bareos/.config/containers/systemd"

    # 5. DATABASE DUMPS (from Chapter 10 hooks)
    File = "/var/tmp/bareos-dumps"

    # 6. Bareos configuration files
    File = "/etc/bareos"
  }

  Exclude {
    # Exclude the container storage itself (we export images separately)
    File = "/home/bareos/.local/share/containers/storage/overlay"
    File = "/home/bareos/.local/share/containers/storage/overlay-containers"
    # Standard exclusions
    File = "/proc"
    File = "/sys"
    File = "/dev"
    File = "/run"
  }
}
```

### Job combining image export + database dump

```
#
# /etc/bareos/bareos-dir.d/job/backup-complete-stack.conf
#
Job {
  Name      = "backup-complete-stack"
  JobDefs   = "DefaultJob"
  Client    = "bareos-fd"
  FileSet   = "FileSet-complete-container-backup"
  Storage   = "File"
  Pool      = "Full"
  Schedule  = "WeeklyCycle"
  Type      = Backup

  # Step 1: Dump MariaDB (from Chapter 10)
  RunScript {
    Command        = "/etc/bareos/scripts/backup-mariadb.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  # Step 2: Export container images
  RunScript {
    Command        = "/etc/bareos/scripts/export-images.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  # Step 3: Clean up old dump files after backup
  RunScript {
    Command        = "/etc/bareos/scripts/cleanup-dumps.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = no
    FailJobOnError = no
  }

  # Step 4: Clean up old image archives after backup
  RunScript {
    Command        = "/etc/bareos/scripts/cleanup-image-exports.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = no
    FailJobOnError = no
  }
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. Quadlet: How Image Archives Work with Quadlet-Managed Containers

In a Quadlet-managed environment, containers are defined by `.container` files and started by systemd. Understanding how image archives interact with this setup is important for both backup and restore.

### How Quadlet finds images at startup

When systemd starts a Quadlet-managed service, Quadlet generates a transient systemd unit that runs `podman run`. The image name is taken from the `Image=` directive in the `.container` file:

```ini
# /home/bareos/.config/containers/systemd/bareos-director.container
[Container]
Image=docker.io/bareos/bareos-director:24
```

When `podman run` executes, it looks for the image in this order:
1. **Local container storage** (images loaded with `podman load` appear here)
2. **Configured registries** (pulls from remote if not found locally)

This means: if you have loaded the image archive with `podman load` before starting the service, Quadlet will use the locally stored image and **will not attempt a registry pull**. This is exactly the behavior you want in a restore scenario.

### Pinning to a specific image digest in Quadlet

To ensure Quadlet always uses a specific image version (even if the tag has been updated in the registry), pin to the image digest:

```ini
[Container]
# Pinned to specific digest — will use local image if available,
# will pull exactly this digest from registry if not.
Image=docker.io/bareos/bareos-director:24@sha256:a3b9c1d2e4f5...
```

This ensures that even if someone updates the `:24` tag in the registry, your container will use the exact image version you archived.

### Quadlet and image pull policies

Quadlet supports a `PullPolicy` option that controls when Podman checks for newer images:

```ini
[Container]
Image=docker.io/bareos/bareos-director:24
# Options: always, missing, never, newer
# "missing" (default): only pull if not in local storage
# "never": never pull, fail if not in local storage (best for air-gapped restore)
# "always": always pull (ignores local cache)
PullPolicy=missing
```

For disaster recovery scenarios where you have loaded images from archives, set `PullPolicy=missing` (the default) or `PullPolicy=never`. The default `missing` is usually appropriate: it uses the local image if present, falls back to the registry if not.

### Quadlet file backup as part of image backup job

Since Quadlet files encode the image name, tag, and runtime configuration, they are an essential component of your image backup. Always include them in your Bareos FileSet:

```
File = "/home/bareos/.config/containers/systemd"
```

When you restore, copy these files back before running `systemctl --user daemon-reload`, and systemd will regenerate the container units from the Quadlet definitions.

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Lab 11-1: Export a Single Image and Add It to a Bareos FileSet

This lab walks through manually exporting one image and configuring a Bareos FileSet to back it up.

### Prerequisites

- Bareos Director, Storage Daemon, and File Daemon running
- At least one container image in the bareos user's local storage
- `XDG_RUNTIME_DIR=/run/user/1001` configured

### Step 1: Create the export directory

```bash
# Create and label the export directory
sudo mkdir -p /var/tmp/bareos-image-exports
sudo chown bareos:bareos /var/tmp/bareos-image-exports
sudo chmod 750 /var/tmp/bareos-image-exports

# Verify the SELinux label
ls -Zd /var/tmp/bareos-image-exports
# Expected: unconfined_u:object_r:tmp_t:s0 /var/tmp/bareos-image-exports
```

### Step 2: Export the bareos-director image manually

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Verify the image exists
sudo -u bareos podman images --filter reference=bareos-director

# Get image digest for the metadata file
DIGEST=$(sudo -u bareos podman inspect \
    --format '{{.Digest}}' \
    docker.io/bareos/bareos-director:24)
echo "Digest: ${DIGEST}"

# Export the image
DATE=$(date '+%Y%m%d')
ARCHIVE="/var/tmp/bareos-image-exports/bareos-director-24-${DATE}.tar"

sudo -u bareos podman save \
    --format oci-archive \
    --output "${ARCHIVE}" \
    docker.io/bareos/bareos-director:24

echo "Archive created: ${ARCHIVE}"
ls -lh "${ARCHIVE}"

# Write metadata file
sudo -u bareos tee "${ARCHIVE%.tar}.meta" > /dev/null << EOF
image_name: docker.io/bareos/bareos-director:24
image_digest: ${DIGEST}
archive_date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
archive_host: $(hostname)
EOF
```

### Step 3: Configure the Bareos FileSet

Create `/etc/bareos/bareos-dir.d/fileset/fileset-container-images.conf`:

```
#
# /etc/bareos/bareos-dir.d/fileset/fileset-container-images.conf
#
FileSet {
  Name = "FileSet-container-images"

  Include {
    Options {
      Signature   = SHA1
      # Note: GZIP compression provides minimal benefit for OCI archives
      # because the layers inside are already gzip-compressed.
      # Use GZIP level 1 (fast) to avoid wasting CPU.
      Compression = GZIP1
    }

    # All image archives and their metadata files
    File = "/var/tmp/bareos-image-exports"
  }

  Exclude {
    File = "/proc"
    File = "/sys"
  }
}
```

### Step 4: Create a Bareos Job for image backup

Create `/etc/bareos/bareos-dir.d/job/backup-images-manual.conf`:

```
Job {
  Name      = "backup-images-manual"
  JobDefs   = "DefaultJob"
  Client    = "bareos-fd"
  FileSet   = "FileSet-container-images"
  Storage   = "File"
  Pool      = "Full"
  Type      = Backup
  Level     = Full
}
```

### Step 5: Run the job and verify

```bash
# Reload configuration
sudo -u bareos bconsole << 'EOF'
reload
EOF

# Run the job
sudo -u bareos bconsole << 'EOF'
run job=backup-images-manual level=Full yes
wait
messages
EOF

# List the files that were backed up
sudo -u bareos bconsole << 'EOF'
list files jobid=<jobid-from-output>
EOF
```

You should see the tar archive and metadata file in the output.

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Lab 11-2: Automate Multi-Image Export with a RunScript Hook

This lab configures the complete automated image export workflow using the `export-images.sh` script.

### The complete `export-images.sh` script

Save this at `/etc/bareos/scripts/export-images.sh`:

```bash
#!/bin/bash
# =============================================================================
# /etc/bareos/scripts/export-images.sh
#
# Bareos pre-backup hook: export all local Podman container images to OCI
# archive files in a staging directory for Bareos to back up.
#
# This script runs as a ClientRunBeforeJob hook inside the bareos-fd container.
# It enumerates all non-dangling images in the bareos user's Podman storage
# and exports each one to /var/tmp/bareos-image-exports/.
#
# Features:
#   - Exports all local images (configurable exclusions)
#   - Uses stable, human-readable filenames with dates
#   - Writes metadata files alongside each archive
#   - Skips images already exported today (unless FORCE_EXPORT=yes)
#   - Validates each export before proceeding
#   - SELinux-aware (sets tmp_t context on export directory)
#
# Requirements:
#   - /usr/bin/podman must be available
#   - XDG_RUNTIME_DIR=/run/user/1001 must be set (set in bareos-fd env)
#   - Export directory must be writable by UID 1001
#
# Exit codes:
#   0 = success
#   1 = failure (backup should be aborted)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
EXPORT_DIR="/var/tmp/bareos-image-exports"
PODMAN="/usr/bin/podman"
DATE=$(date '+%Y%m%d')
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
EXPORT_TIMEOUT=1800  # 30 minutes per image export

# Skip re-exporting images that already have an archive from today
# Set to "yes" to force re-export of all images
FORCE_EXPORT="${FORCE_EXPORT:-no}"

# Images to skip (space-separated list of patterns, matched with grep -F)
# Example: "none:none localhost/cache"
SKIP_IMAGES="${SKIP_IMAGES:-}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [export-images] $*"
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
log "=== Bareos Container Image Export Hook Starting ==="
log "Job:         ${BAREOS_JOB_NAME:-unknown}"
log "Level:       ${BAREOS_LEVEL:-unknown}"
log "Export dir:  ${EXPORT_DIR}"
log "Date:        ${DATE}"
log "Force:       ${FORCE_EXPORT}"

# Verify podman is available
if ! command -v "${PODMAN}" >/dev/null 2>&1; then
    log "ERROR: podman binary not found at ${PODMAN}"
    exit 1
fi

# Verify XDG_RUNTIME_DIR is set
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    log "WARNING: XDG_RUNTIME_DIR is not set, defaulting to /run/user/1001"
    export XDG_RUNTIME_DIR=/run/user/1001
fi

# Create export directory if it does not exist
if [ ! -d "${EXPORT_DIR}" ]; then
    log "Creating export directory: ${EXPORT_DIR}"
    mkdir -p "${EXPORT_DIR}"
    # Ensure SELinux label is correct (inherits tmp_t from /var/tmp/)
    /usr/sbin/restorecon -Rv "${EXPORT_DIR}" 2>/dev/null || true
fi

# Verify export directory is writable
if [ ! -w "${EXPORT_DIR}" ]; then
    log "ERROR: Export directory is not writable: ${EXPORT_DIR}"
    exit 1
fi

log "Export directory verified: ${EXPORT_DIR}"

# ---------------------------------------------------------------------------
# Enumerate images
# ---------------------------------------------------------------------------
log "Enumerating local container images..."

# Build list of images: "ID REPOSITORY:TAG" pairs
# Filter out dangling images (no name, no tag)
IMAGE_LIST=$("${PODMAN}" images \
    --filter "dangling=false" \
    --format "{{.ID}} {{.Repository}}:{{.Tag}}" \
    2>/dev/null) || {
    log "ERROR: Failed to enumerate images"
    exit 1
}

if [ -z "${IMAGE_LIST}" ]; then
    log "No images found to export"
    exit 0
fi

IMAGE_COUNT=$(echo "${IMAGE_LIST}" | wc -l)
log "Found ${IMAGE_COUNT} image(s) to process"

EXPORTED=0
SKIPPED=0
FAILED=0

# ---------------------------------------------------------------------------
# Export each image
# ---------------------------------------------------------------------------
while IFS=' ' read -r IMAGE_ID IMAGE_NAME; do
    [ -z "${IMAGE_NAME}" ] && continue

    log "---"
    log "Processing image: ${IMAGE_NAME} (ID: ${IMAGE_ID:0:12})"

    # Check if this image should be skipped
    SKIP=false
    for PATTERN in ${SKIP_IMAGES}; do
        if echo "${IMAGE_NAME}" | grep -qF "${PATTERN}"; then
            log "  Skipping (matches exclusion pattern: '${PATTERN}')"
            SKIP=true
            break
        fi
    done
    if [ "$SKIP" = "true" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Generate a safe filename from the image name
    # docker.io/bareos/bareos-director:24 → bareos-bareos-director-24
    SAFE_NAME=$(echo "${IMAGE_NAME}" \
        | sed 's|docker\.io/||; s|localhost/||' \
        | tr '/: ' '---' \
        | tr -cd '[:alnum:]-_.')
    ARCHIVE="${EXPORT_DIR}/${SAFE_NAME}-${DATE}.tar"
    META="${EXPORT_DIR}/${SAFE_NAME}-${DATE}.meta"

    # Check if we already exported this image today
    if [ -f "${ARCHIVE}" ] && [ "${FORCE_EXPORT}" != "yes" ]; then
        ARCHIVE_SIZE=$(du -sh "${ARCHIVE}" | cut -f1)
        log "  Already exported today: ${ARCHIVE} (${ARCHIVE_SIZE}), skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Get image digest for metadata
    DIGEST=$("${PODMAN}" inspect --format '{{.Digest}}' "${IMAGE_ID}" 2>/dev/null || echo "unknown")

    log "  Archive: ${ARCHIVE}"
    log "  Digest:  ${DIGEST:0:35}..."

    # Export the image
    log "  Running podman save..."
    EXPORT_START=$(date '+%s')

    if timeout "${EXPORT_TIMEOUT}" "${PODMAN}" save \
        --format oci-archive \
        --output "${ARCHIVE}.tmp" \
        "${IMAGE_NAME}" 2>&1 | while read -r line; do
            log "    podman: ${line}"
        done; then

        # Verify the archive is non-empty
        if [ ! -s "${ARCHIVE}.tmp" ]; then
            log "  ERROR: Export produced empty archive"
            rm -f "${ARCHIVE}.tmp"
            FAILED=$((FAILED + 1))
            continue
        fi

        # Atomically move the tmp file to final name
        mv "${ARCHIVE}.tmp" "${ARCHIVE}"

        EXPORT_END=$(date '+%s')
        EXPORT_DURATION=$((EXPORT_END - EXPORT_START))
        ARCHIVE_SIZE=$(du -sh "${ARCHIVE}" | cut -f1)

        log "  Export successful:"
        log "    Size:     ${ARCHIVE_SIZE}"
        log "    Duration: ${EXPORT_DURATION}s"

        # Write metadata file
        cat > "${META}" << METAEOF
image_name: ${IMAGE_NAME}
image_id: ${IMAGE_ID}
image_digest: ${DIGEST}
archive_path: ${ARCHIVE}
archive_size_human: ${ARCHIVE_SIZE}
export_date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
export_host: $(hostname)
bareos_job: ${BAREOS_JOB_NAME:-unknown}
bareos_level: ${BAREOS_LEVEL:-unknown}
METAEOF
        log "  Metadata: ${META}"
        EXPORTED=$((EXPORTED + 1))

    else
        EXPORT_EXIT=$?
        log "  ERROR: podman save failed (exit code: ${EXPORT_EXIT})"
        rm -f "${ARCHIVE}.tmp"
        FAILED=$((FAILED + 1))
        # Continue with other images even if one fails
        # (set FAIL_ON_ANY_ERROR=yes to change this behavior)
        if [ "${FAIL_ON_ANY_ERROR:-no}" = "yes" ]; then
            log "FATAL: Aborting due to export failure"
            exit 1
        fi
    fi

done <<< "${IMAGE_LIST}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log "---"
log "Export summary:"
log "  Exported: ${EXPORTED}"
log "  Skipped:  ${SKIPPED}"
log "  Failed:   ${FAILED}"

if [ $FAILED -gt 0 ]; then
    log "WARNING: ${FAILED} image export(s) failed"
    # Exit with failure if any exports failed
    # Remove the exit 1 if you want to proceed even with partial failures
    exit 1
fi

log "=== Bareos Container Image Export Hook Completed Successfully ==="
exit 0
```

### The cleanup script for image exports

```bash
#!/bin/bash
# /etc/bareos/scripts/cleanup-image-exports.sh
# Removes image archives older than KEEP_DAYS days from the export directory.

set -uo pipefail

EXPORT_DIR="/var/tmp/bareos-image-exports"
KEEP_DAYS="${KEEP_DAYS:-7}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [cleanup-images] $*"; }

log "=== Image Export Cleanup Starting ==="
log "Export dir: ${EXPORT_DIR}"
log "Keep days:  ${KEEP_DAYS}"

if [ ! -d "${EXPORT_DIR}" ]; then
    log "Export directory does not exist, nothing to clean"
    exit 0
fi

REMOVED=0
while IFS= read -r -d '' file; do
    log "  Removing: $(basename "${file}")"
    rm -f "${file}" && REMOVED=$((REMOVED + 1)) || \
        log "  WARNING: Failed to remove ${file}"
done < <(find "${EXPORT_DIR}" -maxdepth 1 \
    \( -name "*.tar" -o -name "*.meta" \) \
    -mtime "+${KEEP_DAYS}" \
    -print0 2>/dev/null)

log "Removed ${REMOVED} file(s)"
log "=== Image Export Cleanup Done ==="
exit 0
```

### Install and configure the scripts

```bash
# Make scripts executable
sudo chmod 750 /etc/bareos/scripts/export-images.sh
sudo chmod 750 /etc/bareos/scripts/cleanup-image-exports.sh
sudo chown bareos:bareos /etc/bareos/scripts/export-images.sh
sudo chown bareos:bareos /etc/bareos/scripts/cleanup-image-exports.sh

# SELinux labeling
sudo restorecon /etc/bareos/scripts/export-images.sh
sudo restorecon /etc/bareos/scripts/cleanup-image-exports.sh
```

### Configure the Bareos Job with the export hook

```
#
# /etc/bareos/bareos-dir.d/job/backup-container-images.conf
#
Job {
  Name      = "backup-container-images"
  JobDefs   = "DefaultJob"
  Client    = "bareos-fd"
  FileSet   = "FileSet-container-images"
  Storage   = "File"
  Pool      = "Full"
  Schedule  = "WeeklyCycle"
  Type      = Backup

  # Export all local images to staging directory before backup
  RunScript {
    Command        = "/etc/bareos/scripts/export-images.sh"
    RunsWhen       = Before
    RunsOnClient   = yes
    FailJobOnError = yes
  }

  # Clean up old archives after successful backup
  RunScript {
    Command        = "/etc/bareos/scripts/cleanup-image-exports.sh"
    RunsWhen       = After
    RunsOnClient   = yes
    RunsOnSuccess  = yes
    RunsOnFailure  = no
    FailJobOnError = no
  }
}
```

### Run the automated job

```bash
sudo -u bareos bconsole << 'EOF'
reload
run job=backup-container-images level=Full yes
wait
messages
EOF

# Check the export directory
ls -lh /var/tmp/bareos-image-exports/
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. Lab 11-3: Restore an Image on a Fresh Machine and Restart the Container

This lab simulates a complete disaster recovery scenario: you have a fresh RHEL 10 host with Podman installed but no container images, and you need to restore from a Bareos backup.

### Scenario

- **Backup host**: `backup-server.example.com` — the machine that originally ran the containers
- **Restore host**: `restore-target.example.com` — a fresh RHEL 10 machine
- **Goal**: Restore the `bareos-director:24` image and restart the bareos-director container

### Step 1: Prepare the fresh host

```bash
# On the restore target, as root:

# Verify Podman is installed
rpm -q podman
# podman-5.x.x-x.el10.x86_64

# Create the bareos user with correct UID and sub-UID ranges
useradd \
    --uid 1001 \
    --create-home \
    --shell /bin/bash \
    --comment "Bareos backup system user" \
    bareos

echo "bareos:100000:65536" >> /etc/subuid
echo "bareos:100000:65536" >> /etc/subgid

# Enable linger
loginctl enable-linger bareos

# Verify linger
loginctl show-user bareos | grep Linger
# Linger=yes

# Verify the runtime directory is created (may need to wait a moment)
sleep 2
ls -ld /run/user/1001
```

### Step 2: Install and configure the Bareos File Daemon on the restore target

The restore target needs bareos-fd to communicate with the Director. Install it (or start the bareos-fd container):

```bash
# As the bareos user, start a temporary bareos-fd container for the restore
export XDG_RUNTIME_DIR=/run/user/1001

# Create the Quadlet directory
mkdir -p /home/bareos/.config/containers/systemd/

# Create a minimal bareos-fd Quadlet file for the restore operation
cat > /home/bareos/.config/containers/systemd/bareos-fd.container << 'EOF'
[Unit]
Description=Bareos File Daemon (for restore)
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/bareos/bareos-client:24
ContainerName=bareos-fd

# Mount the restore staging directories
Volume=/var/tmp:/var/tmp:Z
Volume=/home/bareos/.local/share/containers/storage/volumes:/mnt/volumes:Z

# Required for rootless Podman socket access
Volume=/run/user/1001/podman/podman.sock:/run/user/1001/podman/podman.sock:Z

Environment=XDG_RUNTIME_DIR=/run/user/1001

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF

# Reload systemd user daemon
systemctl --user daemon-reload

# Start bareos-fd
systemctl --user start bareos-fd
systemctl --user status bareos-fd
```

### Step 3: Restore the image archive from Bareos

On the Bareos Director, initiate a restore to the restore target:

```bash
# On the backup server, as bareos user:
sudo -u bareos bconsole << 'EOF'
restore client=restore-target-fd
5
<select the image backup job>
mark /var/tmp/bareos-image-exports/bareos-bareos-director-24-20260224.tar
mark /var/tmp/bareos-image-exports/bareos-bareos-director-24-20260224.meta
done
yes
EOF
```

Bareos will restore the files to the prefix path on the restore target. Watch the job complete:

```bash
# On restore target, watch the job messages
sudo -u bareos bconsole << 'EOF'
wait
messages
EOF
```

### Step 4: Locate the restored archive

```bash
# Files are typically restored to /tmp/bareos-restores + original path
ls /tmp/bareos-restores/var/tmp/bareos-image-exports/
# bareos-bareos-director-24-20260224.tar
# bareos-bareos-director-24-20260224.meta
```

### Step 5: Load the image into Podman

```bash
export XDG_RUNTIME_DIR=/run/user/1001

ARCHIVE="/tmp/bareos-restores/var/tmp/bareos-image-exports/bareos-bareos-director-24-20260224.tar"

# Load the image
sudo -u bareos podman load --input "${ARCHIVE}"

# Expected output:
# Getting image source signatures
# Copying blob sha256:... done
# Loaded image: docker.io/bareos/bareos-director:24

# Verify the image is loaded
sudo -u bareos podman images --filter reference=bareos-director
```

### Step 6: Verify the digest matches the metadata

```bash
# Get the digest of the loaded image
LOADED_DIGEST=$(sudo -u bareos podman inspect \
    --format '{{.Digest}}' \
    docker.io/bareos/bareos-director:24)

# Get the expected digest from metadata
EXPECTED_DIGEST=$(grep image_digest "${ARCHIVE%.tar}.meta" | awk '{print $2}')

echo "Loaded digest:   ${LOADED_DIGEST}"
echo "Expected digest: ${EXPECTED_DIGEST}"

if [ "${LOADED_DIGEST}" = "${EXPECTED_DIGEST}" ]; then
    echo "DIGEST MATCH: Image integrity verified"
else
    echo "WARNING: Digest mismatch — image may have been corrupted during backup/restore"
fi
```

### Step 7: Restore Quadlet configuration

```bash
# Restore the Quadlet files (also backed up by Bareos)
QUADLET_RESTORE="/tmp/bareos-restores/home/bareos/.config/containers/systemd"
sudo cp -r "${QUADLET_RESTORE}/." /home/bareos/.config/containers/systemd/
sudo chown -R bareos:bareos /home/bareos/.config/
```

### Step 8: Start the container using the restored image

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Reload systemd to pick up the restored Quadlet files
sudo -u bareos systemctl --user daemon-reload

# Start the bareos-director container
# Since the image is already in local storage (loaded in Step 5),
# Podman will NOT pull from the registry — it uses the loaded image.
sudo -u bareos systemctl --user start bareos-director

# Verify it started using the correct image
sudo -u bareos podman ps --filter name=bareos-director \
    --format "{{.Names}}\t{{.Image}}\t{{.Status}}"

# Expected output:
# bareos-director    docker.io/bareos/bareos-director:24    Up 10 seconds
```

### Step 9: Confirm the image matches the backup

```bash
# Get the digest of the running container's image
RUNNING_DIGEST=$(sudo -u bareos podman inspect bareos-director \
    --format '{{.Image}}' | \
    xargs sudo -u bareos podman inspect --format '{{.Digest}}')

echo "Running container image digest: ${RUNNING_DIGEST}"
echo "Expected (from backup metadata): ${EXPECTED_DIGEST}"
```

The matching digests confirm you are running the exact image that was archived in the backup — bit-for-bit identical to the original.

---

[↑ Back to Table of Contents](#table-of-contents)

## 17. Summary

This chapter gave you a complete, practical understanding of how to include container images in your Bareos backup strategy.

**Key concepts covered:**

- **Why image backup matters**: Registry unavailability, mutable tags, air-gapped environments, and the need for complete reproducibility all make local image archives a critical part of a serious DR strategy.

- **`podman save` vs `podman export`**: Always use `podman save` for backup. It preserves image layers, tags, and metadata. `podman export` produces a flat tar of a container's runtime filesystem — useful for file extraction, not for backup archival.

- **OCI archive format**: Use `--format oci-archive` with `podman save` for maximum portability and long-term archival. The resulting tar file can be loaded on any OCI-compatible runtime.

- **Naming strategy**: Encode the image name, tag, date, and digest in archive filenames. Write companion `.meta` files to make archives self-documenting.

- **The `export-images.sh` script**: Enumerates all local images with `podman images --filter "dangling=false"`, generates safe filenames, exports each image with `podman save --format oci-archive`, writes metadata, and skips images already exported today.

- **SELinux**: The export directory at `/var/tmp/bareos-image-exports/` inherits the `tmp_t` type from `/var/tmp/`. Use the `:Z` mount option for bind mounts in Quadlet container files.

- **Restore workflow**: On a fresh host, create the `bareos` user (UID 1001) with correct sub-UID ranges, enable linger, restore the archive with `bconsole`, load it with `podman load`, restore Quadlet configs, run `systemctl --user daemon-reload`, and start the service. Podman will use the locally loaded image without a registry pull.

- **Digest verification**: After loading a restored image, verify its SHA256 digest matches the metadata from the backup. This confirms image integrity through the backup/restore cycle.

- **Complete backup strategy**: Combining the image archive (Chapter 11) + database dumps (Chapter 10) + Quadlet configuration files gives you three components of a complete container backup: the software, the data, and the runtime definition.

**What to back up for each container:**

| Component | Where it lives | Backup method |
|-----------|---------------|---------------|
| Container image | Local Podman storage | `export-images.sh` → Bareos FileSet |
| Volume data | `~/.local/share/containers/storage/volumes/<name>/_data/` | Direct FileSet include |
| Database dump | `/var/tmp/bareos-dumps/` | `backup-mariadb.sh` or `backup-postgres.sh` hook |
| Quadlet config | `/home/bareos/.config/containers/systemd/` | Direct FileSet include |
| Bareos config | `/etc/bareos/` | Direct FileSet include |

---

[↑ Back to Table of Contents](#table-of-contents)
