#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec xsct "${SCRIPT_DIR}/xsct_read_tap_regs.tcl" "$@"