# replay/replay_uart.py

import argparse
import os
import struct
import time
from pathlib import Path
from typing import Iterable, Tuple

import serial
from serial.tools import list_ports
import sys
import pathlib

# Support running both as a package module and as a standalone script
if __package__ in (None, ""):
    this_dir = pathlib.Path(__file__).resolve().parent
    if str(this_dir) not in sys.path:
        sys.path.insert(0, str(this_dir))
    from config import (
        UART_PORT,
        UART_BAUDRATE,
        UART_RTSCTS,
        DEFAULT_MODE,
        DEFAULT_SPEED,
    )
else:
    from .config import (
        UART_PORT,
        UART_BAUDRATE,
        UART_RTSCTS,
        DEFAULT_MODE,
        DEFAULT_SPEED,
    )

# 32-byte record: <QQBffxxxxxxx
# ts_ns:   uint64
# updateId:uint64
# side:    uint8  (0=bid,1=ask)
# price:   float32
# qty:     float32
# padding: 7 bytes
RECORD_STRUCT = struct.Struct("<QQBffxxxxxxx")  # 32 bytes


def parse_log_lines(path: Path) -> Iterable[Tuple[int, int, int, float, float]]:
    """
    Parse log file lines into records suitable for binary packing.

    Input line format:
    - Snapshot line:
        #SNAP {"lastUpdateId": ..., "bids": [...], "asks": [...]}
      (ignored by replay)

    - Event line:
        ts_ns,updateId,side,price,qty
    """
    with path.open("r") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#SNAP"):
                continue

            try:
                ts_str, uid_str, side_str, price_str, qty_str = line.split(",")
                ts_ns = int(ts_str)
                update_id = int(uid_str)
                side_code = 0 if side_str == "B" else 1  # 0 = bid, 1 = ask
                price = float(price_str)
                qty = float(qty_str)
            except ValueError:
                # Skip malformed lines
                continue

            yield ts_ns, update_id, side_code, price, qty


def replay_uart(
    log_path: Path,
    mode: str,
    speed: float,
    port: str,
    baudrate: int,
    rtscts: bool,
) -> None:
    """
    Replay records from log_path over UART.

    Timing behaviour:
    - realtime:
        sleep for the original delta between consecutive ts_ns
    - accelerated:
        sleep for delta / speed
    """
    records = list(parse_log_lines(log_path))
    if not records:
        print("[replay] No records to replay.")
        return

    try:
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            timeout=1,
            rtscts=rtscts,
        )
    except serial.SerialException as e:
        print(f"[replay] Failed to open UART '{port}': {e}")
        ports = list(list_ports.comports())
        if ports:
            print("[replay] Available serial ports:")
            for p in ports:
                print(f"  - {p.device} ({p.description})")
        else:
            print("[replay] No serial ports detected. Is your USB-UART connected?")
        return

    print(f"[replay] Opened UART {port} at {baudrate} baud")
    print(f"[replay] Records to send: {len(records)}")
    print(f"[replay] Mode={mode}, speed={speed}")

    prev_ts_ns = None
    start_wall = time.time()

    try:
        for idx, (ts_ns, update_id, side_code, price, qty) in enumerate(records):
            # Timing
            if prev_ts_ns is not None:
                delta_ns = ts_ns - prev_ts_ns
                if delta_ns < 0:
                    delta_ns = 0

                if mode == "realtime":
                    sleep_s = delta_ns / 1e9
                elif mode == "accelerated":
                    sleep_s = (delta_ns / speed) / 1e9 if speed > 0 else 0.0
                else:
                    sleep_s = 0.0

                if sleep_s > 0:
                    time.sleep(sleep_s)

            prev_ts_ns = ts_ns

            # Pack record into 32 bytes (price/qty cast to float32 by struct)
            payload = RECORD_STRUCT.pack(
                ts_ns,
                update_id,
                side_code,
                float(price),
                float(qty),
            )

            # Send over UART
            ser.write(payload)

            if (idx + 1) % 1000 == 0:
                elapsed = time.time() - start_wall
                rate = (idx + 1) / elapsed if elapsed > 0 else 0.0
                print(
                    f"[replay] sent={idx + 1}/{len(records)} ({rate:.0f} rec/s)"
                )
    finally:
        ser.close()
        print("[replay] UART closed.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Replay Binance depth log over UART (32B records)."
    )
    parser.add_argument(
        "logfile",
        type=str,
        help="Path to binance_depth.log",
    )
    parser.add_argument(
        "--mode",
        type=str,
        choices=["realtime", "accelerated"],
        default=DEFAULT_MODE,
        help="Timing mode for replay.",
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=DEFAULT_SPEED,
        help="Acceleration factor (only for accelerated mode).",
    )
    parser.add_argument(
        "--port",
        type=str,
        default=None,
        help="UART device path (overrides config/env)",
    )
    parser.add_argument(
        "--baud",
        type=int,
        default=None,
        help="UART baud rate (overrides config/env)",
    )
    parser.add_argument(
        "--rtscts",
        action="store_true",
        help="Enable RTS/CTS flow control",
    )

    args = parser.parse_args()
    log_path = Path(args.logfile)

    if not log_path.is_file():
        print(f"[replay] Log file not found: {log_path}")
        return

    # Resolve UART settings with precedence: CLI > ENV > config
    port = (
        args.port
        or os.getenv("UART_PORT")
        or UART_PORT
    )
    baud = (
        args.baud
        if args.baud is not None
        else int(os.getenv("UART_BAUDRATE", UART_BAUDRATE))
    )
    rtscts = args.rtscts or (os.getenv("UART_RTSCTS", str(UART_RTSCTS)).lower() in ("1", "true", "yes"))

    replay_uart(
        log_path=log_path,
        mode=args.mode,
        speed=args.speed,
        port=port,
        baudrate=baud,
        rtscts=rtscts,
    )


if __name__ == "__main__":
    main()
