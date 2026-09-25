// A fake Anthropic Messages API for testing ocelot's UI without real models.
//
// Every request gets a streamed reply: the first token after FIRST_MS, then the text in
// word-sized chunks every CHUNK_MS, with usage that includes cache reads, so timings and turn
// stats have realistic numbers. The newest user text scripts it:
//   "LINES n"  → a numbered list of n lines (long output, for scrolling)
//   "SHELL x"  → calls the shell tool with command x first, then answers
//   anything else → a short paragraph
import { mkdirSync, appendFileSync } from "node:fs"

const PORT = Number(process.env.FAKE_PORT ?? 4851)
const FIRST_MS = Number(process.env.FIRST_MS ?? 450)
const CHUNK_MS = Number(process.env.CHUNK_MS ?? 25)
const LOG = process.env.FAKE_LOG

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
const event = (e: any) => `event: ${e.type}\ndata: ${JSON.stringify(e)}\n\n`

function newestUserText(body: any): { text: string; afterTool: boolean } {
  for (const message of [...(body.messages ?? [])].reverse()) {
    if (message.role !== "user") continue
    const content = typeof message.content === "string" ? [{ type: "text", text: message.content }] : message.content
    const afterTool = content.some((c: any) => c.type === "tool_result")
    const text = content.filter((c: any) => c.type === "text").map((c: any) => c.text).join("\n")
    if (text || afterTool) return { text, afterTool }
  }
  return { text: "", afterTool: false }
}

function reply(text: string) {
  const lines = text.match(/LINES (\d+)/)
  if (lines) return Array.from({ length: Number(lines[1]) }, (_, i) => `${i + 1}. Line number ${i + 1} of the list.`).join("\n")
  return "This is a fake reply from the test provider. It streams a few words at a time so the UI can be checked with realistic timings, and it reports cache reads so the turn stats have something to show."
}

Bun.serve({
  port: PORT,
  hostname: "127.0.0.1",
  idleTimeout: 0,
  async fetch(req) {
    if (!new URL(req.url).pathname.endsWith("/messages")) return new Response("not found", { status: 404 })
    const body = await req.json()
    if (LOG) appendFileSync(LOG, JSON.stringify({ time: Date.now(), messages: body.messages?.length }) + "\n")
    const { text, afterTool } = newestUserText(body)
    const shell = !afterTool && text.match(/SHELL (.+)/)
    const stream = new ReadableStream({
      async start(controller) {
        const send = (e: any) => controller.enqueue(new TextEncoder().encode(event(e)))
        send({ type: "message_start", message: { id: `msg_${Date.now()}`, type: "message", role: "assistant", model: body.model, content: [], stop_reason: null, usage: { input_tokens: 40, cache_read_input_tokens: 9600, cache_creation_input_tokens: 360, output_tokens: 1 } } })
        await sleep(FIRST_MS)
        let output = 0
        if (shell) {
          send({ type: "content_block_start", index: 0, content_block: { type: "tool_use", id: `toolu_${Date.now()}`, name: "shell", input: {} } })
          send({ type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: JSON.stringify({ command: shell[1], description: "Run the test command" }) } })
          send({ type: "content_block_stop", index: 0 })
          output = 30
        } else {
          send({ type: "content_block_start", index: 0, content_block: { type: "text", text: "" } })
          for (const chunk of reply(text).match(/\S+\s*/g) ?? []) {
            send({ type: "content_block_delta", index: 0, delta: { type: "text_delta", text: chunk } })
            output += 1
            await sleep(CHUNK_MS)
          }
          send({ type: "content_block_stop", index: 0 })
        }
        send({ type: "message_delta", delta: { stop_reason: shell ? "tool_use" : "end_turn", stop_sequence: null }, usage: { output_tokens: output } })
        send({ type: "message_stop" })
        controller.close()
      },
    })
    return new Response(stream, { headers: { "content-type": "text/event-stream" } })
  },
})
console.log(`fake anthropic on http://127.0.0.1:${PORT}`)
