# stage6_actions_compare.py
#
# Compare Stage 6 strategy actions (from FPGA ILA) vs a CPU reference
# implementation of:
#   - order book (best bid/ask)
#   - strategy_kernel_simple (IMB threshold = 1:1)
#
# This only checks the STRATEGY output, not the final risk_limiter gating.

import os
import sys
from typing import List, Tuple

import pandas as pd

# ----------------------------------------------------------------------
# Config: adjust these paths / column names to your setup
# ----------------------------------------------------------------------

HERE = os.path.abspath(os.path.dirname(__file__))

# Path to the tiny log used to drive Stage 6 (same as you replay over UART)
LOG_PATH = os.path.join(HERE, "binance_depth_tiny.log")

# Path to the exported ILA CSV from Stage 6 (actions + strategy probes)
ILA_CSV = os.path.join(HERE, "stage6_ila_tiny_strat_valid.csv")

# Column names in the ILA CSV.
# Open the CSV and copy the exact header strings here.
# These are EXAMPLES. You must replace them with what's in your CSV.
# Column names in the ILA CSV.
STRAT_VALID_COL  = "strat_valid"
STRAT_SIDE_COL   = "strat_side"
STRAT_PRICE_COL  = "strat_price[31:0]"
STRAT_QTY_COL    = "strat_qty[31:0]"

# Name of the "Sample in Buffer" column (Vivado default)
SAMPLE_COL = "Sample in Buffer"

# ----------------------------------------------------------------------
# Import depth_cpu_normalizer to reuse the Binance log decoder
# ----------------------------------------------------------------------

STAGE4_SWTOOLS = os.path.join(HERE, "..", "..", "stage4_depth", "sw_tools")
if STAGE4_SWTOOLS not in sys.path:
    sys.path.append(STAGE4_SWTOOLS)

from depth_cpu_normalizer import DepthEvent

import struct  # add this

PRICE_SCALE = 1_000_000  # same as FPGA: 1e-6
QTY_SCALE   = 1_000_000

def iter_csv_depth_events(log_path: str):
    """
    Parse binance_depth_tiny.log style CSV lines:

        ts_ns, update_id, side(B/A), price, qty

    Yield DepthEvent(update_id, side, price_fp, qty_fp) with the
    same fixed-point scale as the FPGA.
    """
    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            # Skip garbage / JSON-fragment first line if present
            if line[0] not in "0123456789":
                continue

            parts = line.split(",")
            if len(parts) != 5:
                # Not a data line; skip
                continue

            ts_ns_str, update_id_str, side_char, price_str, qty_str = parts

            try:
                update_id = int(update_id_str)
                price = float(price_str)
                qty = float(qty_str)
            except ValueError:
                # Malformed line; skip
                continue

            if side_char == "B":
                side = "BID"
            elif side_char == "A":
                side = "ASK"
            else:
                # Unknown side; skip
                continue

            price_fp = int(round(price * PRICE_SCALE))
            qty_fp   = int(round(qty   * QTY_SCALE))

            yield DepthEvent(
                update_id=update_id,
                side=side,
                price_fp=price_fp,
                qty_fp=qty_fp,
            )

# ----------------------------------------------------------------------
# CPU reference: order book + strategy kernel
# ----------------------------------------------------------------------

def best_level(levels: dict, reverse: bool) -> Tuple[int, int]:
    """
    Return (price_fp, qty_fp) for best level.

    reverse = True  -> max price  (best bid)
    reverse = False -> min price  (best ask)

    Returns (0, 0) if no levels are present.
    """
    if not levels:
        return 0, 0
    price = max(levels.keys()) if reverse else min(levels.keys())
    qty = levels[price]
    if qty <= 0:
        return 0, 0
    return price, qty


def simulate_cpu_strategy(log_path: str) -> List[Tuple[int, int, int]]:
    """
    Rebuild a simple book from binance_depth_tiny.log and run the same
    imbalance strategy as strategy_kernel_simple (IMB = 1:1).

    Returns a list of CPU actions:
        [(side, price_fp, qty_fp), ...]
    where side = 0 (BUY), 1 (SELL).
    """
    bids = {}  # price_fp -> qty_fp
    asks = {}

    actions: List[Tuple[int, int, int]] = []

    # IMB_THRESHOLD_NUM = 1, IMB_THRESHOLD_DEN = 1 in your Stage 6 instantiation
    IMB_NUM = 1
    IMB_DEN = 1

    for ev in iter_csv_depth_events(log_path):
        # Update book
        if ev.side == "BID":
            book = bids
        elif ev.side == "ASK":
            book = asks
        else:
            continue

        if ev.qty_fp == 0:
            book.pop(ev.price_fp, None)
        else:
            book[ev.price_fp] = ev.qty_fp

        # Compute best bid / ask
        best_bid_price, best_bid_qty = best_level(bids, reverse=True)
        best_ask_price, best_ask_qty = best_level(asks, reverse=False)

        # book_ready condition from strategy_kernel_simple
        book_ready = (best_bid_price != 0) and (best_ask_price != 0xFFFF_FFFF)

        if not book_ready:
            continue

        # Imbalance logic (DEN=NUM=1)
        # BUY if bid_qty * DEN > ask_qty * NUM  => bid_qty > ask_qty
        # SELL if ask_qty * DEN > bid_qty * NUM => ask_qty > bid_qty
        buy_cond = (best_bid_qty * IMB_DEN) > (best_ask_qty * IMB_NUM)
        sell_cond = (best_ask_qty * IMB_DEN) > (best_bid_qty * IMB_NUM)

        if buy_cond:
            side = 0
            price = best_ask_price
            qty = best_bid_qty
            actions.append((side, price, qty))
        elif sell_cond:
            side = 1
            price = best_bid_price
            qty = best_ask_qty
            actions.append((side, price, qty))

    return actions


# ----------------------------------------------------------------------
# FPGA actions from ILA CSV
# ----------------------------------------------------------------------

def ila_hex_to_scaled_int(value: str, scale: int) -> int:
    """
    Convert a 32-bit IEEE-754 float stored as hex (Vivado ILA export)
    into a scaled integer: round(float * scale).

    Examples:
        "47bb05a0" -> 95755.25  -> 95755250000  (scale = 1e6)
        "3dd0ea9e" -> 0.10201.. -> 102010       (scale = 1e6)
    """
    s = str(value).strip()
    if not s or s == "0":
        return 0

    # Vivado ILA dumps hex like '47bb05a0'
    try:
        raw = int(s, 16)
    except ValueError:
        # If for some reason the CSV already has a decimal number
        return int(float(s))

    # Interpret raw bits as IEEE-754 single-precision float (big-endian)
    f = struct.unpack("!f", raw.to_bytes(4, byteorder="big"))[0]
    return int(round(f * scale))


def load_fpga_actions(csv_path: str):
    """
    Parse FPGA strategy actions from ILA CSV.

    - Only count a new action on a *rising edge* of strat_valid.
    - Decode price/qty from IEEE-754 float hex into scaled ints
      consistent with CPU (price * 1e6, qty * 1e6).
    """
    df = pd.read_csv(csv_path)

    # Drop the radix row if present (first row often has 'Radix - UNSIGNED')
    if isinstance(df.iloc[0]["Sample in Buffer"], str) and \
       df.iloc[0]["Sample in Buffer"].startswith("Radix"):
        df = df.iloc[1:, :].copy()

    # Ensure strat_valid is integer 0/1
    df[STRAT_VALID_COL] = df[STRAT_VALID_COL].astype(int)

    actions = []
    prev_valid = 0

    for _, row in df.iterrows():
        curr_valid = int(row[STRAT_VALID_COL])

        # Rising edge = new action
        if curr_valid == 1 and prev_valid == 0:
            side  = int(row[STRAT_SIDE_COL])
            price = ila_hex_to_scaled_int(row[STRAT_PRICE_COL], PRICE_SCALE)
            qty   = ila_hex_to_scaled_int(row[STRAT_QTY_COL],   QTY_SCALE)
            actions.append((side, price, qty))

        prev_valid = curr_valid

    return actions



# ----------------------------------------------------------------------
# Alignment + comparison (same pattern as Stage 4)
# ----------------------------------------------------------------------

def align_sequences(cpu: List[Tuple[int, int, int]],
                    fpga: List[Tuple[int, int, int]]) -> Tuple[List[Tuple[int,int,int]],
                                                               List[Tuple[int,int,int]]]:
    """
    Align CPU and FPGA action lists by looking for the first exact match.

    Returns (cpu_aligned, fpga_aligned) with equal length.
    """
    if not fpga:
        return [], []

    target = fpga[0]
    start = None

    # Look for exact triple match
    for i, triple in enumerate(cpu):
        if triple == target:
            start = i
            break

    if start is None:
        # No alignment possible – return as-is
        return cpu, fpga

    cpu_slice = cpu[start:start + len(fpga)]
    fpga_slice = fpga[:len(cpu_slice)]
    return cpu_slice, fpga_slice


def compare_actions(cpu: List[Tuple[int, int, int]],
                    fpga: List[Tuple[int, int, int]]) -> None:
    cpu_aligned, fpga_aligned = align_sequences(cpu, fpga)

    total = min(len(cpu_aligned), len(fpga_aligned))
    matches = 0
    mismatches = []

    for i in range(total):
        c = cpu_aligned[i]
        f = fpga_aligned[i]
        if c == f:
            matches += 1
        else:
            mismatches.append((i, c, f))

    print(f"CPU actions:  {len(cpu)}")
    print(f"FPGA actions: {len(fpga)}")
    print(f"Compared:     {total}")
    print(f"Matches:      {matches}")
    if total > 0:
        print(f"Match ratio:  {matches/total:.3f}")

    if mismatches:
        print("First 10 mismatches (index, cpu(side,price,qty), fpga(side,price,qty)):")
        for i, c, f in mismatches[:10]:
            print(f"  {i}: CPU={c}, FPGA={f}")


def main():
    print("Loading CPU reference actions...")
    cpu_actions = simulate_cpu_strategy(LOG_PATH)
    print(f"CPU actions: {len(cpu_actions)}")

    print("Loading FPGA actions from ILA CSV...")
    fpga_actions = load_fpga_actions(ILA_CSV)
    print(f"FPGA actions: {len(fpga_actions)}")

    compare_actions(cpu_actions, fpga_actions)


if __name__ == "__main__":
    main()
