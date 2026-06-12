# Izoh-sweep verifikatori: o'zgargan .dart fayllarda KOD (izohlardan
# tashqari hamma narsa) HEAD bilan aynan bir xilligini tekshiradi.
# Ishlatish: python tool/comments_only_check.py [base_ref]
import io
import subprocess
import sys

BASE = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'


def strip_comments(src):
    """Dart koddan izohlarni olib tashlab, bo'sh joylarni normallashtiradi.
    Stringlar (oddiy/raw/triple) saqlanadi — ular ichidagi // izoh emas.
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        # raw string?
        raw = c == 'r' and nxt in ('"', "'")
        if raw:
            out.append(c)
            i += 1
            c = src[i]
            nxt = src[i + 1] if i + 1 < n else ''
        if c in ('"', "'"):
            triple = src[i:i + 3] in ('"""', "'''")
            quote = src[i:i + 3] if triple else c
            out.append(quote)
            i += len(quote)
            while i < n:
                if not raw and src[i] == '\\':
                    out.append(src[i:i + 2])
                    i += 2
                    continue
                if src.startswith(quote, i):
                    out.append(quote)
                    i += len(quote)
                    break
                out.append(src[i])
                i += 1
            continue
        if c == '/' and nxt == '/':
            while i < n and src[i] != '\n':
                i += 1
            continue
        if c == '/' and nxt == '*':
            depth = 1
            i += 2
            while i < n and depth:
                if src.startswith('/*', i):
                    depth += 1
                    i += 2
                elif src.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            continue
        out.append(c)
        i += 1
    # bo'sh joylarni normallashtirish (izoh o'chirilganda satrlar siljiydi)
    return ' '.join(''.join(out).split())


changed = subprocess.run(
    ['git', 'diff', '--name-only', BASE, '--', '.'],
    capture_output=True, text=True,
).stdout.split('\n')
dart_files = [f for f in changed if f.endswith('.dart')]

bad = []
for f in dart_files:
    old = subprocess.run(['git', 'show', f'{BASE}:./{f}'.replace('./Farzandim/', './')],
                         capture_output=True)
    if old.returncode != 0:
        # repo-root nisbiy yo'l bilan urinish
        old = subprocess.run(['git', 'show', f'{BASE}:{f}'], capture_output=True)
    if old.returncode != 0:
        bad.append((f, 'HEAD versiyasi topilmadi (yangi fayl?)'))
        continue
    local = f[len('Farzandim/'):] if f.startswith('Farzandim/') else f
    try:
        new_src = io.open(local, encoding='utf-8').read()
    except FileNotFoundError:
        bad.append((f, "o'chirilgan fayl"))
        continue
    if strip_comments(old.stdout.decode('utf-8')) != strip_comments(new_src):
        bad.append((f, 'KOD O\'ZGARGAN!'))

print(f"Tekshirildi: {len(dart_files)} ta .dart fayl (baza: {BASE})")
if bad:
    for f, why in bad:
        print(f'  XATO: {f} — {why}')
    sys.exit(1)
print('OK: barcha o\'zgarishlar faqat izohlarda')
