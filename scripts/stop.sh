#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() { cat <<USAGE
Usage: scripts/stop.sh
Stop the lab pod and its containers. Data stays in the volumes.
USAGE
}
for a in "$@"; do case "$a" in
  -h|--help) usage; exit 0;;
  *) usage >&2; exit 2;;
esac; done
systemctl --user stop "${CONTAINER_SERVICES[@]}" "$POD_SERVICE" 2>/dev/null || true
log "Stopped"
