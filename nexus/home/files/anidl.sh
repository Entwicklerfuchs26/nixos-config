#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "Verwendung: AniDL <url> [<url2> <url3> ...]"
    exit 1
fi

DOWNLOADED_SHOWS=()

ntfy_send() {
    curl -s -X POST "https://ntfy.sh/Nexus-NixOS_fuchs" \
        -H "Title: $1" \
        -H "Tags: $3" \
        -d "$2" > /dev/null
}

download_one() {
    local URL="$1"

    # URL parsen
    local SLUG STAFFEL_NR EPISODE_NR
    SLUG=$(echo "$URL" | sed 's|.*/stream/||' | cut -d'/' -f1)
    STAFFEL_NR=$(echo "$URL" | grep -oP 'staffel-\K\d+' || true)
    EPISODE_NR=$(echo "$URL" | grep -oP 'episode-\K\d+' || true)

    # Slug → lesbarer Titel
    local NAME="" word
    for word in $(echo "$SLUG" | tr '-' ' '); do
        NAME="$NAME ${word^}"
    done
    NAME="${NAME# }"

    # Zielordner
    local STAFFEL_TAG="Staffel_${STAFFEL_NR:-1}"
    local ZIEL="$HOME/Videos/Animes/$NAME/$STAFFEL_TAG"
    mkdir -p "$ZIEL"

    # Label
    local LABEL
    if [ -n "$EPISODE_NR" ]; then
        LABEL="$NAME – S${STAFFEL_NR}E${EPISODE_NR}"
    else
        LABEL="$NAME – Staffel ${STAFFEL_NR:-1} (komplett)"
    fi

    echo "==> $LABEL"
    echo "    Ziel: $ZIEL"

    # Provider-Fallback: VOE → Vidmoly → Vidoza
    local RC=1 PROVIDER
    for PROVIDER in VOE Vidmoly Vidoza; do
        echo "  Versuche: $PROVIDER"
        aniworld "$URL" -a Download -o "$ZIEL" -l "German Dub" -p "$PROVIDER" -nm < /dev/null
        RC=$?
        [ $RC -eq 0 ] && break
        echo "  $PROVIDER fehlgeschlagen"
    done

    if [ $RC -eq 0 ]; then
        echo "==> Fertig!"
        ntfy_send "Download fertig ✓" "$LABEL" "white_check_mark"
        DOWNLOADED_SHOWS+=("$NAME")
    else
        echo "==> Alle Provider fehlgeschlagen!"
        ntfy_send "Download fehlgeschlagen ✗" "$LABEL" "x"
    fi
}

GESAMT=$#
INDEX=0
for URL in "$@"; do
    INDEX=$(( INDEX + 1 ))
    echo ""
    echo "======== [$INDEX/$GESAMT] ========"
    download_one "$URL"
done

echo ""
echo "======== Alle $GESAMT Downloads abgeschlossen ========"

# Metadaten für alle erfolgreich heruntergeladenen Serien holen
if [ ${#DOWNLOADED_SHOWS[@]} -gt 0 ] && command -v AniO &>/dev/null; then
    echo ""
    echo "======== Metadaten & Jellyfin-Struktur ========"
    declare -A SEEN
    for SHOW in "${DOWNLOADED_SHOWS[@]}"; do
        if [ -z "${SEEN[$SHOW]+x}" ]; then
            SEEN[$SHOW]=1
            echo "  Organisiere: $SHOW"
            AniO "$HOME/Videos/Animes" --show "$SHOW" --auto
        fi
    done
    ntfy_send "Metadaten fertig ✓" "${DOWNLOADED_SHOWS[*]}" "sparkles"
fi
