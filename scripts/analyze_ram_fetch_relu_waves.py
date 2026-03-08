#!/usr/bin/env python3
"""Parses RAM+ReLU VCD dumps and reports handshake bubbles."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional


@dataclass(frozen=True)
class InterfaceSignals:
    name: str
    valid: str
    ready: str


@dataclass(frozen=True)
class Variant:
    name: str
    reset: Optional[str]
    interfaces: List[InterfaceSignals]
    occupancy: List[str]


VARIANTS: Dict[str, Variant] = {
    "split": Variant(
        name="split",
        reset=None,
        interfaces=[
            InterfaceSignals("addr_in", "tb.addr_in_vld", "tb.addr_in_rdy"),
            InterfaceSignals("ram_req", "tb.ram_req_vld", "tb.ram_req_rdy"),
            InterfaceSignals("ram_resp", "tb.ram_resp_vld", "tb.ram_resp_rdy"),
            InterfaceSignals("out_ch", "tb.out_ch_vld", "tb.out_ch_rdy"),
        ],
        occupancy=[],
    ),
    "single_pipelined": Variant(
        name="single_pipelined",
        reset="tb.rst",
        interfaces=[
            InterfaceSignals("addr_in", "tb.addr_in_vld", "tb.addr_in_rdy"),
            InterfaceSignals("ram_req", "tb.ram_req_vld", "tb.ram_req_rdy"),
            InterfaceSignals("ram_resp", "tb.ram_resp_vld", "tb.ram_resp_rdy"),
            InterfaceSignals("out_ch", "tb.out_ch_vld", "tb.out_ch_rdy"),
        ],
        occupancy=["tb.dut.p0_valid"],
    ),
    "single_cold_steady_drain": Variant(
        name="single_cold_steady_drain",
        reset="tb.rst",
        interfaces=[
            InterfaceSignals("addr_in", "tb.addr_in_vld", "tb.addr_in_rdy"),
            InterfaceSignals("ram_req", "tb.ram_req_vld", "tb.ram_req_rdy"),
            InterfaceSignals("ram_resp", "tb.ram_resp_vld", "tb.ram_resp_rdy"),
            InterfaceSignals("out_ch", "tb.out_ch_vld", "tb.out_ch_rdy"),
        ],
        occupancy=[],
    ),
    "single_nonblocking": Variant(
        name="single_nonblocking",
        reset="tb.rst",
        interfaces=[
            InterfaceSignals("addr_in", "tb.addr_in_vld", "tb.addr_in_rdy"),
            InterfaceSignals("ram_req", "tb.ram_req_vld", "tb.ram_req_rdy"),
            InterfaceSignals("ram_resp", "tb.ram_resp_vld", "tb.ram_resp_rdy"),
            InterfaceSignals("out_ch", "tb.out_ch_vld", "tb.out_ch_rdy"),
        ],
        occupancy=[],
    ),
    "single_dual_token": Variant(
        name="single_dual_token",
        reset="tb.rst",
        interfaces=[
            InterfaceSignals("addr_in", "tb.addr_in_vld", "tb.addr_in_rdy"),
            InterfaceSignals("ram_req", "tb.ram_req_vld", "tb.ram_req_rdy"),
            InterfaceSignals("ram_resp", "tb.ram_resp_vld", "tb.ram_resp_rdy"),
            InterfaceSignals("out_ch", "tb.out_ch_vld", "tb.out_ch_rdy"),
        ],
        occupancy=[],
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--variant",
        action="append",
        nargs=2,
        metavar=("NAME", "VCD"),
        help="Variant name and path to its VCD dump.",
        required=True,
    )
    return parser.parse_args()


def bit_is_one(value: str) -> bool:
    return value[:1] == "1"


def parse_vcd(path: Path) -> Dict[str, List[Dict[str, str]]]:
    id_to_names: Dict[str, List[str]] = {}
    scope: List[str] = []
    values: Dict[str, str] = {}
    samples: List[Dict[str, str]] = []
    current_time: Optional[int] = None
    prev_clk = "x"
    in_definitions = True

    def finish_time() -> None:
        nonlocal prev_clk
        if current_time is None:
            return
        clk_value = values.get("tb.clk", "x")
        if prev_clk == "0" and clk_value == "1":
            samples.append(dict(values))
        if clk_value in ("0", "1"):
            prev_clk = clk_value

    with path.open("r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue
            if in_definitions:
                if line.startswith("$scope"):
                    parts = line.split()
                    scope.append(parts[2])
                elif line.startswith("$upscope"):
                    scope.pop()
                elif line.startswith("$var"):
                    parts = line.split()
                    symbol = parts[3]
                    reference = parts[4]
                    id_to_names.setdefault(symbol, []).append(".".join(scope + [reference]))
                elif line.startswith("$enddefinitions"):
                    in_definitions = False
                continue

            if line.startswith("#"):
                finish_time()
                current_time = int(line[1:])
                continue

            if line[0] in "01xXzZ":
                symbol = line[1:]
                for name in id_to_names.get(symbol, []):
                    values[name] = line[0].lower()
                continue

            if line[0] in "bBrR":
                parts = line.split()
                if len(parts) != 2:
                    continue
                vector_value = parts[0][1:].lower()
                for name in id_to_names.get(parts[1], []):
                    values[name] = vector_value
                continue

    finish_time()
    return {"samples": samples}


def active_samples(samples: List[Dict[str, str]], reset_signal: Optional[str]) -> List[Dict[str, str]]:
    if reset_signal is None:
        return samples
    return [sample for sample in samples if not bit_is_one(sample.get(reset_signal, "0"))]


def handshake_cycles(samples: Iterable[Dict[str, str]], iface: InterfaceSignals) -> List[int]:
    cycles: List[int] = []
    for cycle, sample in enumerate(samples):
        if bit_is_one(sample.get(iface.valid, "0")) and bit_is_one(sample.get(iface.ready, "0")):
            cycles.append(cycle)
    return cycles


def bubble_gaps(cycles: List[int]) -> List[int]:
    return [next_cycle - cycle - 1 for cycle, next_cycle in zip(cycles, cycles[1:]) if next_cycle - cycle > 1]


def format_cycle_list(cycles: List[int]) -> str:
    if not cycles:
        return "[]"
    if len(cycles) <= 12:
        return "[" + ", ".join(str(cycle) for cycle in cycles) + "]"
    head = ", ".join(str(cycle) for cycle in cycles[:6])
    tail = ", ".join(str(cycle) for cycle in cycles[-3:])
    return f"[{head}, ..., {tail}]"


def occupancy_summary(samples: List[Dict[str, str]], signal: str) -> str:
    active = [cycle for cycle, sample in enumerate(samples) if bit_is_one(sample.get(signal, "0"))]
    gaps = bubble_gaps(active)
    return (
        f"{signal}: active_cycles={len(active)} active_at={format_cycle_list(active)} "
        f"bubble_cycles={sum(gaps)} max_bubble_run={max(gaps, default=0)}"
    )


def analyze_variant(name: str, path: Path) -> str:
    variant = VARIANTS[name]
    parsed = parse_vcd(path)
    samples = active_samples(parsed["samples"], variant.reset)
    lines = [f"{name}: {path}", f"  sampled_posedges={len(samples)}"]

    for iface in variant.interfaces:
        cycles = handshake_cycles(samples, iface)
        gaps = bubble_gaps(cycles)
        lines.append(
            "  "
            + (
                f"{iface.name}: handshakes={len(cycles)} at={format_cycle_list(cycles)} "
                f"bubble_cycles={sum(gaps)} max_bubble_run={max(gaps, default=0)}"
            )
        )

    if variant.occupancy:
        for signal in variant.occupancy:
            lines.append("  " + occupancy_summary(samples, signal))

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    reports = []
    for name, raw_path in args.variant:
        if name not in VARIANTS:
            raise SystemExit(f"unknown variant: {name}")
        path = Path(raw_path)
        reports.append(analyze_variant(name, path))

    print("RAM fetch + ReLU waveform analysis")
    print("Cycle indices refer to sampled post-posedge states in the VCD trace.")
    print()
    print("\n\n".join(reports))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
