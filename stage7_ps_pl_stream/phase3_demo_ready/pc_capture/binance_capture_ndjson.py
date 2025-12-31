#!/usr/bin/env python3
import argparse
import asyncio
import json
import time
from datetime import datetime, timezone

import websockets

BINANCE_WS_BASE = "wss://stream.binance.com:9443/ws"

async def capture(symbol: str, seconds: int, out_path: str):
    symbol_lc = symbol.lower()
    stream = f"{symbol_lc}@depth"  # diff depth
    url = BINANCE_WS_BASE

    start_ms = int(time.time() * 1000)
    meta = {
        "type": "meta",
        "schema_version": "ndjson.v0",
        "symbol": symbol.upper(),
        "stream": stream,
        "start_unix_ms": start_ms,
        "start_utc": datetime.now(timezone.utc).isoformat(),
        "source": "binance_spot_ws",
    }

    deadline = time.time() + seconds
    n = 0

    async with websockets.connect(url, ping_interval=20, ping_timeout=20) as ws:
        sub = {"method": "SUBSCRIBE", "params": [stream], "id": 1}
        await ws.send(json.dumps(sub))

        with open(out_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(meta, separators=(",", ":")) + "\n")

            while time.time() < deadline:
                msg = await ws.recv()
                # msg is a JSON string
                f.write(msg.strip() + "\n")
                n += 1

    end_ms = int(time.time() * 1000)
    print(f"captured_messages={n} duration_s={seconds} start_ms={start_ms} end_ms={end_ms} out={out_path}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", default="BTCUSDT")
    ap.add_argument("--seconds", type=int, default=30)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    if args.out is None:
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        args.out = f"sample_{args.symbol.lower()}_{ts}.ndjson"

    asyncio.run(capture(args.symbol, args.seconds, args.out))

if __name__ == "__main__":
    main()
