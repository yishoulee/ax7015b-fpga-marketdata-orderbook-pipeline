# xsct_read_tap_regs.tcl
# Read AXI-Lite tap registers (hash + counters). Self-contained: sets memmap.
#
# Usage:
#   xsct xsct_read_tap_regs.tcl -tap_base 0x40000000

proc usage {} {
  puts "Usage: xsct xsct_read_tap_regs.tcl -tap_base <hex>"
}

proc arg_value {args name default} {
  set idx [lsearch -exact $args $name]
  if {$idx < 0} { return $default }
  if {$idx + 1 >= [llength $args]} { return $default }
  return [lindex $args [expr {$idx + 1}]]
}

proc mrd_u32 {addr} {
  # mrd often returns: "40000000:   651E42BC\n"
  # Avoid split() because repeated spaces/newlines produce trailing empty tokens.
  set s [string trim [mrd $addr]]

  # Grab the last hex word on the line (works with/without 0x prefixes)
  if {![regexp {([0-9A-Fa-f]{1,8})$} $s -> tok]} {
    error "mrd_u32: cannot parse '$s'"
  }
  if {[scan $tok "%x" val] != 1} {
    error "mrd_u32: scan failed for tok='$tok' from '$s'"
  }
  return $val
}

# -------- main --------
set base [arg_value $argv "-tap_base" ""]
if {$base eq ""} { usage; exit 1 }

puts "=== connect ==="
connect
puts "=== targets ==="
targets
puts "=== target -set 1 (APU) ==="
target -set 1

# Required: add the PL AXI slave window to XSCT's memory map before reading it.
puts "=== memmap set (TAP only) ==="
memmap -addr $base -size 0x00010000 -flags 3
puts "=== memmap -list ==="
memmap -list

puts "=== read TAP regs ==="
puts [format "TAP_BASE=%s" $base]

set last  [mrd_u32 [format 0x%08X [expr {$base + 0x00}]]]
set words [mrd_u32 [format 0x%08X [expr {$base + 0x04}]]]
set pkts  [mrd_u32 [format 0x%08X [expr {$base + 0x08}]]]

puts [format "TAP_last_hash=0x%08X" $last]
puts [format "TAP_word_count=%u" $words]
puts [format "TAP_pkt_count=%u" $pkts]
