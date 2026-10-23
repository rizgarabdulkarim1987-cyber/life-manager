# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter 3.47 / Dart, Android only (minSdk 26), Riverpod, go_router, Drift on SQLCipher. Decided in the approved design: docs/superpowers/specs/2026-10-22-personal-life-manager-design.md.

## Users

One person, the owner. They run a personal life plus two businesses, Buzzify (marketing, design, video, clients) and Related / EO (partners, SMS campaigns, operations). They use the app on their own Android phone, mostly on the move, in a market or a car, or between client meetings. They speak Arabic first, use Kurdish Sorani and English, and mix languages and client names in one sentence.

## Product Purpose

Replace the Excel file kept at home and the phone's notes app for three things:
- **Money:** record a spend or income the moment it happens, by speaking one sentence.
- **Tasks:** capture tasks from everywhere (WhatsApp, meetings, calls, thoughts) before they get lost.
- **Passwords:** keep them in an encrypted vault instead of plaintext notes.

Success: the owner stops using Excel and notes for these. Capture takes seconds, and at month end the charts give the whole picture.

## Positioning

A private, single-owner life manager. Voice-first capture comes with a review step before anything is saved. Money stays separated across Personal, Buzzify and EO cash in IQD and USD. Nothing is shared, synced or sold, and nothing goes to Google.

## Operating Context

- Six cash accounts (Personal / Buzzify / EO, each in IQD and USD) and a manual exchange rate.
- Manual "bucket" allocation (Expenses / Emergency / Investment) per income, as numbers only.
- History imported from the owner's Excel sheet.
- Tasks shared in from WhatsApp; meeting notes turned into tasks.
- Backups are files the owner moves to a laptop, a USB stick or a messenger.
- Phase 2 is done: finance (accounts, transactions, transfers, buckets, budgets, debts, reports, Excel import) and voice or text capture with an offline rule parser, optional Groq online AI (key stored on the phone, carried inside encrypted backups) and on-device Whisper. Captures wait in an Inbox until reviewed.

## Capabilities and Constraints

- No Google services of any kind. Free services only. No analytics. Online AI (Groq) only for capture and planning, with disclosure. The vault never leaves the device.
- Arabic is the default locale, RTL. Kurdish Sorani strings are draft quality until the owner reviews them.
- Dark theme by default, with optional light. Approved home direction: "layout B — full dashboard" with a centred mic button (mockup in .superpowers/brainstorm).
- Built in six phases; Phase 1 is the foundation (setup, lock, settings, backup).

## Brand Commitments

Name: "My Life Manager" / «مدير حياتي». The owner bound these visual constraints in the spec: premium and minimal, midnight black and deep navy, white text, electric-blue accent, rounded cards, good charts, smooth subtle motion.

## Evidence on Hand

No real financial data in the repo. Sample numbers in the mockups are invented and must never ship as data.

## Product Principles

1. Capture in seconds, and always reviewed before it is saved.
2. Nothing is ever lost: drafts, backups, safe restore.
3. Private by default; every byte that leaves the device is disclosed first.
4. Scanability over decoration: the owner glances at this between meetings.
5. Arabic and RTL are first-class, not a translation layer.

## Accessibility & Inclusion

Text contrast at WCAG AA or better in both themes. Large touch targets for one-handed use on the move. Arabic-Indic digits are accepted wherever digits are typed.
