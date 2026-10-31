#!/usr/bin/env python3
import asyncio, os, sys
from pathlib import Path

PUBLIC = int(os.environ.get("PORT", "8080"))
BACKEND = int(os.environ.get("BACKEND_PORT", "8081"))
WSPATH = os.environ.get("WSPATH", "/events")
if not WSPATH.startswith("/"):
    WSPATH = "/" + WSPATH
ROOT = Path(os.environ.get("COVER_ROOT", "/opt/app/public"))
INDEX = ROOT / "index.html"
HTML = INDEX.read_bytes() if INDEX.is_file() else (
    b"<!doctype html><html><head><title>Site Probe</title></head>"
    b"<body><h1>Site Probe</h1><p>ok</p></body></html>"
)

async def pipe(a, b):
    try:
        while True:
            data = await a.read(65536)
            if not data:
                break
            b.write(data)
            await b.drain()
    except Exception:
        pass
    try:
        b.close()
    except Exception:
        pass

async def handle(reader, writer):
    try:
        req = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=30)
    except Exception:
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass
        return
    head = req.split(b"\r\n", 1)[0].decode("latin1", "replace")
    parts = head.split(" ")
    target = parts[1] if len(parts) > 1 else "/"
    path = target.split("?", 1)[0]
    if path == WSPATH or path.startswith(WSPATH + "/"):
        try:
            br, bw = await asyncio.open_connection("127.0.0.1", BACKEND)
        except Exception:
            writer.write(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            await writer.drain()
            writer.close()
            return
        bw.write(req)
        await bw.drain()
        await asyncio.gather(pipe(reader, bw), pipe(br, writer))
        return
    if path in ("/healthz", "/health", "/ready"):
        body = b"ok\n"
        ctype = b"text/plain; charset=utf-8"
    else:
        body = HTML
        ctype = b"text/html; charset=utf-8"
    writer.write(
        b"HTTP/1.1 200 OK\r\nContent-Type: " + ctype + b"\r\nContent-Length: "
        + str(len(body)).encode()
        + b"\r\nConnection: close\r\n\r\n"
        + body
    )
    await writer.drain()
    writer.close()
    try:
        await writer.wait_closed()
    except Exception:
        pass

async def main():
    server = await asyncio.start_server(handle, "0.0.0.0", PUBLIC)
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
