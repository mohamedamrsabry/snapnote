# SnapNote — Official Project Requirements

Transcribed from `Mobile_Intern_Graduation_Projects.xlsx` (provided by the mentor/program) so it's readable without opening Excel. This is the source of truth for grading — `CLAUDE.md` should stay consistent with this, not the other way around.

## Program overview

Mobile Internship Graduation Projects — 6 teams total. Difficulty: Medium. Platform: choose one (Android/Kotlin, iOS/Swift, or Flutter) — SnapNote uses Flutter. Req 1–6 = core (must ship), Req 7–8 = stretch (only attempted if core is fully done).

**Team 5**: Mohamed Amr Sabry & Tya Magued — *SnapNote - Notes with Photos & Voice*. Main skills practiced: camera, audio recording, file storage, search.

**Goal**: A rich notes app where a note can contain text, photos and voice memos.

## SnapNote-specific requirements (Req 1–8)

| # | Priority | Requirement |
|---|----------|-------------|
| 1 | Core | Create a note containing text, photos and voice memos |
| 2 | Core | Capture a photo in-app or pick one from the gallery |
| 3 | Core | Record, play and delete a voice memo with a duration display |
| 4 | Core | Attachments saved into app storage, not just a URI reference |
| 5 | Core | Search across note titles and body text |
| 6 | Core | Tags or folders with filtering |
| 7 | Stretch | Pin a note to the top; swipe to delete with Undo |
| 8 | Stretch | Share a note as text plus images |

**Technical Challenge (the "medium" part)**: File and media lifecycle — recording audio with correct permissions, saving attachments into app-private storage, **cleaning up orphan files when a note is deleted**, and keeping large images from blowing up memory.

**Suggested tools**: CameraX / AVFoundation / `image_picker` — MediaRecorder + MediaPlayer / AVAudioRecorder — Room / Core Data — Coil / Kingfisher.

**Definition of Done**: Create a note with 3 photos and a 30-second voice memo, restart the app, play it back. **Delete the note — its files are removed from storage.**

**Optional Bonus**: Speech-to-text to turn a voice memo into note text.

## Current status vs. these requirements (updated as work lands — check CLAUDE.md's "What's built" for the authoritative live status)

- Req 1 (create note with text/photos/voice) — done.
- Req 2 (capture/pick photo) — done.
- Req 3 (record/play/delete voice memo + duration) — done.
- Req 4 (attachments in app storage) — done (photos and voice memos are copied into `getApplicationDocumentsDirectory()`).
- Req 5 (search titles/body) — done.
- Req 6 (tags/folders + filtering) — not started.
- Req 7 (pin + swipe-delete with undo) — not started (`isPinned` field exists but unused).
- Req 8 (share note as text + images) — not started.
- **Technical Challenge — file cleanup**: done. `NoteRepositoryImpl.deleteNote`/`deleteNotes` now delete the note's photo/voice-memo files from disk before removing the DB row(s), matching the Definition of Done ("Delete the note — its files are removed from storage").
- **Technical Challenge — memory safety**: still open. No image downsizing/caching exists yet (`Image.file` used directly at full resolution) — the "keeping large images from blowing up memory" half of the Technical Challenge is unaddressed.

## Shared requirements — apply to all 6 teams (grading weight in parentheses, see Grading Sheet below)

1. **Architecture** — MVVM or MVI with three clear layers (UI/domain/data) and dependency injection. No API/DB call written directly inside a screen file.
2. **State management** — one source of truth per screen. Config changes and process death don't lose user state.
3. **Git** — GitHub repo, feature branches, PRs reviewed by the teammate, meaningful commits. Both members commit every week. *(Checked at Checkpoint 1 — an unbalanced pair is fixable in week 3, not at the end.)*
4. **UI states** — every data-loading screen handles loading/empty/error/success. Errors offer a retry.
5. **Permissions** — any runtime permission has a rationale screen + a working "permanently denied → Settings" path.
6. **Stability** — no crash during the demo. Handles no internet, empty API response, invalid input.
7. **Testing** — at least 3 unit tests (ViewModel/repository logic) + 1 UI test, all passing.
8. **README** — what the app does, how to run it, API key setup, architecture diagram, 4–5 screenshots, known limitations.
9. **Build** — a signed APK (or TestFlight/installable build) the mentor can run.
10. **Demo** — 15-minute live demo + 10 minutes of code Q&A. Both members present, must be able to explain any part of the code.

**Out of scope for every project**: no real payments, no real user data, no custom backend built from scratch. Free public APIs, Firebase free tier, sandbox services, or local mock data are all fine. SnapNote deliberately uses local SQLite for this reason.

## Timeline — 11 Aug to 31 Aug 2026 (same for all teams)

> ⚠️ **This spreadsheet's dates are now stale — the program moved the deadline up.** The spreadsheet itself says core requirements (Req 1–6) ship by 6 Sep, with 30 Aug as just a feature-freeze/code-review checkpoint. Mohamed confirmed directly (2026-08-27) that the program has since **moved the real deadline up to 30 Aug/31 Aug** — everything should be done by 30 Aug, not 6 Sep. **`CLAUDE.md`'s "Hard delivery deadline: 30 Aug 2026" is correct and current; treat the 6 Sep date below as superseded.** Keeping the original table as-is for reference, since the week-by-week breakdown is still useful even though the final date shifted earlier.

| Week | Dates | Focus | Deliverable at end of week | Mentor Checkpoint |
|------|-------|-------|------------------------------|---------------------|
| 1 | 11–16 Aug | Setup, architecture & first screens | Platform chosen, repo created, wireframes done, API keys working, requirements split, navigation between all screens, data models + repository interfaces in place | Kickoff (Tue 11 Aug) + Checkpoint 1 (Sun 16 Aug) |
| 2 | 17–23 Aug | Core requirements 1–3 | Main list/flow works end-to-end with real data. Detail screen started | Checkpoint 2 — mid demo + Git contribution check |
| 3 | 24–28 Aug | Core requirements 4–6 + technical challenge | All 6 core requirements working, technical challenge implemented and demonstrable | Checkpoint 3 — code review (**feature freeze Sun 30 Aug**) |
| 4 | 29 Aug – (6 Sep) | Polish, testing & delivery | Loading/empty/error states, permission flows, validation, 3 unit tests + 1 UI test passing, README with screenshots, signed release build, slides. Stretch requirements only if core is done | Final demo & grading — first week of September |

## Grading rubric — 100 points total

| Criterion | What it means | Max points |
|-----------|----------------|------------|
| Core requirements (Req 1–6) | All six implemented and working | 25 |
| Technical challenge | The project-specific challenge solved properly, not faked or worked around | 15 |
| Code quality & architecture | Clean layering, readable naming, DI, no duplicated logic | 18 |
| UI/UX & states | Consistent design, all four screen states, sensible permission/error flows | 12 |
| Stability | No crash in demo; handles offline, empty data, invalid input | 8 |
| Testing | 3 unit tests + 1 UI test, meaningful and passing | 7 |
| Teamwork & Git | Both members contributed throughout, can explain the whole codebase | 5 |
| Documentation & demo | Complete README with screenshots, clear presentation | 5 |
| Stretch requirements (Req 7–8) | Only counted if all six core requirements are finished first | 5 |
| **Total** | | **100** |
