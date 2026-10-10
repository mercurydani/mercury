# Mercury Support AI

B2B SaaS: an AI customer-support agent for small and mid-sized companies.
A company pastes its FAQ, docs and price list, gets one `<script>` tag for its website, and the agent:

- answers visitors **only from the knowledge base** (no invented prices or policies);
- hands hard cases (refunds, complaints, custom quotes, unknown questions) to a human;
- captures visitor emails as leads;
- shows everything in a dashboard: usage, conversations, leads, handoffs.

Plans: Free (100 replies/mo), Starter $99, Growth $499, Enterprise $2,500.

Business plan (in Russian): [BUSINESS_PLAN.md](BUSINESS_PLAN.md).

## Run locally

```bash
cd saas
npm install
export ANTHROPIC_API_KEY=sk-ant-...   # https://console.anthropic.com
npm start                            # http://localhost:3000
```

Open http://localhost:3000, create an agent, and the chat widget appears in the corner of the page.

## Configuration

| Variable | Purpose |
|---|---|
| `ANTHROPIC_API_KEY` | Claude API key (required for chat) |
| `PORT` | HTTP port, default `3000` |
| `MERCURY_DB` | Path to the JSON database, default `saas/data/db.json` |
| `MERCURY_MODEL` | Claude model, default `claude-opus-5-5` |
| `STRIPE_LINK_STARTER`, `STRIPE_LINK_GROWTH`, `STRIPE_LINK_ENTERPRISE` | Stripe Payment Links for the Upgrade button |
| `ADMIN_TOKEN` | Enables `POST /api/admin/workspaces/:id/plan` to activate a paid plan after payment |

## API

| Method | Path | Auth | |
|---|---|---|---|
| `POST` | `/api/workspaces` | none | Sign up: `{company, email, knowledge}` → `{id, apiKey}` |
| `GET` | `/api/workspaces/:id` | `x-api-key` | Dashboard data |
| `PUT` | `/api/workspaces/:id` | `x-api-key` | Update `{knowledge, botName}` |
| `POST` | `/api/workspaces/:id/upgrade` | `x-api-key` | `{plan}` → Stripe checkout URL |
| `POST` | `/api/chat/:id` | public (CORS) | `{message, sessionId}` → `{reply, handoff}` |

## Embed

```html
<script src="https://YOUR_HOST/widget.js" data-workspace="WORKSPACE_ID" data-title="Acme Support"></script>
```

## Tests

```bash
npm test
```

## Before real customers

This is an MVP. Before charging money: move from the JSON file to Postgres, add a Stripe webhook to switch plans automatically, email notifications for handoffs, rate limiting on `/api/chat`, and HTTPS hosting (Render, Fly.io, Railway).
