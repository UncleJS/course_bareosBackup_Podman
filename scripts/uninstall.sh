#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() { cat <<USAGE
Usage: scripts/uninstall.sh [--purge] [--remove-quadlets]
Stop the services and remove the pod, containers, the built image, unused
base images, build cache, networks and the Podman secrets of the lab (the catalog
secret stays with the volumes unless --purge).
  --purge            also remove the volumes (catalog, config, backups) and
                     the catalog password secret
  --remove-quadlets  also remove the units from $UNIT_DIR
Without the flags, the volumes and the Quadlet units are kept.
With JOB=<slug>, removes only that job's instance (names suffixed -<slug>)
and keeps the base images, which the main install may share.
USAGE
}
PURGE=0; RMQ=0
for a in "$@"; do case "$a" in
  -h|--help) usage; exit 0;;
  --purge) PURGE=1;;
  --remove-quadlets) RMQ=1;;
  *) usage >&2; exit 2;;
esac; done
command -v podman >/dev/null || die "podman is not installed"

log "Stopping the services${JOB:+ of job $JOB}"
systemctl --user stop "${SERVICES[@]}" 2>/dev/null || true
systemctl --user reset-failed "${SERVICES[@]}" 2>/dev/null || true

log "Removing pod and containers"
podman pod rm -f "$POD" >/dev/null 2>&1 || true
for c in "${CONTAINERS[@]}"; do podman rm -f "$c" >/dev/null 2>&1 || true; done
ids=$(podman ps -aq --filter "label=$LABEL"); [ -z "$ids" ] || podman rm -f $ids >/dev/null

log "Removing images and build cache"
for _ in 1 2 3; do
  ids=$(podman images -aq --filter "label=$LABEL" | sort -u); [ -n "$ids" ] || break
  podman rmi -f $ids >/dev/null 2>&1 || true
done
podman rmi -f "$IMAGE" >/dev/null 2>&1 || true
podman image prune -f --filter "label=$LABEL" >/dev/null 2>&1 || true
if [ -n "$JOB" ]; then
  log "Kept the base images (shared with the main install): ${BASE_IMAGES[*]}"
else
  for img in "${BASE_IMAGES[@]}"; do
    podman image exists "$img" || continue
    if [ -n "$(podman ps -aq --filter "ancestor=$img")" ]; then
      log "Kept base image $img (still used by a container)"
    elif podman rmi "$img" >/dev/null 2>&1; then
      log "Removed base image $img"
    else
      log "Kept base image $img (still used by another image)"
    fi
  done
fi

log "Removing networks and secrets"
ids=$(podman network ls -q --filter "label=$LABEL"); [ -z "$ids" ] || podman network rm -f $ids >/dev/null
# The catalog keeps its password in the data volume, so its secret goes only
# together with the volumes (--purge); otherwise a reinstall would mismatch it.
for s in "${SECRETS[@]}"; do
  if [ "$PURGE" = 0 ] && [ "$s" = "$DB_SECRET" ]; then
    log "Kept secret $s (matches the kept catalog volume; use --purge to remove it)"
    continue
  fi
  podman secret rm "$s" >/dev/null 2>&1 || true
done

if [ "$PURGE" = 1 ]; then
  for v in "${VOLUMES[@]}"; do podman volume rm -f "$v" >/dev/null 2>&1 || true; done
  ids=$(podman volume ls -q --filter "label=$LABEL"); [ -z "$ids" ] || podman volume rm -f $ids >/dev/null
  log "Removed volumes ${VOLUMES[*]}"
else
  log "Kept volumes ${VOLUMES[*]} (use --purge to remove them)"
fi

if [ "$RMQ" = 1 ]; then
  for u in "${UNITS[@]}"; do rm -f -- "${UNIT_DIR:?}/${u:?}"; done
  systemctl --user daemon-reload
  systemctl --user reset-failed "${SERVICES[@]}" 2>/dev/null || true
  log "Removed the Quadlet units"
else
  log "Kept the Quadlet units in $UNIT_DIR (use --remove-quadlets to remove them)"
fi

log "Checking for leftovers"
left=""
add() { [ -z "$2" ] || left+="$1: $(echo $2)"$'\n'; }
add containers "$(podman ps -a --format '{{.Names}}' | grep -E "$NAME_RE" || true)"
add pods "$(podman pod ls --format '{{.Name}}' | grep -E "$NAME_RE" || true)"
add images "$(podman images -a --format '{{.Repository}}:{{.Tag}}' | grep -E "$NAME_RE" || true)$(podman images -aq --filter "label=$LABEL")"
add networks "$(podman network ls --format '{{.Name}}' | grep -E "$NAME_RE" || true)"
add secrets "$(podman secret ls --format '{{.Name}}' | grep -E "$NAME_RE" | { [ "$PURGE" = 1 ] && cat || grep -vxF "$DB_SECRET"; } || true)"
[ "$PURGE" = 0 ] || add volumes "$(podman volume ls --format '{{.Name}}' | grep -E "$NAME_RE" || true)"
if [ "$RMQ" = 1 ]; then
  add units "$(ls "$UNIT_DIR" 2>/dev/null | grep -E "$UNIT_RE" || true)"
  loaded=""
  for s in "${SERVICES[@]}"; do
    [ "$(systemctl --user show -p LoadState --value "$s" 2>/dev/null)" != loaded ] || loaded+=" $s"
  done
  add services "$loaded"
fi
if [ -n "$left" ]; then
  printf 'Leftovers found:\n%s' "$left" >&2
  exit 1
fi
kept=""
[ "$PURGE" = 1 ] || kept+=" the volumes, the catalog secret"
[ "$RMQ" = 1 ] || kept+="${kept:+ and} the Quadlet units"
log "Clean: nothing from the Bareos lab${JOB:+ job $JOB} remains${kept:+ except$kept}"
