#!/bin/sh
set -eu

for command in notify-send dbus-monitor; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Missing command: %s\n' "$command" >&2
        printf 'Install libnotify and dbus, then run this script again.\n' >&2
        exit 127
    fi
done

log_file="$(mktemp)"
monitor_pid=
cleanup() {
    if [ -n "$monitor_pid" ]; then
        kill "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
    rm -f "$log_file"
}
trap cleanup EXIT HUP INT TERM

dbus-monitor --session \
    "type='signal',interface='org.freedesktop.Notifications',member='NotificationReplied'" \
    >"$log_file" 2>&1 &
monitor_pid=$!

# Give dbus-monitor time to subscribe before sending the test notification.
sleep 0.4
notify-send \
    --app-name='Quickshell Reply Test' \
    --expire-time=30000 \
    --urgency=critical \
    --action=inline-reply=Reply \
    --hint='string:x-kde-reply-placeholder-text:Type a test reply' \
    'Quickshell inline-reply test' \
    'Press Reply, enter a message, then press Enter or Send.'

printf 'Waiting for a reply. Use the shell notification card to send one. Ctrl+C to stop.\n'
while ! grep -q 'member=NotificationReplied' "$log_file"; do
    if ! kill -0 "$monitor_pid" 2>/dev/null; then
        cat "$log_file"
        printf 'D-Bus monitor exited before a reply was received.\n' >&2
        exit 1
    fi
    sleep 0.1
done

printf '\nReceived NotificationReplied signal:\n'
cat "$log_file"
