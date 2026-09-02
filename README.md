# SabiCheck

**Know what's real.** AI-powered scam & fraud verifier for African digital users
(Cameroon / West Africa focus). Paste a suspicious WhatsApp / SMS / email — or share
it straight from the app it arrived in — and get a structured verdict: risk level,
confidence, category, explanation and what to do next. English & French.

Part of the **Sabi** family (SabiHub, SabiCheck, …). Successor to the
[ScamShield AI](https://github.com/tataisaac/scamshield-cyber-ai) web app.

> The product spec is the source of truth: [`SABICHECK_SPEC.md`](SABICHECK_SPEC.md).

## Repository layout

```
lib/          Flutter app (Android · iOS · web)
  config/     build-time config (--dart-define)
  l10n/       EN/FR strings
  models/     ScamAnalysis contract, history records
  services/   API client, share-sheet receiver, image loading
  state/      settings / history / analysis controllers (provider)
  screens/    Home (check), History, Settings
  widgets/    verdict card, risk badge
  theme/      emerald/teal Material 3 theme
test/         unit + widget tests (fake API, no network)
backend/      SabiCheck API — Gemini proxy (Node/TS). See backend/README.md
android/      share-sheet intent filters, network security config
ios/          Share Extension sources — wiring steps in docs/IOS_SHARE_EXTENSION.md
.github/      CI: backend tests · flutter analyze/test · debug APK + web build
```

## Architecture in one paragraph

The app is a **thin client**. It never talks to Gemini directly and ships **no API
key**. It calls the small backend in `backend/` (`POST /v1/analyze`,
`POST /v1/translate`), which holds the key, validates input, rate-limits, caches and
returns a strict `ScamAnalysis` JSON. The backend has a `mock` mode (offline
heuristic) so the app can be developed with zero AI cost.

## Quick start

### 1. Backend (2 minutes)

```bash
cd backend
npm install
cp .env.example .env        # SABICHECK_MODE=mock by default — no key needed
npm run dev                 # → http://localhost:8080
```

For real AI: put `GEMINI_API_KEY=...` in `.env` and set `SABICHECK_MODE=gemini`.

### 2. App

```bash
flutter pub get
flutter run                 # Android emulator reaches the backend at http://10.0.2.2:8080 by default
```

- **Physical Android phone** on the same Wi-Fi as your laptop:
  `flutter run --dart-define=SABICHECK_API_URL=http://<laptop-ip>:8080`
  (or change it later in *Settings → Developer*). Debug builds allow plain HTTP.
- **iOS simulator**: `--dart-define=SABICHECK_API_URL=http://localhost:8080`
- **Web**: `flutter run -d chrome --dart-define=SABICHECK_API_URL=http://localhost:8080`
  (CORS is open by default; restrict with `ALLOWED_ORIGINS` in production).

### 3. Try the killer feature (Android)

Install on a phone → open WhatsApp → long-press a message → **Share** → **SabiCheck**
→ the message is pre-filled → tap **Check message**. Works for screenshots from
Gallery/Photos too. iOS needs the one-time Xcode setup in
[`docs/IOS_SHARE_EXTENSION.md`](docs/IOS_SHARE_EXTENSION.md).

## Development

```bash
# App
flutter analyze
flutter test
dart format lib test

# Backend
cd backend && npm test && npm run typecheck
```

CI runs all of the above on every push and uploads a debug APK as an artifact
(GitHub → Actions → latest run → *sabicheck-debug-apk*).

### Build-time flags

| `--dart-define`        | Purpose                                              | Default                               |
| ---------------------- | ---------------------------------------------------- | ------------------------------------- |
| `SABICHECK_API_URL`    | Backend base URL                                     | debug `http://10.0.2.2:8080`, release `https://api.sabicheck.example` |
| `SABICHECK_APP_TOKEN`  | Bearer token if the backend sets `SABICHECK_APP_TOKEN` | *(none)*                            |

### Release build

```bash
flutter build appbundle --dart-define=SABICHECK_API_URL=https://<your-api-host>
```

Before the first store upload: create a real signing key (`android/key.properties`),
replace the launcher icons, and set `ALLOWED_ORIGINS` / rate limits on the backend.

## Status

- ✅ Backend proxy (tests, mock + Gemini providers, caching, rate limiting)
- ✅ App core: check flow, EN/FR, dark mode, history, settings
- ✅ Android share sheet (text + images)
- ✅ iOS share extension sources (needs Xcode wiring)
- ⏳ Offline rule engine, number/link reputation, community reports — see spec §7

## License

MIT — see [LICENSE](LICENSE).
