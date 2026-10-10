import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { extractEmail, parseReply } from "../agent.js";
import { createStore } from "../store.js";

test("parseReply strips the handoff tag and flags it", () => {
  assert.deepEqual(parseReply("A teammate will follow up.\n[[HANDOFF]]"), { reply: "A teammate will follow up.", handoff: true });
  assert.deepEqual(parseReply("We open at 9."), { reply: "We open at 9.", handoff: false });
});

test("extractEmail finds an address in free text", () => {
  assert.equal(extractEmail("reach me at Ivan.P@Example.com please"), "ivan.p@example.com");
  assert.equal(extractEmail("no email here"), null);
});

test("store tracks usage, leads, handoffs and quota", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mercury-"));
  const store = createStore(path.join(dir, "db.json"));
  const ws = store.createWorkspace({ company: "Acme", email: "a@acme.io" });

  assert.equal(store.authorize(ws.id, ws.apiKey), ws);
  assert.equal(store.authorize(ws.id, "wrong"), null);

  store.recordTurn(ws, "s1", "hi, I'm bob@x.io", "hello", { handoff: true, lead: "bob@x.io" });
  assert.equal(store.usageThisMonth(ws), 1);
  assert.equal(ws.leads.length, 1);
  assert.equal(ws.handoffs.length, 1);
  assert.equal(store.history(ws, "s1").length, 2);

  ws.usage[new Date().toISOString().slice(0, 7)] = 100;
  assert.equal(store.overQuota(ws), true);

  // Persists across reloads.
  const reloaded = createStore(path.join(dir, "db.json"));
  assert.equal(reloaded.get(ws.id).leads[0].email, "bob@x.io");
});
