"""IQ matritsa qoidalari (shablonlar). Har shablon `rng` bilan tasodifiy
parametrlar tanlaydi va {grid: 9 katak, distractors: 5 katak, rule, c}
qaytaradi. `c` — murakkablik (qoidalar soni) → dizayn qiyinligi `b`.
"""
from render import CLOCKWISE, SEGMENTS

SHAPES = ["circle", "square", "triangle", "diamond", "hexagon"]
FILLS = ["empty", "striped", "filled"]
INNER_R = {"circle": 9, "triangle": 11, "square": 10, "diamond": 10}
COUNT_LAYOUT = {1: ([(50, 50)], 26), 2: ([(28, 50), (72, 50)], 17), 3: ([(50, 29), (28, 71), (72, 71)], 15)}


def shape(kind, fill="empty", r=28, x=50, y=50):
    return {"t": "shape", "kind": kind, "fill": fill, "r": r, "x": x, "y": y}


def single(kind, fill="empty", r=28):
    return [shape(kind, fill, r)]


def count_cell(kind, n, fill="empty"):
    pts, r = COUNT_LAYOUT[n]
    return [shape(kind, fill, r, x, y) for x, y in pts]


def arrow(angle):
    return [{"t": "arrow", "angle": angle % 360}]


def lines(names):
    return [{"t": "lines", "set": sorted(set(names))}]


def latin(rng, items):
    """3x3 lotin kvadrati: har qator va ustunda har element bittadan."""
    base = list(items)
    step = rng.choice([1, 2])
    return [[base[(r * step + c) % 3] for c in range(3)] for r in range(3)]


def _other(rng, pool, exclude):
    return rng.choice([x for x in pool if x not in exclude])


# ── 1 qoida ───────────────────────────────────────────────────────────

def t_count(rng):
    rows = rng.sample(SHAPES, 3)
    counts = rng.choice([[1, 2, 3], [3, 2, 1]])
    fill = rng.choice(FILLS)
    grid = [count_cell(rows[r], counts[c], fill) for r in range(3) for c in range(3)]
    s, n = rows[2], counts[2]
    return dict(rule="count", c=1.0, grid=grid, distractors=[
        count_cell(s, counts[1], fill), count_cell(s, counts[0], fill), count_cell(rows[1], n, fill),
        count_cell(rows[0], n, fill), count_cell(s, n, _other(rng, FILLS, [fill]))])


def t_fill(rng):
    rows, order = rng.sample(SHAPES, 3), rng.sample(FILLS, 3)
    grid = [single(rows[r], order[c]) for r in range(3) for c in range(3)]
    s, f = rows[2], order[2]
    return dict(rule="fill", c=1.0, grid=grid, distractors=[
        single(s, order[1]), single(s, order[0]), single(rows[1], f), single(rows[0], f), count_cell(s, 2, f)])


def t_size(rng):
    rows = rng.sample(SHAPES, 3)
    sizes = rng.choice([[14, 25, 37], [37, 25, 14]])
    fill = rng.choice(FILLS)
    grid = [single(rows[r], fill, sizes[c]) for r in range(3) for c in range(3)]
    s, z = rows[2], sizes[2]
    return dict(rule="size", c=1.0, grid=grid, distractors=[
        single(s, fill, sizes[1]), single(s, fill, sizes[0]), single(rows[1], fill, z),
        single(rows[0], fill, z), single(s, _other(rng, FILLS, [fill]), z)])


def t_rotate(rng, step):
    base, sign = rng.choice(range(0, 360, 45)), rng.choice([1, -1])
    grid = [arrow(base + sign * step * (r + c)) for r in range(3) for c in range(3)]
    ans = (base + sign * step * 4) % 360
    wrong = [a for a in range(0, 360, 45) if a != ans]
    near = [(ans + sign * step) % 360, (ans - sign * step) % 360, (ans + 180) % 360]
    pick = list(dict.fromkeys(near + rng.sample(wrong, len(wrong))))
    return dict(rule=f"rotate{step}", c=1.5 if step == 90 else 2.5, grid=grid,
                distractors=[arrow(a) for a in pick[:5]])


# ── 2 qoida ───────────────────────────────────────────────────────────

def t_latin_rowfill(rng):
    sq, fills = latin(rng, rng.sample(SHAPES, 3)), rng.sample(FILLS, 3)
    grid = [single(sq[r][c], fills[r]) for r in range(3) for c in range(3)]
    s, f = sq[2][2], fills[2]
    others = [x for x in sq[2] if x != s]
    return dict(rule="latin_rowfill", c=2.0, grid=grid, distractors=[
        single(s, fills[0]), single(s, fills[1]), single(others[0], f), single(others[1], f),
        single(_other(rng, SHAPES, sq[2]), f)])


def t_outer_inner(rng):
    outer = rng.sample(["circle", "square", "diamond", "hexagon"], 3)
    inner = rng.sample(list(INNER_R), 3)

    def cell(o, i, fill="filled"):
        return [shape(o, "empty", 37), shape(i, fill, INNER_R[i])]

    grid = [cell(outer[r], inner[c]) for r in range(3) for c in range(3)]
    o, i = outer[2], inner[2]
    return dict(rule="outer_inner", c=2.0, grid=grid, distractors=[
        cell(o, inner[0]), cell(o, inner[1]), cell(outer[1], i), cell(outer[0], i), cell(o, i, "empty")])


def _line_sets(rng, size_a, size_b, overlap):
    names = list(SEGMENTS)
    a = rng.sample(names, size_a)
    rest = [n for n in names if n not in a]
    b = rng.sample(a, overlap) + rng.sample(rest, size_b - overlap)
    return set(a), set(b)


def t_lines(rng, op, sizes):
    """op: union (C=A∪B), xor (C=A△B), minus (C=A∖B, B⊂A)."""
    grid, last = [], None
    for _ in range(3):
        while True:
            if op == "minus":
                a = set(rng.sample(list(SEGMENTS), sizes[0]))
                b = set(rng.sample(sorted(a), sizes[1]))
            else:
                a, b = _line_sets(rng, sizes[0], sizes[1], 0 if op == "union" else 1)
            c = a | b if op == "union" else (a ^ b if op == "xor" else a - b)
            if c and a != b and c not in (a, b):
                break
        grid += [lines(a), lines(b), lines(c)]
        last = (a, b, c)
    a, b, c = last
    e1, e2 = rng.sample([n for n in SEGMENTS if n not in c], 2)
    d1 = rng.choice(sorted(c))
    alt = {"union": a ^ b, "xor": a | b, "minus": a | b}[op]
    # Takrorlar generatorda tashlanadi — shuning uchun zaxira bilan ko'proq nomzod.
    cand = [s for s in [alt, a, b, c | {e1}, c - {d1}, (c - {d1}) | {e1}, c | {e2}, (c - {d1}) | {e2}, c | {e1, e2}] if s]
    cand = [lines(s) for s in cand]
    c_level = {"union": 2.0, "xor": 3.0, "minus": 3.5}[op] + (0.5 if sizes[0] >= 3 else 0)
    return dict(rule=f"lines_{op}", c=c_level, grid=grid, distractors=cand)


def t_latin_count(rng):
    sq, counts, fill = latin(rng, rng.sample(SHAPES, 3)), rng.sample([1, 2, 3], 3), rng.choice(FILLS)
    grid = [count_cell(sq[r][c], counts[c], fill) for r in range(3) for c in range(3)]
    s, n = sq[2][2], counts[2]
    others = [x for x in sq[2] if x != s]
    return dict(rule="latin_count", c=2.5, grid=grid, distractors=[
        count_cell(s, counts[0], fill), count_cell(s, counts[1], fill), count_cell(others[0], n, fill),
        count_cell(others[1], n, fill), count_cell(s, n, _other(rng, FILLS, [fill]))])


def t_latin_size(rng):
    sq, sizes, fill = latin(rng, rng.sample(SHAPES, 3)), rng.choice([[14, 25, 37], [37, 25, 14]]), rng.choice(FILLS)
    grid = [single(sq[r][c], fill, sizes[c]) for r in range(3) for c in range(3)]
    s, z = sq[2][2], sizes[2]
    others = [x for x in sq[2] if x != s]
    return dict(rule="latin_size", c=2.5, grid=grid, distractors=[
        single(s, fill, sizes[0]), single(s, fill, sizes[1]), single(others[0], fill, z),
        single(others[1], fill, z), single(s, _other(rng, FILLS, [fill]), z)])


# ── 3+ qoida ──────────────────────────────────────────────────────────

def t_latin_both(rng):
    sq, fq = latin(rng, rng.sample(SHAPES, 3)), latin(rng, rng.sample(FILLS, 3))
    grid = [single(sq[r][c], fq[r][c]) for r in range(3) for c in range(3)]
    s, f = sq[2][2], fq[2][2]
    return dict(rule="latin_both", c=3.0, grid=grid, distractors=[
        single(s, fq[2][0]), single(s, fq[2][1]), single(sq[2][0], f), single(sq[2][1], f),
        single(_other(rng, SHAPES, sq[2]), f)])


def t_dot_fill(rng):
    centers, order = rng.sample(SHAPES, 3), rng.sample(FILLS, 3)
    starts, sign = rng.sample(range(4), 3), rng.choice([1, -1])

    def cell(center, fill, k):
        return [shape(center, fill, 18), {"t": "dot", "corner": CLOCKWISE[k % 4]}]

    grid = [cell(centers[r], order[c], starts[r] + sign * c) for r in range(3) for c in range(3)]
    s, f, k = centers[2], order[2], starts[2] + sign * 2
    return dict(rule="dot_fill", c=3.0, grid=grid, distractors=[
        cell(s, f, k - sign), cell(s, f, k + sign), cell(s, order[1], k), cell(s, order[0], k), cell(centers[1], f, k)])


def t_count_fill_latin(rng):
    rows, counts, fq = rng.sample(SHAPES, 3), rng.choice([[1, 2, 3], [3, 2, 1]]), latin(rng, rng.sample(FILLS, 3))
    grid = [count_cell(rows[r], counts[c], fq[r][c]) for r in range(3) for c in range(3)]
    s, n, f = rows[2], counts[2], fq[2][2]
    return dict(rule="count_fill_latin", c=3.0, grid=grid, distractors=[
        count_cell(s, n, fq[2][0]), count_cell(s, n, fq[2][1]), count_cell(s, counts[1], f),
        count_cell(rows[1], n, f), count_cell(s, counts[0], f)])


def t_two_dots(rng):
    """Qora nuqta soat strelkasi bo'yicha, halqa teskari yuradi. Farq toq —
    ikkalasi hech qachon bir burchakka tushmaydi."""
    center = rng.choice(SHAPES)

    def cell(a, b):
        return [shape(center, "empty", 16), {"t": "dot", "corner": CLOCKWISE[a % 4]},
                {"t": "dot", "corner": CLOCKWISE[b % 4], "ring": True}]

    starts = []
    for _ in range(3):
        a = rng.randrange(4)
        starts.append((a, a + rng.choice([1, 3])))
    grid = [cell(a + c, b - c) for a, b in starts for c in range(3)]
    a, b = starts[2][0] + 2, starts[2][1] - 2
    cands = [cell(a - 1, b + 1), cell(a + 1, b - 1), cell(b, a), cell(a + 2, b + 2), cell(a + 1, b + 1), cell(a - 1, b - 1)]
    return dict(rule="two_dots", c=3.5, grid=grid, distractors=cands)


def t_three(rng):
    sq, fq, counts = latin(rng, rng.sample(SHAPES, 3)), latin(rng, rng.sample(FILLS, 3)), rng.sample([1, 2, 3], 3)
    grid = [count_cell(sq[r][c], counts[c], fq[r][c]) for r in range(3) for c in range(3)]
    s, f, n = sq[2][2], fq[2][2], counts[2]
    return dict(rule="three_rules", c=4.0, grid=grid, distractors=[
        count_cell(s, n, fq[2][0]), count_cell(sq[2][0], n, f), count_cell(s, counts[0], f),
        count_cell(s, counts[1], f), count_cell(sq[2][1], n, fq[2][1])])


LEVEL_POOLS = {
    1: [t_count, t_fill, t_size, lambda r: t_rotate(r, 90), t_latin_rowfill, t_outer_inner,
        lambda r: t_lines(r, "union", (1, 1)), t_latin_count],
    2: [lambda r: t_rotate(r, 90), t_latin_rowfill, t_outer_inner, lambda r: t_lines(r, "union", (2, 1)),
        t_latin_count, t_latin_size, t_latin_both, t_dot_fill],
    3: [t_outer_inner, lambda r: t_lines(r, "union", (2, 2)), t_latin_count, lambda r: t_rotate(r, 45),
        t_latin_both, lambda r: t_lines(r, "xor", (2, 2)), t_dot_fill, t_count_fill_latin],
    4: [lambda r: t_rotate(r, 45), t_latin_both, lambda r: t_lines(r, "xor", (2, 2)), t_dot_fill,
        t_count_fill_latin, lambda r: t_lines(r, "minus", (3, 1)), t_two_dots, t_three],
    5: [t_latin_both, lambda r: t_lines(r, "xor", (3, 2)), t_count_fill_latin, lambda r: t_lines(r, "minus", (3, 2)),
        t_two_dots, t_three, lambda r: t_lines(r, "xor", (3, 3))],
}
