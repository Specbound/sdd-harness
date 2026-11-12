---
name: diagram-design
description: Generate branded, editorial-quality diagrams (HTML+SVG) styled from a target site's colors/fonts, instead of generic Mermaid boxes-and-arrows. Use when a user wants a diagram that will be published, embedded in a deck, or shown to an external audience.
source: "cathrynlavery/diagram-design (github.com/cathrynlavery/diagram-design)"
---

# Diagram Design

`mermaid-expert` covers syntax-correct flowcharts/sequence diagrams for internal docs. This skill is for the other case: a diagram that needs to look like it belongs on a company's website or in a published post — branded colors, real typography, editorial layout — not a generic Mermaid render.

## When to Use

- User wants a diagram to publish, embed in a deck, or show an external audience
- User names a brand/site whose visual style the diagram should match
- A Mermaid/plain-flowchart output already exists but reads as generic "AI diagram slop" and needs a redesign pass

## Do Not Use When

- The diagram is for internal engineering docs only, and semantic correctness (not visual polish) is the priority → use `mermaid-expert` instead
- No specific brand/style target exists and the user hasn't asked for editorial polish

## Workflow

1. **Get the style source.** If the user names a site/brand, fetch its CSS (WebFetch or `curl`) and extract: primary/accent color hex values, font-family stack, corner-radius/shadow conventions.
2. **Get the content.** Accept input from any of: a plain description, an existing Mermaid diagram, a draw.io/Excalidraw export, or a rough ASCII sketch. Normalize it into a node/edge list before styling.
3. **Build as HTML+SVG**, not a Mermaid render. SVG for node shapes/connectors, HTML+CSS for text and brand styling (real font rendering, not SVG `<text>` fallback fonts). Structure:
   - Nodes: styled `<div>`s positioned absolutely or via CSS grid, corner-radius and color pulled from the extracted style
   - Edges: SVG `<path>` with arrowhead markers, colored to match the brand's accent
   - Layout: compute manually for small graphs (≤10 nodes); for larger graphs, run a layout pass (e.g. dagre) first, then re-skin the output
4. **Validate before shipping:**
   - No overlapping nodes/edges (bounding-box check)
   - Every edge connects two real nodes (no dangling arrows)
   - Contrast check: text color against node background meets readable contrast
5. **Export.** Render to a static PNG/SVG file the user can drop into a doc or deck; keep the HTML source alongside it for future edits.

## Anti-Pattern: "Mermaid Slop"

Generic auto-diagram output — flat boxes, one default font, no visual hierarchy, uniform arrow style regardless of relationship type — reads as machine-generated at a glance. This skill exists specifically to avoid that outcome for anything that will be seen outside the team. If a diagram doesn't need to clear that bar, don't reach for this skill; use `mermaid-expert` and move on.

## Related

- `mermaid-expert` — syntax-correct internal diagrams, no branding work
