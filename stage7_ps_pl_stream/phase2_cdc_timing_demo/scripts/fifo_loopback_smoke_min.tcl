# fifo_loopback_smoke_min.tcl
# AXI FIFO MM-S smoke test for the minimal single-clock loopback BD:
#   TX: write payload words to TDFD, then write TLR (bytes) to start transmit
#   RX: poll RDFO (occupancy in 32-bit words), then read RDFD words back
#
# Usage examples:
#   xsct fifo_loopback_smoke_min.tcl
#   xsct fifo_loopback_smoke_min.tcl -base 0x43C00000
#   xsct fifo_loopback_smoke_min.tcl -base 0x43C00000 -iters 800
#
# Notes:
# - Avoid reading RLR (0x24). Use RDFO + known expected bytes/words for this smoke test.
# - If you still get AHB AP transaction errors: your FIFO_BASE is wrong, or PL isn’t programmed, or target/memmap is wrong.

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
# CONFIG DEFAULTS (override with argv)
# -----------------------
set FIFO_BASE 0x43C00000
set MAP_SIZE  0x00010000
set TIMEOUT_ITERS 400

# Parse argv: -base <hex> -iters <n>
for {set i 0} {$i < [llength $argv]} {incr i} {
    set a [lindex $argv $i]
    if {$a eq "-base"} {
        incr i
        if {$i >= [llength $argv]} { error "missing value after -base" }
        set FIFO_BASE [lindex $argv $i]
    } elseif {$a eq "-iters"} {
        incr i
        if {$i >= [llength $argv]} { error "missing value after -iters" }
        set TIMEOUT_ITERS [lindex $argv $i]
    } else {
        error "unknown arg: $a (supported: -base <hex> -iters <n>)"
    }
}

# -----------------------
# AXI FIFO MM-S register offsets (PG080)
# -----------------------
set ISR  0x00
set IER  0x04
set TDFR 0x08
set TDFV 0x0C
set TDFD 0x10
set TLR  0x14
set RDFR 0x18
set RDFO 0x1C
set RDFD 0x20
# set RLR  0x24 ;# DO NOT READ in this smoke test

# Optional (exists in PG080, but you can leave it unused)
set SRR  0x28

# Payload (8 words = 32 bytes), matches PG080 examples
set payload [list \
    0xFFFFFFFF 0x12345678 0x00010203 0x08090A0B \
    0x10111213 0x18191A1B 0x20212223 0x28292A2B \
]
set nwords [llength $payload]
set nbytes [expr {$nwords * 4}]

# -----------------------
# MAIN
# -----------------------
banner "connect"
connect

banner "targets"
targets

banner "target -set 1 (APU)"
target -set 1

banner "memmap set (FIFO only)"
memmap_set_rw $FIFO_BASE $MAP_SIZE

banner "memmap -list"
puts [memmap -list]

banner "probe FIFO regs (sanity)"
puts [format {FIFO_BASE=%s MAP_SIZE=%s} [hex32 $FIFO_BASE] [hex32 $MAP_SIZE]]

# If this fails, base address or session is wrong; stop early with a clear message.
set isr 0
if {[catch {set isr [must_rd32 [expr {$FIFO_BASE + $ISR}] "FIFO+ISR"]} err]} {
    puts "\nFATAL: cannot read FIFO[ISR] at FIFO_BASE=[hex32 $FIFO_BASE]"
    puts "Most likely: wrong FIFO_BASE (Vivado Address Editor), PL not programmed, or wrong XSCT target/memmap sequence."
    error $err
}
puts [format {FIFO[ISR  0x00] => %s} [hex32 $isr]]
puts [format {FIFO[IER  0x04] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $IER}]  "FIFO+IER"]]]
puts [format {FIFO[TDFV 0x0C] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV"]]]
puts [format {FIFO[RDFO 0x1C] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO"]]]

banner "clear ISR (best-effort)"
catch { must_wr32 [expr {$FIFO_BASE + $ISR}] 0xFFFFFFFF "FIFO+ISR clear" }
after 5

banner "reset TX/RX (TDFR/RDFR)"
# Optional: try SRR first, but do not fail if it errors
catch { must_wr32 [expr {$FIFO_BASE + $SRR}] 0x000000A5 "FIFO+SRR soft reset" }
after 5

must_wr32 [expr {$FIFO_BASE + $TDFR}] 0x000000A5 "FIFO+TDFR reset"
must_wr32 [expr {$FIFO_BASE + $RDFR}] 0x000000A5 "FIFO+RDFR reset"
after 20

banner "post-reset probe"
puts [format {FIFO[ISR  0x00] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $ISR}]  "FIFO+ISR"]]]
puts [format {FIFO[TDFV 0x0C] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV"]]]
puts [format {FIFO[RDFO 0x1C] => %s} [hex32 [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO"]]]

banner "TX write payload to TDFD"
set idx 0
foreach w $payload {
    puts [format {TX[%d] <= %s} $idx [hex32 $w]]
    must_wr32 [expr {$FIFO_BASE + $TDFD}] $w "FIFO+TDFD"
    incr idx
}

banner "TX commit length (TLR starts transmission)"
puts [format {TLR <= %d bytes (%d words)} $nbytes $nwords]
must_wr32 [expr {$FIFO_BASE + $TLR}] $nbytes "FIFO+TLR"
after 5

banner "diag: did TX vacancy change (TDFV)?"
set tdfv0 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV@t0"]
after 50
set tdfv1 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV@t1"]
puts [format {TDFV t0=%s  t1=%s} [hex32 $tdfv0] [hex32 $tdfv1]]

banner "poll RDFO until >= expected words"
set got_words 0
set rdfo 0
for {set k 0} {$k < $TIMEOUT_ITERS} {incr k} {
    set rdfo [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO poll"]
    # Per PG080 example: RDFO reads 0x8 after receiving 32 bytes => 8 words.
    set got_words [expr {$rdfo & 0xFFFFFFFF}]
    if {$got_words >= $nwords} { break }
    after 5
}

puts [format {RDFO=%s (words=%d) expected=%d} [hex32 $rdfo] $got_words $nwords]
if {$got_words < $nwords} {
    error [format {Timeout: RDFO never reached %d words (stuck at %d)} $nwords $got_words]
}

banner "RX read data (RDFD)"
set rx {}
for {set j 0} {$j < $nwords} {incr j} {
    set v [must_rd32 [expr {$FIFO_BASE + $RDFD}] "FIFO+RDFD"]
    lappend rx $v
    puts [format {RX[%d] => %s} $j [hex32 $v]]
}

banner "compare payload"
set ok 1
for {set j 0} {$j < $nwords} {incr j} {
    set txw [lindex $payload $j]
    set rxw [lindex $rx $j]
    if {($txw & 0xFFFFFFFF) != ($rxw & 0xFFFFFFFF)} {
        puts [format {MISMATCH idx=%d tx=%s rx=%s} $j [hex32 $txw] [hex32 $rxw]]
        set ok 0
    }
}

banner "final RDFO (should drop back toward 0)"
catch {
    set rdfo_end [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO end"]
    puts [format {RDFO_end=%s (words=%d)} [hex32 $rdfo_end] [expr {$rdfo_end & 0xFFFFFFFF}]]
}

if {!$ok} { error "FAIL: loopback payload mismatch" }
puts "PASS: loopback payload matched"
