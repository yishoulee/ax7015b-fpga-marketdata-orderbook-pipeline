#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path

HDR = 64
W = 4

def sha256(b: bytes) -> str:
    import hashlib
    h = hashlib.sha256()
    h.update(b)
    return h.hexdigest()

def byteswap4(data: bytes) -> bytes:
    out = bytearray(len(data))
    for i in range(0, len(data), 4):
        out[i:i+4] = data[i:i+4][::-1]
    return bytes(out)

def find_first_mismatch(a: bytes, b: bytes) -> int:
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return i
    return -1 if len(a) == len(b) else n

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True, help="original events.bin")
    ap.add_argument("--b", required=True, help="loopback events.bin")
    args = ap.parse_args()

    A = Path(args.a).read_bytes()
    B = Path(args.b).read_bytes()

    if len(A) < HDR or len(B) < HDR:
        raise SystemExit("files too small")

    Ah, Ap = A[:HDR], A[HDR:]
    Bh, Bp = B[:HDR], B[HDR:]

    print(f"A size={len(A)} payload={len(Ap)}")
    print(f"B size={len(B)} payload={len(Bp)}")
    print(f"header_equal={Ah==Bh}")

    # quick hashes
    print(f"A payload sha256={sha256(Ap)}")
    print(f"B payload sha256={sha256(Bp)}")

    # first mismatch
    mi = find_first_mismatch(Ap, Bp)
    print(f"first_mismatch_byte={mi}")

    if mi >= 0:
        s = max(0, mi-16)
        e = min(len(Ap), mi+16)
        print("A context:", Ap[s:e].hex())
        print("B context:", Bp[s:e].hex())

    # hypothesis 1: per-32bit byte-swap
    if len(Ap) == len(Bp) and len(Ap) % 4 == 0:
        Bswap = byteswap4(Bp)
        print(f"byteswap4(B)==A ? {Bswap==Ap}")

    # hypothesis 2: off-by-4 shift
    if len(Ap) == len(Bp) and len(Ap) >= 8:
        print(f"A == B[4:]+pad ? {Ap[:-4]==Bp[4:]}")
        print(f"A[4:] == B[:-4] ? {Ap[4:]==Bp[:-4]}")

if __name__ == "__main__":
    main()
