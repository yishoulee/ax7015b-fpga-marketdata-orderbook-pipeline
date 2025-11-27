SHELL := /bin/bash

# Configurable variables
PYTHON ?= python
LOG ?= binance_depth.log
MODE ?= realtime       # realtime | accelerated
SPEED ?= 5.0           # used when MODE=accelerated
UART ?= /dev/ttyUSB0
BAUD ?=

.PHONY: help install capture inspect replay replay-accel clean

help:
	@echo "Stage-2 Host-Side Binance Depth Capture + Replay"
	@echo ""
	@echo "Usage:"
	@echo "  make install                 # Install Python deps (use active Conda env)"
	@echo "  make capture                 # Run Binance depth capture"
	@echo "  make inspect [LOG=path]      # Inspect a log (default: $(LOG))"
	@echo "  make replay  [LOG=path MODE=realtime|accelerated SPEED=1.0 UART=/dev/ttyS0 BAUD=115200]"
	@echo "                               # Replay log over UART with timing"
	@echo "  make replay-accel [LOG=path SPEED=5.0]"
	@echo "                               # Convenience: accelerated replay"
	@echo "  make clean                   # Remove caches and logs"
	@echo ""
	@echo "Examples:"
	@echo "  make install"
	@echo "  make capture"
	@echo "  make inspect LOG=binance_depth.log"
	@echo "  make replay LOG=binance_depth.log MODE=realtime UART=/dev/ttyS0 BAUD=115200"
	@echo "  make replay-accel LOG=binance_depth.log SPEED=5.0"

install:
	$(PYTHON) -m pip install -r requirements.txt

capture:
	$(PYTHON) -m capture.capture_binance_depth

inspect:
	$(PYTHON) -m tools.inspect_log $(LOG)

replay:
	$(PYTHON) -m replay.replay_uart --mode $(MODE) --speed $(SPEED) $(if $(UART),--port $(UART),) $(if $(BAUD),--baud $(BAUD),) $(LOG)

replay-accel:
	$(MAKE) replay LOG=$(LOG) MODE=accelerated SPEED=$(SPEED)


clean:
	rm -rf **/__pycache__
	find . -name "*.pyc" -delete
	rm -f *.log
