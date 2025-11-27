set_property PACKAGE_PIN Y14 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name pl_clk -period 20.000 [get_ports clk]  ;# 50 MHz

# Active-low reset on PL user key button
set_property PACKAGE_PIN AB12 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PULLUP true [get_ports rst_n]  ;# so it idles high

# UART RX serial from J12 pin 3 (M1)
set_property PACKAGE_PIN M1 [get_ports uart_rx_serial]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_serial]
