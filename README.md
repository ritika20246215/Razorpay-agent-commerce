# Agent Commerce Layer

A bounded **upsell agent** + an **agent-readable catalog**, built on Razorpay
test-mode APIs. Grows a merchant's sales *and* makes the store readable and
transactable for autonomous AI buyers — with every financial action bounded,
human-gated when needed, and fully audited.

> Built for the Razorpay AI Buildathon, Track 01.

## Quick start

```bash
python -m venv venv && source venv/bin/activate     # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                 # optional: add Razorpay TEST keys
uvicorn app.main:app --reload
```
Then open:
- **`/dashboard`** — the control room: live budget gauge, storefront, approval
  queue, scenario runner, and the full activity ledger
- **`/docs`** — interactive API (the agent-readable catalog lives here)
- **`/catalog/agent-feed`** — schema.org JSON-LD feed for autonomous buyers

### Connecting real Razorpay test keys
Put your test credentials in `.env` (never in code — `.env` is gitignored):
```
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your_test_secret
```
Restart the server. The dashboard header switches from “mock orders” to a green
“Razorpay test mode” indicator showing the active key id, so a demo can never
misrepresent what it's connected to.

Runs with **zero setup**: with no Razorpay keys it creates clearly-labelled
*mock* orders. Add your test keys to `.env` and it hits real Razorpay (do this
for the actual submission). Without an Anthropic key the agent uses its
deterministic brain automatically.

See a purchase happen with no human in the loop:
```bash
python -m demo.buyer_agent
```

## How it maps to the judging bar

| Criterion | Where it lives |
|-----------|----------------|
| **Problem taste** | Real upsell + AI-to-AI discoverability — see `SPEC.md` |
| **Build quality** | Layered modules, one source of truth, tests in `tests/` |
| **AI judgment** | LLM only *proposes*; deterministic code decides — `guardrails/` vs `agent/` |
| **Failure recovery** | Retry/backoff, fail-to-human, idempotency — `orchestrator/checkout.py` |
| **Safety & control** | Caps + human gate + validated LLM output |
| **Audit trail** | Append-only log — `audit/logger.py`, viewed on `/dashboard` |

## Architecture

```
Buyer (REST or MCP)
      │
      ▼
orchestrator/checkout.py ── the spine, enforces idempotency + fail-to-human
      │
      ├─ catalog/      agent-readable products (JSON-LD) + availability
      ├─ agent/        proposes upsell (Claude, or deterministic fallback)  ← ONLY place an LLM runs
      ├─ guardrails/   caps, validation, execute/deny  ← NO LLM, ever
      ├─ razorpay_client/  isolated Razorpay wrapper + retry/backoff + failure sim
      ├─ approvals/    human-in-the-loop queue
      └─ audit/        append-only trail
mcp_server/           the same catalog + checkout as MCP tools (AI-to-AI surface)
demo/buyer_agent.py   an autonomous buyer that reads the feed and purchases
```

**The one idea to take away:** the model handles *judgment* (which upsell, how
confident); plain, testable code handles *money and permission*. The model's
output is validated before it can touch a transaction — an unknown product id
or an over-limit discount never reaches Razorpay.

## Two agent-readable surfaces
- **REST + JSON-LD** (`/catalog/agent-feed`) — the reliable spine; any agent
  that understands schema.org can consume it.
- **MCP server** (`mcp_server/server.py`) — the headline: the same catalog and
  the same bounded checkout exposed as Model Context Protocol tools, so an
  MCP-speaking agent can transact natively. Same orchestrator underneath, so
  the guardrails and audit trail still apply.

```bash
pip install mcp
python -m mcp_server.server      # then register it in your MCP client
```

## Safety model
- **Caps** (in `guardrails/checks.py`): discount ≤ 15%, per-transaction ≤ ₹5,000,
  daily ≤ ₹20,000, confidence ≥ 0.75. Any breach → human approval queue.
- **Human gate**: over-cap or low-confidence actions execute *only* after a
  human approves on the dashboard. Nothing is charged before that.
- **Idempotency**: repeated idempotency key → original result, never a second
  order.
- **Fail-to-human**: if Razorpay is exhausted after retries, no order is created
  (no double charge) and the purchase is routed to review.

## Failure modes demonstrated
Invalid payload · budget/cap hit · payment API drop (transient → recovers;
persistent → human, no charge) · LLM unavailable → deterministic fallback.
Trigger the payment drop live from the dashboard, or via `POST /demo/arm-failure`.

## API surface

| Endpoint | What it's for |
|----------|---------------|
| `GET /catalog/products`, `/products/{id}`, `/{id}/availability` | agent-readable catalog |
| `GET /catalog/agent-feed` | schema.org JSON-LD feed for autonomous buyers |
| `POST /checkout` | the bounded purchase pipeline |
| `GET /approvals/`, `POST /approvals/{id}/approve\|reject` | human-in-the-loop queue |
| `GET /audit/logs` | append-only audit trail |
| `GET /stats`, `/guardrails/config`, `/mode` | live telemetry, caps in force, what it's wired to |
| `POST /demo/arm-failure`, `/demo/reset` | demo controls (would not ship in production) |

## Tests
```bash
pytest -q
```
Covers guardrail limits and every orchestrator outcome, including
"persistent failure creates no charge" and "replay does not double-charge".

## Honest limitations (what I'd add for production)
Single node, file-based storage, one merchant, no auth on the endpoints, and
Razorpay webhook signatures aren't verified here. Next steps: a real database,
endpoint auth, webhook verification, and per-merchant configurable caps.

## Repo guide
`SPEC.md` — one-page design · `DEMO_RUNBOOK.md` — the panel walkthrough ·
`app/` — the service · `mcp_server/` — MCP surface · `demo/` — buyer agent ·
`tests/` — the suite.
