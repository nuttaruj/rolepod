---
name: rolepod-stats
description: Use when the user asks for rolepod stats, an evidence report, tier distributions, verify verdicts, review outcomes or which models ran
disable-model-invocation: true
---

# Rolepod Stats

One project's evidence log and transcripts → a few compact tables.

### 1. Run the script

Run `bash <this skill's folder>/scripts/stats.sh` from the project root (`$1` overrides the git root); never `cd` into the skill folder.
One run prints every table: tiers, verify and review verdicts, strong dispatches, the gate, write-scope and external-verdict tables, and on Claude Code the models that ran — the Lead's turns and the subagent turns, kept apart. On another CLI the transcript tables are skipped; external CLIs never appear in transcripts.

Done when: the tables are in hand, or the script printed "no data" with the paths it read.

## Guardrails

- Answer what the user asked plus every ⚠ line; a plain "stats" ask gets three short tables (intent, Lead turns, subagent turns). Never paste raw output — summarize.
- Flag any strong dispatch without an explicit override and any subagent model the tier policy would not predict.

## Next phase

This skill is a leaf: stop with the tables and each ⚠ line. If `scripts/stats.sh` is missing, say the stats need it and stop.
