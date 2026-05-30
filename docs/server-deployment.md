# Server Deployment Guide

This document describes how to deploy cmd-helper as a shared read-only package on a Linux multi-user server.

## Public Package Layout

Recommended public path:

    /data/public/tools/cmd-helper

Recommended layout:

    /data/public/tools/cmd-helper/
    ├── README.md
    ├── install.sh
    ├── uninstall.sh
    ├── bin/
    ├── lib/
    └── config/

## Permissions

The public package must be readable and executable by target users.

Recommended public permissions:

    find /data/public/tools/cmd-helper -type d -exec chmod 755 {} \;
    find /data/public/tools/cmd-helper/bin /data/public/tools/cmd-helper/lib -type f -exec chmod 755 {} \;
    chmod 755 /data/public/tools/cmd-helper/install.sh
    chmod 755 /data/public/tools/cmd-helper/uninstall.sh
    chmod 644 /data/public/tools/cmd-helper/README.md
    chmod 644 /data/public/tools/cmd-helper/VERSION

The package must not contain user API keys, tokens, runtime logs, or Copilot sessions.

## User Installation

Each user installs into their own home directory:

    bash /data/public/tools/cmd-helper/install.sh

Per-user files are stored under:

    ~/.local/bin
    ~/.local/lib
    ~/.config/copilot-deepseek
    ~/.config/copilot-cmd
    ~/.cache/copilot-cmd
    ~/.copilot-cmd

## Update

Maintainers may update the public package. Users can reinstall by running:

    bash /data/public/tools/cmd-helper/install.sh

The installer should not overwrite user-specific DeepSeek keys or user-specific Copilot model lists.
