# HTML Report Format

The page is not self-contained: Tailwind and Mermaid come from CDNs, which means outside scripts execute on a page containing repo paths and source code. Mermaid suits graph-shaped diagrams; hand-built divs and inline SVG suit the more editorial ones (mass diagrams, cross-sections). Mermaid everywhere looks generic.

When the network is locked down, offline, or the user wants no third-party script, skip both CDNs: embed the CSS and draw the diagrams as SVG by hand. The six candidate card fields must read with no script at all. Either way, fonts are the CSS stacks in "Building the page" and never another face.

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

Title with the repo name and scan date, followed by a key: a box symbol = module, dashed line = seam, red line = leakage, dark fill = deep module. Jump straight into the candidate cards. No introduction section.

## Candidate card

Render each candidate as its own `<article>` element, one per deepening it proposes. The diagram is the main argument; text should be sparse and exact.

Every candidate card contains exactly six fields:

- **Files** — a monospaced list, `font-mono text-sm`.
- **Problem** — one sentence.
- **Solution** — one sentence.
- **Benefits** — short bullets (≤6 words), phrased as locality and leverage wins: "one interface to test", "pricing no longer leaks", "4 shallow wrappers removed".
- **Before / After** — the centrepiece: a left column and a right column, drawn with the patterns below.
- **Strength** — a badge: `Strong` (emerald), `Worth exploring` (amber), or `Speculative` (slate).

Prose takes its architectural terms from the explorer-lens Vocabulary. Swapping in component, service or unit for module is wrong, as is API or signature for interface, boundary for seam, and layer or wrapper for module.

Diagrams must be clear on their own. If yours needs an explanation paragraph, it's not clear yet — redraw it.

## Visual patterns to choose from

Per candidate card, pick the pattern that shows its change best, and vary patterns across the report; identical diagrams hide what differs between candidates.

**Dependency graph**

Use it for call flow and upstream/downstream links. Render with Mermaid inside a styled container that matches the card. Leakage edges go red; the deep module is filled dark. For "before: 6 round-trips; after: 1", use a sequence diagram.

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

**Drawn boundaries**

Use it when a graph layout fights you, or the after-state is one heavy-outlined deep module with dimmed internals. Modules are bordered, labelled `<div>`s; arrows are inline SVG `<line>` or `<path>` elements, absolutely positioned over a `position: relative` container.

**Cross-section**

Use it for layered shallowness: horizontal bands (`h-12 border-l-4`), one per layer a call crosses. Before: six thin bands. After: one thick band labelled with the merged responsibility.

**Mass diagram**

Use it when an interface is nearly as wide as its implementation: two rectangles per module, interface and implementation. Before: similar heights (shallow). After: a short interface over a tall implementation (deep).

**Call-graph collapse**

Use it when a deep call hierarchy is consolidated. Before: boxes inside boxes. After: one box, the now-internal calls faded within.

## Design discipline

- Editorial in feel, never a corporate dashboard; plenty of whitespace.
- Spend color carefully: a single accent (emerald or indigo), red marks leakage, amber marks warnings.
- Hold diagrams near 320px high, so the before and after pair fits on screen unscrolled.
- Inside diagrams, render text as `text-xs uppercase tracking-wider` — it should look like an architectural sketch, not a live interface.
- Otherwise the report is static: it carries no app code and nothing interactive except what the diagram library itself renders.
- HTML-escape all repo text you quote into the page (paths, identifiers, code snippets) before it enters the page (`&`, `<`, `>`, quotes), because third-party scripts load there. In Mermaid, wrap node labels: `A["name"]`.

## Bugs found on the way

A plain table after the cards, `path:line` in mono. No diagrams. None found → omit the section.

## Top recommendation section

One larger card, with an anchor link to the picked card.
