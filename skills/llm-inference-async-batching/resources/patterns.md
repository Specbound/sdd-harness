# Async Continuous Batching — Reference Patterns

Source: https://huggingface.co/blog/continuous_async

---

## The Core Problem

Synchronous continuous batching serializes CPU and GPU work:

```
[CPU prep batch N] → [GPU compute batch N] → [CPU prep batch N+1] → [GPU compute N+1] ...
                                         ↑ idle gap ↑
```

~24% of total runtime wasted in CPU-GPU handoff gaps. On H200s at $5/hour, this is measurable money.

**Target state:**
```
[GPU: compute batch N     ]
      [CPU: prep batch N+1]
                           [GPU: compute batch N+1     ]
                                 [CPU: prep batch N+2  ]
```

---

## Pattern 1: CUDA Streams

A CUDA stream is an ordered queue of GPU operations. Operations in the **same stream** are sequential. Operations in **different streams** can run concurrently.

```python
import torch

# Default stream = synchronizing (don't use for async)
h2d_stream     = torch.cuda.Stream()  # Host-to-device transfers
compute_stream = torch.cuda.Stream()  # Model forward pass
d2h_stream     = torch.cuda.Stream()  # Device-to-host transfers

# Enqueue work on a stream (non-blocking from CPU perspective)
with torch.cuda.stream(compute_stream):
    output = model(inputs)  # GPU will execute this; CPU continues immediately
```

---

## Pattern 2: CUDA Events for Cross-Stream Ordering

Without synchronization, compute_stream might start before h2d_stream finishes uploading inputs.

```python
h2d_done     = torch.cuda.Event()
compute_done = torch.cuda.Event()
d2h_done     = torch.cuda.Event()

# Record event into h2d_stream when transfer completes
with torch.cuda.stream(h2d_stream):
    inputs.to("cuda", non_blocking=True)
    h2d_stream.record_event(h2d_done)

# Compute stream waits for h2d — stream blocks, CPU does NOT block
with torch.cuda.stream(compute_stream):
    compute_stream.wait_event(h2d_done)
    output = model(inputs)
    compute_stream.record_event(compute_done)

# D2H waits for compute
with torch.cuda.stream(d2h_stream):
    d2h_stream.wait_event(compute_done)
    output_cpu.copy_(output, non_blocking=True)
    d2h_stream.record_event(d2h_done)

# CPU blocks ONLY here — one sync point per step
d2h_done.synchronize()
```

**Key rule:** `stream.wait_event(e)` blocks the *stream* until `e` fires. It does not block the CPU thread. The CPU can continue preparing the next batch while this waits.

---

## Pattern 3: Dual-Slot Buffers

**Problem:** CPU writing batch N+1 inputs while GPU reads batch N inputs from the same buffer → race condition / data corruption.

**Solution:** Allocate two slots and alternate:

```python
MAX_BATCH = 64
MAX_SEQ   = 2048

# Two input slots, two output slots
input_slots  = [torch.zeros(MAX_BATCH, MAX_SEQ, device="cuda", dtype=torch.long) for _ in range(2)]
output_slots = [torch.zeros(MAX_BATCH, device="cuda", dtype=torch.long) for _ in range(2)]

slot = 0
for step in range(steps):
    next_slot = 1 - slot

    # CPU writes next batch into next_slot
    fill_inputs(input_slots[next_slot], scheduler.next_batch())

    # GPU processes current slot
    with torch.cuda.stream(compute_stream):
        out = model(input_slots[slot])
        output_slots[slot].copy_(out)

    slot = next_slot
```

Memory cost: 2× input/output buffer size. Usually negligible vs. KV cache.

---

## Pattern 4: Carry-Over Mask

**Problem:** Request R is in both batch N and batch N+1. Its input token for step N+1 is the output token from step N — but the GPU hasn't finished step N yet when we're building step N+1.

**Solution:**
1. Use placeholder token `0` for R's position in batch N+1 inputs
2. After batch N completes, overwrite the placeholder using the carry-over mask

**Carry-over mask format:**
```
mask[i] = j   → output token from batch N position i goes to batch N+1 position j
mask[i] = -1  → request i does not continue into batch N+1
```

**Implementation (4 ops, captured in CUDA graph):**
```python
def apply_carry_over(output_tokens_N, input_ids_N1, carry_mask):
    # 1. Select tokens that carry over
    carry_tokens = output_tokens_N[carry_mask.clamp(min=0)]

    # 2. Zero out positions that don't carry (mask[i]==-1 → zero)
    carry_tokens = carry_tokens * (carry_mask >= 0).long()

    # 3. Truncate to N+1 batch length
    carry_tokens = carry_tokens[:input_ids_N1.shape[0]]

    # 4. Add to inputs (safe because placeholders are 0)
    input_ids_N1 += carry_tokens
```

**Building the carry-over mask** (CPU, during batch prep):
```python
def build_carry_mask(batch_N_requests, batch_N1_requests, max_batch):
    mask = torch.full((max_batch,), -1, dtype=torch.long)
    n1_index = {req.id: i for i, req in enumerate(batch_N1_requests)}
    for i, req in enumerate(batch_N_requests):
        if req.id in n1_index:
            mask[i] = n1_index[req.id]
    return mask
```

---

## Pattern 5: CUDA Graph Memory Pool

CUDA graphs are bound to specific memory addresses. Without a pool, capturing graph A and graph B doubles the VRAM reserved for graph memory.

**Solution:** Share a pool between both slot graphs. They never execute concurrently (batch N must complete before N+1 starts), so the same physical memory can serve both.

```python
pool = torch.cuda.graph_pool_handle()

def capture_graph(slot, pool):
    g = torch.cuda.CUDAGraph()
    # Warm-up (required before capture)
    for _ in range(3):
        model(input_slots[slot])
    with torch.cuda.graph(g, pool=pool):
        output_slots[slot] = model(input_slots[slot])
        apply_carry_over(output_slots[slot], input_slots[1-slot], carry_masks[slot])
    return g

graph_A = capture_graph(slot=0, pool=pool)
graph_B = capture_graph(slot=1, pool=pool)

# Usage in async loop
graph_A.replay()  # Re-runs captured ops on same memory
```

**VRAM cost:** `max(size_A, size_B)` instead of `size_A + size_B`.

---

## Full Async Loop

```python
def run_async(scheduler, model, steps):
    slot = 0

    # Cold start: run step 0 synchronously
    fill_inputs(input_slots[0], scheduler.next_batch())
    run_synchronous_step(slot=0)
    process_outputs(output_slots[0], scheduler)

    for step in range(1, steps):
        next_slot = 1 - slot

        # ── CPU SIDE (overlaps with previous GPU step) ──────────────────
        evict_finished(scheduler)
        admit_new_requests(scheduler)
        update_kv_cache_routing(scheduler)
        fill_inputs(input_slots[next_slot], scheduler.next_batch())  # placeholders for carry-over
        carry_masks[next_slot] = build_carry_mask(
            scheduler.batch(slot), scheduler.batch(next_slot), MAX_BATCH
        )

        # ── ENQUEUE NEXT GPU STEP ────────────────────────────────────────
        with torch.cuda.stream(h2d_stream):
            input_slots[next_slot].record_stream(h2d_stream)
            h2d_stream.record_event(h2d_done)

        with torch.cuda.stream(compute_stream):
            compute_stream.wait_event(h2d_done)
            graph_B.replay() if next_slot == 1 else graph_A.replay()
            compute_stream.record_event(compute_done)

        with torch.cuda.stream(d2h_stream):
            d2h_stream.wait_event(compute_done)
            output_cpu[next_slot].copy_(output_slots[next_slot], non_blocking=True)
            d2h_stream.record_event(d2h_done)

        # ── BLOCK CPU TO READ CURRENT SLOT ──────────────────────────────
        d2h_done.synchronize()
        process_outputs(output_slots[slot], scheduler)

        slot = next_slot
```

---

## Performance Reference

Measured on 8B model, batch size 32, 8K context, H200:

| Metric | Sync | Async | Delta |
|---|---|---|---|
| GPU Utilization | 76.0% | 99.4% | +23.4pp |
| Total Time | 300.6s | 234.5s | -22% |
| Throughput | baseline | +28% tokens/s | |

Theoretical max gain = idle gap fraction (~24%). Achieved 22% (gap: unavoidable sync points).

---

## Debugging

### Outputs don't match synchronous baseline
→ Carry-over mask is wrong. Check: `mask[i]` should be the **index in batch N+1** of the request at position `i` in batch N (not the request ID).

### GPU utilization still low after async implementation  
→ CPU batch prep is longer than GPU compute time. Profile `fill_inputs` and `build_carry_mask`. The GPU can only stay busy if CPU prep < GPU compute.

### CUDA graph replay fails with "invalid memory access"
→ Buffer addresses changed between capture and replay. Ensure `input_slots` and `output_slots` are allocated once and reused — never reallocated. Resize-on-demand patterns break graph capture.

### OOM after adding second graph slot
→ Not using a shared pool. Pass `pool=torch.cuda.graph_pool_handle()` to both graph captures.

### Occasional wrong token at position 0 of batch N+1
→ Carry-over was applied before H2D transfer completed. Ensure `h2d_stream.wait_event(carry_mask_ready)` before the H2D transfer of next_slot inputs, or apply carry-over after D2H sync on the compute stream side.
