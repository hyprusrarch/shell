#!/usr/bin/env bash
set -euo pipefail
kind="${1:-}"
case "$kind" in
    text|image)
        command -v cliphist >/dev/null 2>&1 || exit 127
        tmp_dir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/qs-clip-clear.XXXXXX")"
        trap 'rm -rf -- "$tmp_dir"' EXIT HUP INT TERM
        cliphist list -fields id,mime,preview | awk -F '\t' -v kind="$kind" '
            { image = ($2 ~ /^image\// || $3 ~ /\[\[ binary data/) }
            kind == "image" && image { print $1 }
            kind == "text" && !image { print $1 }
        ' > "$tmp_dir/ids"
        src_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clip-sources"
        while IFS= read -r clip_id; do rm -f -- "$src_dir/$clip_id"; done < "$tmp_dir/ids" 2>/dev/null || true
        if [ -s "$tmp_dir/ids" ]; then
            cliphist list > "$tmp_dir/all"
            awk -F '\t' '
                FILENAME == ARGV[1] { wanted[$1] = 1; next }
                ($1 in wanted) { print }
            ' "$tmp_dir/ids" "$tmp_dir/all" | cliphist delete
        fi
        if [ "$kind" = "text" ]; then
            rm -f -- /tmp/qs_clip_texts/* 2>/dev/null || true
        else
            rm -f -- /tmp/qs_clip_images/* 2>/dev/null || true
        fi
        ;;
    favorites)
        find "$HOME/.cache/qs_clip_favs" -maxdepth 1 -type f -name 'fav_*' -delete 2>/dev/null || true
        ;;
    all)
        command -v cliphist >/dev/null 2>&1 || { echo "cliphist is not installed" >&2; exit 127; }
        cliphist wipe
        rm -rf -- "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clip-sources" 2>/dev/null || true
        rm -f -- /tmp/qs_clip_texts/* /tmp/qs_clip_images/* 2>/dev/null || true
        find "$HOME/.cache/qs_clip_favs" -maxdepth 1 -type f -name 'fav_*' -delete 2>/dev/null || true
        ;;
    *) echo "Usage: $0 {text|image|favorites|all}" >&2; exit 2 ;;
esac
