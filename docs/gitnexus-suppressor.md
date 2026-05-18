# GitNexus suppressor — why CLAUDE.md and AGENTS.md ship with empty markers

Rolepod's framework CLAUDE.md / AGENTS.md (root + rendered) end with:

```html
<!-- gitnexus:start -->
<!-- gitnexus:end -->
```

These markers are **intentionally empty**. Don't delete them. Don't populate them.

## Why

The GitNexus plugin's wrap hook (`hooks/gitnexus-wrap.sh`) auto-seeds project-specific GitNexus content (symbol counts, process names, repo-scoped tool tables) into CLAUDE.md and AGENTS.md the first time `npx gitnexus analyze` runs against a fresh clone. The hook decides whether to seed by checking whether the markers are already present:

```bash
# hooks/gitnexus-wrap.sh (paraphrased)
FREEZE_FLAG="--skip-agents-md"
for entry in "$REPO/CLAUDE.md" "$REPO/AGENTS.md"; do
  [ -f "$entry" ] || continue
  if ! grep -q "<!-- gitnexus:start -->" "$entry"; then
    FREEZE_FLAG=""   # → next analyze will seed
    break
  fi
done
```

When *either* file lacks the marker, the freeze flag clears and the next analyze writes 40+ lines of repo-specific content into both files.

Rolepod is a **universal framework**. Project-specific content (`rolepod is indexed as 1593 symbols / 8 execution flows / ...`) does not belong in upstream tracked files — it pollutes the diff for every contributor and makes the framework look bound to one project. The empty markers tell the wrap hook "block already present" so it always passes `--skip-agents-md` → no inject → no dirty diff.

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
<!-- gitnexus suppressor: empty markers freeze auto-inject (hooks/gitnexus-wrap.sh). Full rationale in docs/gitnexus-suppressor.md. -->
<!-- gitnexus:start -->
<!-- gitnexus:end -->
```
