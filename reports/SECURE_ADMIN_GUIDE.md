# Tertiary Atlas owner administration

Open the top-left logo with a long press, or visit https://ghana-tertiary-atlas.ghana-tertiary-atlas-host.workers.dev/admin.

Initial credentials are stored separately in E:\Atlas-Admin-Keys\START-HERE.txt. Never commit, upload or share that folder. Sign in using only the owner password; no email is requested. The first sign-in requires a new password. Subsequent password changes require the current password and invalidate every session. There is no public registration or email-reset service.

## Editing and publishing

1. Edit home text, announcements and support email, institution display details, or an existing programme's admissions requirements.
2. Save a private draft. Drafts do not change the public feed.
3. Review Preview & publish, enter a publication note, and confirm publication.
4. Use History & undo to restore an earlier version. Restoration creates a new publication; up to 20 entries are retained.

Admissions edits remain pending unless the owner explicitly checks the evidence confirmation. Changing an already reviewed record clears that confirmation. Verified publication also requires the official monitored source to be unchanged and checked within 24 hours. A later source change still quarantines the rule. Review dates are preserved for unchanged evidence and undo. This does not automatically approve annual changes.

Published content reaches online clients when their normal feed refresh completes. Offline clients retain their last cached data. Older installed APKs must first install the release with site-content support.

## Scope and safeguards

Editable: homepage labels and introduction; announcement; support email; school name, location and category; programme title, explanations, aggregate ceiling, compulsory and counted cores, existing elective routes and groups, grade limits, additional conditions and review evidence.

Protected: programme/institution identifiers, official source URLs, accreditation assignments, curriculum equivalences and calculation code. This release does not include image uploads, new programme creation, scholarship/fee/deadline editors or arbitrary layout editing. These require separately validated editors.

Private administration requires an online connection. Long press is an entry shortcut, not the security control. The server enforces owner authentication, eight-hour secure cookie sessions, same-origin requests, CSRF checks, attempt limits, draft version checks and publication validation. Passwords use salted PBKDF2 plus a separate Worker-secret HMAC pepper. Account and session records are never in public feeds or the APK.

Keep Cloudflare owner access and the password manager recovery method secure. A forgotten owner password currently requires an operator-assisted server recovery; no self-service recovery is implemented. Changing the pepper without an account recovery plan prevents password verification. Do not delete the owner-admin Durable Object storage. Keep the bootstrap secret private even after setup; the setup endpoint refuses a second owner.

## Tests

2026-11-17: 131 Node server tests passed; 463 Flutter tests passed, two existing skips; Flutter analysis passed in verified Linux build 44087693004, commit 7672ece80f1d7011b2e2110b5780f803107c6df3. Isolated real Chrome checks cover setup, mandatory password change, wrong old password, re-login, private drafts, preview, publication, pending admissions editing, read-only record viewing, undo, mobile overflow and browser errors. Production writes during verification are limited to owner account setup, login and logout; no demonstration content was published.


## Mobile layout update

Home Explore institutions and Find my pathway actions have equal widths and stay horizontal on phones. Paired actions in institution details, grade checking, pathway results, journey management, reminders, update reviews and offline tools use the same wrapping-label layout. The owner login and change-password dialog buttons have equal widths and heights. Widget tests cover 320px, 390px and desktop layouts, plus enlarged text. The secure admin route bypasses offline caching.

Cloudflare release: 15161bf3-1afa-4e94-a88a-f899a76a6efb. Published content remains unchanged; the admin owner account is configured and requires its first password change.

Native verification: signed Android version 5, build 44087824588, emulator run 44087914086. Upgrade from version 4, Android 16 online/offline launch, bundled catalogue, grade-page opening, owner-signature and 16KB native alignment checks passed. The 320px native screenshot also shows the home buttons side by side. Physical Android/iPhone testing and interactive native grade-entry testing remain separate.

Live Chrome phone checks passed at 320px and 390px: aligned equal-width home buttons, pathway navigation, touch long press to owner login, equal-width centred login actions, and no page errors.
