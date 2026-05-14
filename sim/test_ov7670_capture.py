"""
Cocotb testbench for ov7670_capture.v

The module clocks on negedge pclk, so all signal changes are driven
between falling edges and samples are read at ReadOnly after each negedge.

Tests:
  1. Reset clears all outputs
  2. frame_done pulses exactly once on VSYNC falling edge
  3. No write-enable during edge-guard zone (first 4 pixel pairs per row)
  4. First valid pixel (h_cnt=4, v_cnt=4) written to address 0
  5. Second valid pixel (h_cnt=6, v_cnt=4) written to address 1
  6. wr_en deasserts on the next clock after a write

Run:
  python test_ov7670_capture.py
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, Timer
from cocotb_tools.runner import get_runner


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def do_reset(dut):
    """Apply synchronous reset for 3 negedge cycles."""
    await Timer(1, unit="ps")
    dut.rst.value = 1
    dut.cam_vsync.value = 0
    dut.cam_href.value = 0
    dut.cam_d.value = 0
    for _ in range(3):
        await FallingEdge(dut.pclk)
    dut.rst.value = 0
    await FallingEdge(dut.pclk)


async def leave_readonly():
    """Advance out of ReadOnly before driving DUT inputs."""
    await Timer(1, unit="ps")


async def vsync_pulse(dut, cycles=4):
    """Assert VSYNC (active-high) for `cycles` negedge ticks, then release."""
    await leave_readonly()
    dut.cam_vsync.value = 1
    dut.cam_href.value = 0
    for _ in range(cycles):
        await FallingEdge(dut.pclk)
    dut.cam_vsync.value = 0
    # This next negedge: vsync_prev=1, cam_vsync=0 → frame_done pulses
    await FallingEdge(dut.pclk)


async def blank_row(dut):
    """
    Send one minimal HREF row to advance v_cnt by 1.
    One cycle with HREF=1 registers href_prev; then HREF=0 triggers v_cnt++.
    """
    await leave_readonly()
    dut.cam_href.value = 1
    dut.cam_d.value = 0x00
    await FallingEdge(dut.pclk)   # href_prev becomes 1
    dut.cam_href.value = 0
    await FallingEdge(dut.pclk)   # cam_href=0 + href_prev=1 → v_cnt++
    # h_cnt also resets to 0 here


async def send_pixel_pair(dut, msb, lsb):
    """
    Drive two consecutive bytes over two negedge ticks to form one 16-bit pixel.
    byte_cnt toggles: 0→save first_byte, 1→process pixel.
    """
    await leave_readonly()
    dut.cam_d.value = msb
    await FallingEdge(dut.pclk)   # byte_cnt=0: first_byte = msb
    dut.cam_d.value = lsb
    await FallingEdge(dut.pclk)   # byte_cnt=1: pixel processed


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_reset_clears_outputs(dut):
    """After reset all outputs must be 0."""
    cocotb.start_soon(Clock(dut.pclk, 40, unit="ns").start())
    await do_reset(dut)
    await ReadOnly()
    assert dut.wr_en.value == 0,    "wr_en should be 0 after reset"
    assert dut.wr_addr.value == 0,  "wr_addr should be 0 after reset"
    assert dut.wr_data.value == 0,  "wr_data should be 0 after reset"
    assert dut.frame_done.value == 0, "frame_done should be 0 after reset"


@cocotb.test()
async def test_frame_done_on_vsync_falling(dut):
    """frame_done should pulse for exactly one cycle on the VSYNC falling edge."""
    cocotb.start_soon(Clock(dut.pclk, 40, unit="ns").start())
    await do_reset(dut)

    # Assert VSYNC for 4 cycles, then release
    dut.cam_vsync.value = 1
    for _ in range(4):
        await FallingEdge(dut.pclk)
    dut.cam_vsync.value = 0

    # First negedge after VSYNC falls: vsync_prev=1, cam_vsync=0 → frame_done=1
    await FallingEdge(dut.pclk)
    await ReadOnly()
    assert dut.frame_done.value == 1, "frame_done should be 1 on VSYNC falling edge"

    # Next negedge: frame_done defaults back to 0
    await FallingEdge(dut.pclk)
    await ReadOnly()
    assert dut.frame_done.value == 0, "frame_done must be a single-cycle pulse"


@cocotb.test()
async def test_no_write_during_edge_guard(dut):
    """No wr_en during first 4 pixel-pairs per row (h_cnt 0-3)."""
    cocotb.start_soon(Clock(dut.pclk, 40, unit="ns").start())
    await do_reset(dut)
    await vsync_pulse(dut)

    # Advance v_cnt to 4 via 4 blank rows
    for _ in range(4):
        await blank_row(dut)

    # Now send 4 guarded pixel-pairs on row v_cnt=4 (h_cnt 0-3)
    dut.cam_href.value = 1
    for _ in range(4):
        await send_pixel_pair(dut, 0xAB, 0xCD)
        await ReadOnly()
        assert dut.wr_en.value == 0, (
            f"wr_en should be 0 for h_cnt < 4 (h_cnt was {int(dut.wr_en.value)})"
        )
    await leave_readonly()
    dut.cam_href.value = 0
    await FallingEdge(dut.pclk)


@cocotb.test()
async def test_first_pixel_written_to_address_0(dut):
    """
    First valid pixel (h_cnt=4, v_cnt=4) should write data to address 0.
    addr = ((v_cnt>>1) - 2)*320 + ((h_cnt>>1) - 2)
         = (2-2)*320 + (2-2) = 0
    """
    cocotb.start_soon(Clock(dut.pclk, 40, unit="ns").start())
    await do_reset(dut)
    await vsync_pulse(dut)

    # Advance v_cnt to 4
    for _ in range(4):
        await blank_row(dut)

    # Row v_cnt=4: skip 4 guarded pairs, then write the first valid one
    dut.cam_href.value = 1
    for _ in range(4):
        await send_pixel_pair(dut, 0x00, 0x00)  # h_cnt 0-3, no write

    # h_cnt=4, v_cnt=4, both even → should write
    MSB, LSB = 0x12, 0x34
    dut.cam_d.value = MSB
    await FallingEdge(dut.pclk)  # save first_byte
    dut.cam_d.value = LSB
    await FallingEdge(dut.pclk)  # process pixel
    await ReadOnly()

    assert dut.wr_en.value == 1,      "wr_en should be 1 for first valid pixel"
    assert int(dut.wr_addr.value) == 0, (
        f"First pixel address should be 0, got {int(dut.wr_addr.value)}"
    )
    assert int(dut.wr_data.value) == (MSB << 8 | LSB), (
        f"Pixel data mismatch: expected {(MSB<<8|LSB):#06x}, got {int(dut.wr_data.value):#06x}"
    )

    await leave_readonly()
    dut.cam_href.value = 0
    await FallingEdge(dut.pclk)


@cocotb.test()
async def test_second_pixel_written_to_address_1(dut):
    """
    Second valid pixel (h_cnt=6, v_cnt=4) should go to address 1.
    addr = (2-2)*320 + (3-2) = 1
    Note: h_cnt=5 is odd → skipped; h_cnt=6 is even → addr 1.
    """
    cocotb.start_soon(Clock(dut.pclk, 40, unit="ns").start())
    await do_reset(dut)
    await vsync_pulse(dut)

    for _ in range(4):
        await blank_row(dut)

    dut.cam_href.value = 1

    # h_cnt 0-3: guarded (no write)
    for _ in range(4):
        await send_pixel_pair(dut, 0x00, 0x00)

    # h_cnt=4: first valid pixel (addr 0)
    await send_pixel_pair(dut, 0xAA, 0xBB)

    # h_cnt=5: odd → h_cnt[0]=1, no write
    await send_pixel_pair(dut, 0x00, 0x00)
    await ReadOnly()
    assert dut.wr_en.value == 0, "wr_en should be 0 when h_cnt is odd"

    # h_cnt=6: even → write at address 1
    MSB, LSB = 0xDE, 0xAD
    await leave_readonly()
    dut.cam_d.value = MSB
    await FallingEdge(dut.pclk)
    dut.cam_d.value = LSB
    await FallingEdge(dut.pclk)
    await ReadOnly()

    assert dut.wr_en.value == 1,      "wr_en should be 1 for h_cnt=6"
    assert int(dut.wr_addr.value) == 1, (
        f"Second pixel address should be 1, got {int(dut.wr_addr.value)}"
    )
    assert int(dut.wr_data.value) == (MSB << 8 | LSB), (
        f"Pixel data mismatch at addr 1: got {int(dut.wr_data.value):#06x}"
    )

    await leave_readonly()
    dut.cam_href.value = 0
    await FallingEdge(dut.pclk)


@cocotb.test()
async def test_wr_en_deasserts_after_write(dut):
    """wr_en should return to 0 on the clock after a valid write."""
    cocotb.start_soon(Clock(dut.pclk, 40, unit="ns").start())
    await do_reset(dut)
    await vsync_pulse(dut)

    for _ in range(4):
        await blank_row(dut)

    dut.cam_href.value = 1
    for _ in range(4):
        await send_pixel_pair(dut, 0x00, 0x00)

    # First valid write
    await send_pixel_pair(dut, 0x12, 0x34)
    await ReadOnly()
    assert dut.wr_en.value == 1, "wr_en should be 1 during write"

    # h_cnt=5 (odd) - wr_en defaults to 0
    await leave_readonly()
    dut.cam_d.value = 0x00
    await FallingEdge(dut.pclk)
    await ReadOnly()
    assert dut.wr_en.value == 0, "wr_en should deassert (default 0 at top of always)"

    await leave_readonly()
    dut.cam_href.value = 0
    await FallingEdge(dut.pclk)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/ov7670_capture.v"]

    r = get_runner(sim)
    r.build(
        sources=sources,
        hdl_toplevel="ov7670_capture",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
    r.test(
        hdl_toplevel="ov7670_capture",
        test_module="test_ov7670_capture",
        waves=True,
    )


if __name__ == "__main__":
    runner()
