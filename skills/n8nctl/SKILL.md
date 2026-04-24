---
name: n8nctl
description: "Use this skill whenever the user wants to create, validate, deploy, debug, or manage n8n workflows with an agent-friendly CLI instead of clicking the n8n UI or hand-writing fragile REST API calls. Triggers include: n8n workflow JSON, n8n automation, n8nctl, workflow validate/deploy/debug, execution logs, n8n REST API, webhook workflows, and offline workflow validation. Do NOT use for non-n8n automation or generic coding tasks unrelated to n8n workflows."
license: Proprietary. LICENSE.txt has complete terms
---

# n8nctl workflow automation

## Overview

Use `n8nctl` as an agent-friendly control plane for n8n. Prefer CLI commands and offline validation over clicking the UI or manually composing raw HTTP calls.

## Quick Reference

| Task | Approach |
|------|----------|
| Create workflow | Generate workflow JSON, then validate before deploy |
| Validate workflow | Run offline validator and fix reported issues |
| Deploy workflow | Use n8nctl deploy/import command after validation |
| Debug workflow | Inspect execution logs and failed node details |
| Manage lifecycle | Use CLI for list/get/update/activate/deactivate/delete |

## Core Rules

- Validate workflow JSON before deployment.
- Do not hardcode secrets in workflow JSON; use credentials or environment references.
- Prefer commands with JSON output when available so agents can parse results reliably.
- Treat deploy/delete/activate as external side effects; ask before running against production.
- If n8nctl is unavailable, explain the missing dependency instead of falling back to fragile raw API calls unless explicitly requested.

## Recommended Workflow

1. Understand the user's automation goal.
2. Draft or modify workflow JSON.
3. Validate with the offline validator.
4. Fix structural, referential, expression, secrets, node sanity, and parameter type issues.
5. Deploy only after validation passes.
6. Run or trigger a test execution.
7. Inspect execution logs and report the result.

## Validation Layers

| Layer | Checks |
|------|--------|
| Structural | Required workflow fields, nodes, connections |
| Referential | Connections point to existing nodes |
| Expression | n8n expression syntax and references |
| Secrets leak | API keys/passwords/tokens hardcoded in JSON |
| Node sanity | Required node parameters and likely runtime issues |
| Parameter types | Boolean/number/object/array/enum mismatches |

## Output Structure

```markdown
## Summary

- Workflow: <name>
- Status: Validated | Deployed | Failed | Needs input

## Details

- Validation findings:
- Deployment/execution result:

## Recommendations

1. <next step>
```

## Dependencies

- `n8nctl` CLI from `github.com/trngthnh369/n8nctl`.
- n8n API URL and credentials for deploy/runtime operations.
