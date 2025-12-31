# stage7_ps_pl_stream/phase3_demo_ready/scripts/xsct_replay_events_loopback.tcl
#
# Replay event_t v0 records from events.bin into AXI FIFO MM-S TX,
# read them back from RX (requires a TX->RX loopback path in the programmed bitstream),
# and write a new events.bin to OUT (same 64B header + payload).
#
# Usage:
#   xsct xsct_replay_events_loopback.tcl \
#     -base 0x43C00000 \
#     -in   stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.bin \
#     -out  stage7_ps_pl_stream/phase3_demo_ready/data/sample_btcusdt_depth.events.loopback.bin \
#     -chunk_records 40
#
# Notes:
# - Record size is 48 bytes => 12 x 32-bit words per record.
# - Chunk size must fit TX vacancy (TDFV). With typical TDFV~0x1FC=508 words,
#   chunk_records=40 => 480 words is safe.
# - Avoids RLR(0x24) completely.
# - Robustly parses XSCT `mrd` output: always uses the value after ":" when present.

proc usage {} {
  puts "Usage: xsct xsct_replay_events_loopback.tcl -base <hex> -in <events.bin> -out <loopback.bin> -chunk_records <N>"
  exit 1
}

# ---------------- args ----------------
set BASE ""
set IN_PATH ""
set OUT_PATH ""
set CHUNK_RECORDS 40

for {set i 0} {$i < $argc} {incr i} {
  set a [lindex $argv $i]
  if {$a eq "-base"} {
    incr i; set BASE [lindex $argv $i]
  } elseif {$a eq "-in"} {
    incr i; set IN_PATH [lindex $argv $i]
  } elseif {$a eq "-out"} {
    incr i; set OUT_PATH [lindex $argv $i]
  } elseif {$a eq "-chunk_records"} {
    incr i; set CHUNK_RECORDS [lindex $argv $i]
  } else {
    puts "Unknown arg: $a"
    usage
  }
}
if {$BASE eq "" || $IN_PATH eq "" || $OUT_PATH eq ""} { usage }

# ---------------- constants ----------------
set HDR_SIZE 64
set REC_SIZE 48
set WORDS_PER_REC [expr {$REC_SIZE / 4}]
set RESET_KEY 0xA5

# FIFO offsets (byte offsets)
set TDFR 0x08
set TDFV 0x0C
set TDFD 0x10
set TLR  0x14
set RDFR 0x18
set RDFO 0x1C
set RDFD 0x20

# ---------------- utils: base parsing ----------------
proc u32 {x} {
  if {[string match "0x*" $x]} { return [expr {$x}] }
  return [expr {$x}]
}

proc sleep_ms {ms} { after $ms }

# ---------------- utils: robust mrd/mwr ----------------
proc mrd_u32 {addr} {
  set s [string trim [mrd $addr]]

  # Handle:
  #   "0x43c0001c: 0x000001e0"
  #   "43C0001C:   000001E0"
  # Always prefer the token after ":" (the value).
  if {[regexp -nocase {:\s*(0x[0-9a-f]+|[0-9a-f]+)} $s -> tok]} {
    # tok may be "0x...." or "...."
    scan $tok %x v
    return [expr {$v & 0xFFFFFFFF}]
  }

  # Fallback: take the last hex-looking token on the line.
  # Split on whitespace and ":" and pick last non-empty.
  set parts [split $s " \t:"]
  set last ""
  foreach p $parts {
    if {$p ne ""} { set last $p }
  }
  if {$last ne "" && [regexp -nocase {^(0x)?[0-9a-f]+$} $last]} {
    scan $last %x v
    return [expr {$v & 0xFFFFFFFF}]
  }

  error "mrd_u32: cannot parse '$s'"
}


proc wr_u32 {addr val} {
  mwr $addr [format 0x%08X [expr {$val & 0xFFFFFFFF}]]
}

# ---------------- utils: file I/O ----------------
proc file_size {path} {
  set ch [open $path "rb"]
  fconfigure $ch -translation binary -encoding binary
  seek $ch 0 end
  set sz [tell $ch]
  close $ch
  return $sz
}

proc read_bytes_exact {ch n} {
  set b [read $ch $n]
  if {[string length $b] != $n} {
    error "short read: expected $n got [string length $b]"
  }
  return $b
}

# ---------------- utils: header parsing (XSCT-safe) ----------------
proc hex8_of_bytes {b} {
  binary scan $b H8 hx
  return $hx
}

proc u32_le_from_hex8 {hx} {
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
  set lo [u32_le_from_hex8 [hex8_of_bytes [string range $b8 0 3]]]
  set hi [u32_le_from_hex8 [hex8_of_bytes [string range $b8 4 7]]]
  return [expr {$hi * 4294967296 + $lo}]
}

proc parse_header {hdr} {
  if {[string length $hdr] != 64} { error "header must be 64 bytes" }
  set magic [string range $hdr 0 7]
  set ver   [u32_le_from_hex8 [hex8_of_bytes [string range $hdr  8 11]]]
  set recsz [u32_le_from_hex8 [hex8_of_bytes [string range $hdr 12 15]]]
  set pscale [u64_le_from_8bytes [string range $hdr 16 23]]
  set qscale [u64_le_from_8bytes [string range $hdr 24 31]]
  set sym16 [string range $hdr 32 47]
  set sym [string trimright $sym16 "\x00"]
  return [list $magic $ver $recsz $pscale $qscale $sym]
}

# ---------------- utils: payload packing ----------------
proc bytes_to_u32_list_le {b} {
  set n [string length $b]
  if {$n % 4 != 0} { error "bytes_to_u32_list_le: length not multiple of 4" }
  set out {}
  for {set i 0} {$i < $n} {incr i 4} {
    set w4 [string range $b $i [expr {$i+3}]]
    set hx [hex8_of_bytes $w4]
    set v [u32_le_from_hex8 $hx]
    lappend out $v
  }
  return $out
}

proc u32_list_to_bytes_le {lst} {
  set out ""
  foreach v $lst {
    set vv [expr {$v & 0xFFFFFFFF}]
    set b0 [expr {$vv & 0xFF}]
    set b1 [expr {($vv >> 8) & 0xFF}]
    set b2 [expr {($vv >> 16) & 0xFF}]
    set b3 [expr {($vv >> 24) & 0xFF}]
    append out [binary format H8 [format %02x%02x%02x%02x $b0 $b1 $b2 $b3]]
  }
  return $out
}

# ---------------- main ----------------
set base [u32 $BASE]

puts "=== connect ==="
connect
puts "=== targets ==="
targets
puts "=== target -set 1 (APU) ==="
target -set 1

puts "=== memmap set (FIFO only) ==="
memmap -addr $base -size 0x10000 -flags 3

puts "=== reset FIFO TX/RX ==="
wr_u32 [format 0x%08X [expr {$base + $TDFR}]] $RESET_KEY
wr_u32 [format 0x%08X [expr {$base + $RDFR}]] $RESET_KEY
sleep_ms 10

set in_sz [file_size $IN_PATH]
if {$in_sz < $HDR_SIZE} { error "input too small: $in_sz" }

set payload_sz [expr {$in_sz - $HDR_SIZE}]
if {$payload_sz % $REC_SIZE != 0} {
  error "payload size not multiple of record size: payload=$payload_sz rec=$REC_SIZE"
}
set total_records [expr {$payload_sz / $REC_SIZE}]

puts "=== input ==="
puts "IN=$IN_PATH size=$in_sz payload=$payload_sz total_records=$total_records chunk_records=$CHUNK_RECORDS"

set fin [open $IN_PATH "rb"]
fconfigure $fin -translation binary -encoding binary
set hdr [read_bytes_exact $fin $HDR_SIZE]

set hp [parse_header $hdr]
lassign $hp magic ver recsz pscale qscale sym

binary scan $magic H16 magichex
puts "HEADER magichex=$magichex ver=$ver recsz=$recsz symbol=$sym price_scale=$pscale qty_scale=$qscale"

if {$magic ne "EVT0BIN\x00"} { error "bad magic" }
if {$ver != 0} { error "unsupported version $ver" }
if {$recsz != $REC_SIZE} { error "unexpected record_size $recsz (expected $REC_SIZE)" }

set fout [open $OUT_PATH "wb"]
fconfigure $fout -translation binary -encoding binary
puts -nonewline $fout $hdr

# Clamp chunk_records to safe range for typical TDFV~508 words.
set chunk_records $CHUNK_RECORDS
if {$chunk_records < 1} { error "chunk_records must be >= 1" }
if {$chunk_records > 40} {
  puts "WARN: chunk_records=$chunk_records clamped to 40 (TX vacancy safe default)"
  set chunk_records 40
}

set sent 0
while {$sent < $total_records} {
  set remain [expr {$total_records - $sent}]
  set this_recs [expr {($remain < $chunk_records) ? $remain : $chunk_records}]
  set this_bytes [expr {$this_recs * $REC_SIZE}]

  set chunk [read_bytes_exact $fin $this_bytes]
  set words [bytes_to_u32_list_le $chunk]

  # TX write
  foreach w $words {
    wr_u32 [format 0x%08X [expr {$base + $TDFD}]] $w
  }

  # Commit packet length (bytes)
  wr_u32 [format 0x%08X [expr {$base + $TLR}]] $this_bytes

  # Wait RX occupancy
  set need_words [expr {$this_bytes / 4}]
  set tries 0
  while {1} {
    set rdfo [mrd_u32 [format 0x%08X [expr {$base + $RDFO}]]]
    if {$rdfo >= $need_words} { break }
    incr tries
    if {$tries > 5000} {
      error "timeout waiting RDFO >= $need_words (got $rdfo). Check loopback wiring in bitstream."
    }
    sleep_ms 1
  }

  # RX read
  set rx_words {}
  for {set k 0} {$k < $need_words} {incr k} {
    set v [mrd_u32 [format 0x%08X [expr {$base + $RDFD}]]]
    lappend rx_words $v
  }

  puts -nonewline $fout [u32_list_to_bytes_le $rx_words]

  set sent [expr {$sent + $this_recs}]
  puts "chunk sent_records=$sent / $total_records packet_bytes=$this_bytes"
}

close $fin
close $fout

puts "DONE: wrote loopback file: $OUT_PATH"
exit 0
