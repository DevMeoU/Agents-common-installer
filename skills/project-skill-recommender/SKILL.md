---
name: project-skill-recommender
description: "Use this skill by default at the start of work in a repository or whenever the user asks what skills/tools should be installed for the current project. It scans the current project/repo, identifies relevant Agent Skills from available catalogs, and recommends installing only the skills that match the repo's files, docs, frameworks, workflows, ADRs, MCP config, or deliverables. Triggers include: new project setup, repo onboarding, install needed skills, recommend skills, project capability scan, check current repo, or before doing specialized work where missing skills may help. Do NOT use to blindly install every catalog skill; only recommend or install explicit matches."
license: Proprietary. LICENSE.txt has complete terms
---

# Project skill recommender

## Overview

Use this skill as a default repo-onboarding step. Its job is to inspect the current project, identify which Agent Skills are relevant, and recommend installation only when a matching skill exists in the configured catalogs.

The goal is to keep agents capable without flooding them with unnecessary skills.

## Quick Reference

| Task | Approach |
|------|----------|
| Recommend skills | Run `agent-common-sync.ps1 -ProjectPath <repo> -RecommendSkills` |
| Install recommended skills | Run `agent-common-sync.ps1 -ProjectPath <repo> -InstallRecommendedSkills -Targets <targets>` |
| Refresh catalogs | Run `agent-common-sync.ps1 -UpdateCatalog` |
| Avoid over-installing | Only install skills backed by project evidence |

## Core Rules

- Scan the current repository before recommending skills.
- Recommend only skills that exist in the configured skill catalog roots.
- Do not install all catalog skills.
- Prefer `-RecommendSkills` first; use `-InstallRecommendedSkills` only when the user wants automatic installation.
- Keep OpenClaw config safety unchanged; do not write `openclaw.json` unless explicitly allowed.
- Explain why each skill is recommended using project evidence.

## Workflow

### Step 1: Identify the project root

Use the user's provided path. If none is supplied, use the current working directory or git root.

### Step 2: Refresh catalogs when needed

If recommendations are empty but the project clearly needs specialized skills, refresh catalogs:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -UpdateCatalog
```

### Step 3: Recommend skills

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath <repo-path> -RecommendSkills
```

Review output:

```text
Skill                 Reason                                  Source
-----                 ------                                  ------
supervisor-agents     Project has ADR/plan signals             ...
mcp-builder           MCP config or docs detected              ...
frontend-design       Frontend project signals detected        ...
```

### Step 4: Install only if useful

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath <repo-path> -InstallRecommendedSkills -Targets claude,openclaw,codex -Force
```

### Step 5: Report outcome

Tell the user:

- which skills were recommended
- why they were recommended
- which ones were installed
- which targets were synced
- whether any useful skills were unavailable because catalogs were missing

## Recommendation Signals

| Project signal | Candidate skill |
|----------------|-----------------|
| `docs/adr`, `adr`, `PLAN.md`, `plan.md` | `supervisor-agents` |
| `SKILL.md`, `template-skill/SKILL.md` | `skill-creator` |
| `mcp.json`, `.mcp.json`, `mcpServers`, MCP docs | `mcp-builder` |
| `package.json`, Vite, Next, React app files | `frontend-design` |
| `pyproject.toml`, `requirements.txt`, `setup.py` | Python-related skill when available |
| `Dockerfile`, `docker-compose`, `.github/workflows` | DevOps-related skill when available |
| `.docx`, `.xlsx`, `.pptx`, `.pdf` | document skills when available |
| n8n workflow JSON containing `n8n-nodes-base` | n8n-related skill when available |

## Output Structure

```markdown
## Summary

- Project: <path>
- Recommendation status: <found|none|catalog missing>

## Recommended Skills

- <skill>
  - Reason: <project evidence>
  - Source: <skill path>

## Installation

- Installed: <skills or none>
- Targets synced: <targets or none>

## Next Steps

1. <next action>
```

## Dependencies

- `agent-common-sync.ps1` from Agents Common Installer.
- Skill catalogs under `./skills` and/or `~/.agents/catalog`.
