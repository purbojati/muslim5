# 005 — iCloud backup

- **Status**: IMPLEMENTED — DEVICE/CLOUDKIT VERIFICATION PENDING
- **Platform**: iOS 17+
- **Category**: Data safety
- **Estimated scope**: 2 model updates, app container configuration, 1 small Settings status row, tests and two-device verification

## Outcome

Keep the user's prayer history and Period Mode ranges in their private iCloud account so the data automatically returns after reinstalling Muslim 5 and stays available on another iPhone signed into the same Apple Account.

Use SwiftData's managed CloudKit sync rather than building a separate backup-file format. The app remains local-first and usable offline; CloudKit uploads and downloads changes when iCloud and the network are available. This is automatic synchronization and recovery, not a browsable or point-in-time backup history.

## Data scope

Sync only user-authored SwiftData records:

- `PrayerRecord`: prayer, day, completion status, attendance, and recorded time.
- `TrackingPause`: Period Mode start/end dates and reason.

Keep these device-local:

- location and cached city;
- notification authorization and per-prayer notification switches;
- Salah Focus authorization, selected app tokens, monitoring state, and App Group payload;
- welcome state and other presentation preferences;
- Salah Circle token/profile data, which already belongs to the backend and device-only Keychain.

Calculation and Asr methods may be added to iCloud key-value storage later, but they are outside this first backup scope.

## Product behavior

- Enable iCloud automatically when the user is signed into iCloud; do not add a manual **Back Up Now** button because SwiftData controls the sync schedule.
- Continue reading and writing the local store when offline or when no iCloud account is available.
- Add a concise row in **Others → Data**: **iCloud Sync**, with `Available`, `Sign in to iCloud`, or `Temporarily unavailable` based on `CKContainer.accountStatus()`.
- Explain that changes may take a short time to appear on another device and that Salah Circle is separate.
- Do not expose raw CloudKit errors in the UI. Log them for development and keep local saves working.

## Implementation

### 1. Configure CloudKit

- Add the iCloud/CloudKit capability to the main app target only.
- Create and select the private container `iCloud.com.muslim5.app`.
- Keep the existing Family Controls and App Group entitlements intact.
- Configure `ModelContainer` with an explicit `Schema`, `ModelConfiguration`, and `cloudKitDatabase: .private("iCloud.com.muslim5.app")`.
- Add Push Notifications when Xcode requests it for CloudKit remote-change delivery.

### 2. Make the models CloudKit-compatible

- Remove `@Attribute(.unique)` from `PrayerRecord.id`; CloudKit cannot enforce SwiftData uniqueness constraints.
- Give every non-optional persisted property a declaration-time default so the CloudKit schema can materialize records safely.
- Preserve `PrayerRecord.id` as the logical `day + prayer` key.
- Centralize prayer writes in an upsert helper that fetches by logical ID before inserting.
- On launch and after remote changes, collapse duplicate prayer IDs deterministically: keep the record with the latest `recordedAt`, merge any non-nil attendance from that winner, and delete the rest.
- Normalize duplicate or overlapping open `TrackingPause` ranges so simultaneous edits on two devices do not double-count paused days.

### 3. Preserve existing local data

- Add a versioned SwiftData schema and migration plan before changing the model metadata.
- Open the existing store in place with the CloudKit-enabled configuration so current records remain local and are uploaded when iCloud becomes available.
- Never replace a failed container with a new empty store. If initialization fails, show a recoverable launch error with retry and diagnostic logging instead of silently losing history.

### 4. Add lightweight status UI

- Create a small `ICloudStatusService` that observes account changes and publishes only availability state.
- Add the **Data** section to Settings with status text and a link to iPhone Settings when no iCloud account is present.
- Avoid progress percentages or “Last backed up” timestamps because managed SwiftData sync does not provide a reliable single backup-completion moment.

## Verification

- Migration test: install a build with the current local schema, add prayer records and a pause, upgrade to the CloudKit build, and confirm nothing disappears.
- Offline test: create/edit/delete records in Airplane Mode, relaunch, reconnect, and confirm eventual sync.
- Two-device test: create, edit, and delete the same prayer from two iPhones on the same iCloud account; verify deterministic de-duplication and convergence.
- Restore test: delete and reinstall the app, sign into the same iCloud account, and confirm prayer history and Period Mode ranges repopulate.
- Isolation test: verify a different Apple Account cannot access the data.
- Regression test: confirm notifications, Salah Focus extensions, and Salah Circle still use their existing device/backend state.
- Before release, initialize the development CloudKit schema, inspect both record types, and deploy the schema to production in CloudKit Console.

## Release gates

- Physical two-device and reinstall verification passes with production signing.
- Existing local-store migration is verified using an archived pre-iCloud build.
- The production CloudKit schema is deployed before the App Store build ships.
- App privacy copy states that prayer history is stored in the user's private iCloud account when iCloud is available.

## Implementation result

- Added the CloudKit and Push Notifications capabilities for `iCloud.com.muslim5.app`; automatic signing produced a development profile containing the expected iCloud entitlements.
- Switched the app's versioned SwiftData container to the private CloudKit database without changing its local store location.
- Made both models CloudKit-compatible, centralized prayer upserts/deletes, and added deterministic normalization for duplicate prayer records and overlapping Period Mode ranges.
- Added non-destructive store-open recovery and an iCloud availability row in Settings.
- Added in-memory regression tests for upserts and synced-data normalization.
- Verified a signed device build, a simulator launch over an existing pre-iCloud store, and the full unit-test suite.
- Still required before release: run the signed build on a dedicated iCloud test device/account, verify two-device and reinstall recovery, inspect the generated development schema, then deploy it to production in CloudKit Console.
