# xsct_hash_tap_smoke.tcl
# Usage:
#   xsct xsct_hash_tap_smoke.tcl -fifo_base 0x43C00000 -tap_base 0x40000000

proc usage {} {
  puts "Usage: xsct xsct_hash_tap_smoke.tcl -fifo_base 0x43C00000 -tap_base 0x40000000"
  exit 1
}

proc parse_args {argv} {
  array set A {}
  set i 0
  while {$i < [llength $argv]} {
    set k [lindex $argv $i]
    incr i
    if {$i >= [llength $argv]} { usage }
    set v [lindex $argv $i]
    incr i
    set A($k) $v
  }
  return [array get A]
}

proc hex_u32 {x} {
  if {[string match "0x*" $x] || [string match "0X*" $x]} {
    scan $x %x v
  } else {
    scan $x %d v
  }
  return [expr {$v & 0xFFFFFFFF}]
}

proc mrd_u32 {addr} {
  set s [mrd $addr]
  if {![regexp {([0-9A-Fa-f]{8})\s*$} $s -> hex8]} {
    error "mrd_u32: cannot parse '$s'"
  }
  scan $hex8 %x v
  return [expr {$v & 0xFFFFFFFF}]
}

proc mwr_u32 {addr val} {
  set v [expr {$val & 0xFFFFFFFF}]
  mwr $addr [format 0x%08X $v]
}

# ---------------- main ----------------

array set ARGS [parse_args $argv]
if {![info exists ARGS(-fifo_base)] || ![info exists ARGS(-tap_base)]} { usage }

set FIFO_BASE [hex_u32 $ARGS(-fifo_base)]
set TAP_BASE  [hex_u32 $ARGS(-tap_base)]

# FIFO regs (AXI FIFO MM-S)
set ISR  0x00
set IER  0x04
set TDFR 0x08
set TDFV 0x0C
set TDFD 0x10
set TLR  0x14
set RDFR 0x18
set RDFO 0x1C
set RDFD 0x20
# NOTE: do not read RLR (0x24)

# Tap regs
set REG_LAST_HASH  0x00
set REG_WORD_COUNT 0x04
set REG_PKT_COUNT  0x08

puts "=== connect ==="
connect

puts "=== targets ==="
targets

puts "=== target -set 1 (APU) ==="
target -set 1

puts "=== memmap set (FIFO + TAP) ==="
memmap -addr $FIFO_BASE -size 0x10000 -flags 3
memmap -addr $TAP_BASE  -size 0x1000  -flags 3

puts "=== probe FIFO regs (sanity) ==="
puts [format "FIFO_BASE=0x%08X" $FIFO_BASE]
puts [format "FIFO_ISR_0x00=0x%08X" [mrd_u32 [expr {$FIFO_BASE + $ISR}]]]
puts [format "FIFO_IER_0x04=0x%08X" [mrd_u32 [expr {$FIFO_BASE + $IER}]]]
puts [format "FIFO_TDFV_0x0C=0x%08X" [mrd_u32 [expr {$FIFO_BASE + $TDFV}]]]
puts [format "FIFO_RDFO_0x1C=0x%08X" [mrd_u32 [expr {$FIFO_BASE + $RDFO}]]]

puts "=== probe TAP regs (pre) ==="
puts [format "TAP_BASE=0x%08X" $TAP_BASE]
set pre_hash [mrd_u32 [expr {$TAP_BASE + $REG_LAST_HASH}]]
set pre_wc   [mrd_u32 [expr {$TAP_BASE + $REG_WORD_COUNT}]]
set pre_pc   [mrd_u32 [expr {$TAP_BASE + $REG_PKT_COUNT}]]
puts [format "TAP_last_hash=0x%08X TAP_word_count=%u TAP_pkt_count=%u" $pre_hash $pre_wc $pre_pc]

puts "=== reset FIFO TX/RX (TDFR/RDFR) ==="
mwr_u32 [expr {$FIFO_BASE + $TDFR}] 0xA5
mwr_u32 [expr {$FIFO_BASE + $RDFR}] 0xA5

puts "=== TX write payload to TDFD ==="
set words [list 0xFFFFFFFF 0x12345678 0x00010203 0x08090A0B 0x10111213 0x18191A1B 0x20212223 0x28292A2B]
set idx 0
foreach w $words {
  puts [format "TX_%d=0x%08X" $idx [hex_u32 $w]]
  mwr_u32 [expr {$FIFO_BASE + $TDFD}] [hex_u32 $w]
  incr idx
}

puts "=== TX commit length (TLR starts transmission) ==="
set nwords [llength $words]
set nbytes [expr {$nwords * 4}]
puts [format "TLR_bytes=%d TLR_words=%d" $nbytes $nwords]
mwr_u32 [expr {$FIFO_BASE + $TLR}] $nbytes

puts "=== poll RDFO until >= expected words ==="
set expected $nwords
set loops 0
set rdfo 0
while {$loops < 2000} {
  set rdfo [mrd_u32 [expr {$FIFO_BASE + $RDFO}]]
  set have [expr {$rdfo & 0xFFFF}]
  if {$have >= $expected} break
  after 1
  incr loops
}
puts [format "RDFO=0x%08X RDFO_words=%d expected=%d loops=%d" $rdfo [expr {$rdfo & 0xFFFF}] $expected $loops]
if {[expr {$rdfo & 0xFFFF}] < $expected} {
  error "TIMEOUT: did not receive expected words"
}

puts "=== RX read data (RDFD) ==="
set rx {}
for {set i 0} {$i < $nwords} {incr i} {
  set v [mrd_u32 [expr {$FIFO_BASE + $RDFD}]]
  lappend rx $v
  puts [format "RX_%d=0x%08X" $i $v]
}

puts "=== compare payload ==="
set pass 1
for {set i 0} {$i < $nwords} {incr i} {
  set a [hex_u32 [lindex $words $i]]
  set b [lindex $rx $i]
  if {$a != $b} {
    puts [format "MISMATCH_i=%d TX=0x%08X RX=0x%08X" $i $a $b]
    set pass 0
  }
}
if {!$pass} { error "FAIL: loopback payload mismatch" }

puts "=== probe TAP regs (post) ==="
set post_hash [mrd_u32 [expr {$TAP_BASE + $REG_LAST_HASH}]]
set post_wc   [mrd_u32 [expr {$TAP_BASE + $REG_WORD_COUNT}]]
set post_pc   [mrd_u32 [expr {$TAP_BASE + $REG_PKT_COUNT}]]
puts [format "TAP_last_hash=0x%08X TAP_word_count=%u TAP_pkt_count=%u" $post_hash $post_wc $post_pc]

puts "PASS: FIFO loopback OK; TAP regs read OK"
exit 0
