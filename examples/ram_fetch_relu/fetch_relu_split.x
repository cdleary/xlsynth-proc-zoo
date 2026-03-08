// dslx_run_flags: --max_ticks=64
//
// Split request/response formulation of the same RAM-read-plus-ReLU pipeline.
// `SendAddr` owns the address/request side and `RecvRelu` owns the response and
// output side, which removes the single loop-carried token bottleneck from the
// serialized version. This is the simple throughput-friendly example that
// codegens cleanly at worst_case_throughput=1 for a 1-cycle RAM model.

import examples.ram_fetch_relu.fetch_relu_common;

// Forwards incoming addresses to the RAM request channel.
proc SendAddr {
    addr_in: chan<u32> in;
    ram_req: chan<u32> out;

    config(addr_in: chan<u32> in, ram_req: chan<u32> out) {
        (addr_in, ram_req)
    }

    init { token() }

    next(tok: token) {
        let (tok, addr) = recv(tok, addr_in);
        let tok = send(tok, ram_req, addr);
        tok
    }
}

// Receives RAM data, applies ReLU, and emits the transformed result.
proc RecvRelu {
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (ram_resp, out_ch)
    }

    init { token() }

    next(tok: token) {
        let (tok, data) = recv(tok, ram_resp);
        let relu = if data < s32:0 { s32:0 } else { data };
        send(tok, out_ch, relu)
    }
}

// Wires the split request/response design together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSplitTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (addr_p, addr_c) = chan<u32>("addr");
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn fetch_relu_common::AddressSource(addr_p);
        spawn SendAddr(addr_c, req_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn RecvRelu(resp_c, out_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
