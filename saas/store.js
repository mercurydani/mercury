// Minimal JSON-file persistence. Good enough for the first ~100 customers;
// swap for Postgres once you have paying users.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

export const PLANS = {
  free: { name: "Free", priceUsd: 0, messagesPerMonth: 100 },
  starter: { name: "Starter", priceUsd: 99, messagesPerMonth: 2000 },
  growth: { name: "Growth", priceUsd: 499, messagesPerMonth: 15000 },
  enterprise: { name: "Enterprise", priceUsd: 2500, messagesPerMonth: 200000 },
};

const EMPTY = { workspaces: {} };

export function createStore(file) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  let db = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : structuredClone(EMPTY);

  const save = () => {
    const tmp = file + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(db, null, 2));
    fs.renameSync(tmp, file);
  };

  const monthKey = () => new Date().toISOString().slice(0, 7);

  return {
    createWorkspace({ company, email, knowledge, botName }) {
      const id = crypto.randomBytes(8).toString("hex");
      const apiKey = "msk_" + crypto.randomBytes(24).toString("hex");
      db.workspaces[id] = {
        id,
        apiKey,
        company,
        email,
        botName: botName || `${company} Assistant`,
        knowledge: knowledge || "",
        plan: "free",
        createdAt: new Date().toISOString(),
        usage: {},
        conversations: {},
        leads: [],
        handoffs: [],
      };
      save();
      return db.workspaces[id];
    },

    get(id) {
      return db.workspaces[id] || null;
    },

    authorize(id, apiKey) {
      const ws = db.workspaces[id];
      if (!ws || !apiKey) return null;
      const a = Buffer.from(ws.apiKey);
      const b = Buffer.from(String(apiKey));
      return a.length === b.length && crypto.timingSafeEqual(a, b) ? ws : null;
    },

    update(id, fields) {
      Object.assign(db.workspaces[id], fields);
      save();
      return db.workspaces[id];
    },

    usageThisMonth(ws) {
      return ws.usage[monthKey()] || 0;
    },

    overQuota(ws) {
      return this.usageThisMonth(ws) >= PLANS[ws.plan].messagesPerMonth;
    },

    history(ws, sessionId) {
      return ws.conversations[sessionId]?.messages || [];
    },

    recordTurn(ws, sessionId, userText, assistantText, { handoff, lead }) {
      const now = new Date().toISOString();
      const convo = (ws.conversations[sessionId] ||= { startedAt: now, messages: [] });
      convo.messages.push(
        { role: "user", content: userText, at: now },
        { role: "assistant", content: assistantText, at: now },
      );
      convo.updatedAt = now;
      ws.usage[monthKey()] = (ws.usage[monthKey()] || 0) + 1;
      if (handoff) ws.handoffs.push({ sessionId, question: userText, at: now });
      if (lead && !ws.leads.some((l) => l.email === lead)) ws.leads.push({ email: lead, sessionId, at: now });
      save();
    },
  };
}
