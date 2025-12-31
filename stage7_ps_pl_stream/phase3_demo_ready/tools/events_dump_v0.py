#!/usr/bin/env python3
# stage7_ps_pl_stream/phase3_demo_ready/tools/events_dump_v0.py
#
# Minimal inspector for events.bin (event_t v0).
# Prints header + first N records in human-readable form (no floats).

import argparse
import struct
from decimal import Decimal
from pathlib import Path

MAGIC = b"EVT0BIN\x00"
HEADER_SIZE = 64
RECORD_SIZE = 48

HDR_STRUCT = struct.Struct("<8sIIQQ16s16s")
REC_STRUCT = struct.Struct("<B7xQQQqq")


def scaled_i64_to_str(x: int, scale: int) -> str:
    # exact decimal string without floats
    d = Decimal(x) / Decimal(scale)
    # normalize but keep plain formatting
    return format(d, "f")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="in_path", required=True, help="events.bin path")
    ap.add_argument("--n", type=int, default=10, help="number of records to print")
    args = ap.parse_args()

    p = Path(args.in_path)

    with p.open("rb") as f:
        hdr = f.read(HEADER_SIZE)
        if len(hdr) != HEADER_SIZE:
            raise RuntimeError("file too small for header")

        magic, version, rec_size, price_scale, qty_scale, sym16, _reserved16 = HDR_STRUCT.unpack(hdr)

        symbol = sym16.split(b"\x00", 1)[0].decode("ascii", errors="replace")

        print("HEADER")
        print(f"  magic        = {magic!r}")
        print(f"  version      = {version}")
        print(f"  record_size  = {rec_size}")
        print(f"  price_scale  = {price_scale}")
        print(f"  qty_scale    = {qty_scale}")
        print(f"  symbol       = {symbol}")

        if magic != MAGIC:
            raise RuntimeError("bad magic (not EVT0BIN\\0)")
        if version != 0:
            raise RuntimeError(f"unsupported version {version}")
        if rec_size != RECORD_SIZE:
            raise RuntimeError(f"unexpected record_size {rec_size} (expected {RECORD_SIZE})")

        print("")
        print("RECORDS")
        print("  idx side E_ms U u price qty (scaled_int)")

        for i in range(args.n):
            buf = f.read(RECORD_SIZE)
            if len(buf) == 0:
                print("  <EOF>")
                break
            if len(buf) != RECORD_SIZE:
                raise RuntimeError("truncated record")

            side, E, U, u, price_i64, qty_i64 = REC_STRUCT.unpack(buf)
            side_s = "BID" if side == 0 else "ASK" if side == 1 else f"UNK({side})"
            price_s = scaled_i64_to_str(price_i64, int(price_scale))
            qty_s = scaled_i64_to_str(qty_i64, int(qty_scale))

            print(
                f"  {i:04d} {side_s:3s} {E} {U} {u} "
                f"{price_s} {qty_s} (p={price_i64}, q={qty_i64})"
            )


if __name__ == "__main__":
    main()
