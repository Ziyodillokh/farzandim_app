# Hardcode o'zbekcha UI matnlarini topadi (i18n auditi uchun).
# Ishlatish: python tool/i18n_scan.py [--json out.json]
import io, re, os, sys, json, collections

WORDS = re.compile(
    r"(o'|g'|ʻ|o`|g`|\b(yo'q|bola|vaqt|Xato|xato|kiriting|urinib|"
    r"muvaffaqiyat|saqla|Saqlash|tugadi|emas|uchun|bilan|qayta|Qayta|yuklan|"
    r"Yuklan|topilmadi|ulanmagan|kerak|mumkin|qilingan|yubor|Yubor|ochil|"
    r"tanla|Tanla|Hammasi|Kutilmoqda|Bajarilgan|Bekor|Davom|Tayyor|Yopish|"
    r"sozlama|Sozlama|ruxsat|Ruxsat|telefon|Telefon|raqam|daqiqa|soniya|"
    r"Internet|aloqasi|jadval|Jadval|Uyqu|Dars|bloklash|Bloklash)\b)")
STR_RE = re.compile(r"('(?:[^'\\]|\\.)+'|\"(?:[^\"\\]|\\.)+\")")
SKIP_LINE = re.compile(
    r"\.tr\(|debugPrint|^\s*//|^\s*///|import |part |tag:|reason:")
KEYLIKE = re.compile(r"^['\"][a-zA-Z0-9_.{}$]+['\"]$")

hits = collections.defaultdict(list)
for root, _, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f).replace(os.sep, '/')
        for i, line in enumerate(io.open(p, encoding='utf-8'), 1):
            if SKIP_LINE.search(line):
                continue
            for m in STR_RE.finditer(line):
                s = m.group(1)
                if KEYLIKE.match(s):
                    continue
                inner = s[1:-1]
                if len(inner) < 3:
                    continue
                if WORDS.search(inner):
                    hits[p].append({'line': i, 'text': inner})
                    break

total = sum(len(v) for v in hits.values())
if '--json' in sys.argv:
    out = sys.argv[sys.argv.index('--json') + 1]
    io.open(out, 'w', encoding='utf-8', newline='').write(
        json.dumps(hits, ensure_ascii=False, indent=1))
    print(f"JSON -> {out}")
print(f"JAMI: {total} ta qator, {len(hits)} ta fayl")
for p in sorted(hits, key=lambda x: -len(hits[x])):
    print(f"{len(hits[p]):3d}  {p}")
