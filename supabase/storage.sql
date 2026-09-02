-- Public-read bucket for music clips. Uploads and deletes go through the `clip` edge function, which checks the password.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('clips', 'clips', true, 26214400, array['audio/mpeg','audio/mp4','audio/x-m4a','audio/aac','audio/wav','audio/ogg','audio/webm','audio/flac'])
  on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "clips public read" on storage.objects;
create policy "clips public read" on storage.objects for select to anon, authenticated using (bucket_id = 'clips');
