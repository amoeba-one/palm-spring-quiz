# Quiz Night

Host app for condo quiz nights: teams, timed questions, peer marking, jokers, leaderboard.
Quizzes are stored in Supabase; anyone can play, editing needs the family password.

- `index.html` — the whole app (no build). `clips.js` — embedded music clips for the original Palm Spring quiz.
- `supabase/setup.sql` — creates the table, password check and RPC functions. Run once in the SQL editor (set the password first).
- `supabase/seed.sql` — inserts the original quiz.
- Change the password: `update public.app_secret set password = '...';`
