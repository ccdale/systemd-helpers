#!/bin/bash

set -eo pipefail

USERBIN="$HOME/.local/bin"
if [ ! -d "$USERBIN" ]; then
    mkdir -p "$USERBIN"
fi

VERBS="start stop restart status enable disable"
JVERBS="follow logs blogs"

install() {
    local prefix="${1:-}"
    for verb in $VERBS $JVERBS; do
        ln -sf "$(realpath "$0")" "$USERBIN/${prefix}${verb}"
    done
}

uninstall() {
    local script_path removed=0
    script_path="$(realpath "$0")"
    for link in "$USERBIN"/*; do
        [ -L "$link" ] || continue
        if [ "$(readlink "$link")" = "$script_path" ]; then
            rm -f "$link"
            removed=$((removed + 1))
        fi
    done
    echo "Removed $removed systemd-helper verb(s) from $USERBIN"
}

if [ "$1" = "install" ]; then
    install "${2:-}"
    echo "Installed systemd-helper verbs to $USERBIN"
    exit 0
fi

if [ "$1" = "uninstall" ]; then
    uninstall
    exit 0
fi

USERSERVICE=

SERVICE=${1}
if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name>"
    exit 1
fi

# check if this is a user service or a system service
confd=$HOME/.config/systemd/user
if [ -d "$confd" ]; then
    service_path="$confd/$SERVICE.service"
    if [ -f "$service_path" ]; then
        USERSERVICE=" --user"
    fi
fi

# Resolve the verb from the command name, stripping a prefix if needed.
# Strips one character at a time from the front until a known verb is found
# or fewer than 4 characters remain (no verb is shorter than 4 chars).
resolve_verb() {
    local name="$1"
    while [[ ${#name} -ge 4 ]]; do
        if [[ " $VERBS $JVERBS " =~ " $name " ]]; then
            printf "%s" "$name"
            return 0
        fi
        name="${name:1}"
    done
    return 1
}

# Check what name this script was called with
ME=$(basename "$0")
ME=$(resolve_verb "$ME") || ME=""

if [[ ! " $VERBS " =~ " $ME " ]] && [[ ! " $JVERBS " =~ " $ME " ]]; then
    echo "Usage: <VERB> <service-name>"
    echo "VERBs are soft-linked to this script, so you can call it with the verb as the name of the script."
    echo "Verbs: $VERBS"
    echo "Journal Verbs: $JVERBS"
    exit 1
fi

if [[ " $VERBS " =~ " $ME " ]]; then
    systemctl "$ME" "$SERVICE" $USERSERVICE
    exit $?
elif [[ " $JVERBS " =~ " $ME " ]]; then
    if [ "$ME" = "blogs" ]; then
        USERSERVICE="$USERSERVICE -b"
    elif [ "$ME" = "follow" ]; then
        USERSERVICE="$USERSERVICE -f"
    fi
    journalctl --unit="$SERVICE" $USERSERVICE
    exit $?
fi
