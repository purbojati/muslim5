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

## Suggested next phase

1. Add manual city selection and per-prayer minute adjustments.
2. Add a WidgetKit home/Lock Screen widget.
3. Add data export and local backup.
4. Create the final app icon and onboarding flow.
