puts "=== connect ==="
puts [connect]

puts "=== targets ==="
puts [targets]

# If target indexing differs, keep your known-good selection
puts "=== target -set 1 ==="
target -set 1
puts [targets]

puts "=== memmap before ==="
puts [memmap -list]

puts "=== memmap add 0x43C00000 64KB ==="
memmap -addr 0x43C00000 -size 0x00010000

puts "=== memmap after ==="
puts [memmap -list]

puts "=== reads/writes ==="
puts [mrd 0x43C00000]
mwr 0x43C00000 0x00000001
mwr 0x43C00000 0x00000000
puts [mrd 0x43C00004]

puts "=== done ==="
exit
