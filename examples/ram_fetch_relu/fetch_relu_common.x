// SPDX-License-Identifier: Apache-2.0
//
// Shared support code for the RAM+ReLU family.
// These helpers keep the example variants focused on their top-level proc
// formulation while reusing the same address source, fake RAM, and checker.

// Returns the fake RAM contents for a small fixed address map.
pub fn ram_read(addr: u32) -> s32 {
    match addr {
        u32:0 => s32:-3,
        u32:1 => s32:7,
        u32:2 => s32:0,
        _ => s32:5,
    }
}

// Returns the expected ReLU output for the generated address sequence.
pub fn expected_relu(index: u32) -> s32 {
    match index {
        u32:0 => s32:0,
        u32:1 => s32:7,
        u32:2 => s32:0,
        _ => s32:5,
    }
}

// Generates the small monotonic address stream used by the examples and tests.
pub proc AddressSource {
    out_ch: chan<u32> out;

    config(out_ch: chan<u32> out) {
        (out_ch,)
    }

    init { u32:0 }

    next(index: u32) {
        let tok = token();
        let addr = match index {
            u32:0 => u32:0,
            u32:1 => u32:1,
            u32:2 => u32:2,
            _ => u32:3,
        };
        let tok = send(tok, out_ch, addr);
        if index < u32:3 { index + u32:1 } else { index }
    }
}

// Models a 1-cycle RAM by replying to each request on the following activation.
pub proc FakeRam {
    req: chan<u32> in;
    resp: chan<s32> out;

    config(req: chan<u32> in, resp: chan<s32> out) {
        (req, resp)
    }

    init { (false, u32:0) }

    next(state: (bool, u32)) {
        let tok = token();
        let tok = if state.0 {
            send(tok, resp, ram_read(state.1))
        } else {
            tok
        };
        let (tok, addr) = recv(tok, req);
        (true, addr)
    }
}

// Checks observed outputs against the expected ReLU sequence and then terminates.
pub proc OutputChecker {
    terminator: chan<bool> out;
    observed: chan<s32> in;

    config(terminator: chan<bool> out, observed: chan<s32> in) {
        (terminator, observed)
    }

    init { (u32:0, token()) }

    next(state: (u32, token)) {
        let index = state.0;
        let tok = state.1;
        let (tok, value) = recv(tok, observed);
        assert_eq(value, expected_relu(index));
        if index == u32:3 {
            let tok = send(tok, terminator, true);
            (index, tok)
        } else {
            (index + u32:1, tok)
        }
    }
}
