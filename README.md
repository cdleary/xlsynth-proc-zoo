# xlsynth-proc-zoo

Small standalone XLS/XLSynth proc families that compare different formulations
of the same behavior and their codegen and scheduling consequences.

The goal is not only to provide examples, but to characterize recurring proc
patterns and how the current XLS/XLSynth toolchain pipelines them in practice.

Current families:

- `examples/ram_fetch_relu/`: stream addresses to a RAM-like interface, receive
  signed data back, apply ReLU, and emit the result on an output stream
- `examples/send_recv_patterns/`: small micro-patterns for seeing how the
  current toolchain groups blocking and non-blocking channel ops into stages

The detailed comparison for the RAM+ReLU family lives in
`examples/ram_fetch_relu/README.md`.
The schedule-focused send/recv micro-pattern family lives in
`examples/send_recv_patterns/README.md`.

## Prerequisites

- `XLSYNTH_TOOLS` must point at an xlsynth tools bundle containing:
  - `dslx_interpreter_main`
  - `ir_converter_main`
  - `codegen_main`
- `iverilog` and `vvp` must be installed for the RTL simulation targets.

## Quick Start

Run the DSLX proc tests:

```sh
make dslx-test
```

Check the codegen throughput behavior:

```sh
make codegen-check
```

Generate RTL for the split-stage RAM+ReLU version and run its `iverilog`
testbench:

```sh
make rtl-sim-split
```

Generate RTL for the single software-pipelined RAM+ReLU version and run its
`iverilog` testbench:

```sh
make rtl-sim-single-pipelined
```

Generate RTL for the single cold/steady/drain RAM+ReLU version and run its
`iverilog` testbench:

```sh
make rtl-sim-single-cold-steady-drain
```

Generate RTL for the single dual-token RAM+ReLU version and run its
`iverilog` testbench:

```sh
make rtl-sim-single-dual-token
```

Generate RTL for the single non-blocking RAM+ReLU version and run its
`iverilog` testbench:

```sh
make rtl-sim-single-nonblocking
```

Generate RTL for the single non-blocking RAM+ReLU version with an internal
address counter and run its `iverilog` testbench:

```sh
make rtl-sim-single-nonblocking-internal-counter
```

Generate waveform dumps for the RAM+ReLU RTL examples and report handshake
gaps programmatically:

```sh
make wave-analysis
```

Run the latency/backpressure sweep that compares the split and non-blocking
single-proc variants:

```sh
make wave-sweep
```

Run the boundary-buffering sweep that compares `flop`, `skid`, and
`zerolatency` output kinds on representative variants:

```sh
make wave-io-kind-sweep
```

Generate per-pattern schedules for the small send/recv staging family:

```sh
make characterize-send-recv-patterns
```

Run everything:

```sh
make
```

## Layout

- `examples/ram_fetch_relu/`: DSLX variants and the family-specific README
- `examples/send_recv_patterns/`: small DSLX proc-shape micro-benchmarks
- `tb/ram_fetch_relu/`: small RTL smoke tests for the generated SystemVerilog
- `scripts/`: helper scripts that build and simulate the current families
