# Quiz library: create, list, persist, play

Date: 2026-09-02

## Goal

Turn the single hardcoded Palm Spring quiz into a library of quizzes that anyone
can play and that password holders can create and edit. Quizzes live in a shared
Supabase database so they are the same on every device. The app stays a single `index.html` with no build step, hosted on GitHub Pages.

## Access model

- Anyone with the URL can open the site, see the quiz list, and play any quiz.
- Creating, editing, duplicating and deleting a quiz requires the family
  password. The password is checked inside Postgres, never in the page.
- The browser remembers the password after first successful use. If the server
  rejects it, the stored value is cleared and the prompt reappears.

## Data

One table, `quizzes`:

| column     | type        | notes                                   |
|------------|-------------|-----------------------------------------|
| id         | uuid pk     | default gen_random_uuid()               |
| title      | text        |                                         |
| rounds     | jsonb       | see round shape below                   |
| jokers     | boolean     | whether teams get a joker, default true |
| created_at | timestamptz | default now()                           |
| updated_at | timestamptz | set by save function                    |

`rounds` element shape:
`{name, type: "normal"|"music"|"picture", ptsPerQ, allOrNothing: bool, questions: [[q, a, opts?], ...]}`.
A question is `[text, answer]` or `[text, answer, [optionA, optionB, ...]]` for
multiple choice (2–6 options, lettered A–F on screen). The editor has an
"add multiple choice options" control per question.
"Something or nothing" is a flag orthogonal to type (the old `allornothing`
type is migrated to `type: normal, allOrNothing: true`). When `jokers` is false
the score-entry joker tick box, joker auto-apply and joker copy are hidden.

Timers stay global constants in the page (15 s question, 3 min deliberation,
5 min picture).

Security:
- RLS on. Policy: `select` for `anon`. No insert/update/delete policies.
- A private table `app_secret(password text)` with one row, no policies and no
  grants, so it is unreadable through the API.
- Two `security definer` functions callable by `anon`:
  - `save_quiz(pw text, quiz jsonb) returns quizzes` — upserts by `quiz->>'id'`
    (insert when null or unknown). Raises `invalid password` on mismatch.
  - `delete_quiz(pw text, id uuid) returns void`.
- Password change is `update app_secret set password = '...'`.

Seed: the existing Palm Spring quiz inserted by the setup script with a fixed id
so re-running the script is idempotent.

## Screens

Existing `S.screen` router gains three screens. Navigation state:

- `S.quizId` — the quiz being played. Play screens read `QUIZ.rounds` instead
  of the `ROUNDS` constant, where `QUIZ` is the loaded quiz object.
- Game state stays in localStorage as today, keyed per quiz id, so a refresh
  resumes and switching quizzes does not clobber another game's scores.

1. **library** (new home). Fetches all quizzes (title, id, round count,
   updated_at). Each row: Play, Edit, Duplicate, Delete. Top: New quiz.
   Loading and error states shown inline. Reset quiz button on the play
   screens returns here.
2. **editor**. Title field. Rounds as cards: name, type select, points per
   question, question/answer rows with add, remove, move up/down. Add round,
   remove round, move round. Save button calls `save_quiz`; on success returns
   to library. Unsaved-changes guard on Back (tap-twice, matching the app's
   existing confirm style).
3. **password** prompt. A small modal-style card shown when a write is
   attempted with no stored password or after a rejection.

Play screens (setup, round, scoreEntry, board, rules) are unchanged apart from
reading from `QUIZ` and the topbar showing the quiz title. The Rules screen
text stays as is; it describes the Palm Spring format and is close enough for
most quizzes.

## Music rounds

Clips live in a public-read Supabase Storage bucket `clips`, one object per
question at `<quizId>/<uuid>.<ext>`, and the object path is stored as the
question's fourth element (`[q, a, opts|null, clipPath]`). Uploads and deletes
go through the `clip` edge function, which checks the password via `check_pw`
and then uses the service-role key. Anonymous direct writes to the bucket are
blocked by storage RLS.

Editor: music-round questions get an upload control; chosen files are staged
and uploaded when Save is pressed (so a cancelled edit uploads nothing), then
the quiz row is saved with the new paths. Removed or replaced clips are deleted
after a successful save. Deleting a quiz deletes its folder. Play: the player
uses the public object URL; the "load from files" override remains for
last-minute swaps.

## Supabase client

Loaded via `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2">`.
Project URL and anon key are constants at the top of the script block. The anon
key is public by design; writes are gated by the password function.

## Hosting

GitHub Pages from `main`, root. The repo is public-read so the URL is
shareable. `supabase/setup.sql` in the repo is the single setup script.

## Error handling

- Network or Supabase errors on load: message with a Retry button.
- Save failure: inline error under the Save button; editor state preserved.
- Wrong password: prompt reappears with "Wrong password".

## Testing

Manual, with Playwright smoke where cheap:
- Library lists seeded quiz; Play runs the existing flow end to end.
- New quiz → add round and questions → Save with wrong password fails, with
  correct password succeeds and appears in the list on another browser.
- Edit and Delete round-trip. Refresh mid-game resumes the same quiz.
- Direct REST insert with the anon key is rejected (RLS check).
