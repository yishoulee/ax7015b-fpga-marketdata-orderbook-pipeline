# replay_events.tcl
# Usage:
#   xsct replay_events.tcl events.bin
#   xsct replay_events.tcl events.bin 10000

puts "SCRIPT START"
puts "argc=$argc argv=$argv"
flush stdout

proc u32 {x} {
  if {![string is integer -strict $x]} {
    error "u32: non-integer '$x'"
  }
  return [expr {wide($x) & 0xFFFFFFFF}]
}

proc mmio_write {addr val} {
  mwr $addr $val
}

proc mmio_read {addr} {
  # mrd prints; we also want return value -> use "mrd -value" if supported
  # Many XSCT builds support: mrd -value <addr>
  if {[catch {set v [mrd -value $addr]}]} {
    # fallback: parse mrd output
    set out [mrd $addr]
    # out usually contains: "ADDR: VALUE"
    regexp {:\s*([0-9A-Fa-f]+)} $out _ hex
    scan $hex %x v
  }
  return $v
}

# Mailbox register base
set BASE 0x43C00000
set REG0 [expr {$BASE + 0x00}]
set REG1 [expr {$BASE + 0x04}]
set REG2 [expr {$BASE + 0x08}]  ;# DATA / stats
set REG3 [expr {$BASE + 0x0C}]  ;# CTRL/STATUS

# CTRL bits
set PUSH  0x00000100
set CLEAR 0x00000200

proc set_idx {idx} {
  global REG3
  mmio_write $REG3 $idx
}

proc write_word {idx word} {
  global REG2
  set_idx $idx
  mmio_write $REG2 $word
}

proc do_clear {} {
  global REG3 CLEAR
  mmio_write $REG3 $CLEAR
}

proc do_push {} {
  global REG3 PUSH
  mmio_write $REG3 $PUSH
}

proc status_read {} {
  global REG3
  return [mmio_read $REG3]
}

proc event_valid {status} {
  # In your implementation: bit31 is event_valid
  return [expr {($status >> 31) & 1}]
}

proc stat_read {sel} {
  # sel: 0 events_in, 1 drops, 2 checksum, 3 last_seq
  global REG3 REG2
  set ctrl [expr {($sel & 3) << 10}]
  mmio_write $REG3 $ctrl
  return [mmio_read $REG2]
}

proc replay_file {path max_events} {
  # open binary file
  set f [open $path "rb"]
  fconfigure $f -translation binary -encoding binary

  # Baseline stats (counters accumulate across runs unless you re-program or add a reset bit)
  set e_in0  [stat_read 0]
  set dr0    [stat_read 1]
  set cs0    [stat_read 2]
  set ls0    [stat_read 3]

  puts [format "START events_in=0x%08X drops=0x%08X checksum32=0x%08X last_seq=0x%08X" \
        [u32 $e_in0] [u32 $dr0] [u32 $cs0] [u32 $ls0]]
  flush stdout

  set count 0
  set t0 [clock milliseconds]

  while {1} {
    if {$max_events >= 0 && $count >= $max_events} {
      break
    }

    set bytes [read $f 32]
    if {[string length $bytes] != 32} {
      break
    }

    # 8 little-endian 32-bit integers (Tcl 'i' is native-endian; in Vitis/XSCT on x86 this is little-endian)
    # We treat them as u32 via u32().
    set words {}
    set nconv [binary scan $bytes i8 words]
    if {$nconv != 1} {
      error "binary scan failed (nconv=$nconv), got [string length $bytes] bytes"
    }
    lassign $words w0 w1 w2 w3 w4 w5 w6 w7

    # Write W0..W7 (idx in REG3 then data in REG2)
    write_word 0 [u32 $w0]
    write_word 1 [u32 $w1]
    write_word 2 [u32 $w2]
    write_word 3 [u32 $w3]
    write_word 4 [u32 $w4]
    write_word 5 [u32 $w5]
    write_word 6 [u32 $w6]
    write_word 7 [u32 $w7]

    # PUSH then CLEAR (CLEAR only clears event_valid/mask in your current RTL; counters keep accumulating)
    do_push
    do_clear

    incr count
    if {($count % 100) == 0} {
      puts "progress: $count events"
      flush stdout
    }
  }

  close $f

  set t1 [clock milliseconds]
  set dt_ms [expr {$t1 - $t0}]
  if {$dt_ms <= 0} { set dt_ms 1 }
  set eps [expr {double($count) * 1000.0 / double($dt_ms)}]

  # Final stats
  set e_in1  [stat_read 0]
  set dr1    [stat_read 1]
  set cs1    [stat_read 2]
  set ls1    [stat_read 3]

  set de_in [expr {[u32 $e_in1] - [u32 $e_in0]}]
  set ddr   [expr {[u32 $dr1]   - [u32 $dr0]}]

  set dcs   [expr {[u32 $cs1] ^ [u32 $cs0]}]
  set dls   [expr {[u32 $ls1] - [u32 $ls0]}]

  puts "Replayed events: $count"
  puts "Elapsed ms: $dt_ms"
  puts "Throughput events/s: $eps"

  puts [format "events_in  = 0x%08X (%u)" [u32 $e_in1] [u32 $e_in1]]
  puts [format "drops      = 0x%08X (%u)" [u32 $dr1]   [u32 $dr1]]
  puts [format "checksum32 = 0x%08X"      [u32 $cs1]]
  puts [format "last_seq   = 0x%08X (%u)" [u32 $ls1]   [u32 $ls1]]

  # puts [format "DELTA events_in=%u drops=%u" $de_in $ddr]
  puts [format "DELTA events_in=%u drops=%u checksum32_xor=0x%08X last_seq=%u" $de_in $ddr [u32 $dcs] [u32 $ls1]]

  flush stdout
}


# Entry
if {$argc < 1} {
  puts "Usage: xsct replay_events.tcl <events.bin> [max_events]"
  exit 1
}

set file_path [lindex $argv 0]
set max_events -1
if {$argc >= 2} {
  set max_events [lindex $argv 1]
}

connect
targets
targets -set 1
memmap -addr 0x43C00000 -size 0x00010000 -flags 3
puts [format "counter0=0x%08X" [mrd -value 0x43C00004]]
flush stdout


targets -set 2


# Clear at start to reset state
do_clear

replay_file $file_path $max_events