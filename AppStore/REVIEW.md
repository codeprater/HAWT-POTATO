# HAWT POTATO — App Store Connect / Xcode upload

Version **2.0** (build **1**). Archive uses the **Release** scheme.

## Upload from Xcode

1. Open `HAWT POTATO.xcodeproj` in Xcode.
2. Select the **HAWT POTATO** scheme and **Any iOS Device (arm64)**.
3. Signing & Capabilities: Team **N73XW3H4MX**, Automatically manage signing.
4. Product → **Archive**.
5. Organizer → **Distribute App** → **App Store Connect** → **Upload**.
6. Leave “Upload your app’s symbols” on. Encryption question: **No** (the app sets `ITSAppUsesNonExemptEncryption = NO`).

## Host these before you submit

Put the files in `AppStore/` on `https://hawtpotato.app`:

- `https://hawtpotato.app/privacy` → `privacy.html`
- `https://hawtpotato.app/terms` → `terms.html`
- `https://hawtpotato.app/.well-known/apple-app-site-association` → `apple-app-site-association`  
  Serve it as `application/json` with **no** `.json` filename.

App Store Connect **Privacy Policy URL** must be the live privacy page. Support URL can be the same site or `mailto:support@hawtpotato.app`.

## App Store Connect checklist

- Age rating: 12+ (or 13+). Kids category: **no**.
- Privacy nutrition labels must match the app privacy manifest:
  - Name, User ID, Coarse Location, Precise Location, Other User Content, Gameplay Content
  - Used for App Functionality, linked to identity, **not** used for tracking
- Encryption: **No** (HTTPS / iCloud / Apple encryption only)
- Category: Games
- Screenshots: iPhone portrait — Home, receive, throw, Lobby, Settings. iPad if you list iPad.
- Review notes: there is **no login**. Identity is iCloud/CloudKit. Nearby only works with **two devices, both apps open**.
- After Apple assigns an app ID, replace `ProductCanon.appStoreURL` with `https://apps.apple.com/app/idYOURID`

## Developer portal (Identifiers)

Enable App Groups (`group.com.courtneyprater.HawtPotato`) and iCloud CloudKit (`iCloud.com.courtneyprater.HawtPotato`) on:

- `com.courtneyprater.HawtPotato`
- `com.courtneyprater.HawtPotato.messages`
- `com.courtneyprater.HawtPotato.Clip`
- `com.courtneyprater.HawtPotato.watchkitapp`
- `com.courtneyprater.HawtPotato.widgets`

Clip needs Associated Domains (`appclips:hawtpotato.app`). Do **not** turn on iCloud for the Clip ID unless you also add CloudKit back to `HAWTPotatoClip.entitlements` — the current archive signs without Clip iCloud.

Push: Debug uses `development`. Release / App Store uses `production` (`HAWT POTATO-Release.entitlements`).

## What the binary includes for review

- Onboarding: display name, 13+ checkbox, accept Terms/Privacy
- Settings: Privacy, Terms, support email, blocked list, report, Delete All Data
- iMessage app for group chats; long-press throw menu in the game
- Watch is companion-only
- App Clip shows the potato and an App Store overlay to install
- Privacy manifests on the app, extensions, and HAWTPotatoCore
- Credit: 2026 Courtney & Kourtney Prater
