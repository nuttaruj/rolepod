<!-- Load when hand-editing the pool setting in ~/.rolepod/config.json. SKILL.md step 6 writes it through --setup. -->

# The pool in ~/.rolepod/config.json

The pool lives in `~/.rolepod/config.json` under the `pool` key (machine-wide only; no project override). Use `cross-family.sh --setup` to write it, or hand-edit.

```json
{
  "pool": {
    "cross-family": "on",
    "reviewer": {
      "review": "cursor agy codex codex",
      "consult": "agy codex",
      "critique": "cursor agy codex"
    }
  }
}
```

- **`cross-family`** (string "on" or "off") — enables or disables the external pool machine-wide, even if members are listed. Default: "off" (unset key = off).
- **`reviewer`** (object) — external review members and settings:
  - **`review`** (space-separated CLI names, order matters) — for R4 adversarial pass and standard-pass review. Default order used for all kinds if other kinds are unset.
  - **`consult`** (space-separated CLI names, order matters) — for debug consult. Default: falls back to `review` order if unset.
  - **`critique`** (space-separated CLI names, order matters) — for spec critique during `write-spec`. Default: falls back to `review` order if unset.

**Members** — valid values: `codex`, `claude`, `agy`, `cursor`, `opencode`. List every CLI you use; the Lead's own CLI is skipped at run time, so one pool serves every Lead. Member order matters: the runner tries them in order and uses the first available one. The model family (vendor) is recorded for information and never filters a member — a member on the Lead's own vendor still counts as external.

**Time budgets** — hand-edit to add per-member options after a CLI name:
- `stall=<seconds>` (silence budget; default 600 s) — a member is killed if it goes silent that long.
- `timeout=<seconds>` (wall-clock runaway insurance; defaults: review 7200 s detached / 600 s foreground, consult 300, critique 600).

Example: `"review": "cursor agy codex stall=900 timeout=1800"` binds `stall=900` and `timeout=1800` to codex.

**Precedence** — for any option: `--flag` (command-line) > config setting > kind default.
