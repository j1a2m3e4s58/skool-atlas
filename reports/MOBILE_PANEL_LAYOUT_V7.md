# Mobile panel layout - Android version 7

Released 17 November 2026.

## Changes
- Removed fixed 220px Sources cards and 225px Journey comparison selectors. The shared responsive panel grid fills phone content width and uses columns only when space permits.
- Sources regional cards have consistent padding, text hierarchy and spacing. All 16 regions remain present.
- Home region cards stack on phones. Sources, grades, Journey, guidance and new-curriculum panels stretch to the available width.
- Long programme comparison names wrap naturally. Phone actions remain stacked at full width. The bottom navigation uses Schools to avoid narrow-screen label wrapping.
- Admissions requirements and pending verification status are unchanged.

## Verification
- Web source commit: 7b508701290c15b1aaf96c5c2a613660618c24f4.
- Web CI 44105106422: analysis clean; 463 tests passed, 2 existing skips.
- Android CI 44105109705: signed version 7 built successfully.
- Emulator CI 44107587100: Android 16 upgrade from version 6, online/offline launch, grade page and Sources regional panels passed.
- Local artifact verification passed package/version, owner signature, hashes and non-debuggable checks.
- Hosted browser audit passed all five main tabs, an institution profile and all eight Journey sections, without horizontal document overflow or page errors. Sources checked at 320px and 390px; all 16 region labels present.
- Additional populated comparison test passed long UG/KNUST programme labels and selection persistence. The isolated browser fixture was restored afterward. The test locator was corrected to distinguish section chips from programme checkboxes; no application change was needed.
- Sources, institution profile, Journey, populated comparison and Android Sources screenshots were visually reviewed.
- Physical Android/iPhone testing is separate and remains pending.

## Publication
- Cloudflare version: 7d324d46-634c-400c-9e3d-c70341c388fa.
- Hosted bundle hashes match the tested build. Public admissions data remains 599 rules, and unauthenticated admin workspace access remains blocked.
- APK: release/tertiary-android-mobile-panels-v7/artifacts/tertiary-atlas-testing.apk.
- Evidence: reports/mobile-panels-v7-browser and reports/mobile-panels-v7-emulator.
