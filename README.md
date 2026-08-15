<p align="center">
  <img src="assets/hevox-agent.png" width="450" alt="Hevox Agent">
</p>

<p align="center">
  <strong>The lightweight node agent powering the Hevox ecosystem.</strong>
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

**Hevox Agent** is the node-side service used by Hevox to manage and monitor game server infrastructure.

It provides secure communication between the **Hevox Panel** and your nodes, handling server operations, monitoring and infrastructure tasks.

> This repository contains **compiled releases only**.
> The Hevox Agent source code is maintained in a private repository.


## Installation

Install the latest version with:

```bash
curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash
```

The installer automatically downloads and installs the latest available release.

The installer detects whether this is a first install, an update, or
whether you're already on the latest version, and shows a short branded
summary either way — full `apt`/`dpkg`/`curl` output is logged to
`/var/log/hevoxagent/install.log` but hidden from the terminal by
default. An update never touches an existing `/etc/hevoxagent/config.yml`
or `/var/lib/hevoxagent/identity.json` — pairing state always survives
an update.

## Update

Run the installation command again to update Hevox Agent to the latest
version.

## Advanced usage

`curl | sudo bash` can't take flags directly — pass them after `-s --`:

```bash
# Show full apt/dpkg/curl/systemctl output as it runs, in addition to
# logging it. Useful for diagnosing a failed install/update.
curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash -s -- --verbose

# Pair with a panel and start the service automatically once installed
# (first install only).
curl -sSL https://raw.githubusercontent.com/bretazaaa/hevoxagent-releases/main/install.sh | sudo bash -s -- --panel http://your-panel:8080
```

## Releases

Pre-built Debian packages are available from the [Releases](https://github.com/bretazaaa/hevoxagent-releases/releases) page.

## Requirements

* Linux
* Debian / Ubuntu based distribution
* Root or sudo access
* Network access to your Hevox Panel

---

<p align="center">
  <img src="assets/hevox-logo.png" width="70" alt="Hevox">
</p>

<p align="center">
  <strong>Hevox</strong><br>
  Deploy. Manage. Evolve.
</p>
