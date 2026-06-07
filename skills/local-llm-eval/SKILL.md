---
name: local-llm-eval
description: "Use when evaluating prompts against local Ollama models, comparing outputs across models, or running reproducible offline prompt tests. Examples: 'test this prompt against llama', 'compare mistral vs gemma on this task', 'run this prompt 5 times and see variance', 'evaluate prompt quality without cloud APIs'"
---

# Local LLM Evaluation with OMT

Zero-dependency Python CLI for running prompts against local Ollama models and saving all responses to disk. Results are keyed on prompt hash so multi-model runs land in the same folder for side-by-side comparison.

## When to Activate

- User wants to test a prompt against a local model
- User wants to compare two or more Ollama models on the same task
- User is iterating on a prompt and needs reproducible outputs
- User wants to evaluate temperature sensitivity (run N times, observe variance)
- User needs offline evaluation — no cloud API, no cost

## When NOT to Use

- Ollama not installed or not running locally
- Task requires cloud-only models (GPT-4, Claude, Gemini)
- Single quick inference → use `ollama run <model> "<prompt>"` directly

## Phase 1: Pre-flight

Check Ollama is running:

```bash
curl -s http://localhost:11434/api/tags | python3 -c "import sys,json; models=json.load(sys.stdin).get('models',[]); print('\n'.join(m['name'] for m in models))"
```

If no output or connection refused: `ollama serve` (background) then retry.

## Phase 2: Identify Test Parameters

Before running, decide:

| Parameter | Guidance |
|---|---|
| **Model** | Which model(s) to test. For comparison, pick 2–3 with different sizes/families. |
| **Runs** | 1 for quick check. 3–5 to observe variance. 10+ for statistical sampling. |
| **Temperature** | 0.0 for deterministic. 0.7–0.8 for typical creative/reasoning. 1.0+ for diversity testing. |
| **Streaming** | `--no-stream` for batch/scripted use. `--stream` to watch output live. |

## Phase 3: Run OMT

**Interactive (recommended for first-time):**
```bash
python3 .claude/scripts/ollama_model_test.py
```

**Non-interactive (scriptable, no prompts):**
```bash
python3 .claude/scripts/ollama_model_test.py \
  --model llama3.1:8b \
  --prompt-file prompt.txt \
  --runs 3 \
  --temperature 0.7 \
  --no-stream
```

**Multi-model comparison (shell loop):**
```bash
PROMPT_FILE=prompt.txt
for model in llama3.1:8b gemma3:4b mistral:7b; do
  python3 .claude/scripts/ollama_model_test.py \
    --model "$model" \
    --prompt-file "$PROMPT_FILE" \
    --runs 1 \
    --temperature 0.0 \
    --no-stream
done
```
All three outputs land in the same `ollama-runs/<slug>_<hash>/` folder.

## Phase 4: Read Results

Output structure:
```
ollama-runs/
  <prompt-slug>_<8-char-hash>/
    prompt.md          # full prompt + hash + timestamp
    metadata.json      # run history across all models
    llama3.1-8b.md     # responses + token counts + timing
    gemma3-4b.md
    mistral-7b.md
```

To read results from Claude Code:
```bash
ls ollama-runs/
cat ollama-runs/<folder>/metadata.json   # quick overview of all runs
cat ollama-runs/<folder>/<model>.md      # full responses
```

Key metadata fields:
- `runs_completed` — how many succeeded
- `options.temperature` — what temperature was used
- Per-run: `eval_count` (output tokens), `eval_duration` (ns), `total_duration` (ns)

## Phase 5: Iterate

**Prompt didn't perform well?**
1. Edit `prompt.txt`
2. Re-run with same model → new folder (different hash) in `ollama-runs/`
3. Compare new folder vs old folder

**Temperature too random?**
- Lower temperature toward 0.0 for more deterministic output
- Use `--runs 5` at fixed temperature to measure residual variance

**Model too slow?**
- Try a smaller quantization: `llama3.1:8b-instruct-q4_K_M` vs `llama3.1:8b`
- Check `total_duration` in metadata.json

## Common Workflows

### Prompt quality check before production
```bash
echo "Summarize the following in 3 bullet points: ..." > prompt.txt
python3 .claude/scripts/ollama_model_test.py \
  --model llama3.1:8b --prompt-file prompt.txt --runs 3 --temperature 0.3 --no-stream
```

### Model selection for a task
```bash
for m in llama3.1:8b gemma3:4b phi3:mini; do
  python3 .claude/scripts/ollama_model_test.py \
    --model $m --prompt-file task.txt --runs 1 --temperature 0.0 --no-stream
done
# Read ollama-runs/<folder>/ — compare quality + timing
```

### Variance / stability audit
```bash
python3 .claude/scripts/ollama_model_test.py \
  --model llama3.1:8b --prompt-file prompt.txt --runs 10 --temperature 0.8 --no-stream
# 10 responses in same .md file — scan for consistency
```
