---
name: supervisor-agents
description: Supervise code and architecture changes by reviewing git diffs against system context, implementation plans, and ADRs using distinct reviewer roles. Use this skill whenever the user asks to audit a PR, inspect a git diff, check whether implementation follows a plan, verify architectural decisions, compare code changes against requirements, or produce a compliance report. Especially use it when the request mentions context, plan, ADR, architecture, violations, compliance, multi-agent review, or objective supervision.
---

# Supervisor Agents

This skill guides objective supervision of code and architecture changes. It does not implement fixes. It reads the available evidence, separates the review into independent perspectives, and returns a concise compliance report.

## Core behavior

- Review only. Do not change code, docs, plans, ADRs, configs, or tests unless the user explicitly changes the task from supervision to editing.
- Ground every finding in evidence: diff hunks, file paths, plan items, ADR ids, requirements, or documented constraints.
- Prefer repository-local context over assumptions. If evidence is missing, mark the finding as unknown instead of inventing requirements.
- Keep the reviewer roles independent. If subagents are available, run them in parallel; otherwise perform the same roles as separate passes.
- Distinguish confirmed violations from risks, incomplete evidence, and optional improvements.

## Evidence to collect

Start with user-supplied paths or text. If not provided, inspect likely repository locations.

**Context candidates:**

```text
README.md
AGENTS.md
CLAUDE.md
.openclaw/
docs/
architecture/
requirements.md
```

**Plan candidates:**

```text
PLAN.md
plan.md
TODO.md
roadmap.md
docs/plan*
issue or PR description supplied by the user
```

**ADR candidates:**

```text
docs/adr/
adr/
architecture/adr/
decisions/
docs/architecture/
```

**Diff commands:**

```bash
git status --short
git diff --stat
git diff --find-renames
git diff --cached --find-renames
git log --oneline --decorate -n 10
```

If the review target is ambiguous, ask one focused question about the base branch, PR range, or paths. Otherwise continue best-effort and label gaps.

## Reviewer roles

### Diff Analyzer

Normalize what changed before judging it.

- List changed files and statuses: added, modified, deleted, renamed.
- Summarize each meaningful change by module, behavior, API, schema, config, docs, and tests.
- Flag high-risk areas: auth, permissions, persistence, migrations, public APIs, dependencies, CI/CD, secrets, deployment, and generated files.
- Identify behavior changes without corresponding tests or docs.

### Context Checker

Compare the diff to the system context.

- Check whether changed behavior preserves stated requirements, constraints, non-goals, naming conventions, security/privacy boundaries, and platform assumptions.
- Mark each point as compliant, violation, risk, or unknown.
- Avoid using context that is not present in the repository or user prompt.

### Plan Validator

Compare the diff to the implementation plan.

- Map changed files and behavior to plan steps.
- Identify plan items that are complete, partial, missing, or out of scope.
- Flag unrelated work unless the diff or user prompt justifies it.
- Recommend plan updates when the implementation is valid but intentionally diverges.

### ADR Auditor

Compare the diff to architectural decisions.

- Extract relevant decisions, rationale, constraints, and consequences from ADRs.
- Check selected technologies, data flow, boundaries, integration style, deployment assumptions, and trade-offs.
- Flag ADR drift when code contradicts a still-active decision.
- Recommend ADR updates when code is reasonable but decisions are stale or incomplete.

### Aggregator

Produce the final supervision report.

- Deduplicate overlapping findings.
- Prioritize by impact: Blocker, High, Medium, Low, Informational.
- Preserve uncertainty when context, plan, ADRs, tests, or diff range are incomplete.
- Include actionable recommendations without patching files.

## Severity rubric

- **Blocker**: Violates explicit requirements, security boundaries, data integrity, production safety, or a core active ADR.
- **High**: Likely functional regression, incompatible interface, missing migration, or major plan divergence.
- **Medium**: Partial implementation, missing tests/docs for meaningful behavior, or unclear architecture drift.
- **Low**: Minor naming, organization, documentation, or cleanup mismatch.
- **Informational**: Useful observation with no required action.

## Report structure

Always use this structure unless the user asks for another format:

```markdown
## Summary

- Overall status: Compliant | Mostly compliant | Mixed | Non-compliant | Insufficient evidence
- High-level assessment:
  - <bullet>
  - <bullet>
- Key risks: <bullets or "None found">

## Details

### Diff overview

- Changed files: <count and important files>
- Main change themes:
  - <bullet>

### Compliance

- <Finding title>
  - Evidence: <file/diff/context/plan/ADR reference>
  - Why it complies: <brief explanation>

### Violations

- <Finding title or "No confirmed violations found">
  - Severity: Blocker | High | Medium | Low
  - Evidence: <file/diff/context/plan/ADR reference>
  - Expected: <from context/plan/ADR>
  - Actual: <from diff>
  - Impact: <risk/consequence>

### Unknowns / gaps

- <Missing artifact or ambiguous requirement>
  - Needed to decide: <specific context/plan/ADR/test>

## Recommendations

1. <Actionable next step>
2. <Actionable next step>
3. <ADR/plan update suggestion if needed>
```

## Example trigger prompts

- "Review this PR against the plan and ADRs."
- "Analyze the git diff and report architecture violations."
- "Check whether these changes comply with the system context."
- "Run a multi-agent supervision review for context, plan, ADR, and diff."
