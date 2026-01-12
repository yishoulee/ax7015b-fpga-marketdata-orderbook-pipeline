#!/usr/bin/env bash
set -euo pipefail

# Phase 3 demo checkpoint:
# - Replay events.bin through AXI FIFO MM-S (PS -> PL) and write a loopback copy
# - Read AXI-Lite "tap" regs before/after to assert deterministic deltas and last_hash
# - (Optional) compare input vs loopback; compute software checksum checkpoints

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${PHASE_DIR}/data"
TOOLS_DIR="${PHASE_DIR}/tools"

FIFO_BASE="${FIFO_BASE:-0x43C00000}"
TAP_BASE="${TAP_BASE:-0x40000000}"
CHUNK_RECORDS="${CHUNK_RECORDS:-40}"

IN_BIN="${1:-${DATA_DIR}/sample_btcusdt_depth.events.bin}"
OUT_LOOP="${2:-${DATA_DIR}/sample_btcusdt_depth.events.loopback.bin}"

# Freeze this per dataset+RTL; update only if you intentionally change hash logic or dataset.
EXPECTED_LAST_HASH="${EXPECTED_LAST_HASH:-0x651E42BC}"

# Parse events.bin header to compute expectations (no hard-coded record counts).
# Header layout (little-endian, 64 bytes total):
#   magic[8], ver(u32), recsz(u32), price_scale(u64), qty_scale(u64), symbol[16], padding...
read_header() {
  python3 - "$IN_BIN" <<'PY'
import os, struct, sys
p = sys.argv[1]
b = open(p, "rb").read(64)
if len(b) < 64:
    raise SystemExit("file too small for header")
magic = b[0:8]
ver, recsz = struct.unpack_from("<II", b, 8)
price_scale = struct.unpack_from("<Q", b, 16)[0]
qty_scale   = struct.unpack_from("<Q", b, 24)[0]
sym_raw = b[32:48]
symbol = sym_raw.split(b"\x00", 1)[0].decode("ascii", errors="replace")
size = os.path.getsize(p)
payload = size - 64
if recsz == 0 or payload < 0 or payload % recsz != 0:
    raise SystemExit(f"bad header: recsz={recsz} payload={payload}")
total = payload // recsz
print(f"magic_hex={magic.hex()} version={ver} symbol={symbol} price_scale={price_scale} qty_scale={qty_scale}")
print(f"record_size_bytes={recsz}")
print(f"total_records={total}")
print(f"payload_bytes={payload}")
PY
}

kv="$(read_header)"
# shellcheck disable=SC2034
eval "$(echo "$kv" | sed -n 's/^magic_hex=/magic_hex=/p')"
eval "$(echo "$kv" | sed -n 's/^record_size_bytes=/record_size_bytes=/p')"
eval "$(echo "$kv" | sed -n 's/^total_records=/total_records=/p')"
eval "$(echo "$kv" | sed -n 's/^payload_bytes=/payload_bytes=/p')"

words_per_record=$(( record_size_bytes / 4 ))
expected_delta_words=$(( total_records * words_per_record ))
expected_delta_pkts=$(( (total_records + CHUNK_RECORDS - 1) / CHUNK_RECORDS ))

echo "=== computed expectations ==="
echo "IN_BIN=${IN_BIN}"
echo "magic_hex=${magic_hex} version=${version} symbol=${symbol} price_scale=${price_scale} qty_scale=${qty_scale}"
echo "record_size_bytes=${record_size_bytes}"
echo "total_records=${total_records}"
echo "payload_bytes=${payload_bytes}"
echo "chunk_records=${CHUNK_RECORDS}"
echo "expected_delta_words=${expected_delta_words}"
echo "expected_delta_pkts=${expected_delta_pkts}"
echo

read_tap() {
  xsct "${SCRIPT_DIR}/xsct_read_tap_regs.tcl" -tap_base "${TAP_BASE}"
}

get_field() {
  local key="$1"
  # Reads from stdin
  awk -F= -v k="$key" '$1==k {print $2; exit}'
}

echo "=== TAP before ==="
tap_before="$(read_tap)"
echo "${tap_before}"
before_hash="$(echo "${tap_before}" | get_field TAP_last_hash)"
before_words="$(echo "${tap_before}" | get_field TAP_word_count)"
before_pkts="$(echo "${tap_before}" | get_field TAP_pkt_count)"
echo

echo "=== replay (FIFO) ==="
t0_ns=$(date +%s%N)

xsct "${SCRIPT_DIR}/xsct_replay_events_loopback.tcl" \
  -base "${FIFO_BASE}" \
  -in  "${IN_BIN}" \
  -out "${OUT_LOOP}" \
  -chunk_records "${CHUNK_RECORDS}"

t1_ns=$(date +%s%N)
elapsed_ns=$((t1_ns - t0_ns))

elapsed_s=$(python3 - <<PY
print(${elapsed_ns} / 1e9)
PY
)

events_per_s=$(python3 - <<PY
print(${total_records} / (${elapsed_ns} / 1e9))
PY
)

echo "metric: elapsed_s=${elapsed_s} events_per_s=${events_per_s} (events=${total_records})"
echo


echo "=== TAP after ==="
tap_after="$(read_tap)"
echo "${tap_after}"
after_hash="$(echo "${tap_after}" | get_field TAP_last_hash)"
after_words="$(echo "${tap_after}" | get_field TAP_word_count)"
after_pkts="$(echo "${tap_after}" | get_field TAP_pkt_count)"
echo

delta_words=$(( after_words - before_words ))
delta_pkts=$(( after_pkts - before_pkts ))

echo "=== CHECK (delta) ==="
echo "delta_words=${delta_words} expected=${expected_delta_words}"
echo "delta_pkts=${delta_pkts}  expected=${expected_delta_pkts}"
echo "last_hash=${after_hash} expected=${EXPECTED_LAST_HASH}"

fail=0
if [[ "${delta_words}" -ne "${expected_delta_words}" ]]; then
  echo "FAIL: word_count delta mismatch"
  fail=1
fi
if [[ "${delta_pkts}" -ne "${expected_delta_pkts}" ]]; then
  echo "FAIL: pkt_count delta mismatch"
  fail=1
fi
if [[ "${after_hash}" != "${EXPECTED_LAST_HASH}" ]]; then
  echo "FAIL: last_hash mismatch"
  fail=1
fi

if [[ "${fail}" -eq 0 ]]; then
  echo "PASS: TAP delta + last_hash matched."
else
  exit 1
fi
echo

if [[ -x "${TOOLS_DIR}/compare_events_bins.py" ]]; then
  echo "=== compare input vs loopback (optional) ==="
  python3 "${TOOLS_DIR}/compare_events_bins.py" --a "${IN_BIN}" --b "${OUT_LOOP}"
  echo
fi

echo "=== software checksum checkpoints (payload) ==="
python3 "${TOOLS_DIR}/events_checksum_v0.py" --in "${OUT_LOOP}" --every 500