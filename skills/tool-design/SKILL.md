---
name: tool-design
description: This skill should be used when the user asks to "design agent tools", "create tool descriptions", "reduce tool complexity", "implement MCP tools", or mentions tool consolidation, architectural reduction, tool naming conventions, or agent-tool interfaces.
---

# Tool Design for Agents

Tools are the primary mechanism through which agents interact with the world. They define the contract between deterministic systems and non-deterministic agents. Unlike traditional software APIs designed for developers, tool APIs must be designed for language models that reason about intent, infer parameter values, and generate calls from natural language requests. Poor tool design creates failure modes that no amount of prompt engineering can fix. Effective tool design follows specific principles that account for how agents perceive and use tools.

## When to Activate

Activate this skill when:
- Creating new tools for agent systems
- Debugging tool-related failures or misuse
- Optimizing existing tool sets for better agent performance
- Designing tool APIs from scratch
- Evaluating third-party tools for agent integration
- Standardizing tool conventions across a codebase

## Core Concepts

Tools are contracts between deterministic systems and non-deterministic agents. The consolidation principle states that if a human engineer cannot definitively say which tool should be used in a given situation, an agent cannot be expected to do better. Effective tool descriptions are prompt engineering that shapes agent behavior.

Key principles include: clear descriptions that answer what, when, and what returns; response formats that balance completeness and token efficiency; error messages that enable recovery; and consistent conventions that reduce cognitive load.

## Detailed Topics

### The Tool-Agent Interface

**Tools as Contracts**
Tools are contracts between deterministic systems and non-deterministic agents. When humans call APIs, they understand the contract and make appropriate requests. Agents must infer the contract from descriptions and generate calls that match expected formats.

This fundamental difference requires rethinking API design. The contract must be unambiguous, examples must illustrate expected patterns, and error messages must guide correction. Every ambiguity in tool definitions becomes a potential failure mode.

**Tool Description as Prompt**
Tool descriptions are loaded into agent context and collectively steer behavior. The descriptions are not just documentation—they are prompt engineering that shapes how agents reason about tool use.

Poor descriptions like "Search the database" with cryptic parameter names force agents to guess. Optimized descriptions include usage context, examples, and defaults. The description answers: what the tool does, when to use it, and what it produces.

**Namespacing and Organization**
As tool collections grow, organization becomes critical. Namespacing groups related tools under common prefixes, helping agents select appropriate tools at the right time.

Namespacing creates clear boundaries between functionality. When an agent needs database information, it routes to the database namespace. When it needs web search, it routes to web namespace.

### The Consolidation Principle

**Single Comprehensive Tools**
The consolidation principle states that if a human engineer cannot definitively say which tool should be used in a given situation, an agent cannot be expected to do better. This leads to a preference for single comprehensive tools over multiple narrow tools.

Instead of implementing list_users, list_events, and create_event, implement schedule_event that finds availability and schedules. The comprehensive tool handles the full workflow internally rather than requiring agents to chain multiple calls.

**Why Consolidation Works**
Agents have limited context and attention. Each tool in the collection competes for attention in the tool selection phase. Each tool adds description tokens that consume context budget. Overlapping functionality creates ambiguity about which tool to use.

Consolidation reduces token consumption by eliminating redundant descriptions. It eliminates ambiguity by having one tool cover each workflow. It reduces tool selection complexity by shrinking the effective tool set.

**When Not to Consolidate**
Consolidation is not universally correct. Tools with fundamentally different behaviors should remain separate. Tools used in different contexts benefit from separation. Tools that might be called independently should not be artificially bundled.

### Architectural Reduction

The consolidation principle, taken to its logical extreme, leads to architectural reduction: removing most specialized tools in favor of primitive, general-purpose capabilities. Production evidence shows this approach can outperform sophisticated multi-tool architectures.

**The File System Agent Pattern**
Instead of building custom tools for data exploration, schema lookup, and query validation, provide direct file system access through a single command execution tool. The agent uses standard Unix utilities (grep, cat, find, ls) to explore, understand, and operate on your system.

This works because:
1. File systems are a proven abstraction that models understand deeply
2. Standard tools have predictable, well-documented behavior
3. The agent can chain primitives flexibly rather than being constrained to predefined workflows
4. Good documentation in files replaces the need for summarization tools

**When Reduction Outperforms Complexity**
Reduction works when:
- Your data layer is well-documented and consistently structured
- The model has sufficient reasoning capability to navigate complexity
- Your specialized tools were constraining rather than enabling the model
- You're spending more time maintaining scaffolding than improving outcomes

Reduction fails when:
- Your underlying data is messy, inconsistent, or poorly documented
- The domain requires specialized knowledge the model lacks
- Safety constraints require limiting what the agent can do
- Operations are truly complex and benefit from structured workflows

**Stop Constraining Reasoning**
A common anti-pattern is building tools to "protect" the model from complexity. Pre-filtering context, constraining options, wrapping interactions in validation logic. These guardrails often become liabilities as models improve.

The question to ask: are your tools enabling new capabilities, or are they constraining reasoning the model could handle on its own?

**Build for Future Models**
Models improve faster than tooling can keep up. An architecture optimized for today's model may be over-constrained for tomorrow's. Build minimal architectures that can benefit from model improvements rather than sophisticated architectures that lock in current limitations.

See [Architectural Reduction Case Study](./references/architectural_reduction.md) for production evidence.

### Tool Description Engineering

**Description Structure**
Effective tool descriptions answer four questions:

What does the tool do? Clear, specific description of functionality. Avoid vague language like "helps with" or "can be used for." State exactly what the tool accomplishes.

When should it be used? Specific triggers and contexts. Include both direct triggers ("User asks about pricing") and indirect signals ("Need current market rates").

What inputs does it accept? Parameter descriptions with types, constraints, and defaults. Explain what each parameter controls.

What does it return? Output format and structure. Include examples of successful responses and error conditions.

**Default Parameter Selection**
Defaults should reflect common use cases. They reduce agent burden by eliminating unnecessary parameter specification. They prevent errors from omitted parameters.

### Response Format Optimization

Tool response size significantly impacts context usage. Implementing response format options gives agents control over verbosity.

Concise format returns essential fields only, appropriate for confirmation or basic information. Detailed format returns complete objects with all fields, appropriate when full context is needed for decisions.

Include guidance in tool descriptions about when to use each format. Agents learn to select appropriate formats based on task requirements.

### Error Message Design

Error messages serve two audiences: developers debugging issues and agents recovering from failures. For agents, error messages must be actionable. They must tell the agent what went wrong and how to correct it.

Design error messages that enable recovery. For retryable errors, include retry guidance. For input errors, include corrected format. For missing data, include what's needed.

### Tool Definition Schema

Use a consistent schema across all tools. Establish naming conventions: verb-noun pattern for tool names, consistent parameter names across tools, consistent return field names.

### Tool Collection Design

Research shows tool description overlap causes model confusion. More tools do not always lead to better outcomes. A reasonable guideline is 10-20 tools for most applications. If more are needed, use namespacing to create logical groupings.

Implement mechanisms to help agents select the right tool: tool grouping, example-based selection, and hierarchy with umbrella tools that route to specialized sub-tools.

### MCP Tool Naming Requirements

When using MCP (Model Context Protocol) tools, always use fully qualified tool names to avoid "tool not found" errors.

Format: `ServerName:tool_name`

```python
# Correct: Fully qualified names
"Use the BigQuery:bigquery_schema tool to retrieve table schemas."
"Use the GitHub:create_issue tool to create issues."

# Incorrect: Unqualified names
"Use the bigquery_schema tool..."  # May fail with multiple servers
```

Without the server prefix, agents may fail to locate tools, especially when multiple MCP servers are available. Establish naming conventions that include server context in all tool references.

### Using Agents to Optimize Tools

Claude can optimize its own tools. When given a tool and observed failure modes, it diagnoses issues and suggests improvements. Production testing shows this approach achieves 40% reduction in task completion time by helping future agents avoid mistakes.

**The Tool-Testing Agent Pattern**:

```python
def optimize_tool_description(tool_spec, failure_examples):
    """
    Use an agent to analyze tool failures and improve descriptions.
    
    Process:
    1. Agent attempts to use tool across diverse tasks
    2. Collect failure modes and friction points
    3. Agent analyzes failures and proposes improvements
    4. Test improved descriptions against same tasks
    """
    prompt = f"""
    Analyze this tool specification and the observed failures.
    
    Tool: {tool_spec}
    
    Failures observed:
    {failure_examples}
    
    Identify:
    1. Why agents are failing with this tool
    2. What information is missing from the description
    3. What ambiguities cause incorrect usage
    
    Propose an improved tool description that addresses these issues.
    """
    
    return get_agent_response(prompt)
```

This creates a feedback loop: agents using tools generate failure data, which agents then use to improve tool descriptions, which reduces future failures.

### Testing Tool Design

Evaluate tool designs against criteria: unambiguity, completeness, recoverability, efficiency, and consistency. Test tools by presenting representative agent requests and evaluating the resulting tool calls.

## Advanced Tool Use Patterns

Three empirically validated techniques for high-scale tool systems (source: Anthropic Engineering, 2025). These are orthogonal to consolidation and description engineering — apply them after the base design is solid.

Enable via: `betas=["advanced-tool-use-2025-11-20"]`

### Tool Search (Deferred Discovery)

When tool definitions exceed ~10K tokens, load a small core set at startup and let Claude search for tools on demand instead.

**How it works:** Mark tools with `defer_loading: true`. Provide a search tool (regex or BM25) as part of the always-loaded core. Claude searches for capabilities when needed; definitions load only on demand.

**Results:** 85% token reduction on definition-heavy MCP setups. Opus 4.5 accuracy: 79.5% → 88.1% on MCP evals.

**Cache note:** Deferred tools are excluded from the initial prompt entirely — Tool Search does not break prompt caching.

**Decision rule:** Use when you have 10+ tools or >10K tokens in tool definitions. Keep 3–5 most-used tools always loaded; defer the rest.

### Programmatic Tool Calling

Claude writes orchestration code instead of requesting tools one at a time through natural language.

**How it works:** Mark tools with `allowed_callers: ["code_execution_20250825"]`. Claude generates Python that calls tools in sequence, loops, or parallel. Intermediate results stay in the code executor, not Claude's context.

**Results:** 37% token reduction (43,588 → 27,297 tokens on complex 20-tool workflows). Eliminates 19+ inference passes on sequential tool chains. Enables `asyncio.gather()` for genuine parallel tool calls.

**When to use:** 3+ dependent tool calls, large intermediate data that shouldn't accumulate in context, workflows with loops or conditionals.

### Usage Examples in Tool Definitions

Provide concrete JSON examples in tool definitions for patterns JSON Schema cannot express: when to use optional parameters, which combinations make sense, API conventions.

**Results:** Accuracy: 72% → 90% on complex parameter handling.

**Format:** Include 1–5 realistic examples per tool. Focus on ambiguous areas — minimal, partial, and full specification variants. Use real data (actual cities, real prices) not placeholder strings.

```python
# In tool description:
"""
Examples:
  Minimal: {"city": "Portland"}
  With dates: {"city": "Portland", "check_in": "2026-08-01", "nights": 3}
  Full: {"city": "Portland", "check_in": "2026-08-01", "nights": 3, "guests": 2, "room_type": "queen"}
"""
```

**Layered strategy:** Start with your primary bottleneck (context bloat → Tool Search; intermediate data → Programmatic Calling; parameter errors → Examples). Add techniques progressively.

---

## CLI-to-Agent Bridging

When making an existing CLI agent-consumable, **keep traditional argument-based interfaces** — do not rewrite to JSON payloads. Empirical data shows args strictly dominate.

Source: Microsoft Developer Blog, 2025 — tested across Haiku 4.5, Sonnet 4.6, multiple shells.

### Why Args Beat JSON

| Metric | Args | JSON |
|---|---|---|
| Correctness (all models) | 100% | Degraded on smaller models (Haiku 4.5: 40%) |
| Token cost | Baseline | 4×–11× more per task |
| Shell portability | Consistent | Shell escaping creates 9× cost gap (PowerShell vs Bash) |

**The mechanism:** Args constrain the input space, eliminating JSON syntax validation, nesting errors, and shell escaping ambiguities. Narrowing valid inputs compensates for model capability gaps.

**Shell escaping tax:** JSON failures compound across retry cycles. The same model (Sonnet 4.6) ran 9× more expensive on PowerShell than Bash for JSON mode — identical correctness, just a different shell. Args were unaffected.

### The "Don't Rewrite" Rule

Keep existing CLI argument structures intact. If adding structured input:
- Offer `--json` as an *optional addition*, not a replacement
- Never force agents toward JSON-first interfaces
- The rewrite cost is negative: you get worse performance and more tokens for the trouble

### What to Change (Minimal Intervention)

If an existing CLI does need agent-friendliness improvements, focus on:
1. **Exit codes:** Ensure 0/non-0 are meaningful and consistent — agents need binary success signals
2. **Quiet mode:** Add `--quiet` or `--no-color` to suppress human-oriented decorations (progress bars, ANSI colors) that break agent parsing
3. **Machine-readable output flag (optional):** `--json` as an additive flag for structured output; never remove the default arg-based interface

These three changes cover 90% of CLI-to-agent friction without a rewrite.

---

## Intent-vs-Compiler: Emit Intent, Derive Config

When a tool requires verbose, low-level configuration, do not make the model hand-write it. Have the LLM emit a terse, high-level **intent** plus **semantic types**, and let deterministic code (the "compiler") derive the fragile low-level parameters — scales, formatting, layout, ranges, defaults, styling, config. The model declares *what it means*; the compiler decides *how to realize it*.

Source: Microsoft Flint (chart-generation), 2025. The principle generalizes to any tool where the model currently hand-writes fragile verbose specs.

**Why it wins on both axes:**
- **Token cost:** intent is a fraction of the size of a full spec — the compiler expands it deterministically at zero context cost.
- **Error surface:** the fragile parts (numeric scales, nested layout objects, enum-heavy styling) are exactly what models get wrong. Moving them into deterministic code removes an entire class of malformed-output failures — the model can only get the *intent* wrong, not the syntax.

**Two-layer pattern (charts as the worked example):**

1. **Data layer — semantic types + field metadata.** The model annotates each field with its semantic type (temporal / quantitative / categorical / ordinal) and lightweight metadata (unit, cardinality, whether it's a measure or dimension). It does *not* pick axis ranges, tick formats, or color scales.
2. **Intent layer — map fields to roles/channels.** The model states the intent as a mapping: `date → x`, `revenue → y`, `region → color`. That is the whole model-authored payload.

The compiler fills everything else — axis scales inferred from the quantitative field's range, tick/number formatting inferred from the unit, a categorical palette sized to `region`'s cardinality, legend placement, and layout. None of that touches the model.

**Generalizing beyond charts.** Apply this wherever a tool's schema is verbose and mechanically derivable:
- **Query/report tools:** model emits `{metric, dimension, filter-intent}`; compiler builds the SQL, pagination, and formatting.
- **UI/layout tools:** model emits component roles; compiler resolves spacing, breakpoints, and theming.
- **Infra/config tools:** model emits the high-level goal ("public HTTPS endpoint for service X"); compiler derives ports, security groups, and boilerplate.

**Decision rule:** if a parameter is (a) mechanically derivable from the data or a semantic type, and (b) a frequent source of malformed model output, it belongs in the compiler, not the tool schema. Expose only the irreducible intent. This is the consolidation principle applied to *parameters* rather than tools: the fewer fragile fields the model must author, the fewer ways it can fail.

---

## Practical Guidance

### Anti-Patterns to Avoid

Vague descriptions: "Search the database for customer information" leaves too many questions unanswered.

Cryptic parameter names: Parameters named x, val, or param1 force agents to guess meaning.

Missing error handling: Tools that fail with generic errors provide no recovery guidance.

Inconsistent naming: Using id in some tools, identifier in others, and customer_id in some creates confusion.

### Tool Selection Framework

When designing tool collections:
1. Identify distinct workflows agents must accomplish
2. Group related actions into comprehensive tools
3. Ensure each tool has a clear, unambiguous purpose
4. Document error cases and recovery paths
5. Test with actual agent interactions

## Examples

**Example 1: Well-Designed Tool**
```python
def get_customer(customer_id: str, format: str = "concise"):
    """
    Retrieve customer information by ID.
    
    Use when:
    - User asks about specific customer details
    - Need customer context for decision-making
    - Verifying customer identity
    
    Args:
        customer_id: Format "CUST-######" (e.g., "CUST-000001")
        format: "concise" for key fields, "detailed" for complete record
    
    Returns:
        Customer object with requested fields
    
    Errors:
        NOT_FOUND: Customer ID not found
        INVALID_FORMAT: ID must match CUST-###### pattern
    """
```

**Example 2: Poor Tool Design**

This example demonstrates several tool design anti-patterns:

```python
def search(query):
    """Search the database."""
    pass
```

**Problems with this design:**

1. **Vague name**: "search" is ambiguous - search what, for what purpose?
2. **Missing parameters**: What database? What format should query take?
3. **No return description**: What does this function return? A list? A string? Error handling?
4. **No usage context**: When should an agent use this versus other tools?
5. **No error handling**: What happens if the database is unavailable?

**Failure modes:**
- Agents may call this tool when they should use a more specific tool
- Agents cannot determine correct query format
- Agents cannot interpret results
- Agents cannot recover from failures

## Guidelines

1. Write descriptions that answer what, when, and what returns
2. Use consolidation to reduce ambiguity
3. Implement response format options for token efficiency
4. Design error messages for agent recovery
5. Establish and follow consistent naming conventions
6. Limit tool count and use namespacing for organization
7. Test tool designs with actual agent interactions
8. Iterate based on observed failure modes
9. Question whether each tool enables or constrains the model
10. Prefer primitive, general-purpose tools over specialized wrappers
11. Invest in documentation quality over tooling sophistication
12. Build minimal architectures that benefit from model improvements

## Integration

This skill connects to:
- context-fundamentals - How tools interact with context
- multi-agent-patterns - Specialized tools per agent
- evaluation - Evaluating tool effectiveness

## References

Internal references:
- [Best Practices Reference](./references/best_practices.md) - Detailed tool design guidelines
- [Architectural Reduction Case Study](./references/architectural_reduction.md) - Production evidence for tool minimalism

Related skills in this collection:
- context-fundamentals - Tool context interactions
- evaluation - Tool testing patterns

External resources:
- MCP (Model Context Protocol) documentation
- Framework tool conventions
- API design best practices for agents
- Vercel d0 agent architecture case study

---

## Skill Metadata

**Created**: 2025-12-20
**Last Updated**: 2026-07-08
**Author**: Agent Skills for Context Engineering Contributors
**Version**: 1.3.0
**Sources added**: Anthropic Engineering Advanced Tool Use (advanced tool use patterns); Microsoft Developer Blog (CLI-to-agent bridging); Microsoft Flint (intent-vs-compiler principle — emit intent, derive config)
