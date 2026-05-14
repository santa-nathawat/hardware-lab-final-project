# Real-Time OV7670 Video Capture and VGA Processing System

This project implements a live video pipeline on a Basys 3 FPGA. It captures RGB565 video from an OV7670 camera module, stores a downsampled frame in on-chip Block RAM, applies a switch-selectable image filter, and outputs the result to a VGA monitor at 640x480 timing.

## Hardware

- Basys 3 FPGA board, Artix-7 `xc7a35t`
- OV7670 parallel camera module
- VGA monitor and cable
- Jumper wires for the camera Pmod connections

## Features

- OV7670 camera configuration over SCCB, an I2C-like camera control bus
- Parallel camera capture using `cam_pclk`, `cam_href`, `cam_vsync`, and `cam_d[7:0]`
- RGB565 pixel packing from two 8-bit camera transfers
- Edge guarding to skip unstable OV7670 startup rows/columns
- 640x480 camera stream downsampled to a 320x240 frame buffer
- True dual-port BRAM frame buffer with independent camera-write and VGA-read clocks
- VGA 640x480 display timing from a 25 MHz pixel clock
- Switch-selectable filters:
  - `SW[1:0] = 00`: raw color
  - `SW[1:0] = 01`: grayscale
  - `SW[1:0] = 10`: red channel only
  - `SW[1:0] = 11`: color inversion

## Architecture

```text
OV7670 camera
  -> ov7670_capture
  -> frame_buffer true dual-port BRAM
  -> display_scaler
  -> filter_engine
  -> VGA output
```

Camera configuration is handled separately:

```text
ov7670_config -> sccb_master -> OV7670 SCCB pins
```

Clock domains:

| Clock | Frequency | Purpose |
| --- | ---: | --- |
| `clk_100mhz` | 100 MHz | System clock and SCCB configuration |
| `pixel_clk` | 25 MHz | VGA timing, display pipeline, BRAM read port |
| `cam_xclk` | 24 MHz | Master clock driven out to the OV7670 |
| `cam_pclk` | about 12-25 MHz | Camera capture and BRAM write port |

`frame_done` crosses from the camera clock domain into the VGA pixel clock domain using a toggle synchronizer. The display stays black until a complete frame has been captured.

## Main Source Modules

| Module | Description |
| --- | --- |
| `top.v` | Integrates all modules, clocks, resets, CDC, and VGA sync alignment |
| `ov7670_capture.v` | Captures camera bytes, creates RGB565 pixels, downsamples, writes BRAM |
| `ov7670_config.v` | Sends the OV7670 register configuration sequence |
| `sccb_master.v` | Generates SCCB write transactions |
| `frame_buffer.v` | Wraps the Xilinx Block Memory Generator true dual-port RAM |
| `vga_controller.v` | Generates 640x480 VGA counters and sync pulses |
| `display_scaler.v` | Maps VGA coordinates to frame-buffer addresses and drives VGA RGB |
| `filter_engine.v` | Applies raw, grayscale, red-only, and inversion filters |

## Running Simulations

The test benches use Cocotb and Icarus Verilog.

Install Cocotb, then run each module test:

```sh
conda activate cocotb
python sim/test_filter_engine.py
python sim/test_vga_controller.py
python sim/test_ov7670_capture.py
python sim/test_sccb_master.py
```

Last verified results:

| Test Bench | Result |
| --- | --- |
| `test_filter_engine.py` | 8 passed, 0 failed |
| `test_vga_controller.py` | 8 passed, 0 failed |
| `test_ov7670_capture.py` | 6 passed, 0 failed |
| `test_sccb_master.py` | 7 passed, 0 failed |

## User Controls

- `SW[1:0]`: image filter selection
- `BTNC` / reset input: system reset
- VGA output: standard Basys 3 VGA connector
- OV7670 camera pins: assigned in `src/constraints.xdc`