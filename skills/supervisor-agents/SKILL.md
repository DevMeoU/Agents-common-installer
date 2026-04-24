---
name: supervisor-agents
description: Multi-agent code and architecture supervision for reviewing git diffs against system context, implementation plans, and ADRs. Use when asked to inspect changes, audit compliance, validate whether code follows a plan, check architectural decision records, or produce objective supervision reports with Summary, Details, and Recommendations. Designed for workflows with roles such as Diff Analyzer, Context Checker, Plan Validator, ADR Auditor, and Aggregator.
---

# Supervisor Agents

Use this skill to supervise code and architecture changes without modifying code. Produce an objective report that compares git diff against the available system context, implementation plan, and ADRs.

## Operating rules

- Do not change source code, plans, ADRs, or configs unless the user explicitly changes the task from supervision to editing.
- Treat context, plan, and ADR as evidence. If any are missing, state the gap clearly instead of inventing requirements.
- Prefer repository-local evidence over assumptions.
- Use parallel agents when available; otherwise simulate the roles as independent sections in one pass.
- Keep findings traceable to files, diff hunks, plan items, ADR ids, or context excerpts.
- Separate confirmed violations from risks or missing information.

## Inputs to collect

Collect these artifacts before judging compliance:

1. **Context**: system description, requirements, constraints, architecture overview, README, design docs, user-provided context.
2. **Plan**: implementation plan, task list, issue description, milestone, TODO, roadmap, PR description.
3. **ADR**: architecture decision records and decision logs, usually in `docs/adr`, `adr`, `architecture`, or similar folders.
4. **Diff**: current git diff, staged diff, branch comparison, or PR diff.

If paths are not supplied, inspect likely locations:

```text
README.md
AGENTS.md
CLAUDE.md
.openclaw/
docs/
docs/adr/
adr/
architecture/
plan.md
PLAN.md
requirements.md
```

Use git commands for diff evidence:

```bash
git status --short
git diff --stat
git diff --find-renames
git diff --cached --find-renames
git log --oneline --decorate -n 10
```

## Multi-agent roles

### Agent Diff Analyzer

Normalize the change set:

- List changed files with status: added, modified, deleted, renamed.
- Summarize each meaningful diff by purpose, touched modules, APIs, schemas, config, tests, docs.
- Identify high-risk changes: public interfaces, auth, persistence, migrations, dependencies, security, config, CI/CD.
- Note missing tests or docs when code behavior changes.

### Agent Context Checker

Compare diff against context:

- Check whether changes preserve stated system boundaries and constraints.
- Detect mismatches with domain rules, non-goals, platform assumptions, naming conventions, security/privacy expectations.
- Mark each finding as compliant, violation, risk, or unknown.

### Agent Plan Validator

Compare diff against plan:

- Map changed files and behavior to plan steps.
- Identify plan items implemented, partially implemented, missing, or out-of-scope.
- Flag work that appears unrelated to the plan unless justified.
- Identify plan updates needed when implementation intentionally diverges.

### Agent ADR Auditor

Compare diff against ADRs:

- Extract relevant ADR decisions, rationale, constraints, and consequences.
- Verify code follows selected technologies, boundaries, data flow, integration rules, deployment assumptions, and trade-offs.
- Flag contradictions and ADR drift.
- Recommend ADR updates only when the implementation is valid but the decision record is stale or incomplete.

### Agent Aggregator

Synthesize the independent findings:

- Deduplicate overlapping findings.
- Prioritize by impact: blocker, high, medium, low, informational.
- Preserve dissent or uncertainty when evidence is incomplete.
- Produce final report in the required format.

## Report format

Use this exact structure unless the user requests another format:

```markdown
## Summary

- Overall status: Compliant | Mostly compliant | Mixed | Non-compliant | Insufficient evidence
- High-level assessment: <1-3 bullets>
- Key risks: <bullets or "None found">

## Details

### Diff overview

- Changed files: <count/list>
- Main change themes: <bullets>

### Compliance

- <Finding title>
  - Evidence: <file/diff/context/plan/ADR reference>
  - Why it complies: <brief explanation>

### Violations

- <Finding title>
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

If there are no violations, write `No confirmed violations found` under Violations.

## Severity rubric

- **Blocker**: Breaks explicit requirement, security boundary, data integrity, production safety, or core ADR decision.
- **High**: Likely functional regression, incompatible interface, missing migration, or major plan divergence.
- **Medium**: Partial implementation, missing tests/docs for meaningful behavior, unclear architecture drift.
- **Low**: Naming, organization, minor documentation mismatch, non-critical cleanup.
- **Informational**: Observation without required action.

## Recommended workflow

1. Read user-supplied context, plan, and ADR paths first.
2. If missing, inspect likely repository docs and state what was found.
3. Run git status and diff commands.
4. Analyze with the five roles.
5. Produce the final report only; do not patch files.

## Escalation rules

Ask one focused question only if supervision is impossible without it, for example:

- No git repository or diff exists.
- No context/plan/ADR is available and the user expects strict compliance judgment.
- The requested base branch or PR range is ambiguous.

Otherwise continue with best-effort analysis and clearly label unknowns.
