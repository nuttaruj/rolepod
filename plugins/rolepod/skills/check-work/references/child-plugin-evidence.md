<!-- Load when a sibling plugin wrote a manifest.json under .rolepod/evidence/. -->

# Child-plugin evidence

Sibling plugins (`rolepod-uiproof`, `rolepod-wplab`, any Extension Protocol v1 plugin) write manifests automatically when the parent marker `.rolepod/parent-active` exists:

```bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
find "$ROOT/.rolepod/evidence" -name manifest.json -type f 2>/dev/null
```

Each `manifest.json` carries `plugin`, `skill`, `phase`, `status` (pass / fail / warn), `summary`, `artifacts[]`.

- Keep only dirs whose `<ts>` postdates your last relevant edit and whose `skill` / `summary` names this task's target; older or unidentifiable runs are a named limitation.
- Any KEPT `fail` → verify fails as a whole: surface the summary and the failing artifact path.
- All KEPT `pass` / `warn` → verify passes; list the warnings inline.
- Reference child artifacts by relative path from the manifest directory.
