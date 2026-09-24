<!-- Load when write-spec Contract picks file mode (multi-session, high-risk surface, or repeat feature). -->

# File mode — saving the spec and Gate 2

## Save

Save to `docs/rolepod/specs/<feature>-YYYY-MM-DD.md` (optional `-vN` / `-draft`).

`docs/rolepod/` is private by default. Before the first save run:

```bash
grep -qx 'docs/rolepod/' .gitignore || echo 'docs/rolepod/' >> .gitignore
```

A repo that deliberately tracks its working docs creates `.rolepod/docs-tracked`. Plans and hand-offs follow the same rule.

## Gate 2 — file review

1. Run the spec-lint on the saved file: `grep -niE '\[\[FILL:|TODO|TBD' <spec>` must print nothing.
2. Run the anchor check — it must print nothing:
   ```bash
   for h in 'Non-goals' 'Current behavior' 'Desired behavior' 'Success criteria'; do grep -q "^## $h" <spec> || echo "missing ## $h"; done
   ```
   The next repeat-feature spec seeds from these four headings; a renamed or numbered heading cannot be found.
3. Ask the user to read the FILE and confirm — not the chat. The file review catches:
   - word drift (chat "soft delete", file "delete");
   - implicit edge cases ("except admin" omitted);
   - reconsideration on seeing the concrete shape.
4. Patch and re-confirm when asked. Hand off to `write-plan` only after the user confirms the file.
