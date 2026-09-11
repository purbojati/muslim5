# 007 — App Store screenshots (English)

- **Status**: PLANNED
- **Platform**: iPhone, portrait
- **Localization**: English only for the first release
- **Category**: App Store marketing
- **Deliverable**: five final, upload-ready screenshots plus editable masters and clean in-app captures

## Outcome

Create a five-image App Store story that presents Muslim 5 as a gentle, private companion for staying close to the five daily prayers. Each image should communicate one clear benefit while showing genuine product UI large enough to understand at App Store search-result size.

The sequence should make sense even if someone sees only the first three images:

1. the overall promise and fellow-Muslim provenance;
2. the daily prayer experience;
3. live Qibla guidance;
4. Salah Focus for reducing distractions;
5. private encouragement through Salah Circle.

## Campaign direction

### Core message

**Stay close to salah, one prayer at a time.**

The screenshots should feel calm, sincere, and useful—not gamified, preachy, or generic. The marketing voice should match the app: one Muslim encouraging another Muslim, with worship treated respectfully and progress framed without judgment.

### Visual language

- Use the app's existing palette: deep ink green, parchment, prayer-time gold/orange, Qibla teal, Salah Focus violet, and Salah Circle blue.
- Let each frame borrow the atmosphere of its feature while keeping one shared composition system, typography scale, device treatment, and margin grid.
- Use clean gradients and subtle light rather than stock mosques, crescents, ornamental patterns, or unrelated lifestyle photography. The app UI is the evidence.
- Keep the app capture as the dominant visual—roughly the lower two-thirds to three-quarters of each feature frame—with the headline in a clear band above it. Frame 1 is the exception: its actual Welcome screen becomes the full-bleed background.
- Use one device frame treatment throughout. The Salah Focus frame may be darker, but should not suddenly adopt a different campaign style.
- Use a small **Muslim 5** wordmark only if it improves recognition; do not repeat the app icon or name so prominently that it competes with the benefit headline.
- Include at least one clearly dark experience. Screenshot 4 naturally satisfies this through the Salah Focus shield.

### Copy rules

- Headline: no more than two lines and ideally four to seven words.
- Supporting line: one short sentence, no more than two lines.
- Lead with the benefit, not the feature name, unless the name itself expresses the benefit.
- Avoid unverifiable claims such as “never miss a prayer,” “improve your iman,” or “the most accurate prayer app.”
- Use **Built by a fellow Muslim** because it is true and already reflected in the product. Do not use **Recommended by**, review stars, press logos, or community-size claims unless a real attributable source, permission, and evidence are available before export.
- Keep Islamic phrases inside the actual product UI where they already belong. Do not add decorative religious copy merely to make a marketing frame feel spiritual.

## The five screenshots

### 1. Welcome — the general brand promise

**Eyebrow:** `BUILT BY A FELLOW MUSLIM`

**Headline:** `Stay close to salah`

**Supporting line:** `A private, gentle companion for all five daily prayers.`

**In-app screen/background:** Welcome

**Capture state:**

- Use the shipping Welcome screen and its mountain artwork as the full-bleed background rather than placing it inside a separate device mockup.
- Preserve enough of the **Muslim 5** brand mark and atmospheric scene to make the image unmistakably part of the app.
- Keep the Welcome screen's existing headline, highlights, and **Begin** button only when they do not compete with the App Store overlay. Use a carefully cropped state or subtle scrim rather than deleting genuine UI elements in post-production.
- Place the eyebrow and campaign headline in the quietest part of the sky with a restrained dark gradient behind the text for legibility.
- The overall impression should be general and trust-building: who made the app, what it is for, and how it feels. Do not lead with a particular feature or metric.

**Visual treatment:** full-bleed Welcome artwork with minimal marketing typography. No stock photography, review badge, star rating, or extra device frame. This is the main asset and should read cleanly as a single thumbnail.

### 2. Today — the core daily rhythm

**Headline:** `Keep all five prayers close`

**Supporting line:** `Prayer times and a gentle way to record each salah.`

**In-app screen:** Today

**Capture state:**

- English UI with a fixed, non-personal demo location.
- Use the daylight or golden-hour scene so the screen feels inviting and clearly shows the app's prayer-time atmosphere.
- Show an active prayer phase and countdown, with two earlier prayers completed and the current/next prayers still visible.
- Keep **Your five daily prayers** and enough prayer rows on screen to make the tap-to-record interaction obvious.
- Do not show setup cards, permission errors, Period Mode, or backend errors.

**Visual treatment:** warm sky-to-parchment gradient with the phone rising from the bottom. The phone UI should be larger than in the remaining feature frames because this screen explains the app's primary interaction.

### 3. Qibla — useful wherever the user is

**Headline:** `Find the Qibla with confidence`

**Supporting line:** `Live guidance points you in the right direction.`

**In-app screen:** Qibla

**Capture state:**

- Use a fixed public demo location such as Jakarta; never use a team member's live location.
- Show the aligned state: **You’re facing the Qibla, Alhamdulillah**.
- Display a stable, internally consistent bearing, cardinal direction, compass heading, and city label generated by the real Qibla logic.
- No low-accuracy, denied-location, loading, or compass-unavailable warnings.

**Visual treatment:** deep teal-to-night gradient that echoes the Qibla feature color. Give the compass enough scale that its direction is understandable in search results.

### 4. Salah Focus — the distinctive feature

**Headline:** `Make space for salah`

**Supporting line:** `Optional Screen Time shields pause distractions at prayer time.`

**In-app screen:** final Salah Focus shield, preferably the real system shield on a physical iPhone

**Capture state:**

- Use Dhuhr or Asr for a warm gold-on-dark shield.
- Show the prayer name, the short hadith reminder, the explanation, and the primary action to return to Muslim 5.
- Ensure the shield is configured by the shipping extension and accurately represents what users receive.
- Use the in-app shield preview only for early layout drafts. The final image should use a physical-device capture unless the system prevents an App Store-compliant export.

**Visual treatment:** deep violet/near-black campaign background with a subtle warm halo behind the device. This provides the dark-mode contrast Apple recommends while keeping the feature authentic.

### 5. Salah Circle — quiet shared encouragement

**Headline:** `Pray together, even when apart`

**Supporting line:** `Private check-ins for the people closest to you.`

**In-app screen:** Salah Circle introduction or a populated linked-circle state

**Capture state:**

- Prefer the introduction screen if it cleanly shows the Maghrib example card, family initials, and privacy explanation in one view.
- Use clearly fictional sample names/initials already intended for product demonstrations.
- Show a completed prayer and linked initials, but no messages, rankings, profile photos, or location data—the screenshot should reinforce the feature's intentionally quiet design.
- Keep the private linking code off-screen, or use an unmistakably invalid placeholder if a code must appear.

**Visual treatment:** blue-to-twilight gradient with three subtle overlapping circles or initials as a supporting motif. Do not imply a social feed that the product does not provide.

## Screenshot-state support

Add a Debug-only screenshot mode so the five states can be reproduced without editing product screenshots by hand.

- Create a dedicated **App Store Screenshots** scheme or documented launch-argument set.
- Gate all fixtures with `#if DEBUG`; no screenshot seed controls or demo identities should ship in Release.
- Fix the language to English, region/time format, current date/time, location, prayer scene, heading, records, tracking pauses, Salah Circle state, and iCloud status where relevant.
- Extend the existing `SALAH_PREVIEW_SCENE` support rather than introducing a second mechanism for Today's background.
- Seed records into an isolated temporary/in-memory store so normal developer or user data is never touched.
- Add deterministic providers for location/heading and a sample Sharing service. Preserve the production prayer calculation and Qibla calculation wherever possible.
- Provide one launch preset per screenshot: `welcome`, `today`, `qibla`, `focus`, and `circle`.
- Hide debug banners and development-only server warnings from the capture configuration.

The fixtures may control reachable states, but the captured interface must remain the shipping interface. Do not fabricate controls, results, or capabilities in the marketing composition.

## Capture and composition workflow

### 1. Capture clean source UI

- Capture portrait on the available iPhone 17 Pro Max simulator for screenshots 1, 2, 3, and 5.
- Capture screenshot 4 from a physical iPhone if using the real Screen Time shield.
- Use English UI, consistent region/time settings, 100% text size, Light Mode for screenshots 1–3 and 5, and the natural dark shield for screenshot 4.
- Standardize the status bar: 9:41, full signal/Wi-Fi, and a healthy battery when the capture method permits. Remove call, hotspot, screen-recording, and location-use indicators.
- Capture PNG with no transparency and keep an untouched source copy for each screen.
- Verify there is no personal location, nickname, linking code, notification, account name, or real prayer history.

### 2. Build one reusable marketing template

- Design the master at an Apple-accepted 6.9-inch portrait size. Use **1290 × 2796 px** for the iPhone 17 Pro Max set, and verify the exported files against App Store Connect before upload.
- Establish consistent safe margins, headline baseline, support-copy width, device scale, corner treatment, and shadow across all five frames.
- Recommended starting grid: 96 px side margins, 120 px top safe area, 92–104 px headline size, and 42–48 px supporting copy. Adjust after checking real thumbnails rather than treating these as fixed UI tokens.
- Keep all editable text and background layers separate from the raw captures.
- Export flattened RGB PNG files with no alpha channel.

### 3. Naming and storage

Store the eventual assets predictably:

```text
marketing/app-store/
  sources/en-US/iphone-6.9/
    01-welcome-raw.png
    02-today-raw.png
    03-qibla-raw.png
    04-focus-raw.png
    05-circle-raw.png
  final/en-US/iphone-6.9/
    01-stay-close-to-salah.png
    02-keep-five-prayers-close.png
    03-find-the-qibla.png
    04-make-space-for-salah.png
    05-pray-together.png
```

Keep the editable template next to the sources or link it from a short README so the set can be localized later without recreating the visual system.

## Review checklist

### Product accuracy

- Every image shows a feature available in the submitted build.
- The first image uses the real Welcome screen and makes no unattributed recommendation or popularity claim.
- Prayer times, Qibla direction, date, location, and completion states agree with one another.
- Salah Focus is clearly optional and the shield matches actual system behavior.
- Salah Circle does not suggest chat, rankings, live presence, or broader data sharing.
- No marketing sentence promises a religious outcome or guaranteed behavior.

### Visual quality

- The first three images remain understandable when shown side by side at small search-result size.
- Every headline is readable without zooming and no headline wraps to more than two lines.
- App UI is large enough to inspect; decorative areas do not overpower it. The full-bleed Welcome artwork in frame 1 still reads as real app UI.
- The device frame, scale, top alignment, and typography are consistent across the set.
- Dark and light frames feel like one campaign.
- Screenshots contain no accidental clipping, scroll indicators, debug UI, cursor, or simulator chrome.

### Technical compliance

- Exactly five English screenshots, consistently portrait.
- Final dimensions are accepted for the 6.9-inch iPhone display class.
- Files are PNG, JPEG, or JPG; exported PNGs have no alpha/transparency.
- The set is uploaded in the planned order.
- No iPad set is required because the current project targets iPhone only (`TARGETED_DEVICE_FAMILY = 1`).
- Check App Store Connect Media Manager after upload to confirm automatic scaling produces acceptable smaller-device previews.

## Release gates

- Product/copy review approves all five English headline and supporting-line pairs.
- The five deterministic states can be recreated from a clean checkout without personal data.
- Final artwork passes a thumbnail review, full-resolution review, and App Store Connect validation.
- Screenshot 4 is verified against the real physical-device shield before publication.
- Final files, raw captures, editable master, fonts, and a short recreation README are archived together.

## Later localization

Indonesian screenshots are intentionally outside this first deliverable. Preserve extra vertical room in the headline band and keep text layers editable so Indonesian copy can be introduced without shrinking typography or rebuilding the compositions.

## Apple references

- [Creating Your Product Page](https://developer.apple.com/app-store/product-page/)
- [App Store asset best practices and resources](https://developer.apple.com/app-store/asset-best-practices/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
