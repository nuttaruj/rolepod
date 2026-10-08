# HTML Report Format

The page is not self-contained: Tailwind and Mermaid come from CDNs, which means outside scripts execute on a page containing repo paths and source code. Mermaid suits graph-shaped diagrams; hand-built divs and inline SVG suit the more editorial ones (mass diagrams, cross-sections). Mermaid everywhere looks generic.

When the network is locked down, offline, or the user wants no third-party script, skip both CDNs: embed the CSS and draw the diagrams as SVG by hand. The six card fields must read with no script at all. Either way, fonts are the scaffold's CSS stacks and never another face.

## Building the page

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Deepen codebase — {{repo name}}</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script type="module">
      import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
      mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "strict" });
    </script>
    <style>
      /* extras for architectural visuals */
      .seam { stroke-dasharray: 4 4; }
      .leak { stroke: #dc2626; }
      .deep { background: linear-gradient(135deg, #0f172a, #1e293b); }
      /* standard fonts from system */
      body { font-family: ui-sans-serif, system-ui, sans-serif; font-size: 16px; line-height: 1.5; }
      h1, h2 { font-family: ui-serif, Georgia, Cambria, "Times New Roman", Times, serif; }
      code, pre, .files { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
    </style>
  </head>
  <body class="bg-stone-50 text-slate-900 font-sans">
    <main class="max-w-5xl mx-auto px-6 py-12 space-y-12">
      <header><!-- title, date, legend --></header>
      <section id="candidates" class="space-y-10"><!-- candidate cards --></section>
      <section id="bugs"><!-- issues found --></section>
      <section id="top-recommendation"><!-- pick one --></section>
    </main>
  </body>
</html>
```

## Top of the page

Title with the repo name and scan date, followed by a key: a box symbol = module, dashed line = seam, red line = leakage, dark fill = deep module. Jump straight into the proposals. No introduction section.

## Candidate card

Each card proposes one refactoring. The diagram is the main argument; text should be sparse and exact.

Every card contains exactly six fields:

- **Files** — a monospaced list, `font-mono text-sm`.
- **Problem** — one sentence.
- **Solution** — one sentence.
- **Benefits** — short bullets (≤6 words), phrased as locality and leverage wins: "one interface to test", "pricing no longer leaks", "4 shallow wrappers removed".
- **Before / After** — the centrepiece: a left column and a right column, drawn with the patterns below.
- **Strength** — a badge: `Strong` (emerald), `Worth exploring` (amber), or `Speculative` (slate).

Prose takes its architectural terms from the explorer-lens Vocabulary. Swapping in component, service or unit for module is wrong, as is API or signature for interface, boundary for seam, and layer or wrapper for module.

Diagrams must be clear on their own. If yours needs an explanation paragraph, it's not clear yet — redraw it.

## Visual patterns to choose from

Pick the one that conveys your change most clearly. Mixing different types in one report prevents monotony.

**Dependency graph** — showing upstream/downstream relationships.
The workhorse for dependencies and call flow: X calls Y calls Z, and the mess shows. Render with Mermaid inside a styled card so it does not look pasted in. Leakage edges go red; the deep module is filled dark. For "before: 6 round-trips; after: 1", use a sequence diagram.

```html
<div class="rounded-lg border border-slate-200 bg-white p-4">
  <pre class="mermaid">
    flowchart LR
      A["Handler"] --> B["Validator"]
      B --> C["Repo"]
      C -.leak.-> D["PricingClient"]
      classDef leak stroke:#dc2626,stroke-width:2px;
      class C,D leak
  </pre>
</div>
```

**Drawn boundaries** — hand-built with divs and SVG lines.
Modules are bordered, labelled `<div>`s; arrows are inline SVG `<line>` or `<path>` elements placed absolutely over a relative container. Use it when the graph layout fights you, and when the after-state should read as a single heavy-outlined deep module whose internals are dimmed.

**Cross-section** — showing layered shallowness.
Stacked horizontal bands (`h-12 border-l-4`), one per layer a call crosses. Before: six thin bands, each doing nothing. After: one thick band carrying a label for the merged responsibility.

**Mass diagram** — for an interface as wide as its implementation.
Two rectangles per module: interface surface and implementation. Before: interface almost matches implementation in height (shallow). After: a short interface over a tall implementation (deep).

**Call-graph collapse** — consolidating a deep call hierarchy.
Before: calls drawn as boxes inside boxes. After: that tree folded into a single box, with the calls that became internal faded within.

## Design discipline

- Editorial in feel, never a corporate dashboard; plenty of whitespace.
- Spend color carefully: a single accent (emerald or indigo), red marks leakage, amber marks warnings.
- Hold diagrams near 320px high, so the before and after pair fits on screen unscrolled.
- Inside diagrams, render text as `text-xs uppercase tracking-wider` — it should look like an architectural sketch, not a live interface.
- Otherwise the report is static: it carries no app code and nothing interactive except what the diagram library itself renders.
- Escape special characters in file names and code paths (`&`, `<`, `>`, quotes). In Mermaid, wrap node labels: `A["name"]`.

## Bugs found on the way

A plain table after the cards, `path:line` in mono. No diagrams. None found → omit the section.

## Top recommendation section

One larger card, with an anchor link to the picked card.
