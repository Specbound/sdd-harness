---
name: wiki
description: Generate a browsable project wiki from a codebase — structure catalogue, deep research, page writing, onboarding guides, changelog, Q&A, and a VitePress site build. Use when asked to build or update a wiki, document a repo end-to-end, or answer grounded questions about one.
---

## When to use
Building a full project wiki (or one phase of it) from source code. Pick the phase below that matches the request — they chain in order but each also works standalone (e.g. "answer a question about this repo" only needs the Q&A phase).

**Don't use for:** a single README, API reference, or tutorial with no wiki/site output — use the documentation skill for those.

## Evidence standard (applies to every phase)
Every non-trivial claim needs a source citation `(file_path:line_number)`. Trace actual code — do not guess from file names or conventions, do not say "this likely handles..." without reading it. Distinguish fact from inference explicitly ("I read this" vs "I'm inferring because..."). If evidence is missing, write `(Unknown – verify in path/to/check)` rather than inventing it.

## Phase 1: Architecture catalogue

Produce a JSON catalogue describing the wiki's hierarchical structure before writing any pages.

- Detect the primary language/stack from build files (`package.json`/`tsconfig.json` → TS/JS, `*.csproj`/`*.sln` → .NET, `Cargo.toml` → Rust, `pyproject.toml`/`requirements.txt` → Python, `go.mod` → Go, `pom.xml`/`build.gradle` → Java) — drives which code examples and comparison framing to use throughout.
- Structural limits: max section depth 4, max 8 children per section. Repos with ≤10 files get a Getting-Started-only catalogue — don't over-structure a small repo.
- The catalogue **must** include an Onboarding section (see Phase 4) — it is not optional.
- Each catalogue node maps to one output page in Phase 3.

## Phase 2: Research (deep dives)

For topics that need more than a page-writer pass — "how does X work," architecture questions spanning many files, pattern/anti-pattern investigation. Five iterations, each building on prior findings, never repeating one:

1. **Structural** — map components, entry points
2. **Data flow / state** — trace data through the system
3. **Integration / dependencies** — external connections, API contracts
4. **Patterns / anti-patterns** — design patterns, trade-offs, technical debt
5. **Synthesis** — combine findings into actionable recommendations

Per finding: state it in one sentence → show evidence (file paths, call chains) → explain why it matters → rate confidence (HIGH = read the code, MEDIUM = read some/inferred rest, LOW = inferred from structure only) → flag what's still unexplored. Follow call chains all the way down (A calls B calls C → trace to C, don't stop at B).

| Claim | Required evidence |
|---|---|
| "X calls Y" | file path + function name |
| "Data flows through Z" | entry point → transformations → destination, traced |
| "This is the main entry point" | where it's invoked (config, main, route registration) |
| "These modules are coupled" | import/dependency chain |
| "This is dead code" | show no call sites exist |

## Phase 3: Page writing

One page per catalogue node. Required frontmatter on every page:
```yaml
---
title: "Page Title"
description: "One-line description"
---
```
Structure: Overview (explain WHY it exists, not just what) → Architecture → Components → Data Flow → Implementation → References. Use tables for APIs/configs/component summaries and for technology comparisons. Minimum 5 distinct source files cited per page.

**Mermaid diagrams** — minimum 2 per page, dark-mode colors (mandatory): node fill `#2d333b`, border `#6d5dfc`, text `#e6edf3`; subgraph background `#161b22`, border `#30363d`, lines `#8b949e`. Use `autonumber` in `sequenceDiagram` blocks. Pick the right type: `graph`/`flowchart` for structure, `sequenceDiagram` for interactions, `classDiagram` for type relationships, `stateDiagram-v2`/`erDiagram` where they fit better than a generic flowchart.

**VitePress compatibility gotchas:** never use `<br/>` in Mermaid blocks (use `<br>`); escape bare generics outside code fences (`` `List<T>` ``, not bare `List<T>`); hex colors must be 3 or 6 digits.

## Phase 4: Onboarding guides

Generate two complementary documents — don't collapse them into one, the audiences and depth differ.

| | Principal-Level Guide | Zero-to-Hero Guide |
|---|---|---|
| Audience | Senior/staff+ engineers, wants "why" | New contributors, wants "how" |
| Sections | System philosophy & invariants, architecture overview (+Mermaid), key abstractions, decision log (alternatives/trade-offs), dependency rationale, data flow & state, failure modes, performance characteristics, security model, testing strategy, operational concerns, known technical debt | Elevator pitch, prerequisites, environment setup (exact commands + expected output), annotated project structure, first task walkthrough, dev workflow (branching/commits/PRs), running tests, debugging guide, key concepts/terminology, code patterns ("to add X, follow this"), common pitfalls, where to get help, glossary, quick-reference cheat sheet |
| Rules | ≥3 Mermaid diagrams (architecture, data flow, dependency graph); every claim cited | all code examples in detected primary language; every command copy-pasteable with expected output shown |

Both guides: ground every claim in actual code, cite `(file_path:line_number)`, dark-mode Mermaid colors as in Phase 3.

## Phase 5: Q&A

Answering a specific question about the repo, grounded only in source.

1. Detect the question's language, respond in the same language.
2. Search the codebase for relevant files, read them for evidence.
3. Synthesize an answer with inline citations `(src/path/file.ts:42)`.
4. Include a "Key Files" table mapping files to their role.

Never invent, guess, or fall back to general/external knowledge — if the repo doesn't answer it, say so and point to what to examine next.

## Phase 6: Changelog

Generate from git history, not from memory of what changed.

1. Walk `git log`, group entries by time period (daily or weekly, whichever gives readable chunks).
2. Classify each commit into one category: 🆕 Features, 🐛 Fixes, 🔄 Refactoring, 📝 Docs, 🔧 Config, 📦 Dependencies, ⚠️ Breaking.
3. Write user-facing descriptions in the project's own terminology, not raw commit messages.
4. Merge related commits into one entry instead of listing each separately.
5. Breaking changes always get a migration note, not just the ⚠️ tag.

## Phase 7: VitePress site build

Package generated pages into a static site, dark theme only.

```
wiki-site/
├── .vitepress/
│   ├── config.mts
│   └── theme/{index.ts, custom.css}
├── public/
├── [generated .md pages]
├── package.json
└── index.md
```

`config.mts`: wrap with `withMermaid` (`vitepress-plugin-mermaid`), set `appearance: 'dark'`, populate `themeConfig.nav`/`sidebar` from the Phase 1 catalogue. Mermaid theme variables: `primaryColor:#1e3a5f, primaryTextColor:#e0e0e0, primaryBorderColor:#4a9eed, lineColor:#4a9eed, background:#1a1a2e, mainBkg:#1e3a5f, nodeBorder:#4a9eed, clusterBkg:#16213e`.

**Dark-mode Mermaid needs all three layers, not one:**
1. `themeVariables` in `config.mts` (above)
2. CSS overrides in `custom.css` targeting `.mermaid .node rect/circle/polygon`, `.edgeLabel`, `text` with `!important` — theme variables alone don't win against Mermaid's inline styles
3. Runtime fix in `theme/index.ts`: Mermaid sets inline `style` attributes after async render, so poll in `setup()` + `onMounted()` (not `enhanceApp()` — `document` doesn't exist during SSR) and overwrite `fill`/`stroke`/`color` on `.mermaid svg [style]` elements for ~20 attempts at 500ms intervals.

Click-to-zoom: wrap each `.mermaid` container, on click clone it into a fixed-position modal (`rgba(0,0,0,0.9)` backdrop, `scale(1.5)`), remove on click-away.

Before build, post-process all `.md`: `<br/>` → `<br>`, bare `<T>` generics wrapped in backticks, every page has `title` + `description` frontmatter.

```bash
cd wiki-site && npm install && npm run docs:build
# output: wiki-site/.vitepress/dist/
```

**Gotchas:** Mermaid renders async — SVGs don't exist yet when `onMounted` first fires, must poll. Vue's `isCustomElement` compiler option makes bare `<T>` crash harder — don't set it. Node text uses inline `style` with max specificity — CSS alone won't override it, you need the Layer 3 runtime fix.
