// dslx_run_flags: --max_ticks=64
//
// Single-proc timing-sensitive formulation of the RAM-read-plus-ReLU flow.
// The request side uses blocking address input, while the response side uses a
// non-blocking receive plus `send_if` so the proc can keep launching requests
// even when the RAM response for the prior activation is not yet available.
// In the repo's 1-cycle RAM harness, this is the single-proc variant that
// currently stays bubble-free at the interface.

import examples.ram_fetch_relu.fetch_relu_common;

// Sends a RAM request every activation and conditionally retires a response if one is available.
proc FetchReluSingleNonBlocking {
    addr_in: chan<u32> in;
    ram_req: chan<u32> out;
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(addr_in: chan<u32> in, ram_req: chan<u32> out, ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (addr_in, ram_req, ram_resp, out_ch)
    }

    init { () }

    next(state: ()) {
        let req_tok = token();
        let (req_tok, addr) = recv(req_tok, addr_in);
        let _req_tok = send(req_tok, ram_req, addr);

        let resp_tok = token();
        let (resp_tok, data, valid) = recv_non_blocking(resp_tok, ram_resp, s32:0);
        let relu = if data < s32:0 { s32:0 } else { data };
        let _resp_tok = send_if(resp_tok, out_ch, valid, relu);
    }
}

// Wires the non-blocking single-proc design together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSingleNonBlockingTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (addr_p, addr_c) = chan<u32>("addr");
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn fetch_relu_common::AddressSource(addr_p);
        spawn FetchReluSingleNonBlocking(addr_c, req_p, resp_c, out_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
