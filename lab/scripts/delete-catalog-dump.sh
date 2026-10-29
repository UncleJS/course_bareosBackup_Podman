#!/bin/sh
# Remove catalog dump after BackupCatalog captures it (Chapter 7).
set -eu
rm -f /var/lib/bareos/catalog-dump/bareos-catalog.sql.gz
