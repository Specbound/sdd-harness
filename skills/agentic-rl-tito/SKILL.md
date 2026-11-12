---
name: agentic-rl-tito
description: "TITO correctness invariant for multi-turn RL training loops on tool-calling LLMs, including harness-mediated RL where the trainer does not own the token buffer. Use when implementing or reviewing PPO/GRPO/REINFORCE fine-tuning. Not for general ML, inference, or agent development."
metadata:
  type: skill
  source: https://qgallouedec-tito.hf.space
  added: 2026-06-02
  also_sourced:
    - https://arxiv.org/abs/2608.17528  # Agent Lightning v1.0 — harness-mediated RL section
  model: inherit
risk: low
---

## Use this skill when

- Implementing a multi-turn RL training loop where the model calls tools (function calls, code execution, search)
- Debugging mysterious loss spikes, shape mismatches, or unreliable gradients in an agentic RL loop
- Reviewing training code that re-renders conversation history at each step
- Validating whether a tokenizer/chat template is safe to use in an RL training loop
- Choosing between TITO and a renderer-library approach

## Do not use this skill when

- Running inference with tool-calling models (no training involved)
- Building agent pipelines without RL training (RAG, orchestration, etc.)
- General ML engineering, model serving, or evaluation
- SFT (supervised fine-tuning) on static datasets — TITO applies only to online RL with live sampling

---

## Core Invariant: Token-In, Token-Out (TITO)

> **Never re-encode what you decoded.**

When a model samples tokens during RL, those exact token IDs must flow into the loss computation. Re-rendering the conversation history through the chat template produces different token sequences (BPE drift, template context effects) — the model then receives gradients for tokens it never generated. This silently corrupts training without an obvious error signal.

**Broken pattern:**
```
messages = []
for turn in episode:
    messages.append({"role": "assistant", "content": model.generate(messages)})
    messages.append(tool_result)
    ids = tokenizer.apply_chat_template(messages)  # ← re-encodes everything
    loss = compute_loss(ids)
```

**TITO pattern:**
```
buffer = tokenize(prompt)
while not done:
    new_tokens = model.generate(buffer)
    buffer.extend(new_tokens)           # never re-encode sampled tokens
    if tool_call_detected(new_tokens):
        tool_tokens = compute_tool_delta(buffer, tool_result)
        buffer.extend(tool_tokens)      # delta only — not a full re-render
compute_loss(buffer)                    # loss on exact sampled tokens
```

---

## Correct Loop Algorithm

1. Tokenize the initial prompt → `buffer`
2. **Generate** — run model on `buffer`, append new tokens to `buffer`
3. **Parse** the decoded output (for routing only; discard parsed dict after dispatch)
4. If tool call: execute tool → `compute_tool_delta()` → append delta to `buffer`
5. Else: stop
6. Compute reward on completed trajectory
7. Compute loss on `buffer` (mask to assistant tokens only)
8. Backprop

Key consequence: loss mask boundaries are known at **append time**, not reconstructed from the final buffer.

---

## Prerequisite: Prefix-Preservation Property Test

Before using any tokenizer in a TITO loop, verify its chat template is **prefix-preserving**: appending a tool result to the rendered history must extend the token sequence, not change it.

```python
def is_chat_template_prefix_preserving(tokenizer) -> bool:
    dummy_tool_calls = [{"type": "function", "function": {"name": "dummy", "arguments": {}}}]
    messages1 = [
        {"role": "user", "content": "dummy"},
        {"role": "assistant", "content": "", "tool_calls": dummy_tool_calls},
    ]
    messages2 = messages1 + [{"role": "tool", "name": "dummy", "content": "dummy"}]
    ids1 = tokenizer.apply_chat_template(messages1, tokenize=True, return_dict=False)
    ids2 = tokenizer.apply_chat_template(messages2, tokenize=True, return_dict=False,
                                          add_generation_prompt=True)
    return ids2[:len(ids1)] == ids1
```

**Run this before training.** If it returns `False`, the model requires a template fix before TITO is safe.

---

## Model Compatibility (May 2026)

18 of 19 major open-weight models pass without modification:

| Model Family | Prefix-Preserving |
|---|---|
| Qwen2.5, Qwen2.5-Coder | ✅ |
| Qwen3 (base) | ❌ — see fix below |
| Qwen3 Instruct (2507), Qwen3-VL, Qwen3.5, Qwen3.6 | ✅ |
| DeepSeek-V3.1, DeepSeek-R1 variants | ✅ |
| Llama 3.1, 3.2, 4 | ✅ |
| Gemma 4, Function Gemma | ✅ |
| gpt-oss, GLM-4.5, GLM-5 | ✅ |
| MiniMax-M2.1 | ✅ |

**Qwen3 fix** — the `<think>` block renders conditionally based on position; change one line in the Jinja template:

```
- {%- if loop.last or (not loop.last and reasoning_content) %}
+ {%- if true %}
```

This ensures `<think>` persists when tool results are appended, restoring prefix preservation.

---

## Tool Response Delta (not full re-render)

To add a tool result to the buffer without re-encoding the full history:

```python
prefix_ids = tokenizer.apply_chat_template(messages_so_far, return_dict=False)
full_ids    = tokenizer.apply_chat_template(
    messages_so_far + [{"role": "tool", "content": tool_output}],
    return_dict=False, add_generation_prompt=True
)
delta = full_ids[len(prefix_ids):]   # only the wrapper tokens for this tool result
buffer.extend(delta)
```

Full code examples: `resources/code-patterns.md`

---

## Edge Cases

### History Rewriting
When an agent edits past conversation (compaction, `clear_thinking`, sub-agent summarization):
- **Freeze** everything up to the rewrite point as prompt (no loss computed on it)
- Loss computation begins after the rewrite
- Trade-off: shorter loss-bearing trajectory, but correctness is preserved

### Truncation
If the buffer exceeds the context limit mid-turn, zero out the loss for incomplete turns. TITO handles this naturally — boundaries are tracked in the buffer, so partial turns can be masked without per-model close-token synthesis.

---

## When TITO Is Unattainable: Harness-Mediated RL

Everything above assumes **the trainer owns the token buffer**. That assumption breaks
when training runs *through* a deployment harness (Claude Code, OpenHands, mini-SWE-agent)
that owns the tools, context, and control loop. The trainer then sees no clean token
trajectory at all — only a variable-length sequence of request/response pairs across a
service boundary, with the harness re-rendering prompts between them.

Do not assume the prefix survives. Measured on a real harness-mediated setup, only
**36% of rollouts remain a single sample; the mean is 2.41 samples per rollout** — token
prefix continuity breaks in roughly two-thirds of rollouts.

**Three root causes of prefix breakage** (all invisible unless you check for them):
- **Chat-template non-compositionality** — re-rendering the same history can drop an
  earlier marker (e.g. Qwen's template dropping a prior `<think>` block).
- **Decode–retokenize drift** — `h` + `aving` decodes to text that retokenizes as
  `hav` + `ing`. Same string, different tokens.
- **Output reserialization** — tool-call handlers reserialize the model's own output
  before it re-enters the prompt.

**Merging strategy — use best-effort merging.** Merge consecutive calls only on exact
*token*-prefix match; on mismatch, close the sequence and start a new sample.

> ⚠️ Do **not** use buffered token replacement (as in AReaL, verl Uni-Agent). Stitching
> a recorded response onto a re-rendered prompt trains a response under a prompt
> `p̃ ≠ p` that it was never sampled from — a silent off-policy discrepancy, not a
> formatting detail.

**The two loss-side fixes must ship as a pair.** Splitting one rollout into several
samples breaks per-sample advantage baselines. Measured ablation (Qwen3.5-9B,
mini-SWE-agent, SWE-smith, validation reward at step 128):

| Configuration | Reward |
|---|---|
| sample-level advantage + token-mean loss (baseline) | 35.0% |
| rollout-level advantage **alone** | 33.1% — *worse than baseline* |
| rollout-level advantage + rollout-level token-mean normalization | **38.2%** |

Adopting the advantage fix on its own regresses. Also keep every sample from one rollout
inside a **single optimizer update**, or the rollout is scored partly under a policy that
has already moved.

**Scope:** this is knowledge for authoring a training loop against a harness you do not
control. Nothing here is automatable from a Claude Code harness — there is no hook,
routine, or check that can observe it.

*Source: Agent Lightning v1.0, arXiv:2608.17528 (Microsoft et al., 2026). SWE-bench
Verified 41.8% → 56.4% RL-only. Repo: github.com/microsoft/agent-lightning.*

---

## TITO vs. Renderer Libraries

| Aspect | TITO | Renderer Library |
|---|---|---|
| Template logic | Single `compute_delta()` (~10 lines) | Per-model hand-coded objects |
| Re-encoding risk | Zero | Mitigated by per-family validation |
| Truncation | Natural zero-mask on incomplete turns | Must synthesize close tokens per model |
| History rewriting | Freeze-and-continue | Requires bridge redesign per edit type |
| Maintenance surface | Low | Grows with model family count |

Use TITO when starting a new training loop. Use a renderer library only if integrating with an existing system where TITO adoption would require a full rewrite.
