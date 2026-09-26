# Working on MotoLog from a Claude cloud session

A cloud session is a fresh Linux machine with a clone of this repo. It does
**not** have the owner's PC: no Flutter at `C:\dev\flutter`, no
`env/cloud.json`, no `.claude/launch.json`, no Claude memory files, no
BlueStacks/Drivvo, no owner's Chrome. Everything it needs is in this file,
`docs/STATUS.md`, `CLAUDE.md`, `docs/SPEC.md`, `docs/PLAN.md` and
`docs/SHARING.md`.

## 1. Setup (once per session)

```bash
bash tool/cloud_setup.sh
```

This installs Flutter **3.47.5** (the same version as the owner's PC) into
`~/flutter`, runs `flutter pub get` and writes `env/cloud.json` if the
environment variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are set.
Drift's generated code (`lib/core/db/app_database.g.dart`) is committed, so
`build_runner` is only needed after you change tables.

Then check the baseline: `dart format lib test` (0 changed), `flutter analyze`
(no issues), `flutter test --timeout 45s -r expanded > test-output.txt`
(**513 passing** on `develop` at `c05c02f`, ~1.5 min). If sqlite fails to load
in tests, install it with `sudo apt-get install -y libsqlite3-dev`.

Commands from `CLAUDE.md` work the same on Linux; ignore the Windows path.
The web preview server used on the PC was:

```bash
flutter run -d web-server --release --web-port 8085 --web-hostname localhost --dart-define-from-file=env/cloud.json
```

## 2. What to work on

Read `docs/STATUS.md` → **PAUSED** section first. Cloud-session work
(code only) — **the sharing batch only** (owner wants the app complete
today; the PC session's helper agents are doing everything else in
parallel, so don't touch those items):
- Sharing: users, access profiles, profile editor, invite banner,
  Transfer. Design decided in `docs/SHARING.md`, Drivvo screens in
  `docs/SPEC.md`, permission model in `lib/core/calc/access_profile.dart`.
  New SQL goes in `supabase/migrations/` marked "to apply" in STATUS.md
  (the PC session applies it via Chrome).
- Branch `feature/sharing`; merge into `develop` when format/analyze/test
  pass (pull `develop` first — the PC session merges other work there
  today). Scope decisions: English only, no web deploy.

Being done on the PC today (not cloud): `navigator.storage.persist()`,
Android email deep link, About/Contact/Share app, Reports share as
image/PDF, part number on service items, CSV import, APK + emulators.

Browser QA, BlueStacks/Drivvo checks, Supabase dashboard and Android
builds stay with the owner's PC session, which can run at the same time:
push a branch per chunk and list in STATUS.md what needs hands-on QA.

What a cloud session **can** do: write code + tests, merge, push, test SQL
on a throwaway local Postgres (`bash tool/sql_test.sh`, see
`docs/SECURITY.md`), build web
(`flutter build web --release`, `--wasm`), run the benchmark
(`flutter test --run-skipped -t perf test/perf -r expanded > perf.txt`).

What it **can't** do (leave for a session on the owner's PC, and list it in
STATUS.md "Needs the owner"):
- Compare with real Drivvo (BlueStacks) — rely on `docs/SPEC.md`, which was
  verified hands-on; if something isn't there, don't guess: note it.
- Hands-on browser QA, unless the cloud session has a browser tool.
- Supabase dashboard work (applying SQL) — done via the owner's Chrome.
  New SQL goes in `supabase/migrations/` (idempotent, RLS owner-only) and
  is marked "to apply" in STATUS.md.
- Email-link sign-in: Supabase redirects to `http://localhost:8085` on the
  owner's PC.
- Android/Windows builds.

## 3. Facts that live only in Claude's memory on the owner's PC

- **Owner:** Abdullah, a web developer (JS/TS/React) learning mobile.
  Explain Flutter in web terms (widget ≈ component, go_router ≈ React
  Router, Riverpod ≈ React Query/Context, drift ≈ Prisma/Drizzle).
- **Repo:** github.com/Abdullah8873/Drivvo — `main` (releases), `develop`
  (integration), `feature/*`. Git email must stay the GitHub noreply
  `213306697+Abdullah8873@users.noreply.github.com` (GitHub blocks the
  private one): `git config user.email` before the first commit. CI is parked
  in `.github/workflows-disabled/` — don't re-enable unless asked.
- **Supabase:** project `motolog`, ref `ibizgqnhurgvhyclfqza`
  (ap-northeast-2). Migrations in `supabase/migrations/` are all applied.
  Auth uses **email links, not 6-digit codes** (owner decision — don't
  suggest SMTP/templates/codes). Site URL `http://localhost:8085`, redirect
  URLs 8085 + 8086.
- **Old worktree branches** (27, e.g. `feature/history`, `fix/logic`) are
  all merged and pushed; keep them — don't delete branches without asking.

## 4. Working rules (owner's standing instructions)

- **Autonomy:** do everything that doesn't need the owner; keep a
  "needs you" list and hand it over in one batch.
- **Self-review first:** never ask the owner to review something you
  haven't reviewed and tested yourself.
- **Push as you go:** push `develop` after every merge. Conventional
  commits. Format + analyze + test must pass before merging.
- **Tests:** always `flutter test --timeout 45s -r expanded > file` and read
  the file — never pipe through `tail`. Create the DB in `setUp`, never
  inside `testWidgets`. Debug a hang by logging to a file, not `print`.
  Proofread shell commands; never leave an interactive program in one.
- **Helper agents** (allowed, owner likes parallel work): default 2–3, each
  a group of related tasks, full instructions up front (no mid-task
  corrections), WIP commits at milestones, prompts start with
  `git checkout -B <branch> develop`. Cheapest capable model: Haiku for
  small/mechanical, Sonnet for UI, Opus for sync/SQL/RLS/migrations/math.
- **Token efficiency:** one session per milestone. When a chunk is merged,
  update `docs/STATUS.md` (done / in flight / next / needs owner) and tell
  the owner it's a good time to start a new session with "Read
  docs/STATUS.md and continue". Don't suggest switching while agents run.
- **App rules:** name is MotoLog; never use Drivvo's name, logo or artwork
  in the app.
