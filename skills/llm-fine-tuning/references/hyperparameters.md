# Hyperparameters Guide

## Table of Contents
- [LoRA Parameters](#lora-parameters)
- [Training Parameters](#training-parameters)
- [QLoRA vs LoRA](#qlora-vs-lora)
- [Tuning Strategy](#tuning-strategy)
- [Common Configurations](#common-configurations)

---

## LoRA Parameters

### Rank (r)

Controls the dimensionality of the low-rank matrices. Higher rank = more trainable parameters = more capacity.

| Rank | Trainable Params (7B model) | Use Case |
|------|---------------------------|----------|
| 8 | ~4M | Simple tasks, quick experiments |
| 16 | ~8M | General purpose (recommended start) |
| 32 | ~17M | Complex tasks |
| 64 | ~34M | High capacity needed |
| 128 | ~67M | Domain shift |
| 256 | ~134M | Maximum adaptation |

**Research finding**: QLoRA paper found "very little statistical difference between ranks of 8 and 256" when LoRA is applied to all layers. Start with 16, increase only if needed.

### Alpha (lora_alpha)

Scaling factor that controls the magnitude of LoRA weight updates. The effective scaling is `alpha / rank`.

**Common strategies**:
- `alpha = rank`: Standard, conservative updates
- `alpha = 2 * rank`: More aggressive updates (often better)
- `alpha = rank / 2`: Gentler updates, useful if training is unstable

**Why it exists**: Normalizes learning rate across different rank settings. With alpha=2×rank, a model with r=16 and r=64 can use the same learning rate.

```python
# Recommended: alpha = 2 * rank
model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    lora_alpha=32,  # 2 * 16
)
```

### Target Modules

Which layers to apply LoRA to. **Apply to all layers for best results.**

```python
# Full coverage (recommended)
target_modules = [
    "q_proj", "k_proj", "v_proj", "o_proj",  # Attention
    "gate_proj", "up_proj", "down_proj",      # MLP
]

# Attention only (not recommended, but faster)
target_modules = ["q_proj", "v_proj"]
```

**Research finding**: Applying LoRA only to attention matrices shows no benefit over MLP-only. QLoRA-All (all layers) consistently performs best.

### Dropout

Regularization to prevent overfitting. Usually set to 0 for LoRA.

```python
lora_dropout = 0  # Recommended for most cases
lora_dropout = 0.05  # If overfitting on small datasets
```

---

## Training Parameters

### Learning Rate

| Method | Starting Rate | Range |
|--------|--------------|-------|
| SFT (LoRA) | 2e-4 | 1e-4 to 5e-4 |
| DPO | 5e-6 | 1e-6 to 1e-5 |
| GRPO | 5e-6 | 1e-6 to 1e-5 |
| Full FT | 1e-5 | 5e-6 to 5e-5 |

**Signs learning rate is wrong**:
- Too high: Loss spikes, unstable training, NaN values
- Too low: Loss decreases very slowly, poor final performance

### Batch Size & Gradient Accumulation

Effective batch size = `per_device_batch_size × gradient_accumulation_steps × num_gpus`

```python
# Effective batch size = 2 × 4 × 1 = 8
per_device_train_batch_size = 2
gradient_accumulation_steps = 4
```

**Guidelines**:
- Start with batch size 2-4 per device
- Use gradient accumulation for larger effective batch
- Larger batch = more stable training but slower iteration
- Target effective batch size: 8-32 for most tasks

### Epochs

| Dataset Size | Recommended Epochs |
|--------------|-------------------|
| <1k examples | 3-5 |
| 1k-10k | 1-3 |
| 10k-100k | 1-2 |
| >100k | 1 |

**Warning**: Multi-epoch training on instruction datasets can degrade performance. Monitor for overfitting.

### Sequence Length

Maximum tokens per training example.

```python
max_seq_length = 2048  # Good default
max_seq_length = 4096  # For longer documents
max_seq_length = 512   # For short Q&A
```

**Note**: Longer sequences use more memory quadratically. Start short, increase if truncation is a problem.

### Warmup

Number of steps with linearly increasing learning rate.

```python
warmup_steps = 10   # Quick experiments
warmup_ratio = 0.03 # 3% of total steps (production)
```

---

## QLoRA vs LoRA

| Aspect | LoRA | QLoRA |
|--------|------|-------|
| Base model precision | 16-bit | 4-bit |
| Adapter precision | 16-bit | 16-bit |
| Memory usage | Higher | ~4× lower |
| Training speed | Faster | ~39% slower |
| Final accuracy | Baseline | Slightly lower |

**When to use QLoRA**:
- Limited VRAM
- Quick experiments
- Models >7B on consumer GPUs

**When to use LoRA**:
- Maximum accuracy needed
- Sufficient VRAM available
- Final production training

```python
# QLoRA setup
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.2-3B-Instruct-bnb-4bit",
    load_in_4bit=True,  # This enables QLoRA
)

# LoRA setup (16-bit)
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="meta-llama/Llama-3.2-3B-Instruct",
    load_in_4bit=False,
    dtype=torch.float16,
)
```

---

## Tuning Strategy

### Start Here (Conservative)
```python
r = 16
lora_alpha = 32
learning_rate = 2e-4
per_device_train_batch_size = 2
gradient_accumulation_steps = 4
num_train_epochs = 1
warmup_ratio = 0.03
```

### If Underfitting
1. Increase rank: 16 → 32 → 64
2. Increase alpha proportionally
3. Increase epochs (carefully)
4. Check data quality

### If Overfitting
1. Reduce epochs
2. Add dropout (0.05)
3. Increase dataset size/diversity
4. Reduce rank

### If Unstable Training
1. Reduce learning rate by 2-5×
2. Increase warmup steps
3. Reduce batch size
4. Check for data issues (very long/short examples)

### If OOM Errors
1. Reduce batch size to 1
2. Enable gradient checkpointing
3. Switch from LoRA to QLoRA
4. Reduce sequence length
5. Use smaller model

---

## Common Configurations

### Quick Experiment (3B model, consumer GPU)
```python
r = 8
lora_alpha = 16
learning_rate = 2e-4
per_device_train_batch_size = 2
gradient_accumulation_steps = 2
max_steps = 100
load_in_4bit = True
```

### Production SFT (7B model)
```python
r = 32
lora_alpha = 64
learning_rate = 2e-4
per_device_train_batch_size = 4
gradient_accumulation_steps = 4
num_train_epochs = 2
warmup_ratio = 0.03
load_in_4bit = True
target_modules = ["q_proj", "k_proj", "v_proj", "o_proj",
                  "gate_proj", "up_proj", "down_proj"]
```

### DPO Alignment
```python
r = 16
lora_alpha = 32
learning_rate = 5e-6  # Much lower!
per_device_train_batch_size = 2
gradient_accumulation_steps = 4
num_train_epochs = 1
beta = 0.1
```

### Maximum Quality (A100)
```python
r = 64
lora_alpha = 128
learning_rate = 1e-4
per_device_train_batch_size = 8
gradient_accumulation_steps = 2
num_train_epochs = 3
load_in_4bit = False  # Full LoRA, not QLoRA
```
