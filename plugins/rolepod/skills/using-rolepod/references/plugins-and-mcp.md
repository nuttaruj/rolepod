<!-- Load when a sibling plugin is installed, or the task's central framework has an unconnected official MCP server. -->

# Sibling plugins and vendor MCP servers

## Sibling plugins

Prefer an installed sibling plugin over manual orchestration; its slash commands are the signal it is installed.
- `rolepod-uiproof` — browser + mobile UI, a11y, visual checks.
- `rolepod-wplab` — WordPress.
- `rolepod-dblab` — databases.

Their evidence lands in `.rolepod/evidence/` for `check-work`. The phase skills carry the integration and the not-installed fallback.

## Vendor MCP servers

A framework or service central to the task ships an official MCP server that is not connected in this session → tell the user once, at a natural pause: its name, one line of what it adds, and where to get it.
- Verify it live first; no verify, no recommendation.
- Declined → drop it.
- The user installs vendor MCPs; rolepod never wraps them and never blocks on them.
