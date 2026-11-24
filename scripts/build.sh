#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() { cat <<USAGE
Usage: scripts/build.sh
Build the lab image $IMAGE from container/Containerfile
(Bareos community packages on Debian 12).
USAGE
}
for a in "$@"; do case "$a" in
  -h|--help) usage; exit 0;;
  *) usage >&2; exit 2;;
esac; done
check_podman
log "Building $IMAGE"
# --layers=false: no cached intermediate images are left behind for uninstall.sh to find
podman build --pull=missing --layers=false --label "$LABEL" -t "$IMAGE" -f container/Containerfile container
podman image prune -f --filter "label=$LABEL" >/dev/null 2>&1 || true
log "Built $IMAGE"
