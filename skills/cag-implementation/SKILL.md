---
name: cag-implementation
description: Build Cache-Augmented Generation (CAG) systems — preload knowledge into a HuggingFace model's KV cache instead of retrieving it at runtime. Use when the knowledge base fits in context window, knowledge is static, and low latency matters. Alternative to RAG for bounded, stable knowledge sources.
---

# Cache-Augmented Generation (CAG) Implementation

CAG eliminates real-time retrieval by preloading all knowledge into the model's KV cache once. Subsequent queries reuse the cached key-value states without re-encoding the knowledge, trading knowledge-base size for dramatically lower per-query latency.

**Paper**: https://arxiv.org/abs/2412.15605  
**Reference implementation**: https://github.com/hhhuang/CAG

---

## CAG vs RAG: When to Use Which

| Signal | Use CAG | Use RAG |
|--------|---------|---------|
| Knowledge base size | Fits in context window (≤ 128K tokens) | Millions of documents |
| Update frequency | Static or updated ≤ once/day | Real-time or frequent updates |
| Latency requirement | Hard requirement on inference speed | Latency is secondary |
| Infrastructure | GPU access for local model | API-only or cloud-hosted LLM |
| Architecture complexity | Prefer simple, fewer moving parts | OK with vector DB + retrieval pipeline |

**Rule of thumb**: If your knowledge fits in ~100 pages and changes infrequently, CAG will outperform RAG on latency and reliability.

---

## Core Pattern

```
[Knowledge Docs] → Preload once → [KV Cache on disk]
                                         ↓
                    Query → [KV Cache] + [Question tokens] → Answer
```

Three phases:
1. **Preload** — tokenize all knowledge + run a forward pass to populate the KV cache
2. **Persist** — save the KV cache to disk for reuse
3. **Query loop** — for each question, load cache, append question tokens, generate

---

## Step 1: Preload Knowledge Into KV Cache

```python
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from transformers.cache_utils import DynamicCache

# Allow DynamicCache serialization
torch.serialization.add_safe_globals([DynamicCache])
torch.serialization.add_safe_globals([set])

def preload_knowledge(knowledge_text: str, model, tokenizer, device) -> DynamicCache:
    """Tokenize knowledge and run a forward pass to populate KV cache."""
    input_ids = tokenizer(
        knowledge_text,
        return_tensors="pt",
        truncation=True,
        max_length=tokenizer.model_max_length
    ).input_ids.to(device)

    with torch.no_grad():
        outputs = model(
            input_ids=input_ids,
            use_cache=True,
            return_dict=True
        )

    return outputs.past_key_values  # DynamicCache object


def save_kv_cache(cache: DynamicCache, path: str):
    torch.save(cache, path)


def load_kv_cache(path: str) -> DynamicCache:
    return torch.load(path, weights_only=False)
```

---

## Step 2: Query Using Cached KV States

```python
def generate(
    model,
    input_ids: torch.Tensor,
    past_key_values: DynamicCache,
    max_new_tokens: int = 300,
    eos_token_id: int = None,
) -> torch.Tensor:
    """Greedy decode with KV cache reuse."""
    embed_device = model.model.embed_tokens.weight.device
    input_ids = input_ids.to(embed_device)
    output_ids = input_ids.clone()
    next_token = input_ids

    with torch.no_grad():
        for _ in range(max_new_tokens):
            outputs = model(
                input_ids=next_token,
                past_key_values=past_key_values,
                use_cache=True,
            )
            next_token_logits = outputs.logits[:, -1, :]
            next_token = next_token_logits.argmax(dim=-1).unsqueeze(0)
            output_ids = torch.cat([output_ids, next_token], dim=-1)
            past_key_values = outputs.past_key_values
            if eos_token_id and next_token.item() == eos_token_id:
                break

    return output_ids


def ask(
    question: str,
    cache_path: str,
    model,
    tokenizer,
    device,
    max_new_tokens: int = 300,
) -> str:
    """Load cache, append question, generate answer."""
    kv_cache = load_kv_cache(cache_path)

    prompt = f"\nQuestion: {question}\nAnswer:"
    input_ids = tokenizer(prompt, return_tensors="pt").input_ids.to(device)

    output_ids = generate(
        model=model,
        input_ids=input_ids,
        past_key_values=kv_cache,
        max_new_tokens=max_new_tokens,
        eos_token_id=tokenizer.eos_token_id,
    )

    # Decode only the newly generated tokens
    new_tokens = output_ids[:, input_ids.shape[-1]:]
    return tokenizer.decode(new_tokens[0], skip_special_tokens=True)
```

---

## Step 3: Full End-to-End Example

```python
import os
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from transformers.cache_utils import DynamicCache

torch.serialization.add_safe_globals([DynamicCache, set])

MODEL_ID = "meta-llama/Llama-3.2-3B-Instruct"
CACHE_PATH = "./knowledge.kvcache"
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# Load model once
tokenizer = AutoTokenizer.from_pretrained(MODEL_ID, token=os.environ["HF_TOKEN"])
model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    token=os.environ["HF_TOKEN"],
    torch_dtype=torch.float16,
    device_map="auto",
)

# --- Preload phase (run once, then reuse cache) ---
if not os.path.exists(CACHE_PATH):
    knowledge = open("knowledge.txt").read()  # Your knowledge docs concatenated
    kv_cache = preload_knowledge(knowledge, model, tokenizer, device)
    save_kv_cache(kv_cache, CACHE_PATH)
    print(f"Cache saved: {CACHE_PATH}")

# --- Query loop ---
questions = [
    "What are the main topics covered in this document?",
    "What are the key conclusions?",
]

for q in questions:
    answer = ask(q, CACHE_PATH, model, tokenizer, device)
    print(f"Q: {q}\nA: {answer}\n")
```

---

## Context Window Planning

The entire knowledge base must fit in the model's context window minus space for the question + answer.

```python
def estimate_token_budget(knowledge_text: str, tokenizer, model_max_tokens: int = 128_000) -> dict:
    """Check if knowledge fits and how much room is left for Q+A."""
    knowledge_tokens = len(tokenizer.encode(knowledge_text))
    # Reserve ~512 tokens for question + answer
    available_for_qa = model_max_tokens - knowledge_tokens - 512

    return {
        "knowledge_tokens": knowledge_tokens,
        "model_max_tokens": model_max_tokens,
        "available_for_qa": available_for_qa,
        "fits": available_for_qa > 0,
        "utilization_pct": knowledge_tokens / model_max_tokens * 100,
    }

# Example
budget = estimate_token_budget(knowledge, tokenizer, model_max_tokens=128_000)
if not budget["fits"]:
    print("Knowledge too large for CAG — consider RAG instead")
else:
    print(f"Using {budget['utilization_pct']:.1f}% of context window")
```

**Model context window reference:**
| Model | Context Window |
|-------|---------------|
| Llama 3.2 3B/8B Instruct | 128K tokens |
| Llama 3.1 70B | 128K tokens |
| Mistral 7B | 32K tokens |
| GPT-4o (API) | 128K tokens (no KV cache access) |

---

## Cache Reset Between Sessions

When knowledge is updated, regenerate the cache. When switching between different knowledge sets, use separate cache files.

```python
def invalidate_cache(cache_path: str):
    """Delete stale cache to force regeneration."""
    if os.path.exists(cache_path):
        os.remove(cache_path)
        print(f"Cache invalidated: {cache_path}")


def get_or_build_cache(knowledge_path: str, cache_path: str, model, tokenizer, device) -> str:
    """Return cache_path, building cache if stale or missing."""
    knowledge_mtime = os.path.getmtime(knowledge_path)
    cache_mtime = os.path.getmtime(cache_path) if os.path.exists(cache_path) else 0

    if knowledge_mtime > cache_mtime:
        print("Knowledge updated — rebuilding cache...")
        knowledge = open(knowledge_path).read()
        kv_cache = preload_knowledge(knowledge, model, tokenizer, device)
        save_kv_cache(kv_cache, cache_path)

    return cache_path
```

---

## Evaluation with BERT Similarity

CAG paper uses BERT cosine similarity to evaluate answer quality against ground truth.

```python
from sentence_transformers import SentenceTransformer, util

_bert = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

def bert_similarity(response: str, ground_truth: str) -> float:
    """Cosine similarity between response and ground truth via BERT embeddings."""
    q_emb = _bert.encode(response, convert_to_tensor=True)
    t_emb = _bert.encode(ground_truth, convert_to_tensor=True)
    return util.pytorch_cos_sim(q_emb, t_emb).item()


def evaluate_cag(qa_pairs: list[dict], cache_path: str, model, tokenizer, device) -> dict:
    """
    qa_pairs: list of {"question": str, "expected": str}
    Returns: {"mean_bert_similarity": float, "per_item": list[float]}
    """
    scores = []
    for item in qa_pairs:
        answer = ask(item["question"], cache_path, model, tokenizer, device)
        score = bert_similarity(answer, item["expected"])
        scores.append(score)

    return {
        "mean_bert_similarity": sum(scores) / len(scores),
        "per_item": scores,
    }
```

---

## Memory & Performance Tips

- **Float16 or BFloat16**: Always load model in `torch.float16` or `torch.bfloat16` to halve VRAM usage
- **4-bit quantization**: Use `BitsAndBytesConfig(load_in_4bit=True)` on memory-constrained GPUs — KV cache still works
- **Cache file size**: KV cache for 32K tokens with Llama 3.2 3B ≈ 500MB on disk; 128K tokens ≈ 2GB
- **Batch questions**: You can batch multiple questions in one forward pass if VRAM allows
- **CPU offload**: Use `device_map="auto"` to offload layers to CPU when GPU VRAM is insufficient

```python
# 4-bit quantization example
from transformers import BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
)

model = AutoModelForCausalLM.from_pretrained(
    MODEL_ID,
    quantization_config=bnb_config,
    device_map="auto",
    token=os.environ["HF_TOKEN"],
)
```

---

## Limitations to Communicate Upfront

1. **Knowledge size ceiling**: Knowledge must fit in the model's context window — not suitable for large corpora
2. **Local model required**: CAG requires access to model internals (KV cache); not possible with API-only models (OpenAI, Anthropic API)
3. **Context degradation**: LLMs perform worse at the middle of very long contexts — keep utilization below 80% of context window
4. **Static knowledge**: Cache is invalidated on every knowledge update; frequent updates negate the latency benefit
5. **VRAM requirements**: Large context windows require significant GPU memory; plan for 2-4x the model's base VRAM

---

## Decision Checklist Before Implementing

- [ ] Knowledge base fits in model context window (use `estimate_token_budget`)
- [ ] GPU access confirmed (or CPU acceptable with quantization)
- [ ] Knowledge update frequency ≤ once/day (otherwise cache churn defeats the purpose)
- [ ] HuggingFace model available (not API-only)
- [ ] `HF_TOKEN` env var set for gated models (Llama etc.)
- [ ] VRAM budget estimated for chosen model + context size
