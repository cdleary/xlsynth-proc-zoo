// dslx_run_flags: --max_ticks=64
//
// Single-proc software-pipelined formulation of the RAM-read-plus-ReLU flow.
// Unlike the serialized baseline, the top proc has unit state and starts each
// activation from a fresh `token()`, which lets the scheduler overlap request
// work for activation `n` with response/ReLU/output work for activation `n-1`.
// In this toolchain the scheduler accepts worst_case_throughput=1 with two
// pipeline stages, but the current generated RTL still shows interface bubbles
// under the repo's 1-cycle RAM smoke-test harness.

import examples.ram_fetch_relu.fetch_relu_common;

// Reads an address, overlaps request and response work across stages, and emits ReLU output.
proc FetchReluSinglePipelined {
    addr_in: chan<u32> in;
    ram_req: chan<u32> out;
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(addr_in: chan<u32> in, ram_req: chan<u32> out, ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (addr_in, ram_req, ram_resp, out_ch)
    }

    init { () }

    next(state: ()) {
        let tok = token();
        let (tok, addr) = recv(tok, addr_in);
        let tok = send(tok, ram_req, addr);
        let (tok, data) = recv(tok, ram_resp);
        let relu = if data < s32:0 { s32:0 } else { data };
        let _tok = send(tok, out_ch, relu);
    }
}

// Wires the software-pipelined single-proc design together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSinglePipelinedTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (addr_p, addr_c) = chan<u32>("addr");
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn fetch_relu_common::AddressSource(addr_p);
        spawn FetchReluSinglePipelined(addr_c, req_p, resp_c, out_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
