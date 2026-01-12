# xsct_tap_read.tcl
# Usage:
#   xsct xsct_tap_read.tcl -tap_base 0x40000000

proc usage {} {
  puts "Usage: xsct xsct_tap_read.tcl -tap_base 0x40000000"
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

array set ARGS [parse_args $argv]
if {![info exists ARGS(-tap_base)]} { usage }

set TAP_BASE [hex_u32 $ARGS(-tap_base)]

# Tap regs (must match your RTL)
set REG_LAST_HASH  0x00
set REG_WORD_COUNT 0x04
set REG_PKT_COUNT  0x08

puts "=== connect ==="
connect
puts "=== targets ==="
targets
puts "=== target -set 1 (APU) ==="
target -set 1

puts "=== memmap set (TAP only) ==="
memmap -addr $TAP_BASE -size 0x1000 -flags 3

set h  [mrd_u32 [expr {$TAP_BASE + $REG_LAST_HASH}]]
set wc [mrd_u32 [expr {$TAP_BASE + $REG_WORD_COUNT}]]
set pc [mrd_u32 [expr {$TAP_BASE + $REG_PKT_COUNT}]]

puts [format "TAP_BASE=0x%08X" $TAP_BASE]
puts [format "TAP_last_hash=0x%08X" $h]
puts [format "TAP_word_count=%u" $wc]
puts [format "TAP_pkt_count=%u" $pc]

exit 0
