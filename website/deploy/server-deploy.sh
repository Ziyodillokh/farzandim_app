#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Parvoz sayti → farzandimedu.uz (serverda ROOT sifatida ishlaydi).
#
#   sudo bash server-deploy.sh <stage_dir>
#
# <stage_dir>: site/ (statik fayllar), manifest.sha256 (site/ fayllari xeshi),
#              nginx_switch.py. Chaqiruvchi: .github/workflows/deploy-landing.yml
#
# 1. Release: /var/www/parvoz-releases/<vaqt>/ ← site/; /var/www/parvoz-site
#    symlink'i atomik almashtiriladi (nginx root shu symlink).
# 2. nginx: farzandimedu.uz 443-blokida `location /` statik saytga ulanadi
#    (faqat birinchi marta; keyingi deploy'larda konfig o'zgarmaydi).
#    O'zgartirishdan oldin zaxira: /var/backups/parvoz-nginx/<vaqt>/.
# 3. Tekshiruv (127.0.0.1 orqali): har bir fayl xeshi, 404 sahifa, va boshqa
#    xizmatlar (/api, /socket.io, /app, /child, admin /kirolmaysan, /storage,
#    /ota-ona, /bola) holat kodlari o'zgarishdan OLDINGI bilan bir xil.
# 4. Biror qadam yiqilsa yoki deploy to'xtatilsa (TERM/INT) — nginx konfig va
#    symlink oldingi holatiga qaytadi. SSH uzilsa (HUP/PIPE) skript to'xtamaydi:
#    o'zi tekshirib, kerak bo'lsa o'zi qaytaradi. To'liq log: $LOGFILE.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

STAGE="${1:?stage papka kerak}"
DOMAIN="farzandimedu.uz"
LIVE="/var/www/parvoz-site"
RELEASES="/var/www/parvoz-releases"
KEEP_RELEASES=5
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/parvoz-nginx/$TS"
# Saytga tegishli bo'lmagan, lekin shu domendagi xizmatlar — holati o'zgarmasligi shart.
GUARDED=("/api" "/api/health" "/socket.io/?EIO=4&transport=polling" "/app/" "/child/" "/kirolmaysan" "/storage/"
         "/ota-ona" "/bola")  # do'kon qisqa havolalari (302) — landingfarzandim/parvoz-store-links.nginx
LOGFILE="/var/log/parvoz-deploy.log"

NGINX_FILES=()
NGINX_TOUCHED=0   # konfig fayllariga yozish boshlandimi (rollback uchun)
NGINX_CHANGED=0   # haqiqatan o'zgardimi (reload uchun)
PREV=""
ROLLED_BACK=0

log() {  # SSH uzilgan bo'lsa ham log faylga yoziladi; stdout xatosi skriptni to'xtatmaydi
  printf '%s [parvoz-deploy] %s\n' "$(date '+%F %T')" "$*" >> "$LOGFILE" 2>/dev/null || true
  printf '[parvoz-deploy] %s\n' "$*" 2>/dev/null || true
}

status_of() {  # $1 = yo'l → HTTP status (server ichidan, haqiqiy nginx orqali)
  local s
  s="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 \
    --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN$1" || true)"
  echo "${s:-000}"
}

stable_status() {  # vaqtinchalik tebranishga 3 urinish
  local s i
  for i in 1 2 3; do s="$(status_of "$1")"; [ "$s" != "000" ] && break; sleep 2; done
  echo "$s"
}

guarded_match_before() {  # himoyalangan xizmatlar oldingi holatdami?
  local p
  for p in "${GUARDED[@]}"; do [ "$(status_of "$p")" = "${BEFORE[$p]}" ] || return 1; done
}

wait_until() {  # $1 = tekshiruv funksiyasi; reload asinxron — 20s gacha kutamiz
  local i
  for i in $(seq 1 20); do "$1" && return 0; sleep 1; done
  return 1
}

root_is_new_site() {  # bosh sahifa yangi release'dan berilyaptimi?
  [ "$({ curl -sk --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/" || true; } | sha256sum | cut -d' ' -f1)" = "$INDEX_SUM" ]
}

rollback() {
  [ "$ROLLED_BACK" = 1 ] && return 0
  ROLLED_BACK=1
  set +e            # qaytarish o'zi yarim yo'lda to'xtab qolmasin
  trap - ERR
  log "XATO — oldingi holatga qaytarilmoqda"
  if [ "$NGINX_TOUCHED" = 1 ]; then
    local f
    for f in "${NGINX_FILES[@]}"; do cp -f "$BACKUP/$(echo "$f" | tr '/' '_')" "$f"; done
    if nginx -t 2>/dev/null; then
      systemctl reload nginx
      if wait_until guarded_match_before; then log "nginx konfig tiklandi, xizmatlar oldingi holatda"; else log "!!! konfig tiklandi, lekin xizmatlar holati farq qilyapti — qo'lda tekshiring"; fi
    else
      log "!!! nginx -t tiklangan konfigda ham yiqildi — qo'lda tekshiring: $BACKUP"
    fi
  fi
  if [ -n "$PREV" ]; then
    ln -sfn "$PREV" "$LIVE.tmp" && mv -Tf "$LIVE.tmp" "$LIVE"; log "symlink → $PREV"
  else
    rm -f "$LIVE"  # birinchi deploy edi — eski konfig bu symlink'ni ishlatmaydi
  fi
}
trap 'rollback; exit 1' ERR TERM INT
trap '' HUP PIPE  # SSH uzilishi deploy'ni yarim yo'lda qoldirmasin

# ── 0. Oldindan tekshiruv (hech narsa o'zgartirilmaydi) ──────────────────────
for cmd in python3 nginx curl rsync sha256sum systemctl; do
  command -v "$cmd" >/dev/null || { log "kerakli buyruq yo'q: $cmd"; exit 1; }
done
for f in site/index.html manifest.sha256 nginx_switch.py; do
  if [ ! -f "$STAGE/$f" ]; then log "stage to'liq emas: $STAGE/$f yo'q"; exit 1; fi
done
if [ -e "$LIVE" ] && [ ! -L "$LIVE" ]; then log "$LIVE symlink emas (kutilmagan) — to'xtatildi"; exit 1; fi
if ! nginx -t 2>/dev/null; then log "nginx -t hozirgi konfigda ham yiqilmoqda — avval uni tuzating"; exit 1; fi

INDEX_SUM="$(awk '$2=="./index.html"{print $1}' "$STAGE/manifest.sha256")"
[ -n "$INDEX_SUM" ] || { log "manifestda index.html yo'q"; exit 1; }

declare -A BEFORE
for p in "${GUARDED[@]}"; do BEFORE["$p"]="$(stable_status "$p")"; done
log "boshqa xizmatlar holati (oldin): $(for p in "${GUARDED[@]}"; do printf '%s=%s ' "${p%%\?*}" "${BEFORE[$p]}"; done)"

# ── 1. Release + symlink ─────────────────────────────────────────────────────
REL="$RELEASES/$TS"
mkdir -p "$REL"
rsync -a --delete "$STAGE/site/" "$REL/"
chown -R root:root "$REL"
chmod -R u=rwX,go=rX "$REL"
if [ -L "$LIVE" ]; then PREV="$(readlink -f "$LIVE")"; fi
ln -sfn "$REL" "$LIVE.tmp" && mv -Tf "$LIVE.tmp" "$LIVE"
log "release: $REL"

# ── 2. nginx (faqat kerak bo'lsa) ────────────────────────────────────────────
mapfile -t NGINX_FILES < <(
  nginx -T 2>/dev/null | sed -n 's/^# configuration file \(.*\):$/\1/p' | sort -u |
  while read -r f; do grep -qE "server_name[^;]*[[:space:]]$DOMAIN([[:space:]]|;)" "$f" 2>/dev/null && echo "$f"; done
)
[ "${#NGINX_FILES[@]}" -gt 0 ] || { log "$DOMAIN server bloki bo'lgan nginx fayli topilmadi"; false; }
mkdir -p "$BACKUP"
for f in "${NGINX_FILES[@]}"; do cp -f "$f" "$BACKUP/$(echo "$f" | tr '/' '_')"; done
NGINX_TOUCHED=1  # shu nuqtadan boshlab rollback konfiglarni zaxiradan tiklaydi

for f in "${NGINX_FILES[@]}"; do
  rc=0  # `|| rc=$?` — kod 3 ("o'zgarish yo'q") ERR trap'ni ishga tushirmasligi uchun
  python3 "$STAGE/nginx_switch.py" --conf "$f" --domain "$DOMAIN" --root "$LIVE" --site "$REL" --allow-no-match || rc=$?
  case "$rc" in
    0) NGINX_CHANGED=1 ;;
    3) ;;
    *) log "nginx_switch xato bilan tugadi ($f)"; false ;;
  esac
done

if [ "$NGINX_CHANGED" = 1 ]; then
  nginx -t
  systemctl reload nginx
  wait_until root_is_new_site || { log "reload'dan keyin bosh sahifa 20s ichida yangilanmadi"; false; }
  log "nginx qayta yuklandi (zaxira: $BACKUP)"
else
  NGINX_TOUCHED=0
  rm -rf "$BACKUP"
  log "nginx allaqachon sozlangan — konfig o'zgarmadi"
fi

# ── 3. Tekshiruv ─────────────────────────────────────────────────────────────
fail=0
checked=0
while read -r sum rel; do
  rel="${rel#./}"
  url="/$rel"; [ "$rel" = "index.html" ] && url="/"
  got="$({ curl -sk --max-time 15 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN$url" || true; } | sha256sum | cut -d' ' -f1)"
  if [ "$got" != "$sum" ]; then log "MOS EMAS: $url"; fail=1; fi
  checked=$((checked + 1))
done < "$STAGE/manifest.sha256"
log "fayl xeshlari: $checked ta tekshirildi"

[ "$(status_of /privacy)" = "200" ] || { log "toza URL /privacy ishlamadi"; fail=1; }
[ "$(status_of /__parvoz_404_check)" = "404" ] || { log "404 sahifa ishlamadi"; fail=1; }

for p in "${GUARDED[@]}"; do
  now="$(stable_status "$p")"
  if [ "$now" != "${BEFORE[$p]}" ]; then log "XIZMAT O'ZGARDI: ${p%%\?*} ${BEFORE[$p]} → $now"; fail=1; fi
done

if [ "$fail" != 0 ]; then rollback; exit 1; fi
trap - ERR TERM INT

# ── 4. Eski release'larni tozalash ───────────────────────────────────────────
ls -1dt "$RELEASES"/*/ 2>/dev/null | tail -n +$((KEEP_RELEASES + 1)) | while read -r old; do
  [ "$(readlink -f "$old")" = "$(readlink -f "$LIVE")" ] || rm -rf "$old"
done
log "TAYYOR: https://$DOMAIN → $REL"
