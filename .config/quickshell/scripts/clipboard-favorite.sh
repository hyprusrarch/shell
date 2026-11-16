#!/bin/sh
set -eu
action="${1:-}"
source_path="${2:-}"
dest_path="${3:-}"
case "$action" in
    add)
        [ -n "$source_path" ] && [ -n "$dest_path" ] || exit 2
        mkdir -p "$HOME/.cache/qs_clip_favs"
        cp -- "$source_path" "$dest_path"
        ;;
    remove)
        case "$source_path" in
            "$HOME"/.cache/qs_clip_favs/fav_*) rm -f -- "$source_path" ;;
        esac
        ;;
    *) echo "Usage: $0 {add SOURCE DEST|remove PATH}" >&2; exit 2 ;;
esac
