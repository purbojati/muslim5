# Salah Streak

Salah Streak is a private, local-first iPhone tracker for the five daily prayers. It uses a gentle habit-building approach: progress is visible, while missed days never erase earlier effort.

## Current MVP

- Five-prayer daily checklist
- Completed, late, and made-up statuses
- SwiftData persistence stored on-device
- Twenty-week contribution grid
- Current streak, complete days, and 30-day consistency
- User-friendly monthly and prayer-by-prayer reflections
- Period mode with streak-neutral date ranges
- Travel-mode foundation
- Calculation-method and Asr-method preferences for the upcoming prayer-time phase
- Dark Mode and accessibility labels

## Run locally

1. Open `SalahStreak.xcodeproj` in Xcode.
2. Select the **Salah Streak** scheme.
3. Choose an iPhone simulator or your signing-enabled iPhone.
4. Press **Run**.

The project requires iOS 17 or later and has no third-party dependencies.

## Suggested next phase

1. Add location permission and an offline prayer-time calculation engine.
2. Schedule local prayer reminders.
3. Add a WidgetKit home/Lock Screen widget.
4. Add data export and local backup.
5. Create the final app icon and onboarding flow.
