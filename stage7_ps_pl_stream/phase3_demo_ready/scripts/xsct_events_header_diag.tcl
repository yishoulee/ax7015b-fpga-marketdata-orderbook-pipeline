# xsct_events_header_diag.tcl
# Usage:
#   xsct xsct_events_header_diag.tcl -in path/to/events.bin

proc usage {} {
  puts "Usage: xsct xsct_events_header_diag.tcl -in <events.bin>"
  exit 1
}

set IN_PATH ""
for {set i 0} {$i < $argc} {incr i} {
  set a [lindex $argv $i]
  if {$a eq "-in"} {
    incr i; set IN_PATH [lindex $argv $i]
  } else {
    puts "Unknown arg: $a"
    usage
  }
}
if {$IN_PATH eq ""} { usage }

proc hex8_of_bytes {b} {
  # b must be 4 bytes; return 8 hex chars
  binary scan $b H8 hx
  return $hx
}

proc u32_le_from_hex8 {hx} {
  # hx is 8 hex chars representing bytes in file order: b0 b1 b2 b3
  # Value = b0 + (b1<<8) + (b2<<16) + (b3<<24)
  set b0s [string range $hx 0 1]
  set b1s [string range $hx 2 3]
  set b2s [string range $hx 4 5]
  set b3s [string range $hx 6 7]
  scan $b0s %x b0
  scan $b1s %x b1
  scan $b2s %x b2
  scan $b3s %x b3
  return [expr {($b0 & 0xFF) | (($b1 & 0xFF)<<8) | (($b2 & 0xFF)<<16) | (($b3 & 0xFF)<<24)}]
}

proc u64_le_from_8bytes {b8} {
  # b8 is 8 bytes: lo(u32) then hi(u32), little-endian
  set lo [u32_le_from_hex8 [hex8_of_bytes [string range $b8 0 3]]]
  set hi [u32_le_from_hex8 [hex8_of_bytes [string range $b8 4 7]]]
  return [expr {$hi * 4294967296 + $lo}]
}

set fin [open $IN_PATH "rb"]
fconfigure $fin -translation binary -encoding binary
set hdr [read $fin 64]
close $fin

set got [string length $hdr]
puts "IN=$IN_PATH header_bytes_read=$got"
if {$got != 64} { error "failed to read 64-byte header" }

# Print raw header hex (first 64 bytes)
binary scan $hdr H128 hdrhex
puts "HDR_HEX=$hdrhex"

# Parse fields using only slicing + hex + scan
set magic [string range $hdr 0 7]
binary scan $magic H16 magichex
puts "magic_ascii=<$magic> magic_hex=$magichex"

set ver   [u32_le_from_hex8 [hex8_of_bytes [string range $hdr  8 11]]]
set recsz [u32_le_from_hex8 [hex8_of_bytes [string range $hdr 12 15]]]
set pscale [u64_le_from_8bytes [string range $hdr 16 23]]
set qscale [u64_le_from_8bytes [string range $hdr 24 31]]

set sym16 [string range $hdr 32 47]
set sym [string trimright $sym16 "\x00"]
binary scan $sym16 H32 symhex

puts "version=$ver record_size=$recsz price_scale=$pscale qty_scale=$qscale"
puts "symbol_ascii=<$sym> symbol_hex=$symhex"

exit 0
