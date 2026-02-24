# Chapter 15: TLS Encryption and Certificate Management for Bareos

## Table of Contents

- [1. Why TLS Matters for Backup](#1-why-tls-matters-for-backup)
  - [1.1 TLS vs. At-Rest Encryption](#11-tls-vs-at-rest-encryption)
  - [1.2 The Cost of TLS](#12-the-cost-of-tls)
- [2. Bareos TLS Architecture: Which Connections Are Encrypted](#2-bareos-tls-architecture-which-connections-are-encrypted)
  - [2.1 Who Is the TLS Server and Who Is the Client?](#21-who-is-the-tls-server-and-who-is-the-client)
- [3. PKI Basics: CA, Certificates, Private Keys, and CSRs](#3-pki-basics-ca-certificates-private-keys-and-csrs)
  - [3.1 The Problem TLS Solves (and How It Does It)](#31-the-problem-tls-solves-and-how-it-does-it)
  - [3.2 Key Terms Defined](#32-key-terms-defined)
  - [3.3 The Trust Relationship](#33-the-trust-relationship)
- [4. Bareos TLS Configuration Directives](#4-bareos-tls-configuration-directives)
  - [4.1 Directive Location in Configuration Files](#41-directive-location-in-configuration-files)
- [5. Two TLS Modes in Bareos: TLS-PSK and TLS-cert](#5-two-tls-modes-in-bareos-tls-psk-and-tls-cert)
  - [5.1 TLS-PSK (Pre-Shared Key) — The Default](#51-tls-psk-pre-shared-key-the-default)
  - [5.2 TLS-cert (Certificate-Based TLS)](#52-tls-cert-certificate-based-tls)
- [6. TLS-PSK: How It Works in Bareos](#6-tls-psk-how-it-works-in-bareos)
  - [6.1 The Password-as-PSK Mechanism](#61-the-password-as-psk-mechanism)
  - [6.2 PSK Without Certificates](#62-psk-without-certificates)
  - [6.3 PSK + Certificates Together](#63-psk-certificates-together)
- [7. Certificate-Based TLS: Generating the CA and All Certificates](#7-certificate-based-tls-generating-the-ca-and-all-certificates)
  - [7.1 Certificate Naming Convention](#71-certificate-naming-convention)
  - [7.2 OpenSSL Configuration Files](#72-openssl-configuration-files)
- [8. Self-Signed CA Setup: Complete Step-by-Step](#8-self-signed-ca-setup-complete-step-by-step)
  - [8.1 Create the TLS Directory Structure](#81-create-the-tls-directory-structure)
  - [8.2 Generate the CA Private Key and Certificate](#82-generate-the-ca-private-key-and-certificate)
  - [8.3 Create OpenSSL Extension Files for Each Certificate](#83-create-openssl-extension-files-for-each-certificate)
  - [8.4 Generate the Director Certificate](#84-generate-the-director-certificate)
  - [8.5 Generate the Storage Daemon Certificate](#85-generate-the-storage-daemon-certificate)
  - [8.6 Generate the File Daemon Certificate](#86-generate-the-file-daemon-certificate)
  - [8.7 Generate the bconsole Certificate](#87-generate-the-bconsole-certificate)
  - [8.8 Generate Diffie-Hellman Parameters](#88-generate-diffie-hellman-parameters)
  - [8.9 Final File Summary and Permissions](#89-final-file-summary-and-permissions)
- [9. Distributing Certificates to Containers via Quadlet](#9-distributing-certificates-to-containers-via-quadlet)
  - [9.1 Why Bind-Mount Instead of Copying Into the Image](#91-why-bind-mount-instead-of-copying-into-the-image)
  - [9.2 Updated Quadlet Files with TLS Mounts](#92-updated-quadlet-files-with-tls-mounts)
  - [9.3 Reload Systemd to Apply Quadlet Changes](#93-reload-systemd-to-apply-quadlet-changes)
- [10. Director TLS Configuration](#10-director-tls-configuration)
  - [10.1 bareos-dir.conf: Director Resource](#101-bareos-dirconf-director-resource)
  - [10.2 Client Resource: Director→FD TLS Settings](#102-client-resource-directorfd-tls-settings)
  - [10.3 Storage Resource: Director→SD TLS Settings](#103-storage-resource-directorsd-tls-settings)
- [11. Storage Daemon TLS Configuration](#11-storage-daemon-tls-configuration)
- [12. File Daemon TLS Configuration](#12-file-daemon-tls-configuration)
  - [12.1 bareos-fd.conf: FD Main Resource](#121-bareos-fdconf-fd-main-resource)
  - [12.2 Director Resource in bareos-fd.conf](#122-director-resource-in-bareos-fdconf)
  - [12.3 Messages Resource (No TLS Needed)](#123-messages-resource-no-tls-needed)
- [13. bconsole TLS Configuration](#13-bconsole-tls-configuration)
  - [13.1 Updating the Director's Console Resource](#131-updating-the-directors-console-resource)
- [14. Verifying TLS Connections](#14-verifying-tls-connections)
  - [14.1 Checking Bareos Logs for TLS Messages](#141-checking-bareos-logs-for-tls-messages)
  - [14.2 Testing with openssl s_client](#142-testing-with-openssl-s_client)
  - [14.3 Testing That TLS Is Required](#143-testing-that-tls-is-required)
  - [14.4 Running a Test Backup Job to Confirm End-to-End TLS](#144-running-a-test-backup-job-to-confirm-end-to-end-tls)
  - [14.5 bconsole Status Check](#145-bconsole-status-check)
- [15. Certificate Rotation Procedure](#15-certificate-rotation-procedure)
  - [15.1 Checking Certificate Expiration](#151-checking-certificate-expiration)
  - [15.2 Rotating a Single Certificate (e.g., File Daemon)](#152-rotating-a-single-certificate-eg-file-daemon)
  - [15.3 Rotating the CA Certificate](#153-rotating-the-ca-certificate)
- [16. SELinux: Certificate File Labeling](#16-selinux-certificate-file-labeling)
  - [16.1 Default Labels and the Problem](#161-default-labels-and-the-problem)
  - [16.2 The :Z Mount Option (Automatic Relabeling)](#162-the-z-mount-option-automatic-relabeling)
  - [16.3 Manual Relabeling with chcon](#163-manual-relabeling-with-chcon)
  - [16.4 Making Labels Persistent with semanage fcontext](#164-making-labels-persistent-with-semanage-fcontext)
  - [16.5 The bareos_etc_t Type](#165-the-bareos_etc_t-type)
  - [16.6 Verifying SELinux Is Not Blocking Access](#166-verifying-selinux-is-not-blocking-access)
- [Lab 15-1: Set Up a Bareos CA and Generate All Certificates](#lab-15-1-set-up-a-bareos-ca-and-generate-all-certificates)
- [Lab 15-2: Configure All Bareos Daemons to Use Certificates](#lab-15-2-configure-all-bareos-daemons-to-use-certificates)
- [Lab 15-3: Verify Encrypted Connections and Rotate a Certificate](#lab-15-3-verify-encrypted-connections-and-rotate-a-certificate)
- [20. Summary](#20-summary)

## 1. Why TLS Matters for Backup

A backup system is a privileged system. The Bareos File Daemon reads every file on every client machine — configuration files, database dumps, application secrets, SSH keys, and more. The Storage Daemon receives all of that data and writes it to disk. The Director coordinates the entire process, storing job metadata including file paths and checksums.

All of this data moves across the network. Without encryption, anyone with access to the network path between these components can:

- **Read the backup data** as it streams past — file contents, database records, private keys
- **Inject data** into an unencrypted stream, potentially inserting malicious content into a backup that will later be restored
- **Replay captured credentials** from the Bareos authentication handshake to impersonate a client or storage daemon

These are not theoretical threats. In any environment where network traffic is observable — cloud VPCs with shared subnets, office networks, data center environments with multiple tenants — unencrypted backup traffic is a significant data breach risk.

**TLS (Transport Layer Security)** solves this by establishing an encrypted tunnel between each pair of communicating parties. All data transmitted through the tunnel is:
- **Confidential:** encrypted so that network observers see only ciphertext
- **Authenticated:** each party proves its identity before the tunnel is established
- **Integrity-protected:** any tampering with the data in transit causes the connection to fail

### 1.1 TLS vs. At-Rest Encryption

TLS protects data **in transit** only — while it is moving across the network. It does not protect data stored on disk. For at-rest protection, Bareos has a separate feature called **Volume Encryption** (using AES). This chapter focuses exclusively on TLS.

### 1.2 The Cost of TLS

TLS adds CPU overhead for encryption and decryption. On modern hardware, this overhead is negligible for most backup workloads — backup is typically I/O bound, not CPU bound. The small CPU cost of TLS is always worth the security benefit.

---

[↑ Back to Table of Contents](#table-of-contents)

## 2. Bareos TLS Architecture: Which Connections Are Encrypted

Bareos uses a three-component architecture. Understanding which component communicates with which, and in which direction, is essential before configuring TLS.

```
┌───────────────┐     DIR:9101     ┌───────────────────┐
│   bconsole    │ ───────────────> │  Bareos Director  │
│  (operator)   │                  │    (bareos-director)   │
└───────────────┘                  └────────┬──────────┘
                                            │
                          DIR→SD: 9103      │      DIR→FD: 9102
                                   ┌────────┴──────────┐
                                   │                   │
                          ┌────────▼──────┐   ┌────────▼──────┐
                          │ Storage Daemon│   │  File Daemon  │
                          │ (bareos-storage)   │   │ (bareos-fd)   │
                          └────────┬──────┘   └───────────────┘
                                   │
                          SD←FD: 9103 (data channel)
                                   │
                          ┌────────▼──────┐
                          │  File Daemon  │
                          │ (data stream) │
                          └───────────────┘
```

There are **four distinct TLS connections** to configure:

| Connection | Direction | Default Port | Parties |
|-----------|-----------|-------------|---------|
| `bconsole → Director` | Client → Server | 9101 | Console authenticates to Director |
| `Director → File Daemon` | Client → Server | 9102 | Director authenticates to FD (and optionally FD authenticates to DIR) |
| `Director → Storage Daemon` | Client → Server | 9103 | Director authenticates to SD |
| `File Daemon → Storage Daemon` | Client → Server | 9103 (data) | FD connects to SD to stream data |

Each connection has **independent TLS settings**. A common mistake is configuring only one or two connections and assuming all data is encrypted. You must configure TLS on both ends of **every** connection.

### 2.1 Who Is the TLS Server and Who Is the Client?

In TLS, the "server" is the side that holds the certificate and listens for connections. The "client" initiates the connection.

- **Director**: TLS server for bconsole connections; TLS client for connections to FD and SD
- **File Daemon**: TLS server for connections from the Director
- **Storage Daemon**: TLS server for connections from the Director and from File Daemons
- **bconsole**: TLS client connecting to the Director

This distinction matters when configuring `TLS Certificate` and `TLS Key`: the server side must have them; the client side needs them only if mutual authentication (peer verification) is enabled.

---

[↑ Back to Table of Contents](#table-of-contents)

## 3. PKI Basics: CA, Certificates, Private Keys, and CSRs

Before diving into Bareos-specific configuration, we need to understand Public Key Infrastructure (PKI). If you have never worked with TLS certificates before, this section will give you everything you need.

### 3.1 The Problem TLS Solves (and How It Does It)

Encryption alone is not enough. If you encrypt traffic between your Director and your File Daemon, but an attacker can intercept the connection and pretend to be the File Daemon, they can decrypt everything. You need **authentication** — proof that you are talking to who you think you are.

TLS uses **asymmetric cryptography** (also called public-key cryptography) for authentication:

- Every party has a **key pair**: a **private key** (kept secret, never shared) and a **public key** (freely shared with everyone)
- A **certificate** is a document that binds a public key to an identity (e.g., "this public key belongs to bareos-director.example.com")
- A **Certificate Authority (CA)** is a trusted third party that digitally signs certificates, vouching for their authenticity
- When the File Daemon receives the Director's certificate, it checks: "Is this certificate signed by a CA I trust?" If yes, it trusts the Director's identity

For internal infrastructure like Bareos, you create your **own CA** (a "private CA" or "internal CA"). You configure all Bareos daemons to trust your CA. Any certificate signed by your CA is trusted by all your daemons.

### 3.2 Key Terms Defined

**Private key (`.key` file):**
A randomly generated large number, kept secret on the machine that owns it. Used to sign data and decrypt messages. If this file is compromised, the attacker can impersonate that machine. Protect with mode `0600`.

**Public key:**
Mathematically derived from the private key. Freely shareable. Used by others to verify signatures and encrypt messages to you.

**Certificate (`.crt` or `.pem` file):**
A document containing: a public key, an identity (the "subject": Common Name, organization, etc.), a validity period (not-before and not-after dates), and a digital signature from a CA. Mode `0644` is fine — it is not secret.

**CSR (Certificate Signing Request, `.csr` file):**
A request you send to a CA asking it to sign your public key. Contains your identity information and public key, signed with your private key (to prove you own it). The CA verifies the CSR and returns a signed certificate.

**CA certificate:**
The CA's own certificate, self-signed. All clients that trust this CA must have a copy of this certificate. Used to verify the signature on other certificates.

**Certificate chain:**
In multi-level PKI, certificates can be signed by intermediate CAs, which are signed by root CAs. For our purposes (single internal CA), there is no chain — the CA directly signs all certificates.

### 3.3 The Trust Relationship

```
CA Certificate (self-signed, trust anchor)
  │
  ├── signs ──> Director certificate (trusted by FD, SD, bconsole)
  ├── signs ──> Storage Daemon certificate (trusted by DIR, FD)
  ├── signs ──> File Daemon certificate (trusted by DIR, SD)
  └── signs ──> bconsole certificate (trusted by DIR)
```

Every Bareos daemon gets a copy of the CA certificate. When a TLS connection is established, the daemon presents its certificate, and the peer checks that it is signed by the trusted CA.

---

[↑ Back to Table of Contents](#table-of-contents)

## 4. Bareos TLS Configuration Directives

Bareos uses these directives in daemon configuration files to control TLS behavior. They can appear in multiple resource types (Director, Client, Storage, Console).

| Directive | Type | Description |
|-----------|------|-------------|
| `TLS Enable` | Boolean | Enable TLS for this resource. Default: `yes` in Bareos 18+. |
| `TLS Require` | Boolean | If `yes`, refuse any connection that does not use TLS. Strongly recommended in production. |
| `TLS Verify Peer` | Boolean | If `yes`, require the peer to present a valid certificate signed by the trusted CA. Enables mutual TLS (mTLS). |
| `TLS CA Certificate File` | Path | Path to the CA certificate (`.pem` file). Required on both sides of a connection when certificate-based TLS is used. |
| `TLS Certificate` | Path | Path to this daemon's own certificate (`.pem` or `.crt` file). Required on the server side. |
| `TLS Key` | Path | Path to this daemon's private key (`.key` file). Required on the server side. Must be mode `0600`. |
| `TLS Allowed CN` | String | If set, only accept connections where the peer certificate's Common Name matches this value. An additional layer of authorization. |
| `TLS DH File` | Path | Path to Diffie-Hellman parameters file (for perfect forward secrecy with older cipher suites). Recommended. |

### 4.1 Directive Location in Configuration Files

These directives appear inside resource blocks. For example, in `bareos-dir.conf`, they appear in the `Director` resource:

```
Director {
  Name = bareos-dir
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  ...
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/director.pem
  TLS Key = /etc/bareos/tls/director.key
}
```

And in `Client` resources (describing remote File Daemons):

```
Client {
  Name = client1-fd
  Address = client1.example.com
  FD Port = 9102
  Password = "..."
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/director.pem
  TLS Key = /etc/bareos/tls/director.key
  TLS Allowed CN = "bareos-fd"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 5. Two TLS Modes in Bareos: TLS-PSK and TLS-cert

Bareos supports two fundamentally different TLS authentication mechanisms. Understanding the difference is critical to knowing what level of security you actually have.

### 5.1 TLS-PSK (Pre-Shared Key) — The Default

TLS-PSK uses a shared password as the authentication secret instead of certificates. In Bareos, the PSK is derived from the **password** you configure in each resource (e.g., the `Password` field in a `Client` resource, or in `bareos-fd.conf`).

**How Bareos derives the PSK:**
Bareos takes the configured password string and uses it directly as the TLS PSK identity and key material. No certificates are involved. No CA is involved.

**What TLS-PSK provides:**
- Encrypted data in transit (full TLS encryption)
- Authentication based on knowing the shared password
- Zero-configuration: works out of the box without any certificate setup

**What TLS-PSK does NOT provide:**
- Certificate-based identity verification
- Revocation (you cannot revoke a PSK without changing all passwords)
- Protection against a compromised Director that generates valid PSKs for all clients

**When TLS-PSK is sufficient:**
- Single-site deployments where all daemons are on trusted networks
- Lab environments
- Small environments where operational simplicity matters more than certificate hygiene

### 5.2 TLS-cert (Certificate-Based TLS)

TLS-cert uses X.509 certificates signed by a trusted CA. Each daemon has its own certificate and private key. This is the more secure option and is required for:

- Regulatory compliance (PCI-DSS, HIPAA, SOC2)
- Multi-site deployments over public networks
- Environments where key rotation and revocation are required
- Zero-trust architectures

**What TLS-cert provides over TLS-PSK:**
- Strong cryptographic identity proof (private key in hardware security module possible)
- Certificate revocation via CRL or OCSP
- Certificate expiry (forces regular rotation)
- Separation of authentication from authorization
- Audit trail via certificate serial numbers

**The course focus:** The remainder of this chapter implements TLS-cert, as it is the production-grade approach. The TLS-PSK behavior is preserved as a fallback when `TLS Verify Peer = no`.

---

[↑ Back to Table of Contents](#table-of-contents)

## 6. TLS-PSK: How It Works in Bareos

Even when you configure certificate-based TLS, understanding PSK helps you troubleshoot Bareos authentication errors.

### 6.1 The Password-as-PSK Mechanism

When two Bareos daemons connect, before any certificate exchange, they go through an initial authentication phase. In Bareos 18+, this phase uses TLS-PSK by default. The PSK is constructed as:

```
PSK identity: <daemon-name>
PSK key:      MD5 hash of the configured password
```

For example, if `bareos-fd.conf` contains:

```
Director {
  Name = bareos-dir
  Password = "abc123"
}
```

And `bareos-dir.conf` contains:

```
Client {
  Name = bareos-fd
  Password = "abc123"
}
```

Both sides compute the same PSK from "abc123" and use it to authenticate. If the passwords do not match, the TLS handshake fails immediately, before any data is exchanged.

### 6.2 PSK Without Certificates

A Bareos deployment that uses only PSK (no certificates configured) is encrypted (the tunnel is established with TLS-PSK ciphersuites), but the authentication is only as strong as the password. There is no certificate to verify, so the identity of the peer cannot be verified independently of the password.

### 6.3 PSK + Certificates Together

When you add `TLS Certificate` and `TLS Verify Peer = yes`, Bareos uses:
1. PSK for the initial connection authentication phase
2. Certificate exchange for additional identity verification

This is the recommended configuration: it provides both the operational simplicity of PSK and the cryptographic strength of certificates.

---

[↑ Back to Table of Contents](#table-of-contents)

## 7. Certificate-Based TLS: Generating the CA and All Certificates

We need certificates for:
1. The **Certificate Authority (CA)** — the trust anchor
2. The **Director** — used when the Director acts as a TLS server (for bconsole) and a TLS client (for FD/SD)
3. The **Storage Daemon** — used as a TLS server
4. The **File Daemon** — used as a TLS server
5. **bconsole** — used as a TLS client (optional but recommended for mTLS)

### 7.1 Certificate Naming Convention

We will use the following file naming convention throughout this chapter:

| File | Description |
|------|-------------|
| `ca.key` | CA private key (keep offline if possible) |
| `ca.pem` | CA certificate (distribute to all daemons) |
| `director.key` | Director private key |
| `director.pem` | Director certificate |
| `storage.key` | Storage Daemon private key |
| `storage.pem` | Storage Daemon certificate |
| `client.key` | File Daemon private key |
| `client.pem` | File Daemon certificate |
| `console.key` | bconsole private key |
| `console.pem` | bconsole certificate |

### 7.2 OpenSSL Configuration Files

We use OpenSSL configuration files (`.cnf`) to embed Subject Alternative Names (SANs) in each certificate. SANs are required for modern TLS — browsers and many TLS libraries reject certificates without them. While Bareos itself checks the CN (`TLS Allowed CN`), using SANs is still best practice.

Each component (Director, Storage Daemon, File Daemon, bconsole) gets its own extension file. In Section 8.3 these files are created at paths like `${TLS_DIR}/director.ext`, `${TLS_DIR}/storage.ext`, etc. — i.e., directly inside the `tls/` directory created in Section 8.1. They are referenced during the certificate signing commands in Sections 8.4–8.7 and can be deleted once all certificates have been signed.

---

[↑ Back to Table of Contents](#table-of-contents)

## 8. Self-Signed CA Setup: Complete Step-by-Step

All commands in this section are run on the **host machine** as the `bareos` user, then distributed to containers.

### 8.1 Create the TLS Directory Structure

```bash
# Run as bareos user
export XDG_RUNTIME_DIR=/run/user/1001

TLS_DIR="/home/bareos/.config/bareos/tls"
mkdir -p "${TLS_DIR}"/{certs,private,csr}
chmod 750 "${TLS_DIR}"
chmod 700 "${TLS_DIR}/private"

# Directory layout:
# /home/bareos/.config/bareos/tls/
# ├── certs/       (certificates - mode 644)
# ├── private/     (private keys - mode 600)
# ├── csr/         (certificate signing requests - can be deleted after signing)
# └── ca.pem       (CA certificate - mode 644, copy this everywhere)
```

### 8.2 Generate the CA Private Key and Certificate

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Step 1: Generate the CA private key (4096-bit RSA)
# This key must be kept secure — whoever has it can sign new certificates
openssl genrsa -out "${TLS_DIR}/private/ca.key" 4096
chmod 600 "${TLS_DIR}/private/ca.key"

# Step 2: Create the CA self-signed certificate (valid for 10 years)
# The -x509 flag means "create a self-signed certificate" (not a CSR)
# The -extensions v3_ca flag adds CA-specific extensions
openssl req \
    -new \
    -x509 \
    -days 3650 \
    -key "${TLS_DIR}/private/ca.key" \
    -out "${TLS_DIR}/certs/ca.pem" \
    -subj "/C=US/ST=State/L=City/O=Bareos Lab/OU=Backup Infrastructure/CN=Bareos-Lab-CA"

# Verify the CA certificate
openssl x509 -in "${TLS_DIR}/certs/ca.pem" -text -noout | head -40
# Should show: Issuer = Subject (self-signed), CA:TRUE in extensions
```

### 8.3 Create OpenSSL Extension Files for Each Certificate

Each certificate needs Subject Alternative Names. Create a separate extension file for each component.

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Director certificate extensions
cat > "${TLS_DIR}/director.ext" << 'EOF'
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[dn]
C  = US
ST = State
L  = City
O  = Bareos Lab
OU = Backup Infrastructure
CN = bareos-director

[v3_req]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = bareos-director
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF

# Storage Daemon certificate extensions
cat > "${TLS_DIR}/storage.ext" << 'EOF'
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[dn]
C  = US
ST = State
L  = City
O  = Bareos Lab
OU = Backup Infrastructure
CN = bareos-storage

[v3_req]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = bareos-storage
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF

# File Daemon certificate extensions
cat > "${TLS_DIR}/client.ext" << 'EOF'
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[dn]
C  = US
ST = State
L  = City
O  = Bareos Lab
OU = Backup Infrastructure
CN = bareos-fd

[v3_req]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = bareos-fd
DNS.2 = localhost
IP.1  = 127.0.0.1
EOF

# bconsole certificate extensions
cat > "${TLS_DIR}/console.ext" << 'EOF'
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[dn]
C  = US
ST = State
L  = City
O  = Bareos Lab
OU = Backup Infrastructure
CN = bareos-console

[v3_req]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[alt_names]
DNS.1 = bareos-console
EOF
```

### 8.4 Generate the Director Certificate

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Step 1: Generate Director private key
openssl genrsa -out "${TLS_DIR}/private/director.key" 2048
chmod 600 "${TLS_DIR}/private/director.key"

# Step 2: Generate a CSR (Certificate Signing Request)
openssl req \
    -new \
    -key "${TLS_DIR}/private/director.key" \
    -out "${TLS_DIR}/csr/director.csr" \
    -config "${TLS_DIR}/director.ext"

# Step 3: Sign the CSR with our CA to produce the Director certificate
openssl x509 \
    -req \
    -days 365 \
    -in "${TLS_DIR}/csr/director.csr" \
    -CA "${TLS_DIR}/certs/ca.pem" \
    -CAkey "${TLS_DIR}/private/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/certs/director.pem" \
    -extfile "${TLS_DIR}/director.ext" \
    -extensions v3_req

# Verify the certificate
openssl x509 -in "${TLS_DIR}/certs/director.pem" -text -noout | grep -A3 "Subject:"
openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/director.pem"
# Expected: director.pem: OK
```

### 8.5 Generate the Storage Daemon Certificate

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl genrsa -out "${TLS_DIR}/private/storage.key" 2048
chmod 600 "${TLS_DIR}/private/storage.key"

openssl req \
    -new \
    -key "${TLS_DIR}/private/storage.key" \
    -out "${TLS_DIR}/csr/storage.csr" \
    -config "${TLS_DIR}/storage.ext"

openssl x509 \
    -req \
    -days 365 \
    -in "${TLS_DIR}/csr/storage.csr" \
    -CA "${TLS_DIR}/certs/ca.pem" \
    -CAkey "${TLS_DIR}/private/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/certs/storage.pem" \
    -extfile "${TLS_DIR}/storage.ext" \
    -extensions v3_req

openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/storage.pem"
```

### 8.6 Generate the File Daemon Certificate

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl genrsa -out "${TLS_DIR}/private/client.key" 2048
chmod 600 "${TLS_DIR}/private/client.key"

openssl req \
    -new \
    -key "${TLS_DIR}/private/client.key" \
    -out "${TLS_DIR}/csr/client.csr" \
    -config "${TLS_DIR}/client.ext"

openssl x509 \
    -req \
    -days 365 \
    -in "${TLS_DIR}/csr/client.csr" \
    -CA "${TLS_DIR}/certs/ca.pem" \
    -CAkey "${TLS_DIR}/private/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/certs/client.pem" \
    -extfile "${TLS_DIR}/client.ext" \
    -extensions v3_req

openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/client.pem"
```

### 8.7 Generate the bconsole Certificate

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl genrsa -out "${TLS_DIR}/private/console.key" 2048
chmod 600 "${TLS_DIR}/private/console.key"

openssl req \
    -new \
    -key "${TLS_DIR}/private/console.key" \
    -out "${TLS_DIR}/csr/console.csr" \
    -config "${TLS_DIR}/console.ext"

openssl x509 \
    -req \
    -days 365 \
    -in "${TLS_DIR}/csr/console.csr" \
    -CA "${TLS_DIR}/certs/ca.pem" \
    -CAkey "${TLS_DIR}/private/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/certs/console.pem" \
    -extfile "${TLS_DIR}/console.ext" \
    -extensions v3_req

openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/console.pem"
```

### 8.8 Generate Diffie-Hellman Parameters

DH parameters are used for perfect forward secrecy with DHE cipher suites. This command takes several minutes to complete:

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl dhparam -out "${TLS_DIR}/dh2048.pem" 2048
chmod 644 "${TLS_DIR}/dh2048.pem"
```

### 8.9 Final File Summary and Permissions

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Verify all files exist and have correct permissions
echo "=== CA Certificate ==="
ls -la "${TLS_DIR}/certs/ca.pem"

echo "=== Private Keys (must be 600) ==="
ls -la "${TLS_DIR}/private/"

echo "=== Certificates (644 is fine) ==="
ls -la "${TLS_DIR}/certs/"

echo "=== Verification of all certificates ==="
for cert in "${TLS_DIR}/certs/"*.pem; do
    [[ "$(basename "${cert}")" == "ca.pem" ]] && continue
    result=$(openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${cert}" 2>&1)
    echo "${cert}: ${result}"
done
```

Expected output:
```
/home/bareos/.config/bareos/tls/certs/director.pem: OK
/home/bareos/.config/bareos/tls/certs/storage.pem: OK
/home/bareos/.config/bareos/tls/certs/client.pem: OK
/home/bareos/.config/bareos/tls/certs/console.pem: OK
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 9. Distributing Certificates to Containers via Quadlet

Each container needs access to its certificate, private key, and the CA certificate. In our rootless Podman setup, certificates live on the host at `/home/bareos/.config/bareos/tls/` and are bind-mounted into each container.

### 9.1 Why Bind-Mount Instead of Copying Into the Image

Certificates expire (our certificates are valid for 365 days). When you rotate a certificate, you want to replace the file on the host and restart the container — not rebuild the image. Bind-mounting the TLS directory decouples certificate management from container image management.

### 9.2 Updated Quadlet Files with TLS Mounts

#### Director Container

```ini
# /home/bareos/.config/containers/systemd/bareos-director.container
[Unit]
Description=Bareos Director
After=network-online.target bareos-db.service

[Container]
Image=docker.io/bareos/bareos-director:24
ContainerName=bareos-director

# Configuration bind-mount (includes bareos-dir.conf with TLS settings)
Volume=/etc/bareos:/etc/bareos:ro,Z

# TLS certificates bind-mount
# ro: container only reads certs, never writes
# Z: SELinux relabeling for rootless container access
Volume=/home/bareos/.config/bareos/tls/certs/ca.pem:/etc/bareos/tls/ca.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/certs/director.pem:/etc/bareos/tls/director.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/private/director.key:/etc/bareos/tls/director.key:ro,Z
Volume=/home/bareos/.config/bareos/tls/dh2048.pem:/etc/bareos/tls/dh2048.pem:ro,Z

# State and log volumes
Volume=bareos-director-var:/var/lib/bareos:Z
Volume=bareos-director-log:/var/log/bareos:Z

EnvironmentFile=/home/bareos/.config/bareos/bareos.env
Network=bareos.network
PublishPort=9101:9101

[Service]
Restart=always

[Install]
WantedBy=default.target
```

#### Storage Daemon Container

```ini
# /home/bareos/.config/containers/systemd/bareos-storage.container
[Unit]
Description=Bareos Storage Daemon
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-storage:24
ContainerName=bareos-storage

Volume=/etc/bareos:/etc/bareos:ro,Z

# Storage Daemon TLS certificates
Volume=/home/bareos/.config/bareos/tls/certs/ca.pem:/etc/bareos/tls/ca.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/certs/storage.pem:/etc/bareos/tls/storage.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/private/storage.key:/etc/bareos/tls/storage.key:ro,Z
Volume=/home/bareos/.config/bareos/tls/dh2048.pem:/etc/bareos/tls/dh2048.pem:ro,Z

# Storage volume for backup data
# The /srv/bareos-storage/volumes path on the host is labeled bareos_store_t
Volume=/srv/bareos-storage/volumes:/var/lib/bareos/storage:Z

Network=bareos.network
PublishPort=9103:9103

[Service]
Restart=always

[Install]
WantedBy=default.target
```

#### File Daemon Container

```ini
# /home/bareos/.config/containers/systemd/bareos-fd.container
[Unit]
Description=Bareos File Daemon
After=network-online.target

[Container]
Image=docker.io/bareos/bareos-client:24
ContainerName=bareos-fd

Volume=/etc/bareos:/etc/bareos:ro,Z

# File Daemon TLS certificates
Volume=/home/bareos/.config/bareos/tls/certs/ca.pem:/etc/bareos/tls/ca.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/certs/client.pem:/etc/bareos/tls/client.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/private/client.key:/etc/bareos/tls/client.key:ro,Z

# Data to be backed up
Volume=/home/bareos/backups:/var/bareos/backups:ro,Z

Network=bareos.network
PublishPort=9102:9102

[Service]
Restart=always

[Install]
WantedBy=default.target
```

### 9.3 Reload Systemd to Apply Quadlet Changes

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Reload systemd user daemon to parse updated Quadlet files
systemctl --user daemon-reload

# Restart all Bareos services in the correct order
systemctl --user restart bareos-fd.service
systemctl --user restart bareos-storage.service
systemctl --user restart bareos-director.service

# Verify all three are running
systemctl --user status bareos-fd.service bareos-storage.service bareos-director.service
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 10. Director TLS Configuration

The Director's TLS configuration appears in two places:
1. The `Director { }` resource (controls the Director's own listening port — for bconsole connections)
2. Each `Client { }` and `Storage { }` resource (controls TLS when the Director connects to those daemons)

### 10.1 bareos-dir.conf: Director Resource

```
# /etc/bareos/bareos-dir.d/director/bareos-dir.conf

Director {
  Name = bareos-dir
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  Maximum Concurrent Jobs = 10
  Password = "DirectorConsolePassword"
  Messages = Daemon

  # TLS settings for bconsole connections (Director acts as server)
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes

  # CA certificate: used to verify bconsole's certificate
  TLS CA Certificate File = /etc/bareos/tls/ca.pem

  # Director's own certificate and key (presented to bconsole)
  TLS Certificate = /etc/bareos/tls/director.pem
  TLS Key = /etc/bareos/tls/director.key

  # Diffie-Hellman parameters for perfect forward secrecy
  TLS DH File = /etc/bareos/tls/dh2048.pem
}
```

### 10.2 Client Resource: Director→FD TLS Settings

```
# /etc/bareos/bareos-dir.d/client/bareos-fd.conf

Client {
  Name = bareos-fd
  Address = bareos-fd        # Container name on the Podman network
  FD Port = 9102
  Catalog = MyCatalog
  Password = "FileDaemonPassword"
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes

  # TLS for Director→FD connection (Director acts as client here)
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/director.pem
  TLS Key = /etc/bareos/tls/director.key

  # Only accept connections where FD certificate CN is "bareos-fd"
  TLS Allowed CN = "bareos-fd"
}
```

### 10.3 Storage Resource: Director→SD TLS Settings

```
# /etc/bareos/bareos-dir.d/storage/File-1.conf

Storage {
  Name = File-1
  Address = bareos-storage       # Container name on the Podman network
  SD Port = 9103
  Password = "StorageDaemonPassword"
  Device = FileStorage
  Media Type = File

  # TLS for Director→SD connection
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/director.pem
  TLS Key = /etc/bareos/tls/director.key

  TLS Allowed CN = "bareos-storage"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 11. Storage Daemon TLS Configuration

The Storage Daemon listens for two types of incoming connections: from the Director (port 9103) and from File Daemons (also port 9103 — they share the SD listener). Both connection types go to the same listener, so a single TLS configuration covers both.

```
# /etc/bareos/bareos-sd.d/storagedeamon/bareos-sd.conf

Storage {
  Name = bareos-sd
  SD Port = 9103
  WorkingDirectory = "/var/lib/bareos"
  Plugin Directory = "/usr/lib64/bareos/plugins"
  Maximum Concurrent Jobs = 20
  SD Connect Timeout = 1 min

  # TLS for incoming connections from DIR and FD
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes

  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/storage.pem
  TLS Key = /etc/bareos/tls/storage.key
  TLS DH File = /etc/bareos/tls/dh2048.pem

  # Accept connections from Director and File Daemons by their CN
  TLS Allowed CN = "bareos-director"
  TLS Allowed CN = "bareos-fd"
}
```

The `Director` resource inside `bareos-sd.conf` describes how the SD authenticates the Director:

```
# /etc/bareos/bareos-sd.d/director/bareos-dir.conf

Director {
  Name = bareos-dir
  Password = "StorageDaemonPassword"
  Monitor = no

  # TLS settings for validating the Director's certificate
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Allowed CN = "bareos-director"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 12. File Daemon TLS Configuration

The File Daemon listens for connections from the Director (port 9102) and makes an outbound connection to the Storage Daemon (port 9103) to stream backup data.

### 12.1 bareos-fd.conf: FD Main Resource

```
# /etc/bareos/bareos-fd.d/client/bareos-fd.conf

Client {
  Name = bareos-fd
  FD Port = 9102
  Working Directory = "/var/lib/bareos"
  Plugin Directory = "/usr/lib64/bareos/plugins"
  Maximum Concurrent Jobs = 20

  # TLS for incoming Director connections (FD acts as server)
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes

  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/client.pem
  TLS Key = /etc/bareos/tls/client.key
}
```

### 12.2 Director Resource in bareos-fd.conf

The FD has a `Director` resource that authenticates incoming Director connections:

```
# /etc/bareos/bareos-fd.d/director/bareos-dir.conf

Director {
  Name = bareos-dir
  Password = "FileDaemonPassword"

  # TLS settings to validate the Director's certificate
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Allowed CN = "bareos-director"
}
```

### 12.3 Messages Resource (No TLS Needed)

The `Messages` resource only defines where log messages go (to the Director). No separate TLS configuration is needed here — the Director connection is already covered by the `Director` resource above.

---

[↑ Back to Table of Contents](#table-of-contents)

## 13. bconsole TLS Configuration

`bconsole` is the command-line management interface for Bareos. It connects to the Director on port 9101. In our setup, `bconsole` runs inside the Director container.

```
# /etc/bareos/bconsole.conf

Director {
  Name = bareos-dir
  DIRport = 9101
  Address = localhost          # bconsole runs inside the same container as the Director
  Password = "DirectorConsolePassword"

  # TLS for bconsole→Director connection
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes

  # CA certificate to validate the Director's certificate
  TLS CA Certificate File = /etc/bareos/tls/ca.pem

  # bconsole's own certificate (for mutual TLS)
  TLS Certificate = /etc/bareos/tls/console.pem
  TLS Key = /etc/bareos/tls/console.key
}
```

The bconsole certificate and key must also be bind-mounted into the Director container, since that is where `bconsole` runs:

```ini
# In bareos-director.container, add:
Volume=/home/bareos/.config/bareos/tls/certs/console.pem:/etc/bareos/tls/console.pem:ro,Z
Volume=/home/bareos/.config/bareos/tls/private/console.key:/etc/bareos/tls/console.key:ro,Z
```

### 13.1 Updating the Director's Console Resource

The Director must know the bconsole's password and TLS settings:

```
# /etc/bareos/bareos-dir.d/console/bareos-mon.conf

Console {
  Name = bareos-mon
  Password = "DirectorConsolePassword"
  CommandACL = status, .status

  # Allow bconsole connections using certificates
  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Allowed CN = "bareos-console"
}
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 14. Verifying TLS Connections

After configuring TLS, you must verify that:
1. Daemons can start and accept TLS connections
2. The TLS connection is actually encrypted (not falling back to plaintext)
3. Certificate verification is working (peers are rejecting invalid certificates)

### 14.1 Checking Bareos Logs for TLS Messages

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# Check Director logs for TLS-related messages
journalctl --user -u bareos-director.service -n 100 | grep -i tls

# Check Storage Daemon logs
journalctl --user -u bareos-storage.service -n 100 | grep -i tls

# Check File Daemon logs
journalctl --user -u bareos-fd.service -n 100 | grep -i tls
```

Successful TLS connection messages look like:
```
bareos-director: Connecting to Storage Daemon "File-1" at bareos-storage:9103
bareos-director: TLS negotiation failed for SD "bareos-storage" [or: TLS connection established]
```

### 14.2 Testing with openssl s_client

`openssl s_client` is the definitive tool for testing TLS connections. It acts as a TLS client and shows the full certificate chain and negotiated cipher suite.

#### Test the Director (port 9101)

```bash
export XDG_RUNTIME_DIR=/run/user/1001
TLS_DIR="/home/bareos/.config/bareos/tls"

# Connect to the Director's listening port
# Note: Bareos uses a custom protocol on top of TLS,
# so the connection will hang after the handshake — that is normal
openssl s_client \
    -connect localhost:9101 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    -cert "${TLS_DIR}/certs/console.pem" \
    -key "${TLS_DIR}/private/console.key" \
    -verify_return_error \
    </dev/null 2>&1 | head -50
```

Look for these lines in the output:
```
CONNECTED(00000003)
depth=1 CN = Bareos-Lab-CA
verify return:1
depth=0 CN = bareos-director
verify return:1
---
Certificate chain
 0 s:CN = bareos-director
   i:CN = Bareos-Lab-CA
---
...
SSL-Session:
    Protocol  : TLSv1.3        <-- or TLSv1.2
    Cipher    : TLS_AES_256_GCM_SHA384
    ...
Verify return code: 0 (ok)     <-- CRITICAL: must be 0
```

If you see `Verify return code: 0 (ok)`, the certificate chain is valid. If you see any other code, there is a configuration error.

#### Test the Storage Daemon (port 9103)

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl s_client \
    -connect localhost:9103 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    -cert "${TLS_DIR}/certs/director.pem" \
    -key "${TLS_DIR}/private/director.key" \
    -verify_return_error \
    </dev/null 2>&1 | head -50
```

#### Test the File Daemon (port 9102)

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl s_client \
    -connect localhost:9102 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    -cert "${TLS_DIR}/certs/director.pem" \
    -key "${TLS_DIR}/private/director.key" \
    -verify_return_error \
    </dev/null 2>&1 | head -50
```

### 14.3 Testing That TLS Is Required

Verify that a connection without a valid certificate is rejected. If `TLS Require = yes` and `TLS Verify Peer = yes` are correctly configured, a connection without a certificate should fail:

```bash
# Attempt connection without providing a client certificate
openssl s_client \
    -connect localhost:9101 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    </dev/null 2>&1 | grep -E "error|alert|handshake"

# Expected: alert handshake failure or certificate required error
```

### 14.4 Running a Test Backup Job to Confirm End-to-End TLS

```bash
podman exec bareos-director bconsole << 'EOF'
run job=BackupClient1 level=Full yes
wait
messages
EOF
```

If TLS is working correctly, the job should complete successfully. If there are TLS errors, they appear in the job output as connection errors between the Director/FD/SD components.

### 14.5 bconsole Status Check

```bash
podman exec bareos-director bconsole << 'EOF'
status dir
status storage
status client
EOF
```

If any component cannot be reached due to TLS errors, the status output will show connection failure messages. A successful status shows:

```
bareos-director Version: 24.x.x ...
...
No jobs running.
```

---

[↑ Back to Table of Contents](#table-of-contents)

## 15. Certificate Rotation Procedure

Certificates expire. Our certificates are valid for 365 days. You should set a calendar reminder for 30 days before expiration to rotate them.

### 15.1 Checking Certificate Expiration

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

for cert in "${TLS_DIR}/certs/"*.pem; do
    expiry=$(openssl x509 -in "${cert}" -noout -enddate 2>/dev/null | cut -d= -f2)
    echo "$(basename "${cert}"): expires ${expiry}"
done
```

### 15.2 Rotating a Single Certificate (e.g., File Daemon)

The procedure for rotating one certificate without disrupting others:

**Step 1: Generate a new key and certificate (keep the same CN)**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Generate new key
openssl genrsa -out "${TLS_DIR}/private/client.key.new" 2048
chmod 600 "${TLS_DIR}/private/client.key.new"

# Generate new CSR
openssl req \
    -new \
    -key "${TLS_DIR}/private/client.key.new" \
    -out "${TLS_DIR}/csr/client.csr.new" \
    -config "${TLS_DIR}/client.ext"

# Sign with the existing CA
openssl x509 \
    -req \
    -days 365 \
    -in "${TLS_DIR}/csr/client.csr.new" \
    -CA "${TLS_DIR}/certs/ca.pem" \
    -CAkey "${TLS_DIR}/private/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/certs/client.pem.new" \
    -extfile "${TLS_DIR}/client.ext" \
    -extensions v3_req

# Verify the new certificate
openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/client.pem.new"
```

**Step 2: Atomically replace the old certificate**

```bash
# Back up old certificates
cp "${TLS_DIR}/certs/client.pem" "${TLS_DIR}/certs/client.pem.bak"
cp "${TLS_DIR}/private/client.key" "${TLS_DIR}/private/client.key.bak"

# Replace with new certificates
mv "${TLS_DIR}/certs/client.pem.new" "${TLS_DIR}/certs/client.pem"
mv "${TLS_DIR}/private/client.key.new" "${TLS_DIR}/private/client.key"
```

**Step 3: Restart only the File Daemon container**

```bash
export XDG_RUNTIME_DIR=/run/user/1001

# The Quadlet bind-mount will see the new file automatically after restart
systemctl --user restart bareos-fd.service

# Verify the container started correctly
systemctl --user status bareos-fd.service
journalctl --user -u bareos-fd.service -n 20
```

**Step 4: Verify the new certificate is in use**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl s_client \
    -connect localhost:9102 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    </dev/null 2>&1 | grep "Not After"

# The date should match your newly generated certificate
```

### 15.3 Rotating the CA Certificate

Rotating the CA is a more involved process because all component certificates are signed by it. If the CA expires, all certificates become invalid simultaneously.

**CA rotation procedure:**

1. Generate a new CA key and certificate
2. Re-sign all component certificates with the new CA
3. Create a "combined CA" file that includes both the old and new CA certificates (during the transition period, daemons need to trust both)
4. Deploy the combined CA to all daemons
5. Restart all daemons
6. Once all certificates have been re-issued and verified, remove the old CA from the combined file

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Create combined CA file (old + new)
cat "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/ca-new.pem" \
    > "${TLS_DIR}/certs/ca-combined.pem"
```

In Bareos configuration, point `TLS CA Certificate File` to `ca-combined.pem` during the transition.

---

[↑ Back to Table of Contents](#table-of-contents)

## 16. SELinux: Certificate File Labeling

SELinux enforcing mode is a non-negotiable requirement on RHEL 10. Certificate files need the correct SELinux type for containers to read them.

### 16.1 Default Labels and the Problem

When you create files in `/home/bareos/.config/bareos/tls/`, they receive the SELinux type of their parent directory — typically `user_home_t` or `container_home_t`. Containers running with the `container_t` domain cannot read files labeled `user_home_t` by default.

Verify current labels:

```bash
ls -laZ /home/bareos/.config/bareos/tls/certs/
# Shows current SELinux contexts like:
# unconfined_u:object_r:user_home_t:s0 ca.pem
```

### 16.2 The :Z Mount Option (Automatic Relabeling)

When you add `:Z` to a Podman volume bind-mount, Podman automatically relabels the mounted files with `container_file_t:s0:cXXX,cYYY` (the container's MCS label). This is the simplest solution:

```ini
# In bareos-director.container — already shown in Section 9.2
Volume=/home/bareos/.config/bareos/tls/certs/ca.pem:/etc/bareos/tls/ca.pem:ro,Z
```

The `:Z` flag tells Podman: "relabel this file so that this specific container can read it."

**Caution:** `:Z` sets a container-specific MCS label, meaning only the container that applied the `:Z` label can access the file. If multiple containers need the same file (e.g., all containers need `ca.pem`), use `:z` (lowercase z) instead, which sets a shared `container_file_t` label accessible by any container.

```ini
# Use :z (lowercase) for files shared across multiple containers
Volume=/home/bareos/.config/bareos/tls/certs/ca.pem:/etc/bareos/tls/ca.pem:ro,z
```

### 16.3 Manual Relabeling with chcon

If you need to permanently relabel certificate files (without relying on Podman's automatic relabeling):

```bash
# Label certificate files as container_file_t
sudo chcon -R -t container_file_t /home/bareos/.config/bareos/tls/certs/

# Label private keys more restrictively
sudo chcon -R -t container_file_t /home/bareos/.config/bareos/tls/private/

# Verify
ls -laZ /home/bareos/.config/bareos/tls/certs/
# Should show: system_u:object_r:container_file_t:s0
```

### 16.4 Making Labels Persistent with semanage fcontext

`chcon` labels are lost when `restorecon` is run or on a SELinux relabeling. Use `semanage fcontext` to make the label permanent:

```bash
# Make container_file_t the default for the tls directory tree
sudo semanage fcontext -a -t container_file_t \
    "/home/bareos/.config/bareos/tls(/.*)?"

# Apply the rule immediately
sudo restorecon -Rv /home/bareos/.config/bareos/tls/

# Verify
ls -laZ /home/bareos/.config/bareos/tls/certs/
```

### 16.5 The bareos_etc_t Type

If Bareos configuration is installed natively (not in containers), certificate files in `/etc/bareos/tls/` should use the `bareos_etc_t` type. For our containerized setup where everything goes through bind-mounts, `container_file_t` is the correct choice.

### 16.6 Verifying SELinux Is Not Blocking Access

If a container cannot read its certificate file, the SELinux audit log will show a denial:

```bash
# Check for certificate-related AVC denials
sudo ausearch -m avc -ts recent | grep bareos
sudo ausearch -m avc -ts recent | grep tls

# Or watch the audit log in real time
sudo tail -f /var/log/audit/audit.log | grep denied
```

If you see denials, the typical cause is incorrect file labels. Fix with `chcon` or `semanage fcontext` as described above.

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 15-1: Set Up a Bareos CA and Generate All Certificates

**Objective:** Create a complete PKI for Bareos: a CA, four component certificates, and DH parameters.

**Step 1: Prepare the directory structure**

```bash
su - bareos
export XDG_RUNTIME_DIR=/run/user/1001

TLS_DIR="/home/bareos/.config/bareos/tls"
mkdir -p "${TLS_DIR}"/{certs,private,csr}
chmod 750 "${TLS_DIR}"
chmod 700 "${TLS_DIR}/private"

ls -la "${TLS_DIR}"
```

**Step 2: Generate the CA**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

openssl genrsa -out "${TLS_DIR}/private/ca.key" 4096
chmod 600 "${TLS_DIR}/private/ca.key"

openssl req \
    -new -x509 -days 3650 \
    -key "${TLS_DIR}/private/ca.key" \
    -out "${TLS_DIR}/certs/ca.pem" \
    -subj "/CN=Bareos-Lab-CA/O=Bareos Lab/C=US"

# Verify
openssl x509 -in "${TLS_DIR}/certs/ca.pem" -text -noout | grep -E "Subject:|Issuer:|Not After"
```

Expected output:
```
        Issuer: CN = Bareos-Lab-CA, O = Bareos Lab, C = US
        Not After : Feb 24 00:00:00 2036 GMT
        Subject: CN = Bareos-Lab-CA, O = Bareos Lab, C = US
```

**Step 3: Generate all component certificates using a helper script**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Helper function to create a cert
create_cert() {
    local name="$1"
    local cn="$2"
    local extra_dns="${3:-}"

    cat > "${TLS_DIR}/${name}.ext" << EXTEOF
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = v3_req

[dn]
CN = ${cn}
O  = Bareos Lab
C  = US

[v3_req]
subjectAltName = @alt_names
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth

[alt_names]
DNS.1 = ${cn}
DNS.2 = localhost
IP.1  = 127.0.0.1
${extra_dns}
EXTEOF

    # Key
    openssl genrsa -out "${TLS_DIR}/private/${name}.key" 2048
    chmod 600 "${TLS_DIR}/private/${name}.key"

    # CSR
    openssl req \
        -new \
        -key "${TLS_DIR}/private/${name}.key" \
        -out "${TLS_DIR}/csr/${name}.csr" \
        -config "${TLS_DIR}/${name}.ext"

    # Sign
    openssl x509 \
        -req -days 365 \
        -in "${TLS_DIR}/csr/${name}.csr" \
        -CA "${TLS_DIR}/certs/ca.pem" \
        -CAkey "${TLS_DIR}/private/ca.key" \
        -CAcreateserial \
        -out "${TLS_DIR}/certs/${name}.pem" \
        -extfile "${TLS_DIR}/${name}.ext" \
        -extensions v3_req

    # Verify
    openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/${name}.pem"
    echo "Created: ${name} (CN=${cn})"
}

create_cert "director" "bareos-director"
create_cert "storage"  "bareos-storage"
create_cert "client"   "bareos-fd"
create_cert "console"  "bareos-console"
```

**Step 4: Generate DH parameters**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"
openssl dhparam -out "${TLS_DIR}/dh2048.pem" 2048
# This takes 1-3 minutes — be patient
echo "DH parameters generated."
```

**Step 5: Summary of generated files**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

echo "=== Certificates (can be world-readable) ==="
ls -la "${TLS_DIR}/certs/"

echo ""
echo "=== Private Keys (must be 600) ==="
ls -la "${TLS_DIR}/private/"

echo ""
echo "=== All certificates valid against CA ==="
for cert in "${TLS_DIR}/certs/"*.pem; do
    [[ "$(basename "${cert}")" == "ca.pem" ]] && continue
    openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${cert}"
done
```

All four lines should say `OK`.

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 15-2: Configure All Bareos Daemons to Use Certificates

**Objective:** Update all Bareos configuration files and Quadlet container definitions to use the certificates generated in Lab 15-1. Restart all services and confirm they are running.

**Step 1: Apply SELinux labels to the TLS directory**

```bash
# As root (or via sudo)
sudo semanage fcontext -a -t container_file_t \
    "/home/bareos/.config/bareos/tls(/.*)?"
sudo restorecon -Rv /home/bareos/.config/bareos/tls/

# Verify
ls -laZ /home/bareos/.config/bareos/tls/certs/ca.pem
# Should end with: container_file_t:s0
```

**Step 2: Update the Director Quadlet file**

```bash
cat > /home/bareos/.config/containers/systemd/bareos-director.container << 'EOF'
[Unit]
Description=Bareos Director
After=network-online.target bareos-db.service

[Container]
Image=docker.io/bareos/bareos-director:24
ContainerName=bareos-director
Volume=/etc/bareos:/etc/bareos:ro,Z
Volume=/home/bareos/.config/bareos/tls/certs/ca.pem:/etc/bareos/tls/ca.pem:ro,z
Volume=/home/bareos/.config/bareos/tls/certs/director.pem:/etc/bareos/tls/director.pem:ro,z
Volume=/home/bareos/.config/bareos/tls/private/director.key:/etc/bareos/tls/director.key:ro,Z
Volume=/home/bareos/.config/bareos/tls/certs/console.pem:/etc/bareos/tls/console.pem:ro,z
Volume=/home/bareos/.config/bareos/tls/private/console.key:/etc/bareos/tls/console.key:ro,Z
Volume=/home/bareos/.config/bareos/tls/dh2048.pem:/etc/bareos/tls/dh2048.pem:ro,z
Volume=bareos-director-var:/var/lib/bareos:Z
EnvironmentFile=/home/bareos/.config/bareos/bareos.env
Network=bareos.network
PublishPort=9101:9101

[Service]
Restart=always

[Install]
WantedBy=default.target
EOF
```

**Step 3: Update bareos-dir.conf to enable TLS**

```bash
# This configuration update goes into the container-accessible config path
# Adjust the path for your specific setup:
sudo tee /etc/bareos/bareos-dir.d/director/bareos-dir.conf << 'EOF'
Director {
  Name = bareos-dir
  QueryFile = "/usr/lib/bareos/scripts/query.sql"
  Maximum Concurrent Jobs = 10
  Password = "DirectorConsolePassword"
  Messages = Daemon

  TLS Enable = yes
  TLS Require = yes
  TLS Verify Peer = yes
  TLS CA Certificate File = /etc/bareos/tls/ca.pem
  TLS Certificate = /etc/bareos/tls/director.pem
  TLS Key = /etc/bareos/tls/director.key
  TLS DH File = /etc/bareos/tls/dh2048.pem
}
EOF
```

**Step 4: Reload systemd and restart all Bareos services**

```bash
export XDG_RUNTIME_DIR=/run/user/1001

systemctl --user daemon-reload

systemctl --user restart bareos-fd.service
sleep 3
systemctl --user restart bareos-storage.service
sleep 3
systemctl --user restart bareos-director.service
sleep 5

# Check all three are active
systemctl --user status bareos-fd.service bareos-storage.service bareos-director.service \
    --no-pager | grep -E "Active:|●"
```

Expected output — all three should show `active (running)`:
```
● bareos-fd.service - Bareos File Daemon
     Active: active (running) ...
● bareos-storage.service - Bareos Storage Daemon
     Active: active (running) ...
● bareos-director.service - Bareos Director
     Active: active (running) ...
```

**Step 5: Run a test backup to confirm TLS end-to-end**

```bash
podman exec bareos-director bconsole << 'EOF'
status dir
run job=BackupClient1 level=Full yes
wait
messages
EOF
```

The job should complete with status `T` (Terminated OK). Any TLS handshake failures will appear as error messages in the job output.

---

[↑ Back to Table of Contents](#table-of-contents)

## Lab 15-3: Verify Encrypted Connections and Rotate a Certificate

**Objective:** Use `openssl s_client` to verify TLS connections to all three daemons, then simulate a certificate rotation for the File Daemon.

**Step 1: Verify all three daemon TLS connections**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

echo "=== Testing Director (port 9101) ==="
openssl s_client \
    -connect localhost:9101 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    -cert "${TLS_DIR}/certs/console.pem" \
    -key "${TLS_DIR}/private/console.key" \
    </dev/null 2>&1 | grep -E "subject|issuer|Cipher|Protocol|Verify return"

echo ""
echo "=== Testing Storage Daemon (port 9103) ==="
openssl s_client \
    -connect localhost:9103 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    -cert "${TLS_DIR}/certs/director.pem" \
    -key "${TLS_DIR}/private/director.key" \
    </dev/null 2>&1 | grep -E "subject|issuer|Cipher|Protocol|Verify return"

echo ""
echo "=== Testing File Daemon (port 9102) ==="
openssl s_client \
    -connect localhost:9102 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    -cert "${TLS_DIR}/certs/director.pem" \
    -key "${TLS_DIR}/private/director.key" \
    </dev/null 2>&1 | grep -E "subject|issuer|Cipher|Protocol|Verify return"
```

All three should show `Verify return code: 0 (ok)` and a strong cipher (AES-256 or CHACHA20).

**Step 2: Check current certificate expiration dates**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

echo "Certificate expiration dates:"
for cert in "${TLS_DIR}/certs/"*.pem; do
    cn=$(openssl x509 -in "${cert}" -noout -subject 2>/dev/null | sed 's/.*CN = //')
    expiry=$(openssl x509 -in "${cert}" -noout -enddate 2>/dev/null | cut -d= -f2)
    printf "  %-20s  %s\n" "${cn}" "${expiry}"
done
```

**Step 3: Rotate the File Daemon certificate**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Generate new key and certificate
openssl genrsa -out "${TLS_DIR}/private/client.key.new" 2048
chmod 600 "${TLS_DIR}/private/client.key.new"

openssl req \
    -new \
    -key "${TLS_DIR}/private/client.key.new" \
    -out "${TLS_DIR}/csr/client.csr.new" \
    -subj "/CN=bareos-fd/O=Bareos Lab/C=US"

# Create extension file for SAN
cat > "${TLS_DIR}/client-rotate.ext" << 'EOF'
[v3_req]
subjectAltName = DNS:bareos-fd, DNS:localhost, IP:127.0.0.1
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
EOF

openssl x509 \
    -req -days 365 \
    -in "${TLS_DIR}/csr/client.csr.new" \
    -CA "${TLS_DIR}/certs/ca.pem" \
    -CAkey "${TLS_DIR}/private/ca.key" \
    -CAcreateserial \
    -out "${TLS_DIR}/certs/client.pem.new" \
    -extfile "${TLS_DIR}/client-rotate.ext" \
    -extensions v3_req

# Verify the new certificate
openssl verify -CAfile "${TLS_DIR}/certs/ca.pem" "${TLS_DIR}/certs/client.pem.new"
```

**Step 4: Atomically replace the certificate**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# Backup old files
cp "${TLS_DIR}/certs/client.pem"   "${TLS_DIR}/certs/client.pem.old"
cp "${TLS_DIR}/private/client.key" "${TLS_DIR}/private/client.key.old"

# Install new files
mv "${TLS_DIR}/certs/client.pem.new"    "${TLS_DIR}/certs/client.pem"
mv "${TLS_DIR}/private/client.key.new"  "${TLS_DIR}/private/client.key"

# Reapply SELinux labels
sudo restorecon -v "${TLS_DIR}/certs/client.pem"
sudo restorecon -v "${TLS_DIR}/private/client.key"

echo "Certificate replaced."
```

**Step 5: Restart the File Daemon container**

```bash
export XDG_RUNTIME_DIR=/run/user/1001
systemctl --user restart bareos-fd.service
sleep 3
systemctl --user status bareos-fd.service --no-pager
```

**Step 6: Verify the new certificate is in use**

```bash
TLS_DIR="/home/bareos/.config/bareos/tls"

# The new certificate's 'Not After' date should be ~1 year from today
openssl s_client \
    -connect localhost:9102 \
    -CAfile "${TLS_DIR}/certs/ca.pem" \
    </dev/null 2>&1 | grep -E "CN|Not After|Verify return"

# Expected: CN = bareos-fd, Not After ~ Feb 2027, Verify return code: 0 (ok)
```

**Step 7: Run a backup job to confirm the rotated certificate works**

```bash
export XDG_RUNTIME_DIR=/run/user/1001
podman exec bareos-director bconsole << 'EOF'
run job=BackupClient1 level=Full yes
wait
messages
EOF
```

The job should complete successfully, confirming that the Director can connect to the File Daemon using the new certificate.

---

[↑ Back to Table of Contents](#table-of-contents)

## 20. Summary

TLS in Bareos transforms your backup infrastructure from a potential data exfiltration channel into a secure, authenticated, encrypted communication system.

The key architectural facts to remember:

- **Four connections require TLS:** bconsole→DIR, DIR→FD, DIR→SD, FD→SD
- **Both ends must be configured:** enabling TLS on the server without configuring the client results in a connection failure, not a fallback to plaintext
- **TLS-PSK is the default and is encrypted** — but certificate-based TLS (`TLS Verify Peer = yes`) adds cryptographic identity verification
- **`TLS Require = yes` is mandatory in production** — otherwise a misconfigured client can connect without encryption

The certificate hierarchy for Bareos is simple:
- A single internal CA signs all certificates
- All daemons trust only that CA
- Each daemon presents its own certificate signed by that CA
- `TLS Allowed CN` provides an additional authorization check beyond certificate validity

In rootless Podman on RHEL 10, certificates are distributed via bind-mounts in Quadlet `.container` files. SELinux requires that certificate files be labeled `container_file_t` — accomplished most easily with the `:z` (shared) or `:Z` (private) volume option. For permanent labeling, use `semanage fcontext` followed by `restorecon`.

Certificate rotation is a planned, non-disruptive operation: generate a new key and certificate, replace the files on the host, restart the affected container. No changes to other daemons are required as long as the same CA signs the new certificate.

[↑ Back to Table of Contents](#table-of-contents)
