#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() { cat <<USAGE
Usage: scripts/restart.sh
Stop, then start (scripts/stop.sh, then scripts/start.sh).
USAGE
}
for a in "$@"; do case "$a" in
  -h|--help) usage; exit 0;;
  *) usage >&2; exit 2;;
esac; done
"$REPO_ROOT/scripts/stop.sh"
"$REPO_ROOT/scripts/start.sh"
