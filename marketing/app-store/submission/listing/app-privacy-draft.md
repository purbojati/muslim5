# App privacy response draft

This is a conservative preparation draft based on the current code and backend. Confirm it against the exact submitted build and production infrastructure before publishing the App Privacy answers.

## Does this app collect data?

**Yes**, when the user opts into Salah Circle. Salah Circle transmits and retains data on the developer-operated Cloudflare Worker and D1 database for app functionality.

Suggested disclosures:

- **Contact Info — Name**: the nickname entered for Salah Circle. Purpose: App Functionality. Linked to the user's Salah Circle profile. Not used for tracking.
- **Identifiers — User ID**: the random Salah Circle user ID and account-level authentication identity. Purpose: App Functionality. Linked to the user's Salah Circle profile. Not used for tracking.
- **Sensitive Info**: completed-prayer name and local calendar date can reveal religious practice. Purpose: App Functionality. Linked to the user's Salah Circle profile. Not used for tracking.
- **Other Data**: random linking code and the relationships between linked Salah Circle profiles. Purpose: App Functionality. Linked to the user's Salah Circle profile. Not used for tracking.

Data that stays on-device does not need to be disclosed as developer collection:

- Precise/coarse location used for prayer times and Qibla
- Compass heading
- Detailed prayer history, timing/attendance status, streaks, and preferences
- Notification and Salah Focus configuration

Prayer history and Period Mode may sync through the user's private iCloud account. Apple states that developers are not responsible for disclosing data collected by Apple itself; confirm that the developer has no CloudKit access or server-side telemetry before relying on that treatment.

No data is used for third-party advertising or cross-app tracking.

## Required URL

A public Privacy Policy URL is required before submission. No privacy policy URL is currently stored in this repository.
