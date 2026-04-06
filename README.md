# systemd-helpers

Small shell helper for systemd commands.

It lets you call common `systemctl` and `journalctl` actions as short command names (via symlinks), so instead of typing the full command each time, you run a verb directly.

## Verbs

Service verbs (mapped to `systemctl`):

- `start`
- `stop`
- `restart`
- `status`
- `enable`
- `disable`

Journal verbs (mapped to `journalctl --unit=<service>`):

- `logs`
- `follow` (adds `-f`)
- `blogs` (adds `-b` logs since last boot.)

## Requirements

- Linux with systemd
- `bash`
- `systemctl`
- `journalctl`
- `realpath`

## Install helper verbs

From this repository directory:

```bash
chmod +x systemd-helper.sh
./systemd-helper.sh install
```

This creates symlinks in `~/.local/bin` for all verbs.

Make sure `~/.local/bin` is on your `PATH`.

## Usage

Use the installed verb and pass a service name:

```bash
status sshd
restart docker
logs NetworkManager
follow nginx
blogs sshd
```

### User vs system service behavior

If `~/.config/systemd/user` exists, the script checks for
`~/.config/systemd/user/<service>.service`.

- If the unit file exists, it adds `--user`.
- If the unit file is missing, it runs without `--user`.

This reflects the current script behavior and test coverage.

## Uninstall helper verbs

```bash
./systemd-helper.sh uninstall
```

This removes the verb symlinks from `~/.local/bin`.

## Testing

Run tests with:

```bash
./run-tests.sh
```

Or pass Bats arguments directly:

```bash
./run-tests.sh --filter 'install|uninstall' test/systemd-helper.bats
```

For Bats installation details, see `TESTING.md`.

## Troubleshooting

### Verb command not found

Check that `~/.local/bin` is on `PATH`:

```bash
echo "$PATH"
```

If needed, add this to your shell profile and restart your shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Symlink missing or wrong target

Reinstall links:

```bash
./systemd-helper.sh install
```

Check one link target:

```bash
ls -l ~/.local/bin/status
```

### Remove all helper verbs

```bash
./systemd-helper.sh uninstall
```

Verify one link is gone:

```bash
ls -l ~/.local/bin/status
```
