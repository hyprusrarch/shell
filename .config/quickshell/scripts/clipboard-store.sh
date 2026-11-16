#!/bin/sh
# Run by `wl-paste --watch`: the new clipboard content arrives on stdin.
# Stores it in cliphist exactly as before and also remembers which app it was
# copied from (the focused window at copy time), keyed by the cliphist ID.
set -u
cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
src_dir="$cache/clip-sources"
self_flag="$cache/clip-self-copy"
mkdir -p "$src_dir"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"

# Nothing to attribute for empty / "clear" / sensitive events: plain passthrough.
if [ ! -s "$tmp" ] || [ "${CLIPBOARD_STATE:-data}" != "data" ]; then
    cliphist store < "$tmp"
    exit 0
fi

focused_class() {
    c=""
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        c="$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*"class": *"\([^"]*\)".*/\1/p' | head -n1)"
    elif command -v niri >/dev/null 2>&1 && [ -n "${NIRI_SOCKET:-}" ]; then
        c="$(niri msg -j focused-window 2>/dev/null | sed -n 's/.*"app_id": *"\([^"]*\)".*/\1/p' | head -n1)"
    elif command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ]; then
        c="$(swaymsg -t get_tree 2>/dev/null | jq -r '.. | select(.focused? == true) | (.app_id // .window_properties.class // empty)' 2>/dev/null | head -n1)"
    fi
    printf '%s' "$c"
}

# Copies made from the clipboard UI itself re-use the entry's original source
# instead of whatever window happens to be focused.
cls=""
if [ -f "$self_flag" ] && [ -n "$(find "$self_flag" -mmin -1 2>/dev/null)" ]; then
    cls="$(cat "$self_flag" 2>/dev/null || true)"
fi
rm -f -- "$self_flag"
[ -n "$cls" ] || cls="$(focused_class)"
cls="$(printf '%s' "$cls" | tr -d '|\t\r\n')"

cliphist store < "$tmp"

if [ -n "$cls" ]; then
    id="$(cliphist list 2>/dev/null | head -n1 | cut -f1)"
    case "$id" in
        ''|*[!0-9]*) ;;
        *) printf '%s' "$cls" > "$src_dir/$id" ;;
    esac
fi

# Keep the source cache from growing forever.
find "$src_dir" -type f -mtime +30 -delete 2>/dev/null || true
