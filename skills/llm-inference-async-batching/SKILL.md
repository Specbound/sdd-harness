---
name: llm-inference-async-batching
description: >
  Design and implement async continuous batching for LLM inference. Eliminates
  CPU-GPU serialization via CUDA streams, dual-slot buffers, and carry-over masks.
  Use when optimizing LLM serving throughput, reviewing inference infrastructure,
  or implementing continuous batching from scratch.
metadata:
  model: inherit
source: https://huggingface.co/blog/continuous_async
---

## Use this skill when

- Building or reviewing LLM inference serving infrastructure
- GPU utilization is below ~90% in continuous batching loops
- Implementing async batch preparation to overlap CPU and GPU work
- Debugging carry-over token issues in multi-step generation pipelines
- Designing CUDA stream orchestration for transformer forward passes

## Do not use this skill when

- The bottleneck is memory bandwidth or kernel efficiency (not CPU-GPU serialization)
- Running on CPU-only or non-CUDA inference backends
- The task is unrelated to LLM serving (use `ml-engineer` for general ML)

---

## Phase 1: Diagnose — Is CPU-GPU Serialization Your Bottleneck?

Profile before assuming async batching is the fix.

```bash
# Check GPU utilization during inference
nvidia-smi dmon -s u -d 1

# Nsight Systems for CUDA stream timeline
nsys profile --trace=cuda,nvtx python serve.py
nsys-ui report1.nsys-rep  # Look for idle gaps between kernels
```

**You have the serialization problem if:**
- GPU util < 85% during sustained generation
- Nsight shows alternating CPU-busy / GPU-busy gaps (not overlapping)
- Batch prep time (scheduling, KV routing, H2D transfer) is measurable on CPU profiler

**If GPU is already > 95% utilized**, the bottleneck is elsewhere — stop here.

---

## Phase 2: Design — Core Async Architecture

Four components must work together. Read `resources/patterns.md` for implementation detail on each.

### 2a. Three CUDA Streams
```
H2D stream    → transfers batch inputs to device
Compute stream → runs model forward pass
D2H stream    → transfers outputs back to host
```
Operations within a stream are sequential; streams run concurrently.

### 2b. Event-Based Cross-Stream Sync
```python
# H2D completes → compute can start
h2d_stream.record(h2d_done)
compute_stream.wait(h2d_done)   # blocks the stream, not the CPU

# Compute completes → D2H can start  
compute_stream.record(compute_done)
d2h_stream.wait(compute_done)
```
CPU only blocks once: `d2h_done_event.synchronize()` to read outputs.

### 2c. Dual-Slot Buffers (A/B alternation)
```
Step N:   GPU processes slot A  |  CPU prepares batch N+1 into slot B
Step N+1: GPU processes slot B  |  CPU prepares batch N+2 into slot A
```
Without this, CPU preparing N+1 corrupts N's in-flight data.

### 2d. Carry-Over Mask
Requests in both batch N and N+1 need N's output token as N+1's input — but N hasn't finished yet. Solution: placeholder zeros in N+1 inputs, then patch with real tokens via carry-over mask after N completes.

---

## Phase 3: Implement — Step by Step

### Step 1: Allocate dual-slot buffers
```python
input_ids_slots  = [torch.zeros(max_batch, max_seq, device="cuda") for _ in range(2)]
output_ids_slots = [torch.zeros(max_batch, device="cuda", dtype=torch.long) for _ in range(2)]
carry_over_masks = [torch.full((max_batch,), -1, device="cuda", dtype=torch.long) for _ in range(2)]
```

### Step 2: Create streams and events
```python
h2d_stream     = torch.cuda.Stream()
compute_stream = torch.cuda.Stream()
d2h_stream     = torch.cuda.Stream()

h2d_done     = torch.cuda.Event()
compute_done = torch.cuda.Event()
d2h_done     = torch.cuda.Event()
```

### Step 3: Cold-start batch 0 synchronously
Run step 0 synchronously (no prior slot to alternate with). Then enter the async loop.

### Step 4: Async loop
```python
slot = 0
for step in range(num_steps):
    next_slot = 1 - slot

    # CPU: prepare next batch into next_slot (while GPU runs current)
    prepare_batch(next_slot, scheduler, carry_over_masks[next_slot])

    # Enqueue next batch transfers and compute (non-blocking)
    with torch.cuda.stream(h2d_stream):
        transfer_to_device(input_ids_slots[next_slot])
        h2d_stream.record_event(h2d_done)

    with torch.cuda.stream(compute_stream):
        compute_stream.wait_event(h2d_done)
        outputs[next_slot] = model(input_ids_slots[next_slot])
        compute_stream.record_event(compute_done)

    with torch.cuda.stream(d2h_stream):
        d2h_stream.wait_event(compute_done)
        output_ids_slots[next_slot].copy_(outputs[next_slot], non_blocking=True)
        d2h_stream.record_event(d2h_done)

    # Block CPU to read current slot outputs (batch `step`)
    d2h_done.synchronize()
    process_outputs(output_ids_slots[slot])

    slot = next_slot
```

### Step 5: CUDA Graph capture (optional, for production)
Capture the compute + carry-over kernel into a CUDA graph. Use a shared memory pool so slot A and slot B graphs don't double VRAM:
```python
pool = torch.cuda.graph_pool_handle()
graph_A = capture_graph(slot=0, pool=pool)
graph_B = capture_graph(slot=1, pool=pool)
```
See `resources/patterns.md` → "CUDA Graph Memory Pool" for capture recipe.

---

## Phase 4: Verify

```python
# Utilization target
assert gpu_util > 95, f"Expected >95% GPU util, got {gpu_util}%"

# Correctness: async output must match sync baseline
sync_outputs  = run_synchronous_baseline(prompts)
async_outputs = run_async_batching(prompts)
assert sync_outputs == async_outputs, "Carry-over mismatch — check mask indices"

# Throughput
assert async_tps > sync_tps * 1.18, "Expected ≥18% throughput gain"
```

**Common failure modes → see `resources/patterns.md` → "Debugging"**

---

## Reference

Full pattern implementations, carry-over mask algorithm, CUDA graph capture recipe, and debugging guide: `resources/patterns.md`

HuggingFace Transformers reference implementation:
- Entry point: `src/transformers/generation/continuous_batching/continuous_api.py`
- Async logic: `ContinuousBatchingAsyncIOs` class in `input_outputs.py`
