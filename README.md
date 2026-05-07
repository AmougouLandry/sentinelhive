# SentinelHive

> A multi-honeypot deployment with ELK SIEM integration and ML-based attacker behavior analysis.

[![Status](https://img.shields.io/badge/status-phase%201%20complete-green)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()
[![Cowrie](https://img.shields.io/badge/cowrie-running-success)]()

## Overview

SentinelHive is a homegrown threat intelligence platform that captures, analyzes, and characterizes attacker behavior using a coordinated stack of honeypots, a SIEM pipeline, and unsupervised machine learning. The system is designed to surface distinct attacker "personas" from raw session data — turning noisy probe traffic into actionable threat intelligence.

## Architecture

┌─────────────────────────────────────────────────────────┐
│                     Honeypot Fleet                       │
│   ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│   │ Cowrie  │  │ Dionaea  │  │Heralding │  │  HTTP   │ │
│   │ (SSH)   │  │ (SMB/FTP)│  │ (creds)  │  │ (web)   │ │
│   │   ✓     │  │          │  │          │  │         │ │
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
| 1 | Dionaea (SMB/FTP/MSSQL honeypot)     | Planned |
| 1 | Heralding (multi-protocol creds)     | Planned |
| 1 | Custom HTTP honeypot                 | Planned |
| 2 | Elasticsearch + Logstash + Kibana    | Planned |
| 2 | Filebeat log shipping pipeline       | Planned |
| 3 | Feature engineering & ML clustering  | Planned |
| 4 | Findings, writeup, blog post         | Planned |

## Phase 1 Deliverables (Complete)

The Cowrie SSH honeypot is deployed in Docker, configured via official environment variables, with:

- Generic Linux server disguise (`svr01`, fake Ubuntu 5.15 kernel)
- Realistic credential policy via `AuthRandom` (only weak/default creds work, with intentional failures to avoid honeypot fingerprinting)
- Full JSON logging of every connection, auth attempt, command, and download
- Persisted TTY session recordings for replay analysis
- Persisted host-side log volumes for downstream SIEM ingestion

### Sample captured data

Validated capture across 8 attacker sessions including 19 commands, 13 failed logins, and 5 successful authentications. Captured event types include:

- `cowrie.command.input` — every command typed by the attacker
- `cowrie.login.success` — successful credential pairs
- `cowrie.login.failed` — credential probing attempts
- `cowrie.session.connect` — connection metadata, source IP, ports
- `cowrie.client.version` — attacker SSH client fingerprint
- `cowrie.client.fingerprint` — SSH key fingerprint of the attacker
- `cowrie.session.closed` — session duration and exit reason

A representative sample of captured events is committed at [`docs/samples/cowrie-sample-events.json`](docs/samples/cowrie-sample-events.json).

## Quick Start

> Run only in an isolated lab environment. Honeypots intentionally expose vulnerable services.

```bash
git clone git@github.com:AmougouLandry/sentinelhive.git
cd sentinelhive

# Set ownership for Cowrie's container UID
sudo mkdir -p honeypots/cowrie/data/tty honeypots/cowrie/data/downloads
sudo chown -R 999:999 honeypots/cowrie/data honeypots/cowrie/logs

# Bring up Cowrie
docker compose up -d cowrie

# Test it
ssh root@localhost -p 2222
# Try password: admin (after a couple failures, AuthRandom will accept it)
```

## Tech Stack

- **Honeypots**: Cowrie (deployed), Dionaea, Heralding, custom HTTP (planned)
- **SIEM**: Elasticsearch, Logstash, Kibana, Filebeat (Phase 2)
- **ML**: Python 3.10, scikit-learn, pandas, HDBSCAN (Phase 3)
- **Orchestration**: Docker, Docker Compose
- **OS**: Ubuntu 22.04 (WSL2-compatible)

## Lessons Learned (Phase 1)

A few real debugging stories from the deployment:

**Cowrie image config drift.** The official `cowrie/cowrie:latest` image's internal file paths differ from older documentation. Initial attempts to override `filesystem`, `cmdoutput`, and `txtcmds` paths via a custom `cowrie.cfg` failed because hardcoded paths pointed to legacy locations. Fix: drop the custom config and use environment variables (`COWRIE_<SECTION>_<KEY>`) per the official Docker Hub documentation. Cleaner, version-controlled in `docker-compose.yml`, and immune to internal layout changes.

**Docker bind-mount UID mismatch.** Cowrie inside the container runs as UID 999. Host bind-mount directories defaulted to the host user's UID (1000), causing `Permission denied` on log writes. Fix: `chown -R 999:999` on host directories before container start. Subdirectories Cowrie expects (`tty/`, `downloads/`) had to be created with `sudo` because the chowned parent prevented the host user from creating them later.

**SSH host key change warning after rebuild.** Wiping volumes regenerates Cowrie's SSH host keys, triggering an SSH client warning on reconnect. Realistic — same warning would appear on a real server reinstall. Fix: `ssh-keygen -R "[localhost]:2222"` to clear the cached old key. In production, a real admin would distribute the new key out-of-band; in a honeypot context, regenerated keys are expected.

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
