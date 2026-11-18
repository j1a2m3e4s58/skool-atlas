# Atlas Plus preview - 18 November 2026

## Delivered
- A mobile-first Atlas Plus section in My journey, with full-width controls, consistent cream/green/gold styling and clear feature cards.
- Optional cloud workspace for application plans, notes, budgets and comparisons. Grades, admissions rules and private access credentials are excluded from snapshots.
- Explicit consent before cloud creation. The random private access code is held only in the current session; users must keep their own secure copy. No email delivery or password recovery is claimed.
- Manual cross-device save/restore, with explicit replacement confirmation and optimistic revision checks. Concurrent stale saves cannot overwrite a newer cloud copy. Restore preserves admissions resources and rolls back in-memory changes if local persistence fails.
- Sharing choices and opportunity notices identify the institution. A browser scenario with identical programme titles at UG and KNUST confirmed that only the selected institution was shared.
- Family sharing requires separate consent and selection of one to six cloud applications. Shares include programme, institution, stage and target date only. The read-only snapshot expires after seven days; issuing a new link replaces the previous link. Owners can revoke the link or delete the cloud workspace.
- Family link secrets are carried in URL fragments, removed from the displayed URL and used in authorization headers. The family page uses text-only data insertion, no third-party scripts, restrictive CSP and no-store/no-referrer headers. Following a different sharing fragment refreshes the page content.
- Personalised upcoming published resources for saved institutions, visibly dated with intake/source dates. Closed entries are excluded; unknown dates remain unconfirmed. Changed or unavailable sources are visibly pending, their old dates are hidden, and reminder export is paused. Calendar downloads require import; imported dates do not update automatically.
- The existing consent-controlled family PDF report is available from Plus and remains free. Existing reports, grade suggestions and explanations remain free. No advertisements or payment collection were added.
- Privacy notice updated in-app and on the website. Access-controlled cloud storage is explicitly described as not end-to-end encrypted. Device copies and already-downloaded family reports are not erased by cloud deletion.

## Verification
- Web source: 8c8dd3d0a826957d15ce81ac54a4aca3c1ed33b5.
- Web build 44218894032: clean Flutter analysis; 472 tests passed, 2 existing skips.
- Backend: 44 relevant tests passed across Plus, Plus routes, owner admin, hosting, reminders and source monitoring. Covers ownership, consent, expiry, revocation, deletion, stale-write conflicts, malformed snapshots, origin checks and release gating.
- Built-app browser test passed with isolated local backend objects and two independent device profiles: create, save, permissioned share, reconnect, restore, revoke and delete while preserving device plans.
- The same flow passed against the live Cloudflare deployment using synthetic records, which were deleted afterward. No personal applicant data or actual grades were used.
- Family browser screenshots at 320px and 390px reviewed; Plus overview reviewed at 390px. Flutter layout tests include Atlas Plus at 320px, 390px and desktop width.
- A targeted future pending-deadline browser fixture verified the warning, hidden old date and unavailable calendar export. The same pending-source label was verified for the real UG scholarship on the final live app.
- Live bundle hashes, unchanged 599-rule admissions pack, pending Central IT status and protected owner admin checked.
- Cloudflare version: 5cce7df3-e488-42a9-971e-e5cdb593ed4b.
- Backend/publication commit: 19e4f0e7011f3b2fba5fd91cb8497220b351ed1d.
- Evidence: reports/atlas-plus-preview/browser-result.json and live-browser-result.json.

## Paid launch remains separate
This is a free feature preview, not an activated paid subscription. Google Play Billing products, server-side purchase verification, restore purchases, pricing and entitlement enforcement must be configured and tested before charging. Store privacy/data-safety declarations must reflect optional cloud storage. A public web account-deletion flow and physical-device pilot should be completed before store submission. Native background opportunity notifications and automatic merging/background sync are not claimed; current cloud synchronization is manual and reminder delivery uses existing supported browser reminders or calendar import.

## Android
Version 8 build 44218897045 includes the final pending-source correction. An earlier build hit a dependency-repository HTTP 429; superseded builds were cancelled so only the final source can be delivered. The downloaded APK and AAB passed provenance hashes, owner certificate checks, package/version checks, non-debuggable status and the unchanged reviewed admissions pack. Emulator workflow 44219138913 passed: version 7 to 8 installation, Android 16 online/offline startup, grade page, Sources panels and Atlas Plus view. The native Plus screenshot was visually reviewed. Physical-phone acceptance remains pending.

APK: release/tertiary-android-plus-v8/artifacts/tertiary-atlas-testing.apk.

## Publishing environment
The packaging helper failed its pinned integrity check before execution. It was replaced from the official npm package, checked against package SHA-512 and the pinned executable SHA-256, and only then used for the successful deployment. Flutter builds/tests ran in checksum-verified Linux CI, not the local Windows SDK.

Final signed APK size: 93,372,066 bytes. Local verification: release/tertiary-android-plus-v8/artifacts/local-verification.json.
