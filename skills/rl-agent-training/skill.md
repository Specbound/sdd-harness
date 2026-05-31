---
name: rl-agent-training
description: Guide for training LLM agents with online reinforcement learning using ART (Agent Reinforcement Trainer). Use when the user wants to "train an agent with RL", "improve agent performance without labeled data", "use GRPO on a live agent", "make a small model outperform GPT-4 on a specific task", mentions rollout functions, reward functions, RULER, trajectory collection, or wants to fix production agent behavior by retraining. SKIP for static batch fine-tuning on labeled datasets — use llm-fine-tuning instead.
---

# RL Agent Training with ART

Train live agents via online reinforcement learning — run the agent many times, score each attempt, update weights toward successful behaviors.

## When ART Works (All Three Required)

1. **30% baseline**: The base model succeeds at least 30% of the time already. If it never succeeds, it has nothing to reinforce.
2. **Verifiable reward**: You can score whether a run succeeded — programmatically or via LLM judge.
3. **Safe to repeat**: The agent can run many times without real-world side effects (no emails sent, no DB mutations in prod).

If any condition fails, fix that first (prompt-engineer to 30%, build a sandbox, define a reward signal).

## ART vs. Static Fine-Tuning

| Situation | Use |
|---|---|
| You have labeled input→output pairs | `llm-fine-tuning` (SFT) |
| You can run the agent and score outcomes | ART (this skill) |
| You want to warm-start before RL | SFT first, then ART |
| Production behavioral bug to fix | ART — add the failing case as a scenario |
| No GPU / need cloud GPU | ART Serverless Backend |

## Install

```bash
pip install openpipe-art
```

ART uses a **client/server split**: your rollout code runs on your machine (or any cloud); the GPU backend runs vLLM + GRPO training separately.

```bash
# Start local backend (requires GPU with 24GB+ VRAM for 7B models)
art run

# Or use W&B Serverless backend (no local GPU needed)
# Configure WANDB_API_KEY in .env
```

## Core Data Model

```
Trajectory       — one agent attempt: messages + reward score
TrajectoryGroup  — N parallel attempts at the same scenario
                   (GRPO normalizes scores within the group —
                    only relative ranking matters, not absolute values)
Scenario         — a task instance the agent is run through
TrainableModel   — your model + LoRA adapter, tracked across steps
```

## Minimal Training Loop

```python
import art
from art.local import LocalBackend   # or art.serverless.ServerlessBackend

TRAIN_STEPS = 100
ROLLOUTS_PER_GROUP = 8   # parallel attempts per scenario

# 1. Define model
model = art.TrainableModel(
    name="my-agent-v1",
    project="my-project",
    base_model="Qwen/Qwen2.5-7B-Instruct",  # or any HF model
)

# 2. Connect backend
backend = LocalBackend()
await model.register(backend)

# 3. Define rollout — runs your agent once, returns a scored Trajectory
async def rollout(model: art.Model, scenario, is_validation=False) -> art.Trajectory:
    trajectory = art.Trajectory()
    client = model.openai_client()   # instrumented OpenAI-compatible client

    messages = [{"role": "user", "content": scenario["prompt"]}]

    # Multi-turn agent loop
    while not done:
        response = await client.chat.completions.create(
            model="default",   # ART routes to current LoRA
            messages=messages,
        )
        assistant_msg = response.choices[0].message
        messages.append({"role": "assistant", "content": assistant_msg.content})

        # ... execute tools, update messages ...

        if terminal_condition:
            done = True

    trajectory.messages = messages
    trajectory.reward = compute_reward(outcome, scenario)   # your scoring logic
    return trajectory

# 4. Training loop
for step in range(await model.get_step(), TRAIN_STEPS):
    train_groups = await art.gather_trajectory_groups(
        (
            art.TrajectoryGroup(
                rollout(model, scenario) for _ in range(ROLLOUTS_PER_GROUP)
            )
            for scenario in train_scenarios
        ),
        pbar_desc=f"step {step}",
    )

    result = await backend.train(model, train_groups, learning_rate=1e-5)
    await model.log(train_groups, metrics=result.metrics, step=result.step)
```

## Reward Function Design

The reward is the only signal that guides learning. Design it carefully.

### Binary (simplest, works well)
```python
trajectory.reward = 1.0 if task_succeeded else 0.0
```

### Partial credit (for multi-step tasks)
```python
score = 0.0
if found_answer: score += 0.5
if answer_correct: score += 0.3
if used_minimal_tool_calls: score += 0.2
trajectory.reward = score
```

### RULER — LLM-as-judge, no labeled data needed

RULER ranks trajectories within a group comparatively. Since GRPO only needs relative ranking, absolute scores don't matter — just "which runs were better than others."

```python
from art.rewards import ruler_score_group

train_groups = await art.gather_trajectory_groups(
    (...),
    after_each=ruler_score_group(
        group,
        judge_model="openai/o4-mini",     # or "anthropic/claude-sonnet-4-5"
        rubric="""
        Score this agent's performance on the email search task.
        High scores: found the right email, cited correct sender and date.
        Low scores: wrong email, hallucinated details, excessive tool calls.
        """,
        debug=True,
    ),
)
```

**When to use RULER:** You can describe good vs. bad behavior but can't write a verifiable function. RULER is slower and costs judge-model API calls, but removes the need for labeled data entirely.

**When to use a function:** Prefer a programmatic reward whenever possible — faster, cheaper, more consistent.

## Backend Setup

### Local (GPU required)
```python
from art.local import LocalBackend
backend = LocalBackend()
```
Requires: 24GB+ VRAM for 7B, 40GB+ for 14B. Runs vLLM locally.

### Serverless (W&B managed GPU)
```python
from art.serverless import ServerlessBackend
backend = ServerlessBackend()
```
Requires `WANDB_API_KEY` in `.env`. Spins up ephemeral GPU via W&B Training. Best for: no local GPU, or distributed training.

## LangGraph Integration

```python
from art.langgraph import wrap_rollout
from langchain.chat_models import init_chat_model   # ART patches this

@wrap_rollout
async def rollout(model: art.Model, scenario, is_validation=False):
    # init_chat_model is intercepted by ART to track messages
    llm = init_chat_model(model=model)

    graph = build_my_langgraph_agent(llm=llm)
    result = await graph.ainvoke({"input": scenario["prompt"]})

    trajectory = art.Trajectory()
    trajectory.reward = score_result(result, scenario)
    return trajectory
```

## MCP Integration (MCP•RL)

ART can auto-generate training scenarios for any MCP server — no manual scenario writing needed.

```python
# ART queries the MCP server, discovers tools, generates scenarios
from art.mcp import MCPTrainer

trainer = MCPTrainer(
    mcp_server_command="npx my-mcp-server",
    model=model,
    backend=backend,
)
await trainer.run(steps=50)
```

## SFT Warm-Up Pattern

If the model succeeds <30% of the time, SFT first to reach the threshold:

```python
# Step 1: SFT on a small set of hand-labeled examples
await backend.train_sft(model, sft_data_path="examples.jsonl")

# Step 2: Use SFT adapter as base for RL
model_rl = art.TrainableModel(
    name="my-agent-v1-rl",
    project="my-project",
    base_model=".art/my-project/my-agent-v1/step-20/",  # SFT checkpoint
)
```

## Custom Metrics

Track anything in addition to reward:

```python
trajectory.metrics["correctness"] = 1.0 if answer_matches else 0.0
trajectory.metrics["tool_calls"] = len(tool_call_messages)
trajectory.metrics["tokens_used"] = response.usage.total_tokens
# All metrics auto-average within the group and log to W&B
```

## Validation Split

Evaluate on held-out scenarios to catch overfitting:

```python
val_groups = await art.gather_trajectory_groups(
    (
        art.TrajectoryGroup(
            rollout(model, scenario, is_validation=True)
            for _ in range(4)
        )
        for scenario in val_scenarios
    ),
)
await model.log(val_groups, split="val", step=step)
# Logged separately in W&B — does not feed into training
```

## Resuming a Run

ART checkpoints every step. Resume from where you left off:

```python
for step in range(await model.get_step(), TRAIN_STEPS):
    # model.get_step() returns the last completed step
    ...
```

## Iteration Checklist (Training Not Improving)

- [ ] Is success rate above 30%? If not, do SFT warm-up first.
- [ ] Is there reward variance within groups? (All-0 or all-1 groups teach nothing — increase group size or vary scenarios)
- [ ] Is the reward signal correlated with what you actually want? (Check trajectory logs)
- [ ] Are you using RULER? Check judge model output with `debug=True`
- [ ] Is learning rate too high? Try 5e-6 instead of 1e-5
- [ ] Do training scenarios cover the real distribution? Add harder/diverse cases
- [ ] Is validation reward improving even if training reward plateaus? (Good sign)
- [ ] Check W&B loss curves: loss should decrease, not flat-line from step 1

## Cost Reference

| Setup | GPU | Typical Cost |
|---|---|---|
| 7B model, 50 steps | A100 80GB | ~$15–30 |
| 14B model, 100 steps | 2× A100 | ~$50–100 |
| Serverless (W&B) | Managed | ~$20–200 depending on steps |

Training runs rarely exceed $200. Re-running to fix a production bug: ~$20.

## .env Setup

```bash
WANDB_API_KEY=...          # required for serverless or logging
OPENAI_API_KEY=...         # for RULER judge or GPT-based scenarios
ANTHROPIC_API_KEY=...      # for Claude-based judge
HF_TOKEN=...               # for private HF models
```

## References

- ART GitHub: https://github.com/OpenPipe/ART
- ART docs: https://art.openpipe.ai
- Related skills: [[llm-fine-tuning]] (SFT/DPO warm-up), [[evaluation]] (offline evaluation design), [[multi-agent-patterns]] (sub-agent training architectures)
