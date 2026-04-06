# Testing

## Unit tests (mocked)

This repository includes a Bats test suite that validates argument parsing and command dispatch without calling real `systemctl` or `journalctl`.

Run:

    bats test/systemd-helper.bats

## Install Bats

Examples:

- Arch Linux:

      sudo pacman -S bats

- Debian/Ubuntu:

      sudo apt-get update && sudo apt-get install -y bats

- Fedora:

      sudo dnf install -y bats

## What is covered

- Usage errors for missing service/unsupported verb
- `install` command link creation for all verbs
- `uninstall` command link removal for all verbs
- Dispatch to `systemctl` for service verbs
- Dispatch to `journalctl` for journal verbs
- `follow` adds `-f`
- `blogs` adds `-b`
- Current `--user` detection behavior
- Adds `--user` when `~/.config/systemd/user/<service>.service` exists
