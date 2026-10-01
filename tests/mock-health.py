"""Fake OpenViking /health server for tests (GET /health -> 200 ok)."""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port = int(sys.argv[1]) if len(sys.argv) > 1 else 1933


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"status":"ok"}' if self.path == "/health" else b'{}'
        code = 200 if self.path == "/health" else 404
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", port), H).serve_forever()
