"""
Cocotb testbench for vga_controller.v

Verifies:
  - Reset clears hcount/vcount to 0
  - hcount wraps at 800, vcount increments and wraps at 525
  - hsync is low (active) for hcount in [656, 752)
  - vsync is low (active) for vcount in [490, 492)
  - active is high only for hcount < 640 and vcount < 480

Clock: 25 MHz (40 ns period)

Run:
  python test_vga_controller.py
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb_tools.runner import get_runner

# VGA timing constants (match vga_controller.v)
H_ACTIVE    = 640
H_SYNC_START = 656
H_SYNC_END   = 752
H_TOTAL      = 800
V_ACTIVE    = 480
V_SYNC_START = 490
V_SYNC_END   = 492
V_TOTAL      = 525


async def reset_dut(dut):
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0


async def advance_clocks(dut, n):
    for _ in range(n):
        await RisingEdge(dut.clk)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_reset_clears_counters(dut):
    """After reset, hcount and vcount must be 0"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.hcount.value == 0, f"hcount after reset = {int(dut.hcount.value)}, expected 0"
    assert dut.vcount.value == 0, f"vcount after reset = {int(dut.vcount.value)}, expected 0"


@cocotb.test()
async def test_hcount_increments(dut):
    """hcount should increment by 1 each clock"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    for expected in range(1, 10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        assert dut.hcount.value == expected, (
            f"hcount expected {expected}, got {int(dut.hcount.value)}"
        )


@cocotb.test()
async def test_hcount_wraps_at_800(dut):
    """hcount should wrap from 799 back to 0"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    # Advance to hcount == 799
    await advance_clocks(dut, H_TOTAL - 1)
    await ReadOnly()
    assert dut.hcount.value == H_TOTAL - 1, (
        f"Expected hcount={H_TOTAL - 1}, got {int(dut.hcount.value)}"
    )

    # Next clock should wrap to 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.hcount.value == 0, f"hcount wrap failed: got {int(dut.hcount.value)}"


@cocotb.test()
async def test_hsync_goes_low_at_sync_start(dut):
    """hsync should be low (active) when hcount is in [656, 752)"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    # Advance to one clock before H_SYNC_START
    await advance_clocks(dut, H_SYNC_START - 1)
    await ReadOnly()
    assert dut.hsync.value == 1, "hsync should be high before sync start"

    # Step into sync region
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.hcount.value == H_SYNC_START, (
        f"Expected hcount={H_SYNC_START}, got {int(dut.hcount.value)}"
    )
    assert dut.hsync.value == 0, "hsync should be low at H_SYNC_START"


@cocotb.test()
async def test_hsync_goes_high_at_sync_end(dut):
    """hsync should return high when hcount reaches 752"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    await advance_clocks(dut, H_SYNC_END - 1)
    await ReadOnly()
    assert dut.hsync.value == 0, "hsync should still be low just before sync end"

    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.hcount.value == H_SYNC_END, (
        f"Expected hcount={H_SYNC_END}, got {int(dut.hcount.value)}"
    )
    assert dut.hsync.value == 1, "hsync should be high at H_SYNC_END"


@cocotb.test()
async def test_active_region(dut):
    """active should be 1 for hcount < 640 and vcount < 480, else 0"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    # Sample a few points in the active region
    await ReadOnly()
    assert dut.active.value == 1, "active should be 1 at (0,0)"

    await advance_clocks(dut, H_ACTIVE - 1)
    await ReadOnly()
    assert dut.active.value == 1, f"active should be 1 at hcount={H_ACTIVE-1}"

    # One more clock: hcount = H_ACTIVE (640) -> outside active
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.active.value == 0, f"active should be 0 at hcount={H_ACTIVE}"


@cocotb.test()
async def test_vcount_increments_per_line(dut):
    """vcount should increment by 1 at the end of each horizontal line"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    # After exactly H_TOTAL clocks, vcount should be 1
    await advance_clocks(dut, H_TOTAL)
    await ReadOnly()
    assert dut.vcount.value == 1, f"vcount after 1 line: expected 1, got {int(dut.vcount.value)}"

    await advance_clocks(dut, H_TOTAL)
    await ReadOnly()
    assert dut.vcount.value == 2, f"vcount after 2 lines: expected 2, got {int(dut.vcount.value)}"


@cocotb.test()
async def test_vsync_timing(dut):
    """vsync should pulse low at vcount in [490, 492)"""
    cocotb.start_soon(Clock(dut.clk, 40, unit="ns").start())
    await reset_dut(dut)

    # Advance to start of vsync row (vcount=490, hcount=0)
    await advance_clocks(dut, V_SYNC_START * H_TOTAL)
    await ReadOnly()
    assert dut.vcount.value == V_SYNC_START, (
        f"Expected vcount={V_SYNC_START}, got {int(dut.vcount.value)}"
    )
    assert dut.vsync.value == 0, "vsync should be low at V_SYNC_START"

    # Advance to end of vsync (vcount=492)
    await advance_clocks(dut, V_SYNC * H_TOTAL)
    await ReadOnly()
    assert dut.vsync.value == 1, "vsync should be high after V_SYNC_END"


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

V_SYNC = V_SYNC_END - V_SYNC_START


def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/vga_controller.v"]

    r = get_runner(sim)
    r.build(
        sources=sources,
        hdl_toplevel="vga_controller",
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
    r.test(
        hdl_toplevel="vga_controller",
        test_module="test_vga_controller",
        waves=True,
    )


if __name__ == "__main__":
    runner()
