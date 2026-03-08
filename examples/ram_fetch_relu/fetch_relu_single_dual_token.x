// dslx_run_flags: --max_ticks=64
//
// Single-proc formulation with separate carried token lanes for request issue
// and response retirement. This aims to model the split request/response shape
// inside one proc by making the request-side and response-side dependencies
// explicit in proc state instead of relying on one serialized token chain.

import examples.ram_fetch_relu.fetch_relu_common;

// Carries independent request and response token lanes while tracking pipeline fill.
proc FetchReluSingleDualToken {
    addr_in: chan<u32> in;
    ram_req: chan<u32> out;
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(addr_in: chan<u32> in, ram_req: chan<u32> out, ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (addr_in, ram_req, ram_resp, out_ch)
    }

    init { (false, token(), token()) }

    next(state: (bool, token, token)) {
        let primed = state.0;
        let req_tok = state.1;
        let resp_tok = state.2;

        let (req_tok, addr) = recv(req_tok, addr_in);
        let req_tok = send(req_tok, ram_req, addr);

        let resp_tok = if primed {
            let (resp_tok, data) = recv(resp_tok, ram_resp);
            let relu = if data < s32:0 { s32:0 } else { data };
            send(resp_tok, out_ch, relu)
        } else {
            resp_tok
        };

        (true, req_tok, resp_tok)
    }
}

// Wires the dual-token single-proc design together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSingleDualTokenTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (addr_p, addr_c) = chan<u32>("addr");
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn fetch_relu_common::AddressSource(addr_p);
        spawn FetchReluSingleDualToken(addr_c, req_p, resp_c, out_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
