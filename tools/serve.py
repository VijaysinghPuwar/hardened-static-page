#!/usr/bin/env python3
"""Serve the site locally with the response headers from _headers applied.

Cloudflare Pages and Netlify both read that file in production; this applies
the same rules so the CSP can be tested before it ships rather than after.

    python3 tools/serve.py [port]
"""
import functools
import http.server
import mimetypes
import os
import posixpath
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Python's table is missing the ones that matter most here.
mimetypes.add_type("image/avif", ".avif")
mimetypes.add_type("image/webp", ".webp")
mimetypes.add_type("font/woff2", ".woff2")


def parse_headers_file(path):
    """[(pattern, [(name, value), ...]), ...] in file order."""
    rules, pattern, headers = [], None, []
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.strip().startswith("#"):
            continue
        if not line[0].isspace():
            if pattern is not None:
                rules.append((pattern, headers))
            pattern, headers = line.strip(), []
        elif ":" in line:
            name, _, value = line.strip().partition(":")
            headers.append((name.strip(), value.strip()))
    if pattern is not None:
        rules.append((pattern, headers))
    return rules


def matches(pattern, url_path):
    if pattern.endswith("/*"):
        return url_path.startswith(pattern[:-1])
    if pattern == "/*":
        return True
    return pattern == url_path


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, rules=(), **kw):
        self.rules = rules
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        url_path = posixpath.normpath(self.path.split("?", 1)[0])
        if url_path.endswith("/index.html"):
            url_path = url_path[: -len("index.html")]
        # Later matches win, so a specific path can override /*.
        applied = {}
        for pattern, headers in self.rules:
            if matches(pattern, url_path):
                for name, value in headers:
                    applied[name] = value
        for name, value in applied.items():
            self.send_header(name, value)
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("  %s\n" % (fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    rules = parse_headers_file(os.path.join(ROOT, "_headers"))
    handler = functools.partial(Handler, rules=rules)
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"serving {ROOT} on http://127.0.0.1:{port} with {len(rules)} header rules")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
