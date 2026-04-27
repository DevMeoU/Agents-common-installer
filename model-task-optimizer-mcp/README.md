# model-task-optimizer-mcp

MCP server that recommends model/provider/routing choices for a task and returns tuning guidance for latency, cost, context, tool use, and accuracy constraints. The bundled catalog includes GPT-5.5 plus reference Claude Opus/Sonnet, Grok, DeepSeek, Gemini, Kimi, and Qwen entries, but recommendations only use a model when `available_models` or `available_providers` confirms it is available.

## Tools

- `check_available_models`: verify supplied `available_models` / `available_providers` against the catalog before any recommendation.
- `recommend_model`: score only available model families for a task and return primary/fallback choices.
- `make_routing_policy`: create a tiered routing policy for project use after availability is known.
- `tune_model_settings`: suggest temperature, context strategy, reasoning budget, caching, batching, and validation after availability is known.
- `list_model_catalog`: return the bundled model-family catalog.

## Run locally

```sh
uvx --from ./model-task-optimizer-mcp model-task-optimizer-mcp
```

For common installer sync, the generated MCP preset points to the local package path when this repo is available.
