# Agent bucket'laridagi yangi kalitlarni 3 til JSON'iga birlashtiradi,
# so'ng lib'dagi BARCHA literal .tr() kalitlari 3 tilda ham mavjudligini
# tekshiradi. Ishlatish: python tool/i18n_merge.py
import collections
import glob
import io
import json
import os
import re
import sys

LANGS = ('uz', 'ru', 'en')

def nested_get(d, dotted):
    cur = d
    for part in dotted.split('.'):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur

def nested_set(d, dotted, value):
    parts = dotted.split('.')
    cur = d
    for p in parts[:-1]:
        cur = cur.setdefault(p, collections.OrderedDict())
        assert isinstance(cur, dict), f"{dotted}: {p} guruh emas!"
    assert parts[-1] not in cur, f"{dotted} allaqachon bor!"
    cur[parts[-1]] = value

# 1) Bucket'larni yig'ish + kolliziya tekshiruvi
merged = {}
for path in sorted(glob.glob('tool/i18n_keys_b*.json')):
    data = json.load(io.open(path, encoding='utf-8'))
    for key, vals in data.items():
        assert set(vals) >= set(LANGS), f"{path}:{key} til yetishmaydi"
        if key in merged:
            assert merged[key] == {l: vals[l] for l in LANGS}, \
                f"KOLLIZIYA: {key} ikki bucket'da har xil!"
            continue
        merged[key] = {l: vals[l] for l in LANGS}
print(f"Bucket'lardan jami: {len(merged)} kalit")

# 2) Har tilga merge (mavjud kalit: qiymat bir xil bo'lsa skip, farqli -> xato)
for lang in LANGS:
    p = f'assets/translations/{lang}.json'
    d = json.load(io.open(p, encoding='utf-8'),
                  object_pairs_hook=collections.OrderedDict)
    added = 0
    for key, vals in merged.items():
        existing = nested_get(d, key)
        if existing is not None:
            assert existing == vals[lang], \
                f"{lang}:{key} mavjud lekin qiymati farqli!"
            continue
        nested_set(d, key, vals[lang])
        added += 1
    io.open(p, 'w', encoding='utf-8', newline='').write(
        json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(f"{lang}.json: +{added}")

# 3) Verifikatsiya: lib'dagi barcha literal .tr() kalitlari 3 tilda bormi
KEY_RE = re.compile(r"'([a-zA-Z0-9_.]+)'\s*\.\s*tr\(")
langs_data = {
    l: json.load(io.open(f'assets/translations/{l}.json', encoding='utf-8'))
    for l in LANGS
}
missing = []
for root, _, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f)
        raw = io.open(p, encoding='utf-8').read()
        # Izoh qatorlarini olib tashlash (doc-misollardagi .tr() false-positive)
        text = '\n'.join(
            line for line in raw.split('\n')
            if not line.lstrip().startswith('//')
        )
        for m in KEY_RE.finditer(text):
            key = m.group(1)
            if '.' not in key:
                continue
            for l in LANGS:
                v = nested_get(langs_data[l], key)
                if not isinstance(v, str):
                    missing.append(f"{l}: {key}  ({p})")
if missing:
    print(f"\nYO'Q KALITLAR ({len(missing)}):")
    for x in sorted(set(missing)):
        print(' ', x)
    sys.exit(1)
print('VERIFIKATSIYA OK: barcha literal .tr() kalitlari 3 tilda mavjud')
