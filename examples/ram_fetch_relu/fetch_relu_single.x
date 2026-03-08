// dslx_run_flags: --max_ticks=64
//
// Serialized single-proc baseline for "send address -> read RAM -> apply ReLU ->
// send result". The main proc carries its token in state, so one activation must
// complete `recv(addr) -> send(req) -> recv(resp) -> send(out)` before the next
// activation can begin. This file is the semantic reference point, but for a
// 1-cycle RAM it does not codegen at worst_case_throughput=1.

import examples.ram_fetch_relu.fetch_relu_common;

// Reads an address, waits for the RAM response, applies ReLU, and emits the result.
proc FetchReluSingle {
    addr_in: chan<u32> in;
    ram_req: chan<u32> out;
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(addr_in: chan<u32> in, ram_req: chan<u32> out, ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (addr_in, ram_req, ram_resp, out_ch)
    }

    init { token() }

    next(tok: token) {
        let (tok, addr) = recv(tok, addr_in);
        let tok = send(tok, ram_req, addr);
        let (tok, data) = recv(tok, ram_resp);
        let relu = if data < s32:0 { s32:0 } else { data };
        send(tok, out_ch, relu)
    }
}

// Wires the serialized single-proc example together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSingleTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (addr_p, addr_c) = chan<u32>("addr");
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn fetch_relu_common::AddressSource(addr_p);
        spawn FetchReluSingle(addr_c, req_p, resp_c, out_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
