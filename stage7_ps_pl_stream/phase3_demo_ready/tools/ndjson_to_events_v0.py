#!/usr/bin/env python3
# stage7_ps_pl_stream/phase3_demo_ready/tools/ndjson_to_events_v0.py
#
# Deterministic NDJSON -> events.bin converter (event_t v0)
# - No floats: Decimal -> fixed-point int64 with exact scaling (no rounding)
# - Stable output: same NDJSON => identical events.bin (bitwise) => identical SHA256
#
# Binary format (little-endian):
# Header (64 bytes):
#   magic[8] = b"EVT0BIN\0"
#   version u32 = 0
#   record_size u32 = 48
#   price_scale u64
#   qty_scale u64
#   symbol[16] ASCII NUL-padded
#   reserved[16] zeros
#
# Record (48 bytes):
#   side u8 (0=bid, 1=ask)
#   pad[7]
#   event_time_ms u64 (E)
#   first_update_id u64 (U)
#   final_update_id u64 (u)
#   price_i64 (price * price_scale)
#   qty_i64   (qty   * qty_scale)

import argparse
import hashlib
import json
import struct
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Dict, Any, Iterable, Tuple

MAGIC = b"EVT0BIN\x00"
VERSION = 0
HEADER_SIZE = 64
RECORD_SIZE = 48

HDR_STRUCT = struct.Struct("<8sIIQQ16s16s")  # 64 bytes
REC_STRUCT = struct.Struct("<B7xQQQqq")      # 48 bytes


def _is_meta_line(obj: Any) -> bool:
    return isinstance(obj, dict) and obj.get("type") == "meta"


def _is_subscribe_ack(obj: Any) -> bool:
    # Binance subscribe ACK typically: {"result": null, "id": 1}
    return isinstance(obj, dict) and "result" in obj and "id" in obj


def _dec_to_scaled_i64(s: str, scale: int, what: str) -> int:
    try:
        d = Decimal(s)
    except InvalidOperation as e:
        raise ValueError(f"bad decimal for {what}: {s}") from e

    x = d * Decimal(scale)

    # Require exact integer after scaling (no rounding)
    if x != x.to_integral_value():
        raise ValueError(f"non-integer after scaling for {what}: {s} * {scale} = {x}")

    i = int(x)
    if i < -(1 << 63) or i > (1 << 63) - 1:
        raise ValueError(f"int64 overflow for {what}: {i}")
    return i


def _iter_depth_updates(fin: Iterable[str], symbol: str) -> Iterable[Dict[str, Any]]:
    for line in fin:
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)

        if _is_meta_line(obj) or _is_subscribe_ack(obj):
            continue

        # Expect diff depth payload
        if not isinstance(obj, dict):
            continue
        if obj.get("e") != "depthUpdate":
            continue
        if obj.get("s") != symbol:
            continue

        yield obj


def convert_ndjson_to_events(
    in_path: Path,
    out_path: Path,
    symbol: str,
    price_scale: int,
    qty_scale: int,
) -> Tuple[str, int, int, int]:
    symbol_b = symbol.encode("ascii", errors="strict")
    if len(symbol_b) > 16:
        raise ValueError("symbol too long (max 16 bytes ASCII)")
    sym16 = symbol_b + b"\x00" * (16 - len(symbol_b))
    reserved16 = b"\x00" * 16

    sha = hashlib.sha256()

    n_lines = 0
    n_msgs = 0
    n_recs = 0

    out_path.parent.mkdir(parents=True, exist_ok=True)

    with in_path.open("r", encoding="utf-8") as fin, out_path.open("wb") as fout:
        header = HDR_STRUCT.pack(
            MAGIC,
            VERSION,
            RECORD_SIZE,
            int(price_scale),
            int(qty_scale),
            sym16,
            reserved16,
        )
        if len(header) != HEADER_SIZE:
            raise RuntimeError("header packing error")
        fout.write(header)
        sha.update(header)

        for raw_line in fin:
            n_lines += 1
            # We re-parse in _iter_depth_updates, so pass lines through a tiny buffer:
            # (Keep it simple: handle per line here)
            line = raw_line.strip()
            if not line:
                continue
            obj = json.loads(line)

            if _is_meta_line(obj) or _is_subscribe_ack(obj):
                continue
            if not isinstance(obj, dict):
                continue
            if obj.get("e") != "depthUpdate":
                continue
            if obj.get("s") != symbol:
                continue

            # Required fields
            E = int(obj["E"])
            U = int(obj["U"])
            u = int(obj["u"])
            bids = obj.get("b", [])
            asks = obj.get("a", [])
            n_msgs += 1

            # Emit bids then asks, preserving array order (deterministic)
            for p_str, q_str in bids:
                p_i = _dec_to_scaled_i64(p_str, price_scale, "bid_price")
                q_i = _dec_to_scaled_i64(q_str, qty_scale, "bid_qty")
                rec = REC_STRUCT.pack(0, E, U, u, p_i, q_i)
                fout.write(rec)
                sha.update(rec)
                n_recs += 1

            for p_str, q_str in asks:
                p_i = _dec_to_scaled_i64(p_str, price_scale, "ask_price")
                q_i = _dec_to_scaled_i64(q_str, qty_scale, "ask_qty")
                rec = REC_STRUCT.pack(1, E, U, u, p_i, q_i)
                fout.write(rec)
                sha.update(rec)
                n_recs += 1

    digest = sha.hexdigest()
    return digest, n_lines, n_msgs, n_recs


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="in_path", required=True, help="input NDJSON path")
    ap.add_argument("--out", dest="out_path", required=True, help="output events.bin path")
    ap.add_argument("--symbol", default="BTCUSDT", help="symbol to keep (strict)")
    ap.add_argument("--price-scale", type=int, default=100_000_000)
    ap.add_argument("--qty-scale", type=int, default=100_000_000)
    ap.add_argument("--sha256-out", default=None, help="write SHA256 hex digest to this file")
    args = ap.parse_args()

    in_path = Path(args.in_path)
    out_path = Path(args.out_path)

    digest, n_lines, n_msgs, n_recs = convert_ndjson_to_events(
        in_path=in_path,
        out_path=out_path,
        symbol=args.symbol,
        price_scale=args.price_scale,
        qty_scale=args.qty_scale,
    )

    print(
        f"in={in_path} out={out_path} lines={n_lines} msgs={n_msgs} records={n_recs} sha256={digest}"
    )

    if args.sha256_out:
        sha_path = Path(args.sha256_out)
        sha_path.parent.mkdir(parents=True, exist_ok=True)
        sha_path.write_text(digest + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
