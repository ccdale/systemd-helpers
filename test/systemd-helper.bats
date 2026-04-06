#!/usr/bin/env bats

setup() {
  export SCRIPT_UNDER_TEST="$BATS_TEST_DIRNAME/../systemd-helper.sh"
  chmod +x "$SCRIPT_UNDER_TEST"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"

  export MOCK_BIN="$BATS_TEST_TMPDIR/mock-bin"
  mkdir -p "$MOCK_BIN"

  export CALLS_FILE="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_FILE"

  make_mock systemctl
  make_mock journalctl
  make_mock ln
  make_mock rm
  make_mock realpath 'printf "%s\n" "$1"'

  export PATH="$MOCK_BIN:$PATH"
}

make_mock() {
  local name="$1"
  local body="${2:-capture_call \"$name\" \"\$@\"}"

  cat > "$MOCK_BIN/$name" <<EOF
#!/usr/bin/env bash
set -euo pipefail
capture_call() {
  local cmd="\$1"
  shift
  {
    printf "%s" "\$cmd"
    for arg in "\$@"; do
      printf " [%s]" "\$arg"
    done
    printf "\\n"
  } >> "${CALLS_FILE}"
}
$body
EOF
  chmod +x "$MOCK_BIN/$name"
}

invoke_as() {
  local verb="$1"
  shift

  /usr/bin/ln -sf "$SCRIPT_UNDER_TEST" "$MOCK_BIN/$verb"
  run "$MOCK_BIN/$verb" "$@"
}

@test "prints usage when service name is missing" {
  run "$SCRIPT_UNDER_TEST"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "prints verb usage when invoked with unsupported verb name" {
  invoke_as unknown demo

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: <VERB> <service-name>"* ]]
}

@test "install creates links for all verbs" {
  run "$SCRIPT_UNDER_TEST" install

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed systemd-helper verbs"* ]]

  run grep -c '^ln ' "$CALLS_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 9 ]

  run grep -F "ln [-sf] [$SCRIPT_UNDER_TEST] [$HOME/.local/bin/start]" "$CALLS_FILE"
  [ "$status" -eq 0 ]

  run grep -F "ln [-sf] [$SCRIPT_UNDER_TEST] [$HOME/.local/bin/blogs]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "uninstall removes only links pointing to this script" {
  mkdir -p "$HOME/.local/bin"
  # Create two real symlinks pointing to this script
  /usr/bin/ln -sf "$SCRIPT_UNDER_TEST" "$HOME/.local/bin/start"
  /usr/bin/ln -sf "$SCRIPT_UNDER_TEST" "$HOME/.local/bin/s-stop"
  # Create a decoy symlink pointing elsewhere
  /usr/bin/ln -sf "/usr/bin/true" "$HOME/.local/bin/other"

  run "$SCRIPT_UNDER_TEST" uninstall

  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed 2 systemd-helper verb(s)"* ]]

  # Both script links should have been removed
  run grep -F "rm [-f] [$HOME/.local/bin/start]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
  run grep -F "rm [-f] [$HOME/.local/bin/s-stop]" "$CALLS_FILE"
  [ "$status" -eq 0 ]

  # Decoy link should NOT have been removed
  run grep -F "rm [-f] [$HOME/.local/bin/other]" "$CALLS_FILE"
  [ "$status" -ne 0 ]
}

@test "install with prefix creates prefixed links" {
  run "$SCRIPT_UNDER_TEST" install s-

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed systemd-helper verbs"* ]]

  run grep -F "ln [-sf] [$SCRIPT_UNDER_TEST] [$HOME/.local/bin/s-start]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
  run grep -F "ln [-sf] [$SCRIPT_UNDER_TEST] [$HOME/.local/bin/s-blogs]" "$CALLS_FILE"
  [ "$status" -eq 0 ]

  # Verify unprefixed names were NOT created
  run grep -F "ln [-sf] [$SCRIPT_UNDER_TEST] [$HOME/.local/bin/start]" "$CALLS_FILE"
  [ "$status" -ne 0 ]
}

@test "systemctl verbs call systemctl with verb and service" {
  invoke_as restart sshd

  [ "$status" -eq 0 ]
  run grep -F "systemctl [restart] [sshd]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "prefixed verb name dispatches correct verb" {
  invoke_as sys-status myapp

  [ "$status" -eq 0 ]
  run grep -F "systemctl [status] [myapp]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "prefixed journal verb name dispatches correct verb" {
  invoke_as sys-blogs myapp

  [ "$status" -eq 0 ]
  run grep -F "journalctl [--unit=myapp] [-b]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "logs calls journalctl with --unit only" {
  invoke_as logs nginx

  [ "$status" -eq 0 ]
  run grep -F "journalctl [--unit=nginx]" "$CALLS_FILE"
  [ "$status" -eq 0 ]

  run grep -F "[-f]" "$CALLS_FILE"
  [ "$status" -ne 0 ]

  run grep -F "[-b]" "$CALLS_FILE"
  [ "$status" -ne 0 ]
}

@test "follow adds -f to journalctl call" {
  invoke_as follow docker

  [ "$status" -eq 0 ]
  run grep -F "journalctl [--unit=docker] [-f]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "blogs adds -b to journalctl call" {
  invoke_as blogs NetworkManager

  [ "$status" -eq 0 ]
  run grep -F "journalctl [--unit=NetworkManager] [-b]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "does not add --user when user service file is missing" {
  mkdir -p "$HOME/.config/systemd/user"

  invoke_as status mysvc

  [ "$status" -eq 0 ]
  run grep -F "systemctl [status] [mysvc] [--user]" "$CALLS_FILE"
  [ "$status" -ne 0 ]
  run grep -F "systemctl [status] [mysvc]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}

@test "adds --user when user service file exists" {
  mkdir -p "$HOME/.config/systemd/user"
  touch "$HOME/.config/systemd/user/mysvc.service"

  invoke_as status mysvc

  [ "$status" -eq 0 ]
  run grep -F "systemctl [status] [mysvc] [--user]" "$CALLS_FILE"
  [ "$status" -eq 0 ]
}
