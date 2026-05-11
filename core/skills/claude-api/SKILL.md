---
name: claude-api
description: Build, debug, and optimize Claude API and Anthropic SDK applications with prompt caching as a default. Apply when integrating the Anthropic Python or TypeScript SDK, when migrating between Claude model versions, when tuning cache hit rate, or when implementing tool use, streaming, or batching.
---

# Claude API

Prompt caching cuts cost 90% on repeated context. Tool definitions belong in cached blocks. Model selection = tradeoff curve, not default.

## When to use

- Code imports `anthropic` (Python) or `@anthropic-ai/sdk` (TS)
- Adding/modifying Claude API call
- Migrating model versions (e.g. Sonnet 4.5 → 4.6)
- Tuning prompt caching
- Implementing tool use, streaming, batching, files API
- Cache hit rate below expectation
- Cost spiked

Skip: different LLM provider; generic ML/NLP without Anthropic SDK.

## How to apply

### 1. Always enable prompt caching

Default for non-trivial system prompt or tool list:

```python
from anthropic import Anthropic

client = Anthropic()

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": LONG_SYSTEM_PROMPT,
            "cache_control": {"type": "ephemeral"}
        }
    ],
    tools=[
        {**LAST_TOOL, "cache_control": {"type": "ephemeral"}}
    ],
    messages=[
        {"role": "user", "content": user_input}
    ]
)
```

`cache_control` marks end of cacheable prefix. Cached ~5 min TTL.

### 2. Cache structure that wins

Order most-stable → least-stable:

```
system prompt (rarely changes)
  ↓
tool definitions (rarely changes)
  ↓
few-shot examples (per-task, stable)
  ↓
conversation history (grows)
  ↓
current user message (always new)
```

Place `cache_control` after each stable layer.

### 3. Read response usage block

```
usage: {
  input_tokens: 80,
  cache_creation_input_tokens: 12000,    // first call: writes cache
  cache_read_input_tokens: 0,
  output_tokens: 250
}
```

Next call same prefix:

```
usage: {
  input_tokens: 80,
  cache_creation_input_tokens: 0,
  cache_read_input_tokens: 12000,        // cache HIT — 90% cheaper
  output_tokens: 250
}
```

Consistently 0 `cache_read_input_tokens` on repeated calls → cache key drifting. Find varying field (timestamp, random ID, reordered messages).

### 4. Model selection

| Model | Best for | Speed | Cost |
|-------|----------|-------|------|
| Opus 4.x | Hard reasoning, architecture, design judgment | Slowest | Highest |
| Sonnet 4.x | Default for production | Medium | Medium |
| Haiku 4.x | Classification, routing, simple extraction | Fastest | Lowest |

Default Sonnet. Drop to Haiku when latency/cost dominates and task is simple. Escalate to Opus when correctness on hard reasoning > cost.

### 5. Tool use

```python
tools = [
    {
        "name": "get_weather",
        "description": "Get current weather for a location",
        "input_schema": {
            "type": "object",
            "properties": {
                "location": {"type": "string"}
            },
            "required": ["location"]
        }
    }
]

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    tools=tools,
    messages=[{"role": "user", "content": "Weather in Bangkok?"}]
)

if response.stop_reason == "tool_use":
    for block in response.content:
        if block.type == "tool_use":
            result = run_tool(block.name, block.input)
            # Send tool_result back to continue
```

Loop: call → `tool_use` block → run tool → send `tool_result` → next call. Cache tool list — it's stable.

### 6. Streaming

```python
with client.messages.stream(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": prompt}]
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

Stream for UI. Don't stream when full response needed before acting (parse JSON, tool routing).

### 7. Batch API

Non-realtime work → ~50% cost savings. Up to 100k requests, returns within 24h (often faster). Use for: backfills, evals, offline processing.

### 8. Migration between versions

1. Update model string in one config point — never hardcode in N files
2. Re-run eval suite
3. Watch regressions in: tool-use accuracy, JSON mode, instruction following on long contexts
4. Cache structure model-agnostic — no changes needed
5. Spot-check token counts; tokenizer similar but not identical across majors

## Common mistakes

- No `cache_control` on system prompt → full price every call
- Cache breakpoint before varying field (timestamp in system prompt) → never hits
- Long system prompt under cache minimum (1024 tokens for most models) → silently doesn't activate
- Reordering messages between calls → miss
- Hardcoded model in 10 files → migration is 10 PRs
- Opus for routing/classification → 5x cost, no quality gain
- Haiku for hard reasoning → wrong answers, hidden retry cost
- Streaming when parsing full output → wasted wrapper
- Not checking `stop_reason` — `max_tokens` cutoff looks like success
- Vague tool descriptions ("does X stuff") → model picks wrong tool

## Quick reference

| Need | Solution |
|------|----------|
| Cut repeated-context cost 90% | `cache_control: ephemeral` after stable prefix |
| Verify cache works | `cache_read_input_tokens > 0` on 2nd call |
| Real-time UI | `client.messages.stream(...)` |
| 50% cost on async | Batch API |
| Tool calling | Define tools, loop on `stop_reason == "tool_use"` |
| Hard task | Opus |
| Default | Sonnet |
| High-volume simple | Haiku |
| Migration | One config point, re-run evals |

## Verification before shipping

- [ ] `cache_control` on system + tools
- [ ] Confirmed cache hit on 2nd call
- [ ] Model name in one config location
- [ ] Errors handled (rate limit, timeout, content filtered)
- [ ] Token usage logged per request
- [ ] `stop_reason` checked
- [ ] Eval suite passes on chosen model

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Caching is optimization, not correctness" | Apps without caching burn 10x at scale. Cache from request #1. |
| "Simple change" | 41% of agentic-LLM failures land in trivial diffs (DAPLab). |
| "Time pressure" | Tech debt compounds. |

Default: run anyway.
