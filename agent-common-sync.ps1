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
      mcp/code-review-graph.json # optional preset created by -InstallCodeReviewGraphMcp
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

.PARAMETER ProjectInstall
  With -ProjectPath, install baseline + recommended project-specific skills, MCP config, and commands into the project
  (currently .claude/skills, .claude/commands, and .mcp.json) instead of only syncing global targets.

.PARAMETER FullBootstrap
  Run the end-to-end project bootstrap: update catalogs, install project assets, validate project skills/commands/MCP, optionally build code-review-graph, and recommend skills again.

.PARAMETER AllowInstallUv
  Allow -FullBootstrap to install uv with `python -m pip install uv` if uvx is missing.

.PARAMETER SkipBuildCodeGraph
  Skip the code-review-graph status/build step during -FullBootstrap.

.PARAMETER Demo
  Deprecated compatibility switch. ProjectInstall now always writes project-local common commands, including
  common-installer-demo.md and scrum-align.md.

.PARAMETER BaselineSkills
  Skills always installed for project bootstrap before project-specific recommendations. Defaults include project
  recommender, supervision/review, and project-management skills.

.PARAMETER SkillCatalogRoots
  Skill search roots. Defaults to this repo's ./skills and ~/.agents/catalog.

.PARAMETER UpdateCatalog
  Clone/update known public catalogs into ~/.agents/catalog.

.PARAMETER ScanGithubCatalog
  Scan public -GithubOwner repositories without requiring GitHub login, then clone/update repositories whose name, description, or topics indicate agent, skill, MCP, Claude, or model tooling.

.PARAMETER GithubOwner
  GitHub owner to scan when -ScanGithubCatalog is used. Defaults to DevMeoU.

.PARAMETER GithubIncludeRepoNames
  Extra GitHub repository names to include in the catalog scan even when metadata does not match the default relevance filter.

.PARAMETER GithubIncludeRepoPattern
  Extra regular expression matched against GitHub repository names to include in the catalog scan.

.PARAMETER InstallCodeReviewGraphMcp
  Add the code-review-graph MCP server preset to ~/.agents/mcp/code-review-graph.json.
  This is now enabled by default for normal sync runs; the switch remains for explicitness.
  It only writes MCP config; it does not install Python packages. The generated server uses
  uvx code-review-graph serve so target agents can run the published package on demand.

.PARAMETER InstallModelTaskOptimizerMcp
  Add the model-task-optimizer MCP server preset to ~/.agents/mcp/model-task-optimizer.json.

.PARAMETER SkipCodeReviewGraphMcp
  Do not create/sync the default code-review-graph MCP preset.

.PARAMETER SkipModelTaskOptimizerMcp
  Do not create/sync the default model-task-optimizer MCP preset.

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
  [string[]]$Targets = @(),
  [string]$ProjectPath,
  [switch]$RecommendSkills,
  [switch]$InstallRecommendedSkills,
  [switch]$ProjectInstall,
  [switch]$FullBootstrap,
  [switch]$AllowInstallUv,
  [switch]$SkipBuildCodeGraph,
  [switch]$Demo,
  [string[]]$BaselineSkills = @('project-skill-recommender', 'supervisor-agents', 'scrum-master', 'senior-pm', 'model-task-optimizer'),
  [string]$ProjectTask = '',
  [string[]]$SkillCatalogRoots,
  [switch]$UpdateCatalog,
  [switch]$ScanGithubCatalog,
  [string]$GithubOwner = 'DevMeoU',
  [string[]]$GithubIncludeRepoNames = @(),
  [string]$GithubIncludeRepoPattern,
  [switch]$CloneAllGithubRepos,
  [switch]$InstallCodeReviewGraphMcp,
  [switch]$InstallModelTaskOptimizerMcp,
  [switch]$SkipCodeReviewGraphMcp,
  [switch]$SkipModelTaskOptimizerMcp,
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

function ConvertTo-StableJson($Object) {
  return ($Object | ConvertTo-Json -Depth 100)
}

function Write-JsonFile([string]$Path, $Object) {
  $json = ConvertTo-StableJson $Object
  try { $null = $json | ConvertFrom-Json } catch { throw "Refusing to write invalid JSON to $Path`: $($_.Exception.Message)" }
  if ($DryRun) { Info "Would write JSON: $Path"; return }
  Ensure-Dir (Split-Path -Parent $Path)
  $json | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Test-JsonFileContentEqual([string]$Path, $Object) {
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  try {
    $existing = Read-JsonFile $Path
    return ((ConvertTo-StableJson $existing) -eq (ConvertTo-StableJson $Object))
  } catch {
    return $false
  }
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

function Get-GithubIncludeRepoNameSet([string[]]$Names) {
  $set = @{}
  foreach ($item in $Names) {
    foreach ($part in ($item -split ',')) {
      $name = $part.Trim().ToLowerInvariant()
      if (-not [string]::IsNullOrWhiteSpace($name)) { $set[$name] = $true }
    }
  }
  return $set
}

function Test-GithubRepoLooksRelevant($Repo, [System.Collections.IDictionary]$IncludeNames = @{}, [string]$IncludePattern = '') {
  $repoName = [string]$Repo.name
  $repoNameLower = $repoName.ToLowerInvariant()
  if ($IncludeNames.Count -gt 0) { return $IncludeNames.Contains($repoNameLower) }
  if (-not [string]::IsNullOrWhiteSpace($IncludePattern)) { return ($repoName -match $IncludePattern) }

  if ($CloneAllGithubRepos) { return $true }

  $textParts = @($Repo.name, $Repo.description)
  if ($Repo.repositoryTopics) {
    foreach ($topic in $Repo.repositoryTopics) {
      if ($topic.name) { $textParts += $topic.name }
    }
  }
  $text = (($textParts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' ').ToLowerInvariant()
  return ($text -match 'ai|agent|agents|skill|skills|mcp|model-context-protocol|claude|codex|gemini|gpt|llm|prompt|workflow|tool|token|context|routing|router|optimizer|review|graph|automation|auto-dev|chatbot|rag|embedding|eval|benchmark|openai|anthropic|langchain|llama|copilot|n8n')
}

function Get-GithubPublicRepos([string]$Owner) {
  $all = @()
  $page = 1
  while ($true) {
    $uri = "https://api.github.com/users/$Owner/repos?per_page=100&page=$page&sort=updated"
    Info "Reading public GitHub repos: $uri"
    try {
      $batch = @(Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'agents-common-installer' })
    } catch {
      throw "Could not read public GitHub repositories for $Owner without login: $($_.Exception.Message)"
    }
    if ($batch.Count -eq 0) { break }
    $all += $batch
    if ($batch.Count -lt 100) { break }
    $page += 1
  }
  return $all
}

function Convert-GithubApiRepo($Repo) {
  $topics = @()
  if ($Repo.topics) {
    foreach ($topic in @($Repo.topics)) { $topics += [pscustomobject]@{ name = [string]$topic } }
  }
  return [pscustomobject]@{
    name = [string]$Repo.name
    description = [string]$Repo.description
    url = [string]$Repo.clone_url
    repositoryTopics = $topics
  }
}

function Get-GithubRepos([string]$Owner) {
  try {
    $publicRepos = Get-GithubPublicRepos $Owner
    $converted = @()
    foreach ($repo in @($publicRepos)) {
      if ($repo -is [System.Array]) {
        foreach ($nestedRepo in $repo) { $converted += ,(Convert-GithubApiRepo $nestedRepo) }
      } else {
        $converted += ,(Convert-GithubApiRepo $repo)
      }
    }
    return $converted
  } catch {
    Warn $_.Exception.Message
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) { throw "Public GitHub API failed and GitHub CLI 'gh' is not available. Check network access or install gh for fallback." }
    Warn "Falling back to GitHub CLI. Private repos require gh auth login; public repos usually do not."
    $json = gh repo list $Owner --limit 500 --json name,description,url,isPrivate,updatedAt,repositoryTopics
    return @($json | ConvertFrom-Json)
  }
}

function Update-GithubCatalog([string]$Owner, [string]$CatalogRoot) {
  Ensure-Dir $CatalogRoot
  Info "Scanning GitHub repositories for owner: $Owner"
  $repos = Get-GithubRepos $Owner
  $includeNames = Get-GithubIncludeRepoNameSet $GithubIncludeRepoNames
  $matched = @()
  foreach ($repo in @($repos)) {
    if ($repo -is [System.Array]) {
      foreach ($nestedRepo in $repo) { if (Test-GithubRepoLooksRelevant $nestedRepo $includeNames $GithubIncludeRepoPattern) { $matched += ,$nestedRepo } }
    } elseif (Test-GithubRepoLooksRelevant $repo $includeNames $GithubIncludeRepoPattern) {
      $matched += ,$repo
    }
  }
  if ($matched.Count -eq 0) { Warn "No agent/skill/MCP/model-related repositories matched for $Owner."; return @() }
  foreach ($repo in $matched) {
    $repoName = [string]$repo.name
    $repoUrl = [string]$repo.url
    if ([string]::IsNullOrWhiteSpace($repoName) -or [string]::IsNullOrWhiteSpace($repoUrl)) { Warn "Skipping GitHub repo with missing name or URL."; continue }
    $dest = Join-Path $CatalogRoot $repoName
    Clone-Or-Pull $repoUrl $dest
  }
  Ok "GitHub catalog scan matched $($matched.Count) repository/repositories."
  Write-CatalogInventory $CatalogRoot
  return $matched
}

function Get-CatalogInventory([string]$CatalogRoot) {
  $rows = @()
  if (-not (Test-Path -LiteralPath $CatalogRoot)) { return @() }
  foreach ($repo in @(Get-ChildItem -LiteralPath $CatalogRoot -Directory -ErrorAction SilentlyContinue)) {
    $skills = @(Find-SkillDirs $repo.FullName)
    $mcpFiles = @(Get-ChildItem -LiteralPath $repo.FullName -Recurse -File -Include '.mcp.json','mcp.json','servers.json' -ErrorAction SilentlyContinue)
    $promptFiles = @(Get-ChildItem -LiteralPath $repo.FullName -Recurse -File -Include '*.prompt.md','*prompt*.md','*.md' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'prompt|command|agent|workflow|token|model|routing' })
    $rows += [pscustomobject]@{
      Repo = $repo.Name
      Skills = $skills.Count
      SkillNames = (($skills | ForEach-Object { $_.Name }) -join ', ')
      McpFiles = $mcpFiles.Count
      PromptLikeFiles = $promptFiles.Count
      Path = $repo.FullName
    }
  }
  return $rows
}

function Write-CatalogInventory([string]$CatalogRoot) {
  $rows = @(Get-CatalogInventory $CatalogRoot)
  if ($rows.Count -eq 0) { Warn "Catalog inventory is empty: $CatalogRoot"; return }
  Write-Host "Catalog inventory:" -ForegroundColor Cyan
  $rows | Where-Object { $_.Skills -gt 0 -or $_.McpFiles -gt 0 -or $_.PromptLikeFiles -gt 0 } | Format-Table Repo, Skills, SkillNames, McpFiles, PromptLikeFiles -AutoSize
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

function Find-DirectSkillDirs([string]$Root) {
  if (-not (Test-Path -LiteralPath $Root)) { return @() }
  if (Test-Path -LiteralPath (Join-Path $Root 'SKILL.md')) { return @(Get-Item -LiteralPath $Root) }
  $skillsRoot = Join-Path $Root 'skills'
  if (-not (Test-Path -LiteralPath $skillsRoot)) { return @() }
  return @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') })
}

function Copy-DirectoryContents([string]$SourceDir, [string]$DestDir) {
  if (-not (Test-Path -LiteralPath $SourceDir)) { return }
  Ensure-Dir $DestDir
  foreach ($item in Get-ChildItem -LiteralPath $SourceDir -Force) {
    $dest = Join-Path $DestDir $item.Name
    if (-not $DryRun -and (Test-Path -LiteralPath $dest)) { Remove-Item -LiteralPath $dest -Recurse -Force }
    if ($DryRun) { Info "Would copy $($item.FullName) -> $dest" }
    else { Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse -Force }
  }
}

function Copy-Skills([string]$Root, [System.Collections.IDictionary]$TargetDefs) {
  $skillDirs = @(Find-DirectSkillDirs $Root)
  if ($skillDirs.Count -eq 0) { Warn "No selected skills found under $Root\skills. Put chosen skill folders containing SKILL.md there."; return @() }
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

function Test-AnyFileContent([string]$Root, [string]$Pattern, [string]$Filter = '*') {
  foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue)) {
    try {
      if (Select-String -LiteralPath $file.FullName -Pattern $Pattern -Quiet -ErrorAction Stop) { return $true }
    } catch {
      Warn "Skipping unreadable file while scanning recommendations: $($file.FullName)"
    }
  }
  return $false
}

function Add-Recommendation([System.Collections.ArrayList]$Rows, [string]$Name, [string]$Reason, [System.Collections.IDictionary]$Index) {
  $key = $Name.ToLowerInvariant()
  if ($Index.Contains($key)) { [void]$Rows.Add([pscustomobject]@{ Skill = $key; Reason = $Reason; Source = $Index[$key] }) }
}

function Get-ProjectSkillRecommendations([string]$Project, [System.Collections.IDictionary]$Index, [string]$Task = '') {
  if ([string]::IsNullOrWhiteSpace($Project)) { throw '-ProjectPath is required for -RecommendSkills or -InstallRecommendedSkills.' }
  if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
    throw "Project path does not exist or is not a directory: $Project`nUse an existing project path, for example: -ProjectPath . or -ProjectPath D:\Workspace\Project\Agents-common-installer"
  }
  $root = (Resolve-Path -LiteralPath $Project).Path
  $taskText = if ([string]::IsNullOrWhiteSpace($Task)) { '' } else { $Task.ToLowerInvariant() }
  $rows = New-Object System.Collections.ArrayList

  if (Test-AnyPath $root @('docs\adr','adr','architecture\adr','decisions','PLAN.md','plan.md')) {
    Add-Recommendation $rows 'supervisor-agents' 'Project has ADR/plan architecture-review signals.' $Index
  }
  if (Test-AnyPath $root @('sdkconfig','sdkconfig.defaults','CMakeLists.txt','main\CMakeLists.txt','partitions','idf_component.yml','dependencies.lock')) {
    Add-Recommendation $rows 'esp-idf-firmware' 'ESP-IDF/MCU firmware signals detected.' $Index
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
  if (Test-AnyFileName $root @('workflow.json','n8n-test-email-workflow.json') -or (Test-AnyFileContent $root 'n8n-nodes-base' '*.json')) {
    Add-Recommendation $rows 'n8n' 'n8n workflow JSON signals detected.' $Index
  }
  if (Test-AnyPath $root @('README.md','docs') -and (Test-AnyPath $root @('SKILL.md','template-skill\SKILL.md') -or (Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue | Select-Object -First 1))) {
    Add-Recommendation $rows 'skill-creator' 'Agent Skill authoring signals detected.' $Index
  }
  if (Test-AnyPath $root @('mcp.json','.mcp.json') -or (Test-AnyFileContent $root 'Model Context Protocol|mcpServers')) {
    Add-Recommendation $rows 'mcp-builder' 'MCP config or documentation signals detected.' $Index
  }
  if (Test-AnyPath $root @('promptfoo.yaml','promptfooconfig.yaml','evals','benchmarks') -or (Test-AnyFileContent $root 'anthropic|openai|gemini|grok|deepseek|kimi|nvidia|llm|model routing|prompt caching' '*') -or $taskText -match 'token|prompt|model|routing|optimizer|mcp|agent') {
    Add-Recommendation $rows 'model-task-optimizer' 'AI model, eval, prompt, token, MCP, or provider-routing signals detected.' $Index
  }
  if ($taskText -match 'review|supervisor|adr|plan|architecture|compliance|diff') {
    Add-Recommendation $rows 'supervisor-agents' 'Task asks for supervision, review, ADR, architecture, plan, or diff compliance.' $Index
  }
  if ($taskText -match 'scrum|sprint|backlog|standup|retro|velocity|story') {
    Add-Recommendation $rows 'scrum-master' 'Task asks for Scrum, sprint, backlog, retro, velocity, or story workflow.' $Index
  }
  if ($taskText -match 'project manager|roadmap|milestone|risk|stakeholder|capacity|portfolio') {
    Add-Recommendation $rows 'senior-pm' 'Task asks for PM, roadmap, milestone, risk, stakeholder, capacity, or portfolio workflow.' $Index
  }
  if ($taskText -match 'skill|skills|agentskill|agent skill') {
    Add-Recommendation $rows 'project-skill-recommender' 'Task asks to evaluate or install project skills.' $Index
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

function Add-BaselineRecommendations([array]$Recommendations, [System.Collections.IDictionary]$Index, [string[]]$Names) {
  $rows = New-Object System.Collections.ArrayList
  $seen = @{}
  foreach ($rec in $Recommendations) {
    if ($null -eq $rec) { continue }
    $seen[$rec.Skill.ToLowerInvariant()] = $true
    [void]$rows.Add($rec)
  }
  foreach ($name in $Names) {
    $key = $name.ToLowerInvariant()
    if ($seen.Contains($key)) { continue }
    if ($Index.Contains($key)) {
      [void]$rows.Add([pscustomobject]@{ Skill = $key; Reason = 'Baseline common project skill.'; Source = $Index[$key] })
      $seen[$key] = $true
    } else {
      Warn "Baseline skill not found in catalog/source roots: $name"
    }
  }
  return @($rows)
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

function Write-ProjectCommonCommands([string]$ProjectRoot) {
  $commandsDir = Join-Path $ProjectRoot '.claude\commands'
  Ensure-Dir $commandsDir

  $demoPath = Join-Path $commandsDir 'common-installer-demo.md'
  $demoBody = @'
# Common Installer Demo

Run this bootstrap verification fully automatically. Do not stop after a failed check; continue with fallbacks and produce one final report.

1. Confirm the project root with `pwd` and `git rev-parse --show-toplevel` when available.
2. List installed project skills by scanning directories that contain `SKILL.md`, not with a plain glob that only matches files:
   - Bash/Python fallback:
     ```sh
     python - <<'PY'
     from pathlib import Path
     root = Path('.claude/skills')
     skills = sorted(p.parent.name for p in root.glob('*/SKILL.md')) if root.exists() else []
     print('\n'.join(skills) if skills else 'NO_SKILLS_FOUND')
     PY
     ```
3. List project commands from `.claude/commands/*.md`.
4. Read `.mcp.json` using UTF-8 with BOM support and summarize configured servers:
   ```sh
   PYTHONIOENCODING=utf-8 python - <<'PY'
   import json
   from pathlib import Path
   p = Path('.mcp.json')
   if not p.exists():
       print('NO_MCP_JSON')
   else:
       data = json.loads(p.read_text(encoding='utf-8-sig'))
       servers = data.get('mcpServers', {})
       for name, cfg in servers.items():
           print(f"{name}: {cfg.get('command')} {' '.join(cfg.get('args', []))}")
   PY
   ```
5. Check `uvx` availability:
   - If `uvx` exists, run `uvx --version`, `uvx code-review-graph status`, and if missing/stale explain/run `uvx code-review-graph build` when safe.
   - If `uvx` is missing, try these non-destructive discovery fallbacks before reporting blocked:
     - `python -m uv --version`
     - `python -m pip show uv`
     - check common Windows script paths such as `%APPDATA%\Python\Python312\Scripts\uvx.exe` when accessible.
   - Do not claim MCP is working when `uvx` is unavailable.
6. Run project recommendation again with the common installer when `agent-common-sync.ps1` is reachable from `D:/Workspace/Project/Agents-common-installer/agent-common-sync.ps1`:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:/Workspace/Project/Agents-common-installer/agent-common-sync.ps1" -ProjectPath . -RecommendSkills
   ```
7. Final report must include:
   - project root
   - installed skill count and key skills
   - command files
   - MCP servers and whether each can run now
   - recommended skills
   - exact blockers and exact next command to fix them

Keep the report short, but complete. Include exact commands used.
'@

  $scrumAlignPath = Join-Path $commandsDir 'scrum-align.md'
  $scrumAlignBody = @'
# Scrum Align

Goal: make the current implementation match the repository design/plan/ADR/docs, with supervision and role-based execution.

Workflow:

1. Bootstrap context
   - Read project-local skills in `.claude/skills` when relevant.
   - Inspect `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, `architecture/`, `docs/adr/`, `adr/`, `PLAN.md`, `TODO.md`, and roadmap files when present.
   - Run `git status --short`, `git diff --stat`, and `git diff --find-renames`.

2. Build/update code graph
   - Prefer MCP `code-review-graph` tools if available.
   - Otherwise run:
     - `uvx code-review-graph status`
     - `uvx code-review-graph build` if missing/stale
     - `uvx code-review-graph detect-changes` for current diff impact
   - Use graph results to identify impacted files, callers, tests, flows, hubs, and bridge nodes.

3. Scrum/design alignment check
   - Treat design docs, ADRs, implementation plan, acceptance criteria, and tests as source of truth.
   - Produce a concise alignment matrix:
     - Requirement/design item
     - Evidence in code/tests/docs
     - Status: compliant / partial / missing / violation / unknown
     - Owner role
     - Next action

4. Supervisor review
   - Use the `supervisor-agents` skill rules.
   - Run independent passes/agents when available:
     - Diff Analyzer
     - Context Checker
     - Plan Validator
     - ADR Auditor
     - Aggregator
   - Do not hide uncertainty; mark missing evidence explicitly.

5. Role-based execution loop
   - Create or simulate these roles as subagents/passes:
     - Dev Agent: implement missing/incorrect behavior.
     - Test Agent: add/update unit/integration/e2e tests.
     - QA Agent: verify acceptance criteria and user flows.
     - QC Agent: check quality, lint, formatting, regressions, and edge cases.
     - Docs Agent: update docs/ADR/plan when implementation intentionally changes design.
     - Supervisor Agent: re-review every loop against design/ADR/plan/diff.
   - If subagent tools are available, spawn agents with focused tasks; otherwise run the passes sequentially.

6. Iterate until done
   - After each implementation pass, run relevant tests/lint/build.
   - Re-run code-review-graph update/detect-changes.
   - Re-run supervisor alignment.
   - Continue until all blocker/high/required alignment issues are resolved or a human decision is required.

7. Stop conditions
   - Stop and ask the human when requirements conflict, destructive/external actions are needed, credentials are required, or a design decision is ambiguous.
   - Otherwise keep working until the project is compliant.

Final report:

- Overall status: compliant / mostly compliant / mixed / blocked
- Commands run
- Files changed
- Tests/build/lint result
- Alignment matrix summary
- Remaining risks/blockers
- Suggested next sprint/backlog items
'@

  foreach ($entry in @(
    @{ Path = $demoPath; Body = $demoBody; Name = 'common-installer-demo' },
    @{ Path = $scrumAlignPath; Body = $scrumAlignBody; Name = 'scrum-align' }
  )) {
    if ($DryRun) { Info "Would write project command $($entry.Name): $($entry.Path)" }
    else { $entry.Body | Set-Content -LiteralPath $entry.Path -Encoding UTF8 }
  }
}

function Write-ProjectSkillPlan([string]$ProjectRoot, [array]$Recommendations, [string]$Task) {
  $planPath = Join-Path $ProjectRoot '.claude\AGENT_SKILL_PLAN.md'
  $skillsText = if ($Recommendations.Count -gt 0) {
    (($Recommendations | ForEach-Object { "- ``$($_.Skill)`` - $($_.Reason)`n  - Source: $($_.Source)" }) -join "`n")
  } else {
    '- No installable project skills were recommended.'
  }
  $taskLine = if ([string]::IsNullOrWhiteSpace($Task)) { 'General project bootstrap / alignment.' } else { $Task }
  $bodyTemplate = @'
# Agent Skill Plan

## Task

{{TASK}}

## Installed / Recommended Skills

{{SKILLS}}

## Token-Saving Rules

- Read only the one most specific `SKILL.md` before a task; do not bulk-read every skill.
- Use baseline skills as routing rules: project-skill-recommender for onboarding, supervisor-agents for review/compliance, scrum-master for sprint/backlog, senior-pm for roadmap/risk/status, model-task-optimizer for prompt/model/token routing.
- Prefer code-review-graph for repository context before large diff reviews instead of dumping whole files into context.
- Keep project evidence citations short: file path + purpose + exact command output where possible.
- Use subagents/passes only when the work benefits from role separation; otherwise run sequential lightweight passes.

## Common Project Prompts

### Scrum Master / Alignment Prompt

Use `.claude/commands/scrum-align.md`. Inspect README, docs, ADRs, roadmap/backlog, git diff, code graph, and tests. Produce an alignment matrix and next sprint items.

### Supervisor / Code Review Prompt

Use `supervisor-agents` when reviewing changes. Run Diff Analyzer, Context Checker, Plan Validator, ADR Auditor, and Aggregator roles. Mark missing evidence explicitly.

### Code Graph Prompt

Use MCP `code-review-graph` when available. Build/update graph, detect changed impact, identify hubs/flows/tests, then review only impacted context first.

### Model / Token Optimizer Prompt

Use `model-task-optimizer` for large tasks. Recommend primary/fallback models, context strategy, batching, prompt caching, validation, and token budget before execution.

## Execution Flow

1. Confirm project root and git state.
2. Read this plan and the single most relevant skill.
3. Build/update code-review-graph when useful.
4. Create a small task plan with acceptance checks.
5. Execute with focused agents/passes.
6. Run project-specific tests/build/lint.
7. Re-run supervisor alignment for any diff.
8. Report: changed files, commands, evidence, remaining blockers, next actions.
'@
  $body = $bodyTemplate.Replace('{{TASK}}', $taskLine).Replace('{{SKILLS}}', $skillsText)
  if ($DryRun) { Info "Would write project skill plan: $planPath" }
  else { $body | Set-Content -LiteralPath $planPath -Encoding UTF8 }
}

function Install-ProjectAssets([string]$Project, [array]$Recommendations, [System.Collections.IDictionary]$McpServers, [string]$Task = '') {
  if ([string]::IsNullOrWhiteSpace($Project)) { throw '-ProjectPath is required for -ProjectInstall.' }
  if (-not (Test-Path -LiteralPath $Project -PathType Container)) { throw "Project path does not exist or is not a directory: $Project" }
  $projectRoot = (Resolve-Path -LiteralPath $Project).Path
  $claudeRoot = Join-Path $projectRoot '.claude'
  $projectSkills = Join-Path $claudeRoot 'skills'
  $projectCommands = Join-Path $claudeRoot 'commands'
  Ensure-Dir $projectSkills
  Ensure-Dir $projectCommands

  foreach ($rec in $Recommendations) {
    $skillDest = Join-Path $projectSkills $rec.Skill
    if ((Test-Path -LiteralPath $skillDest) -and -not $Force) { Warn "Project skill exists, skipping without -Force: $skillDest" }
    else {
      Info "Installing project skill $($rec.Skill) -> $skillDest"
      if (-not $DryRun) {
        if (Test-Path -LiteralPath $skillDest) { Remove-Item -LiteralPath $skillDest -Recurse -Force }
        Copy-Item -LiteralPath $rec.Source -Destination $skillDest -Recurse -Force
      }
    }

    $commandSource = Join-Path $rec.Source 'commands'
    if (Test-Path -LiteralPath $commandSource) {
      $commandDest = Join-Path $projectCommands $rec.Skill
      Info "Installing project commands for $($rec.Skill) -> $commandDest"
      Copy-DirectoryContents $commandSource $commandDest
    }
  }

  Write-ProjectCommonCommands $projectRoot
  Write-ProjectSkillPlan $projectRoot $Recommendations $Task

  if ($McpServers.Keys.Count -gt 0) {
    $mcpPath = Join-Path $projectRoot '.mcp.json'
    $config = Read-JsonFile $mcpPath
    if (-not $config.Contains('mcpServers') -or $config['mcpServers'] -isnot [System.Collections.IDictionary]) { $config['mcpServers'] = [ordered]@{} }
    foreach ($name in $McpServers.Keys) { $config['mcpServers'][$name] = $McpServers[$name] }
    if (Test-JsonFileContentEqual $mcpPath $config) {
      Ok "Project MCP config already up to date: $mcpPath"
    } else {
      Backup-File $mcpPath | Out-Null
      Write-JsonFile $mcpPath $config
      Ok "Merged $($McpServers.Keys.Count) MCP server(s) into project: $mcpPath"
    }
  }

  Ok "Project install finished: $projectRoot"
}

function Get-CommandPath([string]$Name) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Ensure-UvxForBootstrap() {
  $uvx = Get-CommandPath 'uvx'
  if ($uvx) { Ok "uvx available: $uvx"; return $true }

  Warn "uvx is not available on PATH."
  try {
    python -m uv --version | Out-Host
    Ok "uv is available through python -m uv, but uvx script is not on PATH. Restart the terminal or add the Python Scripts directory to PATH."
    return $false
  } catch {
    Warn "python -m uv is not available."
  }

  if ($AllowInstallUv) {
    Info "Installing uv with: python -m pip install uv"
    if ($DryRun) { Info "Would run: python -m pip install uv"; return $false }
    python -m pip install uv
    $uvx = Get-CommandPath 'uvx'
    if ($uvx) { Ok "uvx available after install: $uvx"; return $true }
    Warn "uv installed but uvx is still not on PATH. Restart terminal or add Python Scripts directory to PATH."
    return $false
  }

  Warn "To enable MCP tools, run: python -m pip install uv"
  return $false
}

function Invoke-InProject([string]$ProjectRoot, [scriptblock]$Action) {
  Push-Location -LiteralPath $ProjectRoot
  try { & $Action } finally { Pop-Location }
}

function Invoke-CodeGraphBootstrap([string]$ProjectRoot) {
  if ($SkipBuildCodeGraph) { Warn "Skipping code-review-graph build because -SkipBuildCodeGraph was set."; return }
  if (-not (Ensure-UvxForBootstrap)) { Warn "Skipping code-review-graph because uvx is unavailable."; return }
  Invoke-InProject $ProjectRoot {
    Info "Checking code-review-graph status."
    if ($DryRun) { Info "Would run: uvx code-review-graph status"; return }
    uvx code-review-graph status
    if ($LASTEXITCODE -ne 0) {
      Warn "code-review-graph status failed; attempting build."
      uvx code-review-graph build
    }
  }
}

function Write-BootstrapReport([string]$ProjectRoot, [array]$Recommendations) {
  $skillRoot = Join-Path $ProjectRoot '.claude\skills'
  $commandRoot = Join-Path $ProjectRoot '.claude\commands'
  $mcpPath = Join-Path $ProjectRoot '.mcp.json'
  $skills = if (Test-Path -LiteralPath $skillRoot) { @(Get-ChildItem -LiteralPath $skillRoot -Directory | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } | Select-Object -ExpandProperty Name) } else { @() }
  $commands = if (Test-Path -LiteralPath $commandRoot) { @(Get-ChildItem -LiteralPath $commandRoot -File -Filter '*.md' | Select-Object -ExpandProperty Name) } else { @() }
  $mcpServers = @()
  if (Test-Path -LiteralPath $mcpPath) { $mcpServers = @((Normalize-McpServers (Read-JsonFile $mcpPath)).Keys) }

  Write-Host "`nFull bootstrap report:" -ForegroundColor Cyan
  Write-Host "- Project: $ProjectRoot"
  Write-Host "- Installed project skills: $($skills.Count)"
  if ($skills.Count -gt 0) { Write-Host "  $($skills -join ', ')" }
  Write-Host "- Project commands: $($commands -join ', ')"
  Write-Host "- MCP servers: $($mcpServers -join ', ')"
  Write-Host "- Recommended skills: $((@($Recommendations | ForEach-Object { $_.Skill })) -join ', ')"
  if (-not (Get-CommandPath 'uvx')) { Write-Host "- Blocker: uvx is not on PATH. Run: python -m pip install uv, then restart terminal if needed." -ForegroundColor Yellow }
  Write-Host "- Next Claude Code step: restart/open Claude in this project, then run /scrum-align"
}

function Install-CodeReviewGraphMcpPreset([string]$Root) {
  $mcpRoot = Join-Path $Root 'mcp'
  $path = Join-Path $mcpRoot 'code-review-graph.json'
  if ((Test-Path -LiteralPath $path) -and -not $Force) { Warn "code-review-graph MCP preset exists, skipping without -Force: $path"; return }
  $preset = [ordered]@{
    mcpServers = [ordered]@{
      'code-review-graph' = [ordered]@{
        command = 'uvx'
        args = @('code-review-graph', 'serve')
      }
    }
  }
  Info "Installing code-review-graph MCP preset -> $path"
  Write-JsonFile $path $preset
}

function Install-ModelTaskOptimizerMcpPreset([string]$Root) {
  $mcpRoot = Join-Path $Root 'mcp'
  $path = Join-Path $mcpRoot 'model-task-optimizer.json'
  if ((Test-Path -LiteralPath $path) -and -not $Force) { Warn "model-task-optimizer MCP preset exists, skipping without -Force: $path"; return }
  $localPackage = Join-Path $ScriptRoot 'model-task-optimizer-mcp'
  $args = if (Test-Path -LiteralPath $localPackage) { @('--from', $localPackage, 'model-task-optimizer-mcp') } else { @('model-task-optimizer-mcp') }
  $preset = [ordered]@{
    mcpServers = [ordered]@{
      'model-task-optimizer' = [ordered]@{
        command = 'uvx'
        args = $args
      }
    }
  }
  Info "Installing model-task-optimizer MCP preset -> $path"
  Write-JsonFile $path $preset
}

function Load-All-McpServers([string]$Root) {
  $candidates = @((Join-Path $Root 'mcp.json'), (Join-Path $Root '.mcp.json'), (Join-Path $Root 'mcp\servers.json'), (Join-Path $Root 'mcp\mcp.json'), (Join-Path $Root 'mcp\code-review-graph.json'), (Join-Path $Root 'mcp\model-task-optimizer.json'))
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
  if (Test-JsonFileContentEqual $configPath $config) {
    Ok "$TargetName MCP config already up to date: $configPath"
  } else {
    Backup-File $configPath | Out-Null
    Write-JsonFile $configPath $config
    Ok "Merged $($McpServers.Keys.Count) MCP server(s) into $TargetName`: $configPath"
  }
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
  if (Test-JsonFileContentEqual $configPath $config) {
    Ok "OpenClaw skill registry already up to date: $configPath"
  } else {
    Backup-File $configPath | Out-Null
    Write-JsonFile $configPath $config
    Ok "Registered copied OpenClaw skills in $configPath"
  }
}

if ($ListTargets) {
  Write-Host "Built-in targets:" -ForegroundColor Cyan
  foreach ($name in $BuiltInTargets.Keys) {
    $d = $BuiltInTargets[$name]
    $note = if ($name -eq 'openclaw') { ' config write guarded by -AllowOpenClawConfigWrite' } else { '' }
    Write-Host "- $name -> root=$($d.root), skills=$($d.skills), mcp=$($d.mcpFile):$($d.mcpShape)$note"
  }
  Write-Host "`nOptional integrations:" -ForegroundColor Cyan
  Write-Host "- code-review-graph MCP preset: enabled by default; use -SkipCodeReviewGraphMcp to disable"
  Write-Host "- model-task-optimizer MCP preset: enabled by default; use -SkipModelTaskOptimizerMcp to disable"
  Write-Host "- GitHub catalog scan: use -ScanGithubCatalog -GithubOwner <owner>; public repos do not require GitHub login"
  exit 0
}

if ($FullBootstrap) {
  if ([string]::IsNullOrWhiteSpace($ProjectPath)) { throw '-ProjectPath is required for -FullBootstrap.' }
  $UpdateCatalog = $true
  $ProjectInstall = $true
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
  Clone-Or-Pull 'https://github.com/DevMeoU/code-review-graph.git' (Join-Path $catalog 'code-review-graph')
  if ($GithubOwner -ieq 'DevMeoU') { [void](Update-GithubCatalog $GithubOwner $catalog) }
  Ok "Catalog update step finished. Review/copy chosen skills into $Source\skills before syncing."
}

if ($ScanGithubCatalog) {
  $catalog = Join-Path $Source 'catalog'
  [void](Update-GithubCatalog $GithubOwner $catalog)
  if (-not $UpdateCatalog -and -not $ProjectInstall -and -not $FullBootstrap -and -not $RecommendSkills -and -not $InstallRecommendedSkills -and (-not $Targets -or $Targets.Count -eq 0)) {
    Ok "GitHub catalog scan finished."
    exit 0
  }
}

$shouldInstallCodeReviewGraphMcp = (-not $SkipCodeReviewGraphMcp) -and (-not $RecommendSkills -or $InstallRecommendedSkills -or $InstallCodeReviewGraphMcp -or $ProjectInstall -or $FullBootstrap)
if ($shouldInstallCodeReviewGraphMcp) { Install-CodeReviewGraphMcpPreset $Source }

$shouldInstallModelTaskOptimizerMcp = (-not $SkipModelTaskOptimizerMcp) -and (-not $RecommendSkills -or $InstallRecommendedSkills -or $InstallModelTaskOptimizerMcp -or $ProjectInstall -or $FullBootstrap)
if ($shouldInstallModelTaskOptimizerMcp) { Install-ModelTaskOptimizerMcpPreset $Source }

$recommendations = @()
if ($RecommendSkills -or $InstallRecommendedSkills -or $ProjectInstall) {
  $roots = if ($SkillCatalogRoots -and $SkillCatalogRoots.Count -gt 0) { $SkillCatalogRoots } else { Get-DefaultSkillCatalogRoots $Source }
  Info "Skill catalog roots: $($roots -join ', ')"
  $index = Get-SkillIndex $roots
  $recommendations = @(Get-ProjectSkillRecommendations $ProjectPath $index $ProjectTask)
  if ($ProjectInstall -or $InstallRecommendedSkills) { $recommendations = @(Add-BaselineRecommendations $recommendations $index $BaselineSkills) }
  if ($recommendations.Count -eq 0) { Warn "No installable skill recommendations found. Run -UpdateCatalog or add skills to ~/.agents/catalog or ./skills." }
  else {
    Write-Host "Recommended skills:" -ForegroundColor Cyan
    $recommendations | Format-Table Skill, Reason, Source -AutoSize
    if ($InstallRecommendedSkills) { Install-RecommendedSkills $recommendations $Source }
  }
  if ($RecommendSkills -and -not $InstallRecommendedSkills -and -not $ProjectInstall -and -not $UpdateCatalog) { exit 0 }
}

$mcpServers = Load-All-McpServers $Source

if ($ProjectInstall) {
  Install-ProjectAssets $ProjectPath $recommendations $mcpServers $ProjectTask
  if ($FullBootstrap) {
    $projectRoot = (Resolve-Path -LiteralPath $ProjectPath).Path
    Invoke-CodeGraphBootstrap $projectRoot
    Write-BootstrapReport $projectRoot $recommendations
    if (-not $Targets -or ($Targets.Count -eq 0)) { Ok "Full bootstrap complete. Restart/open Claude Code in the project, then run /scrum-align."; exit 0 }
  }
  if (-not $Targets -or ($Targets.Count -eq 0)) { Ok "Done. Restart project agents so new config is picked up."; exit 0 }
}

if (-not $Targets -or $Targets.Count -eq 0) {
  if ($ProjectInstall) { Ok "Done. Restart project agents so new config is picked up."; exit 0 }
  $Targets = @('claude', 'openclaw')
}

$TargetDefs = Resolve-Targets $Targets
Info "Targets: $($TargetDefs.Keys -join ', ')"
foreach ($name in $TargetDefs.Keys) { Ensure-Dir $TargetDefs[$name].root; Ensure-Dir (Join-Path $TargetDefs[$name].root $TargetDefs[$name].skills) }

$installed = @(Copy-Skills $Source $TargetDefs)
if ($mcpServers.Keys.Count -gt 0) { foreach ($name in $TargetDefs.Keys) { Merge-Mcp-IntoTarget $name $TargetDefs[$name] $mcpServers } }
else { Warn "No MCP config found in ~/.agents. Add ~/.agents/mcp.json with a mcpServers object to sync MCP." }
Register-OpenClawSkills $TargetDefs $installed
Ok "Done. Restart target agents so new config is picked up."
