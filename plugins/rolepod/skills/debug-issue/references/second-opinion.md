<!-- Load at the Second opinion step: the consult pool's rules and the vertical fallback. -->

# Second opinion — the consult run

## The pool

- `rolepod-cross-family --kind consult --brief <ledger>` (plugin tree: `scripts/cross-family.sh`; add `--lead <cli>` outside Claude).
- The pool is the user's opt-in (`.rolepod/cross-family` → `~/.rolepod/cross-family`; no file or `none` = off). Never enable it unasked.
- Consult is a FOREGROUND call with a short per-member budget — a stuck loop needs the answer now. A `consult: <fast cli> <deep cli>` order line in the config puts the fast member first and leaves the slow deep one as fallback.
- The runner takes the first usable member that is not the Lead's own CLI — read-only, on that CLI's default model, clean room (`ROLEPOD_BRAIN_SILENT=1`) — and anchors the reply under `.rolepod/evidence/external/`. A failed member is logged and the next one runs.

## Vertical fallback

Pool off (`none`, or no file) or no usable member → the Lead's own CLI at its strongest model.
- A native advisor mode, when the CLI has one, IS this channel.
- Otherwise ask the CLI which models it exposes (its own `--help`), pick the top tier by name, and run that CLI headless on the same ledger file (`<cli> -p --model <name>` / `<cli> exec -m <name>`).
- Valid only when that model differs from the one now running. Already on it, or cannot tell → no usable advisor: escalate to `manage-context`.
