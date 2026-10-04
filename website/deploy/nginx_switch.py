#!/usr/bin/env python3
"""farzandimedu.uz nginx konfiguratsiyasida bosh sahifani statik saytga ulaydi.

Faqat `server_name` da domen bor 443-server bloklarida ishlaydi:
  * `location /` tanasi -> statik sayt (root, try_files, 404, kesh);
  * sayt fayllarini (masalan `= /privacy.html`) ushlab qolgan eski bloklar -> shu root'ga;
  * /api, /socket.io, /storage, /app, /child, /kirolmaysan va boshqalarga TEGILMAYDI.
Matn faqat almashtirilgan bloklar ichida o'zgaradi — qolgan hamma narsa (izohlar,
formatlash) baytma-bayt saqlanadi. Noaniq holatda hech narsa yozilmaydi (SwitchError).

Chiqish kodlari: 0 — o'zgardi, 3 — allaqachon sozlangan (o'zgarish yo'q), 2 — xato.
"""
import argparse
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

MARKER = "# parvoz-site:managed"
EXIT_CHANGED, EXIT_ERROR, EXIT_UNCHANGED = 0, 2, 3

# Saytga tegishli bo'lmagan, lekin shu domenda yashaydigan yo'llar (namunalar).
FOREIGN_PREFIXES = ("/api/", "/socket.io/", "/storage/", "/kirolmaysan/", "/app/", "/child/", "/.well-known/acme-challenge/")
FOREIGN_BASE = ("/api", "/api/health", "/kirolmaysan") + FOREIGN_PREFIXES + ("/app/main.dart.js", "/child/main.dart.js")


def foreign_probes(site_paths: Sequence[str]) -> List[str]:
    """Boshqa xizmatlar yo'llari + sayt fayllaridagi HAR BIR kengaytma o'sha xizmatlar ostida.

    Masalan sayt .png bersa, `/storage/x.png` ham tekshiriladi — `~* \\.png$` kabi
    kengaytma regex'i backend fayllarini ham ushlashini aniqlash uchun.
    """
    exts = {os.path.splitext(p)[1] for p in site_paths if os.path.splitext(p)[1]}
    return list(FOREIGN_BASE) + [f"{pre}x{ext}" for pre in FOREIGN_PREFIXES for ext in sorted(exts)]


class SwitchError(Exception):
    pass


class NoMatch(SwitchError):
    """Faylda domenning almashtiriladigan 443-bloki yo'q (o'tkazib yuborish mumkin)."""


@dataclass
class Directive:
    name: str
    args: List[str]
    start: int                      # direktiva nomining boshlanishi
    end: int                        # ';' yoki '}' dan keyingi indeks
    body_open: Optional[int] = None  # '{' indeksi
    body_close: Optional[int] = None  # mos '}' indeksi
    children: List["Directive"] = field(default_factory=list)


@dataclass
class Report:
    servers_switched: int = 0
    rewritten: List[str] = field(default_factory=list)
    changed: bool = False


# ---------------------------------------------------------------- parsing

def _tokens(text: str) -> Iterable[Tuple[str, int]]:
    """nginx tokenlari: so'zlar, '{', '}', ';'. Izoh, qo'shtirnoq va ${var} hisobga olinadi."""
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if ch.isspace():
            i += 1
        elif ch == "#":
            while i < n and text[i] != "\n":
                i += 1
        elif ch in "{};":
            yield ch, i
            i += 1
        else:
            start = i
            while i < n:
                ch = text[i]
                if ch in "\"'":  # qo'shtirnoq ichidagi { } ; # — matn
                    q, i = ch, i + 1
                    while i < n and text[i] != q:
                        i += 2 if text[i] == "\\" else 1
                    if i >= n:
                        raise SwitchError(f"yopilmagan qo'shtirnoq (pozitsiya {start})")
                    i += 1
                elif ch == "$" and i + 1 < n and text[i + 1] == "{":  # ${var} — blok emas
                    close = text.find("}", i)
                    if close < 0:
                        raise SwitchError(f"yopilmagan ${{...}} (pozitsiya {i})")
                    i = close + 1
                elif ch.isspace() or ch in "{};":
                    break
                else:
                    i += 1
            yield text[start:i], start


def parse(text: str) -> List[Directive]:
    stack: List[List[Directive]] = [[]]
    open_dirs: List[Directive] = []
    words: List[Tuple[str, int]] = []
    for tok, pos in _tokens(text):
        if tok == ";":
            if not words:
                raise SwitchError(f"bo'sh direktiva (pozitsiya {pos})")
            stack[-1].append(Directive(words[0][0], [w for w, _ in words[1:]], words[0][1], pos + 1))
            words = []
        elif tok == "{":
            if not words:
                raise SwitchError(f"nomsiz blok (pozitsiya {pos})")
            d = Directive(words[0][0], [w for w, _ in words[1:]], words[0][1], -1, body_open=pos)
            stack[-1].append(d)
            open_dirs.append(d)
            stack.append(d.children)
            words = []
        elif tok == "}":
            if words or not open_dirs:
                raise SwitchError(f"kutilmagan '}}' (pozitsiya {pos})")
            d = open_dirs.pop()
            d.body_close, d.end = pos, pos + 1
            stack.pop()
        else:
            words.append((tok, pos))
    if open_dirs or words:
        raise SwitchError("qavslar muvozanatsiz yoki direktiva ';' siz tugagan")
    return stack[0]


# ---------------------------------------------------------------- site paths

def site_paths_from_files(rel_files: Iterable[str]) -> List[str]:
    """Saytdagi fayllardan nginx'ga keladigan URL yo'llarini hosil qiladi (toza URL'lar ham)."""
    paths = {"/"}
    for rel in rel_files:
        p = "/" + rel.replace(os.sep, "/").lstrip("/")
        paths.add(p)
        if p.endswith(".html"):
            paths.add(p[:-5])
    return sorted(paths)


def site_paths_from_dir(site: Path) -> List[str]:
    files = [str(p.relative_to(site)) for p in site.rglob("*") if p.is_file()]
    return site_paths_from_files(files)


# ---------------------------------------------------------------- switching

def _unquote(arg: str) -> str:
    return arg[1:-1] if len(arg) >= 2 and arg[0] == arg[-1] and arg[0] in "\"'" else arg


def _is_target_server(d: Directive, domain: str) -> bool:
    if d.name != "server" or d.body_open is None:
        return False
    names = [a for c in d.children if c.name == "server_name" for a in c.args]
    listens = [c.args[0] for c in d.children if c.name == "listen" and c.args]
    return domain in names and any(re.search(r"(?:^|:)443$", l) for l in listens)


def _location_parts(d: Directive) -> Tuple[str, str]:
    args = [_unquote(a) for a in d.args]
    if len(args) == 2:
        return args[0], args[1]
    if len(args) == 1:
        for mod in ("^~", "~*", "~", "="):  # 'location =/x' kabi yopishgan yozuv
            if args[0].startswith(mod) and len(args[0]) > len(mod):
                return mod, args[0][len(mod):]
        return "", args[0]
    raise SwitchError(f"tushunarsiz location: {' '.join(d.args)}")


def _captures(modifier: str, pattern: str, path: str) -> bool:
    if modifier == "=":
        return path == pattern
    if modifier in ("", "^~"):
        return path.startswith(pattern)
    if modifier in ("~", "~*"):
        try:
            return re.search(pattern, path, re.I if modifier == "~*" else 0) is not None
        except re.error as e:
            raise SwitchError(f"regex location tekshirib bo'lmadi: {pattern} ({e})")
    return False  # @named


def _root_body(indent: str, root: str) -> str:
    i2, i3 = indent + "    ", indent + "        "
    return (f"{{\n{i2}{MARKER} — .github/workflows/deploy-landing.yml boshqaradi, qo'lda tahrirlamang\n"
            f"{i2}root {root};\n{i2}index index.html;\n"
            f"{i2}try_files $uri $uri.html $uri/ =404;\n{i2}error_page 404 /404.html;\n"
            f"{i2}expires 5m;\n"
            f"{i2}location /assets/img/ {{\n{i3}expires 1y;   # fayl nomida kontent-xesh bor\n{i2}}}\n{indent}}}")


def _file_body(indent: str, root: str) -> str:
    i2 = indent + "    "
    return (f"{{\n{i2}{MARKER}\n{i2}root {root};\n{i2}try_files $uri $uri.html =404;\n"
            f"{i2}error_page 404 /404.html;\n{i2}expires 5m;\n{indent}}}")


def _indent_of(text: str, pos: int) -> str:
    line_start = text.rfind("\n", 0, pos) + 1
    prefix = text[line_start:pos]
    return prefix if prefix.strip() == "" else re.match(r"\s*", prefix).group(0)


def switch_config(text: str, domain: str, root: str, site_paths: Sequence[str]) -> Tuple[str, Report]:
    tree = parse(text)
    report = Report()
    edits: List[Tuple[int, int, str]] = []  # (body_open, body_close+1, yangi tana)
    ours = [p for p in site_paths if p != "/"]
    foreign = foreign_probes(site_paths)

    servers = [d for d in tree if _is_target_server(d, domain)]
    servers += [c for d in tree if d.name == "http" for c in d.children if _is_target_server(c, domain)]
    if not servers:
        raise NoMatch(f"'{domain}' uchun 443-server bloki topilmadi")

    for srv in servers:
        locs = [c for c in srv.children if c.name == "location" and c.body_open is not None]
        roots = [l for l in locs if _location_parts(l) in (("", "/"), ("^~", "/"))]
        if not roots:
            if not locs and any(c.name == "return" for c in srv.children):
                continue  # faqat redirect qiladigan blok (masalan www -> asosiy)
            raise SwitchError(f"'{domain}' 443-blokida 'location /' topilmadi")
        if len(roots) > 1:
            raise SwitchError("bir nechta 'location /' — avtomatik hal qilinmaydi")

        for loc in locs:
            mod, pat = _location_parts(loc)
            if (mod, pat) in (("", "/"), ("^~", "/")) or mod == "@" or pat.startswith("@"):
                continue
            hits_ours = any(_captures(mod, pat, p) for p in ours)
            if not hits_ours:
                continue
            hits_foreign = any(_captures(mod, pat, p) for p in foreign)
            label = f"{mod} {pat}".strip()
            if hits_foreign:
                kind = "regex " if mod.startswith("~") else ""
                raise SwitchError(f"{kind}location '{label}' ham sayt fayllarini, ham boshqa xizmat yo'llarini "
                                  "ushlaydi — qo'lda hal qilish kerak")
            body_now = text[loc.body_open:loc.body_close + 1]
            if MARKER in body_now and f"root {root};" in body_now:
                continue
            ind = _indent_of(text, loc.start)
            edits.append((loc.body_open, loc.body_close + 1, _file_body(ind, root)))
            report.rewritten.append(label)

        main = roots[0]
        body_now = text[main.body_open:main.body_close + 1]
        new_body = _root_body(_indent_of(text, main.start), root)
        if body_now != new_body:
            edits.append((main.body_open, main.body_close + 1, new_body))
        report.servers_switched += 1

    if report.servers_switched == 0:
        raise NoMatch(f"'{domain}' uchun 'location /' li 443-server bloki topilmadi (faqat redirect)")

    out = text
    for start, end, body in sorted(edits, reverse=True):
        out = out[:start] + body + out[end:]
    report.changed = out != text
    parse(out)  # natija ham sintaktik to'g'ri bo'lishi shart
    return out, report


# ---------------------------------------------------------------- CLI

def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--conf", required=True, type=Path)
    ap.add_argument("--domain", required=True)
    ap.add_argument("--root", required=True)
    ap.add_argument("--site", required=True, type=Path, help="statik sayt papkasi (yo'llarni aniqlash uchun)")
    ap.add_argument("--allow-no-match", action="store_true", help="domen bloki bo'lmagan faylni o'tkazib yuborish")
    a = ap.parse_args(argv)
    text = a.conf.read_text(encoding="utf-8")
    try:
        out, report = switch_config(text, a.domain, a.root, site_paths_from_dir(a.site))
    except NoMatch as e:
        if a.allow_no_match:
            print(f"{a.conf}: {e} — o'tkazildi")
            return EXIT_UNCHANGED
        print(f"{a.conf}: XATO: {e}", file=sys.stderr)
        return EXIT_ERROR
    except SwitchError as e:
        print(f"{a.conf}: XATO: {e}", file=sys.stderr)
        return EXIT_ERROR
    if not report.changed:
        print(f"{a.conf}: allaqachon sozlangan (o'zgarish yo'q)")
        return EXIT_UNCHANGED
    a.conf.write_text(out, encoding="utf-8")
    extra = f"; qayta yo'naltirilgan: {', '.join(report.rewritten)}" if report.rewritten else ""
    print(f"{a.conf}: {report.servers_switched} ta server blokida 'location /' statik saytga ulandi{extra}")
    return EXIT_CHANGED


if __name__ == "__main__":
    sys.exit(main())
