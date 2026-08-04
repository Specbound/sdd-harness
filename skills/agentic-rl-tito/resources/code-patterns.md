# TITO Code Patterns

Reference implementations from the Agentic RL: Token-In, Token-Out article.
Source: https://qgallouedec-tito.hf.space (May 2026, Hugging Face)

---

## 1. Prefix-Preservation Property Test

Run once before training to verify the tokenizer is safe for TITO.

```python
def is_chat_template_prefix_preserving(tokenizer) -> bool:
    dummy_tool_calls = [{"type": "function", "function": {"name": "dummy", "arguments": {}}}]
    messages1 = [
        {"role": "user", "content": "dummy"},
        {"role": "assistant", "content": "", "tool_calls": dummy_tool_calls},
    ]
    messages2 = [
        {"role": "user", "content": "dummy"},
        {"role": "assistant", "content": "", "tool_calls": dummy_tool_calls},
        {"role": "tool", "name": "dummy", "content": "dummy"},
    ]
    ids1 = tokenizer.apply_chat_template(messages1, tokenize=True, return_dict=False)
    ids2 = tokenizer.apply_chat_template(messages2, tokenize=True, return_dict=False,
                                          add_generation_prompt=True)
    return ids2[:len(ids1)] == ids1
```

Usage:
```python
from transformers import AutoTokenizer
tok = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-7B-Instruct")
assert is_chat_template_prefix_preserving(tok), "Template is NOT prefix-preserving — fix before training"
```

---

## 2. Tool Response Delta Computation

Add a tool result to the buffer by computing only the delta (new wrapper tokens), not re-rendering everything.

```python
from transformers import AutoTokenizer

tok = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct")

def compute_tool_delta(tok, messages_so_far: list, tool_output: str) -> list[int]:
    """Return only the token IDs for the tool response wrapper — not the full history."""
    prefix_ids = tok.apply_chat_template(messages_so_far, return_dict=False)
    full_ids = tok.apply_chat_template(
        messages_so_far + [{"role": "tool", "content": tool_output}],
        return_dict=False,
        add_generation_prompt=True,
    )
    return full_ids[len(prefix_ids):]

# Example
messages = [
    {"role": "user", "content": "What's 2+2?"},
    {"role": "assistant", "tool_calls": [
        {"type": "function", "function": {"name": "calc", "arguments": {"expr": "2+2"}}}
    ]},
]
delta = compute_tool_delta(tok, messages, tool_output="4")
# delta contains only the tool response wrapper tokens, safe to extend the buffer with
```

---

## 3. Minimal TITO Training Loop Skeleton

```python
def run_episode(model, tokenizer, prompt: str, tool_fn) -> dict:
    """
    Returns: {'buffer': list[int], 'loss_mask': list[bool], 'reward': float}
    loss_mask[i] = True means buffer[i] is an assistant token we should train on.
    """
    buffer = tokenizer.encode(prompt)
    loss_mask = [False] * len(buffer)   # prompt tokens → no loss
    messages = [{"role": "user", "content": prompt}]

    while True:
        # Generate — new tokens go directly into buffer
        input_ids = torch.tensor([buffer])
        with torch.no_grad():
            new_ids = model.generate(input_ids, max_new_tokens=256)[0][len(buffer):].tolist()

        buffer.extend(new_ids)
        loss_mask.extend([True] * len(new_ids))   # assistant tokens → compute loss

        decoded = tokenizer.decode(new_ids)

        # Parse for tool dispatch (routing only — discard after)
        tool_call = try_parse_tool_call(decoded)
        if tool_call is None:
            break   # model finished

        # Execute tool
        tool_result = tool_fn(tool_call)

        # Append tool response delta — NOT a full re-render
        messages.append({"role": "assistant", "tool_calls": [tool_call]})
        delta = compute_tool_delta(tokenizer, messages, tool_result)
        buffer.extend(delta)
        loss_mask.extend([False] * len(delta))    # tool tokens → no loss
        messages.append({"role": "tool", "content": tool_result})

    reward = compute_reward(tokenizer.decode(buffer))
    return {"buffer": buffer, "loss_mask": loss_mask, "reward": reward}
```

---

## 4. Qwen3 Template Fix

Qwen3 base fails prefix preservation because its `<think>` block renders conditionally.
Edit the Jinja template (one line change):

```diff
-  {%- if loop.last or (not loop.last and reasoning_content) %}
+  {%- if true %}
```

This ensures the `<think>` block always renders, maintaining token sequence stability when tool results are appended.

Verify the fix worked:
```python
tok = AutoTokenizer.from_pretrained("Qwen/Qwen3-8B")
# Apply patch to tok.chat_template string here
assert is_chat_template_prefix_preserving(tok), "Fix did not work"
```
