# send_known_record.py
import struct
import serial
import sys
import time

if len(sys.argv) != 2:
    print("Usage: python send_known_record.py /dev/ttyUSBx")
    sys.exit(1)

port = sys.argv[1]

RECORD_STRUCT = struct.Struct("<QQBffxxxxxxx")

ts_ns     = 1234567890123456789
update_id = 9876543210
side      = 1
price     = 100.5
qty       = 0.25

frame = RECORD_STRUCT.pack(ts_ns, update_id, side, price, qty)
print("len(frame) =", len(frame))
print("frame hex  =", frame.hex())

ser = serial.Serial(port, baudrate=115200)
time.sleep(0.1)  # small settle

for _ in range(4):
    ser.write(frame)
    time.sleep(0.02)

ser.close()
print("done")
