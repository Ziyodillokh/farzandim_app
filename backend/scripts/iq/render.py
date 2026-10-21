"""IQ matritsalari — SVG chizish (faqat flutter_svg ishonchli chizadigan
elementlar: rect/circle/polygon/line/path/g+rotate; pattern, text va
stroke-dasharray YO'Q). Chiziqli bo'yalish — shakl ichiga kesilgan chiziqlar.
"""
import math

CELL = 100
GAP = 10
DARK = "#1F2A44"
BLUE = "#2F6BFF"
BORDER = "#D5DCEB"
MISSING_BG = "#EEF3FF"
HATCH_STEP = 7.0

M = 18
SEGMENTS = {
    "h": (M, 50, 100 - M, 50),
    "v": (50, M, 50, 100 - M),
    "d1": (M, M, 100 - M, 100 - M),
    "d2": (100 - M, M, M, 100 - M),
    "top": (M, M, 100 - M, M),
    "bottom": (M, 100 - M, 100 - M, 100 - M),
    "left": (M, M, M, 100 - M),
    "right": (100 - M, M, 100 - M, 100 - M),
}
CORNERS = {"TL": (22, 22), "TR": (78, 22), "BR": (78, 78), "BL": (22, 78)}
CLOCKWISE = ["TL", "TR", "BR", "BL"]


def _f(x):
    return f"{x:.1f}".rstrip("0").rstrip(".")


def _poly_pts(cx, cy, r, n, start_deg):
    return [(cx + r * math.cos(math.radians(start_deg + 360 * i / n)),
             cy + r * math.sin(math.radians(start_deg + 360 * i / n))) for i in range(n)]


def shape_polygon(kind, cx, cy, r):
    """Qavariq ko'pburchak uchlari (doira uchun None)."""
    if kind == "square":
        s = r * 0.9
        return [(cx - s, cy - s), (cx + s, cy - s), (cx + s, cy + s), (cx - s, cy + s)]
    if kind == "triangle":
        return _poly_pts(cx, cy + r * 0.15, r * 1.15, 3, -90)
    if kind == "diamond":
        return _poly_pts(cx, cy, r * 1.1, 4, -90)
    if kind == "hexagon":
        return _poly_pts(cx, cy, r, 6, 0)
    return None


def _clip_convex(p0, d, poly):
    """Cyrus–Beck: p0 + u·d chizig'ining qavariq ko'pburchak ichidagi [u0, u1] qismi."""
    u0, u1 = -1e9, 1e9
    n = len(poly)
    # Uchlar soat strelkasi bo'yicha (SVG koordinatalarida) — ichki normal.
    area = sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1] for i in range(n))
    sign = 1 if area > 0 else -1
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        nx, ny = -(by - ay) * sign, (bx - ax) * sign
        denom = nx * d[0] + ny * d[1]
        num = nx * (p0[0] - ax) + ny * (p0[1] - ay)
        if abs(denom) < 1e-12:
            if num < 0:
                return None
            continue
        u = -num / denom
        if denom > 0:
            u0 = max(u0, u)
        else:
            u1 = min(u1, u)
    return (u0, u1) if u1 - u0 > 0.5 else None


def hatch_lines(kind, cx, cy, r):
    """45° chiziqlar shakl ichida (oq fon ustiga)."""
    d = (1 / math.sqrt(2), -1 / math.sqrt(2))
    nrm = (1 / math.sqrt(2), 1 / math.sqrt(2))
    poly = shape_polygon(kind, cx, cy, r)
    reach = r * 1.3
    out = []
    t = -reach + HATCH_STEP / 2
    while t < reach:
        p0 = (cx + nrm[0] * t, cy + nrm[1] * t)
        if poly is None:
            if abs(t) >= r:
                t += HATCH_STEP
                continue
            h = math.sqrt(r * r - t * t)
            seg = (-h, h)
        else:
            seg = _clip_convex(p0, d, poly)
        if seg:
            (u0, u1) = seg
            x1, y1 = p0[0] + d[0] * u0, p0[1] + d[1] * u0
            x2, y2 = p0[0] + d[0] * u1, p0[1] + d[1] * u1
            out.append(f'<line x1="{_f(x1)}" y1="{_f(y1)}" x2="{_f(x2)}" y2="{_f(y2)}" stroke="{DARK}" stroke-width="2.5"/>')
        t += HATCH_STEP
    return "".join(out)


def _outline(kind, cx, cy, r, fill):
    attrs = f'fill="{fill}" stroke="{DARK}" stroke-width="3" stroke-linejoin="round"'
    if kind == "circle":
        return f'<circle cx="{_f(cx)}" cy="{_f(cy)}" r="{_f(r)}" {attrs}/>'
    pts = " ".join(f"{_f(x)},{_f(y)}" for x, y in shape_polygon(kind, cx, cy, r))
    return f'<polygon points="{pts}" {attrs}/>'


def draw_element(e, ox, oy):
    t = e["t"]
    if t == "shape":
        cx, cy, r = ox + e["x"], oy + e["y"], e["r"]
        if e["fill"] == "filled":
            return _outline(e["kind"], cx, cy, r, DARK)
        if e["fill"] == "striped":
            return (_outline(e["kind"], cx, cy, r, "#FFFFFF") + hatch_lines(e["kind"], cx, cy, r)
                    + _outline(e["kind"], cx, cy, r, "none"))
        return _outline(e["kind"], cx, cy, r, "#FFFFFF")
    if t == "arrow":
        cx, cy = ox + 50, oy + 50
        return (f'<g transform="rotate({e["angle"]} {cx} {cy})">'
                f'<line x1="{cx}" y1="{cy + 30}" x2="{cx}" y2="{cy - 18}" stroke="{DARK}" stroke-width="6" stroke-linecap="round"/>'
                f'<polygon points="{cx},{cy - 34} {cx - 14},{cy - 12} {cx + 14},{cy - 12}" fill="{DARK}"/></g>')
    if t == "lines":
        return "".join(
            f'<line x1="{ox + x1}" y1="{oy + y1}" x2="{ox + x2}" y2="{oy + y2}" stroke="{DARK}" stroke-width="5" stroke-linecap="round"/>'
            for x1, y1, x2, y2 in (SEGMENTS[n] for n in e["set"]))
    if t == "dot":
        x, y = CORNERS[e["corner"]]
        if e.get("ring"):
            return f'<circle cx="{ox + x}" cy="{oy + y}" r="7" fill="#FFFFFF" stroke="{DARK}" stroke-width="3"/>'
        return f'<circle cx="{ox + x}" cy="{oy + y}" r="8" fill="{DARK}"/>'
    raise ValueError(t)


def _cell_bg(ox, oy, fill="#FFFFFF", stroke=BORDER, width=2):
    return f'<rect x="{ox}" y="{oy}" width="{CELL}" height="{CELL}" rx="12" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'


def _question_mark(ox, oy):
    return (f'<path d="M{ox + 38} {oy + 38}Q{ox + 38} {oy + 24} {ox + 50} {oy + 24}Q{ox + 62} {oy + 24} {ox + 62} {oy + 37}'
            f'Q{ox + 62} {oy + 46} {ox + 50} {oy + 51}L{ox + 50} {oy + 60}" fill="none" stroke="{BLUE}" '
            f'stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>'
            f'<circle cx="{ox + 50}" cy="{oy + 74}" r="4.5" fill="{BLUE}"/>')


def grid_svg(cells):
    size = 3 * CELL + 2 * GAP
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-4 -4 {size + 8} {size + 8}">']
    for i, cell in enumerate(cells[:8]):
        ox, oy = (i % 3) * (CELL + GAP), (i // 3) * (CELL + GAP)
        parts.append(_cell_bg(ox, oy) + "".join(draw_element(e, ox, oy) for e in cell))
    ox = oy = 2 * (CELL + GAP)
    parts.append(_cell_bg(ox, oy, MISSING_BG, BLUE, 3) + _question_mark(ox, oy))
    parts.append("</svg>")
    return "".join(parts)


def cell_svg(cell):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-4 -4 {CELL + 8} {CELL + 8}">'
            f'{_cell_bg(0, 0)}{"".join(draw_element(e, 0, 0) for e in cell)}</svg>')
