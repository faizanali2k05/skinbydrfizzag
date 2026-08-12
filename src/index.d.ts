/**
 * @yourname/llm-stream — streaming LLM output toolkit.
 *
 * eventsource-parser parses SSE; partial-json parses incomplete JSON. But
 * every streaming LLM app writes the glue between them by hand: read bytes →
 * split SSE events → accumulate a JSON prefix → surface typed partial object
 * snapshots. This package is that glue, self-contained. Zero dependencies.
 */
/** One Server-Sent Event. */
export interface SSEEvent {
    event: string;
    data: string;
    id?: string;
}
type ByteSource = AsyncIterable<Uint8Array | string> | ReadableStream<Uint8Array>;
/**
 * Parses a byte/text stream as Server-Sent Events. Handles multi-line `data:`
 * fields, comments, CRLF, and events split across arbitrary chunk boundaries.
 */
export declare function parseSSE(source: ByteSource): AsyncGenerator<SSEEvent>;
/**
 * Parses a (possibly incomplete) JSON prefix, returning the best-effort value.
 * Unterminated strings/arrays/objects are closed; a dangling key or partial
 * literal is dropped. Throws `SyntaxError` only on input that could never
 * become valid JSON (e.g. `{]`).
 */
export declare function parsePartialJSON(text: string): unknown;
/** A progressive view of a streamed JSON document. */
export interface Snapshot<T> {
    /** Best-effort parse of everything received so far. */
    value: Partial<T>;
    /** True on the final snapshot, when the document parsed completely. */
    done: boolean;
}
/**
 * Consumes a stream of JSON text fragments (e.g. LLM deltas) and yields a
 * parsed snapshot after each fragment, ending with `done: true`.
 */
export declare function streamJSON<T = unknown>(fragments: AsyncIterable<string>): AsyncGenerator<Snapshot<T>>;
/**
 * The full pipeline for OpenAI-style streams: bytes → SSE events → the JSON
 * found at `pluck(event)` accumulated across events → object snapshots.
 * Events whose data is `[DONE]` terminate the stream.
 */
export declare function streamSSEJson<T = unknown>(source: ByteSource, pluck: (event: SSEEvent) => string | undefined): AsyncGenerator<Snapshot<T>>;
export {};
