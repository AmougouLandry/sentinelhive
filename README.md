# SentinelHive

> A multi-honeypot deployment with ELK SIEM integration and ML-based attacker behavior analysis.

[![Status](https://img.shields.io/badge/status-phase%201%20in%20progress-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()
[![Cowrie](https://img.shields.io/badge/cowrie-running-success)]()
[![Dionaea](https://img.shields.io/badge/dionaea-running-success)]()

## Overview

SentinelHive is a homegrown threat intelligence platform that captures, analyzes, and characterizes attacker behavior using a coordinated stack of honeypots, a SIEM pipeline, and unsupervised machine learning. The system is designed to surface distinct attacker "personas" from raw session data — turning noisy probe traffic into actionable threat intelligence.

## Architecture

┌─────────────────────────────────────────────────────────┐
│                     Honeypot Fleet                       │
│   ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│   │ Cowrie  │  │ Dionaea  │  │Heralding │  │  HTTP   │ │
│   │ (SSH)   │  │ (SMB/FTP)│  │ (creds)  │  │ (web)   │ │
│   │   ✓     │  │    ✓     │  │          │  │         │ │
│   └────┬────┘  └────┬─────┘  └────┬─────┘  └────┬────┘ │
│        └────────────┴─────────────┴─────────────┘       │
│                          │                               │
│                     [Filebeat]                          │
└──────────────────────────┼──────────────────────────────┘
│
┌──────────────────────────▼──────────────────────────────┐
│                      ELK Stack                           │
│   Logstash → Elasticsearch → Kibana (dashboards)        │
└──────────────────────────┬──────────────────────────────┘
│
┌──────────────────────────▼──────────────────────────────┐
│                   ML Pipeline                            │
│   Feature engineering → Clustering → Persona analysis   │
└─────────────────────────────────────────────────────────┘

## Project Status

| Phase | Component | Status |
|-------|-----------|--------|
| 1 | Cowrie SSH honeypot (Docker)         | Complete |
| 1 | Dionaea (SMB/FTP/MSSQL honeypot)     | Complete |
| 1 | Heralding (multi-protocol creds)     | Planned |
| 1 | Custom HTTP honeypot                 | Planned |
| 2 | Elasticsearch + Logstash + Kibana    | Planned |
| 2 | Filebeat log shipping pipeline       | Planned |
| 3 | Feature engineering & ML clustering  | Planned |
| 4 | Findings, writeup, blog post         | Planned |

## Phase 1 Deliverables

### Cowrie — SSH medium-interaction honeypot

The Cowrie SSH honeypot is deployed in Docker, configured via official environment variables, with:

- Generic Linux server disguise (`svr01`, fake Ubuntu 5.15 kernel)
- Realistic credential policy via `AuthRandom` (only weak/default creds work, with intentional failures to avoid honeypot fingerprinting)
- Full JSON logging of every connection, auth attempt, command, and download
- Persisted TTY session recordings for replay analysis
- Persisted host-side log volumes for downstream SIEM ingestion

Validated capture across 8 attacker sessions including 19 commands, 13 failed logins, and 5 successful authentications. Sample data committed at [`docs/samples/cowrie-sample-events.json`](docs/samples/cowrie-sample-events.json).

### Dionaea — multi-protocol low-interaction honeypot

Dionaea is deployed in Docker exposing **9 listening services across 16 honeypot personalities** (FTP, HTTP, HTTPS, SMB, MSSQL, MySQL, MQTT, Memcache, EPMAP, TFTP, and others). Configured to impersonate a Synology DiskStation NAS on FTP for realism, with JSON event logging for downstream ELK ingestion. The noisy SIP service was disabled due to a SQLite race condition in Dionaea 0.11.0.

Validated capture across 5 protocols (FTP, HTTP, Memcache, MySQL, MQTT) including FTP credential captures with full command sequences. Sample data committed at [`docs/samples/dionaea-sample-events.json`](docs/samples/dionaea-sample-events.json).

Event schema example (FTP credential capture):

```json
{
  "connection": {"protocol": "ftpd", "transport": "tcp", "type": "accept"},
  "src_ip": "172.18.0.1",
  "dst_port": 21,
  "timestamp": "2026-05-12T07:21:01.690903",
  "ftp": {"commands": [{"command": "USER", "arguments": ["root"]}, {"command": "PASS", "arguments": ["toor"]}, {"command": "QUIT", "arguments": []}]},
  "credentials": [{"password": "toor", "username": "root"}]
}
```

## Quick Start

> Run only in an isolated lab environment. Honeypots intentionally expose vulnerable services.

```bash
git clone git@github.com:AmougouLandry/sentinelhive.git
cd sentinelhive

# Set ownership for Cowrie's container UID
sudo mkdir -p honeypots/cowrie/data/tty honeypots/cowrie/data/downloads
sudo chown -R 999:999 honeypots/cowrie/data honeypots/cowrie/logs

# Bring up all honeypots
docker compose up -d

# Test Cowrie
ssh root@localhost -p 2222
# Try password: admin (after a couple failures, AuthRandom will accept)

# Test Dionaea FTP
echo -e "USER admin\r\nPASS admin\r\nQUIT" | nc 127.0.0.1 13021
```

## Tech Stack

- **Honeypots**: Cowrie (deployed), Dionaea (deployed), Heralding, custom HTTP (planned)
- **SIEM**: Elasticsearch, Logstash, Kibana, Filebeat (Phase 2)
- **ML**: Python 3.10, scikit-learn, pandas, HDBSCAN (Phase 3)
- **Orchestration**: Docker, Docker Compose
- **OS**: Ubuntu 22.04 (WSL2-compatible)

## Lessons Learned

**Cowrie image config drift.** The official `cowrie/cowrie:latest` image's internal file paths differ from older documentation. Initial attempts to override `filesystem`, `cmdoutput`, and `txtcmds` paths via a custom `cowrie.cfg` failed because hardcoded paths pointed to legacy locations. Fix: drop the custom config and use environment variables (`COWRIE_<SECTION>_<KEY>`) per the official Docker Hub documentation. Cleaner, version-controlled in `docker-compose.yml`, and immune to internal layout changes.

**Docker bind-mount UID mismatch.** Cowrie inside the container runs as UID 999. Host bind-mount directories defaulted to the host user's UID (1000), causing `Permission denied` on log writes. Fix: `chown -R 999:999` on host directories before container start. Subdirectories Cowrie expects (`tty/`, `downloads/`) had to be created with `sudo` because the chowned parent prevented the host user from creating them later.

**SSH host key change warning after rebuild.** Wiping volumes regenerates Cowrie's SSH host keys, triggering an SSH client warning on reconnect. Realistic — same warning would appear on a real server reinstall. Fix: `ssh-keygen -R "[localhost]:2222"` to clear the cached old key. In production, a real admin would distribute the new key out-of-band; in a honeypot context, regenerated keys are expected.

**Dionaea entrypoint vs bind-mount race.** Bind-mounting an empty host directory over Dionaea's config path caused the entrypoint's template-copy logic to skip initialization — the script tests for directory existence (`test ! -d`), not file presence, so an empty bind mount falsely signals "already initialized." Fixes required: (1) set `DIONAEA_FORCE_INIT=1` (the documented value `true` doesn't work — the script checks for literal `1`, discovered by reading the entrypoint source); (2) mount one level higher (`/opt/dionaea/etc` not `/opt/dionaea/etc/dionaea`) because the script copies to the parent directory; (3) remove `DIONAEA_FORCE_INIT` after first run, otherwise it overrides custom config changes on every restart.

**Container healthcheck mismatched container utilities.** Initial healthcheck used `ss -ltn | grep :21` to verify FTP is listening, but the minimal Dionaea image ships without `ss`, `netstat`, or `lsof`. Healthcheck failed silently, status stuck at `unhealthy` despite the service working correctly. Fix: replaced with a Python `socket.connect()` healthcheck, since Python is guaranteed present (Dionaea is a Python application). General lesson: healthcheck commands must use binaries that exist *in the container*, not the host.

**Dionaea SIP service SQLite race.** Dionaea 0.11.0's SIP module initializes its session database from multiple worker contexts simultaneously, causing `sqlite3.OperationalError: database is locked` on container start. Non-fatal but pollutes logs. Disabled by renaming `services-enabled/sip.yaml` to `sip.yaml.disabled` — Dionaea only loads files matching `.yaml`.

**File URI parsing requires triple-slash for absolute paths.** Dionaea's `log_json.yaml` accepts a `file://` URI for the output path. Configured as `file://var/log/dionaea/dionaea.json` (two slashes), Dionaea parsed this as `file://var` (authority=var) + `/log/dionaea/...` (path) and tried to write to `/log/dionaea/dionaea.json` at the filesystem root. The error message `Unable to open file /log/dionaea/dionaea.json` was the clue — the missing `/var` prefix revealed URI parsing was splitting the string differently than expected. Fix: use `file:///opt/dionaea/var/log/dionaea/dionaea.json` with three slashes — RFC 8089 requires triple-slash to signal absolute path with empty authority.

## Documentation

- [Architecture decisions](docs/architecture/) — design choices and trade-offs
- [Findings](docs/findings/) — attacker patterns and threat intel observations
- [Sample data](docs/samples/) — representative captured events

## Author

**AMOUGOU Landry** — Cybersecurity analyst in training
[GitHub](https://github.com/AmougouLandry)

## License

MIT — see [LICENSE](LICENSE) for details.

## Disclaimer

This project is for educational and research purposes. Honeypots may attract real attacker traffic. Deploy only in environments where you have explicit authorization and where compromise of the honeypot host would not impact production systems.
