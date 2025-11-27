# tools/inspect_log.py

import sys
from pathlib import Path
from collections import Counter


def inspect_log(path: Path) -> None:
    total_lines = 0
    total_events = 0
    snapshot_lines = 0
    sample = []
    update_ids = Counter()

    with path.open("r") as fh:
        for line in fh:
            total_lines += 1
            line = line.rstrip("\n")

            if line.startswith("#SNAP"):
                snapshot_lines += 1
                continue

            if not line:
                continue

            parts = line.split(",")
            if len(parts) != 5:
                continue

            ts_ns, uid_str, side, price, qty = parts
            total_events += 1
            update_ids[uid_str] += 1

            if len(sample) < 5:
                sample.append(line)

    print(f"File: {path}")
    print(f"Total lines       : {total_lines}")
    print(f"Snapshot lines    : {snapshot_lines}")
    print(f"Event records     : {total_events}")
    print(f"Unique updateIds  : {len(update_ids)}")

    print("\nSample records:")
    for s in sample:
        print("  ", s)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python inspect_log.py /path/to/binance_depth.log")
        return

    log_path = Path(sys.argv[1])
    if not log_path.is_file():
        print(f"Log file not found: {log_path}")
        return

    inspect_log(log_path)


if __name__ == "__main__":
    main()
