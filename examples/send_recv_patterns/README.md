# Send/Recv Patterns

This family is a schedule-first characterization zoo for small send/recv
shapes. It is meant to answer a narrower question than the RAM+ReLU family:

- given a proc body shape,
- how does the current XLS/XLSynth toolchain partition the channel operations
  into pipeline stages?

Unlike the RAM+ReLU family, this one intentionally focuses on emitted schedules
and stage grouping first. It is useful for building intuition about what
current proc lowering treats as one blocking frontier versus two.

## Patterns

| Proc | Shape | KPN style? | What it is for |
| --- | --- | --- | --- |
| `RecvThenSend` | `recv -> send` | Yes | Minimal one-frontier baseline |
| `SendThenRecv` | `send -> recv` | Yes | Checks what happens when the blocking receive is later in the activation |
| `SerialTwoRecvsThenSend` | `recv -> recv -> send` | Yes | Two blocking receives on one token chain |
| `ParallelTwoRecvsThenSend` | `(recv || recv) -> join -> send` | Yes | Two blocking receives made explicit as separate token lanes |
| `SerialTwoSends` | `send -> send` | Yes | Checks whether multiple sends tend to stay together |
| `ParallelTwoSends` | `(send || send) -> join` | Yes | Multiple independent sends made explicit as separate token lanes |
| `BlockingRoundTrip` | `send(req) -> recv(resp) -> send(out)` | Yes | Minimal blocking round-trip shape |
| `ParallelSendRecvThenSend` | `(send(req) || recv(resp)) -> join -> send(out)` | Yes | Mixed independent send/recv lanes compared to serialized round-trip |
| `NonBlockingRoundTrip` | `send(req)` plus optional `recv(resp) -> send(out)` | No | Minimal non-KPN escape hatch |

## Run It

Generate the IR, run codegen with schedule output enabled, and print a compact
summary of which channel ops land in which stage:

```sh
make characterize-send-recv-patterns
```

That target writes per-proc `.ir` and `.schedule` files under `build/` and
also writes a summary report to:

```text
build/send_recv_patterns_summary.md
```

## Reading the Results

The most useful questions to ask of the generated summary are:

- Did two blocking channel ops stay in the same stage or get split apart?
- If they got split apart, which op is earlier and which is later?
- Do multiple independent sends behave differently from multiple independent receives?
- Does introducing separate token lanes change the stage partition?
- Does a mixed `send || recv` shape differ from a serialized blocking round-trip?
- Does `recv_non_blocking` collapse what would otherwise be a blocking tail?

The family is intentionally small enough that you can pair the summary with the
source in [send_recv_patterns.x](./send_recv_patterns.x) and then inspect the
generated `.schedule` files directly when a result is surprising.

## Current 2-Stage Result

The current toolchain behavior for `make characterize-send-recv-patterns` is:

| Proc | Observed channel-op staging |
| --- | --- |
| `RecvThenSend` | `S0: recv(in_ch), send(out_ch)` |
| `SendThenRecv` | `S0: send(out_ch)` then `S1: recv(in_ch)` |
| `SerialTwoRecvsThenSend` | `S0: recv(left_in), recv(right_in), send(out_ch)` |
| `ParallelTwoRecvsThenSend` | `S0: recv(left_in), recv(right_in), send(out_ch)` |
| `SerialTwoSends` | `S0: send(left_out), send(right_out)` |
| `ParallelTwoSends` | `S0: send(left_out), send(right_out)` |
| `BlockingRoundTrip` | `S0: send(req_ch)` then `S1: recv(resp_ch), send(out_ch)` |
| `ParallelSendRecvThenSend` | `S0: recv(resp_ch), send(req_ch), send(out_ch)` |
| `NonBlockingRoundTrip` | `S0: recv_non_blocking(resp_ch), send(req_ch), send(out_ch)` |

Two immediate takeaways are:

- separate token lanes by themselves do not force a different stage split in
  the simple dual-receive or dual-send examples; the serial and parallel
  variants stage the channel ops the same way here
- a late blocking `recv` tends to create a later blocking frontier, while a
  non-blocking receive does not

The new mixed-lane result is also useful:

- `ParallelSendRecvThenSend` stages differently from `BlockingRoundTrip`
- serial `send(req) -> recv(resp) -> send(out)` becomes
  `S0: send(req)` then `S1: recv(resp), send(out)`
- but `(send(req) || recv(resp)) -> join -> send(out)` keeps all three channel
  ops in `S0`

So in the current toolchain, introducing separate token lanes still does not
guarantee a new stage boundary, but it can change whether a mixed send/recv
shape is treated like one blocking frontier or two.

The summary table only lists channel ops. A schedule can still have length `2`
even when all of its channel ops appear in `S0`, because state/arithmetic work
may occupy the other stage.
