<!-- Load for a review kind that needs the member order, --all, the anchor rule or the degradation table. SKILL.md step 3 carries the run itself. -->

# Review kind — order, anchor, degradation

Rolepod's CLIs span model families — Claude, Codex (GPT), Google (served by Antigravity `agy`; the standalone Gemini CLI is retired for individual accounts and is never in the pool), plus the multi-model harnesses Cursor and OpenCode (their model = whatever default their owner configured — recorded, never a criterion).
Any CLI can be the Lead. The review goes to a different CLI than the Lead's, never to the Lead's own.

## Member order

| Family (CLI) | Reviews best |
|-------|--------------|
| OpenAI (`codex`) | depth · security · logic rigor |
| Google (`agy`) | breadth · cross-file · large-diff sweep |
| Anthropic (`claude`) | architecture · code quality · maintainability |
| Cursor / OpenCode | the family of their default model — the runner tells you |

1. Read the diff; name the axes it needs (a diff can need several).
2. The pool file is the order — put the member owning the dominant axis first.
3. One run per lens: each `--lens spec` and `--lens standards` gets one external run with the same pool order. Full R4 adds `--adversarial` as a separate run. The first usable member in pool order runs that lens. `--all` (every usable member, concurrently, each anchored) only on the user's ask; each CLI is one opinion.
4. Launch every routed reviewer — the runner and internal agents alike — in ONE dispatch. They read the same frozen diff independently; nothing is gained by waiting for one before starting the next.

