---
name: tool-design
description: "Use when designing or reviewing agent/MCP tool interfaces: writing tool descriptions, deciding whether to consolidate or split tools, capping/formatting tool output, or bridging an existing CLI for agent use."
---

# Tool Design for Agents

Tools are the contract between deterministic systems and non-deterministic agents. Agents
never see your code — only the schema and description — so every ambiguity there becomes a
failure mode no prompt engineering fixes downstream.

## Core Principles

- **Tools are contracts.** Humans infer API contracts from docs; agents must infer them
  entirely from the description. Ambiguity that a human shrugs off becomes a wrong call.
- **Descriptions are prompts.** They're loaded into context and steer behavior, not just
  document it. Answer four questions: what it does, when to use it, what inputs it takes,
  what it returns.
- **Consolidation principle.** If a human engineer can't definitively say which tool applies
  in a given situation, an agent can't either. Prefer one comprehensive tool
  (`schedule_event`: finds availability + books) over a chain of narrow ones
  (`list_users` + `list_events` + `create_event`). Each extra tool costs context-budget
  tokens and adds selection ambiguity even when unused.
- **When not to consolidate:** tools with fundamentally different behaviors, tools used in
  different contexts, or tools that might legitimately be called independently.
- **"Bash gravity."** As a tool collection grows, routing collapses toward the most general
  tool available — it's never *wrong*, only worse, so specific tools silently lose traffic
  to it. Counter this in the description itself (see Six-Section Skeleton below), not by
  hoping agents pick the narrow tool unprompted.

## Architectural Reduction

Taken to its extreme, consolidation argues for removing specialized tools in favor of a
single primitive (e.g. one `execute_command` sandbox tool, agent drives `grep`/`cat`/`find`
over well-documented files) instead of a bespoke tool per operation. Production case: a
17-tool text-to-SQL agent reduced to 2 primitives ran 3.5x faster, 100% vs 80% success, 37%
fewer tokens — see `references/architectural_reduction.md` for the full comparison.

**Reduction wins when:** the data layer is well-documented and consistent, the model has
enough reasoning capacity to navigate it unaided, and specialized tools were constraining
more than enabling.

**Reduction fails when:** data is messy/undocumented, the domain needs knowledge the model
lacks, safety requires hard limits on what the agent can do, or workflows are genuinely
multi-step and benefit from enforced structure.

**Ask before adding a guardrail tool:** is this enabling a new capability, or constraining
reasoning the model could already do? Guardrails become maintenance liabilities as models
improve — build for the model the project will have in a year, not just today's.

## Writing Tool Descriptions: The Six-Section Skeleton

1. **Opening line** — the job, and what it returns. One sentence.
2. **WHEN TO USE** — direct triggers and indirect signals.
3. **WHEN NOT TO USE** — soft boundary: "prefer `<other tool>` for X."
4. **DO NOT USE FOR** — hard boundary: "never use this for Y."
5. **USAGE** — parameters, constraints, defaults.
6. **EXAMPLES** — 2-3, including at least one near-miss the tool should decline.

Sections 3 and 4 deliberately overlap — a soft handoff tells the model where to go instead;
a hard prohibition holds when the request is ambiguous and the soft version bends. Smaller
models drop the soft boundary under ambiguity; mid-tier models gain measurably from the
restatement; the largest models are unaffected either way (not harmed). The repetition
costs nothing where unneeded and rescues routing where it is. Phrase section 4 as a
prohibition on *this* tool, not a recommendation of another — "prefer X" loses to bash
gravity, "never use this for Y" does not.

Long descriptions are cheap — they're cached in the system prompt, paid once per session
not per call. Optimize whether the boundary is unmissable, not description length.

**Verify by per-section ablation, not by reading.** A description you wrote always reads as
clear to you. Hold three fixed probe prompts (one search-shaped, one file-shaped, one
shell-shaped) and strip one section at a time (EXAMPLES, then DO NOT USE FOR, then USAGE),
re-running all three after each removal. The section whose removal first collapses routing
is the one doing the work; sections you can remove with no effect are dead text.

## Naming and Parameters

- Self-documenting parameter names: `customer_id`, `max_results`, `include_history` — never
  `x`, `val`, `param1`, `info`.
- Consistent terms across tools for the same concept (`customer_id` everywhere, not
  `id`/`identifier`/`customer_id` mixed).
- Boolean-style options: `include_` for affirmative, `exclude_` for negative.
- **MCP tools: always use fully-qualified names** (`ServerName:tool_name`) in descriptions
  and cross-references — unqualified names fail to resolve when multiple servers are
  active: `"Use the BigQuery:bigquery_schema tool..."` not `"Use the bigquery_schema
  tool..."`.

## Response Format and Output Caps

Give agents a verbosity choice (`format: "concise" | "detailed"`) — concise for
confirmation/basic info, detailed when the full object drives a downstream decision.

Format options only help when the agent chooses well. **Caps protect the context window
when it doesn't** — an unbounded result is one bad call from evicting the rest of the
session. Three parts, all required:

1. **Cap it.** Working defaults: ~500 lines for a file read, ~50 matches for a search,
   ~5000 characters for command output.
2. **Announce the cut and the true total.** `showing first 50 of 1,284 matches`, never a
   silently shortened list — silent truncation is worse than none, because the model
   believes it has the full picture and will confidently conclude "no other call sites
   exist" from a list cut at 50.
3. **Offer the continuation** — offset, page, or filter. A cap with no way past it is a
   dead end.

**Keep the tail, not the head, for command output** — failures put their signal last (stack
trace, assertion, exit line); `stdout[:MAX]` keeps the build banner and throws away the
reason it failed. Listings are the opposite: keep the head.

Four bounded reads cost more calls than one dump and are still the better trade — the
dump's cost isn't paid at the call, it's paid by every later turn that carries it.

## Error Message Design

Error messages serve agents recovering, not just developers debugging — they must be
actionable. Retryable errors need retry guidance; input errors need the corrected format;
missing-data errors need what's actually required. Example shape:

```json
{"error": "INVALID_CUSTOMER_ID", "message": "Customer ID 'CUST-123' does not match format",
 "expected_format": "CUST-######", "resolution": "Provide ID matching CUST-######",
 "retryable": true}
```

## Agent-Facing API Design Checklist

Agent APIs invert human-API conventions: agents read full docs in one pass and pay no
readability tax for verbosity, so human-typing-saving conventions just add ambiguity here.

1. **Explicit over defaults** — require explicit parameters rather than hidden "sensible
   defaults"; a default an agent didn't choose is ambiguity about what actually happened.
2. **Strict errors over lenient coercion** — don't silently coerce malformed input; a
   precise error is a signal the agent can act on, silent coercion is not.
3. **Specific field names** — `displayName`/`slug`/`externalId` over generic `name`/`id`,
   to cut the odds of hallucinated or confused field meaning.
4. **Facts not utilities** — expose raw primitives (e.g. a raw `exec()`) over
   convenience-wrapped SDK utilities; let the agent compose its own abstraction rather than
   being boxed into someone else's.

## Tool Collection Design

10-20 tools is a reasonable ceiling for most applications — beyond that, namespace into
logical groups (`db:query`, `web:search`) rather than flattening everything. Tool
description overlap measurably causes selection confusion; shrinking the effective set
beats adding more disambiguating text.

## CLI-to-Agent Bridging

When exposing an existing CLI to agents, **keep the argument-based interface** — do not
rewrite to JSON payloads. Tested across Haiku 4.5 / Sonnet 4.6, multiple shells (Microsoft
Developer Blog, 2025):

| Metric | Args | JSON |
|---|---|---|
| Correctness | 100% all models | Degrades on smaller models (Haiku 4.5: 40%) |
| Token cost | Baseline | 4x-11x more per task |
| Shell portability | Consistent | Escaping creates a 9x cost gap (PowerShell vs Bash) |

Args constrain the input space, which eliminates JSON syntax/nesting/escaping errors —
narrowing valid inputs compensates for model capability gaps that JSON exposes.

**Minimal intervention, not a rewrite** — if a CLI needs agent-friendliness work, this
covers ~90% of the friction:
1. Meaningful, consistent exit codes (0 / non-0).
2. A `--quiet`/`--no-color` flag suppressing progress bars and ANSI decoration that breaks
   parsing.
3. An *additive* `--json` flag for structured output — never remove the default arg
   interface, never force JSON-first.

## Intent-vs-Compiler: Emit Intent, Derive Config

When a tool needs verbose low-level configuration, don't make the model hand-write it. Have
it emit terse **intent** + **semantic types**, and let deterministic code (the "compiler")
derive the fragile parameters — scales, formatting, layout, defaults. Worked example
(charts): the model annotates fields by semantic type (temporal/quantitative/categorical)
and states `date -> x, revenue -> y, region -> color`; the compiler derives axis scales,
tick formatting, palette, and legend placement. None of that touches the model.

**Decision rule:** if a parameter is (a) mechanically derivable from the data or a semantic
type, and (b) a frequent source of malformed output, move it into the compiler, not the
tool schema. This is the consolidation principle applied to *parameters* — fewer fragile
fields the model authors, fewer ways it can fail. Generalizes to query tools (model emits
`{metric, dimension, filter-intent}`, compiler builds SQL), UI tools (model emits component
roles, compiler resolves spacing/theming), infra tools (model emits the goal, compiler
derives ports/security groups).

## Advanced Tool Use Patterns

Three techniques for high-scale tool systems (Anthropic Engineering, 2025). Enable via
`betas=["advanced-tool-use-2025-11-20"]`. Apply after the base design above is solid.

- **Tool Search (deferred discovery).** Past ~10K tokens of tool definitions, mark tools
  `defer_loading: true` and provide a search tool as the always-loaded core; Claude searches
  for capabilities instead of loading everything upfront. 85% token reduction on
  definition-heavy MCP setups; Opus 4.5 MCP eval accuracy 79.5% -> 88.1%. Deferred tools are
  excluded from the initial prompt, so this does not break prompt caching. Use at 10+ tools
  or >10K definition tokens; keep the 3-5 most-used tools always loaded.
- **Programmatic Tool Calling.** Mark tools `allowed_callers: ["code_execution_20250825"]`
  so Claude writes orchestration code instead of one tool-call-per-turn; intermediate
  results stay in the code executor, not context. 37% token reduction on a 20-tool workflow,
  eliminates 19+ inference passes on sequential chains, enables real parallel calls via
  `asyncio.gather()`. Use at 3+ dependent calls, large intermediate data, or
  loops/conditionals.
- **Usage examples in tool definitions.** 1-5 realistic JSON examples (minimal / partial /
  full) covering ambiguous parameter combinations, with real data not placeholders. 72% ->
  90% accuracy on complex parameter handling.

Pick by bottleneck: context bloat -> Tool Search; intermediate data -> Programmatic Calling;
parameter errors -> Usage Examples. Add progressively, not all at once.

## Using Agents to Improve Tools

Claude can diagnose its own tool failures: feed it the tool spec plus observed failure
examples and ask why agents are failing, what's missing from the description, and what
ambiguity causes misuse — then test the revised description against the same failure cases.
Production testing shows ~40% reduction in task completion time from this feedback loop.

## Checklist Before Shipping a Tool

- Description states what/when/inputs/returns without vague verbs ("helps with", "handle").
- Parameters are self-documenting; no `x`/`val`/`param1`.
- Errors are structured and actionable, not generic.
- Output is capped, the cut is announced with a true total, and a continuation path exists.
- Naming is consistent with the rest of the tool collection.
- Tested against representative agent requests, not just read for clarity.
- Asked: does this tool enable a new capability, or constrain reasoning the model already
  has?
