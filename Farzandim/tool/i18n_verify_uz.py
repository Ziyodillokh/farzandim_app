# uz bayt-identiklik tekshiruvi: har yangi kalitning uz qiymati (interpolatsiyasiz
# bo'lsa) HEAD'dagi o'zgartirilgan .dart fayllarning birida aynan mavjud
# bo'lishi kerak. Interpolatsiyali ({x}) kalitlar qo'lda ko'riladi.
import glob
import io
import json
import subprocess

changed = subprocess.run(
    ['git', 'diff', '--name-only', 'HEAD', '--', 'lib'],
    capture_output=True, text=True,
).stdout.split()
old_blobs = []
for f in changed:
    r = subprocess.run(['git', 'show', f'HEAD:{f}'], capture_output=True)
    if r.returncode == 0:
        old_blobs.append(r.stdout.decode('utf-8', errors='replace'))
corpus = '\n'.join(old_blobs)
print(f"O'zgargan dart fayllar: {len(changed)}")

plain_ok = plain_miss = interp = 0
misses = []
for path in sorted(glob.glob('tool/i18n_keys_b*.json')):
    for key, vals in json.load(io.open(path, encoding='utf-8')).items():
        uz = vals['uz']
        if '{' in uz:
            interp += 1
            continue
        # Dart literal ichida $ belgisi \$ bo'lib yozilgan bo'lishi mumkin
        if uz in corpus or uz.replace('$', r'\$') in corpus:
            plain_ok += 1
        else:
            plain_miss += 1
            misses.append(f'{key}: {uz[:60]!r}')
print(f'Oddiy kalitlar: {plain_ok} ASLI BILAN AYNAN, {plain_miss} topilmadi')
print(f'Interpolatsiyali (qo`lda ko`riladi): {interp}')
for m in misses:
    print('  MISS', m)

# Dinamik (index bilan qurilgan) kalit oilalari mavjudligini tekshirish
LANGS = {
    l: json.load(io.open(f'assets/translations/{l}.json', encoding='utf-8'))
    for l in ('uz', 'ru', 'en')
}

def get(d, dotted):
    cur = d
    for p in dotted.split('.'):
        if not isinstance(cur, dict) or p not in cur:
            return None
        cur = cur[p]
    return cur

fams = [f'dashboard.chart.weekdays.{i}' for i in range(1, 8)]
fams += [f'weeklyReport.weekdays.{i}' for i in range(1, 8)]
bad = [
    f'{l}:{k}' for k in fams for l in LANGS if not isinstance(get(LANGS[l], k), str)
]
print('Dinamik kalitlar:', 'OK' if not bad else bad)
