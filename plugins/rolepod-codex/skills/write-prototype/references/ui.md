# UI Prototype

Build several radically different layouts on one route and flip between them with a bottom bar. The user picks one, borrows pieces from others, or says "none of these". The whole variant set stays on the `spike/<name>` branch as evidence and never enters the real app.

Use this when the question is about layout, information hierarchy or visual structure. A question about logic or state belongs in `logic.md`.

## Two sub-shapes: almost always pick A

Variants are far easier to judge beside the real header, sidebar, data and density. A lone throwaway page is a vacuum where everything looks fine. Pick A whenever a plausible host page exists; pick B only when nothing nearby can hold the prototype.

**A: an adjustment to an existing page (preferred).** The route exists, so this is the `change` Product mode. Variants render on that route, selected by a `?variant=` URL param, inside the spike worktree and against the route's real data. The route keeps its existing data fetching, params and auth; only the rendering swaps. A new card, dashboard section or flow step that would live inside a page is still A: mount the variants in the host page.

**B: a new page (last resort).** Use it when the thing has no page to live in (a new top-level surface, or a flow that cannot be embedded) or no app can run. This is the `new` Product mode, or a `change` with no runnable app. Build one self-contained HTML file, named so it is obviously a prototype, with the same `?variant=` selection.

Before choosing B, ask once more whether a host page exists: an empty page hides problems a populated one exposes. The bottom bar is identical in both.

## Process

### 1. State the question and pick N

N rules: default 3; 2 for a two-way question; 1 when the user already named the layout to test (then no switcher; step 3 says what to render); cap at 5, because past that the variants stop being different and turn into noise.

Write the plan as one line in the prototype's location, naming the route and the spike branch:

> "Three variants of the settings page on the existing `/settings` route, switched by `?variant=`, built on `spike/settings-layout`."

### 2. Make the variants structurally different

Different layout, information hierarchy and primary affordance, not different colors or spacing. Each variant:

- serves the page's purpose and uses the data it already has;
- uses the project's own component library and styling;
- exports a clearly named component (`VariantA`, `VariantB`, ...).

### 3. Wire them together

N = 1: skip this step and step 4. Render that variant on the route (in B, as the HTML file's only content).

Otherwise one switcher component picks what renders:

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

In A, all data fetching stays above the switcher and only the rendered subtree changes. In B, the same switch lives inline in the HTML file as plain JS.

### 4. Build the floating switcher

A small fixed bar at the bottom centre, with three parts:

- left arrow: previous variant, wrapping;
- label: the variant key, plus its name when the variant exports one, e.g. `B (Sidebar layout)`;
- right arrow: next variant, wrapping.

Behavior:

- A click updates the URL param so the view is shareable and survives reload: the framework's router in A, `URLSearchParams` with `history.replaceState` in B's single file.
- Left and right arrow keys cycle too, except while an input, textarea or contenteditable element has focus.
- Make it look unlike the page (high contrast, soft shadow) so it reads as a prototype control.
- Hide it in production builds behind the project's production check, so a stray merge cannot ship it.

In A, write the switcher in the spike beside the variants, or reuse one the project already has; never build a shared component for future prototypes, since the spike is throwaway. In B, inline the bar as plain markup and JS; nothing can be imported.

### 5. Capture the answer

Capture per the Capture step in `write-prototype/SKILL.md`; the variant set stays on `spike/<name>`.

## Anti-pattern

Variants that share layout code. A shared header is fine, but a shared layout defeats the comparison, so each variant must be free to discard the layout.
