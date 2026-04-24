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

Catalogs are for discovery. Review/copy selected skills into `~/.agents/skills` before syncing.

## Bundled skills

This repository includes bundled skills:

```text
skills/project-skill-recommender/SKILL.md
skills/supervisor-agents/SKILL.md
```

- `project-skill-recommender` is the default repo-onboarding skill. It scans the current project and recommends/install matching skills from available catalogs.
- `supervisor-agents` is a multi-agent code and architecture supervision skill for reviewing git diffs against context, implementation plans, and ADRs.

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

Use custom catalog roots:

```powershell
powershell -ExecutionPolicy Bypass -File ./agent-common-sync.ps1 -ProjectPath . -RecommendSkills -SkillCatalogRoots .\skills,$HOME\.agents\catalog
```

Current heuristics look for signals such as:

- `docs/adr`, `adr`, `PLAN.md` → `supervisor-agents` when available
- n8n workflow JSON containing `n8n-nodes-base` → an n8n-related skill when available
- `SKILL.md` / `template-skill` → `skill-creator` when available
- `mcp.json`, `.mcp.json`, `mcpServers`, MCP docs → `mcp-builder` when available
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

## Useful options

```text
-Source <path>       Source directory, default: ~/.agents
-Targets <names>    Target agents, default: claude,openclaw. Use all for built-ins.
-ProjectPath <path> Project directory to inspect for skill recommendations
-RecommendSkills    Print installable skill recommendations for -ProjectPath
-InstallRecommendedSkills
                    Copy recommended skills into ~/.agents/skills before syncing targets
-SkillCatalogRoots <paths>
                    Search roots for installable skills, default: ./skills and ~/.agents/catalog
-UpdateCatalog      Clone/update public catalogs
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
- Review public catalog content before copying skills into `~/.agents/skills`.

## Example full flow

```powershell
# 1. Clone/update catalogs
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -UpdateCatalog

# 2. Manually review and copy a skill into ~/.agents/skills
# Example only:
# Copy-Item ~/.agents/catalog/some-repo/path/to/some-skill ~/.agents/skills/some-skill -Recurse

# 3. Add MCP config to ~/.agents/mcp.json if needed

# 4. Preview
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -DryRun

# 5. Sync
powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -Force
```
