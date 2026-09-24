<!-- Adapted from mattpocock/skills prototype UI.md (MIT). Load from write-prototype Pick the branch. -->

# UI Prototype

Generate several radically different UI variations on a single route, switchable from a floating bottom bar. The user flips between variants in the browser, picks one (or steals bits from each); the rest stays on `spike/<name>` as evidence, out of the real app.

If the question is about logic/state rather than what something looks like, this is the wrong branch. Use `logic.md`.

## When this is the right shape

- "What should this page look like?"
- "I want to see a few options for this dashboard before committing."
- "Try a different layout for the settings screen."
- Any time the user would otherwise spend a day picking between three vague mockups in their head.

## Two sub-shapes: strongly prefer sub-shape A

A UI prototype is much easier to judge when it's butting up against the rest of the app: real header, real sidebar, real data, real density. A throwaway route on its own is a vacuum: every variant looks fine in isolation. Default to sub-shape A whenever there's a plausible existing page to host the variants. Only reach for sub-shape B if the prototype genuinely has no nearby home.

### Sub-shape A: adjustment to an existing page (preferred)

The route already exists — this is the `change` Product mode. Variants render on the same route, gated by a `?variant=` URL search param, mounted in the spike worktree against the route's real data. The existing data fetching, params, and auth all stay; only the rendering swaps.

If the prototype is for something that doesn't yet have a page but would naturally live inside one (a new section of the dashboard, a new card on the settings screen, a new step in an existing flow), it's still sub-shape A. Mount the variants inside the host page.

### Sub-shape B: a new page (last resort)

Only use this when the thing being prototyped genuinely has no existing page to live inside (an entirely new top-level surface, or a flow that can't be embedded anywhere sensible), or there is no runnable app to mount against — this is the `new` Product mode, or a `change` with no runnable app. Build one self-contained HTML file, named so it's obviously a prototype. Same `?variant=` pattern.

Before committing to sub-shape B, sanity-check: is there really no existing page this could be embedded in? An empty route hides design problems that a populated one would expose.

In both sub-shapes the floating bottom bar is identical.

## Process

### 1. State the question and pick N

Default to 3 variants. More than 5 stops being radically different and starts being noise, so cap there.

Write down the plan in one line, in the prototype's location or a top-of-file comment, naming the spike branch:

> "Three variants of the settings page, switchable via `?variant=`, on the existing `/settings` route, built on `spike/settings-layout`."

This works whether the user is here to push back or not.

### 2. Generate radically different variants

Draft each variant. Hold each one to:

- The page's purpose and the data it has access to.
- The project's component library / styling system (whatever the project already uses).
- A clear exported component name, e.g. `VariantA`, `VariantB`, `VariantC`.

Variants must be structurally different: different layout, different information hierarchy, different primary affordance, not just different colours. Three slightly-tweaked card grids isn't a UI prototype, it's wallpaper. If two drafts come out too similar, redo one with explicit "do not use a card grid" guidance.

### 3. Wire them together

Create a single switcher component on the route:

```
// pseudo-code, adapt to the project's framework
const variant = searchParams.get('variant') ?? 'A';
return (
  <>
    {variant === 'A' && <VariantA {...data} />}
    {variant === 'B' && <VariantB {...data} />}
    {variant === 'C' && <VariantC {...data} />}
    <PrototypeSwitcher variants={['A','B','C']} current={variant} />
  </>
);
```

For sub-shape A: keep all the existing data fetching above the switcher; only the rendered subtree changes per variant. For sub-shape B: the same switch statement lives inline in the one self-contained HTML file, in plain JS instead of framework components.

### 4. Build the floating switcher

A small fixed-position bar at the bottom-centre of the screen with three pieces:

- Left arrow: cycles to the previous variant (wraps around).
- Variant label: shows the current variant key and, if the variant exports a name, that name too, e.g. `B (Sidebar layout)`.
- Right arrow: cycles forward (wraps around).

Behaviour:

- Clicking an arrow updates the URL search param (the framework's router for sub-shape A; plain `URLSearchParams` + `history.replaceState` for the sub-shape B self-contained file) so the variant is shareable and reload-stable.
- Keyboard: left and right arrow keys also cycle. Don't intercept arrow keys when an input, textarea, or contenteditable element is focused.
- Visually distinct from the page (e.g. high-contrast pill, subtle shadow) so it's obviously not part of the design being evaluated.
- Hidden in production builds: gate on the project's production check so a stray prototype merge can't ship the bar to users.

Sub-shape A: put the switcher in a single shared component, located wherever shared UI lives in the project, so multiple hosted prototypes can reuse it. Sub-shape B: inline the same bar as plain markup and JS in the one HTML file — there is nothing to import from.

### 5. Hand it over

Surface both links per `write-prototype` Hand over — the original route and the prototype route with each `?variant=` key — side by side, same route. The user will flip through whenever they get to it. The interesting feedback is usually "I want the header from B with the sidebar from C," which is the actual design they want.

### 6. Capture the answer and clean up

Once a variant has won, capture the answer (which variant and why) the way `write-prototype` Capture describes. The whole variant set — winner and losers, the switcher included — stays on `spike/<name>`, never merged, cherry-picked or copied into a non-spike branch (`write-prototype` Guardrails). The winning variant is the reference shape: the decision goes into the spec, and a variant the user wants for real becomes a change — `write-plan` → `implement-plan` rebuilds it properly (tests, error handling) on the project's normal branch.

The full set of variants is the primary source, so it stays on the spike branch as evidence — code written under prototype constraints (no tests, minimal error handling) left in the main branch rots fast and confuses the next reader.

## Anti-patterns

- Variants that differ only in colour or copy. That's a tweak, not a prototype. Real variants disagree about structure.
- Sharing too much code between variants. A shared header is fine; a shared layout defeats the point. Each variant should be free to throw out the layout.
- Wiring variants to real mutations. Read-only prototypes are fine. If a variant needs to mutate, point it at a stub: the question is "what should this look like," not "does the backend work."
- Promoting the prototype directly to production. The variant code was written under prototype constraints (no tests, minimal error handling); `implement-plan` rewrites it properly, from the spec, not by moving this code.
