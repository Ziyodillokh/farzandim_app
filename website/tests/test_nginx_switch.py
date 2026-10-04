"""nginx_switch.py testlari: jonli konfiguratsiyani ko'rmasdan xavfsiz almashtirish.

Ishga tushirish: python3 -m unittest discover -s website/tests
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "deploy"))
import nginx_switch as ns  # noqa: E402

ROOT = "/var/www/parvoz-site"
DOMAIN = "farzandimedu.uz"
SITE_PATHS = ns.site_paths_from_files([
    "index.html", "404.html", "privacy.html", "oferta.html", "tolov-va-qaytarish.html",
    "account-deletion.html", "robots.txt", "favicon.ico", "apple-touch-icon.png",
    "assets/legal.css", "assets/img/logo.23d406ad.png",
])

# Jonli serverga o'xshash: '/' Node'ga proxy, ikki hujjat statik, qo'shtirnoq ichida qavslar.
LIVE_LIKE = r"""
# farzandimedu.uz { izohdagi qavs }
server {
    listen 80;
    server_name farzandimedu.uz www.farzandimedu.uz;
    if ($host = www.farzandimedu.uz) { return 301 https://$host$request_uri; }
    location / { return 301 https://${host}$request_uri; }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name farzandimedu.uz www.farzandimedu.uz;
    add_header X-Note "braces { inside } quotes";

    location /api {
        proxy_pass http://127.0.0.1:3100;
    }
    location /socket.io/ { proxy_pass http://127.0.0.1:3100; }
    location /storage/ { proxy_pass http://127.0.0.1:9100/; }
    location /kirolmaysan { proxy_pass http://127.0.0.1:3101; }
    location /app/ { alias /home/farzandim/new-platform/flutter/parent/; try_files $uri $uri/ /app/index.html; }
    location /child/ { alias /home/farzandim/new-platform/flutter/child/; }
    location = /privacy.html { root /var/www/farzandim-landing; }
    location = /account-deletion.html { root /var/www/farzandim-landing; }
    location = /health { return 200 '{"ok":true}'; }

    location / {
        proxy_pass http://127.0.0.1:3200;   # Lovable SSR
        proxy_set_header Host $host;
    }
}

server {
    listen 443 ssl;
    server_name test.farzandimedu.uz;
    location / { return 301 https://farzandimedu.uz$request_uri; }
}
"""


def switch(text: str):
    return ns.switch_config(text, domain=DOMAIN, root=ROOT, site_paths=SITE_PATHS)


class TokenizerTest(unittest.TestCase):
    def test_braces_in_quotes_comments_and_variables_are_not_blocks(self):
        tree = ns.parse(LIVE_LIKE)
        self.assertEqual([d.name for d in tree], ["server", "server", "server"])

    def test_unbalanced_braces_raise(self):
        with self.assertRaises(ns.SwitchError):
            ns.parse("server { location / { root /x; }")


class SwitchLiveLikeTest(unittest.TestCase):
    def setUp(self):
        self.out, self.report = switch(LIVE_LIKE)

    def test_root_location_now_serves_static_site(self):
        main = self.out.split("server_name farzandimedu.uz www.farzandimedu.uz;\n    add_header")[1]
        self.assertIn(f"root {ROOT};", main)
        self.assertIn("try_files $uri $uri.html $uri/ =404;", main)
        self.assertIn("error_page 404 /404.html;", main)
        self.assertNotIn("127.0.0.1:3200", main)
        self.assertIn(ns.MARKER, main)

    def test_overriding_document_locations_point_to_new_root(self):
        self.assertNotIn("/var/www/farzandim-landing", self.out)
        self.assertEqual(self.report.rewritten, ["= /privacy.html", "= /account-deletion.html"])

    def test_protected_and_unrelated_locations_untouched(self):
        for line in (
            "location /api {\n        proxy_pass http://127.0.0.1:3100;\n    }",
            "location /socket.io/ { proxy_pass http://127.0.0.1:3100; }",
            "location /storage/ { proxy_pass http://127.0.0.1:9100/; }",
            "location /kirolmaysan { proxy_pass http://127.0.0.1:3101; }",
            "location /app/ { alias /home/farzandim/new-platform/flutter/parent/; try_files $uri $uri/ /app/index.html; }",
            "location /child/ { alias /home/farzandim/new-platform/flutter/child/; }",
            "location = /health { return 200 '{\"ok\":true}'; }",
            'add_header X-Note "braces { inside } quotes";',
        ):
            self.assertIn(line, self.out)

    def test_port_80_and_other_domains_untouched(self):
        self.assertIn("location / { return 301 https://${host}$request_uri; }", self.out)
        self.assertIn("location / { return 301 https://farzandimedu.uz$request_uri; }", self.out)

    def test_result_parses_and_only_one_server_changed(self):
        ns.parse(self.out)
        self.assertEqual(self.report.servers_switched, 1)
        self.assertTrue(self.report.changed)

    def test_second_run_is_noop(self):
        again, report = switch(self.out)
        self.assertEqual(again, self.out)
        self.assertFalse(report.changed)


class SafetyTest(unittest.TestCase):
    def test_missing_root_location_aborts(self):
        conf = "server { listen 443 ssl; server_name farzandimedu.uz; location /api { proxy_pass http://x; } }"
        with self.assertRaisesRegex(ns.SwitchError, "location /"):
            switch(conf)

    def test_no_matching_server_aborts(self):
        with self.assertRaisesRegex(ns.SwitchError, "server"):
            switch("server { listen 443 ssl; server_name example.com; location / { root /x; } }")

    def test_protected_prefix_capturing_site_file_aborts(self):
        # '/app' (slash'siz) /apple-touch-icon.png ni ham ushlab qoladi — avtomatik hal qilib bo'lmaydi.
        conf = ("server { listen 443 ssl; server_name farzandimedu.uz; "
                "location /app { alias /srv/app/; } location / { proxy_pass http://x; } }")
        with self.assertRaisesRegex(ns.SwitchError, "/app"):
            switch(conf)

    def test_regex_location_for_documents_is_rewritten(self):
        conf = ("server { listen 443 ssl; server_name farzandimedu.uz; "
                "location ~ ^/(privacy|account-deletion)\\.html$ { root /var/www/old; } "
                "location / { proxy_pass http://x; } }")
        out, report = switch(conf)
        self.assertNotIn("/var/www/old", out)
        self.assertEqual(report.rewritten, ["~ ^/(privacy|account-deletion)\\.html$"])

    def test_regex_location_mixing_site_and_protected_paths_aborts(self):
        conf = ("server { listen 443 ssl; server_name farzandimedu.uz; "
                "location ~* \\.(js|css|png)$ { expires 7d; } location / { proxy_pass http://x; } }")
        with self.assertRaisesRegex(ns.SwitchError, "regex"):
            switch(conf)

    def test_extension_regex_that_also_serves_backend_files_aborts(self):
        # /storage/*.png, /api/**.png ham shu regex'ga tushadi — static root'ga o'tkazib bo'lmaydi.
        conf = ("server { listen 443 ssl; server_name farzandimedu.uz; "
                "location ~* \\.(png|svg|ico|webp)$ { proxy_pass http://b; } location / { proxy_pass http://x; } }")
        with self.assertRaisesRegex(ns.SwitchError, "regex"):
            switch(conf)

    def test_listen_8443_is_not_https_443(self):
        conf = "server { listen 8443 ssl; server_name farzandimedu.uz; location / { proxy_pass http://x; } }"
        with self.assertRaises(ns.NoMatch):
            switch(conf)

    def test_domain_file_with_only_redirect_blocks_is_no_match(self):
        conf = "server { listen 443 ssl; server_name farzandimedu.uz; return 301 https://example.uz; }"
        with self.assertRaises(ns.NoMatch):
            switch(conf)

    def test_redirect_only_443_block_is_skipped(self):
        conf = ("server { listen 443 ssl; server_name www.farzandimedu.uz; return 301 https://farzandimedu.uz$request_uri; }\n"
                "server { listen 443 ssl; server_name farzandimedu.uz; location / { proxy_pass http://x; } }")
        out, report = switch(conf)
        self.assertEqual(report.servers_switched, 1)
        self.assertIn("return 301 https://farzandimedu.uz$request_uri;", out)


class FileApiTest(unittest.TestCase):
    def test_main_rewrites_file_in_place_and_reports_change(self):
        with tempfile.TemporaryDirectory() as d:
            conf = Path(d) / "site.conf"
            conf.write_text(LIVE_LIKE)
            site = Path(d) / "site"
            (site / "assets").mkdir(parents=True)
            for f in ("index.html", "404.html", "privacy.html", "account-deletion.html"):
                (site / f).write_text("x")
            code = ns.main(["--conf", str(conf), "--domain", DOMAIN, "--root", ROOT, "--site", str(site)])
            self.assertEqual(code, ns.EXIT_CHANGED)
            self.assertIn(ns.MARKER, conf.read_text())
            code = ns.main(["--conf", str(conf), "--domain", DOMAIN, "--root", ROOT, "--site", str(site)])
            self.assertEqual(code, ns.EXIT_UNCHANGED)

    def test_main_redirect_only_domain_file_is_unchanged_with_allow_no_match(self):
        with tempfile.TemporaryDirectory() as d:
            conf = Path(d) / "redir.conf"
            conf.write_text("server { listen 443 ssl; server_name farzandimedu.uz; return 301 https://x.uz; }")
            code = ns.main(["--conf", str(conf), "--domain", DOMAIN, "--root", ROOT, "--site", d, "--allow-no-match"])
            self.assertEqual(code, ns.EXIT_UNCHANGED)

    def test_main_on_unrelated_file_is_unchanged(self):
        with tempfile.TemporaryDirectory() as d:
            conf = Path(d) / "other.conf"
            conf.write_text("server { listen 80; server_name other.uz; location / { root /x; } }")
            code = ns.main(["--conf", str(conf), "--domain", DOMAIN, "--root", ROOT, "--site", d, "--allow-no-match"])
            self.assertEqual(code, ns.EXIT_UNCHANGED)


if __name__ == "__main__":
    unittest.main()
