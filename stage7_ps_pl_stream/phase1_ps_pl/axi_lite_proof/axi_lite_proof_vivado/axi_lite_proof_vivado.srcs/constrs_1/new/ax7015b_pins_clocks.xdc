## AX7015B PL LEDs (active-high via transistor)
## PL_LED1 -> A5, PL_LED2 -> A7, PL_LED3 -> A6, PL_LED4 -> B8
## Source pin map: [ALINX AX7015B "PL Hello World" LED tutorial](https://ax7015b-20231-v101.readthedocs.io/zh-cn/latest/7015B_S1_RSTdocument_CN/04_PL%E7%9A%84_CN.html)

# Pick ONE of the following PACKAGE_PIN lines:

set_property PACKAGE_PIN A5 [get_ports {led_out_0}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_out_0}]
# set_property PACKAGE_PIN A7 [get_ports {led_out_0}]  ; # PL_LED2
# set_property PACKAGE_PIN A6 [get_ports {led_out_0}]  ; # PL_LED3
# set_property PACKAGE_PIN B8 [get_ports {led_out_0}]  ; # PL_LED4


set_property IOSTANDARD LVCMOS33 [get_ports {led_out_0}]
set_property SLEW SLOW [get_ports {led_out_0}]
set_property DRIVE 8 [get_ports {led_out_0}]
