---
name: llm-evaluation
description: "Evaluate LLM applications with task-appropriate metrics, LLM-as-judge, and regression gates. Use when building an eval suite, choosing between BLEU/ROUGE/BERTScore/judge scoring, debugging a judge that disagrees with humans, or deciding whether a prompt or model change actually improved anything."
risk: unknown
source: community
---

# LLM Evaluation

The hard part is not computing a metric — it is picking one that moves when quality
moves. Most LLM eval failures are a metric that stays flat through a real regression,
or a judge that scores a change the humans dislike.

## Use this skill when

- Standing up an eval suite for an LLM feature
- Choosing a metric for a task type
- A judge's scores disagree with human reviewers
- Gating a prompt/model change on evidence rather than vibes

## Pick the metric from the task

| Task | Use | Do not use |
|---|---|---|
| Classification, extraction, routing | Accuracy / P / R / F1 against labels | Judge scoring |
| Code generation | Execute the code; pass@k on real tests | BLEU |
| Translation, short summarization with references | chrF, BERTScore, COMET | BLEU alone |
| Open-ended generation, chat, writing | Pairwise LLM-as-judge + human spot-check | BLEU, ROUGE |
| RAG answers | Groundedness + retrieval recall@k, scored separately | End-to-end score alone |

**BLEU and ROUGE measure n-gram overlap with a reference.** For open-ended generation
there is no single correct string, so they punish valid paraphrase and reward copying.
They remain reasonable for translation and reference-bound summarization. If you cannot
name the reference, the metric is wrong for the task.

For RAG, always score retrieval and generation separately. A fused score cannot tell
"retrieved the wrong chunk" from "had the right chunk and ignored it" — and those have
opposite fixes.

## Reference-based metrics

Use a maintained library rather than hand-rolling. `evaluate` (Hugging Face) wraps most
of these with consistent inputs:

```python
import evaluate

chrf = evaluate.load("chrf")
bertscore = evaluate.load("bertscore")

preds = ["A cat is sitting on the mat"]
refs  = ["The cat sat on the mat"]

chrf.compute(predictions=preds, references=refs)
bertscore.compute(predictions=preds, references=refs, lang="en")
```

Report the distribution, not just the mean — a mean hides a bimodal split where the
model is excellent on most inputs and broken on one segment. Always look at the worst
decile by hand.

## LLM-as-judge

Pairwise beats absolute. Models are poorly calibrated on "rate this 1-10" and much more
reliable at "which of these two is better."

```python
JUDGE = """Compare two answers to the same question.

Question: {question}
A: {answer_a}
B: {answer_b}

Judge on: factual correctness first, then completeness, then clarity.
Ignore length and formatting. Think step by step, then end with exactly
one line: VERDICT: A, VERDICT: B, or VERDICT: TIE."""
```

Controls that are not optional:

- **Position bias.** Judges favor one slot. Run every pair twice with A/B swapped and
  count a flip as a tie. Without this you will measure slot order.
- **Calibrate against humans.** Hand-label 50–100 pairs, measure judge-vs-human
  agreement (Cohen's κ). Below ~0.6, fix the rubric before trusting any judge number.
- **Judge ≠ generator.** Scoring a model's output with itself inflates the score.
- **Self-consistency is not accuracy.** A judge that repeats its own verdict reliably
  can be reliably wrong.
- **Anchor every round to fixed references.** Score a few unchanging reference items
  alongside the candidate each round, and report the candidate's gap to them, not its
  absolute score. If a reference's score moves, the scale moved — in iterative loops,
  untouched references have drifted upward as the candidate improved.
- **Never tell the judge the target.** A judge told "we need 9/10" pulls toward 9.
  Keep pass thresholds in the harness, out of the judge prompt.

Judge scores are a cheap proxy for human preference, and they are only as good as that
measured agreement. Report the κ alongside the win rate or the number means nothing.

## Regression gates

The suite only earns its keep if it blocks a bad change.

```python
import json, pathlib

GOLDEN = pathlib.Path("evals/golden.jsonl")
THRESHOLD = 0.02   # absolute drop tolerated

def gate(new_scores, baseline_path="evals/baseline.json"):
    baseline = json.loads(pathlib.Path(baseline_path).read_text())
    failures = [
        (k, baseline[k], new_scores[k])
        for k in baseline
        if new_scores[k] < baseline[k] - THRESHOLD
    ]
    if failures:
        for k, old, new in failures:
            print(f"REGRESSION {k}: {old:.3f} -> {new:.3f}")
        raise SystemExit(1)
```

- Freeze a golden set and version it next to the code. An eval set that drifts with the
  model measures nothing across time.
- Keep per-segment scores, not one aggregate. Aggregates mask a regression confined to
  one input class.
- Pin temperature (ideally 0) and the model version. An unpinned model silently changes
  the baseline under you.
- Hold out a set you never iterate on. Anything you tune against is training data.

## Is the difference real?

Two prompts scoring 0.71 and 0.73 on 100 examples is usually noise.

- Paired comparison on the **same** inputs — never compare two independent samples when
  you can pair them.
- Bootstrap the difference (resample the paired per-item deltas, take the 2.5/97.5
  percentiles). If that interval straddles zero, you have no result.
- For pairwise judge wins, a binomial test on wins-vs-losses (ties dropped) is enough.
- Sample size first: detecting a 2-point difference needs hundreds of examples, not 30.

## Failure modes

- **Optimizing the metric.** Every metric becomes a target and then stops measuring.
  Re-check against humans periodically.
- **Evaluating only the happy path.** Include adversarial, empty, overlong, and
  wrong-language inputs — production has them.
- **One number for the whole system.** Score retrieval, generation, and formatting
  separately or you cannot act on a drop.
- **No human in the loop, ever.** Automated eval drifts from user-perceived quality.
  Budget a periodic manual review; it is what recalibrates everything else.
