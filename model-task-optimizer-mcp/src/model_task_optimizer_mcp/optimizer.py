from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class ModelProfile:
    name: str
    provider: str
    strengths: tuple[str, ...]
    best_for: tuple[str, ...]
    latency: str
    cost: str
    context: str
    tool_use: str
    notes: str


MODEL_CATALOG: tuple[ModelProfile, ...] = (
    ModelProfile(
        name="gpt-5.5",
        provider="OpenAI",
        strengths=("reasoning", "coding", "tool_use", "structured_output", "multimodal", "architecture"),
        best_for=("architecture", "security", "debugging", "code_review", "agentic", "implementation"),
        latency="medium",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use for top-tier reasoning, complex coding, architecture, and high-accuracy agentic workflows when available.",
    ),
    ModelProfile(
        name="cx/gpt-5.4-xhigh",
        provider="KenDev-API",
        strengths=("reasoning", "coding", "tool_use", "structured_output", "architecture"),
        best_for=("architecture", "security", "debugging", "code_review", "agentic"),
        latency="high",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use for highest-effort reasoning, difficult architecture, security review, and complex debugging.",
    ),
    ModelProfile(
        name="cx/gpt-5.4-high",
        provider="KenDev-API",
        strengths=("reasoning", "coding", "tool_use", "structured_output"),
        best_for=("implementation", "debugging", "architecture", "code_review"),
        latency="medium",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use for high-quality coding and review when xhigh is unnecessary.",
    ),
    ModelProfile(
        name="cx/gpt-5.4",
        provider="KenDev-API",
        strengths=("coding", "reasoning", "tool_use", "analysis"),
        best_for=("implementation", "analysis", "planning", "agentic"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Balanced default for agentic coding and general engineering tasks.",
    ),
    ModelProfile(
        name="cx/gpt-5.3-codex-xhigh",
        provider="KenDev-API",
        strengths=("coding", "reasoning", "debugging", "tool_use"),
        best_for=("debugging", "implementation", "tests", "refactor", "code_review"),
        latency="high",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use for hardest coding/debugging tasks requiring extra reasoning effort.",
    ),
    ModelProfile(
        name="cx/gpt-5.3-codex-high",
        provider="KenDev-API",
        strengths=("coding", "debugging", "tool_use", "tests"),
        best_for=("implementation", "debugging", "tests", "refactor"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Use for routine-to-hard coding implementation with good quality/speed balance.",
    ),
    ModelProfile(
        name="cx/gpt-5.3-codex",
        provider="KenDev-API",
        strengths=("coding", "tool_use", "tests"),
        best_for=("implementation", "tests", "refactor", "simple_edits"),
        latency="low",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Default Codex route for normal implementation work.",
    ),
    ModelProfile(
        name="cx/gpt-5.3-codex-low",
        provider="KenDev-API",
        strengths=("coding", "speed", "simple_edits"),
        best_for=("simple_edits", "tests", "classification", "extraction"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for fast small edits, test updates, and deterministic code transformations.",
    ),
    ModelProfile(
        name="cx/gpt-5.3-codex-none",
        provider="KenDev-API",
        strengths=("speed", "classification", "extraction"),
        best_for=("classification", "extraction", "batch", "simple_edits"),
        latency="very_low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use when minimal reasoning is enough and latency/cost matters most.",
    ),
    ModelProfile(
        name="cx/gpt-5.2-codex",
        provider="KenDev-API",
        strengths=("coding", "tests", "cost_efficiency"),
        best_for=("implementation", "tests", "batch", "simple_edits"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use as low-cost fallback for coding and tests.",
    ),
    ModelProfile(
        name="cx/gpt-5.2",
        provider="KenDev-API",
        strengths=("analysis", "summarization", "classification"),
        best_for=("analysis", "summarization", "classification", "batch"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for general analysis and lower-cost non-Codex tasks.",
    ),
    ModelProfile(
        name="cx/gpt-5.1-codex-max",
        provider="KenDev-API",
        strengths=("coding", "agentic", "tool_use"),
        best_for=("agentic", "implementation", "debugging"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Use as legacy/compatibility route for larger Codex tasks.",
    ),
    ModelProfile(
        name="cx/gpt-5.1-codex-mini-high",
        provider="KenDev-API",
        strengths=("coding", "speed", "tests"),
        best_for=("tests", "simple_edits", "batch", "classification"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for small coding jobs that need a bit more reasoning than mini.",
    ),
    ModelProfile(
        name="cx/gpt-5.1-codex-mini",
        provider="KenDev-API",
        strengths=("speed", "classification", "simple_edits"),
        best_for=("classification", "extraction", "batch", "simple_edits"),
        latency="very_low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for fastest low-cost coding-adjacent tasks.",
    ),
    ModelProfile(
        name="cx/gpt-5.1-codex",
        provider="KenDev-API",
        strengths=("coding", "tests", "tool_use"),
        best_for=("implementation", "tests", "simple_edits"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use as compatibility fallback for coding tasks.",
    ),
    ModelProfile(
        name="cx/gpt-5.1",
        provider="KenDev-API",
        strengths=("analysis", "summarization", "classification"),
        best_for=("analysis", "summarization", "classification"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use as compatibility fallback for non-coding analysis.",
    ),
    ModelProfile(
        name="cx/gpt-5-codex",
        provider="KenDev-API",
        strengths=("coding", "tests"),
        best_for=("implementation", "tests", "simple_edits"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use only when newer Codex models are unavailable.",
    ),
    ModelProfile(
        name="cx/gpt-5-codex-mini",
        provider="KenDev-API",
        strengths=("speed", "simple_edits", "classification"),
        best_for=("simple_edits", "classification", "extraction"),
        latency="very_low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use only for very small low-cost tasks when newer mini models are unavailable.",
    ),
    ModelProfile(
        name="claude-opus-4-7",
        provider="Anthropic",
        strengths=("reasoning", "coding", "review", "architecture", "long_context", "writing"),
        best_for=("architecture", "security", "code_review", "debugging", "planning"),
        latency="medium",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use for difficult cross-file changes, supervision, security review, and nuanced design tradeoffs.",
    ),
    ModelProfile(
        name="claude-opus-4-6",
        provider="Anthropic",
        strengths=("reasoning", "coding", "review", "architecture", "long_context", "writing"),
        best_for=("architecture", "security", "code_review", "debugging", "planning"),
        latency="medium",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use as an Opus reasoning route when available and Opus 4.7 is not selected.",
    ),
    ModelProfile(
        name="claude-opus-4-5",
        provider="Anthropic",
        strengths=("reasoning", "coding", "review", "architecture", "long_context"),
        best_for=("architecture", "security", "code_review", "debugging"),
        latency="medium",
        cost="high",
        context="long",
        tool_use="excellent",
        notes="Use as a legacy Opus high-reasoning fallback when available.",
    ),
    ModelProfile(
        name="claude-sonnet-4-6",
        provider="Anthropic",
        strengths=("coding", "tool_use", "balanced_reasoning", "speed"),
        best_for=("implementation", "refactor", "tests", "analysis", "agentic"),
        latency="low",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Default balanced coding model when speed, cost, and quality all matter.",
    ),
    ModelProfile(
        name="claude-sonnet-4-5",
        provider="Anthropic",
        strengths=("coding", "tool_use", "balanced_reasoning", "speed"),
        best_for=("implementation", "refactor", "tests", "analysis", "agentic"),
        latency="low",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Use as a Sonnet balanced fallback when available.",
    ),
    ModelProfile(
        name="claude-sonnet-4",
        provider="Anthropic",
        strengths=("coding", "tool_use", "analysis"),
        best_for=("implementation", "tests", "analysis", "refactor"),
        latency="low",
        cost="medium",
        context="long",
        tool_use="excellent",
        notes="Use as compatibility fallback for balanced Claude coding tasks.",
    ),
    ModelProfile(
        name="claude-haiku-4-5",
        provider="Anthropic",
        strengths=("speed", "classification", "extraction", "summarization"),
        best_for=("batch", "triage", "classification", "simple_edits"),
        latency="very_low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for cheap fast passes, bulk classification, and deterministic extraction.",
    ),
    ModelProfile(
        name="gemini-2.5-pro",
        provider="Google",
        strengths=("long_context", "multimodal", "analysis", "coding", "reasoning"),
        best_for=("long_context", "multimodal", "research", "analysis", "architecture"),
        latency="medium",
        cost="medium",
        context="very_long",
        tool_use="good",
        notes="Use for very large context, multimodal analysis, and document-heavy workflows when available.",
    ),
    ModelProfile(
        name="gemini-2.5-flash",
        provider="Google",
        strengths=("speed", "multimodal", "analysis", "cost_efficiency"),
        best_for=("summarization", "classification", "extraction", "multimodal", "batch"),
        latency="low",
        cost="low",
        context="very_long",
        tool_use="good",
        notes="Use for fast low-cost Gemini workflows and multimodal/batch tasks when available.",
    ),
    ModelProfile(
        name="gemini-2.0-flash",
        provider="Google",
        strengths=("speed", "multimodal", "summarization", "classification"),
        best_for=("summarization", "classification", "extraction", "batch"),
        latency="very_low",
        cost="low",
        context="long",
        tool_use="good",
        notes="Use as a fast Gemini compatibility route when available.",
    ),
    ModelProfile(
        name="grok-4",
        provider="xAI",
        strengths=("reasoning", "realtime", "analysis", "coding"),
        best_for=("research", "realtime", "analysis", "debugging"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="good",
        notes="Use when realtime/xAI ecosystem access is important.",
    ),
    ModelProfile(
        name="grok-4-fast",
        provider="xAI",
        strengths=("speed", "realtime", "analysis"),
        best_for=("research", "realtime", "summarization", "classification"),
        latency="low",
        cost="medium",
        context="long",
        tool_use="good",
        notes="Use for lower-latency Grok workflows when available.",
    ),
    ModelProfile(
        name="grok-3",
        provider="xAI",
        strengths=("reasoning", "realtime", "analysis"),
        best_for=("research", "realtime", "analysis"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="good",
        notes="Use as a Grok compatibility route when available.",
    ),
    ModelProfile(
        name="kimi-k2",
        provider="Moonshot AI",
        strengths=("agentic", "coding", "long_context", "cost_efficiency"),
        best_for=("agentic", "coding", "long_context", "batch"),
        latency="low",
        cost="low",
        context="long",
        tool_use="good",
        notes="Use for cost-efficient agentic coding and long-context tasks when available.",
    ),
    ModelProfile(
        name="kimi-k2-thinking",
        provider="Moonshot AI",
        strengths=("reasoning", "agentic", "coding", "long_context"),
        best_for=("architecture", "debugging", "agentic", "long_context"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="good",
        notes="Use for Kimi reasoning/agentic workflows when available.",
    ),
    ModelProfile(
        name="kimi-latest",
        provider="Moonshot AI",
        strengths=("long_context", "analysis", "cost_efficiency"),
        best_for=("long_context", "analysis", "summarization"),
        latency="low",
        cost="low",
        context="long",
        tool_use="good",
        notes="Use as a generic Kimi route when an exact Kimi model is exposed by the provider.",
    ),
    ModelProfile(
        name="deepseek-v3.2",
        provider="DeepSeek",
        strengths=("coding", "math", "cost_efficiency", "batch"),
        best_for=("coding", "tests", "batch", "analysis"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for low-cost code generation, tests, and bulk transformations when provider risk is acceptable.",
    ),
    ModelProfile(
        name="deepseek-r1",
        provider="DeepSeek",
        strengths=("reasoning", "math", "debugging", "analysis"),
        best_for=("debugging", "architecture", "analysis", "math"),
        latency="medium",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for cost-efficient reasoning-heavy tasks when available.",
    ),
    ModelProfile(
        name="deepseek-coder",
        provider="DeepSeek",
        strengths=("coding", "tests", "cost_efficiency"),
        best_for=("implementation", "tests", "simple_edits", "batch"),
        latency="low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for low-cost coding tasks when available.",
    ),
    ModelProfile(
        name="qwen3-coder",
        provider="Alibaba Cloud",
        strengths=("coding", "agentic", "tool_use", "cost_efficiency"),
        best_for=("implementation", "tests", "refactor", "agentic"),
        latency="low",
        cost="low",
        context="long",
        tool_use="good",
        notes="Use for cost-efficient coding and agentic software tasks when available.",
    ),
    ModelProfile(
        name="qwen3-max",
        provider="Alibaba Cloud",
        strengths=("reasoning", "coding", "analysis", "long_context"),
        best_for=("architecture", "analysis", "debugging", "implementation"),
        latency="medium",
        cost="medium",
        context="long",
        tool_use="good",
        notes="Use as a stronger Qwen reasoning/coding route when available.",
    ),
    ModelProfile(
        name="qwen-plus",
        provider="Alibaba Cloud",
        strengths=("analysis", "coding", "cost_efficiency"),
        best_for=("analysis", "implementation", "summarization", "batch"),
        latency="low",
        cost="low",
        context="long",
        tool_use="good",
        notes="Use as a balanced Qwen route when available.",
    ),
    ModelProfile(
        name="qwen-turbo",
        provider="Alibaba Cloud",
        strengths=("speed", "classification", "summarization", "extraction"),
        best_for=("classification", "extraction", "summarization", "batch"),
        latency="very_low",
        cost="low",
        context="medium",
        tool_use="good",
        notes="Use for fast low-cost Qwen batch/extraction tasks when available.",
    ),
    ModelProfile(
        name="nvidia-nemotron",
        provider="Nvidia",
        strengths=("enterprise", "local", "gpu", "throughput"),
        best_for=("local", "enterprise", "batch", "privacy"),
        latency="variable",
        cost="variable",
        context="medium",
        tool_use="good",
        notes="Use for self-hosted/GPU/enterprise deployments with privacy or throughput constraints.",
    ),
)

TASK_ALIASES = {
    "code": "implementation",
    "coding": "implementation",
    "implement": "implementation",
    "review": "code_review",
    "security": "security",
    "architect": "architecture",
    "debug": "debugging",
    "bug": "debugging",
    "summarize": "summarization",
    "extract": "extraction",
    "classify": "classification",
    "research": "research",
    "long": "long_context",
    "multimodal": "multimodal",
}


LOW_LATENCY = {"very_low": 3, "low": 2, "medium": 1, "variable": 1, "high": 0}
LOW_COST = {"low": 3, "medium": 2, "variable": 1, "high": 0}
CONTEXT_SCORE = {"medium": 1, "long": 2, "very_long": 3}


def normalize_task(task: str) -> str:
    lowered = task.strip().lower().replace("-", "_").replace(" ", "_")
    return TASK_ALIASES.get(lowered, lowered)


def profile_to_dict(profile: ModelProfile) -> dict[str, Any]:
    return {
        "name": profile.name,
        "provider": profile.provider,
        "strengths": list(profile.strengths),
        "best_for": list(profile.best_for),
        "latency": profile.latency,
        "cost": profile.cost,
        "context": profile.context,
        "tool_use": profile.tool_use,
        "notes": profile.notes,
    }


def get_available_model_names(constraints: dict[str, Any]) -> set[str]:
    values = constraints.get("available_models") or constraints.get("available_model_names") or []
    return {str(value).strip().lower() for value in values if str(value).strip()}


def get_available_provider_names(constraints: dict[str, Any]) -> set[str]:
    values = constraints.get("available_providers") or []
    return {str(value).strip().lower() for value in values if str(value).strip()}


def model_name_matches(profile_name: str, available_name: str) -> bool:
    profile = profile_name.lower()
    available = available_name.lower()
    short_available = available.rsplit("/", 1)[-1]
    short_profile = profile.rsplit("/", 1)[-1]
    return profile == available or profile == short_available or short_profile == available or short_profile == short_available


def get_available_profiles(constraints: dict[str, Any]) -> list[ModelProfile]:
    model_names = get_available_model_names(constraints)
    provider_names = get_available_provider_names(constraints)
    if not model_names and not provider_names:
        return []
    return [
        profile
        for profile in MODEL_CATALOG
        if any(model_name_matches(profile.name, name) for name in model_names) or profile.provider.lower() in provider_names
    ]


def availability_report(constraints: dict[str, Any]) -> dict[str, Any]:
    available = get_available_profiles(constraints)
    return {
        "availability_checked": bool(get_available_model_names(constraints) or get_available_provider_names(constraints)),
        "available_models": [profile_to_dict(profile) for profile in available],
        "available_model_count": len(available),
        "missing_availability_action": "Provide constraints_json with available_models and/or available_providers before changing model settings.",
    }


def score_model(profile: ModelProfile, task_type: str, constraints: dict[str, Any]) -> tuple[int, list[str]]:
    score = 0
    reasons: list[str] = []
    task = normalize_task(task_type)

    if task in profile.best_for:
        score += 5
        reasons.append(f"strong fit for {task}")
    if task in profile.strengths:
        score += 3
        reasons.append(f"has {task} strength")

    text = f"{task_type} {constraints.get('description', '')}".lower()
    for signal in profile.best_for + profile.strengths:
        if signal.replace("_", " ") in text or signal in text:
            score += 1

    priority = str(constraints.get("priority", "balanced")).lower()
    if priority in {"speed", "latency", "fast"}:
        score += LOW_LATENCY.get(profile.latency, 0)
        reasons.append(f"latency tier is {profile.latency}")
    elif priority in {"cost", "cheap", "budget"}:
        score += LOW_COST.get(profile.cost, 0)
        reasons.append(f"cost tier is {profile.cost}")
    elif priority in {"accuracy", "quality", "reasoning"}:
        if "reasoning" in profile.strengths or profile.cost == "high":
            score += 3
            reasons.append("prioritizes higher reasoning quality")

    if constraints.get("long_context") or task == "long_context":
        score += CONTEXT_SCORE.get(profile.context, 0)
        reasons.append(f"context tier is {profile.context}")
    if constraints.get("tool_use") and profile.tool_use in {"excellent", "good"}:
        score += 2 if profile.tool_use == "excellent" else 1
        reasons.append(f"tool use is {profile.tool_use}")
    if constraints.get("privacy") in {"local", "self_hosted", True} and profile.provider == "Nvidia":
        score += 4
        reasons.append("fits local/self-hosted privacy constraint")

    return score, reasons or [profile.notes]


def require_available_profiles(constraints: dict[str, Any]) -> list[ModelProfile]:
    available = get_available_profiles(constraints)
    if available:
        return available
    return []


def recommend_model(task_type: str, constraints: dict[str, Any] | None = None) -> dict[str, Any]:
    constraints = constraints or {}
    availability = availability_report(constraints)
    available_profiles = require_available_profiles(constraints)
    if not available_profiles:
        return {
            "status": "availability_required",
            "task_type": normalize_task(task_type),
            **availability,
            "recommendation": None,
            "assumptions": [
                "No model will be selected until available_models or available_providers is supplied.",
                "Check provider accounts, CLI/API configuration, local model runtime, or project config first.",
            ],
        }

    scored = []
    for profile in available_profiles:
        score, reasons = score_model(profile, task_type, constraints)
        scored.append((score, profile, reasons))
    scored.sort(key=lambda item: item[0], reverse=True)
    primary_score, primary, primary_reasons = scored[0]
    if len(scored) > 1:
        fallback_score, fallback, fallback_reasons = scored[1]
        fallback_payload = profile_to_dict(fallback)
    else:
        fallback_score, fallback_reasons, fallback_payload = None, [], None
    return {
        "task_type": normalize_task(task_type),
        "primary": profile_to_dict(primary),
        "primary_score": primary_score,
        "primary_reasons": primary_reasons,
        "fallback": fallback_payload,
        "fallback_score": fallback_score,
        "fallback_reasons": fallback_reasons,
        "status": "recommended",
        **availability,
        "ranked": [
            {"score": score, "model": profile_to_dict(profile), "reasons": reasons}
            for score, profile, reasons in scored[:5]
        ],
        "assumptions": [
            "Only supplied available models/providers were considered.",
            "Validate with task-specific tests, evals, or human review before adopting for high-stakes workflows.",
        ],
    }


def tune_model_settings(task_type: str, constraints: dict[str, Any] | None = None) -> dict[str, Any]:
    constraints = constraints or {}
    availability = availability_report(constraints)
    if not availability["availability_checked"]:
        return {
            "status": "availability_required",
            "task_type": normalize_task(task_type),
            **availability,
            "settings": None,
        }
    task = normalize_task(task_type)
    priority = str(constraints.get("priority", "balanced")).lower()

    temperature = 0.2
    if task in {"creative", "brainstorm", "planning"}:
        temperature = 0.5
    if task in {"classification", "extraction", "tests", "security", "code_review"}:
        temperature = 0.1

    reasoning_budget = "medium"
    if task in {"architecture", "security", "debugging", "code_review"} or priority in {"accuracy", "quality", "reasoning"}:
        reasoning_budget = "high"
    elif priority in {"speed", "latency", "fast"} or task in {"classification", "extraction", "summarization"}:
        reasoning_budget = "low"

    context_strategy = "full"
    if constraints.get("long_context"):
        context_strategy = "chunked + retrieval + prompt caching"
    elif constraints.get("repository_scale"):
        context_strategy = "targeted retrieval + graph/context index"

    return {
        "status": "tuned",
        **availability,
        "task_type": task,
        "temperature": temperature,
        "reasoning_budget": reasoning_budget,
        "context_strategy": context_strategy,
        "tool_use": "enabled" if constraints.get("tool_use", True) else "restricted",
        "prompt_caching": "enable for stable system/developer/project context",
        "batching": "use for independent classification/extraction/eval cases" if task in {"classification", "extraction", "batch"} else "avoid unless tasks are independent",
        "validation": validation_for_task(task),
        "rework_reducer": rework_reducer_for_task(task),
    }


def validation_for_task(task: str) -> str:
    if task in {"implementation", "debugging", "tests"}:
        return "run relevant tests, type checks, lint, and targeted manual verification"
    if task in {"code_review", "security", "architecture"}:
        return "run independent review pass with evidence-linked findings and severity"
    if task in {"classification", "extraction"}:
        return "validate against JSON schema and sample gold cases"
    return "define a measurable acceptance check before execution"


def rework_reducer_for_task(task: str) -> str:
    if task in {"implementation", "debugging"}:
        return "ask for requirements only when ambiguity changes implementation, then verify with tests before reporting done"
    if task in {"architecture", "security", "code_review"}:
        return "separate evidence gathering from judgment and mark unknowns explicitly"
    return "use structured output and validate before downstream use"


def make_routing_policy(project_type: str = "general", constraints: dict[str, Any] | None = None) -> dict[str, Any]:
    constraints = constraints or {}
    availability = availability_report(constraints)
    if not availability["availability_checked"]:
        return {
            "status": "availability_required",
            "project_type": project_type,
            **availability,
            "routes": None,
        }
    return {
        "status": "policy_created",
        **availability,
        "project_type": project_type,
        "default_tier": recommend_model("implementation", constraints),
        "routes": {
            "simple_edits_or_extraction": recommend_model("classification", {**constraints, "priority": "speed"}),
            "routine_coding": recommend_model("implementation", {**constraints, "priority": "balanced", "tool_use": True}),
            "architecture_security_debugging": recommend_model("architecture", {**constraints, "priority": "accuracy", "tool_use": True}),
            "repo_or_document_sweep": recommend_model("long_context", {**constraints, "long_context": True}),
            "bulk_batch_work": recommend_model("batch", {**constraints, "priority": "cost"}),
        },
        "rules": [
            "Use only providers available in the target environment.",
            "Escalate to reasoning tier after repeated failures, regressions, or ambiguous requirements.",
            "Downgrade to fast/low-cost tier for deterministic extraction and repetitive transformations.",
            "Enable prompt caching for stable project context and batch prompts when provider supports it.",
        ],
    }
