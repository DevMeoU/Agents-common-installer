from __future__ import annotations

import json
from typing import Any

from mcp.server.fastmcp import FastMCP

from .optimizer import MODEL_CATALOG, availability_report, make_routing_policy, profile_to_dict, recommend_model, tune_model_settings

mcp = FastMCP("model-task-optimizer")


def parse_constraints(constraints_json: str | None) -> dict[str, Any]:
    if not constraints_json:
        return {}
    try:
        parsed = json.loads(constraints_json)
    except json.JSONDecodeError as exc:
        raise ValueError(f"constraints_json must be valid JSON: {exc}") from exc
    if not isinstance(parsed, dict):
        raise ValueError("constraints_json must decode to a JSON object")
    return parsed


@mcp.tool()
def list_model_catalog() -> dict[str, Any]:
    """Return bundled model-family catalog used by the optimizer."""
    return {"models": [profile_to_dict(profile) for profile in MODEL_CATALOG]}


@mcp.tool()
def check_available_models(constraints_json: str | None = None) -> dict[str, Any]:
    """Check which supplied available models/providers are known to the optimizer catalog."""
    constraints = parse_constraints(constraints_json)
    return availability_report(constraints)


@mcp.tool()
def recommend_model_for_task(task_type: str, constraints_json: str | None = None) -> dict[str, Any]:
    """Recommend primary and fallback model choices for a task after availability is supplied."""
    constraints = parse_constraints(constraints_json)
    return recommend_model(task_type, constraints)


@mcp.tool()
def tune_model_for_task(task_type: str, constraints_json: str | None = None) -> dict[str, Any]:
    """Suggest model execution settings for a task."""
    constraints = parse_constraints(constraints_json)
    return tune_model_settings(task_type, constraints)


@mcp.tool()
def create_model_routing_policy(project_type: str = "general", constraints_json: str | None = None) -> dict[str, Any]:
    """Create a tiered model-routing policy for a project."""
    constraints = parse_constraints(constraints_json)
    return make_routing_policy(project_type, constraints)


def main() -> None:
    mcp.run()


if __name__ == "__main__":
    main()
