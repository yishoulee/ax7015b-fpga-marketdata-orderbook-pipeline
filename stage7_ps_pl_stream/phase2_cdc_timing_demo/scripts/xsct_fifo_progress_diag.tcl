# xsct_fifo_progress_diag.tcl
# Goal: prove whether TX words are actually entering the FIFO (TDFV changes),
# and whether TX completes / RX gets occupancy (ISR + RDFO).
# Uses known-good memmap syntax. Avoids RLR (0x24).

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

proc wr32 {addr val} {
    mwr $addr $val
}

proc must_rd32 {addr tag} {
    if {[catch {set v [rd32 $addr]} err]} {
        error "READ FAIL $tag addr=[hex32 $addr] : $err"
    }
    return $v
}

proc must_wr32 {addr val tag} {
    if {[catch {wr32 $addr $val} err]} {
        error "WRITE FAIL $tag addr=[hex32 $addr] val=[hex32 $val] : $err"
    }
}

proc memmap_set_rw {base size_hex} {
    catch {memmap -addr $base -clear}
    memmap -addr $base -size $size_hex -flags 3
}

# CONFIG (your Address Editor values)
set FIFO_BASE 0x43C10000
set MAP_SIZE  0x00010000

# AXI FIFO MM-S offsets (PG080)  (avoid 0x24 RLR)
set ISR  0x00
set IER  0x04
set TDFR 0x08
set TDFV 0x0C
set TDFD 0x10
set TLR  0x14
set RDFR 0x18
set RDFO 0x1C
set RDFD 0x20

# ISR bits we care about (from PG080)
# TX complete = 0x0800_0000, RX complete = 0x0400_0000 (used as hints)
set ISR_TXCMPL 0x08000000
set ISR_RXCMPL 0x04000000

banner "connect + target"
connect
targets
target -set 1

banner "memmap"
memmap_set_rw $FIFO_BASE $MAP_SIZE
puts [memmap -list]

banner "baseline regs"
set isr0  [must_rd32 [expr {$FIFO_BASE + $ISR}]  "FIFO+ISR"]
set tdfv0 [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV"]
set rdfo0 [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO"]
puts [format "ISR=%s  TDFV=%s  RDFO=%s" [hex32 $isr0] [hex32 $tdfv0] [hex32 $rdfo0]]

banner "reset TX/RX"
must_wr32 [expr {$FIFO_BASE + $TDFR}] 0x000000A5 "FIFO+TDFR reset"
must_wr32 [expr {$FIFO_BASE + $RDFR}] 0x000000A5 "FIFO+RDFR reset"
after 10

banner "clear ISR (W1C)"
must_wr32 [expr {$FIFO_BASE + $ISR}] 0xFFFFFFFF "FIFO+ISR clear"

banner "write payload and watch TDFV change"
set payload [list 0x11111111 0x22222222 0x33333333 0x44444444]
set i 0
foreach w $payload {
    must_wr32 [expr {$FIFO_BASE + $TDFD}] $w "FIFO+TDFD"
    set tdfv_i [must_rd32 [expr {$FIFO_BASE + $TDFV}] "FIFO+TDFV after word$i"]
    puts [format "w%d=%s  TDFV_now=%s" $i [hex32 $w] [hex32 $tdfv_i]]
    incr i
}

banner "commit length"
set nbytes [expr {[llength $payload] * 4}]
must_wr32 [expr {$FIFO_BASE + $TLR}] $nbytes "FIFO+TLR"
puts [format "TLR=%d bytes" $nbytes]

banner "poll ISR + RDFO (progress)"
set timeout_iters 400
set last_isr 0
set last_rdfo 0
for {set k 0} {$k < $timeout_iters} {incr k} {
    set isr  [must_rd32 [expr {$FIFO_BASE + $ISR}]  "FIFO+ISR poll"]
    set rdfo [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO poll"]
    set words [expr {$rdfo & 0x1FFFF}]
    if {$isr != $last_isr || $rdfo != $last_rdfo} {
        puts [format "k=%d  ISR=%s  RDFO=%s (words=%d)" $k [hex32 $isr] [hex32 $rdfo] $words]
        set last_isr $isr
        set last_rdfo $rdfo
    }
    if {$words >= 4} { break }
    after 5
}

set rdfo_f [must_rd32 [expr {$FIFO_BASE + $RDFO}] "FIFO+RDFO final"]
set words_f [expr {$rdfo_f & 0x1FFFF}]
puts [format "FINAL RDFO=%s (words=%d)" [hex32 $rdfo_f] $words_f]

if {$words_f < 4} {
    set isr_f [must_rd32 [expr {$FIFO_BASE + $ISR}] "FIFO+ISR final"]
    puts [format "FINAL ISR=%s  (TXCMPL=%d RXCMPL=%d)"
        [hex32 $isr_f]
        [expr {($isr_f & $ISR_TXCMPL) != 0}]
        [expr {($isr_f & $ISR_RXCMPL) != 0}]
    ]
    error "No RX words. Use the prints above to decide next fix."
}

banner "read back 4 words"
for {set j 0} {$j < 4} {incr j} {
    set v [must_rd32 [expr {$FIFO_BASE + $RDFD}] "FIFO+RDFD"]
    puts [format "RX[%d]=%s" $j [hex32 $v]]
}

puts "DONE"
