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

.PARAMETER ProjectPath
  Project directory to inspect when recommending skills.

.PARAMETER RecommendSkills
  Inspect -ProjectPath and print skill recommendations that exist in catalog roots.

.PARAMETER InstallRecommendedSkills
  Copy recommended skills into ~/.agents/skills before syncing targets.

.PARAMETER SkillCatalogRoots
  Skill search roots. Defaults to this repo's ./skills and ~/.agents/catalog.

.PARAMETER UpdateCatalog
  Clone/update known public catalogs into ~/.agents/catalog.

.PARAMETER Force
  Overwrite existing target skill folders.

.PARAMETER DryRun
  Print planned actions without writing files.

.PARAMETER ListTargets
  Show built-in target definitions and exit.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -ProjectPath ./my-app -RecommendSkills

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -ProjectPath ./my-app -InstallRecommendedSkills -Targets claude,openclaw -Force

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -UpdateCatalog

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ~/agent-common-sync.ps1 -Targets all -Force
#>

[CmdletBinding()]
param(
  [string]$Source = (Join-Path $HOME '.agents'),
  [string[]]$Targets = @('claude', 'openclaw'),
  [string]$ProjectPath,
  [switch]$RecommendSkills,
  [switch]$InstallRecommendedSkills,
  [string[]]$SkillCatalogRoots,
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

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

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
    if (-not $cursor.Contains($part) -or $cursor[$part] -isnot [System.Collections.IDictionary]) { $cursor[$part] = [ordered]@{} }
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
    if ($BuiltInTargets.Contains($name)) { $resolved[$name] = $BuiltInTargets[$name] }
    else { $resolved[$name] = [ordered]@{ root = (Join-Path $HOME ".$name"); skills = 'skills'; mcpFile = 'mcp.json'; mcpShape = 'mcpServers' } }
  }
  return $resolved
}

function Find-SkillDirs([string]$Root) {
  $found = @()
  if (-not (Test-Path -LiteralPath $Root)) { return @() }
  if (Test-Path -LiteralPath (Join-Path $Root 'SKILL.md')) { return @(Get-Item -LiteralPath $Root) }
  $skillsRoot = Join-Path $Root 'skills'
  if (Test-Path -LiteralPath $skillsRoot) {
    $found += @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Recurse | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') })
  }
  $found += @(Get-ChildItem -LiteralPath $Root -Directory -Recurse | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') })
  $seen = @{}
  $unique = @()
  foreach ($item in $found) {
    $key = $item.FullName.ToLowerInvariant()
    if (-not $seen.Contains($key)) { $seen[$key] = $true; $unique += $item }
  }
  return $unique
}

function Copy-Skills([string]$Root, [System.Collections.IDictionary]$TargetDefs) {
  $skillDirs = @(Find-SkillDirs $Root)
  if ($skillDirs.Count -eq 0) { Warn "No skills found under $Root. Put skill folders containing SKILL.md there."; return @() }
  $installed = @()
  foreach ($skill in $skillDirs) {
    $name = $skill.Name
    foreach ($targetName in $TargetDefs.Keys) {
      $def = $TargetDefs[$targetName]
      $targetRoot = Join-Path $def.root $def.skills
      $dest = Join-Path $targetRoot $name
      if ((Test-Path -LiteralPath $dest) -and -not $Force) { Warn "Skill exists, skipping without -Force: $dest"; continue }
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

function Get-DefaultSkillCatalogRoots([string]$SourceRoot) {
  $roots = @()
  $repoSkills = Join-Path $ScriptRoot 'skills'
  $sourceCatalog = Join-Path $SourceRoot 'catalog'
  if (Test-Path -LiteralPath $repoSkills) { $roots += $repoSkills }
  if (Test-Path -LiteralPath $sourceCatalog) { $roots += $sourceCatalog }
  return $roots
}

function Get-SkillIndex([string[]]$Roots) {
  $index = @{}
  foreach ($root in $Roots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($skill in @(Find-SkillDirs $root)) {
      $name = $skill.Name.ToLowerInvariant()
      if (-not $index.ContainsKey($name)) { $index[$name] = $skill.FullName }
    }
  }
  return $index
}

function Test-AnyPath([string]$Root, [string[]]$RelativePaths) {
  foreach ($rel in $RelativePaths) { if (Test-Path -LiteralPath (Join-Path $Root $rel)) { return $true } }
  return $false
}

function Test-AnyFileName([string]$Root, [string[]]$Names) {
  foreach ($name in $Names) {
    if (Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq $name } | Select-Object -First 1) { return $true }
  }
  return $false
}

function Add-Recommendation([System.Collections.ArrayList]$Rows, [string]$Name, [string]$Reason, [System.Collections.IDictionary]$Index) {
  $key = $Name.ToLowerInvariant()
  if ($Index.Contains($key)) { [void]$Rows.Add([pscustomobject]@{ Skill = $key; Reason = $Reason; Source = $Index[$key] }) }
}

function Get-ProjectSkillRecommendations([string]$Project, [System.Collections.IDictionary]$Index) {
  if ([string]::IsNullOrWhiteSpace($Project)) { throw '-ProjectPath is required for -RecommendSkills or -InstallRecommendedSkills.' }
  $root = (Resolve-Path -LiteralPath $Project).Path
  $rows = New-Object System.Collections.ArrayList

  if (Test-AnyPath $root @('docs\adr','adr','architecture\adr','decisions','PLAN.md','plan.md')) {
    Add-Recommendation $rows 'supervisor-agents' 'Project has ADR/plan architecture-review signals.' $Index
  }
  if (Test-AnyPath $root @('package.json','pnpm-lock.yaml','yarn.lock','vite.config.ts','vite.config.js','next.config.js','src\App.tsx','src\App.jsx')) {
    Add-Recommendation $rows 'frontend-design' 'JavaScript/frontend project signals detected.' $Index
  }
  if (Test-AnyPath $root @('pyproject.toml','requirements.txt','setup.py','setup.cfg','Pipfile')) {
    Add-Recommendation $rows 'python' 'Python project signals detected.' $Index
  }
  if (Test-AnyPath $root @('Dockerfile','docker-compose.yml','docker-compose.yaml','.github\workflows')) {
    Add-Recommendation $rows 'devops' 'Docker or CI/CD signals detected.' $Index
  }
  if (Test-AnyFileName $root @('workflow.json','n8n-test-email-workflow.json') -or (Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue | Select-String -Pattern 'n8n-nodes-base' -Quiet)) {
    Add-Recommendation $rows 'n8n' 'n8n workflow JSON signals detected.' $Index
  }
  if (Test-AnyPath $root @('README.md','docs') -and (Test-AnyPath $root @('SKILL.md','template-skill\SKILL.md') -or (Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue | Select-Object -First 1))) {
    Add-Recommendation $rows 'skill-creator' 'Agent Skill authoring signals detected.' $Index
  }
  if (Test-AnyPath $root @('mcp.json','.mcp.json') -or (Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Select-String -Pattern 'Model Context Protocol|mcpServers' -Quiet)) {
    Add-Recommendation $rows 'mcp-builder' 'MCP config or documentation signals detected.' $Index
  }
  if (Test-AnyFileName $root @('*.docx')) { Add-Recommendation $rows 'docx' 'Word document files detected.' $Index }
  if (Test-AnyFileName $root @('*.xlsx')) { Add-Recommendation $rows 'xlsx' 'Excel workbook files detected.' $Index }
  if (Test-AnyFileName $root @('*.pptx')) { Add-Recommendation $rows 'pptx' 'PowerPoint files detected.' $Index }
  if (Test-AnyFileName $root @('*.pdf')) { Add-Recommendation $rows 'pdf' 'PDF files detected.' $Index }

  $seen = @{}
  $unique = @()
  foreach ($row in $rows) {
    if (-not $seen.Contains($row.Skill)) { $seen[$row.Skill] = $true; $unique += $row }
  }
  return $unique
}

function Install-RecommendedSkills([array]$Recommendations, [string]$SourceRoot) {
  $destRoot = Join-Path $SourceRoot 'skills'
  Ensure-Dir $destRoot
  foreach ($rec in $Recommendations) {
    $dest = Join-Path $destRoot $rec.Skill
    if ((Test-Path -LiteralPath $dest) -and -not $Force) { Warn "Recommended skill exists, skipping without -Force: $dest"; continue }
    Info "Installing recommended skill $($rec.Skill) -> $dest"
    if (-not $DryRun) {
      if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
      Copy-Item -LiteralPath $rec.Source -Destination $dest -Recurse -Force
    }
  }
}

function Load-All-McpServers([string]$Root) {
  $candidates = @((Join-Path $Root 'mcp.json'), (Join-Path $Root '.mcp.json'), (Join-Path $Root 'mcp\servers.json'), (Join-Path $Root 'mcp\mcp.json'))
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
  if ($TargetName -eq 'openclaw' -and -not $AllowOpenClawConfigWrite) { Warn "Skipping OpenClaw MCP config write for safety. Use -AllowOpenClawConfigWrite only after validating OpenClaw's current config schema."; return }
  $configPath = Join-Path $Def.root $Def.mcpFile
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
  if (-not $AllowOpenClawConfigWrite) { Warn "Copied OpenClaw skills, but did not edit openclaw.json. Use OpenClaw's supported skill configuration flow or rerun with -AllowOpenClawConfigWrite after validation."; return }
  $rows = @($Installed | Where-Object { $_.TargetAgent -eq 'openclaw' })
  if ($rows.Count -eq 0) { return }
  $def = $TargetDefs['openclaw']
  $configPath = Join-Path $def.root $def.mcpFile
  $config = Read-JsonFile $configPath
  $entries = Ensure-HashtablePath $config @('skills', 'entries')
  foreach ($row in $rows) { $entries[$row.Name] = [ordered]@{ enabled = $true; path = $row.Target } }
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

if ($RecommendSkills -or $InstallRecommendedSkills) {
  $roots = if ($SkillCatalogRoots -and $SkillCatalogRoots.Count -gt 0) { $SkillCatalogRoots } else { Get-DefaultSkillCatalogRoots $Source }
  Info "Skill catalog roots: $($roots -join ', ')"
  $index = Get-SkillIndex $roots
  $recommendations = @(Get-ProjectSkillRecommendations $ProjectPath $index)
  if ($recommendations.Count -eq 0) { Warn "No installable skill recommendations found. Run -UpdateCatalog or add skills to ~/.agents/catalog or ./skills." }
  else {
    Write-Host "Recommended skills:" -ForegroundColor Cyan
    $recommendations | Format-Table Skill, Reason, Source -AutoSize
    if ($InstallRecommendedSkills) { Install-RecommendedSkills $recommendations $Source }
  }
  if ($RecommendSkills -and -not $InstallRecommendedSkills -and -not $UpdateCatalog) { exit 0 }
}

$TargetDefs = Resolve-Targets $Targets
Info "Targets: $($TargetDefs.Keys -join ', ')"
foreach ($name in $TargetDefs.Keys) { Ensure-Dir $TargetDefs[$name].root; Ensure-Dir (Join-Path $TargetDefs[$name].root $TargetDefs[$name].skills) }

$installed = @(Copy-Skills $Source $TargetDefs)
$mcpServers = Load-All-McpServers $Source
if ($mcpServers.Keys.Count -gt 0) { foreach ($name in $TargetDefs.Keys) { Merge-Mcp-IntoTarget $name $TargetDefs[$name] $mcpServers } }
else { Warn "No MCP config found in ~/.agents. Add ~/.agents/mcp.json with a mcpServers object to sync MCP." }
Register-OpenClawSkills $TargetDefs $installed
Ok "Done. Restart target agents so new config is picked up."
