#!/bin/sh
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
#
# Entrypoint of the lab image. One argument picks the daemon:
#   director | storage | filedaemon | webui
# All containers share the pod's network, so the daemons and the catalog
# database talk over 127.0.0.1 with their standard ports (9101-9103, 5432).
set -eu

CONF=/etc/bareos                 # the bareos-lab-config volume
MARKER=$CONF/.lab-initialized
DB_SECRET=/run/secrets/db-password
ADMIN_SECRET=/run/secrets/admin-password

log() { echo "bareos-lab: $*"; }

wait_for_config() {
  i=0
  until [ -f "$MARKER" ]; do
    i=$((i + 1)); [ "$i" -le 120 ] || { log "no initialized config in $CONF"; exit 1; }
    sleep 1
  done
}

init_config() {
  # A fresh volume holds the image's template; give every placeholder a random value once.
  if [ ! -f "$MARKER" ]; then
    [ -n "$(ls -A "$CONF" 2>/dev/null)" ] || cp -a /usr/share/bareos-lab-config/. "$CONF/"
    for ph in $(grep -rhoE '@LAB_PW_[0-9]+@' "$CONF" | sort -u); do
      pw=$(openssl rand -base64 33 | tr -d '\n/+=' | cut -c1-40)
      grep -rlF "$ph" "$CONF" | while read -r f; do sed -i "s|$ph|$pw|g" "$f"; done
    done
    log "generated the daemon passwords"
  fi
  # Catalog and WebUI login follow the Podman secrets on every start.
  [ -r "$DB_SECRET" ] || { log "missing secret $DB_SECRET"; exit 1; }
  [ -r "$ADMIN_SECRET" ] || { log "missing secret $ADMIN_SECRET"; exit 1; }
  dbpw=$(cat "$DB_SECRET"); adminpw=$(cat "$ADMIN_SECRET")
  cat > "$CONF/bareos-dir.d/catalog/MyCatalog.conf" <<CAT
Catalog {
  Name = MyCatalog
  dbname = "bareos"
  dbuser = "bareos"
  dbpassword = "$dbpw"
  dbaddress = "127.0.0.1"
  dbport = 5432
}
CAT
  cat > "$CONF/bareos-dir.d/console/admin.conf" <<ADM
Console {
  Name = admin
  Password = "$adminpw"
  Profile = "webui-admin"
  TLS Enable = No
}
ADM
  chown -R bareos:bareos "$CONF"
  chmod 640 "$CONF/bareos-dir.d/catalog/MyCatalog.conf" "$CONF/bareos-dir.d/console/admin.conf"
  touch "$MARKER"
}

init_catalog() {
  export PGHOST=127.0.0.1 PGUSER=bareos PGDATABASE=bareos PGPASSWORD="$(cat "$DB_SECRET")"
  i=0
  until pg_isready -q; do
    i=$((i + 1)); [ "$i" -le 60 ] || { log "catalog database not reachable"; exit 1; }
    sleep 1
  done
  if [ "$(psql -tAc "SELECT 1 FROM information_schema.tables WHERE table_name = 'version'")" != 1 ]; then
    log "creating the catalog tables"
    db_name=bareos db_user=bareos /usr/lib/bareos/scripts/make_bareos_tables
  fi
}

case "${1:-}" in
  director)
    init_config
    init_catalog
    bareos-dir -t -u bareos -g bareos
    exec bareos-dir -f -u bareos -g bareos
    ;;
  storage)
    wait_for_config
    chown bareos:bareos /var/lib/bareos/storage
    exec bareos-sd -f -u bareos -g bareos
    ;;
  filedaemon)
    wait_for_config
    exec bareos-fd -f
    ;;
  webui)
    exec apache2ctl -D FOREGROUND
    ;;
  *)
    echo "usage: bareos-lab director|storage|filedaemon|webui" >&2
    exit 2
    ;;
esac
