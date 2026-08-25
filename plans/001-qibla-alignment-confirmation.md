# 001 — Add Qibla alignment confirmation

- **Status**: DONE
- **Commit**: a981b8d
- **Severity**: MEDIUM
- **Category**: Feedback and accessibility
- **Estimated scope**: 1 file, roughly 35 lines

## Problem

Alignment currently changes color and triggers a haptic, but the visual confirmation is easy to miss when the user is watching the Kaaba marker rather than the guidance text.

```swift
// Muslim5/Views/QiblaView.swift:292 — current
Circle()
    .fill(isAligned ? AppTheme.success : AppTheme.accent)
    .frame(width: 22, height: 22)
```

## Target

On the same debounced alignment event that triggers the success haptic:

- Scale the center puck `1 → 1.16 → 1` over 240ms total using two 120ms `.easeOut` phases.
- Add a non-interactive halo behind it that scales `0.75 → 1.30` and fades `0.32 → 0` over 280ms `.easeOut`.
- Under Reduce Motion, keep the puck at scale `1`, keep the halo at scale `1`, and fade the halo `0.32 → 0` over 140ms `.easeOut`.
- Retrigger from the current state and cancel any prior pulse task so rapid sensor jitter never stacks animations.
- Do not animate the compass rose or Kaaba marker rotations.

## Repo conventions to follow

- The project uses SwiftUI value-driven animation and `.easeOut`, for example `Muslim5/Views/Components/PrayerRow.swift:182` uses `.animation(.easeOut(duration: 0.14), value:)`.
- Existing alignment hysteresis lives in `Muslim5/Views/QiblaView.swift:49-57`; extend that event rather than creating a second alignment detector.
- Use `@Environment(\.accessibilityReduceMotion)` to branch movement while retaining opacity feedback.

## Steps

1. Add a monotonically increasing alignment-pulse trigger in `QiblaView`; increment it only beside the existing success haptic.
2. Pass that trigger into `QiblaCompass`.
3. Add private state for puck scale, halo scale, halo opacity, and a cancellable pulse task in `QiblaCompass`.
4. Overlay the halo behind the existing center puck and run the exact phases in **Target** when the trigger changes.
5. Cancel an in-flight pulse before starting another and when the compass disappears.

## Boundaries

- Do NOT modify heading smoothing, bearing math, alignment tolerance, or haptic hysteresis.
- Do NOT add dependencies or animate color/layout properties.
- Do NOT animate the compass or marker rotations.

## Verification

- **Mechanical**: run `xcodebuild test -project Muslim5.xcodeproj -scheme 'Muslim 5' -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' CODE_SIGNING_ALLOWED=NO`; expect all tests to pass.
- **Feel check**: on a physical iPhone, cross into ±3° alignment and confirm one restrained pulse and one haptic. Hover near the boundary and confirm pulses do not stack. Enable Reduce Motion and confirm only the halo opacity changes.
- **Done when**: alignment produces exactly one visible confirmation per armed alignment event without adding lag to heading updates.
