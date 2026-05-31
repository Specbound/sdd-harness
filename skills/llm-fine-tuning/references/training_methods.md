# Training Methods

## Table of Contents
- [Supervised Fine-Tuning (SFT)](#supervised-fine-tuning-sft)
- [Direct Preference Optimization (DPO)](#direct-preference-optimization-dpo)
- [Group Relative Policy Optimization (GRPO)](#group-relative-policy-optimization-grpo)
- [Full Fine-Tuning](#full-fine-tuning)
- [Method Comparison](#method-comparison)

---

## Supervised Fine-Tuning (SFT)

Train on demonstration data showing desired behavior. The most common starting point.

### Use Cases
- Customer support conversations
- Code generation for specific languages/frameworks
- Domain-specific Q&A (medical, legal, technical)
- Instruction following
- Format adherence (JSON output, specific templates)

### Implementation with TRL

```python
from trl import SFTTrainer, SFTConfig
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset

model = AutoModelForCausalLM.from_pretrained("base-model")
tokenizer = AutoTokenizer.from_pretrained("base-model")
dataset = load_dataset("your-dataset", split="train")

# For chat format datasets
def formatting_func(example):
    return tokenizer.apply_chat_template(example["messages"], tokenize=False)

trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    args=SFTConfig(
        output_dir="./sft_output",
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        num_train_epochs=3,
        logging_steps=10,
        save_steps=100,
    ),
    formatting_func=formatting_func,
)
trainer.train()
```

### Best Practices
- Start with 1k-10k high-quality examples
- Quality > quantity (curated LIMA dataset outperforms larger noisy datasets)
- Validate data format before training
- Use held-out test set for evaluation

---

## Direct Preference Optimization (DPO)

Train on preference pairs (chosen vs rejected responses). Typically applied after SFT to align outputs with human preferences.

### Use Cases
- Improving response quality after SFT
- Aligning with specific style preferences
- Reducing harmful outputs
- Teaching nuanced judgment calls

### Dataset Requirements
Must have `chosen` and `rejected` columns (and optionally `prompt`):

```json
{
  "prompt": "Explain quantum computing",
  "chosen": "Quantum computing uses qubits...",
  "rejected": "I don't know much about that..."
}
```

### Implementation

```python
from trl import DPOTrainer, DPOConfig
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset

# Load SFT-trained model as starting point
model = AutoModelForCausalLM.from_pretrained("./sft_output")
tokenizer = AutoTokenizer.from_pretrained("./sft_output")

# Load preference dataset
dataset = load_dataset("your-preference-data", split="train")

trainer = DPOTrainer(
    model=model,
    ref_model=None,  # Will create copy automatically
    args=DPOConfig(
        output_dir="./dpo_output",
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        learning_rate=5e-6,  # Lower than SFT!
        num_train_epochs=1,
        beta=0.1,  # KL divergence coefficient
        logging_steps=10,
    ),
    train_dataset=dataset,
    tokenizer=tokenizer,
)
trainer.train()
```

### Key Parameters
- `beta`: Controls deviation from reference model (0.1-0.5 typical)
- `learning_rate`: Use 5e-6, much lower than SFT
- Typically only 1 epoch needed

---

## Group Relative Policy Optimization (GRPO)

Reinforcement learning for verifiable tasks. Model generates responses, receives rewards based on correctness, learns from outcomes.

### Use Cases
- Mathematical reasoning
- Code generation (can verify with tests)
- Logic puzzles
- Tasks with verifiable ground truth

### How It Works
1. Model generates multiple responses to same prompt
2. Each response evaluated against ground truth
3. Model learns to prefer higher-reward responses
4. No need for separate reward model

### Implementation

```python
from trl import GRPOTrainer, GRPOConfig
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset

model = AutoModelForCausalLM.from_pretrained("base-model")
tokenizer = AutoTokenizer.from_pretrained("base-model")

# Dataset needs verifiable answers
dataset = load_dataset("openai/gsm8k", split="train")

def reward_function(completions, prompts):
    """Return rewards based on correctness."""
    rewards = []
    for completion, prompt in zip(completions, prompts):
        # Extract answer, compare to ground truth
        is_correct = verify_answer(completion, prompt)
        rewards.append(1.0 if is_correct else 0.0)
    return rewards

trainer = GRPOTrainer(
    model=model,
    args=GRPOConfig(
        output_dir="./grpo_output",
        per_device_train_batch_size=2,
        learning_rate=5e-6,
        num_train_epochs=1,
    ),
    train_dataset=dataset,
    tokenizer=tokenizer,
    reward_funcs=reward_function,
)
trainer.train()
```

---

## Full Fine-Tuning

Updates all model parameters. Resource-intensive but maximum flexibility.

### When to Use
- LoRA/QLoRA results insufficient after extensive tuning
- Significant domain shift required
- Compute resources available
- Pre-training continuation

### Why to Avoid
- 10-100× more compute than LoRA
- Risk of catastrophic forgetting
- Harder to iterate and experiment
- Model size unchanged (still need same inference resources)

### If You Must

```python
from transformers import AutoModelForCausalLM, Trainer, TrainingArguments

model = AutoModelForCausalLM.from_pretrained(
    "base-model",
    torch_dtype=torch.bfloat16,
)

trainer = Trainer(
    model=model,
    args=TrainingArguments(
        output_dir="./full_ft",
        per_device_train_batch_size=1,
        gradient_accumulation_steps=16,
        learning_rate=1e-5,  # Very low
        num_train_epochs=1,
        fp16=True,
        gradient_checkpointing=True,
        deepspeed="ds_config.json",  # Usually required
    ),
    train_dataset=dataset,
)
trainer.train()
```

---

## Method Comparison

| Aspect | SFT | DPO | GRPO | Full FT |
|--------|-----|-----|------|---------|
| **Purpose** | Teach behaviors | Align preferences | Learn from rewards | Maximum adaptation |
| **Data needed** | Demonstrations | Preference pairs | Verifiable tasks | Demonstrations |
| **Order** | First | After SFT | After SFT | Standalone |
| **Learning rate** | 2e-4 | 5e-6 | 5e-6 | 1e-5 |
| **Epochs** | 1-3 | 1 | 1-3 | 1 |
| **Compute** | Low (LoRA) | Low (LoRA) | Medium | Very high |

### Recommended Pipeline

For production-grade models:
```
SFT → DPO → (optional) GRPO
```

1. **SFT**: Establish base capabilities with demonstration data
2. **DPO**: Refine quality using preference data
3. **GRPO**: (If applicable) Improve on verifiable tasks
