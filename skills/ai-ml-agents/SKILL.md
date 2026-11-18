---
name: ai-ml-agents
description: AI/ML and agent systems: LLM apps, RAG, embeddings/vector search, prompt engineering, multi-agent orchestration, eval, fine-tuning, generative media. Use when building AI features or agents.
---

# ai-ml-agents — domain router

This is a routing skill for the **ai-ml-agents** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `agent-evaluation` | Testing and benchmarking LLM agents including behavioral testing, capability assessment, reliability metrics, and production monitoring\u2014where even top agen | `~/.claude/skill-library/agent-evaluation/SKILL.md` |
| `agent-execution-control` | Patterns for controlling long-horizon autonomous agent execution: Plan-Execute-Verify loops, action validation (gatekeeper), execution trace grounding, and iter | `~/.claude/skill-library/agent-execution-control/SKILL.md` |
| `agent-manager-skill` | Control coding-agent CLI panes/sessions running in the terminal — start, prompt, wait on lifecycle state, read output. Prefers Herdr (github.com/herdrdev/herdr) | `~/.claude/skill-library/agent-manager-skill/SKILL.md` |
| `agent-memory-consolidation` | Detect and prevent consolidation loop drift — the failure mode where iterative LLM rewrites of agent memory degrade quality below no-memory baseline. Covers thr | `~/.claude/skill-library/agent-memory-consolidation/SKILL.md` |
| `agent-memory-systems` | Use when designing or debugging agent memory: choosing a memory tier/type, scoring or ranking retrieved memories, picking file vs. structured (vector/graph) sto | `~/.claude/skill-library/agent-memory-systems/SKILL.md` |
| `agent-orchestration-improve-agent` | Systematic improvement of existing agents through performance analysis, prompt engineering, and continuous iteration. | `~/.claude/skill-library/agent-orchestration-improve-agent/SKILL.md` |
| `agentic-rl-tito` | TITO correctness invariant for multi-turn RL training loops on tool-calling LLMs, including harness-mediated RL where the trainer does not own the token buffer. | `~/.claude/skill-library/agentic-rl-tito/SKILL.md` |
| `ai-engineer` | Build production-ready LLM applications, advanced RAG systems, and | `~/.claude/skill-library/ai-engineer/SKILL.md` |
| `ai-ml` | AI and machine learning workflow covering LLM application development, RAG implementation, agent architecture, ML pipelines, and AI-powered features. | `~/.claude/skill-library/ai-ml/SKILL.md` |
| `ai-native-org-patterns` | Advisory framework for applying AI-native engineering patterns to a team or org — process audit, JIT planning, AI/human review tiering, and adoption metrics. Us | `~/.claude/skill-library/ai-native-org-patterns/SKILL.md` |
| `ai-product` | Every product will be AI-powered. The question is whether you'll build it right or ship a demo that falls apart in production.  This skill covers LLM integratio | `~/.claude/skill-library/ai-product/SKILL.md` |
| `ai-surface-audit` | This skill should be used when auditing the local AI-agent attack surface — installed MCP servers, CLI agents, and their capabilities (execute, hold secrets, br | `~/.claude/skill-library/ai-surface-audit/SKILL.md` |
| `ai-wrapper-product` | Expert in building products that wrap AI APIs (OpenAI, Anthropic, etc.) into focused tools people will pay for. Not just 'ChatGPT but different' - products that | `~/.claude/skill-library/ai-wrapper-product/SKILL.md` |
| `algorithmic-art` | Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users request creating art using code, generati | `~/.claude/skill-library/algorithmic-art/SKILL.md` |
| `bullmq-specialist` | BullMQ expert for Redis-backed job queues, background processing, and reliable async execution in Node.js/TypeScript applications. Use when: bullmq, bull queue, | `~/.claude/skill-library/bullmq-specialist/SKILL.md` |
| `cag-implementation` | Build Cache-Augmented Generation (CAG) systems — preload knowledge into a HuggingFace model's KV cache instead of retrieving it at runtime. Use when the knowled | `~/.claude/skill-library/cag-implementation/SKILL.md` |
| `claude-ally-health` | A health assistant skill for medical information analysis, symptom tracking, and wellness guidance. | `~/.claude/skill-library/claude-ally-health/SKILL.md` |
| `claude-api` | Anthropic SDK usage guidance — prompt-instruction anti-patterns that hurt frontier-model cost/accuracy, effort-calibration methodology, and model-selection poin | `~/.claude/skill-library/claude-api/SKILL.md` |
| `claude-code-guide` | Master guide for using Claude Code effectively. Includes configuration templates, prompting strategies \\\"Thinking\\\" keywords, debugging techniques, and best | `~/.claude/skill-library/claude-code-guide/SKILL.md` |
| `claude-d3js-skill` | Creating interactive data visualisations using d3.js. This skill should be used when creating custom charts, graphs, network diagrams, geographic visualisations | `~/.claude/skill-library/claude-d3js-skill/SKILL.md` |
| `claude-scientific-skills` | Use when running scientific research or data-analysis tasks that require documented uncertainty, reproducibility, and a clear separation between raw observation | `~/.claude/skill-library/claude-scientific-skills/SKILL.md` |
| `claude-speed-reader` | -Speed read Claude's responses at 600+ WPM using RSVP with Spritz-style ORP highlighting | `~/.claude/skill-library/claude-speed-reader/SKILL.md` |
| `claude-win11-speckit-update-skill` | Use when updating an existing GitHub SpecKit installation on Windows 11 without clobbering local customizations. Performs a hash-diff + 3-way merge against the  | `~/.claude/skill-library/claude-win11-speckit-update-skill/SKILL.md` |
| `competitor-alternatives` | When the user wants to create competitor comparison or alternative pages for SEO and sales enablement. Also use when the user mentions 'alternative page,' 'vs p | `~/.claude/skill-library/competitor-alternatives/SKILL.md` |
| `computer-use-agents` | Build AI agents that interact with computers like humans do - viewing screens, moving cursors, clicking buttons, and typing text. Covers Anthropic's Computer Us | `~/.claude/skill-library/computer-use-agents/SKILL.md` |
| `computer-vision-expert` | SOTA Computer Vision Expert (2026). Specialized in YOLO26, Segment Anything 3 (SAM 3), Vision Language Models, and real-time spatial analysis. | `~/.claude/skill-library/computer-vision-expert/SKILL.md` |
| `context7-auto-research` | Automatically fetch latest library/framework documentation for Claude Code via Context7 API | `~/.claude/skill-library/context7-auto-research/SKILL.md` |
| `crewai` | Expert in CrewAI - the leading role-based multi-agent framework used by 60% of Fortune 500 companies. Covers agent design with roles and goals, task definition, | `~/.claude/skill-library/crewai/SKILL.md` |
| `crypto-bd-agent` | Autonomous crypto business development patterns — multi-chain token discovery, 100-point scoring with wallet forensics, x402 micropayments, ERC-8004 on-chain | `~/.claude/skill-library/crypto-bd-agent/SKILL.md` |
| `data-scientist` | Expert data scientist for advanced analytics, machine learning, and | `~/.claude/skill-library/data-scientist/SKILL.md` |
| `deep-research` | Execute autonomous multi-step research using Google Gemini Deep Research Agent. Use for: market analysis, competitive landscaping, literature reviews, technical | `~/.claude/skill-library/deep-research/SKILL.md` |
| `dispatching-parallel-agents` | Use when 2+ independent tasks (investigations, fixes, specialist reviews) can run without shared state — covers the Agent tool invocation patterns, fan-out-for- | `~/.claude/skill-library/dispatching-parallel-agents/SKILL.md` |
| `embedding-strategies` | Select and optimize embedding models for semantic search and RAG applications. Use when choosing embedding models, implementing chunking strategies, or optimizi | `~/.claude/skill-library/embedding-strategies/SKILL.md` |
| `error-debugging-multi-agent-review` | Use when working with error debugging multi agent review | `~/.claude/skill-library/error-debugging-multi-agent-review/SKILL.md` |
| `evaluation` | Router for the evaluation skill family. Use when any kind of agent evaluation is needed — per-run grading, population patterns, long trajectories, or A/B test d | `~/.claude/skill-library/evaluation/SKILL.md` |
| `exa-search` | Semantic search, similar content discovery, and structured research using Exa API | `~/.claude/skill-library/exa-search/SKILL.md` |
| `fal` | Call fal.ai models via the fal_client Python SDK — text-to-image/video generation, image editing (inpainting/style transfer), upscaling, TTS/STT audio, multi-mo | `~/.claude/skill-library/fal/SKILL.md` |
| `firecrawl-scraper` | Deep web scraping, screenshots, PDF parsing, and website crawling using Firecrawl API | `~/.claude/skill-library/firecrawl-scraper/SKILL.md` |
| `fp-ts-pragmatic` | A practical, jargon-free guide to fp-ts functional programming - the 80/20 approach that gets results without the academic overhead. Use when writing TypeScript | `~/.claude/skill-library/fp-ts-pragmatic/SKILL.md` |
| `gemini-api-dev` | Use this skill when building applications with Gemini models, Gemini API, working with multimodal content (text, images, audio, video), implementing function ca | `~/.claude/skill-library/gemini-api-dev/SKILL.md` |
| `hosted-agents-v2-py` | Build hosted agents using Azure AI Projects SDK with ImageBasedHostedAgentDefinition. Use when creating container-based agents in Azure AI Foundry. | `~/.claude/skill-library/hosted-agents-v2-py/SKILL.md` |
| `hugging-face-cli` | Execute Hugging Face Hub operations using the `hf` CLI. Use when the user needs to download models/datasets/spaces, upload files to Hub repositories, create rep | `~/.claude/skill-library/hugging-face-cli/SKILL.md` |
| `hugging-face-jobs` | This skill should be used when users want to run any workload on Hugging Face Jobs infrastructure. Covers UV scripts, Docker-based jobs, hardware selection, cos | `~/.claude/skill-library/hugging-face-jobs/SKILL.md` |
| `imagen` | | | `~/.claude/skill-library/imagen/SKILL.md` |
| `instrument-agent` | Set up Raindrop AI traces for an agent and verify they flow into Workshop. | `~/.claude/skill-library/instrument-agent/SKILL.md` |
| `langchain-architecture` | Design LLM applications using the LangChain framework with agents, memory, and tool integration patterns. Use when building LangChain applications, implementing | `~/.claude/skill-library/langchain-architecture/SKILL.md` |
| `langfuse` | Expert in Langfuse - the open-source LLM observability platform. Covers tracing, prompt management, evaluation, datasets, and integration with LangChain, LlamaI | `~/.claude/skill-library/langfuse/SKILL.md` |
| `langgraph` | Expert in LangGraph - the production-grade framework for building stateful, multi-actor AI applications. Covers graph construction, state management, cycles and | `~/.claude/skill-library/langgraph/SKILL.md` |
| `linear-claude-skill` | Manage Linear issues, projects, and teams | `~/.claude/skill-library/linear-claude-skill/SKILL.md` |
| `llm-app-patterns` | Production-ready patterns for building LLM applications. Covers RAG pipelines, agent architectures, prompt IDEs, and LLMOps monitoring. Use when designing AI ap | `~/.claude/skill-library/llm-app-patterns/SKILL.md` |
| `llm-application-dev-ai-assistant` | You are an AI assistant development expert specializing in creating intelligent conversational interfaces, chatbots, and AI-powered applications. Design compreh | `~/.claude/skill-library/llm-application-dev-ai-assistant/SKILL.md` |
| `llm-application-dev-langchain-agent` | You are an expert LangChain agent developer specializing in production-grade AI systems using LangChain 0.1+ and LangGraph. | `~/.claude/skill-library/llm-application-dev-langchain-agent/SKILL.md` |
| `llm-evaluation` | Implement comprehensive evaluation strategies for LLM applications using automated metrics, human feedback, and benchmarking. Use when testing LLM performance,  | `~/.claude/skill-library/llm-evaluation/SKILL.md` |
| `llm-fine-tuning` | Guide for fine-tuning and training LLM models using LoRA, QLoRA, SFT, DPO, and GRPO methods. Use when user asks to "fine-tune a model", "train an LLM", "create  | `~/.claude/skill-library/llm-fine-tuning/SKILL.md` |
| `llm-inference-async-batching` | Design and implement async continuous batching for LLM inference. Eliminates CPU-GPU serialization via CUDA streams, dual-slot buffers, and carry-over masks. | `~/.claude/skill-library/llm-inference-async-batching/SKILL.md` |
| `local-llm-eval` | Use when evaluating prompts against local Ollama models, comparing outputs across models, or running reproducible offline prompt tests. Examples: 'test this pro | `~/.claude/skill-library/local-llm-eval/SKILL.md` |
| `machine-learning-ops-ml-pipeline` | Design and implement a complete ML pipeline for: $ARGUMENTS | `~/.claude/skill-library/machine-learning-ops-ml-pipeline/SKILL.md` |
| `ml-engineer` | Build production ML systems with PyTorch 2.x, TensorFlow, and | `~/.claude/skill-library/ml-engineer/SKILL.md` |
| `ml-pipeline-workflow` | Build end-to-end MLOps pipelines from data preparation through model training, validation, and production deployment. Use when creating ML pipelines, implementi | `~/.claude/skill-library/ml-pipeline-workflow/SKILL.md` |
| `mlops-engineer` | Build comprehensive ML pipelines, experiment tracking, and model | `~/.claude/skill-library/mlops-engineer/SKILL.md` |
| `multi-agent-patterns` | Activate when designing multi-agent systems, implementing supervisor/swarm/hierarchical patterns, coordinating subagents, choosing a workflow pattern, or scopin | `~/.claude/skill-library/multi-agent-patterns/SKILL.md` |
| `nanobanana-ppt-skills` | Use when asked to turn a document or outline into a styled PPT image deck (and optionally a transition video) via Google's Gemini image model (nicknamed "Nano B | `~/.claude/skill-library/nanobanana-ppt-skills/SKILL.md` |
| `notebooklm` | Use this skill to query your Google NotebookLM notebooks directly from Claude Code for source-grounded, citation-backed answers from Gemini. Browser automation, | `~/.claude/skill-library/notebooklm/SKILL.md` |
| `prompt-caching` | Caching strategies for LLM prompts including Anthropic prompt caching, response caching, and CAG (Cache Augmented Generation) Use when: prompt caching, cache pr | `~/.claude/skill-library/prompt-caching/SKILL.md` |
| `prompt-engineering` | Use when writing or optimizing prompts, commands, skills, or sub-agent instructions: selecting a prompting technique/framework, routing phrasing to a specific t | `~/.claude/skill-library/prompt-engineering/SKILL.md` |
| `prompt-quality-assess` | Pre-flight 6-dimension quality rubric for agent prompts — apply before every Agent or Workflow tool call to score and improve prompt quality before spawning | `~/.claude/skill-library/prompt-quality-assess/SKILL.md` |
| `quant-analyst` | Build financial models, backtest trading strategies, and analyze | `~/.claude/skill-library/quant-analyst/SKILL.md` |
| `rag-architect` | Use when the user asks to design RAG pipelines, optimize retrieval strategies, choose embedding models, implement vector search, or build knowledge retrieval sy | `~/.claude/skill-library/rag-architect/SKILL.md` |
| `rag-engineer` | Expert in building Retrieval-Augmented Generation systems. Masters embedding models, vector databases, chunking strategies, and retrieval optimization for LLM a | `~/.claude/skill-library/rag-engineer/SKILL.md` |
| `rag-implementation` | Build Retrieval-Augmented Generation (RAG) systems for LLM applications with vector databases and semantic search. Use when implementing knowledge-grounded AI,  | `~/.claude/skill-library/rag-implementation/SKILL.md` |
| `rl-agent-training` | Guide for training LLM agents with online reinforcement learning using ART (Agent Reinforcement Trainer). Use when the user wants to "train an agent with RL", " | `~/.claude/skill-library/rl-agent-training/SKILL.md` |
| `search-specialist` | Expert web researcher using advanced search techniques and | `~/.claude/skill-library/search-specialist/SKILL.md` |
| `setup-agent-replay` | Set up a local agent replay server for Raindrop Workshop. Use when the user wants Workshop to replay a captured trace against their real local agent code and to | `~/.claude/skill-library/setup-agent-replay/SKILL.md` |
| `similarity-search-patterns` | Implement efficient similarity search with vector databases. Use when building semantic search, implementing nearest neighbor queries, or optimizing retrieval p | `~/.claude/skill-library/similarity-search-patterns/SKILL.md` |
| `tavily-web` | Web search, content extraction, crawling, and research capabilities using Tavily API | `~/.claude/skill-library/tavily-web/SKILL.md` |
| `varlock-claude-skill` | Secure environment variable management ensuring secrets are never exposed in Claude sessions, terminals, logs, or git commits | `~/.claude/skill-library/varlock-claude-skill/SKILL.md` |
| `vector-database-engineer` | Expert in vector databases, embedding strategies, and semantic search implementation. Masters Pinecone, Weaviate, Qdrant, Milvus, and pgvector for RAG applicati | `~/.claude/skill-library/vector-database-engineer/SKILL.md` |
| `vector-index-tuning` | Optimize vector index performance for latency, recall, and memory. Use when tuning HNSW parameters, selecting quantization strategies, or scaling vector search  | `~/.claude/skill-library/vector-index-tuning/SKILL.md` |
| `voice-agents` | Voice agents represent the frontier of AI interaction - humans speaking naturally with AI systems. The challenge isn't just speech recognition and synthesis, it | `~/.claude/skill-library/voice-agents/SKILL.md` |
| `voice-ai-development` | Expert in building voice AI applications - from real-time voice agents to voice-enabled apps. Covers OpenAI Realtime API, Vapi for voice agents, Deepgram for tr | `~/.claude/skill-library/voice-ai-development/SKILL.md` |
| `voice-ai-engine-development` | Build real-time conversational AI voice engines using async worker pipelines, streaming transcription, LLM agents, and TTS synthesis with interrupt handling and | `~/.claude/skill-library/voice-ai-engine-development/SKILL.md` |
| `workflow-patterns` | Use this skill when implementing tasks according to Conductor's TDD | `~/.claude/skill-library/workflow-patterns/SKILL.md` |

_82 sub-skills. If none fit, the task likely belongs to another domain router._
