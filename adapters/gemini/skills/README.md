# Gemini extension — skills/

Per Gemini extension reference, skills are bundled as `skills/<name>/SKILL.md`
inside the extension directory. Each skill exposes a workflow that the model
can read on demand when its trigger phrase matches.

This directory is **populated by `build/render.sh --target=gemini`**. The build
copies (or symlinks) every `core/skills/<name>/` tree into
`adapters/gemini/skills/<name>/` (or directly into the rendered extension at
`build/rendered/gemini/skills/`). Source of truth lives in `core/skills/` so
the same skill set ships to all three CLIs.

Lead integration note: `build/render.sh::render_gemini` currently emits only
`GEMINI.md`. To complete the extension wire-up, add a `cp -R` (or symlink) of
`core/skills/` into the rendered output. Pseudocode:

```bash
cp -R "$REPO_DIR/core/skills" "$out_dir/skills"
cp -R "$REPO_DIR/adapters/gemini/commands" "$out_dir/commands"
cp -R "$REPO_DIR/adapters/gemini/hooks"    "$out_dir/hooks"
cp    "$REPO_DIR/adapters/gemini/gemini-extension.json" "$out_dir/"
```

That is intentionally **not** done in this commit — render.sh is owned by
Lead per task brief.

Reference: https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md#agent-skills
