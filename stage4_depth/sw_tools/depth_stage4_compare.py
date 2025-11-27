# depth_stage4_compare.py

import pandas as pd
import csv

ILA_CSV     = "depth_stage4_small.csv"
CPU_REF_CSV = "depth_cpu_ref.csv"

VALID_COL = "u_core/unpack_valid"  # adjust if your CSV header differs
DEPTH_COL = "u_core/depth_ev_packed[127:0]"

def decode_depth(depth_hex: str):
    d = int(depth_hex, 16)
    shifted = d >> 8  # drop header/flags

    update_id = (shifted >> 64) & ((1 << 64) - 1)
    price_fp  = (shifted >> 32) & ((1 << 32) - 1)
    qty_fp    = shifted & ((1 << 32) - 1)
    return update_id, price_fp, qty_fp

def load_fpga_events(csv_path: str):
    df = pd.read_csv(csv_path)

    # Drop the radix row
    df = df[df["Sample in Buffer"] != "Radix - UNSIGNED"].copy()

    # Keep only rows where unpack_valid == 1
    # Depending on how Vivado exported, the column may be "0"/"1" strings or ints.
    valid_mask = df[VALID_COL].astype(int) == 1
    df_valid = df[valid_mask]

    events = []
    for _, row in df_valid.iterrows():
        depth_hex = row[DEPTH_COL]
        events.append(decode_depth(depth_hex))
    return events


def load_cpu_events(csv_path: str):
    """
    Load all CPU events from depth_cpu_ref.csv.
    """
    events = []
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            u = int(row["update_id"])
            p = int(row["price_fp"])
            q = int(row["qty_fp"])
            events.append((u, p, q))
    return events


def align_by_first_match(fpga, cpu):
    """
    Align CPU stream to FPGA window.

    Strategy:
    - Try to find first index in CPU where the triple exactly matches fpga[0].
    - If that fails, fall back to matching only on update_id.
    - If still no match, return original lists (then you know the runs are
      from different parts / different logs).
    """
    if not fpga:
        return [], []

    target = fpga[0]

    # 1) exact triple match
    start = None
    for i, e in enumerate(cpu):
        if e == target:
            start = i
            break

    # 2) fallback: update_id only
    if start is None:
        target_u = target[0]
        for i, (u, p, q) in enumerate(cpu):
            if u == target_u:
                start = i
                break

    if start is None:
        # No alignment possible; return as-is
        return cpu, fpga

    cpu_slice = cpu[start:start + len(fpga)]
    fpga_slice = fpga[:len(cpu_slice)]
    return cpu_slice, fpga_slice


def main():
    fpga_events = load_fpga_events(ILA_CSV)
    cpu_events = load_cpu_events(CPU_REF_CSV)

    cpu_aligned, fpga_aligned = align_by_first_match(fpga_events, cpu_events)

    total = min(len(cpu_aligned), len(fpga_aligned))
    matches = 0
    mismatches = []

    for i in range(total):
        f = fpga_aligned[i]
        c = cpu_aligned[i]
        if f == c:
            matches += 1
        else:
            mismatches.append((i, f, c))

    print(f"Total compared: {total}")
    print(f"Matches: {matches}")
    if total > 0:
        print(f"Match rate: {matches / total * 100:.5f}%")
    else:
        print("Match rate: N/A (no events)")

    print("First 10 mismatches:")
    for i, f, c in mismatches[:10]:
        print(f"idx={i} FPGA={f} CPU={c}")


if __name__ == "__main__":
    main()
