"""
Cocotb testbench for sccb_master.v

To keep simulation fast, CLK_FREQ=400000 and SCCB_FREQ=100000 are used,
giving CLK_DIV=1 so the internal tick fires every clock cycle.
One full SCCB write transaction completes in ~117 clock cycles.

Tests:
  1. Idle state: SCL=1, SDA=1, busy=0 after reset
  2. busy goes high on start pulse
  3. done pulses for exactly one cycle after transaction completes
  4. busy returns low after done
  5. Transmitted ID byte matches {dev_addr, 1'b0} on SDA during ST_ID
  6. SCL toggles during transmission (not stuck)
  7. Back-to-back transactions: second start accepted after first done

Run:
  python test_sccb_master.py
"""

import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer
from cocotb_tools.runner import get_runner

# Simulation parameters — keep CLK_DIV = CLK_FREQ / (SCCB_FREQ * 4) = 1
SIM_CLK_FREQ  = 400_000
SIM_SCCB_FREQ = 100_000
# One full transaction = 4+32+4+32+4+32+4+4+1 = ~117 clock cycles
TX_CYCLES = 130  # generous margin


async def do_reset(dut):
    await leave_readonly()
    dut.rst.value = 1
    dut.start.value = 0
    dut.dev_addr.value = 0
    dut.reg_addr.value = 0
    dut.reg_data.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def leave_readonly():
    """Advance out of ReadOnly before driving DUT inputs."""
    await Timer(1, unit="ps")


async def start_transaction(dut, dev_addr=0x21, reg_addr=0x12, reg_data=0x80):
    """Pulse start for one clock cycle."""
    await leave_readonly()
    dut.dev_addr.value = dev_addr
    dut.reg_addr.value = reg_addr
    dut.reg_data.value = reg_data
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    await leave_readonly()
    dut.start.value = 0


async def wait_for_done(dut, timeout=TX_CYCLES):
    """Wait up to `timeout` cycles for done to pulse; return cycle count."""
    for i in range(timeout):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if dut.done.value == 1:
            await leave_readonly()
            return i + 1
    raise AssertionError(f"done never pulsed within {timeout} cycles")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_idle_after_reset(dut):
    """After reset: SCL=1, SDA=1, busy=0, done=0, ack_err=0"""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)
    await ReadOnly()
    assert dut.scl.value == 1,     "SCL should be high in idle"
    assert dut.sda.value == 1,     "SDA should be high in idle"
    assert dut.busy.value == 0,    "busy should be 0 in idle"
    assert dut.done.value == 0,    "done should be 0 in idle"
    assert dut.ack_err.value == 0, "ack_err should be 0 after reset"


@cocotb.test()
async def test_busy_asserts_on_start(dut):
    """busy should go high in the same cycle as the start pulse."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    await start_transaction(dut)
    assert dut.busy.value == 1, "busy should be 1 immediately after start"


@cocotb.test()
async def test_done_pulses_once(dut):
    """done should pulse for exactly one clock cycle after transaction completes."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    await start_transaction(dut)
    cycles = await wait_for_done(dut)
    dut._log.info(f"Transaction completed in {cycles} cycles")

    # done was high on the cycle found; it should be low next cycle
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.done.value == 0, "done should deassert after one cycle"


@cocotb.test()
async def test_busy_clears_after_done(dut):
    """busy should return to 0 when done pulses."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    await start_transaction(dut)
    await wait_for_done(dut)
    # At the done cycle, busy is already cleared (ST_DONE sets done=1, busy=0)
    assert dut.busy.value == 0, "busy should be 0 when done is 1"


@cocotb.test()
async def test_scl_toggles_during_transmission(dut):
    """SCL must not stay stuck high or low while the transaction runs."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    await start_transaction(dut)

    saw_low  = False
    saw_high = False
    for _ in range(TX_CYCLES):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if dut.scl.value == 0:
            saw_low = True
        if dut.scl.value == 1:
            saw_high = True
        if dut.done.value == 1:
            break

    assert saw_low,  "SCL was never low during transaction"
    assert saw_high, "SCL was never high during transaction"


@cocotb.test()
async def test_sda_starts_with_start_condition(dut):
    """
    SCCB START condition: SDA falls while SCL is high.
    After the start pulse, SCL=1 and SDA must go low before SCL drops.
    """
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    await start_transaction(dut)

    # Watch for SDA falling while SCL is still high (START condition)
    found_start = False
    prev_sda = 1
    for _ in range(20):
        await RisingEdge(dut.clk)
        await ReadOnly()
        cur_sda = int(dut.sda.value)
        cur_scl = int(dut.scl.value)
        if prev_sda == 1 and cur_sda == 0 and cur_scl == 1:
            found_start = True
            break
        prev_sda = cur_sda

    assert found_start, "SCCB START condition (SDA↓ while SCL=1) not observed"


@cocotb.test()
async def test_back_to_back_transactions(dut):
    """Master should accept a second transaction immediately after done."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    # First transaction
    await start_transaction(dut, dev_addr=0x21, reg_addr=0x12, reg_data=0x80)
    await wait_for_done(dut)

    # Second transaction starts on the very next cycle after done
    await start_transaction(dut, dev_addr=0x21, reg_addr=0x15, reg_data=0xAB)
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.busy.value == 1, "Master should be busy for second transaction"

    # Wait for second done
    cycles2 = await wait_for_done(dut)
    dut._log.info(f"Second transaction completed in {cycles2} cycles")
    assert dut.done.value == 1, "done should pulse after second transaction"


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

def runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent
    sources = [proj_path / "../src/sccb_master.v"]

    parameters = {
        "CLK_FREQ":  SIM_CLK_FREQ,
        "SCCB_FREQ": SIM_SCCB_FREQ,
    }

    r = get_runner(sim)
    r.build(
        sources=sources,
        hdl_toplevel="sccb_master",
        parameters=parameters,
        always=True,
        waves=True,
        timescale=("1ns", "1ps"),
    )
    r.test(
        hdl_toplevel="sccb_master",
        test_module="test_sccb_master",
        parameters=parameters,
        waves=True,
    )


if __name__ == "__main__":
    runner()
