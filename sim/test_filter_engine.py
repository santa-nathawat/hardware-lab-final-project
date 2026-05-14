"""
Cocotb testbench for filter_engine.v

Covers all four filter modes:
  00 – raw passthrough
  01 – grayscale (Rec.601-like: Y = (R5*54 + G6*183 + B5*18) >> 8)
  10 – red-only
  11 – color inversion

Run:
  python test_filter_engine.py
  SIM=verilator python test_filter_engine.py
"""

import os
from pathlib import Path

import cocotb
from cocotb.triggers import Timer
from cocotb_tools.runner import get_runner


# ---------------------------------------------------------------------------
# Helper: compute expected grayscale output matching RTL formula exactly
# ---------------------------------------------------------------------------
def expected_grayscale(pixel_in):
    r5 = (pixel_in >> 11) & 0x1F
    g6 = (pixel_in >> 5) & 0x3F
    b5 = pixel_in & 0x1F
    y_scaled = r5 * 54 + g6 * 183 + b5 * 18
    y_6bit = y_scaled >> 8
    if y_6bit > 63:
        y_6bit = 63
    y_5bit = (y_6bit >> 1) & 0x1F
    return (y_5bit << 11) | (y_6bit << 5) | y_5bit


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_raw_passthrough(dut):
    """sw=00: pixel_out must equal pixel_in for every value"""
    dut.sw.value = 0b00
    for pixel in [0x0000, 0xFFFF, 0xF800, 0x07E0, 0x001F, 0xABCD, 0x1234]:
        dut.pixel_in.value = pixel
        await Timer(1, unit="ns")
        assert dut.pixel_out.value == pixel, (
            f"Raw passthrough failed: pixel_in={pixel:#06x}, got {int(dut.pixel_out.value):#06x}"
        )


@cocotb.test()
async def test_grayscale_white(dut):
    """sw=01: white pixel (0xFFFF) -> known grayscale value"""
    dut.sw.value = 0b01
    dut.pixel_in.value = 0xFFFF
    await Timer(1, unit="ns")
    expected = expected_grayscale(0xFFFF)
    assert dut.pixel_out.value == expected, (
        f"Grayscale white failed: expected {expected:#06x}, got {int(dut.pixel_out.value):#06x}"
    )


@cocotb.test()
async def test_grayscale_black(dut):
    """sw=01: black pixel (0x0000) -> 0x0000"""
    dut.sw.value = 0b01
    dut.pixel_in.value = 0x0000
    await Timer(1, unit="ns")
    assert dut.pixel_out.value == 0x0000, (
        f"Grayscale black failed: got {int(dut.pixel_out.value):#06x}"
    )


@cocotb.test()
async def test_grayscale_pure_red(dut):
    """sw=01: pure red (0xF800) -> grayscale from red channel only"""
    dut.sw.value = 0b01
    dut.pixel_in.value = 0xF800
    await Timer(1, unit="ns")
    expected = expected_grayscale(0xF800)
    assert dut.pixel_out.value == expected, (
        f"Grayscale pure-red failed: expected {expected:#06x}, got {int(dut.pixel_out.value):#06x}"
    )


@cocotb.test()
async def test_grayscale_several_pixels(dut):
    """sw=01: batch of pixels match Python reference implementation"""
    dut.sw.value = 0b01
    pixels = [0xF800, 0x07E0, 0x001F, 0xAAAA, 0x5555, 0x1234, 0xDEAD]
    for pixel in pixels:
        dut.pixel_in.value = pixel
        await Timer(1, unit="ns")
        expected = expected_grayscale(pixel)
        assert dut.pixel_out.value == expected, (
            f"Grayscale mismatch at pixel={pixel:#06x}: expected {expected:#06x}, "
            f"got {int(dut.pixel_out.value):#06x}"
        )


@cocotb.test()
async def test_red_only(dut):
    """sw=10: only red channel kept; G and B zeroed"""
    dut.sw.value = 0b10
    test_cases = [
        (0xFFFF, 0xF800),  # all bits -> only R
        (0xF800, 0xF800),  # pure red unchanged
        (0x07FF, 0x0000),  # no red -> black
        (0xABCD, (0xABCD & 0xF800)),
    ]
    for pixel_in, expected in test_cases:
        dut.pixel_in.value = pixel_in
        await Timer(1, unit="ns")
        assert dut.pixel_out.value == expected, (
            f"Red-only failed: pixel_in={pixel_in:#06x}, "
            f"expected {expected:#06x}, got {int(dut.pixel_out.value):#06x}"
        )


@cocotb.test()
async def test_inversion(dut):
    """sw=11: output must be bitwise NOT of input (16-bit)"""
    dut.sw.value = 0b11
    test_cases = [0x0000, 0xFFFF, 0xF800, 0x07E0, 0x001F, 0xABCD]
    for pixel in test_cases:
        dut.pixel_in.value = pixel
        await Timer(1, unit="ns")
        expected = (~pixel) & 0xFFFF
        assert dut.pixel_out.value == expected, (
            f"Inversion failed: pixel_in={pixel:#06x}, "
            f"expected {expected:#06x}, got {int(dut.pixel_out.value):#06x}"
        )


@cocotb.test()
async def test_switch_transitions(dut):
    """Changing sw mid-stream should update output immediately (combinational)"""
    dut.pixel_in.value = 0xF800  # pure red

    dut.sw.value = 0b00
    await Timer(1, unit="ns")
    assert dut.pixel_out.value == 0xF800, "Raw should pass through"

    dut.sw.value = 0b10
    await Timer(1, unit="ns")
    assert dut.pixel_out.value == 0xF800, "Red-only of pure-red stays the same"

    dut.sw.value = 0b11
    await Timer(1, unit="ns")
    assert dut.pixel_out.value == 0x07FF, "Inversion of 0xF800 -> 0x07FF"

    dut.sw.value = 0b00
    await Timer(1, unit="ns")
    assert dut.pixel_out.value == 0xF800, "Back to raw"


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/filter_engine.v"]

    r = get_runner(sim)
    r.build(
        sources=sources,
        hdl_toplevel="filter_engine",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
    r.test(
        hdl_toplevel="filter_engine",
        test_module="test_filter_engine",
        waves=True,
    )


if __name__ == "__main__":
    runner()
