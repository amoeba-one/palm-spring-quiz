// Password-gated upload/delete for the public `clips` bucket.
// POST multipart: pw, path, file  -> {path}
// DELETE json: {pw, path} (one object) or {pw, prefix} (a quiz's folder) -> {ok:true}
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, DELETE, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const SAFE_PATH = /^[0-9a-f-]{36}\/[A-Za-z0-9_.-]{1,80}$/;

async function passwordOk(pw: string) {
  const { error } = await admin.rpc("check_pw", { pw });
  return !error;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    if (req.method === "POST") {
      const form = await req.formData();
      const pw = String(form.get("pw") ?? ""), path = String(form.get("path") ?? ""), file = form.get("file");
      if (!(await passwordOk(pw))) return json({ error: "invalid password" }, 401);
      if (!SAFE_PATH.test(path) || !(file instanceof File)) return json({ error: "bad request" }, 400);
      const { error } = await admin.storage.from("clips").upload(path, file, { contentType: file.type || "audio/mpeg", upsert: true });
      if (error) return json({ error: error.message }, 500);
      return json({ path });
    }
    if (req.method === "DELETE") {
      const { pw, path, prefix } = await req.json();
      if (!(await passwordOk(String(pw ?? "")))) return json({ error: "invalid password" }, 401);
      let paths: string[] = [];
      if (typeof path === "string" && SAFE_PATH.test(path)) paths = [path];
      else if (typeof prefix === "string" && /^[0-9a-f-]{36}$/.test(prefix)) {
        const { data } = await admin.storage.from("clips").list(prefix, { limit: 1000 });
        paths = (data ?? []).map((o) => `${prefix}/${o.name}`);
      } else return json({ error: "bad request" }, 400);
      if (paths.length) { const { error } = await admin.storage.from("clips").remove(paths); if (error) return json({ error: error.message }, 500); }
      return json({ ok: true });
    }
    return json({ error: "method not allowed" }, 405);
  } catch (e) {
    return json({ error: String(e?.message ?? e) }, 500);
  }
});
