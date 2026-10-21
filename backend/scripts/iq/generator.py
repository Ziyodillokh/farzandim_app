#!/usr/bin/env python3
"""Parvoz IQ — rasmli matritsalar banki (docs/IQ-REJA.md §6).

5 daraja: 1-daraja 48 ta o'z savoli (A 20 + B 20 + 8 zaxira), 2–5-darajalar
42 tadan (A 17 + B 17 + 8 zaxira) + oldingi darajadan 3+3 anchor = har
formada 20 savol. Jami 216 noyob savol. Deterministik (seed) — qayta yig'ish
bir xil natija beradi (migratsiya ON CONFLICT DO NOTHING bilan xavfsiz).

  python3 scripts/iq/generator.py --json prisma/data/iq/items.json [--html preview.html]
"""
import argparse
import html
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import cell_svg, grid_svg  # noqa: E402
from templates import LEVEL_POOLS  # noqa: E402

LETTERS = "ABCDEF"
SPARE = 8
ANCHORS = 3
SEED = 20261021


def own_per_form(level):
    return 20 if level == 1 else 20 - ANCHORS


def design_b(c, rng):
    """Dizayn qiyinligi (logit): murakkablik 1 → -1.6, 4.5 → +1.55. Kalibrovkagacha."""
    return round((c - 1) * 0.9 - 1.6 + rng.uniform(-0.15, 0.15), 2)


def key(cell):
    return json.dumps(cell, sort_keys=True)


def make_item(tpl, rng):
    p = tpl(rng)
    answer = p["grid"][8]
    seen, options = {key(answer)}, [answer]
    for d in p["distractors"]:
        if key(d) not in seen:
            seen.add(key(d))
            options.append(d)
        if len(options) == 6:
            break
    if len(options) < 6:
        return None
    rng.shuffle(options)
    return {
        "rule": p["rule"],
        "c": p["c"],
        "grid": p["grid"],
        "options": options,
        "answer": LETTERS[[key(o) for o in options].index(key(answer))],
    }


def build_level(level, rng, seen_grids):
    pool = LEVEL_POOLS[level]
    needed = 2 * own_per_form(level) + SPARE
    items, i = [], 0
    while len(items) < needed:
        tpl = pool[i % len(pool)]
        i += 1
        for _ in range(50):
            item = make_item(tpl, rng)
            if item and key(item["grid"]) not in seen_grids:
                seen_grids.add(key(item["grid"]))
                item["b"] = design_b(item["c"], rng)
                items.append(item)
                break
        else:
            raise RuntimeError(f"L{level}: shablon {i % len(pool)} noyob savol bermadi")
    items.sort(key=lambda it: it["b"])
    n = len(items)
    spare_idx = {min(n - 1, int((k + 0.5) * n / SPARE)) for k in range(SPARE)}
    toggle = 0
    for idx, it in enumerate(items):
        it["level"] = level
        it["externalId"] = f"iq-L{level}-{idx + 1:03d}"
        if idx in spare_idx:
            it["forms"] = []
        else:
            it["forms"] = [f"L{level}{'AB'[toggle]}"]
            toggle ^= 1
    return items


def add_anchors(levels):
    for level in range(2, 6):
        for form in "AB":
            prev = [it for it in levels[level - 1] if f"L{level - 1}{form}" in it["forms"]]
            for it in sorted(prev, key=lambda x: x["b"])[-ANCHORS:]:
                it["forms"].append(f"L{level}{form}")


def to_record(it):
    return {
        "externalId": it["externalId"],
        "level": it["level"],
        "forms": it["forms"],
        "rule": it["rule"],
        "b": it["b"],
        "answer": it["answer"],
        "gridSvg": grid_svg(it["grid"]),
        "options": [{"key": LETTERS[i], "svg": cell_svg(o)} for i, o in enumerate(it["options"])],
    }


def check(records):
    forms = {}
    for r in records:
        for f in r["forms"]:
            forms.setdefault(f, []).append(r)
    for f in sorted(forms):
        assert len(forms[f]) == 20, f"{f}: {len(forms[f])} savol"
    print(f"{len(records)} savol; formalar: " + ", ".join(f"{f}={len(v)}" for f, v in sorted(forms.items())))


def write_html(records, path):
    cards = []
    for r in records:
        if not r["forms"] or not r["forms"][0].endswith("A") or r["forms"][0][1] != str(r["level"]):
            continue
        opts = "".join(f'<div class="o">{o["svg"]}<b>{o["key"]}</b></div>' for o in r["options"])
        cards.append(f'<section><h3>{r["externalId"]} · {html.escape(r["rule"])} · b={r["b"]} · javob {r["answer"]}</h3>'
                     f'<div class="g">{r["gridSvg"]}</div><div class="os">{opts}</div></section>')
    style = ("body{font-family:sans-serif;background:#F4F7FD;margin:0;padding:16px}section{background:#fff;border-radius:16px;"
             "padding:16px;margin:0 auto 16px;max-width:720px}.g{max-width:300px;margin:auto}svg{width:100%;height:auto}"
             ".os{display:grid;grid-template-columns:repeat(6,1fr);gap:8px;margin-top:12px}.o{text-align:center}")
    with open(path, "w") as f:
        f.write(f'<!doctype html><meta charset="utf-8"><title>IQ bank preview</title><style>{style}</style>{"".join(cards)}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--html")
    args = ap.parse_args()
    rng, seen, levels = random.Random(SEED), set(), {}
    for level in range(1, 6):
        levels[level] = build_level(level, rng, seen)
    add_anchors(levels)
    records = [to_record(it) for level in range(1, 6) for it in levels[level]]
    check(records)
    os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
    with open(args.json, "w") as f:
        json.dump(records, f, ensure_ascii=False, separators=(",", ":"))
    if args.html:
        write_html(records, args.html)


if __name__ == "__main__":
    main()
