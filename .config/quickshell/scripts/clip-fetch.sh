#!/usr/bin/env bash
set -u

printf 'HOME|%s\n' "$HOME"
command -v cliphist >/dev/null 2>&1 || exit 0
mkdir -p /tmp/qs_clip_images /tmp/qs_clip_texts "$HOME/.cache/qs_clip_favs"

src_dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/clip-sources"
source_of() {
    if [ -r "$src_dir/$1" ]; then tr -d '|\r\n' < "$src_dir/$1"; fi
}

text_count=0
image_count=0
keep=" "
while IFS= read -r row; do
    id=${row%%$'\t'*}
    row=${row#*$'\t'}
    mime=${row%%$'\t'*}
    preview=${row#*$'\t'}
    [ -n "$id" ] || continue
    mime=${mime%%;*}

    if [[ "$mime" == image/* || "$preview" == *'[[ binary data'* ]]; then
        [ "$image_count" -ge 30 ] && continue
        image_count=$((image_count + 1))
        case "$mime" in
            image/jpeg) ext=.jpg ;;
            image/webp) ext=.webp ;;
            image/gif) ext=.gif ;;
            image/svg+xml) ext=.svg ;;
            image/bmp) ext=.bmp ;;
            image/avif) ext=.avif ;;
            image/tiff) ext=.tiff ;;
            image/x-icon|image/vnd.microsoft.icon) ext=.ico ;;
            *) ext=.png ;;
        esac
        img_path="/tmp/qs_clip_images/${id}${ext}"
        if [ ! -s "$img_path" ]; then
            printf '%s\t%s\n' "$id" "$preview" | cliphist decode > "$img_path"
        fi
        keep="$keep$img_path "
        [ -s "$img_path" ] && printf 'IMG|%s|%s|%s|%s\n' "$id" "$img_path" "$mime" "$(source_of "$id")"
    else
        [ "$text_count" -ge 30 ] && continue
        text_count=$((text_count + 1))
        txt_path="/tmp/qs_clip_texts/${id}.txt"
        if [ ! -s "$txt_path" ]; then
            printf '%s\t%s\n' "$id" "$preview" | cliphist decode > "$txt_path"
        fi
        keep="$keep$txt_path "
        clean_content=$(head -c 2500 "$txt_path" | awk 1 ORS='_NL_' | sed 's/|/¦/g')
        printf 'TXT|%s|%s|%s|%s\n' "$id" "$txt_path" "$(source_of "$id")" "$clean_content"
    fi
done < <(cliphist list -fields id,mime,preview | sed -n '1,120p')

for f in /tmp/qs_clip_images/* /tmp/qs_clip_texts/*; do
    [ -f "$f" ] || continue
    case "$keep" in *" $f "*) ;; *) rm -f -- "$f" ;; esac
done
