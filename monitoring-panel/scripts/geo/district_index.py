#!/usr/bin/env python3
"""
Tumanlar indeksini (id, nom — geometriyasiz) uz-districts.ts dan ajratib yozadi.
Model va jadvallar faqat indeksni import qiladi; og'ir geometriya (SVG path)
faqat tumanlar xaritasi ochilganda alohida bo'lak sifatida yuklanadi.

  python3 scripts/geo/district_index.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src/data/geo/uz-districts.ts"
OUT = ROOT / "src/data/geo/uz-district-index.ts"

text = SRC.read_text(encoding="utf-8")


def section(name: str) -> str:
    start = text.index(f"export const {name}")
    end = text.find("\nexport const ", start + 1)
    return text[start:] if end == -1 else text[start:end]


# Yangi tumanlar — sof JSON qiymat.
missing_src = section("DISTRICTS_WITHOUT_GEOMETRY")
missing = json.loads(missing_src[missing_src.index("=") + 1 :].strip().rstrip(";"))

# Geometriya — har hudud bloki `"UZ-XX": {` bilan boshlanadi, ichida `{ id: "…", name: "…"` yozuvlari.
shapes_src = section("UZ_DISTRICT_SHAPES")
index = {}
region = None
for line in shapes_src.splitlines():
    rm = re.match(r'\s*"(UZ-[A-Z]{2})":\s*\{', line)
    if rm:
        region = rm.group(1)
        index[region] = []
        continue
    dm = re.match(r'\s*\{\s*id:\s*"([^"]+)",\s*name:\s*"([^"]+)"', line)
    if dm and region:
        index[region].append({"id": dm.group(1), "name": dm.group(2)})
if len(index) != 14:
    raise SystemExit(f"kutilgan 14 hudud, topildi {len(index)}")

OUT.write_text(
    "// AVTOMATIK yaratilgan: scripts/geo/district_index.py (uz-districts.ts dan). Qo'lda tahrirlamang.\n"
    "// Tumanlar ro'yxati geometriyasiz — model va jadvallar uchun yengil modul.\n\n"
    "export type DistrictIndexEntry = { id: string; name: string };\n\n"
    "/** Hudud → xaritada chegarasi bor tumanlar (id, rasmiy nom). */\n"
    f"export const UZ_DISTRICT_INDEX: Readonly<Record<string, readonly DistrictIndexEntry[]>> = {json.dumps(index, ensure_ascii=False)};\n\n"
    "/** 2020 yildan keyin tuzilgan, chegarasi hali yo'q tumanlar (ro'yxatda bor, xaritada yo'q). */\n"
    f"export const DISTRICTS_WITHOUT_GEOMETRY: Readonly<Record<string, readonly string[]>> = {json.dumps(missing, ensure_ascii=False)};\n",
    encoding="utf-8",
)
print(f"{OUT.relative_to(ROOT)}: {sum(len(v) for v in index.values())} tuman, {sum(len(v) for v in missing.values())} yangi")
