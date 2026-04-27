---
name: model-task-optimizer
description: "Use when choosing, comparing, or tuning AI models for a task. It evaluates task requirements, latency/cost/accuracy constraints, tool needs, context size, privacy, and provider fit across current model families such as GPT, Claude Opus/Sonnet/Haiku, Gemini, Grok, Kimi, DeepSeek, Nvidia, and local/open models. Pair with the model-task-optimizer MCP server when available."
---

# Model task optimizer

## Overview

Use this skill to select and tune the best model setup for a specific job instead of defaulting to one general model.

The goal is to improve speed, accuracy, cost, and rework rate by matching model capability to task shape.

## Core workflow

1. Classify the task.
   - Coding implementation, code review, architecture, security, data analysis, summarization, planning, multimodal, agentic tool use, long-context research, or realtime interaction.
2. Capture constraints.
   - Required accuracy, latency, budget, context size, tool use, structured output, privacy, deployment location, provider availability, and retry tolerance.
3. Check available models before changing or recommending anything.
   - Read the user's available model list, project config, provider account, CLI output, or MCP `check_available_models` result.
   - If availability is unknown, stop and ask for `available_models` / `available_providers` instead of guessing.
4. Compare only available model families.
   - GPT/KenDev-API, Claude Opus/Sonnet/Haiku, Gemini, Grok, Kimi, DeepSeek, Qwen, Nvidia, and local/open models.
   - Use only models actually available in the user's environment or provider accounts; if a listed family exists in `available_models`, prefer the matching catalog entry.
5. Choose a routing tier.
   - Fast/default tier for routine edits and simple analysis.
   - Reasoning tier for architecture, debugging, security review, and high-stakes decisions.
   - Long-context tier for repository/document sweeps.
   - Low-cost batch tier for bulk classification, extraction, and repetitive transformations.
6. Tune execution.
   - Pick temperature, max output, reasoning/thinking budget when supported, prompt caching, batching, tool-call limits, retry rules, and validation checks.
7. Validate outcome.
   - Define an acceptance check: tests, exact JSON schema, reviewer pass, benchmark score, latency target, or human approval.

## Recommendation output

```markdown
## Model Recommendation

- Task type: <classification>
- Primary model: <model/provider>
- Fallback model: <model/provider>
- Why: <capability and constraint fit>
- Tuning:
  - temperature: <value>
  - context strategy: <full|chunked|retrieval|cache>
  - reasoning budget: <none|low|medium|high if supported>
  - tool use: <enabled|disabled|restricted>
- Validation: <tests/checks/metrics>
- Rework reducer: <specific guardrail>
```

## MCP usage

When the `model-task-optimizer` MCP server is configured, prefer it for:

- checking supplied available models before recommending changes
- maintaining a current provider/model catalog
- scoring task-to-model fit
- producing routing policies
- suggesting prompt-caching and batching settings
- tracking observed latency, cost, failures, and rework loops

If the MCP server is not available, provide a manual recommendation using the same output structure and state assumptions clearly.

## Rules

- Always check available models first; do not recommend or change routing when availability is unknown.
- GPT-5.5 can be kept in the reference catalog, but only select it when it appears in the confirmed available model list.
- Do not claim access to a model unless the project config or user confirms it.
- Prefer smaller/faster models for simple deterministic tasks.
- Prefer stronger reasoning models for ambiguous design, security, debugging, and cross-file changes.
- Prefer long-context models or retrieval-backed workflows for repository-scale analysis.
- Use provider-neutral language when implementation must support multiple providers.
- Re-evaluate the choice after failures, test regressions, repeated retries, or context overflow.
