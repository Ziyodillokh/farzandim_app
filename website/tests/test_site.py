"""website/public yaxlitligi: havolalar, rasmlar, huquqiy sahifalar, hajm byudjeti.

Ishga tushirish: python3 -m unittest discover -s website/tests
"""
import json
import re
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

PUBLIC = Path(__file__).resolve().parents[1] / "public"
HTML_FILES = sorted(PUBLIC.glob("*.html"))
LEGAL_PAGES = ["privacy.html", "oferta.html", "tolov-va-qaytarish.html", "account-deletion.html"]
INDEX_BUDGET_BYTES = 300_000  # rasmlar ichiga qaytib kirib qolmasin (asl fayl 5.9 MB edi)


class _Refs(HTMLParser):
    def __init__(self):
        super().__init__()
        self.refs, self.ids = [], set()

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        for key in ("href", "src"):
            if a.get(key):
                self.refs.append((tag, a[key]))


def parse(path: Path) -> _Refs:
    p = _Refs()
    p.feed(path.read_text(encoding="utf-8"))
    return p


def resolve_local(url: str):
    """Ichki URL -> public/ dagi fayl (nginx: $uri, $uri.html, katalog/index.html)."""
    u = urlparse(url)
    if u.scheme or u.netloc and u.netloc != "farzandimedu.uz":
        return None
    path = u.path or "/"
    if not path.startswith("/"):
        return None
    rel = path.lstrip("/")
    for cand in (PUBLIC / rel, PUBLIC / f"{rel}.html", PUBLIC / rel / "index.html"):
        if cand.is_file():
            return cand
    return False


class LinksTest(unittest.TestCase):
    def test_every_internal_href_and_src_exists(self):
        broken = []
        for f in HTML_FILES:
            for tag, ref in parse(f).refs:
                if ref.startswith(("#", "mailto:", "tel:", "data:")):
                    continue
                target = resolve_local(ref) if not ref.startswith("https://farzandimedu.uz") else \
                    resolve_local(urlparse(ref).path)
                if target is False:
                    broken.append(f"{f.name}: <{tag}> {ref}")
        self.assertEqual(broken, [])

    def test_in_page_anchors_exist(self):
        for f in HTML_FILES:
            p = parse(f)
            for _, ref in p.refs:
                if ref.startswith("#") and len(ref) > 1:
                    self.assertIn(ref[1:], p.ids, f"{f.name}: {ref}")

    def test_js_image_urls_exist(self):
        text = (PUBLIC / "index.html").read_text(encoding="utf-8")
        urls = set(re.findall(r"""["'](/assets/img/[^"']+)["']""", text))
        self.assertGreaterEqual(len(urls), 20)
        missing = [u for u in urls if not (PUBLIC / u.lstrip("/")).is_file()]
        self.assertEqual(missing, [])

    def test_sitemap_urls_resolve(self):
        locs = re.findall(r"<loc>([^<]+)</loc>", (PUBLIC / "sitemap.xml").read_text())
        self.assertEqual(len(locs), 6)
        for loc in locs:
            self.assertTrue(resolve_local(urlparse(loc).path), loc)

    def test_manifest_icons_exist(self):
        m = json.loads((PUBLIC / "manifest.json").read_text())
        for icon in m["icons"]:
            self.assertTrue((PUBLIC / icon["src"].lstrip("/")).is_file(), icon["src"])


class ContentTest(unittest.TestCase):
    def test_index_has_no_inline_images_and_fits_budget(self):
        data = (PUBLIC / "index.html").read_bytes()
        self.assertNotIn(b";base64,", data)
        self.assertLess(len(data), INDEX_BUDGET_BYTES)

    def test_index_links_every_legal_page_and_store(self):
        text = (PUBLIC / "index.html").read_text(encoding="utf-8")
        for page in LEGAL_PAGES:
            self.assertIn(f'href="/{page}"', text)
        for store in ("apps.apple.com/app/id6798972223", "id=com.farzandim.parent", "id=com.farzandim.growth"):
            self.assertIn(store, text)
        self.assertIn('<link rel="canonical" href="https://farzandimedu.uz/">', text)

    def test_legal_pages_keep_company_details(self):
        for page in LEGAL_PAGES:
            text = (PUBLIC / page).read_text(encoding="utf-8")
            self.assertIn("farzandimtech@gmail.com", text, page)
            self.assertIn(f'<link rel="canonical" href="https://farzandimedu.uz/{page}">', text)
        oferta = (PUBLIC / "oferta.html").read_text(encoding="utf-8")
        for detail in ("313 060 726", "2020 8000 9074 7641 0001", "00083"):
            self.assertIn(detail, oferta)

    def test_future_plans_and_schools_are_linked(self):
        index = (PUBLIC / "index.html").read_text(encoding="utf-8")
        self.assertIn('id="kelajak"', index)
        self.assertIn("Kelajakdagi rejalar", index)
        self.assertIn("Parvoz Watch", index)
        self.assertIn('href="/maktablar"', index)
        school = (PUBLIC / "maktablar.html").read_text(encoding="utf-8")
        self.assertIn('<link rel="canonical" href="https://farzandimedu.uz/maktablar">', school)
        for section in ("imkoniyatlar", "maxfiylik", "hamkorlik", "kelajakda", "savollar", "aloqa"):
            self.assertIn(f'id="{section}"', school)

    def test_schools_page_marks_unbuilt_features_as_plans(self):
        """Maktab kabineti va jadval integratsiyasi hali yo'q — faqat 'Reja' bo'limida bo'lishi shart."""
        school = (PUBLIC / "maktablar.html").read_text(encoding="utf-8")
        plans = school.split('id="kelajakda"', 1)[1].split('id="savollar"', 1)[0]
        before_plans = school.split('id="kelajakda"', 1)[0]
        for planned in ("Maktab kabineti", "Elektron kundalik", "Davomat"):
            self.assertIn(planned, plans)
            self.assertNotIn(planned, before_plans)
        self.assertIn("Android", before_plans)  # bloklash cheklovi ochiq aytilgan

    def test_admin_path_is_not_disclosed(self):
        for f in PUBLIC.rglob("*"):
            if f.is_file() and f.suffix in {".html", ".txt", ".xml", ".json", ".css"}:
                self.assertNotIn("kirolmaysan", f.read_text(encoding="utf-8"), f.name)

    def test_no_internal_links_to_dead_parvoz_uz(self):
        for f in HTML_FILES:
            self.assertNotIn("parvoz.uz", f.read_text(encoding="utf-8"), f.name)


if __name__ == "__main__":
    unittest.main()
