# Muslim 5

Muslim 5 is a private, local-first iPhone tracker for the five daily prayers. It
uses a gentle habit-building approach: progress is visible, while missed days
never erase earlier effort. Its optional **Salah Circle** helps families and
friends quietly encourage one another without turning worship into a social
feed.

## Salah Circle — pray together, even when apart

Every user receives a simple personal linking code. Share the code with family
or friends to connect instantly—there are no invitations to approve and no
complicated account setup.

When someone in your Salah Circle completes a prayer, their compact two-letter
initial appears directly on that prayer's card on the Today screen. One glance
shows that your people have prayed, offering gentle accountability without
scores, rankings, messages, profile photos, or full-name clutter.

Only the minimum sharing data is sent to the backend. Detailed prayer history,
timing and attendance status, streaks, location, and preferences remain on the
iPhone.

## Current MVP

- Salah Circle linking through auto-generated personal codes
- Compact two-letter initials from linked users on each completed prayer card
- Five-prayer daily checklist
- Completed, late, and prayed-after-time statuses
- Congregation and individual prayer attendance
- SwiftData persistence stored on-device
- Twenty-week contribution grid
- Current streak, complete days, and 30-day consistency
- User-friendly monthly and prayer-by-prayer reflections
- Period mode with streak-neutral date ranges
- Offline, location-aware prayer times powered by Adhan Swift
- Offline Qibla compass with live turn-by-turn guidance
- Active-prayer and next-prayer countdowns on the Today screen
- Dawn, daylight, golden-hour, dusk, and night homepage scenes
- Calculation-method and Asr-method preferences
- Configurable on-device reminders for each prayer time
- Optional Salah Focus Screen Time shields for user-selected apps and websites
- Subtle prayer-phase color transitions
- Dark Mode and accessibility labels

## Run locally

1. Open `Muslim5.xcodeproj` in Xcode.
2. Select the **Muslim 5** scheme.
3. Choose an iPhone simulator or your signing-enabled iPhone.
4. Press **Run**.

The project requires iOS 17 or later and uses Adhan Swift for offline prayer-time calculations.

## Salah Circle backend

Muslim 5 uses a small Cloudflare Worker and D1 database for linking users and
showing who has completed each prayer. The production API is available at
[muslim5.purbojati.workers.dev](https://muslim5.purbojati.workers.dev), with a
health check at [`/health`](https://muslim5.purbojati.workers.dev/health).

The prayer tracker remains local-first. SwiftData stores the full prayer log,
timing and attendance status, streaks, period mode, preferences, location, and
calculated prayer times on the iPhone. The backend only stores the data required
for sharing:

- User ID, nickname, avatar key, linking code, hashed authentication token, and
  creation/update timestamps
- Mutual user links and their creation timestamps
- Completed prayer name, local calendar date, and completion timestamp

Private authentication tokens are returned once when a profile is created and
stored in the iOS Keychain; D1 stores only their SHA-256 hashes. Linking is
immediate when a valid code is entered and does not require acceptance. Either
person can unlink later, and deleting a sharing profile also deletes its links
and check-ins through database cascades.

Sync uses normal HTTPS requests rather than WebSockets or push updates. A user's
changes are written immediately when the app synchronizes, while linked-user
initials refresh when the Today screen loads, the app becomes active, or the
user pulls to refresh.

### Backend development

The Worker source, D1 migration, tests, and complete API reference live in
[`backend/`](backend/README.md). Bun runs the local scripts and Wrangler runs the
Worker:

```sh
cd backend
bun install
bun run cf-typegen
bun run db:migrate:local
bun run dev
```

The local API runs at `http://127.0.0.1:8787`, which is already configured for
Debug builds. Production uses the Worker named `muslim5` and the D1 database
named `salah-streak`. To verify and deploy backend changes:

```sh
cd backend
bun run cf-typecheck
bun run typecheck
bun run test
bun run deploy:check
bun run db:migrate:remote
bun run deploy
```

Set the Release `SALAH_API_BASE_URL` build setting to
`https://muslim5.purbojati.workers.dev` before an App Store build.

## Distribute to App Store Connect

Run the distribution script from the project root:

```sh
./scripts/distribute-app-store.sh
```

Every run increments both versions before archiving: the last digit of the
marketing version increments (`0.1.0` to `0.1.1`) and the build number increments
by one (`1` to `2`). It then creates a Release archive and uploads it to App Store
Connect using the Apple account configured in Xcode.

Useful modes:

```sh
# Preview the next version without changing or building anything
./scripts/distribute-app-store.sh --dry-run

# Build and export an IPA locally without uploading it
./scripts/distribute-app-store.sh --no-upload
```

For CI, authenticate with an App Store Connect API key instead of an Xcode
account:

```sh
ASC_API_KEY_PATH=/absolute/path/to/AuthKey_XXXXXXXXXX.p8 \
ASC_API_KEY_ID=XXXXXXXXXX \
ASC_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
./scripts/distribute-app-store.sh
```

Archives, exported files, and distribution logs are written under
`.build/app-store/`. If a build or upload fails after versioning, the bumped
values remain in the Xcode project so the attempted build number is not reused.

## Suggested next phase

1. Add manual city selection and per-prayer minute adjustments.
2. Add a WidgetKit home/Lock Screen widget.
3. Add data export and local backup.
4. Create the final app icon and onboarding flow.
