# 006 — Indonesian localization

- **Status**: IMPLEMENTED — NATIVE REVIEW/PHYSICAL-DEVICE VERIFICATION PENDING
- **Platform**: iOS 17+
- **Category**: Localization and product voice
- **Estimated scope**: main app, location permission copy, prayer notifications, Salah Focus shield extension, accessibility copy, localization tests, and native-speaker review

## Outcome

Make Muslim 5 feel as though it was written in Indonesia by one Muslim speaking gently to another Muslim. Indonesian must be a complete product experience, not a literal English layer: navigation, prayer names, encouragement, errors, dates, notifications, accessibility labels, permission copy, and the Salah Focus shield should all use the same natural voice.

The first release will follow the iPhone's app language. Users can choose Indonesian through iOS's per-app language setting; an in-app language picker is not required. English remains the development language and fallback.

## Voice and translation principles

- Write natural Indonesian first, then check that it preserves the English intent. Do not preserve English sentence structure when an Indonesian Muslim would phrase the thought differently.
- Sound like a supportive fellow Muslim: warm, calm, hopeful, and respectful. Use **kita** selectively when shared perspective feels natural, and **kamu** sparingly; prefer direct sentences that do not over-address the user.
- Keep missed prayers factual and compassionate. Never shame, imply that a streak measures iman, declare whether worship is accepted, or invent religious rulings.
- Keep encouragement grounded: `Semoga Allah mudahkan`, `Alhamdulillah`, and `insyaAllah` are appropriate where the original already carries spiritual encouragement. Do not sprinkle religious phrases into functional or error copy merely for flavor.
- Use familiar Indonesian Muslim vocabulary rather than Arabic transliteration for its own sake. Preserve Arabic-derived words that are genuinely natural in Indonesia.
- Keep technical and privacy explanations plain. Translate the meaning of Apple features, but retain official product names such as **iCloud**, **Screen Time**, and **Pengaturan iPhone** where that aids recognition.
- Treat hadith text with extra care. Use a verified Indonesian rendering of the cited meaning, keep the citation, and have a knowledgeable Indonesian Muslim review it before release. Do not improvise or broaden its claim.
- Preserve the current gentle, non-competitive product philosophy in Salah Circle, streak, missed-prayer, and Mode Haid copy.

### House glossary

| Product meaning | Indonesian | Notes |
|---|---|---|
| prayer / salah | salat | Use standard Indonesian spelling in sentences. |
| Fajr | Subuh | UI display only; persisted/API value stays `fajr`. |
| Dhuhr | Zuhur | UI display only; persisted/API value stays `dhuhr`. |
| Asr | Asar | UI display only; persisted/API value stays `asr`. |
| Maghrib | Magrib | UI display only; persisted/API value stays `maghrib`. |
| Isha | Isya | UI display only; persisted/API value stays `isha`. |
| Qibla | Kiblat | Use **arah kiblat** where the sentence needs clarity. |
| congregation | Berjamaah | Avoid uncommon transliteration in the Indonesian UI. |
| individual | Sendiri | Prefer natural language over a formal fiqh label. |
| streak | rentetan | In explanatory copy, prefer `hari berturut-turut` when clearer. |
| Period Mode | Mode Haid | Gentle supporting copy must explain that tracking is paused without implying a ruling beyond the feature. |
| Salah Focus | Salah Focus | Keep the feature name; translate all supporting copy. |
| Salah Circle | Salah Circle | Keep the feature name; translate all supporting copy. |
| MashaAllah / inshaAllah | MasyaAllah / insyaAllah | Apply consistently in Indonesian copy. |
| completed | Selesai | Use `Sudah salat` when that is more natural in an action or status. |
| completed late | Salat agak terlambat | Keep the distinction from prayer after its time. |
| prayed after time | Dikerjakan setelah waktunya | Avoid introducing `qada` as a blanket label. |

The glossary is a product style guide, not a word-replacement table. Context wins when the fixed term would make a sentence stiff or ambiguous.

### Contextual examples

| English intent | Indonesian direction | Why |
|---|---|---|
| `Missed a check-in?` | `Lupa mencatat?` | Describes the actual action; avoids importing “check-in.” |
| `Ready when you are` | `Kalau sudah salat, tandai di sini` | Gives a warm, useful cue instead of a literal idiom. |
| `One prayer left. May Allah make it easy.` | `Tinggal satu salat lagi. Semoga Allah mudahkan.` | Natural fellow-Muslim encouragement. |
| `Every salah is a fresh chance to return to Allah.` | `Setiap waktu salat adalah kesempatan baru untuk kembali mendekat kepada Allah.` | Preserves the spiritual intent in natural Indonesian. |
| `Stay close to salah, a little more every day.` | `Mari jaga salat kita, sedikit demi sedikit setiap hari.` | Reads like locally authored onboarding copy. |
| `Your pause is protected` | `Jeda ini tidak mengurangi progresmu` | Explains the product behavior without an awkward metaphor. |

These examples establish tone; final strings still require an in-context pass on the device.

## Localization architecture

### 1. Add string catalogs for every runtime bundle

- Add `Localizable.xcstrings` to the main `Muslim5` target with `en` and `id` localizations.
- Add `InfoPlist.xcstrings` for the main target so the location permission prompt is Indonesian when the app is Indonesian.
- Add a separate `Localizable.xcstrings` to `SalahFocusShieldConfiguration`. The shield is an extension with its own bundle and cannot assume the main app's catalog is available.
- Add Indonesian to the Xcode project's known regions while keeping English as `developmentRegion` and the fallback.
- Keep extension display names stable unless App Store/device testing shows them to users; if they are visible, localize them with the corresponding target's InfoPlist catalog.

Use stable, semantic keys for authored copy and add translator comments describing screen, state, and intent. Comments are especially important for short labels such as `On`, `Late`, `Clear`, `Ready`, and `Paused`.

### 2. Separate data identity from localized presentation

- Keep raw values, record identifiers, `UserDefaults` keys, notification identifiers, App Group payloads, API fields, link codes, and analytics/debug values language-neutral.
- Make `Prayer.name`, `PrayerStatus`, `PrayerAttendance`, `PrayerPhase`, reflections, settings state labels, and user-facing `LocalizedError` descriptions resolve through localized presentation resources.
- In `SalahFocusRequirement`, keep `prayerRawValue` as the shared value and derive the localized prayer name inside whichever bundle renders it. Never store `Subuh` or `Fajr` in shared state.
- Keep backend prayer values (`fajr`, `dhuhr`, `asr`, `maghrib`, `isha`) unchanged so Indonesian support does not require a data migration or API change.
- Do not localize user content such as nicknames, city names returned by Core Location, or generated link codes.

### 3. Convert every user-facing string path

Cover all of these surfaces, not only literal `Text` values:

- Welcome, Today, Journey/Insights, Qibla, Salah Circle, Salah Focus, Settings, Prayer Times, Mode Haid, launch recovery, alerts, dialogs, menus, buttons, section labels, and empty/loading/error states.
- Dynamic model/service text: prayer states, encouragement and reflection cards, countdowns, iCloud state/detail strings, location state, Salah Focus errors, Sharing errors, and share-sheet message text.
- Accessibility labels and hints, including Qibla guidance, prayer rows, linked-person counts, onboarding steps, and preview descriptions.
- Local notifications for all five prayer times.
- The system Screen Time shield title, subtitle, and both buttons.

Static SwiftUI parameters that are currently typed as `String` should accept `LocalizedStringResource` where possible. Runtime-generated text should use explicit localized formatting instead of relying on `Text` to discover localization after interpolation.

### 4. Handle grammar, counts, dates, and time correctly

- Use String Catalog substitutions and plural variations for day counts, linked-person counts, hours/minutes, completed-prayer counts, and similar dynamic phrases. Do not construct Indonesian sentences by concatenating translated fragments.
- Replace the hard-coded English weekday initials in the Journey grid with locale-aware narrow weekday symbols.
- Localize the hand-maintained Hijri month names for Indonesian: Muharam, Safar, Rabiulawal, Rabiulakhir, Jumadilawal, Jumadilakhir, Rajab, Syakban, Ramadan, Syawal, Zulkaidah, and Zulhijah. Keep the existing Umm al-Qura date behavior.
- Continue respecting the user's 12/24-hour preference and calendar/time-zone behavior through Foundation format styles. Apply the active locale explicitly wherever a service returns a `String` outside a SwiftUI environment.
- Make Qibla compass directions and turn instructions whole localized messages, including `kiri`/`kanan`, degree values, and cardinal abbreviations.

### 5. Localize notifications and server failures safely

- Build prayer notification title/body from the active app locale at scheduling time.
- Track the locale used for scheduled notifications and reschedule pending prayer reminders when the app language changes, so old English notifications do not linger after switching to Indonesian.
- Decode Salah Circle API error `code` values and map known codes to localized client messages. Do not show the backend's English `message` directly in Indonesian UI; use a localized generic fallback for unknown codes.
- Keep developer-only configuration and entitlement diagnostics precise. They should still be localized if they can reach a release UI, but must not be softened until the corrective action becomes unclear.

## Content workflow

1. Export a complete English inventory from the String Catalogs and group it by user journey rather than translating alphabetically.
2. Draft Indonesian in this order: core prayer loop; onboarding; Journey/Insights; Qibla; Mode Haid; Salah Focus; Salah Circle; Settings/iCloud; errors, permissions, notifications, and accessibility.
3. Review each journey in context on an Indonesian simulator. Rewrite strings that are technically accurate but sound translated, preachy, overly formal, or too long.
4. Run a terminology pass against the house glossary and a religious-sensitivity pass across encouragement, missed-prayer reflections, the hadith, and Mode Haid.
5. Have at least one fluent Indonesian Muslim review the full product voice. Include an Indonesian Muslim woman in the Mode Haid review.
6. Freeze the approved catalog for the release candidate and require translator comments for newly added English strings going forward.

## Verification

### Automated checks

- Add localization tests for all prayer names, status/attendance labels, prayer phases, countdown variants, Journey/Today messages, iCloud states, known API errors, and notification content in both `en` and `id`.
- Assert that persisted raw values and generated record/API identifiers do not change under an Indonesian locale.
- Assert that every user-facing English catalog entry has an Indonesian translation and no entry is left in a `needs_review` or stale state for release.
- Add tests for zero/one/many dynamic values even though Indonesian does not inflect plurals like English; this protects interpolation order and meaning.
- Build and test the main app and all three Salah Focus extensions after adding localized resources.

### Device and simulator checks

- Run the entire first-use and daily prayer flow in Indonesian: onboarding, location prompt, prayer completion/status/attendance, historical edit, day navigation, Journey, and Insights.
- Check Qibla guidance while turning left/right, low-accuracy and denied-location states, compass accessibility, and localized cardinal labels.
- Check Salah Circle setup, link/share/unlink, deletion confirmation, empty state, backend failures, and long Indonesian nicknames.
- Check Mode Haid enable/active/disable behavior and every related explanation for discretion, clarity, and warmth.
- On a physical device, verify Screen Time authorization, Salah Focus onboarding, an active shield for every prayer name, and both shield actions.
- Schedule all five notifications in Indonesian, switch the app between English and Indonesian, and verify pending notifications are regenerated in the new language.
- Test VoiceOver in Indonesian and confirm labels communicate status rather than merely reading visible fragments.
- Test the smallest supported iPhone and Accessibility text sizes for truncation. Indonesian text will often be longer than English; allow wrapping before shortening meaningful copy.
- Confirm English behavior and layout remain unchanged when English is selected.

## Release gates

- No English remains in the Indonesian experience except approved brands, user-provided data, Apple product names, and unavoidable system text.
- All five prayer names and every Salah Focus shield use the Indonesian glossary while raw storage/API identifiers remain backward compatible.
- Hadith wording and all spiritually sensitive encouragement have Indonesian Muslim review approval.
- Mode Haid has been reviewed in context by an Indonesian Muslim woman.
- Notifications, accessibility, permission prompts, server-error fallbacks, and extension UI pass alongside the visible app screens.
- App Store Connect includes complete Indonesian metadata, screenshots, privacy text, and release notes before Indonesian is advertised as supported.

## Non-goals

- Translating backend routes, database values, log messages, or persisted identifiers.
- Adding a custom in-app language picker in the first release.
- Changing prayer-time calculations, Islamic calendar behavior, or jurisprudential guidance.
- Translating personal nicknames, place names, or other user/generated content.

## Implementation result

- Added complete English/Indonesian String Catalogs for the main app and the Salah Focus shield extension, plus localized location-permission copy.
- Localized 373 main-app strings and 12 shield strings with Indonesian prayer names and a contextual, fellow-Muslim voice.
- Kept persisted prayer raw values, record identifiers, notification identifiers, App Group state, and API values language-neutral and backward compatible.
- Localized dynamic prayer phases, countdowns, reflections, errors, share text, accessibility labels, Qibla guidance, Hijri months, weekday labels, notifications, iCloud state, and Mode Haid copy.
- Changed Salah Circle failures to map backend error codes to localized client messages instead of exposing English server messages.
- Added regression tests for translation completeness, Indonesian prayer names, contextual notification copy, and identifier stability.
- Verified the full automated test suite and visually checked the Indonesian welcome and Today screens on an iPhone 17 simulator.
- Still required before release: native Indonesian Muslim copy sign-off, review of Mode Haid by an Indonesian Muslim woman, and physical-device verification of notification delivery, VoiceOver, permission prompts, and every Salah Focus shield state.
