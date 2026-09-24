<!-- Load at the Second opinion step: which channel runs the consult, and the fallback when the pool cannot. -->

# Second opinion — the consult run

## Pool on

`cross-family` kind consult with the ledger file — a FOREGROUND call on a short budget; it runs the member, the order and the evidence.
The pool is the user's opt-in (`.rolepod/cross-family` → `~/.rolepod/cross-family`; no file or `none` = off). Never enable it unasked.

## Vertical fallback

Pool off, no usable member, or `cross-family` absent → the Lead's own CLI at its strongest model.
- A native advisor mode, when the CLI has one, IS this channel.
- Otherwise read the CLI's own `--help` for the models it exposes, pick the top tier by name, and run that CLI headless on the same ledger file (`<cli> -p --model <name>` / `<cli> exec -m <name>`).
- Valid only when that model differs from the one now running. Already on it, or cannot tell → no usable advisor: escalate to `manage-context`.
