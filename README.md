<p align="center">
  <img src="assets/hevox-agent.png" width="600" alt="Hevox Agent">
</p>

<p align="center">
  <strong>Lightweight node agent for the Hevox game server management platform.</strong>
</p>

<p align="center">
  <a href="https://github.com/bretazaaa/hevoxagent-releases/releases/latest">
    <img src="https://img.shields.io/github/v/release/bretazaaa/hevoxagent-releases?style=flat-square&label=release" alt="Release">
  </a>
  <img src="https://img.shields.io/badge/platform-Linux-blue?style=flat-square&logo=linux" alt="Linux">
  <img src="https://img.shields.io/badge/package-DEB-red?style=flat-square&logo=debian" alt="Debian">
  <img src="https://img.shields.io/badge/source-private-orange?style=flat-square" alt="Private Source">
</p>

---

## About

**Hevox Agent** connects Linux nodes to **Hevox Panel**.

It provides secure communication, system monitoring and workload management across your infrastructure.

A Hevox node can run a **single dedicated server** or **multiple game servers**, depending on your infrastructure and isolation requirements.

<p align="center">
  <img src="assets/hevox-preview.png" width="900" alt="Hevox Infrastructure">
</p>

## Architecture

Hevox Agent runs natively on each managed Linux node.

```text
Hevox Panel
     │
     │ API
     ▼
Hevox Agent
     │
     └── Node
          ├── Game Server
          ├── Game Server
          └── Game Server
```

Nodes can be deployed in different ways:

* **All-in-One** — Panel, Agent and game servers on the same machine.
* **Shared Node** — One Agent managing multiple game servers.
* **Dedicated Node** — One VM/LXC, one Agent and one isolated game server.

Hevox Agent itself runs as a native Linux service. Containerization may be used as a runtime for workloads when required.

## Installation

Install the latest version:

```bash
curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash
```

Then pair the Agent with your Hevox Panel:

```bash
hevoxagent pair --panel https://your-panel.example.com
```

Once paired:

```bash
sudo systemctl start hevoxagent
```

## Updating

Run the installer again:

```bash
curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash
```

The installer automatically detects and installs the latest available version while preserving the Agent configuration and identity.

## Requirements

* Linux
* Debian / Ubuntu based distribution
* Root or sudo access
* Network access to Hevox Panel

## Releases

This repository contains **compiled Hevox Agent releases only**.

The source code is maintained in a private repository.

Pre-built packages are available from the [Releases](https://github.com/bretazaaa/hevoxagent-releases/releases) page.

## Project Status

> Hevox Agent is currently under active development.

APIs, configuration and installation methods may change before the first stable release.

## License

See [LICENSE](LICENSE) for more information.

---

<p align="center">
  <img src="assets/hevox-logo.png" width="70" alt="Hevox">
</p>

<p align="center">
  <strong>Hevox</strong><br>
  Deploy. Manage. Evolve.
</p>
