# iOS Share Extension — wiring checklist (Mac + Xcode required)

The Android share sheet works out of the box (intent filters are in
`AndroidManifest.xml`). On iOS, Apple requires a separate **Share Extension
target** that can only be created in Xcode. The Swift/plist files are already in
`ios/ShareExtension/`; this checklist wires them in. Budget ~30 minutes.

Reference: [receive_sharing_intent README → iOS](https://pub.dev/packages/receive_sharing_intent#ios).

## 0. Prerequisites

- macOS with Xcode 16+ and the Flutter SDK (`flutter doctor` green for iOS).
- An Apple Developer account (free tier is enough to run on your own device;
  a paid one is needed for TestFlight / App Store).
- Swift Package Manager enabled for Flutter (the plugin is SPM-only):

  ```bash
  flutter config --enable-swift-package-manager
  flutter pub get
  ```

## 1. Create the target

1. `open ios/Runner.xcworkspace`
2. **File → New → Target…** → iOS → **Share Extension** → Next.
3. Product Name: **`ShareExtension`** (exactly — the plist references
   `$(PRODUCT_MODULE_NAME).ShareViewController`). Language: Swift. Finish.
   If Xcode asks to *activate* the new scheme, choose **Cancel** (keep Runner).
4. Xcode created a `ShareExtension/` folder with `ShareViewController.swift`,
   `Info.plist` and `MainInterface.storyboard`.
   - **Delete** `MainInterface.storyboard` (move to trash).
   - **Replace** the generated `ShareViewController.swift` and `Info.plist` with
     the versions from this repo's `ios/ShareExtension/` folder (drag-and-drop
     with "Copy items if needed" unchecked, since they are already in place).
5. Select the **ShareExtension** target → **General**:
   - Minimum Deployments = same as Runner (**iOS 15.0**).
   - Bundle Identifier = `com.incredible.sabicheck.ShareExtension`.

## 2. App Group (shared container)

The extension writes the shared payload where the app can read it.

1. Runner target → **Signing & Capabilities** → **+ Capability** → **App Groups**
   → **+** → `group.com.incredible.sabicheck`. Tick it.
2. Repeat for the **ShareExtension** target, selecting the **same** group.
3. Both targets → **Build Settings** → **+** → **Add User-Defined Setting**:
   `CUSTOM_GROUP_ID` = `group.com.incredible.sabicheck`.
   (Both `Info.plist` files read `$(CUSTOM_GROUP_ID)`.)

`ios/Runner/Runner.entitlements` and `ios/ShareExtension/ShareExtension.entitlements`
already contain this group; if Xcode generated new entitlement files, make sure
the target's *Code Signing Entitlements* build setting points at one containing it.

## 3. Link the plugin into the extension

ShareExtension target → **General → Frameworks and Libraries → +** → choose
**`receive-sharing-intent`** from the `receive_sharing_intent` Swift package.

Then Runner target → **Build Phases**: drag **Embed Foundation Extensions** so it
sits **above** *Thin Binary* (otherwise: `No such module 'receive_sharing_intent'`).

## 4. Signing

Select your Team on **both** targets (Signing & Capabilities). Automatic signing
will create the App Group entitlement in your developer account.

## 5. Test

```bash
flutter run -d <your-iphone>
```

1. Open WhatsApp → long-press any message → **Share** → scroll the app row →
   **SabiCheck**. The app opens with the text pre-filled; tap **Check message**.
2. Photos → pick a screenshot → Share → SabiCheck → screenshot attached.
3. If SabiCheck doesn't appear in the share sheet: tap **More** at the end of the
   app row and enable it; also confirm the activation rule in
   `ios/ShareExtension/Info.plist` covers the content type.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `No such module 'receive_sharing_intent'` | Step 3 (embed order) or the framework isn't linked to the extension target. |
| App opens but input is empty | `CUSTOM_GROUP_ID` differs between targets, or App Groups capability missing on one of them. |
| Extension shows a blank white sheet | `MainInterface.storyboard` still referenced — remove it; the plist uses `NSExtensionPrincipalClass`. |
| Works in debug, missing in TestFlight | The extension has its own provisioning profile; regenerate profiles after adding the App Group. |

## Later: Message Filter Extension (SMS junk filtering)

Separate from the share sheet. iOS lets an app classify SMS from **unknown
senders** via an `ILMessageFilterExtension` (offline rules or a fixed backend
URL), moving scams to the Junk tab. This is the only legal "auto-scan SMS" on
iPhone — see SABICHECK_SPEC.md §6. Not started yet.
