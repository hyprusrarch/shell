#!/bin/sh
# Owns the two long-running wl-paste clipboard history watchers for this shell.
set -eu
uid="$(id -u)"
action="${1:-start}"
state_dir="${XDG_RUNTIME_DIR:-${HOME}/.cache/quickshell}/quickshell-clipboard"
state_file="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clipboard-enabled"
mkdir -p "$state_dir" "$(dirname "$state_file")"
chmod 700 "$state_dir" 2>/dev/null || true

# The UI and shell startup can request the same state change at once. Serialize
# transitions so two concurrent starts cannot create duplicate wl-paste watchers.
lock_dir="$state_dir/.transition-lock"
lock_attempt=0
while ! mkdir "$lock_dir" 2>/dev/null; do
    lock_owner="$(cat "$lock_dir/pid" 2>/dev/null || true)"
    case "$lock_owner" in
        ''|*[!0-9]*) ;;
        *) if ! kill -0 "$lock_owner" 2>/dev/null; then rm -rf -- "$lock_dir" 2>/dev/null || true; fi ;;
    esac
    lock_attempt=$((lock_attempt + 1))
    if [ "$lock_attempt" -ge 100 ]; then
        echo "Timed out waiting for clipboard service lock" >&2
        exit 1
    fi
    sleep 0.05
done
printf '%s\n' "$$" > "$lock_dir/pid"
release_lock() { rm -rf -- "$lock_dir" 2>/dev/null || true; }
trap release_lock EXIT
trap 'exit 130' INT TERM HUP

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
store_script="$script_dir/clipboard-store.sh"

pid_file() { printf '%s/cliphist-%s.pid' "$state_dir" "$1"; }

is_our_watcher() {
    pid="$1"
    kind="$2"
    [ -r "/proc/$pid/cmdline" ] || return 1
    cmd="$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"
    case "$cmd" in
        *"wl-paste --type $kind --watch "*) return 0 ;;
        *) return 1 ;;
    esac
}

# A watcher started by an older version (plain `cliphist store`) does not record
# the source app, so it is replaced rather than reused.
is_current_watcher() {
    pid="$1"
    [ -r "/proc/$pid/cmdline" ] || return 1
    case "$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)" in
        *clipboard-store.sh*) return 0 ;;
        *) return 1 ;;
    esac
}

stop_watcher() {
    kind="$1"
    file="$(pid_file "$kind")"
    pid="$(cat "$file" 2>/dev/null || true)"
    case "$pid" in
        ''|*[!0-9]*) pid="$(find_watcher "$kind" || true)" ;;
    esac
    case "$pid" in
        ''|*[!0-9]*) ;;
        *)
            if kill -0 "$pid" 2>/dev/null && is_our_watcher "$pid" "$kind"; then
                kill -TERM "$pid" 2>/dev/null || true
                n=0
                while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 20 ]; do
                    sleep 0.05
                    n=$((n + 1))
                done
                if kill -0 "$pid" 2>/dev/null && is_our_watcher "$pid" "$kind"; then
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            fi
            ;;
    esac
    rm -f -- "$file"
}

find_watcher() {
    kind="$1"
    for proc in /proc/[0-9]*; do
        [ -r "$proc/status" ] || continue
        owner="$(awk '/^Uid:/ { print $2; exit }' "$proc/status" 2>/dev/null || true)"
        [ "$owner" = "$uid" ] || continue
        pid="${proc##*/}"
        if is_our_watcher "$pid" "$kind"; then
            printf '%s\n' "$pid"
            return 0
        fi
    done
    return 1
}

start_watcher() {
    kind="$1"
    file="$(pid_file "$kind")"
    if [ -r "$file" ]; then
        pid="$(cat "$file" 2>/dev/null || true)"
        case "$pid" in
            ''|*[!0-9]*) ;;
            *)
                if kill -0 "$pid" 2>/dev/null && is_our_watcher "$pid" "$kind"; then
                    if is_current_watcher "$pid"; then return 0; fi
                    stop_watcher "$kind"
                fi
                ;;
        esac
        rm -f -- "$file"
    fi

    existing="$(find_watcher "$kind" || true)"
    if [ -n "$existing" ]; then
        if is_current_watcher "$existing"; then
            printf '%s\n' "$existing" > "$file"
            return 0
        fi
        stop_watcher "$kind"
    fi

    nohup wl-paste --type "$kind" --watch sh "$store_script" </dev/null >/dev/null 2>&1 &
    pid=$!
    printf '%s\n' "$pid" > "$file"
    sleep 0.08
    if ! kill -0 "$pid" 2>/dev/null || ! is_our_watcher "$pid" "$kind"; then
        rm -f -- "$file"
        echo "Failed to start $kind clipboard watcher" >&2
        return 1
    fi
}

case "$action" in
    stop)
        stop_watcher text
        stop_watcher image
        printf '0\n' > "$state_file"
        ;;
    start)
        if [ -r "$state_file" ] && [ "$(cat "$state_file" 2>/dev/null || printf 0)" = "0" ]; then
            stop_watcher text
            stop_watcher image
            exit 0
        fi
        command -v wl-paste >/dev/null 2>&1 || { echo "wl-paste is not installed" >&2; exit 127; }
        command -v cliphist >/dev/null 2>&1 || { echo "cliphist is not installed" >&2; exit 127; }
        printf '1\n' > "$state_file"
        start_watcher text
        start_watcher image
        ;;
    status)
        for kind in text image; do
            file="$(pid_file "$kind")"
            pid="$(cat "$file" 2>/dev/null || true)"
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && is_our_watcher "$pid" "$kind"; then
                printf '%s=running:%s\n' "$kind" "$pid"
            else
                printf '%s=stopped\n' "$kind"
            fi
        done
        ;;
    *)
        echo "Usage: $0 [start|stop|status]" >&2
        exit 2
        ;;
esac
