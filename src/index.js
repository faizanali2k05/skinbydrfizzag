/**
 * @yourname/llm-stream — streaming LLM output toolkit.
 *
 * eventsource-parser parses SSE; partial-json parses incomplete JSON. But
 * every streaming LLM app writes the glue between them by hand: read bytes →
 * split SSE events → accumulate a JSON prefix → surface typed partial object
 * snapshots. This package is that glue, self-contained. Zero dependencies.
 */
async function* iterate(source) {
    if (Symbol.asyncIterator in source) {
        yield* source;
        return;
    }
    const reader = source.getReader();
    try {
        for (;;) {
            const { done, value } = await reader.read();
            if (done)
                return;
            yield value;
        }
    }
    finally {
        reader.releaseLock();
    }
}
/**
 * Parses a byte/text stream as Server-Sent Events. Handles multi-line `data:`
 * fields, comments, CRLF, and events split across arbitrary chunk boundaries.
 */
export async function* parseSSE(source) {
    const decoder = new TextDecoder();
    let buffer = "";
    let event = "";
    let data = [];
    let id;
    function* flushLines(final = false) {
        let idx;
        while ((idx = buffer.search(/\r\n|\n|\r/)) !== -1) {
            const nl = buffer.startsWith("\r\n", idx) ? 2 : 1;
            const line = buffer.slice(0, idx);
            buffer = buffer.slice(idx + nl);
            if (line === "") {
                if (data.length > 0) {
                    yield { event: event || "message", data: data.join("\n"), id };
                }
                event = "";
                data = [];
            }
            else if (!line.startsWith(":")) {
                const colon = line.indexOf(":");
                const field = colon === -1 ? line : line.slice(0, colon);
                let value = colon === -1 ? "" : line.slice(colon + 1);
                if (value.startsWith(" "))
                    value = value.slice(1);
                if (field === "data")
                    data.push(value);
                else if (field === "event")
                    event = value;
                else if (field === "id")
                    id = value;
            }
        }
        if (final && data.length > 0) {
            yield { event: event || "message", data: data.join("\n"), id };
        }
    }
    for await (const chunkRaw of iterate(source)) {
        buffer += typeof chunkRaw === "string" ? chunkRaw : decoder.decode(chunkRaw, { stream: true });
        yield* flushLines();
    }
    buffer += decoder.decode();
    buffer += "\n"; // terminate a dangling last line
    yield* flushLines(true);
}
/**
 * Parses a (possibly incomplete) JSON prefix, returning the best-effort value.
 * Unterminated strings/arrays/objects are closed; a dangling key or partial
 * literal is dropped. Throws `SyntaxError` only on input that could never
 * become valid JSON (e.g. `{]`).
 */
export function parsePartialJSON(text) {
    const p = new PartialParser(text);
    const value = p.parseValue();
    return value === INCOMPLETE ? undefined : value;
}
const INCOMPLETE = Symbol("incomplete");
class PartialParser {
    s;
    i = 0;
    constructor(s) {
        this.s = s;
    }
    ws() {
        while (this.i < this.s.length && /\s/.test(this.s[this.i]))
            this.i++;
    }
    parseValue() {
        this.ws();
        if (this.i >= this.s.length)
            return INCOMPLETE;
        const c = this.s[this.i];
        if (c === "{")
            return this.parseObject();
        if (c === "[")
            return this.parseArray();
        if (c === '"')
            return this.parseString();
        return this.parseLiteral();
    }
    parseObject() {
        this.i++; // {
        const obj = {};
        this.ws();
        if (this.s[this.i] === "}") {
            this.i++;
            return obj;
        }
        for (;;) {
            this.ws();
            if (this.i >= this.s.length)
                return obj; // truncated: close it
            if (this.s[this.i] !== '"')
                throw new SyntaxError(`expected key at ${this.i}`);
            const keyStart = this.i;
            const key = this.parseString();
            if (typeof key !== "string" || this.i >= this.s.length) {
                // key itself truncated — drop it
                this.i = keyStart;
                return obj;
            }
            this.ws();
            if (this.i >= this.s.length)
                return obj; // truncated before ':'
            if (this.s[this.i] !== ":")
                throw new SyntaxError(`expected ':' at ${this.i}`);
            this.i++;
            const value = this.parseValue();
            if (value === INCOMPLETE)
                return obj; // value never started
            obj[key] = value;
            this.ws();
            if (this.i >= this.s.length)
                return obj;
            if (this.s[this.i] === ",") {
                this.i++;
                continue;
            }
            if (this.s[this.i] === "}") {
                this.i++;
                return obj;
            }
            throw new SyntaxError(`expected ',' or '}' at ${this.i}`);
        }
    }
    parseArray() {
        this.i++; // [
        const arr = [];
        this.ws();
        if (this.s[this.i] === "]") {
            this.i++;
            return arr;
        }
        for (;;) {
            const value = this.parseValue();
            if (value === INCOMPLETE)
                return arr;
            arr.push(value);
            this.ws();
            if (this.i >= this.s.length)
                return arr;
            if (this.s[this.i] === ",") {
                this.i++;
                this.ws();
                if (this.i >= this.s.length)
                    return arr;
                continue;
            }
            if (this.s[this.i] === "]") {
                this.i++;
                return arr;
            }
            throw new SyntaxError(`expected ',' or ']' at ${this.i}`);
        }
    }
    /** Returns the decoded string; truncated strings are closed at end-of-input. */
    parseString() {
        this.i++; // "
        let out = "";
        while (this.i < this.s.length) {
            const c = this.s[this.i];
            if (c === '"') {
                this.i++;
                return out;
            }
            if (c === "\\") {
                if (this.i + 1 >= this.s.length) {
                    this.i = this.s.length; // dangling escape: stop here
                    return out;
                }
                const e = this.s[this.i + 1];
                const simple = { '"': '"', "\\": "\\", "/": "/", b: "\b", f: "\f", n: "\n", r: "\r", t: "\t" };
                if (e in simple) {
                    out += simple[e];
                    this.i += 2;
                }
                else if (e === "u") {
                    const hex = this.s.slice(this.i + 2, this.i + 6);
                    if (hex.length < 4) {
                        this.i = this.s.length; // truncated \uXXXX
                        return out;
                    }
                    if (!/^[0-9a-fA-F]{4}$/.test(hex))
                        throw new SyntaxError(`bad \\u escape at ${this.i}`);
                    out += String.fromCharCode(parseInt(hex, 16));
                    this.i += 6;
                }
                else {
                    throw new SyntaxError(`bad escape '\\${e}' at ${this.i}`);
                }
            }
            else {
                out += c;
                this.i++;
            }
        }
        return out; // unterminated string: return what we have
    }
    parseLiteral() {
        const rest = this.s.slice(this.i);
        const m = rest.match(/^-?\d+(\.\d+)?([eE][+-]?\d+)?/);
        if (m && m[0].length > 0) {
            // A number at end-of-input may still be growing ("12" -> "123").
            if (this.i + m[0].length >= this.s.length) {
                this.i = this.s.length;
                const n = Number(m[0]);
                return Number.isFinite(n) ? n : INCOMPLETE;
            }
            this.i += m[0].length;
            return Number(m[0]);
        }
        for (const [word, value] of [["true", true], ["false", false], ["null", null]]) {
            if (rest.startsWith(word)) {
                this.i += word.length;
                return value;
            }
            if (word.startsWith(rest) && rest.length > 0) {
                this.i = this.s.length; // partial literal like "tru"
                return INCOMPLETE;
            }
        }
        throw new SyntaxError(`unexpected token at ${this.i}`);
    }
}
/**
 * Consumes a stream of JSON text fragments (e.g. LLM deltas) and yields a
 * parsed snapshot after each fragment, ending with `done: true`.
 */
export async function* streamJSON(fragments) {
    let acc = "";
    for await (const f of fragments) {
        acc += f;
        yield { value: parsePartialJSON(acc), done: false };
    }
    yield { value: JSON.parse(acc), done: true };
}
/**
 * The full pipeline for OpenAI-style streams: bytes → SSE events → the JSON
 * found at `pluck(event)` accumulated across events → object snapshots.
 * Events whose data is `[DONE]` terminate the stream.
 */
export async function* streamSSEJson(source, pluck) {
    let acc = "";
    for await (const event of parseSSE(source)) {
        if (event.data === "[DONE]")
            break;
        const piece = pluck(event);
        if (piece === undefined || piece === "")
            continue;
        acc += piece;
        yield { value: parsePartialJSON(acc), done: false };
    }
    yield { value: JSON.parse(acc), done: true };
}
