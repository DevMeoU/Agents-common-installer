# Agents Common Installer

A small common installer/syncer for sharing Agent Skills and MCP server configs from one home folder source (`~/.agents`) into multiple AI coding/agent tools.

Built-in targets currently include:

- Claude / Claude Code
- OpenClaw
- Codex
- Cursor
- Gemini CLI
- OpenCode
- Windsurf
- Custom `~/.<agent>` targets

## Why

Many agent tools have similar concepts:

- **Skills**: folders containing `SKILL.md`
- **MCP servers**: JSON config blocks such as `mcpServers`

Instead of manually copying the same skills/MCP definitions into every agent config, keep a common source in:

```text
~/.agents
```

Then sync to whichever tools you use.

## Files

```text
agent-common-sync.ps1   # Main implementation
agent-common-sync.cmd   # Windows CMD wrapper
agent-common-sync.bat   # Windows BAT wrapper
agent-common-sync.sh    # macOS/Linux shell wrapper, requires pwsh
```

## Source layout

All source content is optional. The script creates `~/.agents` if missing.

```text
~/.agents/
  skills/
    some-skill/
      SKILL.md
    another-skill/
      SKILL.md
  mcp.json
  .mcp.json
  mcp/
    servers.json
    mcp.json
    code-review-graph.json       # default preset unless -SkipCodeReviewGraphMcp
    model-task-optimizer.json    # default preset unless -SkipModelTaskOptimizerMcp
  catalog/
```

### Skills

Each skill should be a folder containing a `SKILL.md` file:

```text
~/.agents/skills/my-skill/SKILL.md
```

The script copies skill folders into each selected target's skill directory.

### MCP config

The script accepts any of these files:

```text
~/.agents/mcp.json
~/.agents/.mcp.json
~/.agents/mcp/servers.json
~/.agents/mcp/mcp.json
```

Supported shapes:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "C:\\Users\\PC"]
    }
  }
}
```

or:

```json
{
  "servers": {
    "time": {
      "command": "uvx",
      "args": ["mcp-server-time"]
    }
  }
}
```

or:

```json
{
  "mcp": {
    "servers": {
      "memory": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-memory"]
      }
    }
  }
}
```

## Built-in targets

Run:

```powershell
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -ListTargets
```

Default built-ins:

```text
claude   -> ~/.claude/skills,   ~/.claude/settings.json:mcpServers
openclaw -> ~/.openclaw/skills only by default; openclaw.json writes are guarded by `-AllowOpenClawConfigWrite`
codex    -> ~/.codex/skills,    ~/.codex/mcp.json:mcpServers
cursor   -> ~/.cursor/skills,   ~/.cursor/mcp.json:mcpServers
gemini   -> ~/.gemini/skills,   ~/.gemini/mcp.json:mcpServers
opencode -> ~/.opencode/skills, ~/.opencode/mcp.json:mcpServers
windsurf -> ~/.windsurf/skills, ~/.windsurf/mcp.json:mcpServers
```

Unknown/custom target names are supported. For example:

```powershell
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets myagent -Force
```

will use:

```text
~/.myagent/skills
~/.myagent/mcp.json
```

## Catalog sources

With `-UpdateCatalog`, the script clones or updates these public sources into `~/.agents/catalog`:

- <https://github.com/DevMeoU/awesome-agent-skills>
- <https://github.com/DevMeoU/andrej-karpathy-skills>
- <https://github.com/DevMeoU/everything-claude-code>
- <https://github.com/DevMeoU/supervisor-agents-skill>
- <https://github.com/DevMeoU/template-for-skills-agent>
- <https://github.com/modelcontextprotocol/servers>
- <https://github.com/DevMeoU/code-review-graph>

Catalogs are for discovery. Review/copy selected skills into `~/.agents/skills` before syncing.

To scan public GitHub repositories for agent, skill, MCP, Claude, model, prompt, or LLM-related catalogs without requiring GitHub login, run:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ScanGithubCatalog -GithubOwner DevMeoU
```

Matched repositories are cloned or updated under `~/.agents/catalog` and then become available to `-RecommendSkills` and `-InstallRecommendedSkills`. The scan uses GitHub's public API first and falls back to `gh repo list` only if the public API is unavailable. Private repositories still require `gh auth login`.

If a useful repo has a short or ambiguous name that does not match the default metadata filter, include it explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ScanGithubCatalog -GithubOwner DevMeoU -GithubIncludeRepoNames rtk
```

Or include a family of repo names by regex, for example repositories whose names contain `ski`:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ScanGithubCatalog -GithubOwner DevMeoU -GithubIncludeRepoPattern 'ski'
```

## model-task-optimizer MCP

This repository now includes a local MCP server package in `model-task-optimizer-mcp/`.

It exposes tools for:

- listing a bundled model-family catalog
- recommending a primary/fallback model for a task
- generating a project routing policy
- tuning model settings such as temperature, context strategy, reasoning budget, prompt caching, batching, and validation

The common installer creates `~/.agents/mcp/model-task-optimizer.json` by default. When this repo is present, the preset uses the local package:

```json
{
  "mcpServers": {
    "model-task-optimizer": {
      "command": "uvx",
      "args": ["--from", "<repo>/model-task-optimizer-mcp", "model-task-optimizer-mcp"]
    }
  }
}
```

Run it manually with:

```powershell
uvx --from ./model-task-optimizer-mcp model-task-optimizer-mcp
```

Use `-SkipModelTaskOptimizerMcp` if a project should not receive this MCP preset.

## code-review-graph integration

[`code-review-graph`](https://github.com/DevMeoU/code-review-graph) builds a local code knowledge graph and exposes it to coding agents through MCP.

This installer supports it in two ways:

1. `-UpdateCatalog` clones/updates the repository into `~/.agents/catalog/code-review-graph` for discovery, including its bundled skills.
2. Normal sync runs create/sync this MCP preset by default at `~/.agents/mcp/code-review-graph.json`:

```json
{
  "mcpServers": {
    "code-review-graph": {
      "command": "uvx",
      "args": ["code-review-graph", "serve"]
    }
  }
}
```

Then sync it into your agent targets:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -Targets claude,codex,cursor -Force
```

If you only want recommendations and no MCP writes, use `-RecommendSkills` by itself or add `-SkipCodeReviewGraphMcp` to any sync run.

Notes:

- Requires Python 3.10+ and preferably `uv`/`uvx` available on PATH.
- The installer only writes MCP config; it does not run the package or build graphs automatically.
- After syncing, restart the target agent/editor, then run `code-review-graph build` in a project or ask the agent to build the code review graph.
- OpenClaw MCP config writes are still guarded; add `-AllowOpenClawConfigWrite` only after validating the current OpenClaw config schema.

## Bundled skills

This repository includes bundled skills:

```text
skills/project-skill-recommender/SKILL.md
skills/supervisor-agents/SKILL.md
skills/scrum-master/SKILL.md
skills/senior-pm/SKILL.md
skills/esp-idf-firmware/SKILL.md
```

- `project-skill-recommender` is the default repo-onboarding skill. It scans the current project and recommends/install matching skills from available catalogs.
- `supervisor-agents` is a multi-agent code and architecture supervision skill for reviewing git diffs against context, implementation plans, and ADRs.
- `scrum-master` is a baseline project-management skill for agile/sprint health and alignment workflows.
- `senior-pm` is a baseline product/project decision skill for requirements, priorities, and acceptance criteria.
- `esp-idf-firmware` is for ESP-IDF / ESP32-family firmware projects with `sdkconfig`, component CMake, partitions, build/flash/monitor workflows, and embedded safety constraints.
- `model-task-optimizer` is for selecting and tuning the best model/provider/routing tier for a task, with optional MCP support for model scoring and routing policies.

After `-UpdateCatalog`, code-review-graph skills are available under `~/.agents/catalog/code-review-graph/skills` and can be copied into `~/.agents/skills` if you want them synced as normal agent skills.

To install a bundled skill into your common source manually, copy it into `~/.agents/skills`:

```powershell
New-Item -ItemType Directory -Force ~/.agents/skills | Out-Null
Copy-Item ./skills/supervisor-agents ~/.agents/skills/supervisor-agents -Recurse -Force
```

Then sync to your targets:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -Targets claude,openclaw,codex -Force
```

## Project-based skill recommendations

The installer can inspect a project and recommend only skills that actually exist in its catalog roots (`./skills` and `~/.agents/catalog` by default). It does **not** auto-install every catalog skill.

Recommend only:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath D:\Workspace\Project\my-app -RecommendSkills
```

Recommend and install matching skills into `~/.agents/skills`, then sync targets:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath D:\Workspace\Project\my-app -InstallRecommendedSkills -Targets claude,openclaw,codex -Force
```

Install baseline + recommended project-specific assets directly into a project-local Claude setup:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath D:\Workspace\Project\my-app -ProjectInstall -Force
```

Project install currently writes:

```text
<ProjectPath>/.claude/skills/<baseline-or-recommended-skill>/
<ProjectPath>/.claude/commands/<skill-name>/...   # when a skill ships commands/
<ProjectPath>/.claude/commands/common-installer-demo.md
<ProjectPath>/.claude/commands/scrum-align.md
<ProjectPath>/.mcp.json                           # merged MCP servers from ~/.agents
```

Baseline skills are installed for every project by default because they are broadly useful:

```text
project-skill-recommender
supervisor-agents
scrum-master
senior-pm
model-task-optimizer
```

Override them with `-BaselineSkills skill-a,skill-b`, or add `-SkipCodeReviewGraphMcp` if the project should not receive the default code-review-graph MCP preset.

Project install also creates a default `.claude/commands/scrum-align.md` command. This command tells the agent to build/update `code-review-graph`, read design docs/ADR/plan, run supervisor-style review, split work into Dev/Test/QA/QC/Docs/Supervisor roles, and iterate until implementation aligns with the documented design or a human decision is required.

Use this when global `~/.claude` should stay minimal and only contain common reusable skills/commands, while project-specific recommendations live with the project.

Use custom catalog roots:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath . -RecommendSkills -SkillCatalogRoots .\skills,$HOME\.agents\catalog
```

Current heuristics look for signals such as:

- `docs/adr`, `adr`, `PLAN.md` → `supervisor-agents` when available
- `sdkconfig`, `sdkconfig.defaults`, `CMakeLists.txt`, `main/`, `partitions/`, `idf_component.yml` → `esp-idf-firmware` when available
- n8n workflow JSON containing `n8n-nodes-base` → an n8n-related skill when available
- `SKILL.md` / `template-skill` → `skill-creator` when available
- `mcp.json`, `.mcp.json`, `mcpServers`, MCP docs → `mcp-builder` when available
- AI SDK imports, provider names, evals, benchmarks, prompt configs → `model-task-optimizer` when available
- frontend, Python, Docker/CI, document files → matching skills when available in catalogs

## Usage

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -ListTargets
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -UpdateCatalog
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -Force
```

### Windows CMD/BAT

From this repo folder:

```cmd
agent-common-sync.cmd -ListTargets
agent-common-sync.cmd -UpdateCatalog
agent-common-sync.cmd -Targets all -Force
```

or:

```bat
agent-common-sync.bat -Targets claude,openclaw,codex -Force
```

### macOS/Linux

Requires PowerShell 7+ (`pwsh`).

```sh
chmod +x ./agent-common-sync.sh
./agent-common-sync.sh -ListTargets
./agent-common-sync.sh -UpdateCatalog
./agent-common-sync.sh -Targets all -Force
```

You can also run the `.ps1` directly with `pwsh`:

```sh
pwsh -NoProfile -File ./agent-common-sync.ps1 -Targets claude,openclaw -Force
```

## One-command project bootstrap

Run the whole setup for a project in one command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath D:\Workspace\Project\FlintVN\FlintOS -FullBootstrap -Force -AllowInstallUv
```

This updates catalogs, scans public DevMeoU repositories, installs project skills/commands/MCP, checks `uvx`, builds `code-review-graph` when possible, reruns recommendations, and prints a final bootstrap report. Omit `-AllowInstallUv` if the script should not install `uv` automatically.

## Useful options

```text
-Source <path>       Source directory, default: ~/.agents
-Targets <names>    Target agents, default: claude,openclaw. Use all for built-ins.
-ProjectPath <path> Project directory to inspect for skill recommendations
-RecommendSkills    Print installable skill recommendations for -ProjectPath
-InstallRecommendedSkills
                    Copy recommended skills into ~/.agents/skills before syncing targets
-ProjectInstall    Install baseline + recommended skills/commands and MCP config into -ProjectPath
-FullBootstrap    Run end-to-end bootstrap: update catalog, project install, validate, build graph, report
-AllowInstallUv   Allow -FullBootstrap to install uv with python -m pip install uv when uvx is missing
-SkipBuildCodeGraph
                  Skip code-review-graph status/build during -FullBootstrap
-Demo              Deprecated compatibility switch; common project commands are always installed
-BaselineSkills <names>
                    Always install these common project skills during -ProjectInstall
-SkillCatalogRoots <paths>
                    Search roots for installable skills, default: ./skills and ~/.agents/catalog
-UpdateCatalog      Clone/update public catalogs
-ScanGithubCatalog
                    Scan public GitHub repos for agent/skill/MCP/model-related catalogs without login; falls back to gh if needed
-GithubOwner <name>
                    GitHub owner to scan, default: DevMeoU
-GithubIncludeRepoNames <names>
                    Extra repository names to include even when metadata does not match the default filter
-GithubIncludeRepoPattern <regex>
                    Extra repository-name regex to include, for example 'ski'
-InstallCodeReviewGraphMcp
                    Explicitly add code-review-graph MCP preset; normal sync runs do this by default
-InstallModelTaskOptimizerMcp
                    Explicitly add model-task-optimizer MCP preset; normal sync runs do this by default
-SkipCodeReviewGraphMcp
                    Disable the default code-review-graph MCP preset creation/sync
-SkipModelTaskOptimizerMcp
                    Disable the default model-task-optimizer MCP preset creation/sync
-Force              Overwrite existing target skill folders
-DryRun             Show planned actions without writing
-ListTargets        Print built-in target definitions
-AllowOpenClawConfigWrite
                    Allow experimental writes to ~/.openclaw/openclaw.json. Off by default for safety.
```

## Safety

- Existing JSON config files are backed up before modification using `*.bak.YYYYMMDD-HHMMSS`.
- JSON output is parsed before writing; invalid JSON is refused.
- OpenClaw config is schema-sensitive, so `openclaw.json` is not edited by default. OpenClaw skills are copied to `~/.openclaw/skills`; use OpenClaw's supported configuration flow to enable them. Only use `-AllowOpenClawConfigWrite` after validating your OpenClaw config schema.
- Use `-DryRun` before syncing if unsure.
- The script does not auto-enable arbitrary external services or install package dependencies. MCP command definitions are copied as config only.
- Normal sync runs configure agents to run `uvx code-review-graph serve`; ensure you trust that package and have Python/uv available before using it. Use `-SkipCodeReviewGraphMcp` to disable.
- Review public catalog content before copying skills into `~/.agents/skills`.

## Example full flow

```powershell
# 1. Clone/update catalogs
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -UpdateCatalog

# 2. Manually review and copy a skill into ~/.agents/skills
# Example only:
# Copy-Item ~/.agents/catalog/some-repo/path/to/some-skill ~/.agents/skills/some-skill -Recurse

# 3. Add extra MCP config to ~/.agents/mcp.json if needed
#    code-review-graph MCP is included by default during sync runs

# 4. Preview
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -DryRun

# 5. Sync
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -Force
```
