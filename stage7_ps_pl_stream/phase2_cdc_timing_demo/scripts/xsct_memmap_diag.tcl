# fifo_loopback_smoke.tcl
# AXI FIFO MM-S smoke test: write TX, expect data to appear on RX via BD loopback chain
# XSCT 2025.1: uses option-style memmap syntax (memmap -addr/-size/-flags).
# Avoid reading RLR (0x24).

proc banner {s} { puts "\n=== $s ===" }

proc hex32 {v} {
    set x [expr {($v) & 0xFFFFFFFF}]
    return [format "0x%08X" $x]
}

proc rd32 {addr} {
    set out [mrd $addr]
    if {[regexp {:\s*([0-9A-Fa-f]+)} $out -> datahex]} {
        scan $datahex %x v
        return $v
    }
    error "rd32: cannot parse mrd output: $out"
}

proc must_rd32 {addr tag} {
    if {[catch {set v [rd32 $addr]} err]} {
        error "READ FAIL $tag addr=[hex32 $addr] : $err"
    }
    return $v
}

proc must_wr32 {addr val tag} {
    if {[catch {mwr $addr $val} err]} {
        error "WRITE FAIL $tag addr=[hex32 $addr] val=[hex32 $val] : $err"
    }
}

proc memmap_set_rw {base size_hex} {
    catch {memmap -addr $base -clear}
    memmap -addr $base -size $size_hex -flags 3
}

# -----------------------
# CONFIG: Address Editor values
# -----------------------
set MYIP_BASE 0x43C00000
set FIFO_BASE 0x43C10000
set MAP_SIZE  0x00010000

# AXI FIFO MM-S offsets (avoid 0x24)
set ISR  0x00
set TDFR 0x08
set TDFV 0x0C
set TDFD 0x10
set TLR  0x14
set RDFR 0x18
set RDFO 0x1C
set RDFD 0x20

# -----------------------
# MAIN
# -----------------------
banner "connect"
connect

banner "targets"
targets

banner "target -set 1 (APU)"
target -set 1

banner "memmap set (MYIP + FIFO)"
memmap_set_rw $MYIP_BASE $MAP_SIZE
memmap_set_rw $FIFO_BASE $MAP_SIZE
puts [memmap -list]

banner "probe (safe regs)"
puts [format {MYIP[0x04] => %s} [hex32 [must_rd32 [expr {$MYIP_BASE + 0x04}] "MYIP+0x04"]]]
puts [format {FIFO[ISR  0x00] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $ISR}]  "FIFO+ISR"]]]
puts [format {FIFO[TDFV 0x0C] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV"]]]
puts [format {FIFO[RDFO 0x1C] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO"]]]

banner "FIFO reset TX/RX"
must_wr32 [expr {$FIFO_BASE + $TDFR}] 0x000000A5 "FIFO+TDFR reset"
must_wr32 [expr {$FIFO_BASE + $RDFR}] 0x000000A5 "FIFO+RDFR reset"
after 10

banner "TX write 4 words + commit length"
set payload [list 0x11111111 0x22222222 0x33333333 0x44444444]
set nwords  [llength $payload]
set nbytes  [expr {$nwords * 4}]

set i 0
foreach w $payload {
    puts [format {TX[%d] <= %s} $i [hex32 $w]]
    must_wr32 [expr {$FIFO_BASE + $TDFD}] $w "FIFO+TDFD"
    incr i
}
puts [format {TLR <= %d bytes} $nbytes]
must_wr32 [expr {$FIFO_BASE + $TLR}] $nbytes "FIFO+TLR"

banner "poll RDFO for RX words (timeout)"
set want_words $nwords
set got_words  0
set rdfo       0
set timeout_iters 400

for {set k 0} {$k < $timeout_iters} {incr k} {
    set rdfo [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO poll"]
    set got_words [expr {$rdfo & 0x1FFFF}]
    if {$got_words >= $want_words} { break }
    after 5
}

puts [format {RDFO=%s (words=%d)} [hex32 $rdfo] $got_words]
puts [format {TDFV(now)=%s} [hex32 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV(after)"]]]

if {$got_words < $want_words} {
    error [format {Timeout: RDFO never reached %d words (stuck at %d). Likely AXIS chain not running (clock/reset).} $want_words $got_words]
}

banner "RX read + compare"
set rx {}
for {set j 0} {$j < $want_words} {incr j} {
    set v [must_rd32 [expr {$FIFO_BASE + $RDFD}] "FIFO+RDFD"]
    lappend rx $v
    puts [format {RX[%d] => %s} $j [hex32 $v]]
}

for {set j 0} {$j < $want_words} {incr j} {
    set txw [lindex $payload $j]
    set rxw [lindex $rx $j]
    if {($txw & 0xFFFFFFFF) != ($rxw & 0xFFFFFFFF)} {
        error [format {FAIL: mismatch idx=%d tx=%s rx=%s} $j [hex32 $txw] [hex32 $rxw]]
    }
}

puts "PASS: loopback payload matched"
