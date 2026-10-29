# Lab assets (Chapter 6 baseline)

Copy-paste companions for the course chapters. **Authoritative narrative and labs remain in `chapters/`**; these files reduce transcription errors.

## Layout

| Path | Purpose |
|---|---|
| [`quadlet/`](quadlet/) | Quadlet units for the five-container stack (install under `/home/bareos/.config/containers/systemd/`) |
| [`env/`](env/) | Non-secret env templates (generate real values with `openssl rand -base64 32`) |
| [`scripts/`](scripts/) | Host scripts bind-mounted at `/etc/bareos/scripts` (Chapters 7+) |

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

## Canonical names

See README **Canonical Lab Stack Vocabulary**: network `bareos` (`10.89.10.0/24`), containers `bareos-db` / `bareos-storage` / `bareos-director` / `bareos-fd` / `bareos-webui`, localhost publishes `9101`–`9103` and `9100`.

## Remote multi-client note

This course covers same-host hybrid FD in Chapter 21. Extending to remote RPM clients uses the same Director `Client` pattern with a reachable `Address`, firewall opens, and TLS (Chapter 15) before widening `PublishPort`.
