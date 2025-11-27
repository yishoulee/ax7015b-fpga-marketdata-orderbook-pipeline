# capture/capture_binance_depth.py

import asyncio
import json
import time
from typing import TextIO

import requests
import websockets
import sys
import pathlib

# Support running both as a package module and as a standalone script
if __package__ in (None, ""):
    this_dir = pathlib.Path(__file__).resolve().parent
    if str(this_dir) not in sys.path:
        sys.path.insert(0, str(this_dir))
    from config import (
        REST_DEPTH_URL,
        WS_DEPTH_STREAM_URL,
        LOG_FILE,
        FLUSH_INTERVAL,
        WS_MAX_SIZE,
    )
else:
    from .config import (
        REST_DEPTH_URL,
        WS_DEPTH_STREAM_URL,
        LOG_FILE,
        FLUSH_INTERVAL,
        WS_MAX_SIZE,
    )


def write_snapshot(fh: TextIO) -> None:
    """
    Fetch and write initial order book snapshot.

    Line format:
    #SNAP {"lastUpdateId": ..., "bids": [...], "asks": [...]}
    """
    resp = requests.get(REST_DEPTH_URL, timeout=10)
    resp.raise_for_status()
    snap = resp.json()
    fh.write("#SNAP " + json.dumps(snap, separators=(",", ":")) + "\n")


async def capture_loop() -> None:
    """
    Connect to Binance depth WebSocket, append records to LOG_FILE.

    Record format (CSV):
    ts_ns,updateId,side,price,qty

    - ts_ns: int (Python time.time_ns() at receive)
    - updateId: int (field 'u' from Binance diff depth stream)
    - side: 'B' for bid, 'A' for ask
    - price, qty: strings from Binance JSON (kept as text for exactness)
    """
    msg_counter = 0

    with open(LOG_FILE, "a", buffering=1) as fh:
        # Snapshot first
        write_snapshot(fh)
        fh.flush()

        async with websockets.connect(
            WS_DEPTH_STREAM_URL,
            max_size=WS_MAX_SIZE,
            ping_interval=20,
            ping_timeout=20,
        ) as ws:
            print(f"[capture] Connected to {WS_DEPTH_STREAM_URL}")
            async for msg in ws:
                ts_ns = time.time_ns()
                data = json.loads(msg)

                # Binance diff depth fields:
                # u: final update ID in event
                # b: bids [price, qty]
                # a: asks [price, qty]
                update_id = data["u"]

                # Write one line per (side, price, qty)
                for price, qty in data.get("b", []):
                    fh.write(f"{ts_ns},{update_id},B,{price},{qty}\n")

                for price, qty in data.get("a", []):
                    fh.write(f"{ts_ns},{update_id},A,{price},{qty}\n")

                msg_counter += 1
                if msg_counter % FLUSH_INTERVAL == 0:
                    fh.flush()
                    print(f"[capture] messages={msg_counter}", flush=True)


async def main() -> None:
    while True:
        try:
            await capture_loop()
        except (websockets.ConnectionClosed, websockets.WebSocketException) as e:
            print(f"[capture] WebSocket error: {e}. Reconnecting in 5s...")
            await asyncio.sleep(5)
        except Exception as e:
            print(f"[capture] Fatal error: {e}. Exiting.")
            raise


if __name__ == "__main__":
    asyncio.run(main())
