#!/bin/sh
set -eu
name="${1:-}"
case "$name" in
    launcher|clipboard|media|modules|powerdrop|powermenu) ;;
    *) echo "usage: $0 {launcher|clipboard|media|modules|powerdrop|powermenu}" >&2; exit 2 ;;
esac
runtime="${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}"
control="$runtime/quickshell/control"
[ -d "$(dirname "$control")" ] || mkdir -p "$(dirname "$control")"
printf 'toggle %s\n' "$name" >> "$control"
