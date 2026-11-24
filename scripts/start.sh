#!/usr/bin/env bash
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

usage() { cat <<USAGE
Usage: scripts/start.sh
Start the lab pod ($POD_SERVICE and its containers), wait until the
Director and the WebUI answer, and print the URLs.
USAGE
}
for a in "$@"; do case "$a" in
  -h|--help) usage; exit 0;;
  *) usage >&2; exit 2;;
esac; done
[ -f "$UNIT_DIR/$POD.pod" ] || die "units are not installed; run scripts/install.sh first"
systemctl --user start "$POD_SERVICE" "${CONTAINER_SERVICES[@]}"
log "Waiting for the Director and the WebUI"
for _ in $(seq 1 90); do
  if podman exec "$APP-webui$SFX" curl -fsS -o /dev/null http://127.0.0.1/bareos-webui/ 2>/dev/null \
     && podman exec "$APP-director$SFX" sh -c 'echo "status director" | bconsole' 2>/dev/null | grep 'Daemon started' >/dev/null; then
    log "Bareos lab is running"
    log "  WebUI        $WEBUI_URL  (user admin, password: podman secret inspect --showsecret --format '{{.SecretData}}' $ADMIN_SECRET)"
    log "  Director     127.0.0.1:$DIR_PORT"
    log "  File Daemon  127.0.0.1:$FD_PORT"
    log "  Storage      127.0.0.1:$SD_PORT"
    exit 0
  fi
  sleep 2
done
die "the lab did not come up; see: journalctl --user -u $APP-director$SFX.service"
