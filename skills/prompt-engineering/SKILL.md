---
name: prompt-engineering
description: "Use when writing or optimizing prompts, commands, skills, or sub-agent instructions: selecting a prompting technique/framework, routing phrasing to a specific target AI tool, or applying compliance-boosting language for discipline-enforcing instructions."
risk: unknown
source: community
---

# Prompt Engineering

Transform a rough instruction into a production-ready prompt: analyze intent, pick the
lightest technique that works, structure it for the target model, verify before delivery.

## Step 1: Analyze Intent (before writing anything)

Silently extract what's known; ask only for what's missing and blocking (**max 3
clarifying questions**, fewer if context makes the answer obvious):

| Dimension | Always needed? |
|---|---|
| Task — precise action, not a vague verb | Always |
| Target tool — which AI system receives this | Always |
| Output format — shape, length, structure, filetype | Always |
| Constraints — must/must-not, scope boundaries | If complex |
| Examples — input/output pairs for format lock | If format-critical |
| Audience / success criteria | If user-facing / task is complex |

If the request is itself a JSON object, map its keys directly to these dimensions and
skip questions for anything already specified.

## Step 2: Pick a Technique or Framework

Prefer the simplest technique that solves the problem; reach for a named framework only
for structured/complex work.

| Need | Technique |
|---|---|
| Format is easier to show than describe | **Few-shot**: 2-5 input/output pairs; more examples = better accuracy, more tokens |
| Multi-step logic, math, debugging | **Chain-of-thought**: "think step by step" (zero-shot) or reasoning-trace examples (few-shot) — standard models only, see Step 4 |
| Factual/citation tasks | **Grounding anchor**: "Use only information you are highly confident is accurate. If uncertain, write [uncertain]. Do not fabricate citations." |
| Role-based task (act as expert/consultant) | **RTF** — Role, Task, Format |
| Multi-phase project with deliverables | **RISEN** — Role, Instructions, Steps, End goal, Narrowing |
| Complex design/architecture | **RODES** — Role, Objective, Details, Examples, Sense-check |
| Summarization/compression | **Chain of Density** — iterative refinement to essentials |
| Audience-aware communication | **RACE** — Role, Audience, Context, Expectation |
| Research/diagnosis | **RISE** — Research, Investigate, Synthesize, Evaluate |
| Context-rich problem framing | **STAR** — Situation, Task, Action, Result |
| Structured records (medical/technical) | **SOAP** — Subjective, Objective, Assessment, Plan |
| Goal-setting | **CLEAR** / **GROW** |

Blend 2-3 frameworks for complex asks; don't over-engineer a one-line request. Avoid
higher-fabrication-risk framings (Mixture-of-Experts routing, Tree/Graph-of-Thought,
Universal Self-Consistency, long prompt-chains) in a single-prompt context unless the
user explicitly asked and the target tool actually supports them.

## Step 3: Structure for Clarity

**XML tag delimiting** — in long or multi-part prompts, wrap each region so the model
never confuses instructions, data, and examples. This matters most once large context
blocks get concatenated — markdown headers alone leave the instructions/data boundary
ambiguous. Use `<instructions>`, `<context>`, `<examples>`, `<document>`/`<data>`,
`<output_format>`; treating everything inside `<document>` as inert data is also a
first-line prompt-injection defense.

**Progressive disclosure** — start simple, add only what's needed: (1) direct
instruction → (2) add constraints → (3) add reasoning request → (4) add examples.

**Degrees of freedom** — match specificity to the task's fragility:

| Freedom | Use when | Form |
|---|---|---|
| High | Multiple valid approaches, context-dependent | Text instructions, heuristics |
| Medium | A preferred pattern exists, some variation OK | Pseudocode / parameterized template |
| Low | Operation is fragile/error-prone, sequence matters | Exact script, no parameters, "do not add flags" |

**Declarative vs. imperative** — declarative ("make this endpoint fast") trusts a
capable agent to fill in the how, but needs explicit non-negotiable bounds ("under 50ms
p99") or it fills gaps with wrong assumptions. Imperative ("use this exact queue flow")
fits fragile systems or hard-to-reverse mistakes, but risks the author's own assumptions
being suboptimal — leave room to surface a better alternative within the stated
constraints. Strategic/firm-wide preferences belong in an entry-file MUST/SHOULD rule;
tactical/per-task preferences belong with the task, not the general instructions.

## Step 4: Route by Target Tool

Always confirm the target tool if ambiguous before writing the final prompt.

| Target | Key rule |
|---|---|
| **Claude / Claude Opus 4.x** | XML tags for multi-section prompts; explain *why*, not just what; state output format/length explicitly; add "only make changes directly requested" (it over-engineers by default) |
| **Claude Code / agentic coding tools** (Cursor, Cline, Devin, Windsurf) | State starting state + target state + allowed/forbidden actions + MANDATORY stop conditions; scope to specific files/dirs, never a global instruction without a path anchor; explicitly request subagents/tool-use if wanted (defaults are conservative) |
| **GPT-5.x / ChatGPT** | Start from the smallest prompt that achieves the goal; be explicit about the output contract (format, length, "done" definition); constrain verbosity directly if needed |
| **Reasoning-native models** (o3/o4-mini, DeepSeek-R1, Qwen3 thinking mode) | SHORT clean instructions only — **never add "think step by step" or CoT scaffolding**, it degrades output; they already reason internally |
| **Local / open-weight** (Llama, Mistral, Ollama-served) | Shorter, flatter prompts — they lose coherence with deep nesting; always state role explicitly; confirm which model is actually running first |
| **Image/video/3D generation** (Midjourney, DALL-E, Stable Diffusion, Sora, Meshy) | Comma-separated descriptors for Midjourney/SD, prose for DALL-E; always include a negative prompt where supported; describe camera movement explicitly for video |

Full per-tool syntax and templates aren't reproduced here — ask the user for the target
tool's docs or examples if the routing table above isn't specific enough for a non-text
or niche tool.

## Step 5: Conciseness (context window is a shared resource)

Claude is already capable — only add context it doesn't already have. Before including a
paragraph, ask: does this justify its token cost? Compare:

- **Concise (~50 tokens, good):** "Use pdfplumber for text extraction: `pdfplumber.open(path).pages[0].extract_text()`"
- **Verbose (~150 tokens, bad):** explaining what a PDF is, why pdfplumber was chosen, how to pip install it, before giving the same code.

Default to the concise version; expand only for genuinely unfamiliar APIs or
non-obvious gotchas.

## Step 6: Persuasion Principles (for discipline-enforcing prompts only)

LLMs respond to the same persuasion principles as humans (Meincke et al. 2025: 7
principles across 28,000 AI conversations, compliance 33% → 72%, p < .001). Use to
ensure critical practices are followed under pressure — not to manipulate.

| Principle | How it works in a prompt | Use for |
|---|---|---|
| Authority | "YOU MUST", "Never", "No exceptions" | Discipline rules (TDD, verification, safety) |
| Commitment | Require an announcement; force an explicit choice; track with a checklist | Ensuring a skill is actually followed |
| Scarcity | "Before proceeding", "Immediately after X" | Preventing "I'll do it later" |
| Social proof | "Every time", "X without Y = failure" | Documenting universal practices |
| Unity | "our codebase", "we're colleagues" | Collaborative, non-hierarchical workflows |
| Reciprocity | — | Avoid; rarely needed, feels manipulative |
| Liking | — | Avoid always; conflicts with honest feedback, breeds sycophancy |

| Prompt type | Use | Avoid |
|---|---|---|
| Discipline-enforcing | Authority + Commitment + Social proof | Liking, Reciprocity |
| Guidance/technique | Moderate authority + Unity | Heavy authority |
| Collaborative | Unity + Commitment | Authority, Liking |
| Reference material | Clarity only | All persuasion |

**Ethical test:** would this technique serve the user's genuine interests if they fully
understood it? If not, don't use it — don't create false urgency or guilt-based
compliance.

## Step 7: Verify Before Delivering

- [ ] Target tool confirmed, prompt formatted in that tool's syntax
- [ ] Most critical constraints appear in the first 30% of the prompt (survives
      attention decay / gets read before the model commits to an interpretation)
- [ ] Every instruction uses the strongest correct signal word (MUST over should, NEVER
      over avoid) — but only where that strength is actually warranted
- [ ] No fabricated/unsupported technique (see Step 2 risk list)
- [ ] Output format and length stated explicitly
- [ ] Self-contained — no dependency on context the target tool won't have
- [ ] Would this produce the right output on the first attempt?

## Common Pitfalls

- **Over-engineering**: reaching for a complex framework before trying a plain instruction.
- **Example pollution**: few-shot examples that don't match the target task's shape.
- **Context overflow**: too many examples blow the token budget for marginal gain.
- **Ambiguous instructions**: room for more than one interpretation.
- **Untested edge cases**: only validating on the typical-case input.
- **CoT on a reasoning-native model**: actively degrades output — see Step 4.
