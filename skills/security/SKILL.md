---
name: security
description: Security work: audits, pentesting/CTF, secure coding, threat modeling, vuln scanning, privacy/compliance. Use when assessing, hardening, or attacking (authorized) a system.
---

# security — domain router

This is a routing skill for the **security** domain. It holds no technique itself — it lists the sub-skills in this domain so you can load the right one(s).

**How to use:** scan the table, then READ the SKILL.md at each path that genuinely helps the task with the Read tool. **Load as many as the task needs — not just one.** A task that spans sub-skills (e.g. build + test, or debug + fix infra) should pull every relevant row. Skip the rest.


| sub-skill | what it covers | path |
|---|---|---|
| `accessibility-compliance-accessibility-audit` | You are an accessibility expert specializing in WCAG compliance, inclusive design, and assistive technology compatibility. Conduct audits, identify barriers, an | `~/.claude/skill-library/accessibility-compliance-accessibility-audit/SKILL.md` |
| `ai-security-workflow` | 5-phase interactive security workflow for finding and fixing real vulnerabilities: threat-model → vuln-scan → triage → patch → close. Produces standardized arti | `~/.claude/skill-library/ai-security-workflow/SKILL.md` |
| `anti-reversing-techniques` | Understand anti-reversing, obfuscation, and protection techniques encountered during software analysis. Use when analyzing protected binaries, bypassing anti-de | `~/.claude/skill-library/anti-reversing-techniques/SKILL.md` |
| `api-security-best-practices` | Implement secure API design patterns including authentication, authorization, input validation, rate limiting, and protection against common API vulnerabilities | `~/.claude/skill-library/api-security-best-practices/SKILL.md` |
| `attack-tree-construction` | Build comprehensive attack trees to visualize threat paths. Use when mapping attack scenarios, identifying defense gaps, or communicating security risks to stak | `~/.claude/skill-library/attack-tree-construction/SKILL.md` |
| `binary-analysis-patterns` | Master binary analysis patterns including disassembly, decompilation, control flow analysis, and code pattern recognition. Use when analyzing executables, under | `~/.claude/skill-library/binary-analysis-patterns/SKILL.md` |
| `firmware-analyst` | Expert firmware analyst specializing in embedded systems, IoT | `~/.claude/skill-library/firmware-analyst/SKILL.md` |
| `gdpr-data-handling` | Implement GDPR-compliant data handling with consent management, data subject rights, and privacy by design. Use when building systems that process EU personal d | `~/.claude/skill-library/gdpr-data-handling/SKILL.md` |
| `k8s-security-policies` | Implement Kubernetes security policies including NetworkPolicy, PodSecurityPolicy, and RBAC for production-grade security. Use when securing Kubernetes clusters | `~/.claude/skill-library/k8s-security-policies/SKILL.md` |
| `laravel-security-audit` | Security auditor for Laravel applications. Analyzes code for vulnerabilities, misconfigurations, and insecure practices using OWASP standards and Laravel securi | `~/.claude/skill-library/laravel-security-audit/SKILL.md` |
| `malware-analyst` | Expert malware analyst specializing in defensive malware research, | `~/.claude/skill-library/malware-analyst/SKILL.md` |
| `memory-forensics` | Master memory forensics techniques including memory acquisition, process analysis, and artifact extraction using Volatility and related tools. Use when analyzin | `~/.claude/skill-library/memory-forensics/SKILL.md` |
| `memory-safety-patterns` | Implement memory-safe programming with RAII, ownership, smart pointers, and resource management across Rust, C++, and C. Use when writing safe systems code, man | `~/.claude/skill-library/memory-safety-patterns/SKILL.md` |
| `network-101` | This skill should be used when the user asks to \"set up a web server\", \"configure HTTP or HTTPS\", \"perform SNMP enumeration\", \"configure SMB shares\", \" | `~/.claude/skill-library/network-101/SKILL.md` |
| `oss-hunter` | Automatically hunt for high-impact OSS contribution opportunities in trending repositories. | `~/.claude/skill-library/oss-hunter/SKILL.md` |
| `pci-compliance` | Implement PCI DSS compliance requirements for secure handling of payment card data and payment systems. Use when securing payment processing, achieving PCI comp | `~/.claude/skill-library/pci-compliance/SKILL.md` |
| `penetration-testing` | Methodology and per-target playbooks for authorized penetration tests and CTFs: scoping/rules of engagement, recon-to-report phases, and concrete tool commands  | `~/.claude/skill-library/penetration-testing/SKILL.md` |
| `privacy-filter` | Use OPF (OpenAI Privacy Filter) to detect and redact PII from text, files, or codebases. Covers 8 categories including secrets/API keys, emails, phone numbers,  | `~/.claude/skill-library/privacy-filter/SKILL.md` |
| `protocol-reverse-engineering` | Master network protocol reverse engineering including packet analysis, protocol dissection, and custom protocol documentation. Use when analyzing network traffi | `~/.claude/skill-library/protocol-reverse-engineering/SKILL.md` |
| `reverse-engineer` | Expert reverse engineer specializing in binary analysis, | `~/.claude/skill-library/reverse-engineer/SKILL.md` |
| `sast-configuration` | Configure Static Application Security Testing (SAST) tools for automated vulnerability detection in application code. Use when setting up security scanning, imp | `~/.claude/skill-library/sast-configuration/SKILL.md` |
| `secrets-management` | Implement secure secrets management for CI/CD pipelines using Vault, AWS Secrets Manager, or native platform solutions. Use when handling sensitive credentials, | `~/.claude/skill-library/secrets-management/SKILL.md` |
| `secure-agent-design` | Security patterns for Claude agents that process untrusted input or run in multi-agent systems: prompt injection mitigation, find/verify isolation, serial dedup | `~/.claude/skills/secure-agent-design/SKILL.md` |
| `secure-coding` | Secure coding patterns for backend, frontend, and mobile: input validation, auth, CSRF/SSRF, XSS prevention, WebView/storage/cert-pinning. Use when writing or r | `~/.claude/skill-library/secure-coding/SKILL.md` |
| `security-audit` | Full-spectrum security audit: OWASP Top 10 review, SAST/dependency/secrets scanning, risk prioritization, and a pre-deployment checklist. Use when auditing an a | `~/.claude/skill-library/security-audit/SKILL.md` |
| `security-bluebook-builder` | Use when a sensitive application (handles auth, payment, PII, or admin access) needs a single reference document covering its assets, threats, controls, and inc | `~/.claude/skill-library/security-bluebook-builder/SKILL.md` |
| `security-compliance-compliance-check` | You are a compliance expert specializing in regulatory requirements for software systems including GDPR, HIPAA, SOC2, PCI-DSS, and other industry standards. Per | `~/.claude/skill-library/security-compliance-compliance-check/SKILL.md` |
| `security-requirement-extraction` | Derive security requirements from threat models and business context. Use when translating threats into actionable requirements, creating security user stories, | `~/.claude/skill-library/security-requirement-extraction/SKILL.md` |
| `solidity-security` | Master smart contract security best practices to prevent common vulnerabilities and implement secure Solidity patterns. Use when writing smart contracts, auditi | `~/.claude/skill-library/solidity-security/SKILL.md` |
| `stride-analysis-patterns` | Apply STRIDE methodology to systematically identify threats. Use when analyzing system security, conducting threat modeling sessions, or creating security docum | `~/.claude/skill-library/stride-analysis-patterns/SKILL.md` |
| `threat-mitigation-mapping` | Map identified threats to appropriate security controls and mitigations. Use when prioritizing security investments, creating remediation plans, or validating c | `~/.claude/skill-library/threat-mitigation-mapping/SKILL.md` |
| `threat-modeling-expert` | Expert in threat modeling methodologies, security architecture review, and risk assessment. Masters STRIDE, PASTA, attack trees, and security requirement extrac | `~/.claude/skill-library/threat-modeling-expert/SKILL.md` |
| `wcag-audit-patterns` | Conduct WCAG 2.2 accessibility audits with automated testing, manual verification, and remediation guidance. Use when auditing websites for accessibility, fixin | `~/.claude/skill-library/wcag-audit-patterns/SKILL.md` |
| `web3-testing` | Test smart contracts comprehensively using Hardhat and Foundry with unit tests, integration tests, and mainnet forking. Use when testing Solidity contracts, set | `~/.claude/skill-library/web3-testing/SKILL.md` |
| `wireshark-analysis` | This skill should be used when the user asks to \"analyze network traffic with Wireshark\", \"capture packets for troubleshooting\", \"filter PCAP files\", \"fo | `~/.claude/skill-library/wireshark-analysis/SKILL.md` |

_35 sub-skills. If none fit, the task likely belongs to another domain router._
