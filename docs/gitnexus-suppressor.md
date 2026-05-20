# GitNexus suppressor — why CLAUDE.md and AGENTS.md ship with empty markers

Rolepod's framework CLAUDE.md / AGENTS.md (root + rendered) end with:

```html
<!-- gitnexus:start -->
<!-- gitnexus:end -->
```

These markers are **intentionally empty**. Don't delete them. Don't populate them.

## Why

`npx gitnexus analyze` seeds project-specific GitNexus content (symbol counts,
process names, repo-scoped tool tables) into the `<!-- gitnexus:start -->` /
`<!-- gitnexus:end -->` block of CLAUDE.md and AGENTS.md. GitNexus owns that
behaviour — rolepod ships no hook of its own around it (the pre-PR-10
`gitnexus-wrap.sh` wrapper was removed; rolepod no longer wraps vendor hooks).

Rolepod is a **universal framework**. Project-specific content (`rolepod is
indexed as 1593 symbols / 8 execution flows / ...`) does not belong in upstream
tracked files — it pollutes the diff for every contributor and makes the
framework look bound to one project. The markers are kept **empty** in the
tracked files as a convention; to keep them that way, run GitNexus's own
`npx gitnexus analyze --skip-agents-md` (which preserves the block) or simply
do not run `analyze` against the rolepod repo itself. If a populated block
slips into a commit, restore the empty markers before merging.

## Where the markers must live

| File | Purpose |
|------|---------|
| `CLAUDE.md` (root) | What Lead reads when working in the rolepod repo |
| `AGENTS.md` (root) | Codex CLI's entry doc when working in the rolepod repo |
| `adapters/claude/CLAUDE.md.tmpl` | Template rendered into user homes — keeps `~/.claude/CLAUDE.md` from being seeded with one specific project's content |
| `adapters/codex/AGENTS.md.tmpl` | Same idea for Codex |

The root files are byte-identical to the rendered output (`make test-render-clean` enforces this), so the templates are the source of truth.

## When NOT to keep them empty

If you (a downstream user, not rolepod itself) want GitNexus seeded in your own clone's CLAUDE.md / AGENTS.md, **delete the empty markers** in your local copy. The next `npx gitnexus analyze` will populate them with your repo's content.

**Don't commit the populated form back upstream to rolepod main.** It's project-specific noise here.

## Test guard

`tests/static/lean-surface.sh` caps the rendered CLAUDE.md at 150 lines. Earlier versions of the suppressor had a 14-line HTML comment explaining the rationale inline; that pushed rendered CLAUDE.md to 158 lines and tripped the cap. The comment now lives in this doc, the templates keep a one-line pointer:

```html
<!-- gitnexus suppressor: empty markers + GitNexus's own --skip-agents-md keep auto-inject off. Full rationale in docs/gitnexus-suppressor.md. -->
<!-- gitnexus:start -->
<!-- gitnexus:end -->
```
