# capture/config.py

import pathlib

# Symbol and endpoints
SYMBOL = "BTCUSDT"

# Binance endpoints (Spot API)
# Official docs: https://binance-docs.github.io/apidocs/spot/en/
REST_DEPTH_URL = (
    f"https://api.binance.com/api/v3/depth?symbol={SYMBOL}&limit=1000"
)
WS_DEPTH_STREAM_URL = (
    f"wss://stream.binance.com:9443/ws/{SYMBOL.lower()}@depth@100ms"
)

# Logging
BASE_DIR = pathlib.Path(__file__).resolve().parent.parent
LOG_FILE = BASE_DIR / "binance_depth.log"

# Capture behaviour
# Flush to disk every N websocket messages to avoid excessive fsyncs.
FLUSH_INTERVAL = 50

# Max websocket message size (bytes); 16 MiB is plenty for depth updates.
WS_MAX_SIZE = 16 * 1024 * 1024
