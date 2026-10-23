# Redesign, Privacy and AI Life Organizer — Design

Date: 2026-10-23. Amends the master design (`2026-10-22-personal-life-manager-design.md`). Where the two disagree, this document wins. Section numbers like "§10.3" refer to the master design.

## 1. Intent and the why

The owner used the Phase 2 build and found it hard to use:

- It looks plain, and it has no privacy: opening the app shows all the money right away.
- Unlocking with an app PIN is wrong. It should unlock with face or fingerprint.
- The mic sits alone in the nav bar. **Typing matters more than voice.** The owner wants to write (or say) anything and have the AI sort it out. Without that, the app is a chore.
- The buckets (Investment, Emergency, Expenses) aren't visible enough to be useful.
- Deleting and correcting mistakes takes too many steps.
- Income doesn't need a per-source breakdown, only the total. Income and expense categories, and accounts, must be created by the owner and not seeded.
- The AI should organize the owner's whole life: tasks, reminders, appointments, notes, debts and projects, not only money. For a project, it asks questions, builds a plan, saves the plan, and tracks progress, including how far the Investment bucket is from paying for it.

Success: the owner opens the app with their face, types one sentence, sees what the AI understood, taps "OK", and it's done. Nobody looking over their shoulder sees any money.

## 2. Goals

1. A new look: **light, clean and very simple** (owner's choice), with lots of space and clear type.
2. Privacy by default: no money on Home, and Finance totals hidden until tapped.
3. Unlock with face or fingerprint, falling back to the phone's own screen lock. The app relocks itself, and the sensitive sections ask again.
4. One **composer** (a text box plus a mic) on every main screen. Every domain can be captured through it.
5. A chat-style AI that shows what it understood, asks when something is missing, and saves nothing until the owner confirms.
6. Visible buckets that split each income automatically, with a target per bucket.
7. Fast delete and edit: swipe, inline edit, multi-select, and by typing.
8. Owner-created accounts, categories and income sources.
9. Receipt scanning with the camera.
10. Tasks, reminders, appointments, notes and an AI project planner.

## 3. Non-goals

- Investment advice, meaning which assets to buy. The master design's ban stays.
- Sending balances, history or vault content to the AI (§5).
- Changes to the vault crypto design (§9), backup format (§13) or money math (§10.2).

## 4. Anti-goals (failure even if it "works")

- Money visible on any screen without a deliberate tap.
- The AI saving anything the owner didn't confirm.
- A composer that feels like a form: dropdowns and required fields before you can type.
- A redesign that keeps the old crowded dashboard and just recolors it.
- Losing the owner's existing data in the migration.

## 5. Constraints (owner decisions)

- Android only, free services only, no Google services, and no analytics. All unchanged.
- **Online AI gets only what the owner types or says**, plus a receipt photo when they take one. *(My call, flagged for the owner: the AI also gets the **names** of accounts, categories, workspaces and projects so it can route the sentence. It never gets amounts, balances or history, as in §8.3.)*
- Any number derived from the owner's data (bucket progress, "how long until this project is affordable", daily tips) is computed **on the device**, never by the AI.
- Arabic is the default language, with RTL. Kurdish Sorani and English stay.

## 6. The work, split into three parts (owner's order)

The owner chose this order. Each part ends with a tested, installable APK.

- **Part A: look, lock and composer.** §7–§10.
- **Part B: money.** §11.
- **Part C: life organizer and projects.** §12.

The master design's Phases 3–6 (Vault, Tasks, Home, Future Projects) are re-cut as follows. Part C absorbs Tasks (Phase 4) and Future Projects (Phase 6). The new Home in Part A replaces Phase 5's "layout B". The Vault (Phase 3) comes after Part C and is otherwise unchanged.

## 7. Look (Part A)

- **Light theme is the default**, and the look is minimal. The dark theme stays available in Settings. This reverses §14's "dark default". Tokens are rebuilt for a light, airy palette, keeping one accent color. The exact palette, type scale and spacing are left to the builder, using the `impeccable` skill, and shown to the owner as mockups before they're built.
- Fewer things per screen. No chart on Home. Charts live in Reports.
- Font: Vazirmatn (unchanged).

### 7.1 Navigation

- Bottom nav: **Home · Finance · Tasks · Projects**, plus **Vault** once it exists. The mic leaves the nav bar, because the composer (§9) replaces it.
- Settings and Inbox are in Home's top bar.
- Tabs whose part isn't built yet show a simple "coming soon" screen, as now.

### 7.2 Home

From top to bottom:

1. A **large composer** (§9) with a short prompt, for example "Write or say anything…".
2. **An AI tip:** one or two lines, computed on device by rules (§12.4).
3. **Today's tasks** (from Part C on).
4. **Recent entries:** the last 5 captures, each with quick edit and swipe-to-delete with undo. They show **no amounts**: only the category or title, plus a masked amount.
5. **Active projects** with a progress bar (from Part C on).

**No money appears on Home.** The old balance, month tiles, chart and bucket cards are removed from Home.

## 8. Lock and privacy (Part A)

### 8.1 Unlock

- Unlock uses Android BiometricPrompt and accepts **face or fingerprint**, whichever the phone has enrolled, with the **phone's own screen lock (PIN, pattern or password) as the fallback**.
- **The app PIN is removed.** The setup flow loses its PIN step, the Change PIN screen goes, and the stored PIN hash is deleted on upgrade. This replaces §15's app-lock decision.
- **Face unlock caveat:** on many Android phones, face unlock is a "weak" (Class 2) biometric, or isn't offered to apps at all. The prompt must allow weak biometrics, not only strong ones, so face unlock works wherever the phone allows it. If the owner's phone doesn't offer face unlock to apps, the app shows fingerprint and screen lock only, and Settings explains why in one line. The builder verifies this on the owner's phone.
- If the phone has **no screen lock at all**, the app can't protect itself. It shows a screen that explains this, with a button that opens Android's security settings, and doesn't continue until a screen lock exists.

### 8.2 Relock

- The app locks itself after it has been in the background for **1 minute** (owner's choice; configurable from 0 to 15 minutes).
- **Sensitive sections ask again:** opening the Finance tab or the Vault prompts for face or fingerprint, unless the owner unlocked within the last 60 seconds. *(My call on 60 seconds.)*
- `FLAG_SECURE` stays on.

### 8.3 Money masking

- Finance shows **totals only** (§11.3). **Every amount on screen is masked** (`•••••`) until the owner taps the eye icon in the app bar. One tap reveals that screen. Leaving the screen or the app masks it again.
- Masking covers every money widget, including lists, detail screens, buckets and reports. One shared widget must be used, so nothing slips through.
- Amounts in the composer's proposal cards are shown unmasked, because the owner just typed them.

## 9. Composer: type or speak anything (Part A)

### 9.1 Placement

- A composer bar is pinned **above the bottom nav on every main tab** (Home, Finance, Tasks, Projects): a text box with a mic button beside it. On Home, the same composer is shown large at the top (§7.2).
- **Typing is primary.** Tapping the box opens the keyboard.
- **Mic:** hold to talk and release to send. A single tap starts hands-free recording, and a second tap stops it. *(My call on the tap behavior; the owner chose hold-to-talk.)*
- A camera button for receipts (§11.5) appears in the composer in Part B.

### 9.2 Conversation

- Sending opens a **chat thread** in a bottom sheet. The owner's message appears as a bubble, and the AI replies in plain words (Arabic by default), for example: "I'll record 25,000 IQD for food from your personal cash. OK?"
- Each reply carries one or more **proposal cards**. One sentence can produce several, for example an expense plus a reminder. Each card has **OK**, **Edit** (opens the pre-filled form) and **Drop**. *(This replaces the full-screen Capture Review from §8.1 as the default path. The review form still exists behind "Edit".)*
- **Clarifying questions:** when something required is missing or ambiguous, such as which account, the currency, or the rate for a USD income (§11.2), the AI asks one short question with quick-reply chips. The owner taps a chip or types an answer.
- **Nothing is saved until the owner taps OK.** After saving, the reply says it's done and offers **Undo** for 10 seconds.
- If something can't be understood or is offline, it goes to the Inbox, as now (§8.4).

### 9.3 What it can capture

| Part | Intents |
|---|---|
| A | expense, income, transfer, debt and debt payment, note, **edit** and **delete** of existing entries ("delete the last expense", "change it to 30 thousand") |
| B | receipt (photo), create category, create account |
| C | task, reminder, appointment, project idea, project update |

An intent from a later part that arrives early ("remind me tomorrow…") is saved to the Inbox as a draft, with a line saying the feature is coming.

Edit and delete by text always show a card that names exactly which entry will change, and the owner confirms it.

### 9.4 Offline

The rule parser (§8.3) stays as the fallback for finance intents. Because categories are now owner-created (§11.4), the parser matches on the keywords the owner attached to each category. Offline accuracy will be lower than before, and the owner has been told this by way of this document.

## 10. Delete and edit (Part A)

All of these apply wherever a list of entries appears:

- **Swipe** a row to delete it, with an **Undo** snackbar for 10 seconds. *(Implementation: a soft delete that becomes real after the undo window, or on the next app start.)*
- **Long-press** to enter multi-select, then delete together, with Undo.
- **Transaction details** has a clear delete button, and **each field is editable in place**: tap the amount, category, account, date or note and change it right there, without opening a separate form.
- **By text** through the composer (§9.3).

Deleting a transaction that has bucket allocations also removes those allocations.

## 11. Money (Part B)

### 11.1 Buckets

This replaces §10.3's "manual per income" and "app never suggests numbers" decisions.

- The three buckets (Expenses, Emergency, Investment) are shown **on the Finance screen** as cards, masked (§8.3).
- **Automatic split:** every income is split across the buckets by **fixed percentages** the owner sets. They sum to 100%. Past allocations stay unchanged when the percentages change (unchanged from §10.3).
- **The AI can suggest percentages:** a "Suggest a split" button. Its prompt sends **no amounts**, only the owner's stated goal if they type one. The owner accepts or edits the suggestion.
- **A target per bucket** (for example Emergency: 5,000,000 IQD) with a progress bar.
- The Expenses bucket resets each month. Emergency and Investment carry over (unchanged).
- The Investment bucket is linked to projects (§12.3).

### 11.2 USD income

When an income is in USD, the AI (or the form) asks for **today's exchange rate**, pre-filled with the last rate used. The owner confirms or changes it, and it's stored per §10.2.

### 11.3 Totals only

- The Finance overview shows the **total balance**, **total income this month** and **total spending this month**, plus the bucket cards. It shows no per-source breakdown of income.
- Per-category data is still recorded. Reports can still show spending by category. *(My call: income by source is dropped from Reports too, per the owner's "only the total". Expense by category stays because budgets need it.)*

### 11.4 Owner-created accounts and categories

- **Nothing is seeded:** no income categories, no expense categories, no accounts. This replaces §10.1's seeded accounts and the seeded category list. *(The bucket keys stay, since the three buckets are fixed by the owner's request.)*
- Create them in Settings, or **from the composer**: if a sentence names a category or account that doesn't exist ("received the company salary"), the AI asks "Create a new income category 'Company salary'?" and creates it on OK.
- First run: setup asks the owner to create at least one account (name and currency) before reaching Home.
- Each category has an editable keyword list for the offline parser.
- **Existing installs:** seeded categories and accounts that **have no transactions** are deleted on upgrade. Seeded items that have transactions are kept as ordinary owner items, so no data is lost. Workspaces: Personal stays. The other seeded workspaces follow the same rule.

### 11.5 Receipt scanning

- A camera button in the composer. The photo is sent to an online vision model on Groq's free tier **only when the owner takes it**, behind a one-time consent sheet (§8.7). The model name is configurable, like the other Groq models.
- The result appears as a normal proposal card (amount, date, merchant and suggested category), and the owner confirms it.
- The photo isn't stored unless the owner taps "attach to the transaction". *(My call.)*
- With no network, the photo is kept in the Inbox to finish later.

## 12. Life organizer and projects (Part C)

### 12.1 Tasks, reminders and appointments

Built per §11 of the master design (statuses, priorities, views, recurrence, exact alarms, notification actions, persistent overdue reminders), with all capture going through the composer. An **appointment** is a task with a time and an optional place, shown on the calendar. Notes are free text attached optionally to a project.

### 12.2 Project planner

- Typing "I have an idea for a project…" (or tapping New Project) opens a **project chat**.
- The AI asks short questions one at a time: the goal, budget, deadline, what the owner already has, and what worries them. Then it proposes a **plan**: phases, steps with suggested dates, and an estimated cost.
- The owner edits the plan in chat or directly, then saves it. **The plan is stored** with the project, and the chat history is kept.
- **Plan steps become tasks** with dates, on the owner's OK, per step or all at once.
- **Follow-up:** the app reminds the owner about due steps. When they report progress ("I finished the logo"), the AI marks the step done and, if a date slipped, proposes an updated plan for OK.
- The AI is sent only that project's own text and chat (§5).

### 12.3 Cost tracking against Investment

For each project with an estimated cost, the project screen shows, **computed on device**: the Investment bucket's current amount, what remains to reach the cost, and the estimated months to get there at the recent average monthly allocation. It is masked like other money (§8.3). The AI never sees these numbers. When the owner asks about them in chat, the app inserts the on-device figures into the reply locally.

### 12.4 Home tip

A one- or two-line tip on Home, **generated by on-device rules** (no AI call), for example: an overdue task, a budget at 80%, a project step due this week, or the Emergency bucket below target. It names no amounts. *(My call: keeps §5's "only what I type".)*

## 13. Migration and data safety

- All schema changes come through Drift migrations with tests, from the current schema version.
- The PIN hash is deleted (§8.1). Unused seeded items are removed (§11.4). Nothing that has transactions is deleted.
- Backups made before the upgrade must still restore (§13 of the master design).

## 14. Left to the builder

- The exact palette, type scale, spacing, icons and motion. Mockups go to the owner first.
- Composer and chat widget structure, the sheet versus full-screen decision for the chat, and the animations.
- The LLM prompt and JSON schema extensions for the new intents (edit, delete, create category or account, task, appointment, project), validated as in §8.3.
- The soft-delete mechanism, and how undo is wired.
- The vision model choice on Groq.
- How Part C's chat history is stored.
