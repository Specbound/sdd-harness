# Dataset Formats

## Table of Contents
- [File Formats](#file-formats)
- [Chat Format (OpenAI/ChatML)](#chat-format-openaichatml)
- [ShareGPT Format](#sharegpt-format)
- [Instruction Format (Alpaca)](#instruction-format-alpaca)
- [Text-Only Format](#text-only-format)
- [Preference Data (DPO)](#preference-data-dpo)
- [Format Conversion](#format-conversion)
- [Dataset Quality](#dataset-quality)

---

## File Formats

### JSONL (Recommended)
One JSON object per line. Easy to stream, append, and process.

```jsonl
{"messages": [{"role": "user", "content": "Hello"}, {"role": "assistant", "content": "Hi!"}]}
{"messages": [{"role": "user", "content": "How are you?"}, {"role": "assistant", "content": "I'm doing well!"}]}
```

### Parquet
Efficient column-based storage. Good for large datasets. Use with Hugging Face datasets library.

### JSON Array
Single file with array of objects. Less common, harder to stream.

---

## Chat Format (OpenAI/ChatML)

Most common format for instruction-tuned models. Used by OpenAI, Llama, Mistral.

```json
{
  "messages": [
    {"role": "system", "content": "You are a helpful coding assistant."},
    {"role": "user", "content": "Write a Python function to calculate factorial"},
    {"role": "assistant", "content": "def factorial(n):\n    if n <= 1:\n        return 1\n    return n * factorial(n - 1)"}
  ]
}
```

### Multi-turn Conversations
```json
{
  "messages": [
    {"role": "system", "content": "You are a math tutor."},
    {"role": "user", "content": "What is 5 + 3?"},
    {"role": "assistant", "content": "5 + 3 = 8"},
    {"role": "user", "content": "Now multiply that by 2"},
    {"role": "assistant", "content": "8 × 2 = 16"}
  ]
}
```

### Roles
- `system`: Optional. Sets context/behavior for the assistant.
- `user`: Human input
- `assistant`: Model response (what we're training)

---

## ShareGPT Format

Alternative chat format popular with open-source datasets.

```json
{
  "conversations": [
    {"from": "system", "value": "You are a helpful assistant."},
    {"from": "human", "value": "Explain photosynthesis"},
    {"from": "gpt", "value": "Photosynthesis is the process..."}
  ]
}
```

### Role Mapping
| ShareGPT | OpenAI |
|----------|--------|
| `system` | `system` |
| `human` | `user` |
| `gpt` | `assistant` |

---

## Instruction Format (Alpaca)

Simple prompt-response pairs with optional input context.

### Basic Format
```json
{
  "instruction": "Translate to French",
  "input": "Hello, how are you?",
  "output": "Bonjour, comment allez-vous?"
}
```

### Without Input
```json
{
  "instruction": "Write a haiku about programming",
  "input": "",
  "output": "Code flows like water\nBugs emerge then fade away\nShip it anyway"
}
```

### Simple Prompt-Response
```json
{
  "prompt": "What is the capital of France?",
  "response": "The capital of France is Paris."
}
```

---

## Text-Only Format

Pre-templated strings with special tokens. Model sees exactly this during training.

```json
{"text": "<|im_start|>system\nYou are helpful.<|im_end|>\n<|im_start|>user\nHello<|im_end|>\n<|im_start|>assistant\nHi there!<|im_end|>"}
```

### When to Use
- Custom chat templates
- Pre-tokenized data
- Specific formatting requirements

---

## Preference Data (DPO)

Required for DPO training. Each example has chosen and rejected responses.

### Basic Format
```json
{
  "prompt": "Explain machine learning in simple terms",
  "chosen": "Machine learning is like teaching a computer by showing it examples...",
  "rejected": "ML is a subset of AI utilizing statistical methods..."
}
```

### With Messages Format
```json
{
  "prompt": [
    {"role": "user", "content": "Explain machine learning"}
  ],
  "chosen": [
    {"role": "assistant", "content": "Machine learning is like teaching..."}
  ],
  "rejected": [
    {"role": "assistant", "content": "ML is a subset of AI..."}
  ]
}
```

### Creating Preference Data
1. **Human annotation**: Have humans rank responses
2. **Model-based**: Use stronger model to judge
3. **Heuristic**: Use metrics (length, format compliance)
4. **A/B testing**: Use user engagement signals

---

## Format Conversion

### Alpaca to Chat Format

```python
def alpaca_to_chat(example):
    messages = []
    if example.get("input"):
        user_content = f"{example['instruction']}\n\nInput: {example['input']}"
    else:
        user_content = example["instruction"]

    messages.append({"role": "user", "content": user_content})
    messages.append({"role": "assistant", "content": example["output"]})
    return {"messages": messages}
```

### ShareGPT to Chat Format

```python
def sharegpt_to_chat(example):
    role_map = {"system": "system", "human": "user", "gpt": "assistant"}
    messages = []
    for turn in example["conversations"]:
        messages.append({
            "role": role_map[turn["from"]],
            "content": turn["value"]
        })
    return {"messages": messages}
```

### Apply to Dataset

```python
from datasets import load_dataset

dataset = load_dataset("your-alpaca-dataset", split="train")
dataset = dataset.map(alpaca_to_chat)
dataset.to_json("converted.jsonl")
```

---

## Dataset Quality

### Quality > Quantity
Research shows 1k curated examples can outperform 50k noisy ones (LIMA study).

### Quality Checklist
- [ ] Responses are accurate and helpful
- [ ] Consistent style and formatting
- [ ] No harmful or incorrect content
- [ ] Diverse examples covering use cases
- [ ] Appropriate length (not too short/long)
- [ ] Valid JSON/JSONL format

### Validation Script

```python
import json

def validate_chat_dataset(filepath):
    errors = []
    with open(filepath, 'r') as f:
        for i, line in enumerate(f, 1):
            try:
                data = json.loads(line)
                if "messages" not in data:
                    errors.append(f"Line {i}: Missing 'messages' key")
                    continue
                for msg in data["messages"]:
                    if "role" not in msg or "content" not in msg:
                        errors.append(f"Line {i}: Invalid message format")
                    if msg["role"] not in ["system", "user", "assistant"]:
                        errors.append(f"Line {i}: Invalid role '{msg['role']}'")
            except json.JSONDecodeError:
                errors.append(f"Line {i}: Invalid JSON")
    return errors

errors = validate_chat_dataset("train.jsonl")
if errors:
    print("Dataset errors found:")
    for e in errors:
        print(f"  {e}")
else:
    print("Dataset valid!")
```

### Train/Test Split

```python
from datasets import load_dataset

dataset = load_dataset("json", data_files="data.jsonl", split="train")
split = dataset.train_test_split(test_size=0.1, seed=42)
split["train"].to_json("train.jsonl")
split["test"].to_json("test.jsonl")
```
