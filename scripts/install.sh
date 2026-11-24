#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() { cat <<USAGE
Usage: scripts/install.sh
Check prerequisites, build the image, create the Podman secrets for the
catalog database and the WebUI admin login (random, only if missing), copy
the Quadlet units to $UNIT_DIR with this instance's names and ports, and
reload the systemd user manager.
With JOB=<slug> PORT_OFFSET=<n>, installs a separate instance with names
suffixed -<slug> and every host port shifted by <n>.
USAGE
}
for a in "$@"; do case "$a" in
  -h|--help) usage; exit 0;;
  *) usage >&2; exit 2;;
esac; done
check_prereqs
"$REPO_ROOT/scripts/build.sh"
for s in "${SECRETS[@]}"; do
  if podman secret exists "$s"; then
    log "Secret $s exists, kept"
  else
    head -c 48 /dev/urandom | base64 | tr -d '\n/+=' | cut -c1-40 \
      | podman secret create --label "$LABEL" "$s" - >/dev/null
    log "Created secret $s"
  fi
done
mkdir -p "$UNIT_DIR"
for i in "${!SRC_UNITS[@]}"; do
  render_unit "${SRC_UNITS[$i]}" > "$UNIT_DIR/${UNITS[$i]}"
  log "Installed $UNIT_DIR/${UNITS[$i]}"
done
# Every port placeholder must be filled, and a job instance must keep no main-install name.
for u in "${UNITS[@]}"; do
  ! grep -n '@[A-Z_]*_PORT@' "$UNIT_DIR/$u" || die "$UNIT_DIR/$u has an unfilled port placeholder"
  if [ -n "$JOB" ]; then
    for n in "${UNIT_NAMES[@]}"; do
      if grep -v '^#' "$UNIT_DIR/$u" | grep -qE "(^|[^a-z0-9-])$n([^a-z0-9-]|\$)"; then
        die "$UNIT_DIR/$u still uses the main-install name $n; fix render_unit in scripts/common.sh (JOB=$JOB scripts/uninstall.sh --remove-quadlets removes the units)"
      fi
    done
  fi
done
systemctl --user daemon-reload
log "Installed. Start with scripts/start.sh"
