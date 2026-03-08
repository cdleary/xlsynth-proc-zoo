// dslx_run_flags: --max_ticks=64
//
// Single-proc phased formulation with explicit cold-start, steady-state, and
// drain phases. This tests whether adding a one-request prologue and a final
// response-drain epilogue is enough to make a monolithic proc bubble-free.
// In the current toolchain, the generated RTL still bubbles in steady state,
// so fill/drain alone do not remove the core request/response coupling.

import examples.ram_fetch_relu.fetch_relu_common;

const NUM_ITEMS = u32:4;
const PHASE_COLD = u2:0;
const PHASE_STEADY = u2:1;
const PHASE_DRAIN = u2:2;
const PHASE_DONE = u2:3;

// Uses explicit cold/steady/drain phases to test whether prologue and epilogue help.
proc FetchReluSingleColdSteadyDrain {
    addr_in: chan<u32> in;
    ram_req: chan<u32> out;
    ram_resp: chan<s32> in;
    out_ch: chan<s32> out;

    config(addr_in: chan<u32> in, ram_req: chan<u32> out, ram_resp: chan<s32> in, out_ch: chan<s32> out) {
        (addr_in, ram_req, ram_resp, out_ch)
    }

    init { (u32:0, u32:0, PHASE_COLD) }

    next(state: (u32, u32, u2)) {
        let issued = state.0;
        let retired = state.1;
        let phase = state.2;

        match phase {
            PHASE_COLD => {
                let tok = token();
                let (tok, addr) = recv(tok, addr_in);
                let _tok = send(tok, ram_req, addr);
                let next_issued = issued + u32:1;
                let next_phase = if next_issued == NUM_ITEMS { PHASE_DRAIN } else { PHASE_STEADY };
                (next_issued, retired, next_phase)
            },
            PHASE_STEADY => {
                let req_tok = token();
                let (req_tok, addr) = recv(req_tok, addr_in);
                let _req_tok = send(req_tok, ram_req, addr);

                let resp_tok = token();
                let (resp_tok, data) = recv(resp_tok, ram_resp);
                let relu = if data < s32:0 { s32:0 } else { data };
                let _resp_tok = send(resp_tok, out_ch, relu);

                let next_issued = issued + u32:1;
                let next_retired = retired + u32:1;
                let next_phase = if next_issued == NUM_ITEMS { PHASE_DRAIN } else { PHASE_STEADY };
                (next_issued, next_retired, next_phase)
            },
            PHASE_DRAIN => {
                let tok = token();
                let (tok, data) = recv(tok, ram_resp);
                let relu = if data < s32:0 { s32:0 } else { data };
                let _tok = send(tok, out_ch, relu);
                let next_retired = retired + u32:1;
                let next_phase = if next_retired == NUM_ITEMS { PHASE_DONE } else { PHASE_DRAIN };
                (issued, next_retired, next_phase)
            },
            _ => state,
        }
    }
}

// Wires the phased single-proc design together for DSLX interpreter testing.
#[test_proc]
proc FetchReluSingleColdSteadyDrainTest {
    terminator: chan<bool> out;

    config(terminator: chan<bool> out) {
        let (addr_p, addr_c) = chan<u32>("addr");
        let (req_p, req_c) = chan<u32>("ram_req");
        let (resp_p, resp_c) = chan<s32>("ram_resp");
        let (out_p, out_c) = chan<s32>("out");

        spawn fetch_relu_common::AddressSource(addr_p);
        spawn FetchReluSingleColdSteadyDrain(addr_c, req_p, resp_c, out_p);
        spawn fetch_relu_common::FakeRam(req_c, resp_p);
        spawn fetch_relu_common::OutputChecker(terminator, out_c);

        (terminator,)
    }

    init { () }

    next(state: ()) { () }
}
