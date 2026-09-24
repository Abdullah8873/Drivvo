# Cloud config (optional)

Copy `cloud.example.json` to `cloud.json` (git-ignored) and fill in the
values, then build/run with:

    flutter run -d chrome --dart-define-from-file=env/cloud.json

Only public values go here: the Supabase project URL, the **publishable** key (or legacy anon key) and
the Google OAuth **client IDs**. Never put the Supabase secret / service-role key or
the Google client secret in this file or anywhere in the app.

Without `cloud.json` the app runs fully offline (login is optional).
