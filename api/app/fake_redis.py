"""A Redis-compatible server for local development: ``python -m app.fake_redis`` (``make redis-local``).

Backed by fakeredis' TCP server, so the API and the worker run as separate OS processes and talk to it
exactly as they would to a real Redis. Data lives in memory and is gone when this process stops.
Not for production, and not a place to test Redis-specific behaviour (the CI arq test uses real Redis).
"""

import os
import sys
import time

from fakeredis import TcpFakeServer

DEFAULT_PORT = 6390


def start(port: int | None = None) -> TcpFakeServer | None:
    """Starts the server in a background thread. Returns None if one is already listening there."""
    import socket
    import threading

    port = port or int(os.environ.get("FAKE_REDIS_PORT", DEFAULT_PORT))
    with socket.socket() as probe:
        if probe.connect_ex(("127.0.0.1", port)) == 0:
            return None  # someone (an earlier `make redis-local`) is already serving
    server = TcpFakeServer(("127.0.0.1", port), server_type="redis")
    threading.Thread(target=server.serve_forever, daemon=True, name="fake-redis").start()
    return server


def main() -> int:
    server = start()
    port = int(os.environ.get("FAKE_REDIS_PORT", DEFAULT_PORT))
    if server is None:
        print(f"a Redis is already listening on 127.0.0.1:{port}", file=sys.stderr)
        return 1
    print(f"fake Redis on redis://127.0.0.1:{port}/0  (Ctrl-C to stop)", file=sys.stderr)
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
