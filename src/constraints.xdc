## =============================================================================
## constraints.xdc
## Project : Real-Time Video Capture and Processing System
## Board   : Digilent Basys 3 (xc7a35tcpg236-1)
## Purpose : Pin assignments, I/O standards, and clock constraints for
##           OV7670 camera interface, VGA output, system clock, and reset.
## =============================================================================

## ---------------------------------------------------------------------------
## System Clock — W5, 100 MHz
## ---------------------------------------------------------------------------
set_property PACKAGE_PIN W5   [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk_100mhz [get_ports clk_100mhz]

## ---------------------------------------------------------------------------
## Reset Button — BTNC (active-high in RTL)
## ---------------------------------------------------------------------------
set_property PACKAGE_PIN U18  [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

set_property PACKAGE_PIN T18  [get_ports btnu]
set_property IOSTANDARD LVCMOS33 [get_ports btnu]

set_property PACKAGE_PIN M17  [get_ports btnr]
set_property IOSTANDARD LVCMOS33 [get_ports btnr]



## ---------------------------------------------------------------------------
## OV7670 Camera — Pixel Data (D0–D7)
## Per project spec pin table:
##   D0 → P17, D1 → N17, D2 → M19, D3 → M18
##   D4 → L17, D5 → K17, D6 → C16, D7 → B16
## ---------------------------------------------------------------------------
set_property PACKAGE_PIN P17  [get_ports {cam_d[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[0]}]

set_property PACKAGE_PIN N17  [get_ports {cam_d[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[1]}]

set_property PACKAGE_PIN M19  [get_ports {cam_d[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[2]}]

set_property PACKAGE_PIN M18  [get_ports {cam_d[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[3]}]

set_property PACKAGE_PIN L17  [get_ports {cam_d[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[4]}]

set_property PACKAGE_PIN K17  [get_ports {cam_d[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[5]}]

set_property PACKAGE_PIN C16  [get_ports {cam_d[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[6]}]

set_property PACKAGE_PIN B16  [get_ports {cam_d[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_d[7]}]

## ---------------------------------------------------------------------------
## OV7670 Camera — Control / Sync Signals
## ---------------------------------------------------------------------------
# HREF — horizontal reference (active during valid pixel line)
set_property PACKAGE_PIN A17  [get_ports cam_href]
set_property IOSTANDARD LVCMOS33 [get_ports cam_href]

# PCLK — pixel clock driven by camera (input to FPGA)
set_property PACKAGE_PIN A16  [get_ports cam_pclk]
set_property IOSTANDARD LVCMOS33 [get_ports cam_pclk]

# PWDN — power-down (active-high; drive low to enable camera)
set_property PACKAGE_PIN R18  [get_ports cam_pwdn]
set_property IOSTANDARD LVCMOS33 [get_ports cam_pwdn]

# RST  — camera hardware reset (active-low)
set_property PACKAGE_PIN P18  [get_ports cam_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports cam_rst_n]

# SCL  — SCCB clock
set_property PACKAGE_PIN A14  [get_ports cam_scl]
set_property IOSTANDARD LVCMOS33 [get_ports cam_scl]

# SDA  — SCCB data (bidirectional; constrain as output; Z-state for read)
set_property PACKAGE_PIN A15  [get_ports cam_sda]
set_property IOSTANDARD LVCMOS33 [get_ports cam_sda]

# VSYNC — vertical sync from camera (input)
set_property PACKAGE_PIN B15  [get_ports cam_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports cam_vsync]

# XCLK — master clock supplied to camera from FPGA (output)
set_property PACKAGE_PIN C15  [get_ports cam_xclk]
set_property IOSTANDARD LVCMOS33 [get_ports cam_xclk]

## ---------------------------------------------------------------------------
## VGA Output — Basys3 Reference Manual Figure 11
## RED[3:0] = JA header (VGA Pmod on JA)
## The Basys3 has a built-in 4-bit DAC resistor ladder for each channel.
## ---------------------------------------------------------------------------

# RED channel
set_property PACKAGE_PIN G19  [get_ports {vga_r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[0]}]

set_property PACKAGE_PIN H19  [get_ports {vga_r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[1]}]

set_property PACKAGE_PIN J19  [get_ports {vga_r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[2]}]

set_property PACKAGE_PIN N19  [get_ports {vga_r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_r[3]}]

# GREEN channel
set_property PACKAGE_PIN J17  [get_ports {vga_g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[0]}]

set_property PACKAGE_PIN H17  [get_ports {vga_g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[1]}]

set_property PACKAGE_PIN G17  [get_ports {vga_g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[2]}]

set_property PACKAGE_PIN D17  [get_ports {vga_g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_g[3]}]

# BLUE channel
set_property PACKAGE_PIN N18  [get_ports {vga_b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[0]}]

set_property PACKAGE_PIN L18  [get_ports {vga_b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[1]}]

set_property PACKAGE_PIN K18  [get_ports {vga_b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[2]}]

set_property PACKAGE_PIN J18  [get_ports {vga_b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_b[3]}]

# HSYNC
set_property PACKAGE_PIN P19  [get_ports vga_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_hsync]

# VSYNC
set_property PACKAGE_PIN R19  [get_ports vga_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vga_vsync]

## ---------------------------------------------------------------------------
## Slide Switches — SW[1:0] for filter selection
## ---------------------------------------------------------------------------
set_property PACKAGE_PIN V17  [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16  [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]

## ---------------------------------------------------------------------------
## LEDs — used for status/debugging
## ---------------------------------------------------------------------------
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]


set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ---------------------------------------------------------------------------
## Clock Domain Constraints
## ---------------------------------------------------------------------------
# Constrain cam_pclk as a 25 MHz clock (worst-case if prescaler is 1)
create_clock -period 40.000 -name cam_pclk [get_ports cam_pclk]

# Clock Groups - tell Vivado these domains are asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk_100mhz] \
    -group [get_clocks -include_generated_clocks pixel_clk] \
    -group [get_clocks cam_pclk]


## Bypass unconstrained port error if Vivado is being stubborn
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]

