---
name: claude-api
description: Build, debug, and optimize Claude API and Anthropic SDK applications with prompt caching as a default. Apply when integrating the Anthropic Python or TypeScript SDK, when migrating between Claude model versions, when tuning cache hit rate, or when implementing tool use, streaming, or batching.
---

# Claude API

The Claude API rewards careful structuring. Prompt caching cuts cost 90% on repeated context. Tool definitions belong in cached blocks. Model selection is a tradeoff curve, not a default. This skill covers the patterns that make Claude apps cheap, fast, and correct.

## When to use

- Code imports `anthropic` (Python) or `@anthropic-ai/sdk` (TypeScript)
- Adding or modifying a Claude API call
- Migrating between model versions (e.g. Sonnet 4.5 → Sonnet 4.6)
- Tuning prompt caching for cost / latency
- Implementing tool use, streaming, batching, or files API
- Cache hit rate is below expectation
- Cost suddenly spiked

Skip when: code uses a different LLM provider (OpenAI, Cohere, etc.), or generic ML / NLP work without Anthropic SDK.

## How to apply

### 1. Always enable prompt caching

Default for any non-trivial system prompt or tool list. Mark the cacheable suffix with `cache_control`:

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
        # tool definitions...
        {**LAST_TOOL, "cache_control": {"type": "ephemeral"}}
    ],
    messages=[
        {"role": "user", "content": user_input}
    ]
)
```

Cache breakpoints (`cache_control`) mark the **end** of a cacheable prefix. Everything from the start of the request to that breakpoint is cached for ~5 minutes (TTL).

### 2. Cache structure that wins

Order content from most-stable to least-stable:

```
system prompt (rarely changes)
  ↓
tool definitions (rarely changes)
  ↓
few-shot examples (per-task, but stable)
  ↓
conversation history (grows over time)
  ↓
current user message (always new)
```

Place `cache_control` after each stable layer. The cache hit you want: same system + tools + examples → only the new turn is uncached.

### 3. Read the response usage block

Every response includes:

```
usage: {
  input_tokens: 80,
  cache_creation_input_tokens: 12000,    // first call: writes cache
  cache_read_input_tokens: 0,
  output_tokens: 250
}
```

On the next call with same prefix:

```
usage: {
  input_tokens: 80,
  cache_creation_input_tokens: 0,
  cache_read_input_tokens: 12000,        // cache HIT — 90% cheaper
  output_tokens: 250
}
```

If `cache_read_input_tokens` is consistently 0 on repeated calls, your cache key is changing — find what's drifting (timestamps, random IDs, varying message order).

### 4. Model selection

| Model | Best for | Speed | Cost |
|-------|----------|-------|------|
| Opus 4.x | Hard reasoning, architecture, design judgment | Slowest | Highest |
| Sonnet 4.x | Default for production tasks, balanced | Medium | Medium |
| Haiku 4.x | High-volume classification, routing, simple extraction | Fastest | Lowest |

Default to Sonnet. Drop to Haiku when latency or cost dominates and the task is simple. Escalate to Opus when correctness on hard reasoning matters more than cost.

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
            # Send tool_result back to continue conversation
```

Tool use loop: call → `tool_use` block → run tool → send `tool_result` → next call. Cache the tool list — it's stable.

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

Use streaming for UI responsiveness. Don't stream when you need the full response before acting (parsing JSON output, tool routing).

### 7. Batch API

For non-realtime work, use the Batch API for ~50% cost savings:

- Submit a batch of up to 100k requests
- Returns within 24 hours (often much faster)
- Good for: backfills, evals, offline processing

### 8. Migration between model versions

When upgrading (e.g. 4.5 → 4.7):

1. Update model string in one config point — never hardcode in N files
2. Re-run eval suite with the new model
3. Watch for regressions in: tool-use accuracy, JSON mode reliability, instruction following on long contexts
4. Cache structure should not need changes — it's model-agnostic
5. Spot-check token counts; tokenizer is similar but not identical between major versions

## Common mistakes

- No `cache_control` on system prompt → paying full price every call
- Cache breakpoint before something that varies (e.g. timestamp in system prompt) → cache never hits
- Long system prompt under cache minimum (1024 tokens for most models) → cache silently doesn't activate
- Reordering messages between calls → cache miss
- Hardcoded model name in 10 files → migration is 10 PRs instead of 1
- Using Opus for routing / classification → 5x cost for no quality gain
- Using Haiku for hard reasoning → wrong answers, hidden cost in retries
- Streaming when you need to parse the full output → wasted wrapper code
- Not checking `stop_reason` — `max_tokens` cutoff looks like success otherwise
- Tool descriptions vague ("does X stuff") → model picks wrong tool

## Quick reference

| Need | Solution |
|------|----------|
| Cut repeated-context cost 90% | `cache_control: ephemeral` after stable prefix |
| Verify cache works | Check `cache_read_input_tokens > 0` on 2nd call |
| Real-time UI | `client.messages.stream(...)` |
| 50% cost on async work | Batch API |
| Tool calling | Define tools, loop on `stop_reason == "tool_use"` |
| Hard task | Opus |
| Default | Sonnet |
| High-volume simple | Haiku |
| Migration | One config point, re-run evals |

## Verification before shipping

- [ ] `cache_control` on system + tools
- [ ] Confirmed cache hit on 2nd call (`cache_read_input_tokens > 0`)
- [ ] Model name in one config location
- [ ] Errors handled (rate limit, timeout, content filtered)
- [ ] Token usage logged per request (for cost monitoring)
- [ ] `stop_reason` checked (not just response text)
- [ ] Eval suite passes on chosen model

## Common Rationalizations

When you're tempted to skip this skill, watch for these excuses:

| Excuse | Reality |
|--------|---------|
| "Prompt caching is an optimization, not a correctness issue" | Cost per request scales with traffic — apps without caching burn 10x at scale. Cache from request #1, not request #100,000. |
| "This is a simple change, doesn't need <skill>" | Bugs hide in simple changes too — DAPLab data shows 41% of agentic-LLM failures land in 'trivial' diffs. |
| "I already know the answer" | Confirmation bias — the skill exists to surface what you didn't think of, not to repeat what you did. |
| "Time pressure, skip just this once" | Tech debt compounds; 5 minutes saved at write time costs 50 minutes of debugging later. |

Default response when rationalizing: run the skill anyway. Cost of running it is bounded; cost of skipping when you needed it is not.
