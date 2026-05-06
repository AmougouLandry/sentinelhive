# SentinelHive

> A multi-honeypot deployment with ELK SIEM integration and ML-based attacker behavior analysis.

[![Status](https://img.shields.io/badge/status-in%20development-yellow)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()

## Overview

SentinelHive is a homegrown threat intelligence platform that captures, analyzes, and characterizes attacker behavior using a coordinated stack of honeypots, a SIEM pipeline, and unsupervised machine learning. The system is designed to surface distinct attacker "personas" from raw session data — turning noisy probe traffic into actionable threat intelligence.

## Architecture

┌─────────────────────────────────────────────────────────┐
│                     Honeypot Fleet                       │
│   ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐ │
│   │ Cowrie  │  │ Dionaea  │  │Heralding │  │  HTTP   │ │
│   │ (SSH)   │  │ (SMB/FTP)│  │ (creds)  │  │ (web)   │ │
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

| Phase | Status |
|-------|--------|
| 1. Honeypot fleet (Docker)         | 🟡 In progress |
| 2. ELK SIEM pipeline               | ⬜ Not started |
| 3. ML attacker behavior analysis   | ⬜ Not started |
| 4. Findings & writeup              | ⬜ Not started |

## Quick Start

> ⚠️ Run only in an isolated lab environment. Honeypots intentionally expose vulnerable services.

```bash
git clone git@github.com:AmougouLandry/sentinelhive.git
cd sentinelhive
cp .env.example .env
make up
```

## Tech Stack

- **Honeypots**: Cowrie, Dionaea, Heralding, custom HTTP honeypot
- **SIEM**: Elasticsearch, Logstash, Kibana, Filebeat
- **ML**: Python 3.10, scikit-learn, pandas, HDBSCAN
- **Orchestration**: Docker, Docker Compose
- **OS**: Ubuntu 22.04 (WSL2-compatible)

## Documentation

- [Architecture decisions](docs/architecture/) — design choices and trade-offs
- [Findings](docs/findings/) — attacker patterns and threat intel observations
- [Deployment guide](docs/) — how to reproduce this lab

## Author

**AMOUGOU Landry** — Cybersecurity analyst in training
[GitHub](https://github.com/AmougouLandry)

## License

MIT — see [LICENSE](LICENSE) for details.

## Disclaimer

This project is for educational and research purposes. Honeypots may attract real attacker traffic. Deploy only in environments where you have explicit authorization and where compromise of the honeypot host would not impact production systems.
