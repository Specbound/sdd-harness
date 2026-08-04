# Credit-Killing Patterns Reference

38 patterns that waste tokens and cause re-prompts. Read this file when the user pastes a bad prompt and asks you to fix it, or when diagnosing why a prompt is underperforming.

---

## Task Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 1 | **Vague task verb** | "help me with my code" | "Refactor `getUserData()` to use async/await and handle null returns" |
| 2 | **Two tasks in one prompt** | "explain AND rewrite this function" | Split into two prompts: explain first, rewrite second |
| 3 | **No success criteria** | "make it better" | "Done when the function passes existing unit tests and handles null input without throwing" |
| 4 | **Over-permissive agent** | "do whatever it takes" | Explicit allowed actions list + explicit forbidden actions list |
| 5 | **Emotional task description** | "it's totally broken, fix everything" | "Throws uncaught TypeError on line 43 when `user` is null" |
| 6 | **Build-the-whole-thing** | "build my entire app" | Break into Prompt 1 (scaffold), Prompt 2 (core feature), Prompt 3 (polish) |
| 7 | **Implicit reference** | "now add the other thing we discussed" | Always restate the full task — never reference "the thing we discussed" |

---

## Context Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 8 | **Assumed prior knowledge** | "continue where we left off" | Include Memory Block with all prior decisions |
| 9 | **No project context** | "write a cover letter" | "PM role at B2B fintech, 2yr SWE experience transitioning to product, shipped 3 features as tech lead" |
| 10 | **Forgotten stack** | New prompt contradicts prior tech choice | Always include Memory Block with established stack |
| 11 | **Hallucination invite** | "what do experts say about X?" | "Cite only sources you are certain of. If uncertain, say so explicitly rather than guessing." |
| 12 | **Undefined audience** | "write something for users" | "Non-technical B2B buyers, no coding knowledge, decision-maker level" |
| 13 | **No mention of prior failures** | (blank) | "I already tried X and it didn't work because Y. Do not suggest X." |

---

## Format Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 14 | **Missing output format** | "explain this concept" | "3 bullet points, each under 20 words, with a one-sentence summary at top" |
| 15 | **Implicit length** | "write a summary" | "Write a summary in exactly 3 sentences" |
| 16 | **No role assignment** | (blank) | "You are a senior backend engineer specializing in Node.js and PostgreSQL" |
| 17 | **Vague aesthetic adjectives** | "make it look professional" | "Monochrome palette, 16px base font, 24px line height, no decorative elements" |
| 18 | **No negative prompts for image AI** | "a portrait of a woman" | Add: "no watermark, no blur, no extra fingers, no distortion, no text overlay" |
| 19 | **Prose prompt for Midjourney** | Full descriptive sentence | "subject, style, mood, lighting, composition, --ar 16:9 --v 6" |

---

## Scope Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 20 | **No scope boundary** | "fix my app" | "Fix only the login form validation in `src/auth.js`. Touch nothing else." |
| 21 | **No stack constraints** | "build a React component" | "React 18, TypeScript strict, no external libraries, Tailwind only" |
| 22 | **No stop condition for agents** | "build the whole feature" | Explicit stop conditions + ✅ checkpoint output after each step |
| 23 | **No file path for IDE AI** | "update the login function" | "Update `handleLogin()` in `src/pages/Login.tsx` only" |
| 24 | **Wrong template for tool** | GPT-style prose prompt used in Cursor | Adapt to File-Scope Template (Template G) |
| 25 | **Pasting entire codebase** | Full repo context every prompt | Scope to only the relevant function and file |

---

## Reasoning Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 26 | **No CoT for logic task** | "which approach is better?" | "Think through both approaches step by step before recommending" |
| 27 | **Adding CoT to reasoning models** | "think step by step" sent to o1/o3 | Remove it — reasoning models think internally, CoT instructions degrade output |
| 28 | **Expecting inter-session memory** | "you already know my project" | Always re-provide the Memory Block in every new session |
| 29 | **Contradicting prior work** | New prompt ignores earlier architecture | Include Memory Block with all established decisions |
| 30 | **No grounding rule for factual tasks** | "summarize what experts say about X" | "Use only information you are highly confident is accurate. Say [uncertain] if not." |

---

## Agentic Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 31 | **No starting state** | "build me a REST API" | "Empty Node.js project, Express installed, `src/app.js` exists" |
| 32 | **No target state** | "add authentication" | "`/src/middleware/auth.js` with JWT verify. `POST /login` and `POST /register` in `/src/routes/auth.js`" |
| 33 | **Silent agent** | No progress output | "After each step output: ✅ [what was completed]" |
| 34 | **Unlocked filesystem** | No file restrictions | "Only edit files inside `src/`. Do not touch `package.json`, `.env`, or any config file." |
| 35 | **No human review trigger** | Agent decides everything autonomously | "Stop and ask before: deleting any file, adding any dependency, or changing the database schema" |
| 36 | **Vague first turn on Opus 4.7** | "fix the auth bug" with no scope, no files, no criteria | Opus 4.7 reads prompts literally — use Template M. Front-load intent, file scope, constraints, and acceptance criteria. |
| 37 | **Context rot on long sessions** | Keeps correcting in the same session for 60+ turns | New task = new session. Use /rewind instead of correcting. /compact at ~50% context. Subagents for file-heavy investigation. |

---

## JSON Prompting Patterns

| # | Pattern | Bad Example | Fixed |
|---|---------|------------|-------|
| 38 | **Prose with ≥3 guessable dimensions** | "write a tweet about dopamine detox" (tone? length? style? audience? all unspecified) | Switch to JSON: `{"task": "write a tweet", "topic": "dopamine detox", "tone": "punchy and contrarian", "length": "under 280 characters", "style": "viral"}`. Every key is a resolved dimension — model stops guessing. |

---

## JSON Prompting — Before/After Gallery

### Single-level: Flat dimensions

**Before (prose — 4 guessable dimensions):**
```
Write a tweet about dopamine detox.
```

**After (JSON — zero guessable dimensions):**
```json
{
  "task": "write a tweet",
  "topic": "dopamine detox",
  "style": "viral",
  "length": "under 280 characters",
  "tone": "punchy and contrarian"
}
```

---

### Nested: Structured output

**Before (prose — structure left to model):**
```
Write a Twitter thread about founder productivity.
```

**After (JSON — structure locked):**
```json
{
  "task": "write a thread",
  "platform": "twitter",
  "topic": "founder productivity",
  "tone": "direct and contrarian",
  "structure": {
    "hook": "curiosity-driven, under 10 words",
    "body": "3 insights with concrete examples",
    "cta": "question that sparks replies"
  }
}
```

---

### API / Programmatic output

**Before (prose — format ambiguous):**
```
Analyze this support ticket and tell me what's wrong.
```

**After (JSON — format, schema, and behavior locked):**
```json
{
  "task": "analyze support ticket",
  "input": "[ticket text here]",
  "output_format": "JSON",
  "output_schema": {
    "category": "authentication | billing | bug | feature_request | other",
    "severity": "low | medium | high | critical",
    "summary": "one sentence under 20 words",
    "suggested_action": "string"
  },
  "constraints": "respond only with valid JSON, no prose outside the object"
}
```

---

### When JSON is overkill (do NOT suggest it)

| Request | Why JSON adds no value |
|---------|----------------------|
| "write a haiku about rain" | One dimension. Nothing to lock. |
| "explain recursion simply" | Audience implied, format implied. No ambiguity. |
| "what's 2+2?" | No dimensions whatsoever. |
