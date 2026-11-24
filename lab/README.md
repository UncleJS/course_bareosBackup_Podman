# Lab assets (Chapter 6 baseline)

[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey)](../LICENSE.md)
[![RHEL 10](https://img.shields.io/badge/platform-RHEL%2010-red)](https://access.redhat.com/products/red-hat-enterprise-linux)
[![Bareos](https://img.shields.io/badge/Bareos-v24-orange)](https://www.bareos.com)

## Table of Contents

- [Layout](#layout)
- [Install (sketch)](#install-sketch)
- [Canonical names](#canonical-names)
- [Remote multi-client note](#remote-multi-client-note)

Copy-paste companions for the course chapters. **Authoritative narrative and labs remain in `chapters/`**; these files reduce transcription errors.

## Layout

| Path | Purpose |
|---|---|
| [`quadlet/`](quadlet/) | Quadlet units for the five-container stack (install under `/home/bareos/.config/containers/systemd/`) |
| [`env/`](env/) | Non-secret env templates (generate real values with `openssl rand -base64 32`) |
| [`scripts/`](scripts/) | Host scripts bind-mounted at `/etc/bareos/scripts` (Chapters 7+) |

[↑ Back to TOC](#table-of-contents)

---

## Install (sketch)

Follow [Chapter 6](../chapters/06-bareos-in-podman.md) for secrets, SELinux, catalog init, and Director/SD/FD `.conf` trees. Typical flow:

```bash
# As root / with sudo — create host paths first (see Chapter 3 / 6)
sudo mkdir -p /etc/bareos/{bareos-dir.d,bareos-sd.d,scripts}
sudo mkdir -p /var/tmp/bareos-restores /srv/bareos-storage/volumes
sudo chown -R bareos:bareos /etc/bareos /var/tmp/bareos-restores /srv/bareos-storage

# Copy Quadlets
sudo -u bareos cp lab/quadlet/* /home/bareos/.config/containers/systemd/

# Generate secrets into ~/.config/bareos/ (do not commit real env files)
sudo -u bareos bash -c '
  install -d -m 700 ~/.config/bareos
  # fill db.env / bareos.env from lab/env/*.example using openssl rand
'

# Optional: install catalog dump helpers
sudo cp lab/scripts/*.sh /etc/bareos/scripts/
sudo chmod 755 /etc/bareos/scripts/*.sh
sudo chown bareos:bareos /etc/bareos/scripts/*.sh

sudo -u bareos XDG_RUNTIME_DIR=/run/user/1001 systemctl --user daemon-reload
```

[↑ Back to TOC](#table-of-contents)

---

## Canonical names

See README **Canonical Lab Stack Vocabulary**: network `bareos` (`10.89.10.0/24`), containers `bareos-db` / `bareos-storage` / `bareos-director` / `bareos-fd` / `bareos-webui`, localhost publishes `127.0.0.1:10111` (Director), `10112` (FD), `10113` (SD) and `10110` (WebUI) from the course range 10110-10119; inside the containers Bareos keeps 9101-9103 and the WebUI 80. The catalog (`bareos-db:3306`) is never published.

[↑ Back to TOC](#table-of-contents)

---

## Remote multi-client note

This course covers same-host hybrid FD in Chapter 21. Extending to remote RPM clients uses the same Director `Client` pattern with a reachable `Address`, firewall opens, and TLS (Chapter 15) before widening `PublishPort`.

[↑ Back to TOC](#table-of-contents)

---

© 2026 UncleJS — Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)
