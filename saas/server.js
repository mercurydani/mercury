import express from "express";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createStore, PLANS } from "./store.js";
import { answer, extractEmail } from "./agent.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const store = createStore(process.env.MERCURY_DB || path.join(here, "data", "db.json"));
const app = express();

app.use(express.json({ limit: "2mb" }));
app.use(express.static(path.join(here, "public")));

// The widget is embedded on customers' sites, so the chat API must allow cross-origin calls.
app.use("/api/chat", (req, res, next) => {
  res.set({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  if (req.method === "OPTIONS") return res.sendStatus(204);
  next();
});

function requireOwner(req, res, next) {
  const ws = store.authorize(req.params.id, req.get("x-api-key"));
  if (!ws) return res.status(401).json({ error: "Invalid workspace or API key" });
  req.ws = ws;
  next();
}

function publicView(ws) {
  const { apiKey, conversations, ...rest } = ws;
  return {
    ...rest,
    planInfo: PLANS[ws.plan],
    usageThisMonth: store.usageThisMonth(ws),
    conversationCount: Object.keys(conversations).length,
    recentConversations: Object.entries(conversations)
      .sort(([, a], [, b]) => (b.updatedAt || "").localeCompare(a.updatedAt || ""))
      .slice(0, 20)
      .map(([sessionId, c]) => ({ sessionId, ...c })),
  };
}

app.get("/api/plans", (_req, res) => res.json(PLANS));

app.post("/api/workspaces", (req, res) => {
  const { company, email, knowledge, botName } = req.body || {};
  if (!company || !email) return res.status(400).json({ error: "company and email are required" });
  const ws = store.createWorkspace({ company, email, knowledge, botName });
  res.status(201).json({ id: ws.id, apiKey: ws.apiKey });
});

app.get("/api/workspaces/:id", requireOwner, (req, res) => res.json(publicView(req.ws)));

app.put("/api/workspaces/:id", requireOwner, (req, res) => {
  const { knowledge, botName } = req.body || {};
  const fields = {};
  if (typeof knowledge === "string") fields.knowledge = knowledge;
  if (typeof botName === "string" && botName.trim()) fields.botName = botName.trim();
  res.json(publicView(store.update(req.ws.id, fields)));
});

// Billing: point each paid plan at a Stripe Payment Link (STRIPE_LINK_STARTER, ...).
// After payment, set the plan via the admin endpoint below or a Stripe webhook.
app.post("/api/workspaces/:id/upgrade", requireOwner, (req, res) => {
  const plan = req.body?.plan;
  const link = process.env[`STRIPE_LINK_${String(plan).toUpperCase()}`];
  if (!PLANS[plan] || plan === "free") return res.status(400).json({ error: "Unknown plan" });
  if (!link) return res.json({ checkoutUrl: null, message: `Contact sales to activate ${PLANS[plan].name}.` });
  const url = new URL(link);
  url.searchParams.set("client_reference_id", req.ws.id);
  url.searchParams.set("prefilled_email", req.ws.email);
  res.json({ checkoutUrl: url.toString() });
});

app.post("/api/admin/workspaces/:id/plan", (req, res) => {
  if (!process.env.ADMIN_TOKEN || req.get("x-admin-token") !== process.env.ADMIN_TOKEN) return res.sendStatus(401);
  const ws = store.get(req.params.id);
  if (!ws || !PLANS[req.body?.plan]) return res.status(400).json({ error: "Bad workspace or plan" });
  res.json(publicView(store.update(ws.id, { plan: req.body.plan })));
});

app.post("/api/chat/:id", async (req, res) => {
  const ws = store.get(req.params.id);
  if (!ws) return res.status(404).json({ error: "Unknown workspace" });

  const message = String(req.body?.message || "").trim().slice(0, 4000);
  const sessionId = String(req.body?.sessionId || "").slice(0, 64);
  if (!message || !sessionId) return res.status(400).json({ error: "message and sessionId are required" });

  if (store.overQuota(ws)) {
    return res.json({
      reply: "Our assistant is unavailable right now. Please leave your email and we'll get back to you.",
      handoff: true,
    });
  }

  try {
    const { reply, handoff } = await answer(ws, store.history(ws, sessionId), message);
    store.recordTurn(ws, sessionId, message, reply, { handoff, lead: extractEmail(message) });
    res.json({ reply, handoff });
  } catch (err) {
    console.error("chat error:", err.status ?? "", err.message);
    res.status(502).json({ error: "The assistant is temporarily unavailable." });
  }
});

const port = Number(process.env.PORT) || 3000;
app.listen(port, () => console.log(`Mercury Support AI running on http://localhost:${port}`));
