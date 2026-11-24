#!/bin/sh
# SPDX-License-Identifier: CC-BY-NC-SA-4.0
# Copyright (C) 2026 UncleJS
#
# Build step: turn the package's /etc/bareos into a template without secrets.
# The package install generated random passwords; each distinct one becomes a
# placeholder (@LAB_PW_1@, @LAB_PW_2@, ...) so the image holds no secret. The
# entrypoint replaces the placeholders with fresh values on first start.
set -eu
n=0
for pw in $(grep -rhoE 'Password = "[^"]+"' /etc/bareos | sed -E 's/.*"(.*)"/\1/' | grep -vx admin | sort -u); do
  n=$((n + 1))
  grep -rlF "\"$pw\"" /etc/bareos | while read -r f; do
    sed -i "s|\"$pw\"|\"@LAB_PW_$n@\"|g" "$f"
  done
done
[ "$n" -gt 0 ] || { echo "no generated passwords found in /etc/bareos" >&2; exit 1; }
if grep -rqE 'Password = "[A-Za-z0-9+/]{30,}"' /etc/bareos; then
  echo "a generated password is still in /etc/bareos" >&2; exit 1
fi
# In the pod every daemon is reachable on 127.0.0.1.
sed -i -E 's/^( *Address = )[^ ]+/\1127.0.0.1/' /etc/bareos/bareos-dir.d/storage/File.conf
rm -f /etc/bareos/.rndpwd
cp -a /etc/bareos /usr/share/bareos-lab-config
echo "prepared /etc/bareos with $n password placeholders"
