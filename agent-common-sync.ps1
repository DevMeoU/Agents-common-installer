<#
.SYNOPSIS
  Common Agent asset syncer: install skills and MCP configs from ~/.agents to multiple AI agents.

.DESCRIPTION
  DoraeonMall common installer for NoBiOki.

  Source layout (all optional):

    ~/.agents/
      skills/
        some-skill/SKILL.md
        another-skill/SKILL.md
      mcp.json                  # { "mcpServers": { ... } } or { "servers": { ... } }
      .mcp.json                 # same shape
      mcp/servers.json          # same shape
      catalog/                  # cloned public catalogs

  Built-in targets:
    claude   -> ~/.claude/skills, ~/.claude/settings.json:mcpServers
    openclaw -> ~/.openclaw/skills only by default (does not edit openclaw.json unless -AllowOpenClawConfigWrite is set)
    codex    -> ~/.codex/skills, ~/.codex/config.json:mcpServers if config.json exists, otherwise ~/.codex/mcp.json
    cursor   -> ~/.cursor/skills, ~/.cursor/mcp.json
    gemini   -> ~/.gemini/skills, ~/.gemini/settings.json:mcpServers if settings exists, otherwise ~/.gemini/mcp.json
    opencode -> ~/.opencode/skills, ~/.opencode/mcp.json
    windsurf -> ~/.windsurf/skills, ~/.windsurf/mcp.json

  Unknown/custom targets:
    Use -Targets with any name. The script will install skills to ~/.<name>/skills
    and MCP to ~/.<name>/mcp.json.

.PARAMETER Source
  Source agents directory. Defaults to ~/.agents.

.PARAMETER Targets
  Target agents to sync into. Defaults to: claude, openclaw.
  Examples: -Targets claude,openclaw,codex,cursor,gemini
            -Targets all
            -Targets claude,my-agent

.PARAMETER UpdateCatalog
  Clone/update known public catalogs into ~/.agents/catalog.

.PARAMETER Force
  Overwrite existing target skill folders.

.PARAMETER DryRun
  Print planned actions without writing files.

.PARAMETER ListTargets
  Show built-in target definitions and exit.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -UpdateCatalog

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -Force

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets claude,openclaw,codex -DryRun
#>

[CmdletBinding()]
param(
  [string]$Source = (Join-Path $HOME '.agents'),
  [string[]]$Targets = @('claude', 'openclaw'),
  [switch]$UpdateCatalog,
  [switch]$Force,
  [switch]$DryRun,
  [switch]$ListTargets,
  [switch]$AllowOpenClawConfigWrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

$BuiltInTargets = [ordered]@{
  claude = [ordered]@{ root = (Join-Path $HOME '.claude'); skills = 'skills'; mcpFile = 'settings.json'; mcpShape = 'mcpServers' }
  openclaw = [ordered]@{ root = (Join-Path $HOME '.openclaw'); skills = 'skills'; mcpFile = 'openclaw.json'; mcpShape = 'mcp.servers'; registerSkills = $true; skipConfigByDefault = $true }
  codex = [ordered]@{ root = (Join-Path $HOME '.codex'); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' }
  cursor = [ordered]@{ root = (Join-Path $HOME '.cursor'); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' }
  gemini = [ordered]@{ root = (Join-Path $HOME '.gemini'); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' }
  opencode = [ordered]@{ root = (Join-Path $HOME '.opencode'); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' }
  windsurf = [ordered]@{ root = (Join-Path $HOME '.windsurf'); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' }
}

function Ensure-Dir([string]$Path) {
  if ($DryRun) { Info "Would ensure directory: $Path"; return }
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Backup-File([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $backup = "$Path.bak.$stamp"
  if ($DryRun) { Info "Would backup $Path -> $backup"; return $backup }
  Copy-Item -LiteralPath $Path -Destination $backup -Force
  return $backup
}

function ConvertTo-HashtableCompat($InputObject) {
  if ($null -eq $InputObject) { return $null }
  if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject }
  if ($InputObject -is [System.Collections.IDictionary]) {
    $h = [ordered]@{}
    foreach ($key in $InputObject.Keys) { $h[$key] = ConvertTo-HashtableCompat $InputObject[$key] }
    return $h
  }
  if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
    $arr = @()
    foreach ($item in $InputObject) { $arr += ,(ConvertTo-HashtableCompat $item) }
    return $arr
  }
  if ($InputObject -is [pscustomobject]) {
    $h = [ordered]@{}
    foreach ($prop in $InputObject.PSObject.Properties) { $h[$prop.Name] = ConvertTo-HashtableCompat $prop.Value }
    return $h
  }
  return $InputObject
}

function Read-JsonFile([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{} }
  $raw = Get-Content -LiteralPath $Path -Raw
  if ([string]::IsNullOrWhiteSpace($raw)) { return [ordered]@{} }
  return ConvertTo-HashtableCompat ($raw | ConvertFrom-Json)
}

function Write-JsonFile([string]$Path, $Object) {
  $json = $Object | ConvertTo-Json -Depth 100
  try { $null = $json | ConvertFrom-Json } catch { throw "Refusing to write invalid JSON to $Path`: $($_.Exception.Message)" }
  if ($DryRun) { Info "Would write JSON: $Path"; return }
  Ensure-Dir (Split-Path -Parent $Path)
  $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Ensure-HashtablePath([System.Collections.IDictionary]$Root, [string[]]$PathParts) {
  $cursor = $Root
  foreach ($part in $PathParts) {
    if (-not $cursor.Contains($part) -or $cursor[$part] -isnot [System.Collections.IDictionary]) {
      $cursor[$part] = [ordered]@{}
    }
    $cursor = $cursor[$part]
  }
  return $cursor
}

function Normalize-McpServers($Obj) {
  if ($null -eq $Obj -or $Obj -isnot [System.Collections.IDictionary]) { return [ordered]@{} }
  if ($Obj.Contains('mcpServers') -and $Obj['mcpServers'] -is [System.Collections.IDictionary]) { return $Obj['mcpServers'] }
  if ($Obj.Contains('servers') -and $Obj['servers'] -is [System.Collections.IDictionary]) { return $Obj['servers'] }
  if ($Obj.Contains('mcp') -and $Obj['mcp'] -is [System.Collections.IDictionary]) {
    $mcp = $Obj['mcp']
    if ($mcp.Contains('servers') -and $mcp['servers'] -is [System.Collections.IDictionary]) { return $mcp['servers'] }
    if ($mcp.Contains('mcpServers') -and $mcp['mcpServers'] -is [System.Collections.IDictionary]) { return $mcp['mcpServers'] }
  }
  return [ordered]@{}
}

function Clone-Or-Pull([string]$Url, [string]$Dest) {
  if (Test-Path -LiteralPath (Join-Path $Dest '.git')) {
    Info "Updating catalog: $Dest"
    if ($DryRun) { Info "Would run: git -C `"$Dest`" pull --ff-only"; return }
    git -C $Dest pull --ff-only
  } elseif (Test-Path -LiteralPath $Dest) {
    Warn "Catalog destination exists but is not a git repo, skipping: $Dest"
  } else {
    Info "Cloning catalog: $Url -> $Dest"
    if ($DryRun) { Info "Would run: git clone --depth 1 `"$Url`" `"$Dest`""; return }
    git clone --depth 1 $Url $Dest
  }
}

function Resolve-Targets([string[]]$Names) {
  $expanded = @()
  foreach ($item in $Names) {
    foreach ($part in ($item -split ',')) {
      $trimmed = $part.Trim()
      if (-not [string]::IsNullOrWhiteSpace($trimmed)) { $expanded += $trimmed }
    }
  }
  $Names = $expanded
  if ($Names.Count -eq 1 -and $Names[0].ToLowerInvariant() -eq 'all') { $Names = @($BuiltInTargets.Keys) }
  $resolved = [ordered]@{}
  foreach ($nameRaw in $Names) {
    $name = $nameRaw.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($name)) { continue }
    if ($BuiltInTargets.Contains($name)) {
      $resolved[$name] = $BuiltInTargets[$name]
    } else {
      $resolved[$name] = [ordered]@{ root = (Join-Path $HOME ".$name"); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' }
    }
  }
  return $resolved
}

function Find-SkillDirs([string]$Root) {
  $skillsRoot = Join-Path $Root 'skills'
  if (-not (Test-Path -LiteralPath $skillsRoot)) { return @() }
  return Get-ChildItem -LiteralPath $skillsRoot -Directory -Recurse | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md')
  }
}

function Copy-Skills([string]$Root, [System.Collections.IDictionary]$TargetDefs) {
  $skillDirs = @(Find-SkillDirs $Root)
  if ($skillDirs.Count -eq 0) {
    Warn "No skills found under $Root\skills. Put skill folders containing SKILL.md there."
    return @()
  }

  $installed = @()
  foreach ($skill in $skillDirs) {
    $name = $skill.Name
    foreach ($targetName in $TargetDefs.Keys) {
      $def = $TargetDefs[$targetName]
      $targetRoot = Join-Path $def.root $def.skills
      $dest = Join-Path $targetRoot $name
      if ((Test-Path -LiteralPath $dest) -and -not $Force) {
        Warn "Skill exists, skipping without -Force: $dest"
        continue
      }
      Info "Installing skill $name -> $targetName`: $dest"
      if (-not $DryRun) {
        Ensure-Dir $targetRoot
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        Copy-Item -LiteralPath $skill.FullName -Destination $dest -Recurse -Force
      }
      $installed += [pscustomobject]@{ Name = $name; Source = $skill.FullName; TargetAgent = $targetName; Target = $dest }
    }
  }
  return $installed
}

function Load-All-McpServers([string]$Root) {
  $candidates = @(
    (Join-Path $Root 'mcp.json'),
    (Join-Path $Root '.mcp.json'),
    (Join-Path $Root 'mcp\servers.json'),
    (Join-Path $Root 'mcp\mcp.json')
  )
  $merged = [ordered]@{}
  foreach ($file in $candidates) {
    if (-not (Test-Path -LiteralPath $file)) { continue }
    Info "Reading MCP config: $file"
    $servers = Normalize-McpServers (Read-JsonFile $file)
    foreach ($key in $servers.Keys) { $merged[$key] = $servers[$key] }
  }
  return $merged
}

function Merge-Mcp-IntoTarget([string]$TargetName, [System.Collections.IDictionary]$Def, [System.Collections.IDictionary]$McpServers) {
  if ($McpServers.Keys.Count -eq 0) { return }
  if ($TargetName -eq 'openclaw' -and -not $AllowOpenClawConfigWrite) {
    Warn "Skipping OpenClaw MCP config write for safety. Use -AllowOpenClawConfigWrite only after validating OpenClaw's current config schema."
    return
  }
  $root = $Def.root
  $configPath = Join-Path $root $Def.mcpFile
  $config = Read-JsonFile $configPath

  switch ($Def.mcpShape) {
    'mcp.servers' { $container = Ensure-HashtablePath $config @('mcp', 'servers') }
    default {
      if (-not $config.Contains('mcpServers') -or $config['mcpServers'] -isnot [System.Collections.IDictionary]) { $config['mcpServers'] = [ordered]@{} }
      $container = $config['mcpServers']
    }
  }

  foreach ($name in $McpServers.Keys) { $container[$name] = $McpServers[$name] }
  Backup-File $configPath | Out-Null
  Write-JsonFile $configPath $config
  Ok "Merged $($McpServers.Keys.Count) MCP server(s) into $TargetName`: $configPath"
}

function Register-OpenClawSkills([System.Collections.IDictionary]$TargetDefs, [array]$Installed) {
  if (-not $TargetDefs.Contains('openclaw')) { return }
  if (-not $AllowOpenClawConfigWrite) {
    Warn "Copied OpenClaw skills, but did not edit openclaw.json. Use OpenClaw's supported skill configuration flow or rerun with -AllowOpenClawConfigWrite after validation."
    return
  }
  $rows = @($Installed | Where-Object { $_.TargetAgent -eq 'openclaw' })
  if ($rows.Count -eq 0) { return }

  $def = $TargetDefs['openclaw']
  $configPath = Join-Path $def.root $def.mcpFile
  $config = Read-JsonFile $configPath
  $entries = Ensure-HashtablePath $config @('skills', 'entries')
  foreach ($row in $rows) {
    $entries[$row.Name] = [ordered]@{ enabled = $true; path = $row.Target }
  }
  Backup-File $configPath | Out-Null
  Write-JsonFile $configPath $config
  Ok "Registered copied OpenClaw skills in $configPath"
}

if ($ListTargets) {
  Write-Host "Built-in targets:" -ForegroundColor Cyan
  foreach ($name in $BuiltInTargets.Keys) {
    $d = $BuiltInTargets[$name]
    $note = if ($name -eq 'openclaw') { ' config write guarded by -AllowOpenClawConfigWrite' } else { '' }
    Write-Host "- $name -> root=$($d.root), skills=$($d.skills), mcp=$($d.mcpFile):$($d.mcpShape)$note"
  }
  exit 0
}

Info "Source: $Source"
Ensure-Dir $Source

if ($UpdateCatalog) {
  $catalog = Join-Path $Source 'catalog'
  Ensure-Dir $catalog
  Clone-Or-Pull 'https://github.com/DevMeoU/awesome-agent-skills.git' (Join-Path $catalog 'awesome-agent-skills')
  Clone-Or-Pull 'https://github.com/DevMeoU/andrej-karpathy-skills.git' (Join-Path $catalog 'andrej-karpathy-skills')
  Clone-Or-Pull 'https://github.com/DevMeoU/everything-claude-code.git' (Join-Path $catalog 'everything-claude-code')
  Clone-Or-Pull 'https://github.com/DevMeoU/supervisor-agents-skill.git' (Join-Path $catalog 'supervisor-agents-skill')
  Clone-Or-Pull 'https://github.com/DevMeoU/template-for-skills-agent.git' (Join-Path $catalog 'template-for-skills-agent')
  Clone-Or-Pull 'https://github.com/modelcontextprotocol/servers.git' (Join-Path $catalog 'mcp-servers')
  Ok "Catalog update step finished. Review/copy chosen skills into $Source\skills before syncing."
}

$TargetDefs = Resolve-Targets $Targets
Info "Targets: $($TargetDefs.Keys -join ', ')"
foreach ($name in $TargetDefs.Keys) {
  Ensure-Dir $TargetDefs[$name].root
  Ensure-Dir (Join-Path $TargetDefs[$name].root $TargetDefs[$name].skills)
}

$installed = @(Copy-Skills $Source $TargetDefs)
$mcpServers = Load-All-McpServers $Source

if ($mcpServers.Keys.Count -gt 0) {
  foreach ($name in $TargetDefs.Keys) { Merge-Mcp-IntoTarget $name $TargetDefs[$name] $mcpServers }
} else {
  Warn "No MCP config found in ~/.agents. Add ~/.agents/mcp.json with a mcpServers object to sync MCP."
}

Register-OpenClawSkills $TargetDefs $installed
Ok "Done. Restart target agents so new config is picked up."


