#!/usr/bin/env bash
set -euo pipefail

# One-time, project-local install of the official Google Sans Flex variable font.
# The font is fetched from the upstream googlefonts release, not a third-party mirror.
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FONT_DIR="$ROOT/assets/fonts"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

VERSION='v5.000'
ARCHIVE="$TMP_DIR/GoogleSansFlex-v5.000.zip"
URL="https://github.com/googlefonts/googlesans-flex/releases/download/${VERSION}/GoogleSansFlex-v5.000.zip"
EXPECTED_SHA256='c20b00878dd801d1bfc06d771732447940c7255bf94cf538ce0102c7fb06fa85'

for tool in curl unzip sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$tool" >&2
        exit 1
    }
done

printf 'Downloading Google Sans Flex %s from the official release…\n' "$VERSION"
curl --fail --location --retry 3 --connect-timeout 15 "$URL" --output "$ARCHIVE"
ACTUAL_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    printf 'Release archive checksum mismatch; refusing to install.\nExpected: %s\nActual:   %s\n' \
        "$EXPECTED_SHA256" "$ACTUAL_SHA256" >&2
    exit 1
fi

mkdir -p "$TMP_DIR/extracted" "$FONT_DIR"
unzip -q "$ARCHIVE" -d "$TMP_DIR/extracted"
FONT_FILE="$(find "$TMP_DIR/extracted" -type f -iname 'GoogleSansFlex*.ttf' \
    ! -iname '*android*' ! -iname '*figma*' ! -iname '*workspace*' ! -iname '*tv*' -print -quit)"
if [[ -z "$FONT_FILE" ]]; then
    printf 'Could not find the main Google Sans Flex TTF in the official archive.\n' >&2
    exit 1
fi
install -m 0644 "$FONT_FILE" "$FONT_DIR/GoogleSansFlex.ttf"

# Preserve the upstream font license alongside the installed font if present.
LICENSE_FILE="$(find "$TMP_DIR/extracted" -type f \( -iname 'OFL.txt' -o -iname 'OFL-1.1.txt' \) -print -quit)"
if [[ -n "$LICENSE_FILE" ]]; then
    install -m 0644 "$LICENSE_FILE" "$FONT_DIR/OFL.txt"
fi

printf 'Installed project-local font: %s\n' "$FONT_DIR/GoogleSansFlex.ttf"
printf 'Restart Quickshell to load Google Sans Flex.\n'
