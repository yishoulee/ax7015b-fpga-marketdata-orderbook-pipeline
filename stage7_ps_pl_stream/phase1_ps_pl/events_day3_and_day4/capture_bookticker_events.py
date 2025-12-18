#!/usr/bin/env python3
import argparse
import asyncio
import struct
from decimal import Decimal, InvalidOperation
import websockets

MAGIC = 0x30545645  # "EVT0"
PRICE_SCALE = Decimal("1e4")
QTY_SCALE   = Decimal("1e4")
U32_MAX = 0xFFFFFFFF

def to_u32_pips(x_str: str, scale: Decimal) -> int:
    try:
        x = Decimal(x_str)
    except InvalidOperation:
        return 0
    v = int((x * scale).to_integral_value(rounding="ROUND_HALF_UP"))
    if v < 0:
        return 0
    if v > U32_MAX:
        return U32_MAX
    return v

async def capture(symbol: str, out_path: str, count: int):
    stream = f"{symbol.lower()}@bookTicker"
    url = f"wss://stream.binance.com:9443/ws/{stream}"

    seq = 0
    written = 0

    with open(out_path, "wb") as f:
        async with websockets.connect(url, ping_interval=180, ping_timeout=600) as ws:
            while written < count:
                msg = await ws.recv()  # JSON string
                # Minimal JSON parsing without heavy overhead
                # We only need fields: u, b, B, a, A
                # Use python json for correctness.
                import json
                j = json.loads(msg)

                u = int(j.get("u", 0)) & 0xFFFFFFFF
                b = to_u32_pips(j.get("b", "0"), PRICE_SCALE)
                B = to_u32_pips(j.get("B", "0"), QTY_SCALE)
                a = to_u32_pips(j.get("a", "0"), PRICE_SCALE)
                A = to_u32_pips(j.get("A", "0"), QTY_SCALE)

                words = (MAGIC, seq & 0xFFFFFFFF, u, 0, b, B, a, A)
                f.write(struct.pack("<8I", *words))

                seq += 1
                written += 1

                if (written % 100) == 0:
                    print(f"captured {written}/{count}")

    print(f"wrote {written} events to {out_path} ({written*32} bytes)")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--symbol", default="BTCUSDT")
    ap.add_argument("--out", default="events.bin")
    ap.add_argument("--count", type=int, default=1000)
    args = ap.parse_args()
    asyncio.run(capture(args.symbol, args.out, args.count))

if __name__ == "__main__":
    main()
