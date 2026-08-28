# 004 — Salah Focus app shield

- **Status**: IMPLEMENTED — DEVICE VERIFICATION PENDING
- **Platform**: iOS 17+
- **Category**: Focus and accountability
- **Estimated scope**: 3 app-extension targets, 5–7 new Swift files, 4–6 modified files
- **External prerequisite**: Family Controls entitlement approval for the app and Screen Time extensions

## Outcome

Add an optional **Salah Focus** setting that shields user-selected distracting apps and websites when a prayer becomes due. The shield stays active until that specific salah is recorded in Muslim 5. The user can turn the feature off at any time, which immediately removes all shields and cancels future monitoring.

This is the closest App Store-compliant version of “lock the phone.” A normal iOS app cannot lock the whole device or replace the system Lock Screen. Apple’s Screen Time APIs can instead shield apps, app categories, and web domains chosen by the user. Phone, emergency, system, and other unselected access remains available.

## Product decisions

- Name the feature **Salah Focus**, not “Phone Lock,” so the UI accurately describes the system behavior.
- Make it fully opt-in and off by default.
- Use Apple’s individual Screen Time authorization with Face ID or Touch ID.
- Let the user select which apps, categories, and websites are shielded using Apple’s privacy-preserving picker. Muslim 5 itself must remain reachable.
- Apply the shield at the calculated start time for each enabled prayer. MVP enables all five prayers; a follow-up may add per-prayer switches if user feedback justifies the extra settings.
- Keep the shield active for the exact due prayer until a record for that prayer and local calendar day saves successfully. A late or made-up status also counts because all three statuses represent a completed salah.
- If another prayer becomes due while the earlier shield remains active, keep the earlier prayer as the requirement. After it is recorded, immediately reconcile; if another prayer is already due and unrecorded, update the shield to that prayer rather than briefly unlocking.
- If the user removes the active prayer record while its window is still due, reconcile and reapply the shield.
- Turning Salah Focus off is always allowed from Muslim 5 Settings and clears the shield immediately. Do not add a cooldown, PIN, remote approval, or shame copy.
- Period Mode suspends Salah Focus, cancels monitoring, and clears active shields. Turning Period Mode off runs a fresh reconciliation from the next applicable prayer; it does not lock for prayers within the paused range.
- Keep all Salah Focus state on-device. Do not add it to Salah Circle or the backend.

## User flow

### Enable

1. In **Others → Salah Focus**, the user sees a short explanation: “At prayer time, pause selected apps until you record your salah.”
2. Tap **Set Up Salah Focus**.
3. Request individual Family Controls authorization. Explain that Face ID/Touch ID is an Apple permission step and that Muslim 5 cannot see the names of selected apps.
4. Present `FamilyActivityPicker` and require at least one app, category, or web domain.
5. Show a confirmation summary with the five prayers, “Starts at each prayer time,” and a prominent **Turn On** button.
6. On success, persist the selection, enable the feature, reconcile current state, and schedule only the next uncompleted future prayer.

Do not request Family Controls authorization during first launch. It is a high-friction permission that should only appear after the user explicitly starts setup.

### Active shield

Use a custom Managed Settings shield:

- Title: **It’s time for {Prayer}**
- Body: **Complete your salah, then record it in Muslim 5 to continue.**
- Primary button on iOS 26.5+: **Open Muslim 5**
- Primary button on earlier iOS versions: **Close app**
- Secondary text: **Open Muslim 5 from your Home Screen.**

The shield action extension returns `.openParentalControlsApp` on iOS 26.5 and later. Earlier iOS versions return `.close` and tell the user to open Muslim 5 from the Home Screen.

### Complete

1. The user opens Muslim 5 and records the active salah in the existing Today checklist.
2. `modelContext.save()` succeeds.
3. The app writes the completion snapshot to the shared app-group state.
4. The Salah Focus coordinator reconciles synchronously from the user’s perspective:
   - clear the named `ManagedSettingsStore` when no prayer is due; or
   - move directly to the next already-due, unrecorded prayer; then
   - schedule the next future prayer trigger.
5. Show a small confirmation near the prayer row: **Apps available again**. Keep the existing prayer completion haptic; do not add a second competing success haptic.

### Disable or repair

The detail screen contains:

- master toggle;
- authorization status;
- selected-item count and **Choose Apps & Websites**;
- **Test Shield** in Debug builds only;
- a concise error row when monitoring cannot be scheduled;
- **Open iPhone Settings** when authorization is denied or later revoked.

When the master toggle is switched off, first clear the named store and stop all Muslim 5 device-activity monitoring, then persist `enabled = false`. This ordering avoids leaving a shield behind if the app is terminated between operations.

## State model

Treat enforcement as a small derived state machine rather than scattering booleans through views:

```text
disabled
  └─ setup + authorization + nonempty selection → ready
ready
  ├─ next prayer is in the future → armed(prayer, day, start)
  └─ prayer is due and unrecorded → shielded(prayer, day)
shielded
  ├─ active prayer saved → reconcile to ready, armed, or next shielded prayer
  └─ disabled / Period Mode / authorization lost / invalid state → disabled or suspended, shield cleared
```

The source of truth remains existing SwiftData `PrayerRecord` data. Shared extension state is a compact projection, not a second prayer database.

## Architecture

### 1. Entitlements and targets

Add:

- Family Controls capability to the main app;
- App Group capability, using one registered identifier shared by every target;
- a Device Activity Monitor extension;
- a Shield Configuration extension;
- a Shield Action extension;
- Family Controls entitlement to the main app and each Screen Time API extension as required by Apple’s distribution process.

Submit the Family Controls entitlement request before implementation is considered release-ready. Development signing can validate the APIs, but App Store distribution requires Apple’s approval.

### 2. Shared state

Create `SalahFocusSharedState.swift`, compiled into the app and all three extensions. Store a versioned `Codable` payload in app-group `UserDefaults` containing:

- feature enabled flag;
- encoded `FamilyActivitySelection`;
- active prayer raw value and local day identifier;
- today/yesterday completion identifiers needed for reconciliation;
- Period Mode flag;
- calculation time zone and the next scheduled activity identifier;
- a monotonically increasing revision for stale-callback rejection.

Never store selected app names: the selection contains Apple’s opaque tokens. If decoding fails, authorization is revoked, or tokens become invalid, clear the Muslim 5 store and surface setup as needing repair.

### 3. Main-app coordinator

Create `@MainActor final class SalahFocusService: ObservableObject` alongside `PrayerNotificationService`. It owns:

- `AuthorizationCenter.shared` status;
- a named `ManagedSettingsStore`, for example `ManagedSettingsStore(named: .salahFocus)`;
- `DeviceActivityCenter` scheduling;
- selected activity persistence;
- public state for Settings UI;
- one idempotent `reconcile(now:schedule:records:isPaused:)` entry point.

Reconciliation rules:

1. If disabled, paused, unauthorized, selection-empty, location-missing, or schedule-invalid: stop Muslim 5 monitoring and clear its named store.
2. Find the earliest applicable due and unrecorded prayer, excluding paused days.
3. If one exists: persist it as active and apply shields to the selected application, category, and web-domain tokens.
4. Otherwise: clear the active shield and monitor only the next future unrecorded prayer.
5. Use prayer/day/revision in the activity name so stale extension callbacks cannot reactivate an old shield.

Monitoring only the next relevant prayer avoids Device Activity’s activity-count ceiling. Once a prayer is recorded, Muslim 5 is necessarily foregrounded and can schedule the next one. A physical-device spike must confirm that a nonrepeating monitor reliably invokes the extension after the containing app is terminated.

### 4. Device Activity Monitor extension

At `intervalDidStart`:

1. Decode shared state and validate enabled, not paused, matching activity revision, authorization-compatible state, and nonempty selection.
2. Check the shared completion projection so an early-recorded or stale prayer never relocks apps.
3. Set active prayer/day in shared state.
4. Apply application tokens, category tokens, and web-domain tokens to the same named `ManagedSettingsStore`.

`intervalDidEnd` must not clear the store: the product contract is “until recorded,” not “until the scheduling interval ends.” The main app owns unlocking after a successful record save or explicit disable.

### 5. Shield extensions

- `SalahFocusShieldConfiguration` reads the active prayer from shared state and returns restrained, accessible copy and Muslim 5 branding.
- `SalahFocusShieldAction` closes the attempted app for primary and secondary actions.
- Provide generic fallback copy when shared state is unavailable.
- Do not include prayer history, streak, linked-user data, or location in extension state or shield copy.

### 6. Existing app integration

- `RootTabView.swift`: create and inject `SalahFocusService`; reconcile on launch, foreground, location change, calculation-setting change, time-zone change, and feature configuration change.
- `SettingsView.swift`: add a **Focus** section with a NavigationLink to `SalahFocusSettingsView`; integrate Period Mode enable/disable with immediate suspension/reconciliation.
- `TodayView.swift`: after the existing save succeeds in `toggle`, `setStatus`, and `setAttendance`, publish the record projection and call reconciliation. Do the same after deleting a record. Centralize this in one post-save helper so all mutation paths behave identically.
- `PrayerScheduleService.swift`: reuse existing calculations. Add a helper that returns ordered `(prayer, day, start)` occurrences for yesterday/today/tomorrow so focus and notification scheduling cannot disagree.
- `Muslim5App.swift`: no new SwiftData model is required; register only the service at the root level through `RootTabView`.

## Implementation phases

### Phase 0 — capability spike

- Create minimal development-signed monitor and shield targets on a branch.
- Authorize an individual user on a physical iPhone.
- Shield one selected test app from a nonrepeating `DeviceActivitySchedule` while Muslim 5 is terminated.
- Relaunch Muslim 5 and clear the named store.
- Confirm disable and authorization revocation both recover without reinstalling.

Stop here if background triggering is unreliable or the entitlement request is rejected. Retain the product UI only after the native enforcement path is proven.

### Phase 1 — shared state and coordinator

- Add app-group state, versioning, token persistence, state derivation, named store, and single-next-prayer scheduling.
- Unit-test reconciliation with injected clock, calendar, authorization, scheduler, and shield-store adapters.

### Phase 2 — setup and settings UI

- Add explanation, authorization request, system picker, selected count, master toggle, permission/error recovery, and accessibility labels.
- Keep setup out of onboarding and leave the feature off for existing users.

### Phase 3 — prayer completion integration

- Route all successful record insert/update/delete paths through one post-save hook.
- Add Period Mode suspension and foreground/time-zone/location reconciliation.
- Add the quiet “Apps available again” confirmation.

### Phase 4 — extensions and hardening

- Implement the monitor, configuration, and action extensions.
- Add stale callback protection, corrupt-state fail-open behavior, token invalidation handling, and logging that contains no selected-app identity or prayer history.

## Verification

### Automated

- Disabled never schedules or shields.
- Enabling requires approved authorization and a nonempty selection.
- Before prayer time, only the next uncompleted prayer is monitored.
- At prayer time, the matching callback applies all selected token types.
- A callback with an old revision or completed prayer does nothing and clears stale state.
- Saving completed, late, or made-up records unlocks.
- A failed SwiftData save does not unlock.
- Deleting the active record reapplies the shield when still due.
- Backlogged prayers advance without an unlocked gap.
- Period Mode, master disable, authorization loss, empty selection, corrupted payload, and invalid schedule all clear the named store and stop monitoring.
- Time-zone, coordinate, calculation-method, and Asr-method changes replace the pending trigger.
- Existing notification and prayer-time tests remain green.

### Physical iPhone matrix

Test with the app foregrounded, backgrounded, force-quit, and after device restart:

- each of the five prayer callbacks;
- app, category, and website selections;
- completion, late completion, made-up completion, and record removal;
- enable, disable while shielded, Period Mode, and permission revocation;
- daylight-saving/time-zone travel and a material location change;
- Screen Time already configured by the user;
- VoiceOver, Dynamic Type, Dark Mode, and Reduce Motion;
- incoming calls, emergency access, Settings access, and Muslim 5 access remain available.

The iOS Simulator is useful for unit tests but does not replace enforcement testing on a signed physical device.

## Release gates

- Apple approves Family Controls distribution entitlements for the app and every required extension.
- Phase 0 passes on the minimum supported iOS version and current iOS release.
- App Review metadata plainly says that Salah Focus shields user-selected apps; it must not claim to lock the entire iPhone.
- Privacy documentation states that app selections use opaque on-device Screen Time tokens and are never uploaded.
- Disable, Period Mode, revoked permission, corrupted state, and scheduling failure are verified to fail open.

## Non-goals for MVP

- locking the iPhone Lock Screen or every system app;
- preventing the device owner from disabling Salah Focus;
- parent-controlled or remote unlocking;
- proof that a prayer physically occurred beyond the user’s existing check-in;
- Salah Circle sharing of focus status;
- configurable grace periods, temporary snooze, per-prayer app selections, or per-prayer enable switches;
- Android device administration.

## Apple framework references

- [Family Controls and individual authorization](https://developer.apple.com/documentation/familycontrols)
- [FamilyActivityPicker](https://developer.apple.com/documentation/familycontrols/familyactivitypicker)
- [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore)
- [DeviceActivityMonitor](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor)
- [Managed Settings UI](https://developer.apple.com/documentation/managedsettingsui)
- [App Groups entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups)
