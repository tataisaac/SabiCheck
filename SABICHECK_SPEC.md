# SabiCheck — Product Specification & Handoff Document

> **Purpose:** This document is the single source of truth for the **SabiCheck** mobile app
> (Flutter). It captures everything agreed in the ScamShield → SabiCheck conversation so the
> plan survives a repo switch and is not reliant on chat memory.
>
> **Status:** Living spec. Update it as decisions change.
>
> **New repo:** This document should be copied into the new Flutter repo when it is created.

---

## 1. Identity & Brand

- **Product name:** **SabiCheck**
- **Master brand:** **Sabi** (a family of products)
- **Brand meaning in Pidgin:** "Sabi" = **to know / to understand / to be street-smart**
  (from Portuguese _saber_). The brand thesis across all Sabi products is **"knowing more."**
- **Existing / sibling products:**
  - **SabiHub** — event / data analytics ("know your data")
  - **SabiCheck** — scam & fraud verifier ("know what's real")
  - _(future)_ SabiLearn, SabiShop, SabiPay, SabiFund, SabiAm, SabiEye, SabiSef
- **Old name being replaced:** The current web app is named **"ScamShield AI"** and is being
  renamed/kept as the web reference. The mobile app is **SabiCheck**.

### Why "Check" not "Shield"?

The current app **verifies** (assesses whether a message is real/fake). It does **not yet**
actively shield/block/intercept. **SabiCheck** accurately describes what the product does.
"Shield" is reserved for a _future_ tier of features (see §7) — if those are ever built, the
brand may evolve or tier.

---

## 2. Product Summary

An AI-powered **scam & fraud verifier** for African digital users (with a focus on Cameroon /
West Africa). User pastes a suspicious message (WhatsApp / SMS / email) or uploads a
screenshot. The app returns a structured risk assessment: risk level, confidence, category,
summary, explanation, and recommended actions. It is **bilingual (English / French)**.

**Target scams:** Mobile-money scams (MTN MoMo / Orange Money), WhatsApp impersonation,
fake job offers, emergency-money scams, phishing, advance-fee ("419"/feyman) scams.

---

## 3. The "Killer Feature" — Share-Sheet Integration

The single most valuable differentiator: let users push a suspicious message/screenshot into
the app **without copy-paste**.

- **What the user does:** In WhatsApp (or any app), long-press a message → **Share** → pick
  **SabiCheck** from the share sheet.
- **What the app does:** Opens with that message/image **already populated** → user taps
  **Analyze** → get the verdict. Two taps, right from where the scam reached them.
- **Why it matters:** The biggest friction in a scam-detector is _getting the content in_.
  The share sheet collapses it to "share → tap SabiCheck → analyze."
- **Where it works:**
  - **Android:** Share **intent filter** (`ACTION_SEND`), receives text + images.
  - **iOS:** **Share Extension** (`NSExtension`), receives text + images.
  - **NOT on web / PWA:** browsers block third-party apps from the share sheet. This is the
    strongest argument for a **native** build over a PWA.

---

## 4. Architecture Rules (non-negotiable)

### 4.1 API key must NOT ship in the app binary

The current web app injects `process.env.GEMINI_API_KEY` into the client bundle
(`vite.config.ts`). This is fine for a demo but is **extractable and insecure** for a
distributed app.

**Rule:** All Gemini calls go through a **thin backend proxy** (Cloud Run, Firebase
Functions, or any small API). The backend:

- holds the Gemini API key,
- adds rate limiting / usage / cost control,
- optionally logs usage and caches results for similar messages,
- exposes clean endpoints for analysis, translation, and (later) reputation & reports.

The mobile app calls the **proxy**, never Gemini directly.

### 4.2 Shared logic

- The core Gemini prompt + `ScamAnalysis` schema live in the **backend proxy**.
- The mobile app is a **thin client**: send text/image to the proxy → render the structured
  `ScamAnalysis` response.

---

## 5. The Core Model & Prompt (verbatim reference)

> Copy the following into the backend proxy. This is the exact logic from the current web
> `src/services/geminiService.ts`.

### 5.1 Response schema

```json
{
  "riskLevel": "Low | Medium | High",
  "confidenceScore": 0-100 (int),
  "category": "e.g. Mobile Money Scam, WhatsApp Impersonation, Phishing, Safe",
  "summary": "1-2 sentence summary",
  "explanation": "detailed explanation of suspicious indicators",
  "recommendedActions": ["1-4 actionable steps"]
}
```

TypeScript interface (reference):

```ts
export interface ScamAnalysis {
  riskLevel: "Low" | "Medium" | "High";
  confidenceScore: number;
  category: string;
  summary: string;
  explanation: string;
  recommendedActions: string[];
}
```

### 5.2 Analysis prompt (base — adapt "ScamShield" → "SabiCheck" in new app)

```
You are ScamShield AI, an expert cybersecurity assistant specializing in detecting digital
fraud, particularly scams targeting African digital users (e.g., Mobile money scams,
WhatsApp impersonation, fake job offers, emergency money scams, phishing).

Your task is to dynamically analyze the provided message (and/or image) and generate a
tailored threat assessment. Do not use generic responses. Base your risk classification,
confidence score, category, suspicious indicators, and recommendations strictly on the
specific contents and nuances of the user's input.

If an image is provided, extract and analyze the text visible in the image.

IMPORTANT: You MUST respond entirely in {language} ({en = English | fr = French}).
```

- Then append `Message to analyze: "<message>"` if text present.
- If an image is present, send it as a multimodal content part (base64 + mime type).
- Use `responseMimeType: application/json` and the `responseSchema` above to force
  structured output.

### 5.3 Translation (also done via proxy)

- `translateContent(text, lang)` — plain translate of the input text.
- `translateAnalysis(analysis, lang)` — translate only `category`, `summary`, `explanation`,
  `recommendedActions`; **never** translate `riskLevel`; never change `confidenceScore`.
- Note: Each language switch today triggers 2 full Gemini calls — consider caching later.

---

## 6. Platform Feasibility (what is actually possible)

| Feature                                   | Android                                                                                        | iOS                                                 | Notes                            |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------- | -------------------------------- |
| Paste / screenshot analysis               | ✅ Easy                                                                                        | ✅ Easy                                             | No special permissions           |
| **Share-sheet / WhatsApp share-in**       | ✅ Doable (intent)                                                                             | ✅ Doable (extension)                               | **Killer feature**               |
| Scam number / link reputation lookup      | ✅ Easy (backend API)                                                                          | ✅ Easy                                             | No device permissions            |
| Detect risky patterns (OTP, "send money") | ✅ Easy                                                                                        | ✅ Easy                                             | Prompt/schema logic              |
| Offline rule-based fallback               | ✅ Easy                                                                                        | ✅ Easy                                             | Static rules                     |
| History / saved reports                   | ✅ Easy                                                                                        | ✅ Easy                                             | Local storage / backend          |
| **Auto-scan incoming SMS inbox + warn**   | ⚠️ Hard — must be **default SMS handler** to get `READ_SMS`/`RECEIVE_SMS` (Google Play policy) | ❌ **Impossible** — no public API reads SMS content | Flagship "shield" is constrained |
| **Block / intercept calls or texts**      | ⚠️ Hard — default phone/SMS handler + big permissions                                          | ⚠️ Partial — CallKit VoIP-style; can't read SMS     | Limited on iOS                   |
| SIM-swap / account-lock alerts            | ⚠️ Partial — detect? no; educate + escalate                                                    | ⚠️ Partial — same                                   | Education/reporting, not passive |
| **Community reports + shared blacklist**  | ✅ Easy (backend)                                                                              | ✅ Easy (backend)                                   | Strong feature; no permissions   |
| Auto-warn on scam link before clicking    | ⚠️ Medium — limited deep-link/accessibility                                                    | ⚠️ Difficult                                        | Depends on intercept             |

**Key constraint:** iOS does **not** allow third-party apps to read the SMS/call inbox. Any
"read your texts and warn you" feature is **Android-only** and gated behind **default-SMS-handler**
status + Google Play permission review.

---

## 7. Feature Roadmap (build order)

### Tier 1 — Smarter "Check" (verification, natural next step)

- Link & number reputation lookup (blacklist database)
- Structured detection of risky behaviors: PIN/OTP requests, "send money to X," urgency/
  emotional pressure, too-good-to-be-true offers
- Pattern / fingerprint matching against known scam templates (cheap, no AI call)
- Graceful confidence handling ("inconclusive — here's what to check")
- History + saved reports + "report a scam" (grows the database)

### Tier 2 — Proactive Warning (starts feeling like a "Shield")

- **Real-time SMS / notification scanning (Android)** — flag MTN MoMo / Orange Money phishing
  (fake prize, "account locked," OTP request, SIM-swap warning) before the user acts
- **Share-sheet auto-feed** (the killer feature, upgraded)
- Quick-paste homescreen widget / quick action
- **Lightweight offline rule engine** (keywords, number prefixes, URL patterns) — catches
  obvious scams with zero network

### Tier 3 — Protection / "Guard"

- Soft-blocking "unsafe" gate before sending money to a flagged number / clicking a flagged link
- SIM-swap & account-lock education + in-app escalation to MTN / Orange
- **Community reputation network** — aggregate user reports into a public blacklist
- "Protect a family member" mode (alert a relative if a loved one gets a flagged message)
- Fraud-report & recovery guide (report to provider / police / regulator)

### Tier 4 — Native Integrations (ceiling of "mobile Shield")

- Android SMS / Caller-ID integration (screen SMS + flag scam calls, like lightweight Truecaller)
- Deep WhatsApp/Telegram integration (**hard:** WhatsApp limits third-party access)
- Blocklist-based call/text blocking (Android only)

---

## 8. Repo Structure & Split Decision

**Decision from conversation:** The web and mobile apps are **separate by design**. The web
app runs independently of the mobile app.

### The split

- **Web app (existing React/Vite):** stays in the current repo
  (`tataisaac/scamshield-cyber-ai`). This is the **reference implementation** containing the
  Gemini logic in `src/services/geminiService.ts`.
- **Mobile app (new Flutter app):** goes in a **new, separate repo** (e.g. `SabiCheck`).
  Flutter produces its own web build too, so co-hosting with React is unnecessary.
- **Backend proxy:** shared by both. Either its own repo or a folder in the Flutter repo (or
  web repo). Recommended: separate small backend service.

### Why separate repos (not a branch / not a monorepo)

- Different stack (React/JS vs Dart/Flutter), different toolchains, different lifecycles.
- They don't meaningfully share code (only the prompt text + backend API).
- Flutter already builds for mobile **and** web, so cross-platform is handled without co-hosting.
- Separate repos let each deploy/release independently.
- A branch would create a permanent fork with merge drift; a monorepo adds tooling overhead
  for no shared-code benefit here.

### The only shared things

- **Brand naming** ("Sabi" / "SabiCheck") — done across repos by convention.
- **A small backend API** (Gemini proxy + reputation/report endpoints) — a real shared
  component, best kept in its own service.

---

## 9. Development Environment Constraints (for future sessions)

**Session binding:** This Arena session is pinned to branch
`arena/01a06056-scamshield-cyber-ai` in this repo and cannot switch to a different repository.
Any new repo must be created by the user; the build happens there.

**Scaffold recommendation:** When creating the new Flutter repo from scratch, target
**Android + iOS + web** from one Flutter codebase. Use `flutter create` (e.g. Project name
`sabicheck`).

---

## 10. Naming & Config to Apply in the New Repo

When scaffolding, set:

- **Project / package name:** `sabicheck` (Dart package + Android applicationId)
- **Android package ID:** `com.<org>.sabicheck`
- **iOS bundle ID:** `com.<org>.sabicheck`
- **App display name:** `SabiCheck` (or `SabiCheck — Scam & Fraud Detector` for stores)
- **Brand color:** emerald/teal green (matches existing ScamShield UI theme) — decision pending.

---

## 11. Open Decisions / TODO

- [ ] Confirm final app display name (short `SabiCheck` vs descriptive).
- [ ] Confirm Android applicationId and iOS bundle ID (`com.<org>.sabicheck`).
- [ ] Decide where the **backend proxy** lives (own repo vs inside Flutter repo).
- [ ] Confirm Flutter vs React Native final choice (currently: **Flutter** for a beginner with
      lowest learning curve; RN only if the user wants to stay in the JS/React world).
- [ ] Set up the Gemini proxy before any API key is placed in the mobile app.
- [ ] Implement the **share-sheet** integration first (Android intent + iOS extension) — it is
      the killer feature and works on both platforms.
- [ ] Verify brand/trademark availability for "Sabi" and "SabiCheck" before store submission.

---

_End of spec._
