#!/usr/bin/env python3
"""Summarizes split vs single-nonblocking under latency/backpressure sweeps."""

from __future__ import annotations

import argparse
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

from analyze_ram_fetch_relu_waves import (
    VARIANTS,
    active_samples,
    bit_is_one,
    parse_vcd,
)


@dataclass(frozen=True)
class CaseInput:
    case_name: str
    variant_name: str
    vcd_path: Path


@dataclass(frozen=True)
class WindowStats:
    handshakes: int
    window_len: int
    design_bubbles: int
    blocked: int
    idle: int
    max_design_bubble_run: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--case",
        action="append",
        nargs=3,
        metavar=("CASE", "VARIANT", "VCD"),
        required=True,
        help="Scenario name, variant name, and VCD path.",
    )
    return parser.parse_args()


def interface_stats(samples: List[Dict[str, str]], valid_signal: str, ready_signal: str) -> WindowStats:
    states: List[Tuple[bool, bool]] = []
    handshakes: List[int] = []
    for cycle, sample in enumerate(samples):
        valid = bit_is_one(sample.get(valid_signal, "0"))
        ready = bit_is_one(sample.get(ready_signal, "0"))
        states.append((valid, ready))
        if valid and ready:
            handshakes.append(cycle)

    if not handshakes:
        return WindowStats(0, 0, 0, 0, 0, 0)

    start = handshakes[0]
    end = handshakes[-1]
    design_bubbles = 0
    blocked = 0
    idle = 0
    max_run = 0
    current_run = 0

    for valid, ready in states[start : end + 1]:
        if valid and ready:
            current_run = 0
        elif (not valid) and ready:
            design_bubbles += 1
            current_run += 1
            max_run = max(max_run, current_run)
        elif valid and (not ready):
            blocked += 1
            current_run = 0
        else:
            idle += 1
            current_run = 0

    return WindowStats(
        handshakes=len(handshakes),
        window_len=end - start + 1,
        design_bubbles=design_bubbles,
        blocked=blocked,
        idle=idle,
        max_design_bubble_run=max_run,
    )


def summarize_case(case_name: str, case_inputs: List[CaseInput]) -> str:
    lines = [f"{case_name}"]
    for case_input in case_inputs:
        variant = VARIANTS[case_input.variant_name]
        samples = active_samples(parse_vcd(case_input.vcd_path)["samples"], variant.reset)
        iface_by_name = {iface.name: iface for iface in variant.interfaces}
        req_stats = interface_stats(samples, iface_by_name["ram_req"].valid, iface_by_name["ram_req"].ready)
        out_stats = interface_stats(samples, iface_by_name["out_ch"].valid, iface_by_name["out_ch"].ready)
        lines.append(
            "  "
            + (
                f"{case_input.variant_name}: req_issue_bubble_free={'yes' if req_stats.design_bubbles == 0 else 'no'}; "
                f"out_retire_bubble_free={'yes' if out_stats.design_bubbles == 0 else 'no'}; "
                f"ram_req(handshakes={req_stats.handshakes}, design_bubbles={req_stats.design_bubbles}, "
                f"blocked={req_stats.blocked}, max_bubble_run={req_stats.max_design_bubble_run}); "
                f"out_ch(handshakes={out_stats.handshakes}, design_bubbles={out_stats.design_bubbles}, "
                f"blocked={out_stats.blocked}, max_bubble_run={out_stats.max_design_bubble_run})"
            )
        )
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    grouped: "OrderedDict[str, List[CaseInput]]" = OrderedDict()
    for case_name, variant_name, raw_path in args.case:
        if variant_name not in VARIANTS:
            raise SystemExit(f"unknown variant: {variant_name}")
        grouped.setdefault(case_name, []).append(
            CaseInput(case_name=case_name, variant_name=variant_name, vcd_path=Path(raw_path))
        )

    print("RAM fetch + ReLU sweep analysis")
    print("Design bubbles count cycles inside the active handshake window where ready=1 but valid=0.")
    print("Blocked cycles count cycles inside that window where valid=1 but ready=0.")
    print()
    for case_name, case_inputs in grouped.items():
        print(summarize_case(case_name, case_inputs))
        print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
