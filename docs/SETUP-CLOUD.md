# Cloud setup checklist (owner)

These steps connect MotoLog to your own Supabase project (login, backup,
sync). They involve accounts and keys, so **you** do them; Claude never
handles secrets. Login stays optional: without these steps the app keeps
working fully offline.

Keys you will meet:

| Key | Where it goes | Safe to share? |
|---|---|---|
| Supabase project URL | `env/cloud.json` | yes (public) |
| Supabase **publishable** key (`sb_publishable_…`, or legacy "anon") | `env/cloud.json` | yes (public, protected by row-level security) |
| Supabase **secret** / service-role key | **nowhere** — never copy it | **NO** |
| Google OAuth **client IDs** | `env/cloud.json` + Supabase dashboard | yes (public) |
| Google OAuth **client secret** | only the Supabase dashboard (Google provider) | **NO** |

`env/cloud.json` is git-ignored — it never reaches GitHub.

## 1. Create the Supabase project (≈5 min)
1. https://supabase.com → sign in → **New project**. Name `motolog`, a strong
   database password (save it in your password manager), region
   **South Asia (Mumbai)** or **Southeast Asia (Singapore)**. Free plan is fine.
2. When it's ready: **Project Settings → API Keys** → copy the
   **publishable** key. **Project Settings → Data API** (or API) → copy the
   **Project URL**.
3. In the repo: copy `env/cloud.example.json` to `env/cloud.json` and paste
   the URL and publishable key. Leave the Google lines empty for now.

## 2. Create the database tables (≈2 min)
**SQL Editor → New query**, then paste each file's full contents and **Run**,
in this order:
1. `supabase/migrations/20260924000001_sync_tables.sql` (the 9 synced tables,
   row-level security, last-write-wins trigger)
2. `supabase/migrations/20260924000002_account.sql` (profiles table +
   "delete my account" function)
3. `supabase/migrations/20260925000001_attachments_checklists.sql` (app
   schema v4: `attachments`, `checklist_forms`, `checklist_form_items`,
   `checklists`, `checklist_answers`, plus the private Storage bucket
   `attachments` with owner-only policies). **Must be run before a v4 app
   build syncs** — without it the sync fails on the new tables and photos
   can't upload.

Check: **Table Editor** shows `vehicles`, `catalog_items`, `refuelings`,
`refueling_fuels`, `entries`, `entry_items`, `routes`, `readings`,
`reminders`, `profiles`, `checklist_forms`, `checklist_form_items`,
`checklists`, `checklist_answers`, `attachments` — each with the **RLS
enabled** badge — and **Storage** shows a private `attachments` bucket (10 MB
limit). Every file is safe to run again if something failed halfway.

## 3. Email login with links (≈2 min)
1. **Authentication → Sign In / Providers → Email**: enabled; keep
   **Confirm email** on.
2. Nothing else to do here — the app now uses Supabase's *default* email
   templates, which already send a clickable link (editing templates needs
   custom SMTP, which we're not setting up).
3. **Authentication → URL Configuration**: Site URL `http://localhost:8085`;
   add Redirect URLs `http://localhost:8085` and `http://localhost:8086`
   (also needed for Google sign-in on the web; add your real web address
   later). The app sends this same origin back as the link's redirect, so
   whichever port you ran on is where the link returns you.
4. Note: Supabase's built-in email sender allows only a few emails per hour —
   fine for testing. For real use, add your own SMTP later
   (Authentication → Emails → SMTP).

## 4. Google sign-in — web (≈10 min, optional for now)
1. https://console.cloud.google.com → new project `MotoLog`.
2. **APIs & Services → OAuth consent screen**: External, app name MotoLog,
   your email as support/developer contact; add yourself as a **test user**.
3. **Credentials → Create credentials → OAuth client ID → Web application**:
   - Authorized JavaScript origins: `http://localhost:8085`
   - Authorized redirect URI: `https://<your-project-ref>.supabase.co/auth/v1/callback`
     (Supabase shows this exact URL on the Google provider page)
4. Copy the **Client ID** and **Client secret** → Supabase
   **Authentication → Sign In / Providers → Google**: enable, paste both, save.
   The secret goes **only** here.
5. Put the same **Client ID** in `env/cloud.json` as `GOOGLE_WEB_CLIENT_ID`.

## 5. Google sign-in — Android (later, after Android Studio setup)
1. Finish the Android Studio first-run wizard (installs the Android SDK).
2. Get the debug SHA-1: `cd android` then `./gradlew signingReport`.
3. Google Cloud → **Create OAuth client ID → Android**: package name
   `com.abdullah8873.motolog`, the SHA-1 from step 2.
4. Put its Client ID in `env/cloud.json` as `GOOGLE_ANDROID_CLIENT_ID`.
   (Android sign-in sends the **web** client ID to Supabase, so nothing else
   changes there. If Android sign-in ever fails with a "nonce" error, turn on
   **Skip nonce checks** on the Supabase Google provider.)

## 6. Run it
```bash
flutter run -d chrome --web-port 8085 --dart-define-from-file=env/cloud.json
```
More → My account → create an account (you'll get a confirmation link by
email — open it on this same browser tab/device), then More → Synchronize
data → Sync now.

**Then tell Claude "cloud is set up"** — it will run the end-to-end checks
(sign-up, sync between two browsers, conflict, delete account) and fix
anything the real server reveals. Nothing so far has run against a real
Supabase project.
