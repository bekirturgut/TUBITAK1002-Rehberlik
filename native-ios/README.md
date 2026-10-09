# Native Swift / SwiftUI Rehberlik

The Swift iOS client preserves the original Flutter data flow and backend. There is no Firebase Auth login, custom-token bridge, credential hashing migration, server-side quiz grading, or native device registry.

## Compatibility

- Login queries `users` by normalized phone, compares the existing `password` and `role`, then stores the remembered user ID locally. Login history is written to the original subcollection.
- User administration writes the original profile fields directly. Existing passwords remain when the password field is left blank. There is no new password length requirement or disabled-account behavior.
- Quiz results use `correctCards` / `wrongCards` and `${collectionName}_${cardId}` IDs. Evaluation, rounded percentages and persistent badges follow Flutter's QuizProgressService.
- Chat writes user/admin/bot messages directly; only the original `askFaqBot` and `escalateChatToAdmin` callables are used with their original payloads. Existing expert-reply triggers remain.
- FCM tokens are stored in `users/{uid}.fcmToken`. Local notification scheduling uses `scheduledNotifs`; existing queue IDs and backend schedulers remain.
- User deletion follows Flutter's original scope: user notifications, loginHistory, scheduledNotifs, and user document. It does not introduce deletion of other legacy collections.

The original backend flow is restored from `e445e39`; only FieldValue/Timestamp imports are adjusted for Firebase Admin SDK compatibility. Package files and firebase.json are restored byte-for-byte. No replacement production rules or indexes are deployed. Local rotated Gemini credentials remain ignored by Git.

## Build and tests

Validated on 9 October 2026 at `306ad10`: [successful CI run](https://github.com/bekirturgut/TUBITAK1002-Rehberlik/actions/runs/37898717007). All 39 distinct tests/checks passed, including actual Swift/Firestore user operations and UI login–quiz–expert conversation. The unsigned iPhone Release build also succeeded. See the [validation report](../docs/SWIFT_GECIS_RAPORU.md) for scope and limits.

Requires macOS, Xcode 16.4+ and XcodeGen. iOS target: 16.

```sh
swift test --package-path Core
brew install xcodegen
xcodegen generate
xcodebuild test -project Rehberlik.xcodeproj -scheme Rehberlik -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
```

GitHub Actions also tests the unsigned device build. Demo UI tests use `-ui-testing`; actual Firebase UI tests use debug-only `-emulator-testing`. The separate `firebase.legacy-tests.json` is only for the isolated `demo-rehberlik` emulators. Its permissive test rules must not be deployed. `prepare-emulator.js` creates an ignored copy of the original backend with fake Gemini and messaging; no local secrets are copied. Emulator checks therefore validate data flow, not real Gemini quality or APNs delivery.

## Device distribution

Apple Developer signing, APNs key upload to Firebase, TestFlight and physical iPhone notification tests are still required for distribution. These do not require changing the existing login or migrating users. No live backend deployment is required by the client conversion itself, provided existing Firestore rules allow the unchanged Flutter operations.
