# Plans

## Product features

| # | Plan | Status |
|---|---|---|
| 004 | Salah Focus app shield | IMPLEMENTED — DEVICE VERIFICATION PENDING |
| 005 | iCloud backup | IMPLEMENTED — DEVICE/CLOUDKIT VERIFICATION PENDING |
| 006 | Indonesian localization | IMPLEMENTED — NATIVE REVIEW/DEVICE VERIFICATION PENDING |

## Animation improvements

| # | Plan | Severity | Status |
|---|---|---|---|
| 001 | Qibla alignment confirmation | MEDIUM | DONE |
| 002 | Qibla content transition | LOW | DONE |
| 003 | Qibla refresh feedback | LOW | DONE |

Recommended execution order: 001, 002, 003. They touch the same Qibla view but have no behavioral dependencies. Implement all three in one focused diff, then run the test suite once and perform the physical-device feel checks together.
