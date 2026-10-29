#!/bin/sh
# Dump the Bareos catalog from the bareos-db container over the network.
# Runs inside bareos-director (RunsOnClient = no). MARIADB_* from EnvironmentFile=db.env.
# See Chapter 7 — BackupCatalog job.
set -eu
mkdir -p /var/lib/bareos/catalog-dump
mariadb-dump \
  --host=bareos-db \
  --user="${MARIADB_USER}" \
  --password="${MARIADB_PASSWORD}" \
  --single-transaction \
  "${MARIADB_DATABASE}" \
  | gzip > /var/lib/bareos/catalog-dump/bareos-catalog.sql.gz
