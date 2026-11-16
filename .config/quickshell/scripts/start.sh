#!/bin/sh
set -eu
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
entry="$config_dir/shell.qml"
if [ ! -f "$entry" ]; then
    echo "Quickshell config not found: $entry" >&2
    exit 1
fi
runtime="${XDG_RUNTIME_DIR:-/tmp/qs-runtime-$(id -u)}"
umask 077
mkdir -p "$runtime/quickshell"
chmod 700 "$runtime/quickshell"
touch "$runtime/quickshell/control"
for name in launcher clipboard media modules powerdrop powermenu; do
    path="$runtime/quickshell/$name.cmd"
    [ ! -p "$path" ] || rm -f "$path"
    touch "$path"
done
# A quick duplicate guard for repeated compositor autostart invocations.
if pgrep -u "$(id -u)" -f "[q]s .*${entry}" >/dev/null 2>&1; then
    exit 0
fi
export MALLOC_ARENA_MAX=2
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_CONF="narenas:2,background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000"
export QT_LOGGING_RULES="*.debug=false"
export QS_NO_RELOAD_POPUP=1
if [ "${QS_DEV:-0}" != "1" ]; then
    export QS_DISABLE_FILE_WATCHER=1
fi
exec qs -p "$entry"
