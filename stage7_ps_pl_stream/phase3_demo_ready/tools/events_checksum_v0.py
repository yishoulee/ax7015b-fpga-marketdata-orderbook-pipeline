#!/usr/bin/env python3
# stage7_ps_pl_stream/phase3_demo_ready/tools/events_checksum_v0.py

import argparse
import hashlib
import struct
from pathlib import Path

MAGIC = b"EVT0BIN\x00"
HEADER_SIZE = 64
RECORD_SIZE = 48

HDR_STRUCT = struct.Struct("<8sIIQQ16s16s")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="in_path", required=True)
    ap.add_argument("--every", type=int, default=10000)
    ap.add_argument("--max", type=int, default=0, help="0 = no limit")
    args = ap.parse_args()

    p = Path(args.in_path)
    with p.open("rb") as f:
        hdr = f.read(HEADER_SIZE)
        if len(hdr) != HEADER_SIZE:
            raise SystemExit("file too small for header")

        magic, version, rec_size, price_scale, qty_scale, sym16, _ = HDR_STRUCT.unpack(hdr)
        if magic != MAGIC:
            raise SystemExit("bad magic")
        if version != 0:
            raise SystemExit(f"unsupported version {version}")
        if rec_size != RECORD_SIZE:
            raise SystemExit(f"unexpected record_size {rec_size}")

        symbol = sym16.split(b"\x00", 1)[0].decode("ascii", errors="replace")
        print(f"symbol={symbol} price_scale={price_scale} qty_scale={qty_scale} every={args.every}")

        h = hashlib.sha256()
        rec_count = 0
        byte_count = 0

        while True:
            if args.max and rec_count >= args.max:
                break

            rec = f.read(RECORD_SIZE)
            if not rec:
                break
            if len(rec) != RECORD_SIZE:
                raise SystemExit("truncated record")

            h.update(rec)
            rec_count += 1
            byte_count += RECORD_SIZE

            if rec_count % args.every == 0:
                print(f"records={rec_count} bytes={byte_count} sha256={h.hexdigest()}")

        print(f"done records={rec_count} bytes={byte_count} sha256_final={h.hexdigest()}")

if __name__ == "__main__":
    main()
