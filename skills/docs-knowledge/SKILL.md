---
name: docs-knowledge
description: Docs, writing & knowledge work: READMEs/API docs, wikis, tutorials, diagrams, planning, research, briefings, office formats. Use when documenting, planning, researching, or writing.
---

# docs-knowledge — domain router

This is a routing skill for the **docs-knowledge** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `audio-transcriber` | Transform audio recordings into professional Markdown documentation with intelligent summaries using LLM integration | `~/.claude/skill-library/audio-transcriber/SKILL.md` |
| `beautiful-prose` | Hard-edged writing style contract for timeless, forceful English prose without AI tics | `~/.claude/skill-library/beautiful-prose/SKILL.md` |
| `brainstorming` | Use before creative or constructive work (features, architecture, behavior) to turn a vague idea into a validated design through structured dialogue before any  | `~/.claude/skill-library/brainstorming/SKILL.md` |
| `brand-guidelines-anthropic` | Applies Anthropic's official brand colors and typography to any sort of artifact that may benefit from having Anthropic's look-and-feel. Use it when brand color | `~/.claude/skill-library/brand-guidelines-anthropic/SKILL.md` |
| `context-optimization` | Use when designing, debugging, or cutting cost in context-constrained agent systems — covers context anatomy, degradation patterns, compression/compaction strat | `~/.claude/skill-library/context-optimization/SKILL.md` |
| `daily-news-report` | Scrapes content based on a preset URL list, filters high-quality technical information, and generates daily Markdown reports. | `~/.claude/skill-library/daily-news-report/SKILL.md` |
| `decision-archaeology` | /why-style dig: trace a line/file/function back through git blame → commit → PR/issue → chat context to answer 'why does this exist'. Use when the reason behind | `~/.claude/skill-library/decision-archaeology/SKILL.md` |
| `diagram-design` | Generate branded, editorial-quality diagrams (HTML+SVG) styled from a target site's colors/fonts, instead of generic Mermaid boxes-and-arrows. Use when a user w | `~/.claude/skill-library/diagram-design/SKILL.md` |
| `doc-coauthoring` | Guide users through a structured workflow for co-authoring documentation. Use when user wants to write documentation, proposals, technical specs, decision docs, | `~/.claude/skill-library/doc-coauthoring/SKILL.md` |
| `document-parsing` | Parse PDF/DOCX/XLSX/PPTX/images locally with liteparse for RAG ingestion, agent vision workflows, or structured data extraction. Invoke before building any RAG  | `~/.claude/skills/document-parsing/SKILL.md` |
| `documentation` | Write and generate documentation — READMEs, API references (OpenAPI/REST/GraphQL), long-form architecture manuals, code walkthroughs for onboarding, and step-by | `~/.claude/skill-library/documentation/SKILL.md` |
| `docx-official` | Comprehensive document creation, editing, and analysis with support for tracked changes, comments, formatting preservation, and text extraction. When Claude nee | `~/.claude/skill-library/docx-official/SKILL.md` |
| `file-organizer` | Intelligently organizes files and folders by understanding context, finding duplicates, and suggesting better organizational structures. Use when user wants to  | `~/.claude/skill-library/file-organizer/SKILL.md` |
| `grill-with-docs` | Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decis | `~/.claude/skill-library/grill-with-docs/SKILL.md` |
| `internal-comms-anthropic` | A set of resources to help me write all kinds of internal communications, using the formats that my company likes to use. Claude should use this skill whenever  | `~/.claude/skill-library/internal-comms-anthropic/SKILL.md` |
| `ktx-data-context` | Use when building a data agent or adding analytics capability to a project that queries a warehouse. Guides ktx setup (semantic layer + MCP server) so agents ge | `~/.claude/skill-library/ktx-data-context/SKILL.md` |
| `mermaid-expert` | Create Mermaid diagrams for flowcharts, sequences, ERDs, and | `~/.claude/skill-library/mermaid-expert/SKILL.md` |
| `obsidian-clipper-template-creator` | Guide for creating templates for the Obsidian Web Clipper. Use when you want to create a new clipping template, understand available variables, or format clippe | `~/.claude/skill-library/obsidian-clipper-template-creator/SKILL.md` |
| `office-productivity` | Office productivity workflow covering document creation, spreadsheet automation, presentation generation, and integration with LibreOffice and Microsoft Office  | `~/.claude/skill-library/office-productivity/SKILL.md` |
| `pdf-official` | Comprehensive PDF manipulation toolkit for extracting text and tables, creating new PDFs, merging/splitting documents, and handling forms. When Claude needs to  | `~/.claude/skill-library/pdf-official/SKILL.md` |
| `podcast-generation` | Generate AI-powered podcast-style audio narratives using Azure OpenAI's GPT Realtime Mini model via WebSocket. Use when building text-to-speech features, audio  | `~/.claude/skill-library/podcast-generation/SKILL.md` |
| `pptx-official` | Presentation creation, editing, and analysis. When Claude needs to work with presentations (.pptx files) for: (1) Creating new presentations, (2) Modifying or e | `~/.claude/skill-library/pptx-official/SKILL.md` |
| `reference-builder` | Creates exhaustive technical references and API documentation. | `~/.claude/skill-library/reference-builder/SKILL.md` |
| `research-engineer` | An uncompromising Academic Research Engineer. Operates with absolute scientific rigor, objective criticism, and zero flair. Focuses on theoretical correctness,  | `~/.claude/skill-library/research-engineer/SKILL.md` |
| `storm-research` | Research a topic from 5 adversarial perspectives, map their contradictions, synthesize a reliability-ranked briefing, then self-peer-review for bias. Use before | `~/.claude/skill-library/storm-research/SKILL.md` |
| `synthesizing-daily-briefings` | Maintains projects.md/people.md context files and synthesizes a daily prioritized briefing from connected sources (git, GitHub, Jira, Slack) — evidence required | `~/.claude/skill-library/synthesizing-daily-briefings/SKILL.md` |
| `team-collaboration-standup-notes` | You are an expert team communication specialist focused on async-first standup practices, AI-assisted note generation from commit history, and effective remote  | `~/.claude/skill-library/team-collaboration-standup-notes/SKILL.md` |
| `tool-failure-memory` | Use when a tool-failure recall warning appears before a Bash/MCP call, a command fails 2+ times in a session, or reviewing the tool-failure ledger. Covers the c | `~/.claude/skills/tool-failure-memory/SKILL.md` |
| `wiki` | Generate a browsable project wiki from a codebase — structure catalogue, deep research, page writing, onboarding guides, changelog, Q&A, and a VitePress site bu | `~/.claude/skill-library/wiki/SKILL.md` |
| `writing-behavior-specs` | Authors and revises BEHAVIOR.md specs that capture recurring, judgeable agent conduct for this project. A BEHAVIOR.md is answer-key material for reviewing trace | `~/.claude/skill-library/writing-behavior-specs/SKILL.md` |
| `writing-plans` | Use to write or execute a multi-step implementation/research plan before touching code: choosing plan weight, bite-sized task format, file-based planning for lo | `~/.claude/skill-library/writing-plans/SKILL.md` |
| `xlsx-official` | Comprehensive spreadsheet creation, editing, and analysis with support for formulas, formatting, data analysis, and visualization. When Claude needs to work wit | `~/.claude/skill-library/xlsx-official/SKILL.md` |
| `youtube-summarizer` | Extract transcripts from YouTube videos and generate comprehensive, detailed summaries using intelligent analysis frameworks | `~/.claude/skill-library/youtube-summarizer/SKILL.md` |

_33 sub-skills. If none fit, the task likely belongs to another domain router._
