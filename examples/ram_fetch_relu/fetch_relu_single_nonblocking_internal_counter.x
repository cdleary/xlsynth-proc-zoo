// dslx_run_flags: --max_ticks=64
//
// Single-proc timing-sensitive formulation of the RAM-read-plus-ReLU flow with
// the address recurrence kept inside the proc. This removes the external
// address-source helper so the core idea can be read as one proc that owns the
// counter state, sends RAM requests, and optionally retires responses.

import examples.ram_fetch_relu.fetch_relu_common;

// Owns the address counter, issues a RAM request every activation, and conditionally emits ReLU output.
proc FetchReluSingleNonBlockingInternalCounter {
    ram_req: chan<u32> out;
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(ram_req: chan<u32> out, ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (ram_req, ram_resp, out_ch)
    }

    init { u32:0 }

    next(index: u32) {
        let addr = if index < u32:3 { index } else { u32:3 };

        let req_tok = token();
        let _req_tok = send(req_tok, ram_req, addr);

        let resp_tok = token();
        let (resp_tok, data, valid) = recv_non_blocking(resp_tok, ram_resp, s32:0);
        let relu = if data < s32:0 { s32:0 } else { data };
        let _resp_tok = send_if(resp_tok, out_ch, valid, relu);

        if index < u32:3 { index + u32:1 } else { index }
    }
}

// Wires the internal-counter non-blocking design together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSingleNonBlockingInternalCounterTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn FetchReluSingleNonBlockingInternalCounter(req_p, resp_c, out_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
