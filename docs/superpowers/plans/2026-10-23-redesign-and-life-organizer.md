# Redesign, Privacy and AI Life Organizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Parts A, B and C of the redesign spec as one installable APK: the light look, money masking, face/fingerprint lock, the composer and chat with confirm cards, fast delete and edit, owner-made categories and accounts, auto-split buckets, receipt scanning, tasks, reminders, notes and the AI project planner.

**Architecture:** Riverpod plus Drift, as now. One masked `MoneyText` gates every amount. Capture keeps its pipeline: the parse step stays, but Capture Review is replaced as the default path by a `Conversation` controller that turns proposals into chat replies and cards, and commits through `CaptureCommitter`. New tables (tasks, notes, projects, project steps and messages) arrive in schema v3. Tips, cost tracking and bucket math stay on device.

**Tech Stack:** Flutter 3.47, Dart, Riverpod 3, go_router 18, Drift on SQLCipher, local_auth 3, Groq (chat, Whisper, vision), new: `flutter_local_notifications`, `timezone`, `image_picker`.

**Spec:** `docs/superpowers/specs/2026-10-23-redesign-and-life-organizer-design.md`, which amends `docs/superpowers/specs/2026-10-22-personal-life-manager-design.md`.

## Global Constraints

- Android only, minSdk 26. No Google services, no analytics, free services only.
- Arabic is the default, RTL first. Every new string goes in `app_en.arb`, `app_ar.arb` and `app_ckb.arb`.
- Money is integer minor units, never `double` (§10.2).
- Online AI gets only the owner's text (or photo), plus the names of accounts, categories, workspaces, buckets and projects. It never gets amounts, balances or history. Derived numbers are computed on device.
- Nothing from the AI is saved without an explicit OK.
- No money is visible without a tap: every amount goes through `MoneyText` or `FittedMoney`.
- The light theme is the default. Dark stays selectable.
- The lock relocks after 60 s in the background by default, and Finance re-asks if the last auth was more than 60 s ago.
- Existing data survives the upgrade. Seeded rows that have transactions are kept.
- After code changes run `graphify update .`.

## Review Focus

1. **An amount rendered outside `MoneyText`**, for example chart labels, reports, the debt screens or text interpolation. The expected behavior is masked. *Test:* in Task A1, a widget test pumps Finance, Reports, Debts and Buckets with `revealed=false` and asserts that no digit-bearing money string is found.
2. **A phone with no screen lock, or with face unlock not offered to apps.** The expected behavior is an explanatory screen, not a dead lock screen. *Test:* in Task A3, `FakeBiometric(deviceSupported: false)` shows `no-screen-lock`.
3. **Undo after a chat save that wrote several rows**, or a debt with a principal. The expected behavior is that everything is reverted. *Test:* in Task A5, `undo` removes the transactions and the debt created by one capture.
4. **Upgrade from v2 with real data in seeded categories and accounts.** The expected behavior is that used rows are kept and unused ones removed. *Test:* in Task B1, a migration test from a v2 fixture.
5. **A USD income when no rate exists yet.** The expected behavior is that chat asks for the rate, and bucket allocation never throws `MissingRate`. *Test:* in Task B3.

---

## Part A: look, lock and composer

### Task A1: Money masking

**Files:**
- Create: `lib/core/security/money_privacy.dart`
- Modify: `lib/features/finance/ui/widgets/money_text.dart`, `lib/app/app.dart`, `lib/app/router.dart`
- Test: `test/core/security/money_privacy_test.dart`, `test/ui/masking_test.dart`

**Interfaces:**
- Produces: `final moneyRevealedProvider = NotifierProvider<MoneyReveal, bool>`, with `MoneyReveal.toggle()` and `MoneyReveal.hide()`. Produces `class RevealMoneyButton extends ConsumerWidget` (an eye icon, key `reveal-money`). `MoneyText(..., {bool alwaysShow = false})` and `FittedMoney(..., {bool alwaysShow = false})`. Produces `const kMaskedMoney = '•••••'`.

- [ ] Tests: `MoneyText hides digits by default` (finds `•••••`, finds no `25,000`). `alwaysShow shows the amount`. `toggle reveals, hide re-masks`. `going to background hides` (the lifecycle hide calls `hide()`). `route change hides`: a `NavigatorObserver` on the router calls `hide()` on push and pop, and `StatefulShellRoute` branch changes call it too.
- [ ] Implement: `MoneyText` reads `moneyRevealedProvider` (it becomes a `ConsumerWidget`) and renders `kMaskedMoney` in the muted color when not revealed. The App lifecycle `onHide` calls `hide()`.
- [ ] Add a `masking_test` covering Finance overview, Account detail, Debts, Buckets and Reports (Review Focus 1). Reports chart axis labels must use `MoneyText` or show `kMaskedMoney`.
- [ ] Run `flutter test test/core/security test/ui`, then commit.

### Task A2: Light, minimal theme

**Files:**
- Modify: `lib/core/theme/tokens.dart`, `lib/core/theme/app_theme.dart`, `lib/core/db/tables.dart` (`themeMode` default `'light'`), `lib/core/db/app_database.dart` (v3 migration sets `theme_mode='light'` once)
- Test: `test/core/theme/*`

- [ ] Tests: `default theme is light`, and `v2→v3 migration switches dark to light once`.
- [ ] Tokens: a light palette with a near-white `bg` (`#FAFAF7`), white `surface`, hairline borders, one calm accent (deep blue `#2F5BEA`), softer `textMuted`, `radiusCard` 24. Keep the dark tokens. The theme uses fewer borders, more whitespace, a 16 px gutter, and titles `w600`.
- [ ] Commit.

### Task A3: Face/fingerprint lock without app PIN

**Files:**
- Modify: `lib/features/lock/biometric_authenticator.dart`, `lock_controller.dart`, `lock_screen.dart`, `lib/features/setup/setup_flow.dart`, `lib/features/settings/settings_screen.dart`, `lib/app/app.dart`, `lib/app/router.dart`
- Delete: `lib/features/lock/pin_service.dart`, `lib/features/lock/digits.dart` (if only the PIN uses it), `lib/features/settings/change_pin_screen.dart`, and their tests
- Create: `lib/features/lock/sensitive_gate.dart`
- Test: `test/features/lock/lock_screen_test.dart`, `lock_controller_test.dart`, `sensitive_gate_test.dart`, `test/features/setup/setup_flow_test.dart`

**Interfaces:**
- `BiometricAuthenticator`: `Future<bool> deviceSecure()` (`isDeviceSupported`, true when any screen lock exists) and `Future<bool> authenticate(String reason)` (`biometricOnly: false`, which allows weak and strong biometrics plus the device credential).
- `LockController`: adds a `DateTime? lastAuthAt` field and `bool authFresh(DateTime now, {Duration within = const Duration(seconds: 60)})`, and `unlock()` sets `lastAuthAt`.
- `SensitiveGate({required Widget child})` shows a "tap to unlock" panel and prompts on first build when `!authFresh`.
- `FakeBiometric({bool deviceSupported = true, bool result = true})` replaces the `available:` parameter in `test/helpers/fakes.dart`.

- [ ] Tests: `lock screen prompts automatically and unlocks on success`. `failed prompt shows retry button` (key `unlock-retry`). `no screen lock shows explanation` (key `no-screen-lock`, with a button `open-security-settings` that launches `android.settings.SECURITY_SETTINGS` through a method channel `life_manager/intents`). `setup has no PIN step` (steps: language, then warning). `relock default is 60 s`. `Finance tab asks again after 60 s`.
- [ ] Implement. On startup, delete the stored PIN keys (`SecureStore.delete` for the old PIN service keys). Schema v3 sets `lockTimeoutSeconds` to 60 when it is still the old 300 default, and drops the `biometricEnabled` use (the column stays). Settings: the lock timeout choices are 0 s, 30 s, 1 min, 5 min and 15 min. Remove "Change PIN". Add a one-line note: "If your face unlock isn't offered, your phone doesn't share it with apps".
- [ ] `MainActivity.kt`: add the `life_manager/intents` channel with `openSecuritySettings`.
- [ ] Update `test/helpers/app_harness.dart` (no PinService), then commit.

### Task A4: Fast delete and in-place edit

**Files:**
- Modify: `lib/features/finance/ui/widgets/transaction_list.dart`, `lib/features/finance/ui/transaction_form_screen.dart`
- Create: `lib/features/finance/ui/widgets/undo_snack.dart`
- Test: `test/features/finance/ui/transaction_list_test.dart`, `transaction_form_test.dart`

**Interfaces:**
- `showUndoSnack(BuildContext, {required String message, required Future<void> Function() onUndo})` with `duration: Duration(seconds: 10)`.
- `TransactionSliverList`: long-press enters selection mode; `onSelectionChanged(Set<int>)`; a selection bar with `select-delete` deletes all with one undo.

- [ ] Tests: `swipe deletes with 10 s undo`, `long press selects and bulk deletes, undo restores all`, `edit screen has delete button (tx-delete) with undo`, and `tapping amount on edit screen focuses it` (the edit form opens with fields directly editable and Save shown only when dirty).
- [ ] Implement, then commit.

### Task A5: Conversation controller

**Files:**
- Create: `lib/features/capture/chat/conversation.dart` (models and controller), `lib/features/capture/chat/describe.dart` (proposal to sentence), `lib/features/capture/chat/clarify.dart` (missing field to question)
- Modify: `lib/features/capture/data/capture_committer.dart` (add `undo`)
- Test: `test/features/capture/chat/conversation_test.dart`, `describe_test.dart`, `test/features/capture/data/capture_committer_test.dart`

**Interfaces:**
- `sealed class ChatMessage`: `UserMessage(String text)`, `AssistantMessage(String text, {List<ProposalCard> cards, List<QuickReply> replies})`.
- `class ProposalCard { final int captureId; final int index; final Proposal proposal; CardState state; }`, where `enum CardState { open, accepted, dropped, saved, undone }`.
- `class QuickReply { final String label; final Object value; }`
- `class Conversation extends Notifier<List<ChatMessage>>`, with `conversationProvider`. Methods: `Future<void> send(String text)`, `Future<void> sendVoice(Uint8List wav)`, `Future<void> answer(QuickReply r)`, `Future<void> accept(ProposalCard c)`, `void drop(ProposalCard c)`, `Future<void> undo(int captureId)`, `void clear()`.
- `String describeProposal(Proposal p, Lexicon lex, AppLocalizations l)`, for example ar: «أسجّل 25,000 د.ع مصروف «أكل» من «نقد شخصي». تمام؟».
- `Clarification? nextClarification(Proposal p, Lexicon lex)` returns `Clarification(field, options)`, with `field` one of `account | category | amount | rate | counterparty | direction`.
- `CaptureCommitter.undo(int captureId)` deletes transactions with that `captureId`, the debts created from them, and tasks, notes and projects with that `captureId` (from Part C), then marks the capture `discarded`.

- [ ] Tests: `send adds user bubble then assistant reply with a card`. `missing account asks with account chips, answer fills it`. `accept on the only card commits and shows saved + undo`. `two cards commit together after both decided`. `drop all discards capture`. `undo reverts every row of the capture` (Review Focus 3). `low confidence still shows card with question, not inbox`. `pipeline SavedToInbox (no speech) replies with the inbox reason`.
- [ ] Implement it on the existing `CapturePipeline.fromText` and `fromVoice` and `CaptureRepository` (proposals are read back from `parsedJson`). Income allocation per Task B3, and the rate question per Task B5. Then commit.

### Task A6: Composer and chat sheet

**Files:**
- Create: `lib/features/capture/ui/composer.dart`, `lib/features/capture/ui/chat_sheet.dart`
- Modify: `lib/features/shell/shell_scaffold.dart` (remove the mic FAB, put the composer above the nav), `lib/features/capture/ui/capture_sheet.dart` (keep the recorder logic and expose `HoldToTalk`)
- Test: `test/features/capture/ui/composer_test.dart`, `chat_sheet_test.dart`, `test/features/shell/shell_test.dart`

**Interfaces:**
- `Composer({bool large = false})`: key `composer-field` for the text field, `composer-mic` for the mic (hold to record and release to send; tap toggles hands-free) and `composer-send`. The `composer-camera` button is added in Task B7.
- `openChatSheet(BuildContext)` is a draggable bottom sheet (0.6 to 0.95) that renders `conversationProvider`. Card buttons: `card-ok-<i>`, `card-edit-<i>` (pushes the existing `/capture/:id`), `card-drop-<i>`. Chips: `reply-<i>`. Undo: `undo-<captureId>`.

- [ ] Tests: `composer is on every tab`, `typing and send opens chat with reply`, `hold mic records and release sends`, `tap mic toggles recording`, `nav has Home, Finance, Tasks, Projects`.
- [ ] Commit.

### Task A7: Edit and delete by text

**Files:**
- Modify: `lib/features/capture/domain/proposal.dart`, `intent_validator.dart`, `ai/ai_payload.dart`, `rules/rule_parser.dart`, `rules/keywords.dart`, `data/capture_committer.dart`, `chat/describe.dart`
- Test: the matching test files

**Interfaces:**
- `IntentType.edit` and `IntentType.delete`.
- `class EditProposal extends Proposal { final int? txId; final int? newAmountMinor; final int? newCategoryId; final String? newDescription; }`
- `class DeleteProposal extends Proposal { final int? txId; }`
- Schema: `type` adds `edit|delete`, and a new key `target`: `"last" | "last_expense" | "last_income" | <text>`. The resolver picks the newest transaction matching the target (by type, or by description or category name containing the text).
- `EditCommit(EditProposal)` and `DeleteCommit(DeleteProposal)` in the committer. Undo restores them (it keeps the old row in a `capture_undo` JSON on the capture).

- [ ] Tests: `«احذف آخر مصروف» → DeleteProposal(latest expense id)` (rules), `«غير المبلغ لـ 30 الف» → EditProposal(last, 30000)`, `card names the entry`, `commit deletes, undo restores`.
- [ ] Schema v3 adds `undo_json TEXT NULL` to `captures`. Commit.

### Task A8: New Home

**Files:**
- Modify: `lib/features/shell/home_screen.dart`, `home_cards.dart`, `lib/app/router.dart` (branches: home, finance, tasks, projects)
- Create: `lib/features/shell/tips.dart`
- Test: `test/features/shell/home_test.dart`, `tips_test.dart`

**Interfaces:**
- `Future<List<Tip>> computeTips(AppDatabase db, DateTime now)` → `Tip(kind, args)`, in this priority: overdue tasks, a budget at 80% or more, a project step due within 7 days, Emergency below target, or "all clear". No amounts in args.
- Home order: `Composer(large: true)`, the tip, today's tasks (key `home-today`), recent captures (key `home-recent`, 5 rows, swipe delete with undo, masked amounts), active projects (key `home-projects`).

- [ ] Tests: `home shows no money digits`, `home shows composer large`, `tip picks overdue first`, `recent entry swipe deletes with undo`.
- [ ] Commit.

## Part B: money

### Task B1: No seeded accounts or categories; migration v3

**Files:**
- Modify: `lib/core/db/seed.dart`, `finance_seed.dart`, `app_database.dart`, `lib/features/setup/setup_flow.dart`, `lib/features/capture/domain/lexicon.dart` (Personal is the lowest `sortOrder`), `lib/features/settings/categories_screen.dart` (income and expense tabs, add, rename, delete if unused, keywords)
- Test: `test/core/db/migration_v3_test.dart`, `test/features/setup/setup_flow_test.dart`

**Interfaces:**
- `seedInitialData(db, names)` creates only the Personal workspace and the three buckets.
- The setup step `firstAccount` (keys `setup-account-name`, `setup-account-currency`, `setup-account-save`) is required.
- The migration (`from < 3`): delete categories with a `systemKey` that no transaction or budget references; delete accounts with no transactions, unless that would leave none; delete workspaces other than the lowest `sortOrder` that have no accounts and no transactions; clear `systemKey` on the categories kept (copying the localized name into `name`).

- [ ] Tests (Review Focus 4): `fresh install has no categories and no accounts until setup`, `v2 db with used food category keeps it named, removes unused`, `account with transactions kept`.
- [ ] Commit.

### Task B2: Create a category or account from chat

**Files:**
- Modify: `proposal.dart` (`MoneyProposal.newCategoryName`, `newAccountName`), `intent_validator.dart` (keeps an unmatched name), `chat/clarify.dart`, `chat/conversation.dart`
- Test: `conversation_test.dart`

- [ ] Tests: `unknown category asks «أسوي فئة جديدة …؟», yes creates and fills`, `no accounts at all asks to create one with currency chips`.
- [ ] Commit.

### Task B3: Automatic bucket split

**Files:**
- Modify: `lib/features/capture/data/capture_committer.dart`, `lib/features/finance/data/buckets_repository.dart` (`Map<int,int> splitByPercents(int totalBaseMinor, List<Bucket>)`, with the remainder going to the largest bucket), `lib/features/finance/ui/transaction_form_screen.dart` (allocation is on by default for income, pre-filled)
- Test: `buckets_repository_test.dart`, `capture_committer_test.dart`

- [ ] Tests: `income via chat is auto allocated by percents`, `split sums exactly to total`, `USD income with rate saved first allocates without MissingRate` (Review Focus 5), `percent change affects only later incomes`.
- [ ] Commit.

### Task B4: Finance overview with totals only

**Files:**
- Modify: `lib/features/finance/ui/finance_overview_screen.dart`, `buckets_screen.dart`, `reports_screen.dart` (remove income-by-source)
- Test: `test/features/finance/ui/finance_overview_test.dart`

- [ ] Layout: `RevealMoneyButton` in the app bar; a total balance card (consolidated in the base currency, key `fin-total`); month income and month spending (`fin-month-income`, `fin-month-expense`); three bucket cards (`bucket-<key>`) with progress to target and "set a target"; then links to Accounts, History, Budgets, Debts and Reports; and the `SensitiveGate` wrapper (Task A3).
- [ ] Tests: `no per-account balances on overview`, `bucket cards visible`, `all masked until eye`.
- [ ] Commit.

### Task B5: Today's rate for USD income

**Files:**
- Modify: `chat/clarify.dart`, `conversation.dart`, `transaction_form_screen.dart`, `lib/features/finance/data/rates_repository.dart` (`Future<ExchangeRate?> latest(String base, String quote)`)
- Test: `conversation_test.dart`

- [ ] Tests: `USD income asks rate with last rate as chip, saving stores rate effective today`.
- [ ] Commit.

### Task B6: AI suggests a bucket split

**Files:**
- Create: `lib/features/finance/ai/split_suggester.dart`
- Modify: `buckets_screen.dart` (button `suggest-split`, optional goal text field)
- Test: `test/features/finance/ai/split_suggester_test.dart`

**Interfaces:**
- `Future<Map<String,int>> suggestSplit(GroqClient c, String model, String goal)` returns basis points per `expenses|emergency|investment`. It validates that each is an integer from 0 to 10000 and that they sum to 10000; otherwise it throws `InvalidAiOutput('split')`. The payload is `{goal}` only.

- [ ] Tests: the payload has no amounts, a bad sum is rejected, and applying it updates the editor without saving until Save.
- [ ] Commit.

### Task B7: Receipt scanning

**Files:**
- Modify: `pubspec.yaml` (`image_picker`), `lib/features/capture/ai/groq_client.dart` (`chatJsonWithImage({model, system, user, Uint8List jpeg})` as an OpenAI-style `image_url` data URL), `ai_config.dart` (`AiFeature.receipt`), `lib/core/db/tables.dart` (`groqVisionModel` default `meta-llama/llama-4-scout-17b-16e-instruct`), `capture_tables.dart` (`source` adds `image`, plus an `image` blob), `capture_pipeline.dart` (`fromImage(Uint8List)`), `composer.dart` (`composer-camera`), `ai_settings_screen.dart` (the vision model field)
- Test: `groq_client_test.dart`, `capture_pipeline_test.dart`

- [ ] Tests: `image request carries data url and no lexicon amounts`, `offline keeps image capture in inbox`, `result becomes MoneyProposal card`.
- [ ] Commit.

## Part C: life organizer and projects

### Task C1: Tasks, appointments and notes tables

**Files:**
- Create: `lib/core/db/life_tables.dart`, `lib/features/tasks/data/tasks_repository.dart`, `notes_repository.dart`
- Modify: `app_database.dart` (v3 creates them)
- Test: `test/features/tasks/data/*`

**Interfaces:**
- `Tasks`: `id`, `title`, `notes?`, `kind` (`task|appointment|reminder`), `dueAt?`, `hasTime` bool, `place?`, `priority` (0–2), `status` (`open|done`), `recurrence` (`none|daily|weekly|monthly`), `workspaceId?`, `projectId?`, `projectStepId?`, `captureId?`, `createdAt`, `completedAt?`.
- `Notes`: `id`, `body`, `projectId?`, `captureId?`, `createdAt`, `updatedAt`.
- `TasksRepository`: `add`, `update`, `complete(id)` (a recurring task spawns the next occurrence), `delete` and `restore`, plus `watchView(TaskView v, DateTime now)`, where `enum TaskView { today, upcoming, overdue, inbox, done }`, and `watchMonth(DateTime month)`.

- [ ] Tests for each view boundary (local midnight), recurrence on completion, and that delete and restore round-trips.
- [ ] Commit.

### Task C2: Tasks tab UI

**Files:**
- Create: `lib/features/tasks/ui/tasks_screen.dart` (segments: Today, Upcoming, Overdue, No date, Done, Calendar, Notes), `task_form_screen.dart`, `calendar_view.dart`, `notes_screen.dart`
- Modify: `router.dart`
- Test: `test/features/tasks/ui/*`

- [ ] Rows: a checkbox to complete (with undo), swipe to delete with undo, and tap to edit. The calendar is a month grid with dots and the day's list.
- [ ] Commit.

### Task C3: Reminders and notifications

**Files:**
- Modify: `pubspec.yaml` (`flutter_local_notifications`, `timezone`, `flutter_timezone`), `android/app/src/main/AndroidManifest.xml` (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, and the plugin receivers)
- Create: `lib/features/tasks/reminders/reminder_scheduler.dart`
- Test: `test/features/tasks/reminders/reminder_scheduler_test.dart` (against a fake `NotificationPort`)

**Interfaces:**
- `abstract interface class NotificationPort { Future<void> schedule(int id, String title, DateTime at); Future<void> cancel(int id); Future<bool> ensurePermissions(); }`
- `ReminderScheduler.sync(List<Task> open, DateTime now)` schedules every open task with `dueAt` in the future, plus a 09:00 next-day nudge for each overdue open task, and cancels the rest. It runs on app start, on task change, and on a notification action. The actions are Done and Snooze for 10 min, 1 h, or until tomorrow at 09:00.
- Fallback: when exact alarms are denied, use inexact scheduling and show a banner `exact-alarm-warning` in Tasks.

- [ ] Commit.

### Task C4: Capture life intents

**Files:**
- Modify: `proposal.dart` (`TaskProposal` adds `kind` and `place`; `ProjectIdeaProposal(title, description)`), `intent_validator.dart` (types `reminder|appointment|project_idea`, plus the key `place`), `ai_payload.dart` (adds project names), `rules/rule_parser.dart` («ذكرني», «موعد», «عندي فكرة مشروع»), `capture_committer.dart` (`TaskCommit`, `NoteCommit`, `ProjectCommit`), `chat/describe.dart`
- Test: the matching tests

- [ ] Tests: `«ذكرني باجر الساعة 5 أخابر أحمد» → reminder tomorrow 17:00`, `«موعد طبيب الخميس 10 بالمنصور» → appointment with place`, `note saved`, `project idea opens project after OK`.
- [ ] Commit.

### Task C5: Projects data and planner chat

**Files:**
- Create: `lib/core/db/project_tables.dart`, `lib/features/projects/data/projects_repository.dart`, `lib/features/projects/ai/planner.dart`
- Test: `test/features/projects/*`

**Interfaces:**
- `Projects`: `id`, `title`, `description?`, `status` (`idea|planning|active|done|dropped`), `estCostMinor?`, `currencyCode?`, `targetDate?`, `createdAt`, `updatedAt`, `captureId?`.
- `ProjectSteps`: `id`, `projectId`, `seq`, `phase?`, `title`, `dueDate?`, `done`, `taskId?`.
- `ProjectMessages`: `id`, `projectId`, `role` (`user|assistant`), `body`, `createdAt`.
- Planner reply JSON: `{"reply": str, "question": bool, "plan": null | {"phases":[{"name":str,"steps":[{"title":str,"due":"YYYY-MM-DD|null"}]}], "est_cost": "<decimal>|null", "currency": "IQD|USD|null"}, "step_updates": [{"seq": int, "done": bool}] }`.
- `Planner.reply(Project p, List<ProjectMessage> history, List<ProjectStep> steps) -> PlannerReply`. The payload is the project title, description, chat and step titles only. The system prompt asks one question at a time (goal, budget, deadline, what the owner has, what worries them), then proposes a plan. It never gives investment advice.

- [ ] Tests: `payload has no bucket amounts`, `invalid plan rejected`, `plan saved replaces steps on OK`, `step_updates mark done`.
- [ ] Commit.

### Task C6: Projects UI and cost tracking

**Files:**
- Create: `lib/features/projects/ui/projects_screen.dart`, `project_detail_screen.dart` (plan, steps, progress, the cost card, chat)
- Create: `lib/features/projects/domain/affordability.dart`
- Test: `test/features/projects/*`

**Interfaces:**
- `Affordability computeAffordability({required int costBaseMinor, required int investmentAvailableMinor, required int avgMonthlyAllocationMinor})` → `(remainingMinor, int? months)`, where `months` is null when the average is 0. The average is taken over the last 3 full months of Investment allocations.
- The detail screen: a "Make all steps tasks" button (`steps-to-tasks`), a per-step "make task" action, and a cost card that is masked and wrapped in `SensitiveGate`.

- [ ] Tests: the affordability math (including exact and zero cases), `steps to tasks links taskId`, `completing linked task marks step done`.
- [ ] Commit.

### Task C7: Home cards for tasks and projects

- [ ] Wire `home-today` and `home-projects` (Task A8) to the repositories, and connect the tips to the tasks, budgets, project steps and buckets. Commit.

## Finish

### Task Z1: Verify and build

- [ ] `dart run build_runner build --delete-conflicting-outputs`, then `flutter gen-l10n`, then `flutter analyze` with 0 issues, then `flutter test` all passing.
- [ ] Bump `pubspec.yaml` to `2.0.0+3`.
- [ ] `flutter build apk --release --split-per-abi`, then copy the arm64 APK to `build/LifeManager-2.0.0-arm64.apk`.
- [ ] `graphify update .`, then commit.
