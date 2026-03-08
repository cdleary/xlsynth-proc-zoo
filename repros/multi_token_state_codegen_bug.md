# Multi-Token State Codegen Bug

This is a minimal reproducer for an XLS codegen internal error on a proc whose
carried state contains multiple tokens.

Files:

- `repros/multi_token_state_codegen_bug.x`
- `scripts/repro_multi_token_state_codegen_bug.sh`

Run:

```sh
bash scripts/repro_multi_token_state_codegen_bug.sh
```

Current result:

- `ir_converter_main` succeeds.
- `codegen_main` fails with an internal error instead of producing RTL or a
  normal user-facing rejection.
- The failure reproduces with a single output channel and a proc state of just
  `(token, token)`.

The current observed failure includes:

```text
INTERNAL: XLS_RET_CHECK failure ...
UNIMPLEMENTED: Proc has zero-width state element 0, but type is not token or empty tuple, instead got ().
```
