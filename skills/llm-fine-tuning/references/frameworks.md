# Frameworks Guide

## Table of Contents
- [Framework Comparison](#framework-comparison)
- [Unsloth](#unsloth)
- [Hugging Face TRL](#hugging-face-trl)
- [Axolotl](#axolotl)
- [LLaMA Factory](#llama-factory)
- [Installation](#installation)

---

## Framework Comparison

| Framework | Best For | Ease of Use | Speed | Features |
|-----------|----------|-------------|-------|----------|
| **Unsloth** | Speed, low VRAM | Easy | Fastest (2×) | LoRA, QLoRA, GGUF export |
| **TRL** | Flexibility, RLHF | Medium | Standard | SFT, DPO, GRPO, PPO |
| **Axolotl** | Config-based training | Easy | Standard | Multi-dataset, many formats |
| **LLaMA Factory** | GUI, beginners | Easiest | Standard | Web UI, many models |

**Recommendation**: Start with Unsloth for speed and simplicity. Use TRL directly if you need custom training loops or RLHF methods.

---

## Unsloth

Optimized fine-tuning with 2× speed improvement and 60% memory reduction.

### Installation
```bash
pip install unsloth
# Or for specific CUDA version:
pip install "unsloth[cu121]"  # CUDA 12.1
pip install "unsloth[cu118]"  # CUDA 11.8
```

### Basic Usage
```python
from unsloth import FastLanguageModel
from trl import SFTTrainer
from transformers import TrainingArguments

# Load with 4-bit quantization
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.2-3B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

# Add LoRA
model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
)

# Train
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=2048,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        max_steps=60,
        learning_rate=2e-4,
        fp16=True,
        logging_steps=1,
        output_dir="outputs",
    ),
)
trainer.train()
```

### Saving Models
```python
# Save LoRA adapter only (~100MB)
model.save_pretrained("lora_adapter")

# Save merged model (full size)
model.save_pretrained_merged("merged_model", tokenizer)

# Export to GGUF for llama.cpp
model.save_pretrained_gguf("gguf_model", tokenizer, quantization_method="q4_k_m")
```

### Fast Inference
```python
FastLanguageModel.for_inference(model)  # 2× faster inference
```

### Supported Models
- Llama 3.x, 3.2
- Mistral, Mixtral
- Qwen 2.5
- Phi-3, Phi-4
- Gemma 2
- And more: check `unsloth/` on Hugging Face

---

## Hugging Face TRL

Official library for transformer reinforcement learning. Most flexible option.

### Installation
```bash
pip install trl transformers datasets peft accelerate bitsandbytes
```

### SFT Training
```python
from trl import SFTTrainer, SFTConfig
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import LoraConfig
from datasets import load_dataset

# QLoRA setup
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.2-3B-Instruct",
    quantization_config=bnb_config,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.2-3B-Instruct")

# LoRA config
lora_config = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_dropout=0,
    bias="none",
    task_type="CAUSAL_LM",
)

# Train
trainer = SFTTrainer(
    model=model,
    train_dataset=dataset,
    peft_config=lora_config,
    args=SFTConfig(
        output_dir="./output",
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        num_train_epochs=1,
    ),
)
trainer.train()
```

### DPO Training
```python
from trl import DPOTrainer, DPOConfig

trainer = DPOTrainer(
    model=model,
    ref_model=None,
    args=DPOConfig(
        output_dir="./dpo_output",
        learning_rate=5e-6,
        per_device_train_batch_size=2,
        beta=0.1,
    ),
    train_dataset=preference_dataset,
    tokenizer=tokenizer,
    peft_config=lora_config,
)
trainer.train()
```

---

## Axolotl

Config-driven fine-tuning. Define everything in YAML.

### Installation
```bash
pip install axolotl
# Or from source for latest:
git clone https://github.com/OpenAccess-AI-Collective/axolotl
cd axolotl
pip install -e .
```

### Config File (config.yml)
```yaml
base_model: meta-llama/Llama-3.2-3B-Instruct
model_type: LlamaForCausalLM

load_in_4bit: true
adapter: lora
lora_r: 16
lora_alpha: 32
lora_dropout: 0.0
lora_target_modules:
  - q_proj
  - k_proj
  - v_proj
  - o_proj

datasets:
  - path: your-dataset
    type: alpaca

sequence_len: 2048
sample_packing: true

micro_batch_size: 2
gradient_accumulation_steps: 4
num_epochs: 1
learning_rate: 2e-4
optimizer: adamw_torch

output_dir: ./output
```

### Training
```bash
accelerate launch -m axolotl.cli.train config.yml
```

### Multi-Dataset Training
```yaml
datasets:
  - path: dataset1
    type: alpaca
  - path: dataset2
    type: sharegpt
  - path: dataset3
    type: completion
```

---

## LLaMA Factory

GUI-based fine-tuning with web interface.

### Installation
```bash
pip install llmtuner
# Or:
git clone https://github.com/hiyouga/LLaMA-Factory
cd LLaMA-Factory
pip install -e .
```

### Web UI
```bash
llamafactory-cli webui
```

### CLI Training
```bash
llamafactory-cli train \
    --model_name_or_path meta-llama/Llama-3.2-3B-Instruct \
    --dataset your_dataset \
    --template llama3 \
    --finetuning_type lora \
    --lora_rank 16 \
    --output_dir ./output \
    --per_device_train_batch_size 2 \
    --learning_rate 2e-4 \
    --num_train_epochs 1
```

---

## Installation

### Full Environment Setup
```bash
# Create environment
conda create -n finetune python=3.10
conda activate finetune

# Install PyTorch (check CUDA version first: nvidia-smi)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install Unsloth (fastest option)
pip install unsloth

# Or install TRL stack (most flexible)
pip install transformers trl peft accelerate bitsandbytes datasets

# Install Flash Attention (optional, speeds up training)
pip install flash-attn --no-build-isolation
```

### Google Colab Setup
```python
# Unsloth (free Colab works!)
!pip install unsloth

# Check GPU
!nvidia-smi
```

### Verify Installation
```python
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None'}")

from unsloth import FastLanguageModel
print("Unsloth loaded successfully!")
```
