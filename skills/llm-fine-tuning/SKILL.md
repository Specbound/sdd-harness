---
name: llm-fine-tuning
description: Guide for fine-tuning and training LLM models using LoRA, QLoRA, SFT, DPO, and GRPO methods. Use when user asks to "fine-tune a model", "train an LLM", "create a custom model", "adapt a model to my data", mentions LoRA/QLoRA training, dataset preparation for fine-tuning, hyperparameter selection for training, or needs help with Unsloth, Hugging Face TRL, or Axolotl frameworks.
---

# LLM Fine-Tuning

Fine-tune foundation LLMs into task-specific models using parameter-efficient methods.

## Method Selection

| Method | Use Case | Memory | Speed |
|--------|----------|--------|-------|
| **QLoRA** | Default choice, resource-constrained | Low (4-bit) | Moderate |
| **LoRA** | Higher accuracy needed | 4× more than QLoRA | Faster |
| **SFT** | Teach specific behaviors | Via LoRA/QLoRA | Standard |
| **DPO** | Align with preferences (after SFT) | Via LoRA/QLoRA | Standard |
| **GRPO** | Verifiable tasks (math, code) — static dataset | Via LoRA/QLoRA | Slower |
| **Full FT** | Last resort only | Very high | Slowest |

Start with QLoRA + SFT. If results insufficient, try LoRA. Avoid full fine-tuning unless absolutely necessary.

## Quick Start (Unsloth + QLoRA)

```python
from unsloth import FastLanguageModel
from trl import SFTTrainer
from transformers import TrainingArguments
from datasets import load_dataset

# Load model with 4-bit quantization
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.2-3B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

# Add LoRA adapters
model = FastLanguageModel.get_peft_model(
    model,
    r=16,                    # Rank: 8-256, start with 16
    lora_alpha=32,           # Alpha: typically 2×rank
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
)

# Load dataset (chat format)
dataset = load_dataset("your-dataset", split="train")

# Training
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",  # or use formatting_func
    max_seq_length=2048,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        max_steps=60,  # or num_train_epochs=1
        learning_rate=2e-4,
        fp16=True,
        logging_steps=1,
        output_dir="outputs",
    ),
)
trainer.train()

# Save adapter (~100MB)
model.save_pretrained("lora_model")
```

## Dataset Formats

### Chat Format (OpenAI/ChatML)
```json
{"messages": [
  {"role": "system", "content": "You are a helpful assistant."},
  {"role": "user", "content": "What is 2+2?"},
  {"role": "assistant", "content": "4"}
]}
```

### Instruction Format (Alpaca)
```json
{"instruction": "Summarize the text", "input": "Long article...", "output": "Summary..."}
```

### ShareGPT Format
```json
{"conversations": [
  {"from": "human", "value": "Hello"},
  {"from": "gpt", "value": "Hi there!"}
]}
```

For DPO, include `chosen` and `rejected` columns. See [references/dataset_formats.md](references/dataset_formats.md).

## Key Hyperparameters

| Parameter | Recommended | Notes |
|-----------|-------------|-------|
| `r` (rank) | 16-64 | Higher = more capacity, more memory |
| `lora_alpha` | 2×r | Scaling factor; r or 2×r common |
| `learning_rate` | 2e-4 (SFT), 5e-6 (DPO/GRPO) | Start here, adjust down if unstable |
| `batch_size` | 2-8 | Use gradient accumulation for larger effective batch |
| `epochs` | 1-3 | >3 risks overfitting |
| `target_modules` | All attention + MLP | Best results; attention-only is suboptimal |

See [references/hyperparameters.md](references/hyperparameters.md) for detailed guidance.

## Hardware Requirements

| Model Size | GPU | VRAM (QLoRA) | Est. Cost |
|------------|-----|--------------|-----------|
| <1B | T4 | 3GB | $1-2 |
| 1-3B | T4/A10G | 6-10GB | $5-15 |
| 3-7B | A10G/A100 | 10-24GB | $15-40 |
| 7B+ | Multiple A100s | 40GB+ | $50+ |

Consumer GPUs: RTX 3090 (24GB) can fine-tune 7B models with QLoRA.

## Training Workflow

1. **Prepare dataset**: Format as JSONL, ensure quality over quantity (1k curated > 50k noisy)
2. **Select base model**: Start small (3B) to validate approach
3. **Configure LoRA**: r=16, alpha=32, all layers
4. **Train**: Monitor loss (target 0.5-1.0, not 0)
5. **Evaluate**: Test on held-out set before deployment
6. **Deploy**: Export to GGUF for local inference or merge adapters

## Deployment

### Export to GGUF (for llama.cpp)
```python
model.save_pretrained_gguf("model", tokenizer, quantization_method="q4_k_m")
```

### Merge adapters (for full model)
```python
model.save_pretrained_merged("merged_model", tokenizer)
```

## Common Issues

- **Loss reaches 0**: Overfitting. Reduce epochs or increase data diversity.
- **Loss doesn't decrease**: Learning rate too low or data quality issues.
- **OOM errors**: Reduce batch size, enable gradient checkpointing, use QLoRA.
- **Poor quality output**: Data quality issue. Curate better examples.

## See Also

**Training a live agent without labeled data?** Use the [[rl-agent-training]] skill instead. ART (Agent Reinforcement Trainer) runs GRPO online — the agent executes against real scenarios, trajectories are scored by a reward function or LLM judge (RULER), and weights update each step. It's the right path when you have an agent you can run and score, not a pre-built dataset.

## References

- [Training Methods](references/training_methods.md): SFT, DPO, GRPO details
- [Dataset Formats](references/dataset_formats.md): Format specifications and conversion
- [Hyperparameters](references/hyperparameters.md): Detailed tuning guidance
- [Frameworks](references/frameworks.md): Unsloth, HF TRL, Axolotl setup
