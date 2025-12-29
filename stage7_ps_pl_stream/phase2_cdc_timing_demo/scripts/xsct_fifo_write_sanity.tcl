# xsct_fifo_write_sanity.tcl
# Purpose: confirm AXI-Lite writes complete to the FIFO region.
# Tries "safe" writes first (IER, TLR), then TDFR.

proc banner {s} { puts "\n=== $s ===" }
proc hex32 {v} { return [format "0x%08X" [expr {($v) & 0xFFFFFFFF}]] }

proc rd32 {addr} {
    set out [mrd $addr]
    if {[regexp {:\s*([0-9A-Fa-f]+)} $out -> datahex]} {
        scan $datahex %x v
        return $v
    }
    error "rd32 parse fail: $out"
}

proc wr32 {addr val} { mwr $addr $val }

proc try_rd {addr tag} {
    if {[catch {set v [rd32 $addr]} e]} {
        puts "READ FAIL $tag addr=[hex32 $addr] : $e"
        return ""
    } else {
        puts "READ ok   $tag addr=[hex32 $addr] => [hex32 $v]"
        return $v
    }
}

proc try_wr {addr val tag} {
    if {[catch {wr32 $addr $val} e]} {
        puts "WRITE FAIL $tag addr=[hex32 $addr] val=[hex32 $val] : $e"
        return 0
    } else {
        puts "WRITE ok   $tag addr=[hex32 $addr] val=[hex32 $val]"
        return 1
    }
}

# --- CONFIG ---
set FIFO_BASE 0x43C10000
set MAP_SIZE  0x00010000

# AXI FIFO MM-S offsets
set ISR  0x00
set IER  0x04
set TDFR 0x08
set TDFV 0x0C
set TLR  0x14
set RDFO 0x1C

banner "connect + target"
connect
targets
target -set 1

banner "memmap"
catch {memmap -addr $FIFO_BASE -clear}
memmap -addr $FIFO_BASE -size $MAP_SIZE -flags 3
puts [memmap -list]

banner "baseline reads"
try_rd [expr {$FIFO_BASE + $ISR}]  "ISR"
try_rd [expr {$FIFO_BASE + $TDFV}] "TDFV"
try_rd [expr {$FIFO_BASE + $RDFO}] "RDFO"

banner "write sanity (IER then TLR then TDFR)"
# 1) IER: should be writable, and usually readable back
set ok_ier [try_wr [expr {$FIFO_BASE + $IER}] 0x00000000 "IER<=0"]
set ier_rb [try_rd [expr {$FIFO_BASE + $IER}] "IER readback"]

# 2) TLR: writing 0 is harmless (doesn't require stream activity)
set ok_tlr [try_wr [expr {$FIFO_BASE + $TLR}] 0x00000000 "TLR<=0"]
try_rd [expr {$FIFO_BASE + $TDFV}] "TDFV after TLR<=0"

# 3) TDFR reset (the one that currently times out)
set ok_tdfr [try_wr [expr {$FIFO_BASE + $TDFR}] 0x000000A5 "TDFR<=A5 reset"]
try_rd [expr {$FIFO_BASE + $TDFV}] "TDFV after TDFR"

banner "verdict"
puts "ok_ier=$ok_ier ok_tlr=$ok_tlr ok_tdfr=$ok_tdfr"
if {!$ok_ier && !$ok_tlr} {
    puts "VERDICT: even simple writes fail -> AXI-Lite write path is broken (reset/clock/bitstream mismatch)."
} elseif {$ok_ier && $ok_tlr && !$ok_tdfr} {
    puts "VERDICT: writes work, but TDFR write stalls -> treat TDFR as unsafe in this config; avoid reset reg for now."
} else {
    puts "VERDICT: writes complete -> proceed to next FIFO progress checks."
}
