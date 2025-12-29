# xsct_axi_fifo_diag.tcl
# Diagnostics for AXI FIFO MM-S regs + basic TX drain / RX occupancy checks
# Hard-coded connect + target -set 1 (APU)
# Avoids RLR (0x24) because you've seen AHB AP transaction errors there.

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
    # Known-good syntax in your session:
    # memmap -addr <base> -size <size> -flags 3
    catch {memmap -addr $base -clear}
    memmap -addr $base -size $size_hex -flags 3
}

proc connect_apu_hardcoded {} {
    banner "connect"
    connect
    banner "targets"
    targets
    banner "target -set 1 (APU)"
    target -set 1
}

# -----------------------
# CONFIG (edit only these if addresses change)
# -----------------------
set MYIP_BASE 0x43C00000
set FIFO_BASE 0x43C10000
set MAP_SIZE  0x00010000

# AXI FIFO MM-S offsets (do not read 0x24)
set ISR  0x00
set IER  0x04
set TDFR 0x08
set TDFV 0x0C
set TDFD 0x10
set TLR  0x14
set RDFR 0x18
set RDFO 0x1C
set RDFD 0x20
# set RLR  0x24  ;# DO NOT TOUCH

# -----------------------
# MAIN
# -----------------------
# connect_apu_hardcoded

banner "memmap set (MYIP + FIFO)"
memmap_set_rw $MYIP_BASE $MAP_SIZE
memmap_set_rw $FIFO_BASE $MAP_SIZE

banner "memmap -list"
puts [memmap -list]

banner "probe MYIP + FIFO regs"
puts [format "MYIP[0x04] => %s" [hex32 [must_rd32 [expr {$MYIP_BASE + 0x04}] "MYIP+0x04"]]]
puts [format "FIFO[ISR 0x00] => %s" [hex32 [must_rd32 [expr {$FIFO_BASE + $ISR}]  "FIFO+ISR"]]]
puts [format "FIFO[TDFV 0x0C] => %s" [hex32 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV"]]]
puts [format "FIFO[RDFO 0x1C] => %s" [hex32 [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO"]]]

banner "reset TX/RX FIFOs"
must_wr32 [expr {$FIFO_BASE + $TDFR}] 0x000000A5 "FIFO+TDFR reset"
must_wr32 [expr {$FIFO_BASE + $RDFR}] 0x000000A5 "FIFO+RDFR reset"
after 10

banner "TX write 4 words + commit length"
set payload [list 0x11111111 0x22222222 0x33333333 0x44444444]
set nwords  [llength $payload]
set nbytes  [expr {$nwords * 4}]

set i 0
foreach w $payload {
    puts [format "TX[%d] <= %s" $i [hex32 $w]]
    must_wr32 [expr {$FIFO_BASE + $TDFD}] $w "FIFO+TDFD"
    incr i
}
puts [format "TLR <= %d bytes" $nbytes]
must_wr32 [expr {$FIFO_BASE + $TLR}] $nbytes "FIFO+TLR"

banner "check whether TX is draining (TDFV should decrease if a sink asserts TREADY)"
set tdfv0 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV@t0"]
after 50
set tdfv1 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV@t1"]
puts [format "TDFV t0=%s  t1=%s" [hex32 $tdfv0] [hex32 $tdfv1]]

if {$tdfv1 == $tdfv0} {
    puts "DIAG: TX did not drain. That usually means the AXIS TX path has no real sink (TREADY low) or is held in reset/clock mismatch."
} else {
    puts "DIAG: TX drained (some progress on AXIS TX path)."
}

banner "check RX occupancy (RDFO)"
set rdfo [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO"]
set got_words [expr {$rdfo & 0x1FFFF}]
puts [format "RDFO=%s (words=%d)" [hex32 $rdfo] $got_words]

if {$got_words == 0} {
    puts "DIAG: RX has 0 words. If you expected TX->RX loopback, your BD is not wired that way (TX chain is not connected to AXI_STR_RXD)."
} else {
    puts "DIAG: RX has data; you can read RDFD next."
}

banner "done"
