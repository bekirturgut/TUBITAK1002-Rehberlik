# Native Swift / SwiftUI Rehberlik

This directory is the native iOS replacement for the Flutter client. Flutter sources are retained as the migration reference; the new backend requires a coordinated cutover before any legacy Android client can share it. No Dart runtime is linked into this application.

## Build and test

Requires macOS, Xcode 16.4+ and XcodeGen. iOS deployment target: 16. Firebase Apple SDK pinned to 12.0.0 via Swift Package Manager.

```sh
swift test --package-path Core
brew install xcodegen
xcodegen generate
xcodebuild test -project Rehberlik.xcodeproj -scheme Rehberlik -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project Rehberlik.xcodeproj -scheme Rehberlik -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

GitHub Actions performs core tests, app/unit/UI simulator tests, and an unsigned physical-device build. Unsigned artifacts cannot be installed on an iPhone. UI tests cover both `-ui-testing` in-memory fixtures and a debug-only `-emulator-testing` flow against isolated Auth, Firestore and Functions emulators: mother login, server-graded quiz, AI fallback, admin login/expert reply, and receipt by the mother account. The emulator flow is enabled by `RUN_FIREBASE_UI_TESTS=1` in CI. These tests do not prove production IAM, Gemini availability or APNs delivery.

## Feature mapping

| Flutter | Native SwiftUI |
|---|---|
| LoginPage | LoginView, authenticated server-side phone/password bridge |
| MotherPage / UpperPage | HomeView, typed role profile |
| LearnPage | QuizView, RehberlikCore, server-authoritative idempotent grading |
| quiz_progress_service / user_badge_summary | QuizSummary, BadgesView, profile/progress listeners |
| SSSPage | FAQView |
| ChatPage | ChatView, ChatModel, callable message/feedback endpoints |
| NotificationPage | NotificationsView, FCM/APNs |
| AdminPage / UsersTab | AdminView, UsersView |
| UserDetailPage / LoginHistoryPage | UserEditor, UserDetailView, HistoryView |
| GameCardsTab / detail | ContentListView(.cards), ContentEditor |
| SSSTab / detail | ContentListView(.faq), ContentEditor |
| ChatbotTab / detail | ContentListView(.bot), ContentEditor |
| NotificationsTab / detail | ContentListView(.notifications), ContentEditor |

Native accessibility, Dynamic Type, system navigation and controls replace the Flutter-specific animations. Text/content and data identities are preserved; this is not a pixel-for-pixel renderer.

## Backend cutover (not automatically deployed)

1. Revoke the exposed Gemini API key. Removing `.env` from new commits does not remove Git history or invalidate the key.
2. Back up the live Firestore database. Freeze legacy user/content writes during credential migration.
3. Run `npm run migrate:users` from functions with operator ADC credentials. It performs validation only. Resolve duplicate/invalid phone numbers and missing roles/dates first.
4. Run `npm run migrate:users -- --apply` only after the dry run succeeds. The script preserves Firestore user IDs and all subcollections, creates private scrypt credentials and phone indexes, and deletes plaintext passwords. Legacy Flutter phone/password login stops working after this change. Run `node scripts/migrate-notifications.js` (dry run) then the same command with `--apply` to preserve sent-state from the legacy queue and prevent duplicate template delivery.
5. Configure the new key with `firebase functions:secrets:set GEMINI_API_KEY`. Configure Firebase Auth and give the function service account the permissions required to sign custom tokens (Service Account Token Creator). Do not commit signing credentials.
6. Deploy the native function set and Firestore rules/indexes together during a coordinated cutover. The legacy scheduled functions/embedding triggers must be removed when the CLI identifies obsolete functions; do not run both versions concurrently.
7. Embed existing FAQ vectors again with output dimensionality 768; old mismatching vectors cannot be compared. An edit of the FAQ question regenerates its vector. See the operator backfill script.
8. Verify a migrated mother, elder and admin account against staging before production cutover. First admin is a validated legacy profile; new admins can only be created by an authenticated admin.

Rules deny all client writes to profiles, quiz results, credentials, messages, devices, queue and alerts. Admin content changes are schema-validated by Firestore rules. Native uses private credentials through callable login and Firebase Auth custom tokens; no password is read from Firestore by the app.

## Notifications and account lifecycle

Only the server schedules templates. Registration is held until an APNs token exists. Each installation has one active owner in the server device registry. Logout detaches the installation (or invalidates the token on failure), clears delivered notifications and ends the authenticated session. Message bodies and names are omitted from push text. Queue creation is idempotent and sends use a lease, retry backoff, per-device completion and APNs collapse IDs. FCM delivery is at-least-once: a crash between send acceptance and recording success can still duplicate a notification.

Signing/APNs setup remains required: select the teacher's Developer team, register the bundle ID, enable Push Notifications, upload an APNs authentication key to Firebase, provision the app and use TestFlight. The repository contains no Apple private key or signing profile.

## Remaining verification boundaries

Live account migration, IAM/token signing, Gemini response quality, notification delivery in foreground/background/terminated states, account-switch behavior on physical devices and TestFlight signing require the appropriate external accounts/device. CI fixtures are not substitutes for those checks. Nothing here deploys to production automatically.
