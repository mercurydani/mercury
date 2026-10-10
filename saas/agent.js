// The AI part: answers customer questions strictly from the workspace's
// knowledge base and flags conversations a human should take over.
import Anthropic from "@anthropic-ai/sdk";

const MODEL = process.env.MERCURY_MODEL || "claude-opus-5-5";
const HANDOFF_TAG = "[[HANDOFF]]";
const MAX_HISTORY_MESSAGES = 20;

let client;

function systemPrompt(ws) {
  return `You are "${ws.botName}", the customer-support assistant for ${ws.company}.

Answer the visitor's questions using only the knowledge base below. Be concise, friendly and concrete; reply in the language the visitor writes in.

If the knowledge base does not contain the answer, or the visitor asks for a human, a refund, a custom quote, or is upset, say that a teammate will follow up, ask for their email if they have not given it, and end your reply with ${HANDOFF_TAG} on its own line. Never invent prices, policies or features.

<knowledge_base>
${ws.knowledge || "(empty: tell the visitor a teammate will follow up)"}
</knowledge_base>`;
}

export function extractEmail(text) {
  return text.match(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i)?.[0]?.toLowerCase() || null;
}

export function parseReply(raw) {
  const handoff = raw.includes(HANDOFF_TAG);
  return { reply: raw.replaceAll(HANDOFF_TAG, "").trim(), handoff };
}

export async function answer(ws, history, userText) {
  const messages = [
    ...history.slice(-MAX_HISTORY_MESSAGES).map(({ role, content }) => ({ role, content })),
    { role: "user", content: userText },
  ];

  client ||= new Anthropic();
  const response = await client.beta.messages.create({
    model: MODEL,
    max_tokens: 2048,
    // Support chat is latency-sensitive and simple; low effort keeps it fast and cheap.
    output_config: { effort: "low" },
    // The knowledge base is the large, stable prefix: cache it across visitors.
    system: [{ type: "text", text: systemPrompt(ws), cache_control: { type: "ephemeral" } }],
    messages,
    // If a safety classifier declines, let the API retry on a suitable fallback model.
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
  });

  if (response.stop_reason === "refusal") {
    return { reply: "Sorry, I can't help with that here. A teammate will follow up.", handoff: true };
  }

  const text = response.content
    .filter((b) => b.type === "text")
    .map((b) => b.text)
    .join("\n");
  return parseReply(text || HANDOFF_TAG);
}
