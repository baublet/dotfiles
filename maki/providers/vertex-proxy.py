#!/usr/bin/env python3
"""Signature-preserving proxy between Maki and Vertex AI's native Gemini endpoint.

Gemini 3.x attaches an encrypted `thoughtSignature` to every functionCall it
returns, and *requires* that signature echoed back on the next turn or it 400s
("Function call is missing a thought_signature"). Maki's providers don't carry
that field across turns, so multi-turn tool calls break.

This proxy sits in the middle (Maki -> here -> Vertex). It:
  * captures `thoughtSignature` from each functionCall in responses, and
  * re-injects it into functionCall parts of later requests that lack one.

Maki never has to know about signatures. The proxy is launched per `sc` session
(see the `sc` shell function), so its cache is naturally scoped to one session
and can't leak a signature from one conversation into another.

Usage: vertex-proxy.py <port>
Env:   GOOGLE_VERTEX_LOCATION  (default: global) -> picks the Vertex host.
Auth is passed through untouched: Maki sends the Bearer token it already mints.
"""
import json
import os
import sys
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOCATION = os.environ.get("GOOGLE_VERTEX_LOCATION", "global")
HOST = "aiplatform.googleapis.com" if LOCATION == "global" else f"{LOCATION}-aiplatform.googleapis.com"

# (function name + canonical args) -> thoughtSignature, populated from responses.
SIG_CACHE = {}


def _key(fc):
    name = fc.get("name", "")
    args = fc.get("args", {})
    try:
        canon = json.dumps(args, sort_keys=True, separators=(",", ":"))
    except (TypeError, ValueError):
        canon = str(args)
    return name + "|" + canon


def _walk_parts(body):
    """Yield every part dict found under contents[]/candidates[] in a JSON body."""
    if not isinstance(body, dict):
        return
    for container_key in ("contents", "candidates"):
        for item in body.get(container_key, []) or []:
            content = item.get("content", item) if isinstance(item, dict) else None
            if not isinstance(content, dict):
                continue
            for part in content.get("parts", []) or []:
                if isinstance(part, dict):
                    yield part


def inject_signatures(raw):
    """Add cached thoughtSignatures to functionCall parts of a request body."""
    try:
        body = json.loads(raw)
    except (ValueError, TypeError):
        return raw
    changed = False
    for part in _walk_parts(body):
        fc = part.get("functionCall")
        if isinstance(fc, dict) and not part.get("thoughtSignature"):
            sig = SIG_CACHE.get(_key(fc))
            if sig:
                part["thoughtSignature"] = sig
                changed = True
    if not changed:
        return raw
    return json.dumps(body).encode("utf-8")


def capture_from_json(body):
    """Record thoughtSignatures attached to functionCall parts in a response body."""
    try:
        obj = json.loads(body) if isinstance(body, (str, bytes, bytearray)) else body
    except (ValueError, TypeError):
        return
    for part in _walk_parts(obj):
        fc = part.get("functionCall")
        sig = part.get("thoughtSignature")
        if isinstance(fc, dict) and sig:
            SIG_CACHE[_key(fc)] = sig


def capture_from_sse(text):
    """Record signatures from streamed `data: {json}` lines."""
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("data:"):
            payload = line[5:].strip()
            if payload and payload != "[DONE]":
                capture_from_json(payload)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass  # stay quiet

    def _proxy(self, method):
        length = int(self.headers.get("Content-Length", 0) or 0)
        raw = self.rfile.read(length) if length else b""
        if raw:
            raw = inject_signatures(raw)

        url = f"https://{HOST}{self.path}"
        out_headers = {}
        for k, v in self.headers.items():
            if k.lower() in ("host", "content-length", "connection", "accept-encoding"):
                continue
            out_headers[k] = v
        req = urllib.request.Request(url, data=raw if raw else None, headers=out_headers, method=method)

        try:
            upstream = urllib.request.urlopen(req)
            status = upstream.status
        except urllib.error.HTTPError as e:
            upstream = e
            status = e.code
        except urllib.error.URLError as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f"proxy upstream error: {e}".encode())
            return

        ctype = upstream.headers.get("Content-Type", "application/octet-stream")
        is_stream = "event-stream" in ctype or "streamGenerateContent" in self.path

        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        collected = bytearray()
        try:
            while True:
                chunk = upstream.read(8192)
                if not chunk:
                    break
                collected.extend(chunk)
                # chunked framing
                self.wfile.write(b"%X\r\n%s\r\n" % (len(chunk), chunk))
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            return

        # Capture signatures from whatever we just relayed.
        if status == 200:
            if is_stream:
                capture_from_sse(collected.decode("utf-8", "replace"))
            else:
                capture_from_json(bytes(collected))

    def do_POST(self):
        self._proxy("POST")

    def do_GET(self):
        self._proxy("GET")


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    # If port was 0, print the chosen one (not used by sc, which picks the port).
    if port == 0:
        print(server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
