# @yourname/llm-stream

Streaming LLM output toolkit: SSE parsing + tolerant partial-JSON parsing + typed object snapshots. Zero dependencies.

`eventsource-parser` parses SSE; `partial-json` parses incomplete JSON. Every streaming app writes the glue by hand. This is the glue, self-contained.

```ts
import { streamSSEJson, parseSSE, parsePartialJSON, streamJSON } from "@yourname/llm-stream";

for await (const snap of streamSSEJson<MyShape>(response.body!, (e) =>
  JSON.parse(e.data).choices[0]?.delta.content
)) {
  render(snap.value); // grows as tokens arrive; snap.done on the final full parse
}
```

Handles events split across chunk boundaries, CRLF, multi-line data, multibyte characters split mid-chunk, and `[DONE]` sentinels. `parsePartialJSON` closes truncated strings/arrays/objects, drops dangling keys, and throws only on never-valid input. Works with `AsyncIterable` or `ReadableStream`. MIT.
