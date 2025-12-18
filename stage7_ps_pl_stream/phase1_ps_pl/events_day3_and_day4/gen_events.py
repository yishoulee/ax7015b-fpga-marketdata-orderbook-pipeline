#!/usr/bin/env python3
import struct
import sys

MAGIC = 0x30545645  # "EVT0" in your scheme

def make_event(seq: int):
    # 8 x u32, little-endian
    # W0 magic, W1 seq, W2..W7 payload
    w0 = MAGIC
    w1 = seq & 0xFFFFFFFF
    # simple deterministic payload that changes with seq
    w2 = (1 + seq) & 0xFFFFFFFF
    w3 = (0) & 0xFFFFFFFF
    w4 = (0x10 + (seq & 0xFF)) & 0xFFFFFFFF
    w5 = (0) & 0xFFFFFFFF
    w6 = (0x20 + ((seq >> 8) & 0xFF)) & 0xFFFFFFFF
    w7 = (0) & 0xFFFFFFFF
    return (w0, w1, w2, w3, w4, w5, w6, w7)

def main():
    if len(sys.argv) < 3:
        print("Usage: gen_events.py <out.bin> <count>")
        sys.exit(1)

    out_path = sys.argv[1]
    n = int(sys.argv[2])

    with open(out_path, "wb") as f:
        for seq in range(n):
            words = make_event(seq)
            f.write(struct.pack("<8I", *words))

    print(f"Wrote {n} events to {out_path} ({n*32} bytes)")

if __name__ == "__main__":
    main()
