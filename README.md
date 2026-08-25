# Muslim 5

Muslim 5 is a private, local-first iPhone tracker for the five daily prayers. It uses a gentle habit-building approach: progress is visible, while missed days never erase earlier effort.

## Current MVP

- Five-prayer daily checklist
- Completed, late, and prayed-after-time statuses
- Congregation and individual prayer attendance
- SwiftData persistence stored on-device
- Twenty-week contribution grid
- Current streak, complete days, and 30-day consistency
- User-friendly monthly and prayer-by-prayer reflections
- Period mode with streak-neutral date ranges
- Offline, location-aware prayer times powered by Adhan Swift
- Active-prayer and next-prayer countdowns on the Today screen
- Dawn, daylight, golden-hour, dusk, and night homepage scenes
- Calculation-method and Asr-method preferences
- Configurable on-device reminders for each prayer time
- Subtle prayer-phase color transitions
- Dark Mode and accessibility labels

## Run locally

1. Open `Muslim5.xcodeproj` in Xcode.
2. Select the **Muslim 5** scheme.
3. Choose an iPhone simulator or your signing-enabled iPhone.
4. Press **Run**.

The project requires iOS 17 or later and uses Adhan Swift for offline prayer-time calculations.

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
