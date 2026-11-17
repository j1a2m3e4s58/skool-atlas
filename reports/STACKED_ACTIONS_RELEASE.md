# Stacked mobile actions — 17 November 2026

Mobile action groups now use full-width stacked buttons, 15px labels, comfortable padding and 12px gaps. Filled primary actions keep rounded corners; outlined secondary actions use a pill shape. The shared control covers the home page, institution panels, grade checks, pathway results, journey actions and update tools. Admin dialog actions also stack on phones. Wide desktop action groups retain their responsive arrangement.

Web preview deployed to https://ghana-tertiary-atlas.ghana-tertiary-atlas-host.workers.dev/ with Cloudflare version 1682b922-9b00-4b99-ac95-c4a747301bcf.

Validation: 131 server tests passed; Flutter analysis and 463 Flutter tests passed with two existing skips. The layout tests cover 320px, 390px, desktop and enlarged text. Live Chrome phone checks passed after scrolling both buttons fully into view: equal widths, vertical separation, 52px visible heights, pathway navigation, logo long press and stacked password-only login actions. Initial checks encountered a viewport-clipping assertion and a page-load timeout; the corrected scroll and completed live checks are recorded in reports/admin-browser/stacked-mobile-results.json.

Android testing release: version 6, source commit 56ea817461fbdc78f9c7d97a290f3140dc3b9c8f, build 44093290428. Native test run 44093537903 passed upgrade installation over version 5, Android 16 online/offline launch and grade-page opening. Local APK/AAB hashes, owner signing certificate, application identity, version and bundled 599-rule admissions pack were verified. Physical-phone testing is separate.

Installer: release/tertiary-android-stacked-v6/artifacts/tertiary-atlas-testing.apk. Install over the existing app. Password-only administration remains enabled; the private temporary password was verified without publishing any content.
