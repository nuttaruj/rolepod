The rules a `domain: writing` build adds to implement-plan.

## Audience first

The brief names one audience: `dev`, `user` or `prospect`. None named, or it conflicts with the target path → return `BLOCKED` with `MISSING TARGET: audience must be dev | user | prospect`; write nothing. One build, one audience; switching mid-text means restart.

| Audience | Reads | Register | Cut |
|---|---|---|---|
| `dev` — repo docs, ADRs, runbooks, API reference, code comments | engineers, API consumers | technical, precise, code sample over prose, link to source over a paraphrase | marketing adjectives, hand-holding |
| `user` — help, FAQ, onboarding, in-app strings, errors, transactional email | end users, often frustrated or lost | plain words, second person, action first; an error says what happened, why when known, what to try | internal terms (endpoint, deploy, schema, payload, auth, status codes), blame, idioms |
| `prospect` — landing, blog, SEO, ads, campaign email | visitors and leads | benefit before feature, one CTA per surface, urgency only when true | internal tooling names, a second CTA |

Path to audience when the brief names none: `README*`, `CONTRIBUTING*`, `CHANGELOG*`, `docs/**` → `dev`; `help/**`, `faq/**`, `onboarding/**`, in-app strings, lifecycle email → `user`; `marketing/**`, `landing/**`, `blog/**`, `ads/**` → `prospect`. Several globs match or none → the audience is unset.

## Stops

- Facts come from the spec, the code or real support tickets, never memory; every claim points at something you read in this run.
- A code comment defaults to none: only a hidden constraint, a subtle invariant, a workaround for a named bug or behavior that surprises a reader. Never restate the code; never name the task or ticket.
- `user` copy that describes a feature the spec or code does not show, any pricing text, and a change announcement with no step the reader can take → `BLOCKED` naming the question; the Lead asks.
- Copy the brief did not name (an existing string, error or email that users see) stays untouched; changing it → `BLOCKED` or a `NEEDS:` line.
- A runbook or migration guide states its rollback and who to escalate to; an API doc has no `TODO` or `tbd` placeholder.
- A breaking change whose migration path is unset → `BLOCKED`; a guessed path can lose a reader's data.
- An A/B variant declares no winner before its minimum sample size is reached.
- Search trend, volume and competitor content come from a fetched page or search in this run, not from memory.
- An SEO deliverable (audit, schema, canonical, sitemap, fix plan) with the `rolepod-seo` plugin installed → that plugin's skill; without it, out of scope.
- Security warnings are full sentences, never compressed.
