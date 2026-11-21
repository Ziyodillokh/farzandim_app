#!/usr/bin/env bash
# Tarmoqqa bog'liq qadamni qayta urinish: `retry.sh 3 npm run build`.
# Next.js `next/font/google` build vaqtida Google Fonts'dan CSS oladi; ba'zan noto'g'ri
# javob keladi («Cannot read properties of null (reading '1')») va build yiqiladi.
set -uo pipefail
attempts="$1"; shift
for ((i = 1; i <= attempts; i++)); do
  "$@" && exit 0
  status=$?
  if ((i < attempts)); then
    echo "::warning::'$*' yiqildi (urinish $i/$attempts, kod $status) — 20 s dan keyin qayta"
    sleep 20
  fi
done
echo "::error::'$*' $attempts urinishda ham yiqildi"
exit 1
