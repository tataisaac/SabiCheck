# SabiCheck API (backend proxy)

Thin server between the SabiCheck apps and Gemini. It exists so the **Gemini API key
never ships inside a mobile binary** (SABICHECK_SPEC.md §4.1) and so we get rate
limiting, input validation, caching and a stable contract in one place.

- **Stack:** Node 20+ · TypeScript · Express 5 · `@google/genai` · Zod · Vitest
- **Endpoints:** `GET /healthz`, `POST /v1/analyze`, `POST /v1/translate`
- **Modes:** `gemini` (real AI) or `mock` (deterministic keyword heuristic, no key
  needed — for local app development and tests)

## Run locally

```bash
cd backend
npm install
cp .env.example .env          # defaults to SABICHECK_MODE=mock
npm run dev                   # http://localhost:8080
```

To use real AI, put your key in `.env` (`GEMINI_API_KEY=...`) and set
`SABICHECK_MODE=gemini` (or just remove the `SABICHECK_MODE` line).

```bash
npm test          # 50 unit + HTTP tests, no network required
npm run typecheck
npm run build && npm start
```

## API

### `POST /v1/analyze`

```jsonc
// request
{
  "message": "Congratulations! You won 500,000 FCFA. Send your PIN…",   // optional if image present
  "language": "en",                                                      // "en" | "fr" (default "en")
  "image": { "mimeType": "image/jpeg", "data": "<base64, no data: prefix>" }  // optional
}

// response 200
{
  "riskLevel": "High",                 // "Low" | "Medium" | "High"
  "confidenceScore": 93,               // 0–100
  "category": "Mobile Money Scam",
  "summary": "…",
  "explanation": "…",
  "recommendedActions": ["…", "…"],    // 1–4 items
  "language": "en",
  "source": "gemini",                  // "gemini" | "mock" | "cache"
  "analysisId": "uuid"
}
```

### `POST /v1/translate`

```jsonc
{ "language": "fr", "analysis": { /* a ScamAnalysis as returned above */ } }
```

Returns the same shape with `category / summary / explanation / recommendedActions`
translated. `riskLevel` and `confidenceScore` are **guaranteed unchanged** server-side.

### Errors

Every error is `{"error": {"code": "...", "message": "...", "details"?: …}}` with a
stable `code`: `bad_request` (400) · `unauthorized` (401) · `payload_too_large` (413) ·
`rate_limited` (429) · `upstream_error` / `invalid_model_output` (502) ·
`upstream_timeout` (504) · `not_found` (404) · `internal` (500).

### Optional app token

Set `SABICHECK_APP_TOKEN` and clients must send `Authorization: Bearer <token>`.
This only deters casual abuse — anything inside an app binary can be extracted.
Real cost control = rate limit + quota caps on the Gemini key.

## Deploy (Cloud Run example)

```bash
gcloud run deploy sabicheck-api --source backend \
  --region europe-west1 --allow-unauthenticated \
  --set-env-vars GEMINI_MODEL=gemini-2.5-flash,GEMINI_THINKING_BUDGET=0,ALLOWED_ORIGINS=https://your-web-domain \
  --set-secrets GEMINI_API_KEY=gemini-api-key:latest
```

Any Node host works (Render, Railway, Fly.io, a VPS with pm2). The server reads `PORT`.

## Layout

```
src/
  server.ts          entrypoint (env → config → listen, graceful shutdown)
  app.ts             Express app: CORS, JSON limits, rate limit, token, routes, error mapping
  config.ts          validated env config (fails fast if key missing in gemini mode)
  schema.ts          Zod contracts: ScamAnalysis, requests, responses, error body
  service.ts         validation/coercion of model output + caching
  prompts.ts         analysis + translation prompts (spec §5.2 / §5.3, "SabiCheck" branding)
  cache.ts           in-memory TTL/LRU cache (swap for Redis behind the same interface)
  providers/
    gemini.ts        real provider (structured JSON output, thinking budget, error mapping)
    mock.ts          offline heuristic provider (dev/tests)
test/                vitest suites (config, cache, providers, service, HTTP)
```
