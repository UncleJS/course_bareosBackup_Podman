#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
# Shared names and ports for the lifecycle scripts. Sourced, not executed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Parallel job instances: JOB=<slug> suffixes every name with -<slug> and
# PORT_OFFSET=<n> is added to every published port, so a job pod runs next to
# the main install without touching it. Unset, the names and ports are the defaults.
JOB="${JOB:-}"
PORT_OFFSET="${PORT_OFFSET:-0}"
[[ "$JOB" =~ ^([a-z0-9][a-z0-9-]*)?$ ]] || { echo "JOB must be lowercase kebab-case" >&2; exit 2; }
[[ "$PORT_OFFSET" =~ ^[0-9]+$ ]] || { echo "PORT_OFFSET must be a number" >&2; exit 2; }
PORT_OFFSET=$((10#$PORT_OFFSET))
# A slug that starts like a component name would collide with main-install names
# (JOB=db-data would turn the pod into bareos-lab-db-data, the main volume's name).
[[ ! "$JOB" =~ ^(db|director|storage|fd|webui|config|working|volumes|data|password|admin|pod|infra)(-|$) ]] \
  || { echo "JOB=$JOB clashes with a main-install name" >&2; exit 2; }
# A slug ending in -infra would match another job's infra container name.
[[ ! "$JOB" =~ -infra$ ]] || { echo "JOB must not end in -infra" >&2; exit 2; }
# A job must not overlap the main install's range 10110-10119, and its ports must stay valid.
[ -z "$JOB" ] || [ "$PORT_OFFSET" -ge 10 ] || { echo "JOB needs a PORT_OFFSET >= 10 (10110-10119 belong to the main install)" >&2; exit 2; }
[ $((10119 + PORT_OFFSET)) -le 65535 ] || { echo "PORT_OFFSET is too large (ports above 65535)" >&2; exit 2; }
SFX="${JOB:+-$JOB}"

APP=bareos-lab
LABEL="app=$APP$SFX"

# Registered range for this repo (00_repoMan): 10110-10119. The lab pod uses
# the first four ports, on 127.0.0.1 only. The ports inside the pod stay the
# Bareos defaults (WebUI 80, Director 9101, FD 9102, SD 9103); the catalog
# database (PostgreSQL 5432) is pod-internal and never published.
PORT_RANGE=10110-10119
WEBUI_PORT=$((10110 + PORT_OFFSET))   # WebUI       -> pod port 80
DIR_PORT=$((10111 + PORT_OFFSET))     # Director    -> pod port 9101
FD_PORT=$((10112 + PORT_OFFSET))      # File Daemon -> pod port 9102
SD_PORT=$((10113 + PORT_OFFSET))      # Storage     -> pod port 9103
WEBUI_URL="http://127.0.0.1:$WEBUI_PORT/bareos-webui/"

POD=$APP$SFX
POD_SERVICE=$POD-pod.service
CONTAINERS=("$APP-db$SFX" "$APP-director$SFX" "$APP-storage$SFX" "$APP-fd$SFX" "$APP-webui$SFX")
VOLUMES=("$APP-db-data$SFX" "$APP-config$SFX" "$APP-working$SFX" "$APP-volumes$SFX")
SECRETS=("$APP-db-password$SFX" "$APP-admin-password$SFX")
ADMIN_SECRET="$APP-admin-password$SFX"
DB_SECRET="$APP-db-password$SFX"
IMAGE=localhost/$APP$SFX:latest
BASE_IMAGES=(docker.io/library/debian:12-slim docker.io/library/postgres:17)
CONTAINER_SERVICES=(); for c in "${CONTAINERS[@]}"; do CONTAINER_SERVICES+=("$c.service"); done
VOLUME_SERVICES=(); for v in "${VOLUMES[@]}"; do VOLUME_SERVICES+=("$v-volume.service"); done
SERVICES=("${CONTAINER_SERVICES[@]}" "$POD_SERVICE" "${VOLUME_SERVICES[@]}")

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
SRC_UNITS=()
for f in quadlet/*.pod quadlet/*.container quadlet/*.volume; do SRC_UNITS+=("${f#quadlet/}"); done
UNITS=(); for u in "${SRC_UNITS[@]}"; do UNITS+=("${u%.*}$SFX.${u##*.}"); done

# Exact names of this instance, for uninstall.sh's leftover check. From the
# main install they never match a job's names, and the other way round.
NAME_RE="^(localhost/)?$APP(-db|-director|-storage|-fd|-webui|-db-data|-config|-working|-volumes|-db-password|-admin-password)?$SFX(-infra)?(:latest)?\$"
UNIT_RE="^$APP(-db|-director|-storage|-fd|-webui|-db-data|-config|-working|-volumes)?$SFX\.(pod|container|volume)\$"

# Every name in the units, longest first, so render_unit can suffix them.
UNIT_NAMES=(bareos-lab-admin-password bareos-lab-db-password bareos-lab-db-data bareos-lab-director
            bareos-lab-storage bareos-lab-working bareos-lab-volumes bareos-lab-config bareos-lab-webui
            bareos-lab-db bareos-lab-fd bareos-lab)

# Print quadlet/<src unit> with this instance's names and ports.
render_unit() {
  local args=() n
  if [ -n "$SFX" ]; then
    for n in "${UNIT_NAMES[@]}"; do
      args+=(-e "s/(^|[^a-z0-9-])$n([^a-z0-9-]|\$)/\\1$n$SFX\\2/g")
    done
  fi
  sed -E "${args[@]}" \
      -e "s/@WEBUI_PORT@/$WEBUI_PORT/g" -e "s/@DIR_PORT@/$DIR_PORT/g" \
      -e "s/@FD_PORT@/$FD_PORT/g" -e "s/@SD_PORT@/$SD_PORT/g" \
      "quadlet/$1"
}

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

check_podman() {
  command -v podman >/dev/null || die "podman is not installed"
  [ "$(id -u)" -ne 0 ] || die "run as a normal user (rootless podman), not root"
  [ "$(podman info --format '{{.Host.Security.Rootless}}')" = "true" ] || die "podman is not rootless"
}

check_prereqs() {
  check_podman
  systemctl --user show-environment >/dev/null 2>&1 || die "no systemd user session"
  [ -x /usr/libexec/podman/quadlet ] || [ -x /usr/lib/podman/quadlet ] || log "WARNING: the Quadlet generator was not found"
}
