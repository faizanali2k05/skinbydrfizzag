import { test } from "node:test";
import assert from "node:assert/strict";
import { parseSSE, parsePartialJSON, streamJSON, streamSSEJson, type SSEEvent } from "./index.js";

async function* chunks(...parts: string[]): AsyncGenerator<Uint8Array> {
  const enc = new TextEncoder();
  for (const p of parts) yield enc.encode(p);
}

async function collect<T>(gen: AsyncIterable<T>): Promise<T[]> {
  const out: T[] = [];
  for await (const v of gen) out.push(v);
  return out;
}

test("parseSSE: basic events and default event name", async () => {
  const events = await collect(parseSSE(chunks("data: hello\n\ndata: world\n\n")));
  assert.deepEqual(events.map((e) => e.data), ["hello", "world"]);
  assert.ok(events.every((e) => e.event === "message"));
});

test("parseSSE: event split across chunk boundaries", async () => {
  const events = await collect(parseSSE(chunks("da", "ta: he", "llo\n", "\n")));
  assert.deepEqual(events.map((e) => e.data), ["hello"]);
});

test("parseSSE: multi-line data, named events, ids, comments, CRLF", async () => {
  const raw = ": comment\r\nevent: delta\r\nid: 7\r\ndata: line1\r\ndata: line2\r\n\r\n";
  const events = await collect(parseSSE(chunks(raw)));
  assert.deepEqual(events, [{ event: "delta", data: "line1\nline2", id: "7" }]);
});

test("parseSSE: final event without trailing blank line is flushed", async () => {
  const events = await collect(parseSSE(chunks("data: tail")));
  assert.deepEqual(events.map((e) => e.data), ["tail"]);
});

test("parseSSE: multibyte characters split across chunks survive", async () => {
  const enc = new TextEncoder().encode("data: héllo\n\n");
  async function* split() {
    yield enc.slice(0, 8); // cuts é in half
    yield enc.slice(8);
  }
  const events = await collect(parseSSE(split()));
  assert.deepEqual(events.map((e) => e.data), ["héllo"]);
});

test("parsePartialJSON: complete documents parse exactly", () => {
  const doc = { a: 1, b: [true, null, "x"], c: { d: -2.5e2 } };
  assert.deepEqual(parsePartialJSON(JSON.stringify(doc)), doc);
});

test("parsePartialJSON: truncations at every prefix are safe and monotone", () => {
  const full = '{"name": "Ada Lovelace", "tags": ["math", "code"], "age": 36, "ok": true}';
  for (let i = 1; i <= full.length; i++) {
    const v = parsePartialJSON(full.slice(0, i)); // must never throw
    if (i === full.length) assert.deepEqual(v, JSON.parse(full));
  }
});

test("parsePartialJSON: representative partial shapes", () => {
  assert.deepEqual(parsePartialJSON('{"a": "hel'), { a: "hel" });
  assert.deepEqual(parsePartialJSON('{"a": 12, "b'), { a: 12 });
  assert.deepEqual(parsePartialJSON('[1, 2, {"x": tru'), [1, 2, {}]);
  assert.deepEqual(parsePartialJSON('{"s": "a\\'), { s: "a" });
  assert.equal(parsePartialJSON("  "), undefined);
});

test("parsePartialJSON: throws on inputs that can never become valid", () => {
  assert.throws(() => parsePartialJSON("{]"), SyntaxError);
  assert.throws(() => parsePartialJSON('{"a" 1}'), SyntaxError);
  assert.throws(() => parsePartialJSON("[1 2]"), SyntaxError);
  assert.throws(() => parsePartialJSON("@"), SyntaxError);
});

test("streamJSON yields growing snapshots then a done parse", async () => {
  async function* frags() {
    yield '{"story": "Once';
    yield ' upon", "rating"';
    yield ": 5}";
  }
  const snaps = await collect(streamJSON<{ story: string; rating: number }>(frags()));
  assert.equal(snaps.length, 4); // one per fragment + final done snapshot
  assert.deepEqual(snaps[0], { value: { story: "Once" }, done: false });
  assert.deepEqual(snaps[1], { value: { story: "Once upon" }, done: false });
  assert.deepEqual(snaps[2], { value: { story: "Once upon", rating: 5 }, done: false });
  assert.deepEqual(snaps.at(-1), { value: { story: "Once upon", rating: 5 }, done: true });
});

test("streamSSEJson: OpenAI-style deltas end-to-end", async () => {
  // Simulates content deltas that together form a JSON object.
  const deltas = ['{"answer": "', "forty", ' two"}'];
  const sse = deltas.map((d) => `data: ${JSON.stringify({ choices: [{ delta: { content: d } }] })}\n\n`).join("")
    + "data: [DONE]\n\n";
  type Out = { answer: string };
  const snaps = await collect(
    streamSSEJson<Out>(chunks(sse), (e: SSEEvent) => {
      const parsed = JSON.parse(e.data) as { choices: { delta: { content?: string } }[] };
      return parsed.choices[0]?.delta.content;
    }),
  );
  assert.deepEqual(snaps.at(-1), { value: { answer: "forty two" }, done: true });
  assert.deepEqual(snaps[0]!.value, { answer: "" });
  assert.deepEqual(snaps[1]!.value, { answer: "forty" });
});

test("works with a ReadableStream source", async () => {
  const stream = new ReadableStream<Uint8Array>({
    start(c) {
      c.enqueue(new TextEncoder().encode("data: via-stream\n\n"));
      c.close();
    },
  });
  const events = await collect(parseSSE(stream));
  assert.deepEqual(events.map((e) => e.data), ["via-stream"]);
});
