# replay/config.py

# UART configuration
# Adjust PORT to match your system:
#   Linux example: "/dev/ttyS0" or "/dev/ttyUSB0"
#   Windows example: "COM3"
UART_PORT = "/dev/ttyS0"

# Baud rate: pick a value your USB-UART and board support.
UART_BAUDRATE = 115200

# Optional: RTS/CTS flow control (False by default)
UART_RTSCTS = False

# Replay behaviour
DEFAULT_MODE = "realtime"  # "realtime" or "accelerated"
DEFAULT_SPEED = 5.0        # acceleration factor when mode == "accelerated"
