// SPDX-License-Identifier: Apache-2.0

// Minimal proc patterns for characterizing how send/recv shapes are scheduled.

// One blocking receive followed by one send in the same activation.
proc RecvThenSend {
    in_ch: chan<u32> in;
    out_ch: chan<u32> out;

    config(in_ch: chan<u32> in, out_ch: chan<u32> out) {
        (in_ch, out_ch)
    }

    init { () }

    next(state: ()) {
        let tok = token();
        let (tok, value) = recv(tok, in_ch);
        let _tok = send(tok, out_ch, value);
    }
}

// One send followed by one blocking receive in the same activation.
proc SendThenRecv {
    out_ch: chan<u32> out;
    in_ch: chan<u32> in;

    config(out_ch: chan<u32> out, in_ch: chan<u32> in) {
        (out_ch, in_ch)
    }

    init { u32:0 }

    next(counter: u32) {
        let tok = token();
        let tok = send(tok, out_ch, counter);
        let (_tok, _ack) = recv(tok, in_ch);
        counter + u32:1
    }
}

// Two blocking receives serialized on one token chain before a send.
proc SerialTwoRecvsThenSend {
    left_in: chan<u32> in;
    right_in: chan<u32> in;
    out_ch: chan<u32> out;

    config(left_in: chan<u32> in, right_in: chan<u32> in, out_ch: chan<u32> out) {
        (left_in, right_in, out_ch)
    }

    init { () }

    next(state: ()) {
        let tok = token();
        let (tok, left) = recv(tok, left_in);
        let (tok, right) = recv(tok, right_in);
        let _tok = send(tok, out_ch, left + right);
    }
}

// Two blocking receives on separate token lanes that rejoin before the send.
proc ParallelTwoRecvsThenSend {
    left_in: chan<u32> in;
    right_in: chan<u32> in;
    out_ch: chan<u32> out;

    config(left_in: chan<u32> in, right_in: chan<u32> in, out_ch: chan<u32> out) {
        (left_in, right_in, out_ch)
    }

    init { () }

    next(state: ()) {
        let left_tok = token();
        let right_tok = token();
        let (left_tok, left) = recv(left_tok, left_in);
        let (right_tok, right) = recv(right_tok, right_in);
        let send_tok = join(left_tok, right_tok);
        let _tok = send(send_tok, out_ch, left + right);
    }
}

// A blocking round-trip shape: send a request, wait for a response, then send an output.
proc BlockingRoundTrip {
    req_ch: chan<u32> out;
    resp_ch: chan<u32> in;
    out_ch: chan<u32> out;

    config(req_ch: chan<u32> out, resp_ch: chan<u32> in, out_ch: chan<u32> out) {
        (req_ch, resp_ch, out_ch)
    }

    init { u32:0 }

    next(counter: u32) {
        let tok = token();
        let tok = send(tok, req_ch, counter);
        let (tok, resp) = recv(tok, resp_ch);
        let _tok = send(tok, out_ch, resp + u32:1);
        counter + u32:1
    }
}

// A round-trip shape whose response retirement is optional per activation.
proc NonBlockingRoundTrip {
    req_ch: chan<u32> out;
    resp_ch: chan<u32> in;
    out_ch: chan<u32> out;

    config(req_ch: chan<u32> out, resp_ch: chan<u32> in, out_ch: chan<u32> out) {
        (req_ch, resp_ch, out_ch)
    }

    init { u32:0 }

    next(counter: u32) {
        let req_tok = token();
        let _req_tok = send(req_tok, req_ch, counter);

        let resp_tok = token();
        let (resp_tok, resp, valid) = recv_non_blocking(resp_tok, resp_ch, u32:0);
        let _resp_tok = send_if(resp_tok, out_ch, valid, resp + u32:1);

        counter + u32:1
    }
}
