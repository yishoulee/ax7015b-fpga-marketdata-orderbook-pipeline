# depth_cpu_normalizer.py
from dataclasses import dataclass
from typing import Iterable, Iterator, Literal
import json
import math

Side = Literal["BID", "ASK"]

@dataclass
class DepthEvent:
    update_id: int
    side: Side
    price_fp: int
    qty_fp: int

    # optional extra fields if you want full match:
    ts_rx_ns: int = 0
    symbol_id: int = 0
    flags: int = 0

PRICE_SCALE = 1_000_000  # 1e-6
QTY_SCALE   = 1_000_000  # same as you used in Stage 2

def float_to_fp(x: float, scale: int) -> int:
    return int(round(x * scale))

def iter_binance_depth_events(path: str) -> Iterator[DepthEvent]:
    """
    Assumes each line of `path` is one JSON Binance depthUpdate message.

    For each bid/ask level in the event, we emit one DepthEvent.
    """
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            msg = json.loads(line)

            # update_id: use 'u' (final update ID) – consistent with Binance docs
            # If your TLV uses 'U'/'lastUpdateId' instead, swap accordingly.
            # docs: https: developers.binance.com/docs/... depth streams
            u = int(msg["u"])

            # Bids: side = BID
            for price_str, qty_str in msg.get("b", []):
                price = float(price_str)
                qty = float(qty_str)
                price_fp = float_to_fp(price, PRICE_SCALE)
                qty_fp   = float_to_fp(qty, QTY_SCALE)
                yield DepthEvent(
                    update_id=u,
                    side="BID",
                    price_fp=price_fp,
                    qty_fp=qty_fp,
                )

            # Asks: side = ASK
            for price_str, qty_str in msg.get("a", []):
                price = float(price_str)
                qty = float(qty_str)
                price_fp = float_to_fp(price, PRICE_SCALE)
                qty_fp   = float_to_fp(qty, QTY_SCALE)
                yield DepthEvent(
                    update_id=u,
                    side="ASK",
                    price_fp=price_fp,
                    qty_fp=qty_fp,
                )
