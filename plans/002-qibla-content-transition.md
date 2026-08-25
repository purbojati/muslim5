# 002 — Bridge Qibla location state into the compass

- **Status**: DONE
- **Commit**: a981b8d
- **Severity**: LOW
- **Category**: Preventing a jarring change
- **Estimated scope**: 1 file, roughly 10 lines

## Problem

When a coordinate becomes available, the location placeholder is replaced by the full compass with no visual bridge.

```swift
// Muslim5/Views/QiblaView.swift:20 — current
if let coordinate = locationProvider.coordinate {
    compassContent(for: coordinate)
} else {
    locationStateContent
}
```

## Target

- Compass insertion: `opacity 0 → 1` plus `scale 0.97 → 1` over 200ms `.easeOut`.
- Location-state removal: `opacity 1 → 0` over 140ms `.easeOut` with no movement.
- Under Reduce Motion, compass insertion becomes opacity-only over 200ms `.easeOut`; removal remains opacity-only over 140ms.
- Animate only opacity and transform; do not animate layout or the navigation/tab transition.

## Repo conventions to follow

- `Muslim5/Views/Components/PrayerSkyBackground.swift:26-31` uses `.transition(.opacity)` with a short value-driven animation.
- Keep this transition local to the coordinate conditional in `QiblaView`.

## Steps

1. Read `accessibilityReduceMotion` from the SwiftUI environment in `QiblaView`.
2. Give the compass and location-state branches asymmetric transitions matching **Target**.
3. Drive the transition from whether `locationProvider.coordinate` is present; use a value-driven animation so changes are interruptible.

## Boundaries

- Do NOT animate the whole screen, navigation title, location header, or tab bar.
- Do NOT change location request behavior or either branch’s layout.
- Do NOT add dependencies.

## Verification

- **Mechanical**: run the existing iPhone 17 simulator test command; expect all tests to pass.
- **Feel check**: reset location permission in Simulator, open Qibla, grant access, and confirm the placeholder fades away while the compass gently settles from 0.97 scale. Enable Reduce Motion and confirm there is no scale change.
- **Done when**: the swap is visually bridged without delaying interaction or moving surrounding navigation.
