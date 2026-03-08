// Minimal reproducer for XLS codegen failing on a proc whose carried state
// contains more than one token.

// Sends on one output channel while carrying a second token in proc state.
proc MultiTokenState {
    out_ch: chan<u1> out;

    config(out_ch: chan<u1> out) {
        (out_ch,)
    }

    init { (token(), token()) }

    next(state: (token, token)) {
        let active_tok = send(state.0, out_ch, u1:1);
        (active_tok, state.1)
    }
}
