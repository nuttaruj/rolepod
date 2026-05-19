---
name: web-design-guidelines
description: Compatibility shim — UI compliance review (a11y / hierarchy / consistency / platform) now lives in `review-code`; depth lives in the `ui-ux-designer` agent.
when_to_use: when auditing design quality, checking a11y, or reviewing UX before merge
tier: 3
redirect_to: review-code
---

# web-design-guidelines

Compatibility shim. UI compliance review now lives inside **`review-code`**; the `ui-ux-designer` agent adds depth when installed.

→ Open `core/skills/review-code/SKILL.md` and follow that instead. Brief `ui-ux-designer` if available.

This shim preserves the legacy trigger phrase during the migration release.

## If `review-code` is not available

Minimum viable fallback:

1. A11y: keyboard reach, focus order, color contrast, semantic HTML
2. Hierarchy: visual weight matches importance, primary action obvious
3. Consistency: same widget = same behavior across the surface
4. Platform conventions respected (iOS / Android / web)
5. Empty / loading / error states present, not "later"
6. Test with the real data shape, not a placeholder
7. Findings severity-ordered with file or component reference
