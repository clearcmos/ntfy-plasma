#!/usr/bin/env bash
# Regenerate package/contents/ui/Emoji.js from ntfy's upstream emoji database.
# Run this when a new ntfy release adds shortcodes you want to support.
#
# The upstream source is github.com/binwiederhier/ntfy at
# scripts/emoji.json -- a copy of github/gemoji's emoji.json. Each entry has
# {emoji, aliases[]}; we flatten to a flat {alias: emoji} map.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/package/contents/ui/Emoji.js"
SRC_URL="https://raw.githubusercontent.com/binwiederhier/ntfy/main/scripts/emoji.json"
TMP="$(mktemp -t ntfy-emoji.XXXXXX.json)"
trap 'rm -f "$TMP"' EXIT

echo "Fetching $SRC_URL"
curl -sSfL "$SRC_URL" -o "$TMP"

count=$(jq 'length' "$TMP")
echo "Got $count emoji entries"

{
    printf '// Generated from ntfy upstream emoji database (gemoji).\n'
    printf '// Source: github.com/binwiederhier/ntfy/scripts/emoji.json (~%s aliases).\n' \
        "$(jq '[.[] | .aliases[]] | length' "$TMP")"
    printf '// Regenerate with scripts/regen-emoji.sh.\n'
    printf '.pragma library\n\n'
    printf 'const TABLE = '
    jq -c '[.[] | .emoji as $e | .aliases[] | {(.): $e}] | add' "$TMP"
    cat <<'EOF'


function lookup(name) {
    if (!name) return ""
    const key = String(name).trim().toLowerCase()
    return TABLE.hasOwnProperty(key) ? TABLE[key] : ""
}

// Render a list of ntfy tags as a single string. Mapped shortcodes become
// emoji; unknown names fall through with a #-prefix so they remain visible.
function renderTags(tags) {
    if (!tags || !tags.length) return ""
    const out = []
    for (let i = 0; i < tags.length; i++) {
        const e = lookup(tags[i])
        out.push(e || "#" + tags[i])
    }
    return out.join(" ")
}
EOF
} > "$OUT"

echo "Wrote $OUT ($(wc -c < "$OUT") bytes)"
