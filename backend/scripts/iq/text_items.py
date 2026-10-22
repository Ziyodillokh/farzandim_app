#!/usr/bin/env python3
"""Parvoz IQ — aralash formalar (C/D) uchun matnli savollar (docs/IQ-REJA.md §8).

Har daraja: 10 ta sonli qator (generatsiya), 7 ta so'z munosabati va 7 ta
mantiq savoli (text_content.py, qo'lda yozilgan). Aralash forma = 10 rasmli
(A/B formadan, items.json o'zgarmaydi) + 4 son + 3 so'z + 3 mantiq = 20.
Deterministik (seed) — qayta yig'ish bir xil natija beradi.

  python3 scripts/iq/text_items.py --items prisma/data/iq/items.json \
      --out prisma/data/iq/text_items.json --forms prisma/data/iq/mixed_forms.json
"""
import argparse
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from text_content import LOGIC, VERBAL, T  # noqa: E402

SEED = 20261022
LETTERS = "ABCDEF"
PER_FORM = {"NUMERIC": 4, "VERBAL": 3, "LOGIC": 3}
FIGURAL_PER_FORM = 10
PREFIX = {"NUMERIC": "N", "VERBAL": "V", "LOGIC": "G"}

NEXT = T("Qatorni davom ettiring:\n", "Продолжите ряд:\n", "Continue the sequence:\n")
GAP = T("Yetishmayotgan sonni toping:\n", "Найдите пропущенное число:\n", "Find the missing number:\n")


def design_b(c, rng):
    """generator.py bilan bir xil shkala: murakkablik 1 → -1.6, 4.5 → +1.55."""
    return round((c - 1) * 0.9 - 1.6 + rng.uniform(-0.15, 0.15), 2)


# ── Sonli qatorlar ──────────────────────────────────────────────────
# Har qoida: (rng) → (hadlar, xato-qoida javoblari). Hadlar to'liq; yashirin
# had `hide` bilan tanlanadi (oxirgi yoki o'rtadagi).

def arith(step, lo=1, hi=20, n=6):
    def f(rng):
        a = rng.randint(lo, hi) + (abs(step) * n if step < 0 else 0)
        terms = [a + step * i for i in range(n)]
        return terms, [terms[-1] + step + 1, terms[-1] - step, terms[-2]]
    return f


def geom(ratio, lo=1, hi=3, n=6):
    def f(rng):
        a = rng.randint(lo, hi)
        terms = [a * ratio ** i for i in range(n)]
        d = terms[-2] - terms[-3]
        return terms, [terms[-2] + 2 * d, terms[-2] * (ratio + 1), terms[-2] + terms[-3]]
    return f


def steps(pattern, lo=1, hi=12, n=7):
    """Ayirmalar takrorlanuvchi naqsh: +a, +b, ... (yoki ×/− aralash)."""
    def f(rng):
        terms = [rng.randint(lo, hi)]
        for i in range(n - 1):
            op, k = pattern[i % len(pattern)]
            prev = terms[-1]
            terms.append(prev + k if op == "+" else prev - k if op == "-" else prev * k)
        last = terms[-2]
        alt = [(o, k) for o, k in pattern if (o, k) != pattern[(n - 2) % len(pattern)]][0]
        wrong = last + alt[1] if alt[0] == "+" else last - alt[1] if alt[0] == "-" else last * alt[1]
        return terms, [wrong, terms[-1] + 1, terms[-1] - 2]
    return f


def growing(d0, inc=1, lo=1, hi=10, n=6):
    """Ayirmalar o'sadi: d0, d0+inc, d0+2·inc, ..."""
    def f(rng):
        terms = [rng.randint(lo, hi)]
        for i in range(n - 1):
            terms.append(terms[-1] + d0 + inc * i)
        d = terms[-2] - terms[-3]
        return terms, [terms[-2] + d, terms[-2] + d + 2 * inc, terms[-1] + inc]
    return f


def doubling_diff(lo=1, hi=9, n=6):
    def f(rng):
        terms, d = [rng.randint(lo, hi)], rng.choice([1, 2, 3])
        for _ in range(n - 1):
            terms.append(terms[-1] + d)
            d *= 2
        last_d = terms[-2] - terms[-3]
        return terms, [terms[-2] + last_d, terms[-2] + last_d + last_d // 2, terms[-1] + 2]
    return f


def fib(n=7, k=2):
    def f(rng):
        terms = [rng.randint(1, 4), rng.randint(2, 6)] + ([rng.randint(3, 7)] if k == 3 else [])
        while len(terms) < n:
            terms.append(sum(terms[-k:]))
        d = terms[-2] - terms[-3]
        return terms, [terms[-2] + d, terms[-2] * 2, terms[-1] + terms[-2] - terms[-3] - 1]
    return f


def power(p, shift=0, start=(1, 3), n=6, desc=False):
    def f(rng):
        s = rng.randint(*start)
        terms = [(s + i) ** p + shift for i in range(n)]
        if desc:
            terms = terms[::-1]
        d = terms[-2] - terms[-3]
        return terms, [terms[-2] + d, terms[-1] + 1, terms[-1] - 1]
    return f


def product(n=6):
    def f(rng):
        s = rng.randint(1, 3)
        terms = [(s + i) * (s + i + 1) for i in range(n)]
        d = terms[-2] - terms[-3]
        return terms, [terms[-2] + d, terms[-1] + 2, (s + n - 1) ** 2]
    return f


def mul_add(m, add, lo=1, hi=4, n=6):
    def f(rng):
        terms = [rng.randint(lo, hi)]
        while len(terms) < n:
            terms.append(terms[-1] * m + add)
        return terms, [terms[-2] * m, terms[-2] * m + 2 * add, terms[-1] + 1]
    return f


def interleave(a_step, b_step, a_mul=False, n=8):
    """Ikki qator navbatma-navbat: toq o'rinlar va juft o'rinlar alohida qoida."""
    def f(rng):
        a, b = rng.randint(1, 5), rng.randint(15, 30)
        terms = []
        for i in range(n):
            if i % 2 == 0:
                terms.append(a)
                a = a * a_step if a_mul else a + a_step
            else:
                terms.append(b)
                b += b_step
        return terms, [terms[-2] + b_step, terms[-2] + a_step, terms[-1] + 1]
    return f


def second_order(d0, dd, lo=1, hi=8, n=6):
    """Ayirmalar arifmetik qator: d0, d0+dd, d0+2dd, ..."""
    return growing(d0, dd, lo, hi, n)


def square_diffs(n=6):
    def f(rng):
        terms = [rng.randint(1, 6)]
        for i in range(1, n):
            terms.append(terms[-1] + i * i)
        return terms, [terms[-2] + (n - 2) ** 2, terms[-2] + (n - 1) * 2, terms[-1] + 1]
    return f


def factorial_like(n=6):
    def f(rng):
        terms = [rng.randint(1, 2)]
        for i in range(1, n):
            terms.append(terms[-1] * i)
        return terms, [terms[-2] * (n - 2), terms[-2] + terms[-3], terms[-1] - 1]
    return f


# (rule nomi, murakkablik c, qoida, yashirin had: -1 oxirgi, aks holda indeks)
NUMERIC = {
    1: [
        ("arith+2", 1.0, arith(2), -1),
        ("arith+5", 1.1, arith(5), -1),
        ("arith+4", 1.2, arith(4, 2, 12), -1),
        ("arith-3", 1.4, arith(-3, 5, 15), -1),
        ("arith+3 gap", 1.6, arith(3), 2),
        ("steps+1+3", 1.7, steps([("+", 1), ("+", 3)]), -1),
        ("geom×2", 1.8, geom(2), -1),
        ("growing+1", 2.0, growing(1), -1),
        ("steps+3-1", 2.0, steps([("+", 3), ("-", 1)], 5, 12), -1),
        ("geom×2 gap", 2.2, geom(2, 1, 2), 3),
    ],
    2: [
        ("arith+6", 1.3, arith(6), -1),
        ("arith-4", 1.5, arith(-4, 3, 20), -1),
        ("geom×2", 1.8, geom(2, 2, 5), -1),
        ("steps+3+5", 1.9, steps([("+", 3), ("+", 5)]), -1),
        ("growing+1", 2.0, growing(2), -1),
        ("steps+4-2", 2.1, steps([("+", 4), ("-", 2)], 3, 10), -1),
        ("geom×3", 2.2, geom(3, 1, 2), -1),
        ("interleave+2/-1", 2.6, interleave(2, -1), -1),
        ("triangular gap", 2.6, growing(2, 1, 1, 1), 3),
        ("fib", 2.7, fib(), -1),
    ],
    3: [
        ("arith+7", 1.8, arith(7, 10, 40), -1),
        ("geom×3", 2.2, geom(3, 1, 3), -1),
        ("growing+2", 2.4, growing(2, 1, 1, 10, 7), -1),
        ("fib", 2.7, fib(), -1),
        ("doubling-diff", 2.8, doubling_diff(), -1),
        ("squares", 2.8, power(2, 0, (1, 4)), -1),
        ("interleave+3/-2", 2.9, interleave(3, -2), -1),
        ("steps×2-1", 3.0, steps([("*", 2), ("-", 1)], 2, 5), -1),
        ("mul×2+1", 3.1, mul_add(2, 1), -1),
        ("second-order 2/3", 3.2, second_order(2, 3), -1),
    ],
    4: [
        ("geom×3 gap", 2.6, geom(3, 1, 2), 2),
        ("doubling-diff", 2.8, doubling_diff(3, 15), -1),
        ("fib", 2.9, fib(8), -1),
        ("squares+1", 3.0, power(2, 1, (2, 5)), -1),
        ("second-order 3/2", 3.2, second_order(3, 2, 2, 9), -1),
        ("product n(n+1)", 3.3, product(), -1),
        ("mul×3-1", 3.3, mul_add(3, -1, 1, 3), -1),
        ("steps×2+3", 3.4, steps([("*", 2), ("+", 3)], 1, 4), -1),
        ("cubes", 3.5, power(3, 0, (1, 2)), -1),
        ("interleave×2/+5", 3.6, interleave(2, 5, True), -1),
    ],
    5: [
        ("squares desc", 3.0, power(2, 0, (3, 6), 6, True), -1),
        ("doubling-diff gap", 3.4, doubling_diff(2, 12, 7), 4),
        ("product gap", 3.5, product(7), 3),
        ("mul×2-3", 3.6, mul_add(2, -3, 4, 6), -1),
        ("cubes+1", 3.7, power(3, 1, (1, 2)), -1),
        ("steps×3-2", 3.7, steps([("*", 3), ("-", 2)], 2, 3), -1),
        ("factorial-like", 3.8, factorial_like(7), -1),
        ("square-diffs", 3.9, square_diffs(7), -1),
        ("tribonacci", 4.0, fib(8, 3), -1),
        ("interleave×3/-4", 4.0, interleave(3, -4, True), -1),
    ],
}


def numeric_item(rule, c, make, hide, rng):
    for _ in range(50):
        terms, wrong = make(rng)
        if min(terms) < 0 or max(terms) > 9999:
            continue
        idx = len(terms) - 1 if hide == -1 else hide
        answer = terms[idx]
        shown = [("?" if i == idx else str(t)) for i, t in enumerate(terms)]
        if hide != -1:
            # O'rtadagi had — atrofidagi "xato qoida" variantlari.
            wrong = [terms[idx - 1] + (terms[idx - 1] - terms[idx - 2]), terms[idx + 1] - 1, (terms[idx - 1] + terms[idx + 1]) // 2 + 1]
        pool = [w for w in dict.fromkeys(wrong + [answer + d for d in (1, -1, 2, -2, 3, 10, -10, 5)]) if w != answer and w > 0]
        if len(pool) < 5:
            continue
        options = [answer] + pool[:3] + rng.sample(pool[3:], 2)
        rng.shuffle(options)
        series = ", ".join(shown)
        lead = NEXT if hide == -1 else GAP
        return {
            "kind": "NUMERIC",
            "rule": rule,
            "c": c,
            "stem": {lang: lead[lang] + series for lang in ("uz", "ru", "en")},
            "options": [str(o) for o in options],
            "answer": LETTERS[options.index(answer)],
        }
    raise RuntimeError(f"{rule}: qator chiqmadi")


def text_item(kind, q, rng):
    opts = list(range(len(q["options"])))
    rng.shuffle(opts)
    return {
        "kind": kind,
        "rule": q["rule"],
        "c": q["c"],
        "stem": q["stem"],
        "options": [q["options"][i] for i in opts],
        "answer": LETTERS[opts.index(q["answer"])],
    }


def assign_forms(items, per_form, level):
    """Murakkablik bo'yicha juftlab C/D ga (navbat bilan), qolgani zaxira."""
    items.sort(key=lambda it: it["c"])
    spare_n = len(items) - 2 * per_form
    spare = {min(len(items) - 1, int((k + 0.5) * len(items) / spare_n)) for k in range(spare_n)} if spare_n else set()
    used = [i for i in range(len(items)) if i not in spare]
    for i in spare:
        items[i]["forms"] = []
    for p in range(0, len(used), 2):
        first, second = ("C", "D") if (p // 2) % 2 == 0 else ("D", "C")
        items[used[p]]["forms"] = [f"L{level}{first}"]
        items[used[p + 1]]["forms"] = [f"L{level}{second}"]


def to_record(it, level, idx, rng):
    options = it["options"]
    texts = [o if isinstance(o, dict) else {"uz": o, "ru": o, "en": o} for o in options]
    return {
        "externalId": f"iq-L{level}-{PREFIX[it['kind']]}{idx + 1:02d}",
        "level": level,
        "kind": it["kind"],
        "forms": it["forms"],
        "rule": it["rule"],
        "b": design_b(it["c"], rng),
        "answer": it["answer"],
        "stem": it["stem"],
        "options": [{"key": LETTERS[i], "text": t} for i, t in enumerate(texts)],
    }


def figural_forms(bank):
    """Har daraja: A formadan 10 ta → C, B formadan 10 ta → D (b bo'yicha har ikkinchisi)."""
    out = {}
    for level in range(1, 6):
        for src, dst in (("A", "C"), ("B", "D")):
            form = [r for r in bank if f"L{level}{src}" in r["forms"]]
            form.sort(key=lambda r: (r["b"], r["externalId"]))
            out[f"L{level}{dst}"] = [r["externalId"] for r in form[::2]][:FIGURAL_PER_FORM]
    return out


def check(records, forms):
    count = {f: len(ids) for f, ids in forms.items()}
    for r in records:
        for f in r["forms"]:
            count[f] = count.get(f, 0) + 1
    for f, n in sorted(count.items()):
        assert n == 20, f"{f}: {n} savol"
    print(f"{len(records)} matnli savol; formalar: " + ", ".join(f"{f}={n}" for f, n in sorted(count.items())))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--forms", required=True)
    args = ap.parse_args()
    rng = random.Random(SEED)
    records = []
    for level in range(1, 6):
        groups = {
            "NUMERIC": [numeric_item(*spec, rng) for spec in NUMERIC[level]],
            "VERBAL": [text_item("VERBAL", q, rng) for q in VERBAL[level]],
            "LOGIC": [text_item("LOGIC", q, rng) for q in LOGIC[level]],
        }
        for kind, items in groups.items():
            assign_forms(items, PER_FORM[kind], level)
            records += [to_record(it, level, i, rng) for i, it in enumerate(items)]
    with open(args.items) as f:
        forms = figural_forms(json.load(f))
    check(records, forms)
    for path, data in ((args.out, records), (args.forms, forms)):
        with open(path, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
            f.write("\n")


if __name__ == "__main__":
    main()
