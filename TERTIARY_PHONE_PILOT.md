# Tertiary Atlas student and parent phone pilot

Prepared 28 October 2026. Status: ready for recruitment; **no participants or physical-device results yet**. The owner will arrange participants later. Browser-width checks and automated tests are separate evidence.

## Session setup

### Release-fix acceptance pass — prepared 10 November 2026

Status: participant sessions pending. Run these checks only after the tested release is deployed and record the release identifier shown by Sources. Do not describe a browser-width check as a physical-phone pass.

Use Android Chrome and iPhone Safari, at normal and enlarged text sizes. Record device, browser, network, release, result and assistance needed for each task.

| Check | Expected observation |
| --- | --- |
| Open UG and a long-name institution profile | Location/category rows align, text wraps, and website/regulator/save actions have consistent spacing without clipping. |
| Run a programme check with no grades; open related courses | Missing results are requested. An empty alternative list must not say that alternatives meet the academic minimum. |
| Mark English Not taken | No inferred pass. Wording explains that this does not waive a compulsory subject requirement. |
| Use a route allowing Science OR Social Studies, leaving both blank | Missing-subject explanation names both permitted options. |
| Set both permitted alternative cores below the same required grade | Failure explanation names both correction options; changing one to an allowed grade clears only that shortfall. |
| Open an alternative course | The institution filter and programme match the chosen alternative, including where other schools use the same programme title. |
| Berekum national Primary Education baseline: English, Maths, Science, Geography and Economics C6; Government D7 | Three-elective check fails. Add History A1: six counted subjects total 31 and omit Government; college-specific confirmation remains required. |
| Save a fictional choice, close/reopen, then test offline and reconnect | Saved choice persists; offline status and source dates stay visible; updates do not erase the choice. |

Measure first load and grade-result time separately on each physical device, with cold/warm cache and Wi-Fi/mobile data noted. Record actual seconds rather than guessing. Ask the participant to explain the result and next action without prompting. Any false eligibility, lost saved choice, or unreadable primary control blocks pilot sign-off.

No real grades, certificates, index numbers or participant names should be entered in the feedback file. Participants have not yet been recruited; this checklist is preparation only.

### Nursing scenario added 4 November 2026

After the four-college Ministry-policy release is deployed, test Wa, Lawra and Zuarungu Diploma in Registered General Nursing and Nandom Diploma in Registered Midwifery. Use fictional English C6, Core Mathematics C6, Integrated Science C6, Biology C6, Chemistry C6 and Physics C6: aggregate 36 should meet the checked academic minimum for 2026/2027. Change English to D7, E8 and F9 in turn: each must fail. Remove Integrated Science and add Social Studies A1: it must not substitute for the missing required science grade.

Ask the participant to explain the difference between an academic match and admission. They should find the age and interview conditions, identify the Ministry policy year, and recognise that the published 12 June 2026 application deadline is past. The GHS150 voucher price is for the published cycle, not tuition or an invitation to pay. Record whether they mistakenly think applications are open or that an academic match guarantees a place; either misunderstanding needs correction before wider rollout. No physical-device result is claimed until these sessions occur.

Aim for six voluntary sessions: four prospective students and two parents/guardians. Include at least two physical Android phones and two iPhones, one lower-cost Android, and both mobile data and Wi-Fi. Sessions take about 20 minutes. Do not contact or enrol participants automatically.

Explain that this is an independent planning guide, not an admission decision or official application portal. Participants can stop at any time. For a minor, arrange parent/guardian permission and the student's willingness before the session. Use participant codes such as S01/P01. Do not collect names, WAEC index numbers, certificates, actual grades, household income or login credentials in the feedback sheet.

Open https://ghana-tertiary-atlas.ghana-tertiary-atlas-host.workers.dev/ in Safari on iPhone and Chrome on Android. Record phone model, operating system, browser, connection and text size. Ask participants to think aloud; let them attempt the tasks before helping. Use the fictional examples below, or let a participant privately enter results without copying them into the report.

## Tasks and expected observations

| Task | Expected outcome | Record |
| --- | --- | --- |
| Find an institution in the participant's preferred region | Region directory and institution identity are understandable | Success, help needed, time |
| Search UBIDS BSc Planning with no grades | More results needed; no positive eligibility result | Participant's explanation |
| Use fictional case A below | Academic minimum can pass; admission offer and current cutoff are not implied | Can student and parent explain the distinction? |
| Change English to D7 in case A | No academic pass; missing requirement is explained | Accuracy and clarity |
| Use fictional case B below | The diploma's published D7 core allowance is distinct from degree entry | No mixing degree and diploma rules |
| Search UTAS Nursing | Programme conditions and undated cutoff require confirmation | Does user understand what to ask admissions? |
| Find UTAS application cost and closing date | GHS 200 application fee is separate from tuition; published date is 31 October 2026 | Can parent identify what is excluded? |
| Read the UTAS hardship scholarship record | Applications closed; no implied future reopening date | Misinterpretation, if any |
| Save and compare two institutions; create a journey item | Choices persist after closing and reopening | Avoid submitting a real institution application |
| Export a parent report and open it | Readable on the physical device; source dates and uncertainty remain visible | Actual receiving app and result |
| After the app confirms its offline shell is ready, enable airplane mode and reopen | Previously bundled content works; unavailable online updates remain clear | Actual offline result |
| Reconnect, open Sources and check for updates | Published updates load; saved choices remain | Any lost state or confusing messages |
| Increase text size and use VoiceOver/TalkBack for key controls | No clipped critical text; controls and errors are understandable | Device screenshots only with permission and private content removed |

### Fictional case A — UBIDS BSc Planning

English C6, Core Mathematics C6, Integrated Science C6; Geography C6, Economics C6, Government C6. Social Studies may remain blank. These three electives are in the department's category A. No numeric current-year competitive cutoff is inferred. Change only English to D7 for the negative case.

### Fictional case B — UBIDS Diploma in Integrated Urban Planning

English D7, Core Mathematics D7, Integrated Science D7; Geography C6, Economics C6, Accounting C6. The two category A electives plus one B and three elective credits meet the conservatively modelled academic subjects. The same core grades must not pass a degree check. These are test examples, not real student records.

## Feedback and release decision

Use `reports/tertiary-pilot-results-template.csv`. Keep every row as pending until tested on a physical phone. Record actual failures and assistance; do not convert a browser emulation result into a physical-device pass. Ask each participant: What does the result mean? What would you do next? What was hard to find? Would you return to this app, and why?

Any false academic approval, lost saved choices, unusable primary control or private-data exposure blocks a wider release until fixed and retested. Investigate unclear wording and material phone performance problems before expanding the pilot. Summarise completed Android/iPhone sessions separately, including untested device/network combinations. Do not promise measured phone speed until it has been measured on the device.

The 15-minute source monitor detects changes on known URLs. Reviewed requirements and new annual URLs still need review and publication; offline phones update only after reconnecting.


## Atlas Plus preview: additional physical-phone checks (18 November 2026)

Not yet accepted on physical devices. Use synthetic applications and notes only; the preview collects no payments.

1. Install the signed version 8 update. Confirm existing local plans remain available.
2. Create a cloud workspace only after reading its consent. Save the private access code securely; do not put it in a feedback screenshot.
3. Save plans on Android and reconnect in a separate phone browser. Restore and compare programme names, stages, notes, budgets and comparison choices. Confirm grade-checker entries were not uploaded.
4. Make different changes on two devices and verify the stale-save warning. Confirm replacement prompts are understandable and that cancelling leaves local plans intact.
5. Select identically named programmes at different institutions. Share only one with a parent. Confirm the link shows the selected school and excludes notes, budgets and grades.
6. Revoke the family link and reopen it. Delete the cloud workspace; confirm device plans remain. Copies already downloaded or printed cannot be revoked.
7. Import a published calendar reminder into Google Calendar and Apple Calendar. Check date and alert behavior. A pending source must show its warning and offer no calendar export.
8. Prepare a family PDF with grades excluded, then explicitly include grades in a separate test. Review legibility and the Android/iPhone share flow.
9. Check large text, weak connections, offline browsing and returning to the app after an interruption. Cloud sync is manual; existing supported web reminders require separate device permission.

Record device model, OS/browser version, app version, result and any screenshot with access codes and family links removed. Paid billing and store acceptance remain separate.
