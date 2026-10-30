#!/usr/bin/env python3
"""Build SVG-ready Uzbekistan geometry for the Parvoz regional monitoring dashboard.

Regions  : Natural Earth 1:10m admin-1 (public domain), 14 units; Toshkent shahri is last (paints on top).
Districts: geoBoundaries gbOpen UZB ADM2 = OCHA ROCCA 2020 (CC BY 3.0 IGO), 199 units, with official
           Uzbek names and SOATO codes matched from the stat.uz SIAT classifier.
Usage    : python3 build_geo.py           -> dry run: prints a summary, writes nothing
           python3 build_geo.py OUT_DIR   -> writes uz-regions.json, uz-districts.json, preview-*.svg
           GEO_VERBOSE=1 prints every district name match.
Needs    : Python 3.9+ standard library and curl.
"""
import difflib
import heapq
import json
import math
import os
import re
import subprocess
import sys
from collections import defaultdict
from html import escape
from pathlib import Path

NE_URL = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
          "ne_10m_admin_1_states_provinces.geojson")
GB_API = "https://www.geoboundaries.org/api/current/gbOpen/UZB/ADM2/"
SIAT_URL = "https://api.siat.stat.uz/media/uploads/sdmx/sdmx_data_3134.json"  # any district-level SIAT table
VIEW_W, PAD = 1000, 12
REGION_TOL_PX, REGION_DECIMALS = 0.15, 1
DISTRICT_TOL_PX, DISTRICT_DECIMALS = 0.05, 2
REGION_BUDGET, DISTRICT_BUDGET = 60_000, 350_000
ALBERS = {"lon0": 64.5, "lat0": 41.4, "lat1": 38.5, "lat2": 44.2, "radiusKm": 6371.0088}
REGIONS = [  # id, SOATO, app slug, nameUz (backend canonical), nameRu, nameEn -- stat.uz order, Toshkent shahri LAST
    ("UZ-QR", "1735", "karakalpakstan", "Qoraqalpog'iston Respublikasi", "Республика Каракалпакстан", "Republic of Karakalpakstan"),
    ("UZ-AN", "1703", "andijan", "Andijon viloyati", "Андижанская область", "Andijan Region"),
    ("UZ-BU", "1706", "bukhara", "Buxoro viloyati", "Бухарская область", "Bukhara Region"),
    ("UZ-JI", "1708", "jizzakh", "Jizzax viloyati", "Джизакская область", "Jizzakh Region"),
    ("UZ-QA", "1710", "kashkadarya", "Qashqadaryo viloyati", "Кашкадарьинская область", "Kashkadarya Region"),
    ("UZ-NW", "1712", "navoi", "Navoiy viloyati", "Навоийская область", "Navoi Region"),
    ("UZ-NG", "1714", "namangan", "Namangan viloyati", "Наманганская область", "Namangan Region"),
    ("UZ-SA", "1718", "samarkand", "Samarqand viloyati", "Самаркандская область", "Samarkand Region"),
    ("UZ-SU", "1722", "surkhandarya", "Surxondaryo viloyati", "Сурхандарьинская область", "Surkhandarya Region"),
    ("UZ-SI", "1724", "sirdarya", "Sirdaryo viloyati", "Сырдарьинская область", "Syrdarya Region"),
    ("UZ-TO", "1727", "tashkent", "Toshkent viloyati", "Ташкентская область", "Tashkent Region"),
    ("UZ-FA", "1730", "fergana", "Farg'ona viloyati", "Ферганская область", "Fergana Region"),
    ("UZ-XO", "1733", "khorezm", "Xorazm viloyati", "Хорезмская область", "Khorezm Region"),
    ("UZ-TK", "1726", "tashkentCity", "Toshkent shahri", "город Ташкент", "Tashkent City"),
]
NE_EXCLAVE_FIX = ("UZ-SI", (68.74, 39.96), "UZ-JI")  # NE files Jizzax's Yangiobod district under Sirdaryo
TK_DISTRICTS = ("Almazar", "Bektemir", "Chilanzar", "Mirabad", "Mirzo Ulugbek", "Sergeli", "Shaykhantokhur",
                "Uchtepa", "Yakkasaray", "Yashnobod", "Yunusabad")
DISTRICT_REGION_OVERRIDES = {**{n: "UZ-TK" for n in TK_DISTRICTS}, "Shirin city": "UZ-SI", "Yangiabad": "UZ-JI"}
DISTRICT_NAME_SWAPS = {"Kagan": "Kagan city", "Kagan city": "Kagan"}  # OCHA swapped them (city polygon is 1.8 km2)
NAME_OVERRIDES = {"Boz": "Bo'ston tumani", "Sergeli": "Sirg'ali tumani", "Zaamin": "Zomin tumani"}
EXPECTED_DISTRICTS = {"UZ-QR": 15, "UZ-AN": 16, "UZ-BU": 13, "UZ-JI": 13, "UZ-QA": 15, "UZ-NW": 10, "UZ-NG": 12,
                      "UZ-SA": 16, "UZ-SU": 14, "UZ-SI": 11, "UZ-TO": 22, "UZ-FA": 19, "UZ-XO": 12, "UZ-TK": 11}
APOSTROPHES = "‘’ʻʼ`´"
PALETTE = ("#4E79A7", "#F28E2B", "#E15759", "#76B7B2", "#59A14F", "#EDC948", "#B07AA1",
           "#FF9DA7", "#9C755F", "#86BCB6", "#D37295", "#A0CBE8", "#8CD17D", "#1F1F1F")
REGION_SOURCE = ("Natural Earth 1:10m Cultural Vectors, Admin 1 - States, Provinces (public domain), "
                 "https://www.naturalearthdata.com/ via github.com/nvkelso/natural-earth-vector")
REGION_NOTES = [
    "Natural Earth files the Yangiobod district area (~68.6-69.0E, 39.8-40.15N) under Sirdaryo; it belongs to "
    "Jizzax viloyati (geoBoundaries ADM1/OSM and OCHA ADM2 agree) and is merged into UZ-JI here.",
    "UZ-TO has a hole where UZ-TK sits; UZ-TK is last in the array so it paints on top and stays clickable.",
    "Natural Earth's Toshkent shahri outline (~240 km2) is smaller than the real city: fine for the national map only.",
]
DISTRICT_ATTRIBUTION = (
    "District boundaries (c) OCHA ROCCA (2020), via HDX data.humdata.org/dataset/ubbekistan-update, licensed "
    "CC BY 3.0 IGO; distributed by geoBoundaries (Runfola D. et al. 2020, PLoS ONE 15(4): e0231866); simplified "
    "and reprojected. Official names and SOATO codes: National Statistics Committee of Uzbekistan (siat.stat.uz).")
DISTRICT_NOTES = [
    "Boundaries represent 2020; units created later have no geometry and are listed in missingGeometry.",
    "Source names 'Kagan' and 'Kagan city' were swapped in OCHA data and are corrected here.",
    "Some source city polygons are tiny (Shirin 0.1 km2, Yangiyer 0.5 km2, Ohangaron shahri 0.6 km2): draw a "
    "minimum-size marker at the centroid.",
    "District outer borders do not coincide exactly with the Natural Earth region outlines: in a region "
    "drill-down draw districts only (zoom with the region bbox).",
]


# ------------------------------------------------------------------ io
def fetch_json(url):
    raw = subprocess.run(["curl", "-sSfL", "--max-time", "300", url], capture_output=True, check=True).stdout
    return json.loads(raw)


# ------------------------------------------------------------------ geometry helpers
def polys_of(geom):
    return [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]


def open_ring(ring):
    out = []
    for p in ring:
        q = (p[0], p[1])
        if not out or out[-1] != q:
            out.append(q)
    if len(out) > 1 and out[0] == out[-1]:
        out.pop()
    return out


def signed_area(r):
    return 0.5 * sum(r[i][0] * r[(i + 1) % len(r)][1] - r[(i + 1) % len(r)][0] * r[i][1] for i in range(len(r)))


def point_in(x, y, polys):
    hit = False
    for poly in polys:
        for r in poly:
            j = len(r) - 1
            for i in range(len(r)):
                (ax, ay), (bx, by) = r[i], r[j]
                if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
                    hit = not hit
                j = i
    return hit


def area_centroid(polys):
    a = cx = cy = 0.0
    for poly in polys:
        for r in poly:
            for i in range(len(r)):
                (x0, y0), (x1, y1) = r[i], r[(i + 1) % len(r)]
                c = x0 * y1 - x1 * y0
                a += c
                cx += (x0 + x1) * c
                cy += (y0 + y1) * c
    return (cx / (3 * a), cy / (3 * a)) if a else polys[0][0][0]


def seg_dist2(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return (px - ax - t * dx) ** 2 + (py - ay - t * dy) ** 2


def signed_dist(x, y, rings):
    d = math.sqrt(min(seg_dist2(x, y, *r[i], *r[i - 1]) for r in rings for i in range(len(r))))
    return d if point_in(x, y, [rings]) else -d


def frange(a, b, step):
    v = a
    while v < b:
        yield v
        v += step


def polylabel(rings):
    """Pole of inaccessibility (Mapbox polylabel) of one polygon given as [outer, *holes]."""
    xs, ys = [p[0] for p in rings[0]], [p[1] for p in rings[0]]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    size = min(x1 - x0, y1 - y0)
    if size <= 0:
        return (x0, y0)
    precision, h = max(size / 200, 1e-4), size / 2

    def cell(cx, cy, half):
        d = signed_dist(cx, cy, rings)
        return (-(d + half * math.sqrt(2)), cx, cy, half, d)

    heap = [cell(x + h, y + h, h) for x in frange(x0, x1, size) for y in frange(y0, y1, size)]
    heapq.heapify(heap)
    best = max((cell(*area_centroid([rings]), 0), cell((x0 + x1) / 2, (y0 + y1) / 2, 0)), key=lambda c: c[4])
    while heap:
        c = heapq.heappop(heap)
        if c[4] > best[4]:
            best = c
        if -c[0] - best[4] <= precision:
            continue
        q = c[3] / 2
        for dx in (-q, q):
            for dy in (-q, q):
                heapq.heappush(heap, cell(c[1] + dx, c[2] + dy, q))
    return (best[1], best[2])


def dissolve(rings):
    """Union of outer rings that share exact vertices (shared edges cancel out)."""
    edges = {}
    for r in rings:
        r = r if signed_area(r) > 0 else r[::-1]
        for i in range(len(r)):
            a, b = r[i], r[(i + 1) % len(r)]
            if (b, a) in edges:
                del edges[(b, a)]
            else:
                edges[(a, b)] = True
    nxt = defaultdict(list)
    for a, b in edges:
        nxt[a].append(b)
    out = []
    while nxt:
        start = cur = next(iter(nxt))
        ring = [start]
        while True:
            b = nxt[cur].pop()
            if not nxt[cur]:
                del nxt[cur]
            if b == start:
                break
            ring.append(b)
            cur = b
        out.append(ring)
    return out


# ------------------------------------------------------------------ projection
def make_albers(lon0, lat0, lat1, lat2, radiusKm):
    p1, p2, p0 = map(math.radians, (lat1, lat2, lat0))
    n = (math.sin(p1) + math.sin(p2)) / 2
    c = math.cos(p1) ** 2 + 2 * n * math.sin(p1)
    rho0 = radiusKm * math.sqrt(c - 2 * n * math.sin(p0)) / n

    def project(lon, lat):
        theta = n * math.radians(lon - lon0)
        rho = radiusKm * math.sqrt(c - 2 * n * math.sin(math.radians(lat))) / n
        return rho * math.sin(theta), rho0 - rho * math.cos(theta)
    return project


def make_screen(points_lonlat):
    albers = make_albers(**ALBERS)
    km = [albers(*p) for p in points_lonlat]
    min_x, max_y = min(p[0] for p in km), max(p[1] for p in km)
    scale = (VIEW_W - 2 * PAD) / (max(p[0] for p in km) - min_x)
    height = math.ceil((max_y - min(p[1] for p in km)) * scale + 2 * PAD)

    def to_screen(lon, lat):
        x, y = albers(lon, lat)
        return ((x - min_x) * scale + PAD, (max_y - y) * scale + PAD)
    meta = {"type": "Albers equal-area conic (sphere)", **ALBERS, "pxPerKm": round(scale, 6),
            "originKm": [round(min_x, 4), round(max_y, 4)], "pad": PAD,
            "formula": "x = (Xkm - originKm[0]) * pxPerKm + pad; y = (originKm[1] - Ykm) * pxPerKm + pad"}
    return to_screen, height, meta


# ------------------------------------------------------------------ topology-preserving Douglas-Peucker
def dp_keep(pts, tol):
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack, tol2 = [(0, len(pts) - 1)], tol * tol
    while stack:
        a, b = stack.pop()
        best, idx = -1.0, -1
        for i in range(a + 1, b):
            d = seg_dist2(*pts[i], *pts[a], *pts[b])
            if d > best:
                best, idx = d, i
        if idx > 0 and best > tol2:
            keep[idx] = True
            stack += [(a, idx), (idx, b)]
    return keep


def ring_arcs(ring, junctions, scr):
    """Split a ring into arcs between junctions; junction-free rings get a canonical start and direction."""
    js = [i for i, p in enumerate(ring) if p in junctions]
    if not js:
        s = min(range(len(ring)), key=lambda i: ring[i])
        r = ring[s:] + ring[:s]
        if r[-1] < r[1]:
            r = [r[0]] + r[1:][::-1]
        far = max(range(len(r)), key=lambda i: seg_dist2(*scr[r[i]], *scr[r[0]], *scr[r[0]]))
        return [r[:far + 1], r[far:] + [r[0]]]
    r = ring[js[0]:] + ring[:js[0]]
    idx = [i for i, p in enumerate(r) if p in junctions] + [len(r)]
    r = r + [r[0]]
    return [r[idx[k]:idx[k + 1] + 1] for k in range(len(idx) - 1)]


def simplify_shared(rings, scr, tol):
    """Vertices to keep; every shared border is simplified once, identically for both neighbours."""
    nbrs = defaultdict(set)
    for r in rings:
        for i, p in enumerate(r):
            nbrs[p].add(frozenset((r[i - 1], r[(i + 1) % len(r)])))
    junctions = {p for p, s in nbrs.items() if len(s) > 1}
    kept = set(junctions)
    for r in rings:
        arcs = ring_arcs(r, junctions, scr)
        for arc in arcs:
            arc = arc if arc[0] <= arc[-1] else arc[::-1]
            flags = dp_keep([scr[p] for p in arc], tol)
            if len(arcs) <= 2 and sum(flags) < 3 and len(arc) > 2:  # keep tiny rings from collapsing
                far = max(range(1, len(arc) - 1), key=lambda i: seg_dist2(*scr[arc[i]], *scr[arc[0]], *scr[arc[-1]]))
                flags[far] = True
            kept.update(p for p, f in zip(arc, flags) if f)
    return kept


def project_ring(ring, kept, scr, decimals):
    pts = []
    for p in ring:
        if p in kept:
            q = (round(scr[p][0], decimals), round(scr[p][1], decimals))
            if not pts or pts[-1] != q:
                pts.append(q)
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts.pop()
    return pts


def project_polys(polys, kept, scr, decimals):
    """Screen-space polygons: outer rings clockwise on screen, holes counter-clockwise."""
    out = []
    for poly in polys:
        rings = []
        for k, ring in enumerate(poly):
            pts = project_ring(ring, kept, scr, decimals)
            if len(pts) < 3:
                if k == 0:
                    break
                continue
            if (k == 0) != (signed_area(pts) > 0):
                pts = pts[::-1]
            rings.append(pts)
        if rings:
            out.append(rings)
    return out


def fmt(v, decimals):
    s = f"{v:.{decimals}f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def path_d(polys, decimals):
    def f(v):
        return fmt(v, decimals)
    return "".join("M" + f(r[0][0]) + "," + f(r[0][1]) + "L" + " ".join(f(x) + "," + f(y) for x, y in r[1:]) + "Z"
                   for poly in polys for r in poly)


def bbox(polys, decimals):
    pts = [p for poly in polys for r in poly for p in r]
    return [round(min(p[0] for p in pts), decimals), round(min(p[1] for p in pts), decimals),
            round(max(p[0] for p in pts), decimals), round(max(p[1] for p in pts), decimals)]


def inside_point(polys, decimals):
    """Area centroid, or the pole of inaccessibility of the largest part when the centroid falls outside."""
    c = area_centroid(polys)
    if not point_in(*c, polys):
        c = polylabel(max(polys, key=lambda p: abs(signed_area(p[0]))))
    return [round(c[0], decimals), round(c[1], decimals)]


# ------------------------------------------------------------------ sources
def load_regions():
    feats = [f for f in fetch_json(NE_URL)["features"] if f["properties"].get("adm0_a3") == "UZB"]
    reg = {f["properties"]["iso_3166_2"]: [[open_ring(r) for r in poly] for poly in polys_of(f["geometry"])]
           for f in feats}
    assert sorted(reg) == sorted(r[0] for r in REGIONS), sorted(reg)
    src, pt, dst = NE_EXCLAVE_FIX
    part = [p for p in reg[src] if point_in(*pt, [p])]
    assert len(part) == 1 and len(reg[dst]) == 1 and len(reg[dst][0]) == 1, "NE layout changed: review the fix"
    reg[src] = [p for p in reg[src] if p is not part[0]]
    reg[dst] = [[r] for r in dissolve([reg[dst][0][0], part[0][0]])]
    return reg


def load_districts(gb_meta):
    out = {}
    for f in fetch_json(gb_meta["simplifiedGeometryGeoJSON"])["features"]:
        name = f["properties"]["shapeName"].replace("а", "a").replace("А", "A").strip()  # homoglyphs
        name = DISTRICT_NAME_SWAPS.get(name, name)
        out[name] = [[open_ring(r) for r in poly] for poly in polys_of(f["geometry"])]
    return out


def assign_region(name, polys, regions):
    if name in DISTRICT_REGION_OVERRIDES:
        return DISTRICT_REGION_OVERRIDES[name]
    c = area_centroid(polys)
    order = ["UZ-TK"] + [k for k in regions if k != "UZ-TK"]
    hits = [k for k in order if point_in(*c, regions[k])]
    if hits:
        return hits[0]
    return min(regions, key=lambda k: min(seg_dist2(*c, *r[i], *r[i - 1])
                                          for poly in regions[k] for r in poly for i in range(len(r))))


def clean_uz(s):
    for a in APOSTROPHES:
        s = s.replace(a, "'")
    s = re.sub(r"\s+", " ", s).strip()
    s = re.sub(r"(\S)shahri$", r"\1 shahri", s)
    return re.sub(r" shahar$", " shahri", s)


def load_siat_districts():
    d = fetch_json(SIAT_URL)
    d = d[0] if isinstance(d, list) else d
    out = defaultdict(list)
    for row in d["data"]:
        code = str(row["Code"])
        if len(code) == 7:
            out[code[:4]].append((code, clean_uz(row["Klassifikator"])))
    return out


def is_city(s):
    return bool(re.search(r"(city|shahri)$", s))


def phon(s):
    s = re.sub(r"\s*(tumani|shahri|city)$", "", s.lower())
    s = s.replace("o'", "u").replace("g'", "g").replace("'", "").replace(" ", "").replace("-", "")
    for a, b in (("dzh", "j"), ("dj", "j"), ("zh", "j"), ("kh", "x"), ("q", "k"), ("o", "a"), ("y", "i"), ("e", "i")):
        s = s.replace(a, b)
    return s


def match_names(names, candidates):
    """Greedy best-similarity match: source name -> (SOATO code, official Uzbek name, score) within one region."""
    by_name = {u: c for c, u in candidates}
    res = {n: (by_name[NAME_OVERRIDES[n]], NAME_OVERRIDES[n], 1.0) for n in names if n in NAME_OVERRIDES}
    used = {v[1] for v in res.values()}
    pairs = sorted(((difflib.SequenceMatcher(None, phon(n), phon(u)).ratio(), n, c, u)
                    for n in names if n not in res for c, u in candidates if is_city(n) == is_city(u)), reverse=True)
    for score, n, c, u in pairs:
        if n not in res and u not in used:
            res[n] = (c, u, score)
            used.add(u)
    assert set(res) == set(names), sorted(set(names) - set(res))
    return res, [u for c, u in candidates if u not in used]


# ------------------------------------------------------------------ build
def build_regions(regions, to_screen):
    rings = [r for ps in regions.values() for poly in ps for r in poly]
    scr = {p: to_screen(*p) for r in rings for p in r}
    kept = simplify_shared(rings, scr, REGION_TOL_PX)
    out = []
    for rid, soato, slug, uz, ru, en in REGIONS:
        polys = project_polys(regions[rid], kept, scr, REGION_DECIMALS)
        label = polylabel(max(polys, key=lambda p: abs(signed_area(p[0]))))
        out.append({"id": rid, "soato": soato, "slug": slug, "nameUz": uz, "nameRu": ru, "nameEn": en,
                    "d": path_d(polys, REGION_DECIMALS), "centroid": inside_point(polys, 1),
                    "label": [round(label[0], 1), round(label[1], 1)], "bbox": bbox(polys, 1), "_polys": polys})
    return out


def build_districts(districts, regions, to_screen):
    rings = [r for ps in districts.values() for poly in ps for r in poly]
    scr = {p: to_screen(*p) for r in rings for p in r}
    kept = simplify_shared(rings, scr, DISTRICT_TOL_PX)
    grouped = defaultdict(list)
    for name, polys in districts.items():
        grouped[assign_region(name, polys, regions)].append(name)
    counts = {k: len(v) for k, v in grouped.items()}
    assert counts == EXPECTED_DISTRICTS, counts
    siat = load_siat_districts()
    out, missing, matches_all = {}, {}, []
    for rid, soato, *_ in REGIONS:
        matches, missing[rid] = match_names(grouped[rid], siat[soato])
        items = []
        for name in sorted(grouped[rid], key=lambda n: matches[n][1]):
            code, uz, score = matches[name]
            matches_all.append((round(score, 2), rid, name, uz))
            polys = project_polys(districts[name], kept, scr, DISTRICT_DECIMALS)
            items.append({"id": code, "name": uz, "nameSrc": name, "d": path_d(polys, DISTRICT_DECIMALS),
                          "centroid": inside_point(polys, DISTRICT_DECIMALS), "_polys": polys})
        out[rid] = {"bbox": bbox([p for it in items for p in it["_polys"]], DISTRICT_DECIMALS), "districts": items}
    return out, {k: v for k, v in missing.items() if v}, matches_all


# ------------------------------------------------------------------ output
def public(obj):
    return {k: v for k, v in obj.items() if not k.startswith("_")}


def to_json(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n"


def regions_doc(regions, height, proj):
    return {"viewBox": f"0 0 {VIEW_W} {height}", "width": VIEW_W, "height": height, "fillRule": "evenodd",
            "projection": proj, "source": REGION_SOURCE, "license": "Public domain (Natural Earth)",
            "simplification": f"topology-preserving Douglas-Peucker, {REGION_TOL_PX}px, {REGION_DECIMALS} decimal",
            "fields": "centroid: area centroid (always inside); label: pole of inaccessibility; "
                      "bbox: [minX,minY,maxX,maxY]; soato: stat.uz region code",
            "notes": REGION_NOTES, "regions": [public(r) for r in regions]}


def districts_doc(districts, missing, height, gb):
    return {"viewBox": f"0 0 {VIEW_W} {height}", "frame": "same projected coordinates as uz-regions.json",
            "fillRule": "evenodd", "attribution": DISTRICT_ATTRIBUTION, "license": gb["boundaryLicense"],
            "boundarySource": gb["boundarySource"], "boundaryYear": gb["boundaryYearRepresented"],
            "sourceUrl": gb["simplifiedGeometryGeoJSON"],
            "simplification": f"topology-preserving Douglas-Peucker, {DISTRICT_TOL_PX}px, {DISTRICT_DECIMALS} decimals",
            "fields": "id: SOATO code; name: official Uzbek name (SIAT); nameSrc: source (OCHA) name; "
                      "centroid: always inside; bbox per region: [minX,minY,maxX,maxY]",
            "notes": DISTRICT_NOTES, "missingGeometry": missing,
            "regions": {rid: {"bbox": g["bbox"], "districts": [public(d) for d in g["districts"]]}
                        for rid, g in districts.items()}}


def preview_svg(height, shapes, labels):
    head = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {VIEW_W} {height}" width="{VIEW_W}" '
            f'height="{height}"><rect width="100%" height="100%" fill="#ffffff"/>')
    paths = "".join(f'<path d="{d}" fill="{fill}" fill-rule="evenodd" stroke="#ffffff" stroke-width="{sw}"/>'
                    for d, fill, sw in shapes)
    texts = "".join(f'<text x="{x}" y="{y}" font-family="Helvetica,Arial,sans-serif" font-size="11" '
                    f'text-anchor="middle" fill="#111111">{escape(t)}</text>' for (x, y), t in labels)
    return head + paths + texts + "</svg>\n"


def write_outputs(out_dir, regions, districts, missing, height, proj, gb):
    out_dir.mkdir(parents=True, exist_ok=True)
    colors = {r["id"]: PALETTE[i] for i, r in enumerate(regions)}
    labels = [(r["label"], r["nameUz"].replace(" viloyati", "").replace(" Respublikasi", "")) for r in regions]
    files = {
        "uz-regions.json": to_json(regions_doc(regions, height, proj)),
        "uz-districts.json": to_json(districts_doc(districts, missing, height, gb)),
        "preview-regions.svg": preview_svg(height, [(r["d"], colors[r["id"]], 0.8) for r in regions], labels),
        "preview-districts.svg": preview_svg(
            height, [(d["d"], colors[rid], 0.3) for rid, g in districts.items() for d in g["districts"]], labels),
    }
    for name, text in files.items():
        (out_dir / name).write_text(text, encoding="utf-8")
        print(f"wrote {out_dir / name} ({len(text.encode('utf-8')):,} bytes)")


def print_summary(regions, districts, missing, matches, height):
    rbytes = sum(len(r["d"]) for r in regions)
    dbytes = sum(len(d["d"]) for g in districts.values() for d in g["districts"])
    print(f"viewBox 0 0 {VIEW_W} {height}")
    print(f"regions: {len(regions)}, path bytes {rbytes:,} (budget {REGION_BUDGET:,})")
    for r in regions:
        print(f"  {r['id']} {r['nameUz']:<30} parts={len(r['_polys'])} d={len(r['d']):>5} "
              f"centroid={r['centroid']} label={r['label']} bbox={r['bbox']}")
    tk, to = regions[-1], next(r for r in regions if r["id"] == "UZ-TO")
    print("UZ-TK drawn last:", tk["id"] == "UZ-TK", "| TK centroid not under UZ-TO fill:",
          not point_in(*tk["centroid"], to["_polys"]))
    print(f"districts: {sum(len(g['districts']) for g in districts.values())}, path bytes {dbytes:,} "
          f"(budget {DISTRICT_BUDGET:,})", {rid: len(g["districts"]) for rid, g in districts.items()})
    print("weakest name matches:", sorted(matches)[:6])
    if os.environ.get("GEO_VERBOSE"):
        for m in sorted(matches, key=lambda m: (m[1], m[2])):
            print("   ", m)
    print("SIAT units without 2020 geometry:", missing)
    assert rbytes <= REGION_BUDGET and dbytes <= DISTRICT_BUDGET, (rbytes, dbytes)


def main():
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    regions_ll = load_regions()
    gb = fetch_json(GB_API)
    districts_ll = load_districts(gb)
    to_screen, height, proj = make_screen([p for ps in regions_ll.values() for poly in ps for r in poly for p in r])
    regions = build_regions(regions_ll, to_screen)
    districts, missing, matches = build_districts(districts_ll, regions_ll, to_screen)
    print_summary(regions, districts, missing, matches, height)
    if out_dir:
        write_outputs(out_dir, regions, districts, missing, height, proj, gb)
    else:
        print("dry run: nothing written (pass OUT_DIR to write files)")


if __name__ == "__main__":
    main()
