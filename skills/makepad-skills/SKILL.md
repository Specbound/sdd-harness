---
name: makepad-skills
description: Use when building or debugging a cross-platform Rust UI app with Makepad 2.0 — DSL/layout syntax, widgets, events, shaders, animation, theming, or migrating from Makepad 1.x. Indexes the 14 upstream `makepad-2.0-*` skills so you load the right one instead of guessing.
risk: safe
source: https://github.com/ZhangHanDong/makepad-skills
---

# Makepad Skills

## When to Use

Trigger on any Makepad 2.0 UI work: app scaffolding, the `script_mod!`/DSL syntax, layout (`Flow`/`Fill`/`Fit`/`Inset`), widget usage, event/action handling, shaders (`Sdf2d`, `DrawQuad`), animation states, theming, or a 1.x→2.0 migration. Not for Makepad 1.x work (including the Robius/MolyKit patterns) — those are archived on the upstream repo's `v1/makepad-1.0` branch and use different APIs.

## Install

Pick one, upstream repo is a skill pack, not a single skill:

```bash
# Option 1: working directory (no copy, tracks upstream)
# add to .claude/settings.json:
#   "additionalWorkingDirectories": ["/path/to/makepad-skills"]

# Option 2: symlink each sub-skill into ~/.claude/skills/
for skill in skills/*; do
    ln -sf "$(pwd)/$skill" ~/.claude/skills/
done

# Option 3: copy (no auto-update)
cp -r skills/* ~/.claude/skills/
```

## Topic Index (14 upstream skills)

Load `makepad-2.0-design-judgment` first — it's the upstream repo's stated entry point (Elm Architecture, Presentational/Container split, GPU-rendering mental model) — then co-load whichever of the rest matches the task:

| Skill | Covers |
|-------|--------|
| `makepad-2.0-design-judgment` | **Entry point.** Architecture anchors — load before the others |
| `makepad-2.0-app-structure` | `app_main!`, ScriptVm, Cargo setup, hot reload |
| `makepad-2.0-dsl` | DSL syntax, `script_mod!`, colon syntax, `mod.widgets`, let bindings |
| `makepad-2.0-layout` | Layout system: `Flow`, `Fill`, `Fit`, `Inset`, spacing, alignment |
| `makepad-2.0-widgets` | Widget catalog: `View`, `Button`, `Label`, `TextInput`, `PortalList`, `Dock`, etc. |
| `makepad-2.0-events` | Event/action handling: `on_click`, `on_render`, `Hit`, `ids!` |
| `makepad-2.0-animation` | Animator, states, Forward/Snap/Loop, ease functions |
| `makepad-2.0-shaders` | Shader system: `draw_bg`, `Sdf2d`, pixel/vertex fn, `DrawQuad` |
| `makepad-2.0-splash` | Splash scripting language, streaming evaluation, hot reload |
| `makepad-2.0-theme` | Theme system: `mod.themes`, colors, fonts, dark/light mode |
| `makepad-2.0-vector` | Vector graphics: SVG paths, gradients, tweens, `DropShadow` |
| `makepad-2.0-performance` | Perf: GC, draw batching, `ViewOptimize` |
| `makepad-2.0-troubleshooting` | Common mistakes, FAQ, debugging |
| `makepad-2.0-migration` | 1.x → 2.0 migration guide |

## Anti-Patterns

- Loading a specific sub-skill (e.g. `makepad-2.0-shaders`) without `makepad-2.0-design-judgment` first on unfamiliar code — the entry-point skill's architecture anchors are what make the topic-specific syntax make sense
- Applying this index's guidance to a Makepad 1.x codebase — 1.x and 2.0 have different DSL and widget APIs; use the archived `v1/makepad-1.0` branch content instead

## Verification Note

This index's table is drawn from the upstream repo's own README topic list — the per-skill file bodies (the actual DSL/API reference content inside each `makepad-2.0-*` skill) weren't independently fetched or verified this session. Install one of the three ways above to get the real per-topic content; treat this file as a router, not a substitute for the underlying skills.
