#!/bin/bash

set -eo pipefail

USERBIN="$HOME/.local/bin"
if [ ! -d "$USERBIN" ]; then
    mkdir -p "$USERBIN"
fi

VERBS="start stop restart status enable disable"
JVERBS="follow logs blogs"

install() {
    for verb in $VERBS $JVERBS; do
        ln -sf "$(realpath "$0")" "$USERBIN/$verb"
    done
}

uninstall() {
    for verb in $VERBS $JVERBS; do
        rm -f "$USERBIN/$verb"
    done
}

if [ "$1" = "install" ]; then
    install
    echo "Installed systemd-helper verbs to $USERBIN"
    exit 0
fi

if [ "$1" = "uninstall" ]; then
    uninstall
    echo "Removed systemd-helper verbs from $USERBIN"
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

# Check what name this script was called with
ME=$(basename "$0")

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
