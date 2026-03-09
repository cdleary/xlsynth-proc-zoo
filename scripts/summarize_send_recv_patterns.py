#!/usr/bin/env python3
"""Summarizes channel-op staging from send/recv pattern schedule files."""

from __future__ import annotations

import csv
import pathlib
import re
import sys


CHAN_RE = re.compile(r"^chan (\S+)\(")
OP_RE = re.compile(
    r"^\s*(\S+): .* = (receive|send)\(.*channel=(\S+?)(?:,|\))"
)
BLOCKING_FALSE_RE = re.compile(r"blocking=false")
STAGE_RE = re.compile(r"^\s*stage: (\d+)")
NODE_RE = re.compile(r'^\s*node: "([^"]+)"')
LENGTH_RE = re.compile(r"^\s*length: (\d+)")


def parse_ir(ir_path: pathlib.Path) -> dict[str, str]:
    op_map: dict[str, str] = {}
    for line in ir_path.read_text().splitlines():
        match = OP_RE.match(line)
        if not match:
            continue
        node_name, op_kind, channel_name = match.groups()
        short_channel = channel_name.split("__")[-1]
        if op_kind == "receive" and BLOCKING_FALSE_RE.search(line):
            op_map[node_name] = f"recv_non_blocking({short_channel})"
        elif op_kind == "receive":
            op_map[node_name] = f"recv({short_channel})"
        else:
            op_map[node_name] = f"send({short_channel})"
    return op_map


def parse_schedule(schedule_path: pathlib.Path) -> tuple[int, dict[int, list[str]]]:
    length = 0
    stage_to_nodes: dict[int, list[str]] = {}
    current_stage: int | None = None
    for line in schedule_path.read_text().splitlines():
        match = STAGE_RE.match(line)
        if match:
            current_stage = int(match.group(1))
            stage_to_nodes.setdefault(current_stage, [])
            continue
        match = NODE_RE.match(line)
        if match and current_stage is not None:
            stage_to_nodes[current_stage].append(match.group(1))
            continue
        match = LENGTH_RE.match(line)
        if match:
            length = int(match.group(1))
    return length, stage_to_nodes


def summarize_entry(proc_name: str, requested_stages: str, ir_path: pathlib.Path, schedule_path: pathlib.Path) -> str:
    op_map = parse_ir(ir_path)
    schedule_length, stage_to_nodes = parse_schedule(schedule_path)
    stage_summaries: list[str] = []
    for stage in sorted(stage_to_nodes):
        ops = [op_map[node] for node in stage_to_nodes[stage] if node in op_map]
        if ops:
            stage_summaries.append(f"S{stage}: " + ", ".join(ops))
    if not stage_summaries:
        stage_summary = "(no channel ops found in schedule summary)"
    else:
        stage_summary = "<br>".join(stage_summaries)
    return (
        f"| `{proc_name}` | {requested_stages} | {schedule_length} | {stage_summary} |"
    )


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: summarize_send_recv_patterns.py MANIFEST.tsv", file=sys.stderr)
        return 1

    manifest_path = pathlib.Path(sys.argv[1])
    rows = list(csv.reader(manifest_path.read_text().splitlines(), delimiter="\t"))

    print("# Send/Recv Pattern Schedule Summary")
    print()
    print("| Proc | Requested stages | Scheduled length | Channel-op staging |")
    print("| --- | --- | --- | --- |")
    for proc_name, requested_stages, ir_path, schedule_path in rows:
        print(
            summarize_entry(
                proc_name,
                requested_stages,
                pathlib.Path(ir_path),
                pathlib.Path(schedule_path),
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
