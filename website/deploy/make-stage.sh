#!/usr/bin/env bash
# website/public → <out>/ : site/ + manifest.sha256 + nginx_switch.py + server-deploy.sh
# deploy-landing.yml shu papkani serverga yuklaydi va server-deploy.sh ni ishga tushiradi.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:?chiqish papkasi kerak}"

rm -rf "$OUT"
mkdir -p "$OUT/site"
cp -R "$HERE/../public/." "$OUT/site/"
find "$OUT/site" -name '.DS_Store' -delete
(cd "$OUT/site" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$OUT/manifest.sha256"
cp "$HERE/nginx_switch.py" "$HERE/server-deploy.sh" "$OUT/"
echo "stage: $(wc -l < "$OUT/manifest.sha256" | tr -d ' ') fayl, $(du -sh "$OUT/site" | cut -f1)"
