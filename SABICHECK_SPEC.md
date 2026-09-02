# SabiCheck — Product Specification & Handoff Document

> **Purpose:** This document is the single source of truth for the **SabiCheck** mobile app
> (Flutter). It captures everything agreed in the ScamShield → SabiCheck conversation so the
> plan survives a repo switch and is not reliant on chat memory.
>
> **Status:** Living spec. Update it as decisions change. Last updated **2026-09-02** (see §12).
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
- Note: the web app translates **both** the analysis *and the user's pasted message* on every
  language switch (2 Gemini calls, and it rewrites the evidence). **Mobile decision:** only the
  verdict is translated; the user's input is never altered. Translations are cached per
  (verdict, language) in the app and per (input hash, language) in the backend, so switching
  back and forth is free after the first call.

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
| **Auto-scan incoming SMS inbox + warn**   | ⚠️ Hard — `READ_SMS`/`RECEIVE_SMS` need **default SMS handler** status, or the Play "anti-smishing" exception (requires a proven protection track record). Realistic alternative: **Notification Listener** (reads notification text incl. WhatsApp/MoMo; user-granted special access, still Play-reviewed) | ⚠️ **Partial** — inbox is unreadable, but Apple's **Message Filter Extension** (`ILMessageFilterExtension`) can classify SMS from *unknown senders* as junk (offline rules or fixed backend URL) | Flagship "shield" is constrained but not dead |
| **Block / intercept calls or texts**      | ⚠️ Hard — default phone/SMS handler + big permissions                                          | ⚠️ Partial — CallKit VoIP-style; can't read SMS     | Limited on iOS                   |
| SIM-swap / account-lock alerts            | ⚠️ Partial — detect? no; educate + escalate                                                    | ⚠️ Partial — same                                   | Education/reporting, not passive |
| **Community reports + shared blacklist**  | ✅ Easy (backend)                                                                              | ✅ Easy (backend)                                   | Strong feature; no permissions   |
| Auto-warn on scam link before clicking    | ⚠️ Medium — limited deep-link/accessibility                                                    | ⚠️ Difficult                                        | Depends on intercept             |

**Key constraint:** iOS does **not** allow third-party apps to read the SMS/call inbox. A
"read your texts and warn you" feature is therefore **Android-first**:

- **Android (SMS permissions):** Google Play only grants the SMS permission group to the
  **default SMS/Phone/Assistant handler** or to listed exceptions. "Anti-SMS phishing /
  spam detection" *is* a listed exception, but only for apps with a documented protection
  track record (analyst reports, benchmarks) — a new app will not qualify. Becoming the
  default SMS handler means SabiCheck must be a full SMS app (send/receive) — out of scope.
- **Android (realistic path):** a **Notification Listener Service** reads the text of
  incoming notifications (SMS, WhatsApp, MoMo/OM apps) without SMS permissions. It is a
  user-granted special access and Play scrutinises it (must be core functionality, prominently
  disclosed) but it is achievable. This is the Tier-2 "real-time warning" plan.
- **iOS (realistic path):** a **Message Filter Extension** receives sender + body for SMS
  from **unknown senders** and returns junk / promotion / transaction; iOS suppresses the
  notification and moves the thread to Junk. No custom alerts, no WhatsApp — but it is an
  official, App-Store-legal "SabiCheck silently filters MoMo smishing" feature.

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
- **Backend proxy:** shared by both. **Decision (2026-09-02):** lives in this repo under
  `backend/` (Node 20 · TypeScript · Express 5 · `@google/genai`). It is self-contained and can
  be moved to its own repo later without changes. See `backend/README.md`.

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

**This repo (`tataisaac/SabiCheck`) is the Flutter app.** Scaffolded with Flutter 3.47 /
Dart 3.13 for **Android + iOS + web** from one codebase (project name `sabicheck`).

**Agent sandbox limits (for future Arena sessions):** the sandbox has Node but **no Flutter/Dart
SDK and no route to `storage.googleapis.com` / `pub.dev` downloads**, so Dart cannot be compiled
or tested there. Compensations in place:

- `.github/workflows/ci.yml` runs `flutter analyze --fatal-infos`, `flutter test`, a debug APK
  build and a web build on every push (plus backend tests). **Treat CI as the Dart compiler.**
- The backend is fully buildable/testable in the sandbox (`npm test`, 50 tests, no network).
- Anything needing a device/emulator, Xcode or store consoles happens on the user's machine.

**Verification loop for Flutter changes:** push → check Actions → fix → repeat; then
`flutter run` locally against `backend/` in mock mode.

---

## 10. Naming & Config to Apply in the New Repo

When scaffolding, set:

- **Project / package name:** `sabicheck` ✅
- **Android applicationId / namespace:** `com.incredible.sabicheck` ✅
- **iOS bundle ID:** `com.incredible.sabicheck` ✅ (Share Extension: `com.incredible.sabicheck.ShareExtension`,
  App Group: `group.com.incredible.sabicheck`)
- **App display name:** `SabiCheck` ✅ (store listing title can be
  `SabiCheck — Scam & Fraud Verifier`)
- **Brand color:** emerald `#10B981` on slate neutrals (light `#F8FAFC`, dark `#020617`) ✅ —
  carried over from the ScamShield UI; implemented in `lib/theme/app_theme.dart`.
- **Backend URL:** `--dart-define=SABICHECK_API_URL=…` (default `http://10.0.2.2:8080` in debug);
  also editable at runtime in *Settings → Developer*.

---

## 11. Open Decisions / TODO

- [x] Confirm final app display name → `SabiCheck`.
- [x] Confirm Android applicationId and iOS bundle ID → `com.incredible.sabicheck`.
- [x] Decide where the **backend proxy** lives → `backend/` in this repo.
- [x] Confirm Flutter vs React Native → **Flutter** (scaffolded, code written).
- [x] Set up the Gemini proxy before any API key is placed in the mobile app → done; the app has
      no key at all.
- [x] Implement the **share-sheet** integration (Android intent filters + iOS extension
      sources) → Android complete; iOS needs the Xcode wiring in `docs/IOS_SHARE_EXTENSION.md`.
- [ ] **Deploy the backend** (Cloud Run / Render / Fly) and bake the URL into release builds.
- [ ] Verify the real Gemini path end-to-end with a key (`SABICHECK_MODE=gemini`) — the sandbox
      cannot reach Google APIs, so this was only tested with a mocked SDK.
- [ ] Replace placeholder launcher icons; create the Android release keystore.
- [ ] Verify brand/trademark availability for "Sabi" and "SabiCheck" before store submission.
- [ ] Tier 1 next steps: offline rule engine (Dart port of the backend mock heuristics as a
      first pass), number/link reputation endpoint, "report a scam".

## 12. Implementation Log

- **2026-09-02** — Backend proxy built and tested (50 tests). Flutter app core written: check
  flow, EN/FR, dark mode, local history, settings, Android share sheet, iOS share extension
  sources, CI workflow. Spec §5.3/§6/§8/§9/§10/§11 updated to match reality.

---

_End of spec._
