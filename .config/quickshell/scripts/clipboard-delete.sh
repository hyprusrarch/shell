#!/bin/sh
# Delete a history item by cliphist's stable numeric ID, not by delegate index.
set -eu
type="${1:-}"
id="${2:-}"
path="${3:-}"

case "$type" in
    TXT|IMG)
        case "$id" in ''|*[!0-9]*) echo "invalid cliphist ID" >&2; exit 2 ;; esac
        command -v cliphist >/dev/null 2>&1 || { echo "cliphist is not installed" >&2; exit 127; }
        # Feed cliphist the canonical list row (ID + preview), exactly as its picker
        # pipeline expects. Resolve it immediately before deletion to avoid acting
        # on a recycled ListView index or an already-removed record.
        all_items="$(cliphist list)"
        line="$(printf '%s\n' "$all_items" | awk -F '\t' -v wanted="$id" '$1 == wanted { print; found=1; exit } END { if (!found) exit 1 }' || true)"
        if [ -n "$line" ]; then
            printf '%s\n' "$line" | cliphist delete
        fi
        rm -f -- "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clip-sources/$id"
        case "$path" in
            /tmp/qs_clip_texts/*|/tmp/qs_clip_images/*) rm -f -- "$path" ;;
        esac
        ;;
    FAV)
        case "$path" in
            "$HOME"/.cache/qs_clip_favs/fav_*) rm -f -- "$path" ;;
        esac
        ;;
    *) echo "Usage: $0 {TXT|IMG|FAV} ID PATH" >&2; exit 2 ;;
esac
