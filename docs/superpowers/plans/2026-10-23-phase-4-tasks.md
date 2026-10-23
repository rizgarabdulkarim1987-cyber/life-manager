# Phase 4 — Tasks and Reminders (plan)

Spec: `docs/superpowers/specs/2026-10-22-personal-life-manager-design.md` §7, §8.5, §8.6, §11, §14 phase 4.
Branch: `claude/phase-3-vault-d634c0` (continues Phase 3; the owner asked for Phase 4 next, then the APK).
Release: `1.3.0+4`.

## Decisions (builder's calls)

1. **Tables (schema v4):** `tasks` (id, parent_id for subtasks, title, notes, workspace_id, priority `low|normal|high|urgent`, status `todo|doing|done`, due_at UTC, due_all_day, remind_at UTC, recurrence `daily|weekly|monthly|yearly`, recurrence_interval, tags comma text, completed_at, capture_id, meeting_note_id, created_at, updated_at) and `meeting_notes` (id, title, body, workspace_id, created_at, updated_at). Both travel in backups with the rest of the database.
2. **Not in this phase (listed under Next steps):** attachments (don't exist anywhere yet), the original spec's separate *Projects* entity (a workspace plus tags covers it for now), Home dashboard cards (Phase 5).
3. **Recurrence:** completing a recurring task marks it done and creates the next occurrence (due and reminder shifted by the same step, month ends clamped, skipping past occurrences until it is in the future); subtasks are copied as open.
4. **Views:** Inbox (no due date and no workspace), Today, Tomorrow, This week, Upcoming, Overdue, Completed, All, plus a workspace filter, a priority sort and a month Calendar. Pure functions in `domain/task_views.dart`, tested with fixed clocks.
5. **Reminders are native** (no plugin, so nothing Google): `ReminderChannel.kt` keeps scheduled reminders in its own `SharedPreferences`, sets `AlarmManager` alarms (`setExactAndAllowWhileIdle` when `canScheduleExactAlarms()`, else `setAndAllowWhileIdle` and the app shows a warning with a button to the exact-alarm settings), and `ReminderReceiver` posts the notification with actions **Done**, **Snooze** (10 min, 1 h, tomorrow 09:00) and **Open**. A reminder that fires re-notifies every hour until Done or Snooze (spec §11, "persistent until handled"). `BootReceiver` reschedules on `BOOT_COMPLETED`, `TIMEZONE_CHANGED`, `TIME_SET` and `MY_PACKAGE_REPLACED` from the native store, so no Dart is needed after a reboot. Done from the notification is queued natively and applied to the database the next time the app is open (the database is encrypted and only Dart opens it). `POST_NOTIFICATIONS` is asked at runtime the first time a reminder is set.
6. **Resync:** every task change updates its alarm; on app start every open reminder is rescheduled and orphans cancelled.
7. **Share target:** `ACTION_SEND text/plain` on `MainActivity`; the text is stashed natively and taken by Dart on start/resume, then split into action points (lines, bullets, numbering) and sent to Capture Review as several `TaskProposal`s the owner keeps, edits or drops. Nothing is sent online by this step.
8. **Meeting notes:** list and editor (title, text, workspace); "Extract action points" runs the local splitter and the rule parser in task mode and shows proposals to convert with one tap (each can be edited or dropped). Typed or dictated text only (the existing mic sheet can dictate into any text field by keyboard).
9. **Capture:** `TaskProposal` in Capture Review becomes a real card (title, due date, workspace) and saves into `tasks` with the capture id; notes stay "kept for later". The "+" menu's task entry opens the task form.
10. **Privacy:** notification text carries the task title (visible on the lock screen unless the phone hides it). Vault data never appears in tasks, reminders or search.

## Tasks

1. Schema v4 (tables, migration, `drift_schema_v4.json`, generated test schema) + migration test.
2. Domain: recurrence, views, action-point splitter (tests first).
3. `TasksRepository` + `MeetingNotesRepository` (create/update/complete/uncomplete/delete, subtasks, recurrence spawn) with tests.
4. Reminder scheduler port, fake, `TaskReminderSync`, Kotlin side, manifest, permission flow.
5. UI: Tasks screen (views, filters, calendar), task form, task detail, meeting notes, reminders warning; ARB strings in `ar`, `en`, `ckb`.
6. Capture review `TaskCommit`; share intake; "+" menu entries; notification actions intake on resume.
7. Worst-case tests (320 dp, `ckb`, 2× text), `flutter analyze`, full `flutter test`.
8. Release: `1.3.0+4`, PRODUCT.md, INSTALL.md (ar, en), APK, commit, push.

## Next steps (not in this plan)

Attachments, Projects entity, Home dashboard cards and the Reminders screen (Phase 5), Future Projects (Phase 6), on-phone verification of alarms, boot rescheduling, notification actions and the share target.
