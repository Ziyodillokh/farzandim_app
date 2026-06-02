# -*- coding: utf-8 -*-
# Farzandim UI preview uchun tezkor statik server.
# - gzip siqish (brauzer so'rasa) -> JS/wasm ~3-4x kichik uzatiladi
# - gzip natijasini keshlaydi (qayta siqmaydi)
# - threaded (parallel asset yuklash)
# - SPA fallback (nomalum yol -> index.html)
# - Cache-Control (qayta yuklashda tez)
import gzip
import io
import os
import socketserver
import http.server

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')
PORT = 5050
GZIP_EXT = ('.js', '.json', '.wasm', '.html', '.css', '.svg', '.ttf', '.otf', '.map')
_cache = {}  # path -> (mtime, gzipped_bytes)


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=DIR, **k)

    def log_message(self, *a):
        pass

    def do_GET(self):
        rel = self.path.split('?')[0]
        path = self.translate_path(rel)
        if not os.path.isfile(path):
            idx = os.path.join(path, 'index.html')
            path = idx if os.path.isdir(path) and os.path.isfile(idx) \
                else os.path.join(DIR, 'index.html')
        try:
            mtime = os.path.getmtime(path)
            with open(path, 'rb') as f:
                raw = f.read()
        except OSError:
            self.send_error(404)
            return

        ctype = self.guess_type(path)
        # ETag = mtime + hajm. O'zgarmasa brauzer 304 oladi (tez), build
        # yangilansa avtomatik qayta yuklanadi (eski kesh muammosi yo'q).
        etag = '"%d-%d"' % (int(mtime), len(raw))
        if self.headers.get('If-None-Match') == etag:
            self.send_response(304)
            self.send_header('ETag', etag)
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            return

        want_gzip = 'gzip' in self.headers.get('Accept-Encoding', '') \
            and path.endswith(GZIP_EXT)

        if want_gzip:
            cached = _cache.get(path)
            if cached and cached[0] == mtime:
                body = cached[1]
            else:
                buf = io.BytesIO()
                with gzip.GzipFile(fileobj=buf, mode='wb', compresslevel=6) as g:
                    g.write(raw)
                body = buf.getvalue()
                _cache[path] = (mtime, body)
        else:
            body = raw

        self.send_response(200)
        self.send_header('Content-Type', ctype)
        if want_gzip:
            self.send_header('Content-Encoding', 'gzip')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('ETag', etag)
        # no-cache = har safar ETag bilan tekshiradi (o'zgarmasa 304 → tez).
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        self.wfile.write(body)


def main():
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(('0.0.0.0', PORT), Handler) as httpd:
        print(f'Serving {DIR} on http://0.0.0.0:{PORT}')
        httpd.serve_forever()


if __name__ == '__main__':
    main()
