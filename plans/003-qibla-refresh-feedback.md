# 003 — Animate Qibla location refresh feedback

- **Status**: DONE
- **Commit**: a981b8d
- **Severity**: LOW
- **Category**: Feedback and accessibility
- **Estimated scope**: 1 file, roughly 25 lines

## Problem

The location refresh button emits a haptic but its visual state does not confirm that the request was registered.

```swift
// Muslim5/Views/QiblaView.swift:78 — current
Button {
    locationProvider.requestLocation()
    HapticFeedback.selection()
} label: {
    Image(systemName: "arrow.clockwise")
```

## Target

- Normal motion: rotate only the arrow symbol by one full turn (`+360°`) over 240ms `.easeInOut` after each tap.
- Reduce Motion: do not rotate; fade symbol opacity `1 → 0.55 → 1` over 140ms total using two 70ms `.easeOut` phases.
- Retarget cleanly on repeated taps: normal-motion rotation accumulates by 360°; reduced-motion feedback cancels and restarts its current task.
- Do not loop for the duration of the location request.

## Repo conventions to follow

- `Muslim5/Views/TodayView.swift:184` uses `.easeInOut(duration: 0.2)` for on-screen movement.
- Existing button style and selection haptic remain unchanged.

## Steps

1. Add refresh rotation, opacity, and cancellable reduced-motion task state to `QiblaView`.
2. Read `accessibilityReduceMotion` from the environment.
3. Extract a small helper called from the existing button action after requesting location and haptic feedback.
4. Apply only `rotationEffect` and `opacity` to the `arrow.clockwise` image using the exact timings in **Target**.
5. Cancel the reduced-motion task when the view disappears.

## Boundaries

- Do NOT change the button’s hit target, style, haptic, or request semantics.
- Do NOT show a looping progress animation or disable the button.
- Do NOT add dependencies.

## Verification

- **Mechanical**: run the existing iPhone 17 simulator test command; expect all tests to pass.
- **Feel check**: tap refresh repeatedly and confirm each tap adds one responsive turn without snapping backward. Enable Reduce Motion and confirm there is no rotation, only a short opacity response.
- **Done when**: every refresh tap has immediate visual feedback and no animation remains active for the network/location wait.
