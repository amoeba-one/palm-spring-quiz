# Quiz Night

Host app for condo quiz nights: teams, timed questions, peer marking, jokers, leaderboard.
Quizzes are stored in Supabase; anyone can play, editing needs the family password.

- `index.html` — the whole app (no build).
- `supabase/setup.sql` — creates the table, password check and RPC functions. Run once in the SQL editor (set the password first).
- `supabase/seed.sql` — inserts the original quiz.
- `supabase/storage.sql` — creates the public `clips` bucket for music rounds.
- `supabase/functions/clip` — edge function that checks the password before uploading or deleting clips. Deploy with `supabase functions deploy clip --project-ref <ref>`.
- Change the password: `update public.app_secret set password = '...';`
