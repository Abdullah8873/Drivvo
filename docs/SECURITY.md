# MotoLog 1.0.0 — security & abuse review

_Reviewed 2026-09-26 (cloud session, branch `security/review`) before sharing
the APK and web app with friends. Scope: Supabase SQL (RLS, SECURITY DEFINER
functions, Storage), abuse/cost on the Supabase Free plan, the Flutter client
(secrets, Android, web, import/export, attachments), dependencies and GitHub
Actions. **Nothing touched the live project:** every SQL finding was
reproduced and every fix tested on a throwaway local Postgres 16 with a
stand-in for Supabase's `auth`/`storage` schemas (`bash tool/sql_test.sh`,
83 checks), client fixes with the normal test suite._

## Summary

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| S1 | Login CSRF: a link carrying `access_token` signs the app into the sender's account; a never-synced device then uploads its records there | **Medium** | Fixed (client) — needs new APK/web build |
| S2 | Member with Users/Profiles *edit* can make themselves Administrator (guard triggers bypassed with `owner_id` in a PATCH) | **Medium** | Fixed (SQL) — reproduced on the applied schema |
| S3 | No database quota: one account can fill the 500 MB database | **High** (cost/availability) | Fixed (SQL): 64 KB/row, 25 MB/account |
| S4 | No Storage quota, 10 MB files: one account can fill the 1 GB bucket and burn bandwidth | **High** (cost/availability) | Fixed (SQL + client): 3 MB/file, 50 MB/account |
| S5 | `sync_row_exists()` tells any user whether `(owner, id)` exists in someone else's account | Low | Fixed (SQL) — reproduced |
| S6 | Transfer codes: no rate limit on guesses or on code creation | Low | Fixed (SQL): 10 wrong codes/hour, 30/day; 20 codes/day |
| S7 | Invitations trust `email_confirmed_at`: with "Confirm email" off anyone could claim an invite | High *if misconfigured* | **Owner check** (Auth settings) |
| S8 | Sign-up spam; CAPTCHA not supported by the app | Low | **Owner action** (rate limits, keep confirm email) |
| S9 | A member can pin a row with `updated_at = 9999-12-31` so the owner's edits lose | Low | Fixed (SQL) |
| S10 | CSV export formula injection (`=HYPERLINK(…)`, `@…`, `=cmd|…` in a note) | Medium | Fixed (client) |
| S11 | Import / restore / attachment picking read any file size into memory; zip bombs | Low | Fixed (client) |
| S12 | Profile name unbounded (shown in other people's invitation banner) | Low | Fixed (SQL + client) |
| S13 | Attachment type is only the client's claim | Low | Fixed in app (content sniffing); server still trusts the declared type |
| S14 | Android: cleartext not explicitly off for API 24–27; backup/deep-link review | Low | Fixed / reviewed |
| S15 | Web: no CSP or security headers for hosting | Medium (once hosted) | `web/_headers` added + tested; **owner** picks a host that serves it |
| S16 | GitHub Actions: default token permissions; secrets spliced into shell | Low | Fixed |
| S17 | Secrets in repo/history | — | None found |
| S18 | Dependencies | Info | No advisories; upgrade list below |
| S19–S23 | Design notes (Users right = admin-equivalent, transfer file access, orphan files, debug-key signing, dynamic SQL review) | Info | Documented |

New SQL: **`supabase/migrations/20260928000001_security_hardening.sql`** —
**not applied**. The PC session dry-runs it inside `begin … rollback`, then
applies it (see "Owner actions" in `docs/STATUS.md`).

---

## Supabase SQL

### How the RLS was reviewed

Every policy in `20260926000001_sharing.sql` (16 synced tables × 4 policies,
4 Storage policies), every SECURITY DEFINER function and every grant was
read, then exercised as simulated users in `supabase/local-test/10_security_checks.sql`:
owner A, stranger B, Driver C, custom-profile member D, buyers E/F, and anon.
Verified (all pass): a stranger can't read, insert, upsert over, update or
delete another account's rows or Storage objects; can't list their files;
can't call the internal helpers (`account_display_name`, `profile_permissions`,
`transfer_copy`, quota functions); `transfers`, `sync_usage`,
`transfer_attempts` are closed tables; anon can read nothing and call no
RPC; a Driver sees only assigned vehicles and own records and can't write to
other vehicles; `created_by` is server-stamped; `delete_my_account()` still
works; RLS is on for every public table; every SECURITY DEFINER function pins
`search_path`; anon can execute none of them.

### S2 — Member self-escalation through the guard triggers (Medium, fixed)

`account_members_guard()` blocked a member from editing their own membership
with `if old.member_id = auth.uid() and new.owner_id <> auth.uid()`, and
`access_profiles_guard()` skipped all checks when `new.owner_id = auth.uid()`.
`new.owner_id` is whatever the client sends. A member whose profile has
Users (or Profiles) *edit* could send
`PATCH account_members?owner_id=eq.<owner>&id=eq.<own row>` with
`{"owner_id": "<self>", "profile_id": "builtin:administrator"}`: the guard
let it through, then `sync_before_write()` quietly reset `owner_id` to the
owner — and the member was Administrator. Reproduced on the currently applied
schema. Fix: both guards decide by the **stored** owner (`old.owner_id`), and
the profile guard checks the old and new `id`. (Managers/Administrators
already have every right, so only custom profiles were affected.)

### S5 — Row-id probing with `sync_row_exists()` (Low, fixed)

The insert policies need `sync_row_exists(table, owner, id)`, so it is
executable by `authenticated` — and answered for any account. With a user id
(members see their owner's; a transfer buyer sees the seller's in
`storage_path`) anyone could test whether given row ids exist. Ids are random
UUIDs, so the practical value was low. Fix: it returns false unless the
caller is the owner or an active member of that account (for anyone else
`can_access()` refuses the row anyway, so policy results are unchanged).

### Enumeration via `my_invitations` / `account_display_name` (no issue)

`account_display_name()` (which falls back to the email) is revoked from
clients. It is only reachable through `my_invitations()` (invitations sent
**to your own verified email** — you learn the name of whoever invited you),
`my_memberships()` (accounts you already joined) and `accept_invitation()`
(the owner learns your name/email after *you* accept). An owner can't learn
whether an email has an account unless its owner acts. See S7 for the one
setting this depends on, and S12 for banner text.

### SECURITY DEFINER functions and dynamic SQL (no issue)

All pin `set search_path = ''` and schema-qualify everything (checked
automatically in the SQL test). `transfer_copy()` builds SQL with `format()`:
the table goes through `%I`, the vehicle id through `quote_literal()` (safe
with `standard_conforming_strings`), the flag and user ids are bound
parameters, the condition text is built only by `redeem_transfer()`, and the
function is revoked from `public`, `anon` and `authenticated`.
`sync_row_exists()` checks the table name against a fixed list before `%I`.
`redeem_transfer()` normalises the code to `[A-Z0-9]` and uses it only as a
value. No injection path found.

### S6 — Transfer codes (Low, fixed)

8 characters from a 31-letter alphabet = 31⁸ ≈ 8.5 × 10¹¹ codes, generated
from `gen_random_uuid()` bytes with rejection sampling (unbiased). Codes live
7 days and work once. Without a limit, 10 live codes and 100 guesses/second
would still need ~27 years on average — but each guess costs a DB round trip,
and there was no cap on creating codes either. Fix:
- `redeem_transfer()`: more than 10 unknown codes in an hour (or 30 in a day)
  per user → `motolog:transfer_rate_limited`. Because a raised error rolls
  back the transaction (and the attempt record with it), an unknown code now
  returns **no rows** instead of raising; the app shows "No transfer with this
  code" for that (1.0.0 builds show "Couldn't redeem this code.").
- `create_transfer()`: at most 20 codes per seller per 24 h.
With throwaway accounts, S8's limits still bound the total rate.

### S9 — Far-future timestamps from members (Low, fixed)

Last-write-wins trusts the client's `updated_at`. A member could write
`updated_at = 9999-12-31` into rows they may edit, after which every edit by
the owner was ignored as "older". Fix: `sync_before_write()` replaces a
member's `updated_at` that is more than a day ahead with the server clock.
The owner's own writes and the RPCs are unchanged.

### S19 — Users/Profiles rights are administrator-equivalent (Info)

Anyone allowed to invite users can invite a second address of their own with
any profile (including Administrator) and accept it. That's inherent in the
model (Drivvo works the same way): give Users/Profiles rights only to people
you'd make Administrator.

### S20 — Transfer buyer's file access (Info)

After redeeming, the buyer may read the seller's Storage objects whose
attachment rows were copied to them (needed to re-upload them into the
buyer's folder). New files the seller adds later to the same vehicle would
need their (random) attachment id, which the buyer never sees.

---

## Abuse and cost (Supabase Free plan)

Limits: 500 MB database, 1 GB Storage, ~5 GB egress/month. Before this
review nothing per-user existed: a single account could fill the database
with a script, or the bucket with 100 × 10 MB uploads, and a full database
turns the whole project read-only for **everyone**.

### S3 — Database quota (High, fixed)

- **Row cap:** a row over 64 KB (as text) is refused (`motolog:row_too_large`,
  SQLSTATE 54000). The app never produces rows near that.
- **Account quota:** every synced row counts toward its account (`owner_id`)
  in `public.sync_usage`, maintained by statement-level triggers (one update
  per push batch, not per row). New rows past **25 MB** are refused
  (`motolog:quota_exceeded`, SQLSTATE 53400) — the whole batch or transfer
  rolls back. Edits and soft deletes get 20 % headroom so a full account can
  still clean up; hard deletes free space. A heavy real account is ~5 MB.
  Size = length of the row's text form, which is the same before and after
  Postgres compresses it (so inserts and deletes add up exactly; on disk it's
  usually smaller). Transfers count toward the buyer.
- Neither error is 42501, so the app never treats it as "not allowed" (which
  would roll rows back in shared accounts): the rows stay queued and `/sync`
  shows "Your cloud space is full…" / "A record is too large…".
- Tune without a redeploy: `create or replace function
  public.sync_row_quota_bytes() … select <bytes>`; recount any time with
  `select public.sync_usage_recount();` (SQL editor).
- 25 MB × 20 accounts = 500 MB, so if many friends join, watch
  `select * from public.sync_usage order by row_bytes desc;`.

### S4 — Storage quota (High, fixed)

- Bucket `attachments`: `file_size_limit` 10 MB → **3 MB** (the app checks
  the same `RemoteFileStore.maxBytes`, now 3 MB; photos are downscaled to
  1920 px / JPEG 80, typically < 1 MB).
- Insert policy: a new object is refused once its account folder
  (`<owner_id>/…`, members' uploads included) holds **50 MB**. Storage's
  RLS check may run before the new file's size is known, so a folder can
  overshoot by at most one file. Tune with `attachment_quota_bytes()`.
- Allowed types unchanged (JPEG/PNG/GIF/WebP/HEIC/HEIF/PDF — no SVG/HTML).
- 50 MB × 20 accounts = 1 GB: watch
  `select (storage.foldername(name))[1] as account, sum((metadata->>'size')::bigint)/1e6 as mb from storage.objects where bucket_id = 'attachments' group by 1 order by 2 desc;`
- Bandwidth: downloads happen only when viewing an attachment that isn't on
  the device (and for transfer re-homing), bounded by the quota.
- Existing files over 3 MB stay; a not-yet-uploaded local file over 3 MB
  (attached while the limit was 10 MB) will keep failing to upload
  (`/sync` counts it as a failed upload). Remove and re-attach a smaller copy.

### S7 — Auth settings the sharing SQL depends on (owner check)

`my_invitations()` / `accept_invitation()` match on the caller's
**confirmed** email. If "Confirm email" were off, Supabase marks every
sign-up confirmed, so anyone could sign up with an invited address and join
that account. Anonymous sign-ins would give script accounts the
`authenticated` role without any email. See Owner actions.

### S8 — Sign-up spam (owner action)

With "Confirm email" on, a spam sign-up is an unconfirmed `auth.users` row
that can't sign in, sync or upload. The built-in email sender's hourly limit
also throttles confirmation mails (and legitimate sign-ups when several
friends join at once). **Do not enable CAPTCHA yet**: Supabase then requires
a `captchaToken` on sign-up, password sign-in, email links and password
reset, which the app doesn't send — every sign-in would fail. Adding hCaptcha
/ Turnstile to the app is a possible later feature. Leaked-password
protection (HaveIBeenPwned) is a Pro-plan feature.

---

## Client

### S1 — Login CSRF through token links (Medium, fixed)

supabase_flutter hands every incoming link that looks like an auth callback
to gotrue's `getSessionFromUrl()`. Even in PKCE mode, gotrue accepts a link
with `access_token` + `refresh_token` and stores that session as-is. So
anyone could send `com.abdullah8873.motolog://login-callback#access_token=…&refresh_token=…`
(or the web app's URL with the same fragment) with tokens for **their own**
account; tapping it signed the app into the attacker's account, and a device
that had never synced attached its local records to that account on the
first sync (the "different account" dialog only guards devices that synced
before). Fix: `isPkceAuthCallback()` (`lib/core/cloud/cloud_config.dart`)
as `detectSessionInUriPredicate`: only `code`/error links are handled,
anything carrying tokens is ignored. The app only uses PKCE flows, so
nothing legitimate is lost. **Old 1.0.0 builds stay affected — share the new
build.**

PKCE itself does protect the custom scheme: another app can register
`com.abdullah8873.motolog` and receive an emailed link, but the `code` in it
can only be exchanged with the code verifier stored inside MotoLog (and a
code planted by an attacker fails against the victim's verifier).
Verified-https App Links would stop the interception outright — optional
later (needs a hosted domain).

### S10 — CSV formula injection (Medium, fixed)

Export cells are user text (notes, places, a member's records, rows from an
imported CSV). A cell starting with `=`, `+`, `-`, `@`, tab or CR runs as a
formula when the CSV is opened in Excel/LibreOffice/Sheets (`=HYPERLINK(…)`
data exfiltration, DDE `=cmd|…`). Fix: `csvSafeCell()` prefixes such cells
with `'` (plain numbers like `-12.5` untouched); the CSV import undoes it
exactly (`csvUnescapeCell()`), so export → import still round-trips. The
Excel export already writes typed text cells, which are never evaluated; PDF
is unaffected.

### S11 — Import, restore and picking limits (Low, fixed)

All are local (the user picks the file), so the impact was an app crash.
Now: CSV/zip import ≤ 20 MB (checked from the file size before reading),
zip ≤ 100 entries and ≤ 50 MB unpacked (declared sizes checked before
inflating, real sizes after); backup restore ≤ 200 MB; PDF attachments are
refused from their size before being read.

### S13 — Attachment content checks (Low, fixed in app)

The bucket's `allowed_mime_types` checks the Content-Type the client
declares. The app now sniffs the file's first bytes (JPEG/PNG/GIF/WebP/
HEIC/HEIF/PDF, `lib/core/files/file_type_sniffer.dart`), refuses anything
else and uploads with the detected type. A modified client could still
upload other bytes under an image type; files are private and the app only
renders them as images/PDF, so the residual risk is low.

### S14 — Android (Low, fixed / reviewed)

- `android:usesCleartextTraffic="false"`: plain http refused on every
  version (it was the default only from Android 9; minSdk is 24).
- Exported components: only the launcher activity (required); the two
  notification receivers are `exported="false"`. `taskAffinity=""` (no task
  hijacking).
- `allowBackup` stays at its default (on): Android's encrypted backup to the
  user's own Google account is the only safety net for people who never sign
  in. It includes the Supabase session; a restored device is the same user.
- Release APKs are signed with the PC's debug key (S22).

### S15 — Web hosting headers (Medium once hosted)

`web/_headers` (copied into `build/web`, read by Cloudflare Pages and
Netlify) sets a Content-Security-Policy limited to the app's own files,
CanvasKit (`www.gstatic.com`), fallback fonts (`fonts.gstatic.com`), the
Supabase project (`https` + `wss`), OpenStreetMap tiles and Google Identity
Services (`accounts.google.com/gsi/`, which the `google_sign_in` web plugin
loads at start-up — the first test run caught it), plus
`X-Content-Type-Options`, `X-Frame-Options: DENY`/`frame-ancestors 'none'`,
`Referrer-Policy`, `Permissions-Policy` and HSTS. Tested with
`tool/web_csp_check.cjs` against an offline release build in headless
Chromium (start-up, database worker + sqlite3.wasm, CanvasKit, History /
Reports / More; external requests blocked): no CSP violations or page
errors. Not exercised there (offline build, empty database): Supabase calls,
Google sign-in and map tiles — their origins are allow-listed from the code;
**check the browser console once on the hosted site** (sign in, sync, open
My places). GitHub Pages (the opt-in deploy in `release.yml`) can't send
headers — prefer Cloudflare Pages or Netlify, or copy the same values into
the host's config (e.g. Firebase `hosting.headers`). If the Supabase URL
changes, update `connect-src`.

### S17 — Secrets (none found)

All 132 commits (every branch) were scanned for Supabase secret/service-role
keys, JWTs, Google API keys, private keys and keystores: nothing.
`env/cloud.json` is git-ignored (`git check-ignore` confirms) and was never
committed; `*.jks`, `*.keystore`, `key.properties`, `.env*` are ignored. The
project ref and publishable key are public by design (RLS protects the
data).

### S22 — APK signing (Info)

`android/app/build.gradle.kts` signs release builds with the debug key, and
the release workflow's `key.properties` isn't wired into Gradle yet. Fine for
sideloading to friends, but whoever holds the PC's `~/.android/debug.keystore`
can sign an "update". Create a real upload key before the Play Store (already
on the owner list).

## S16 — GitHub Actions (Low, fixed)

- `ci.yml`: `permissions: contents: read` (was the repository default). It
  runs on `pull_request`, not `pull_request_target`, so fork PRs get no
  secrets and a read-only token.
- `release.yml`: `permissions: {}` at the top; the APK job gets
  `contents: write`, the Pages job `pages: write` + `id-token: write`.
  Keystore secrets now reach the script as environment variables (they were
  spliced into the script text, where a `$(…)` in a password would have run).
- Optional: pin third-party actions (`subosito/flutter-action`,
  `softprops/action-gh-release`) to commit SHAs.

## S18 — Dependencies

`flutter pub get` reports no security advisories for the locked versions.
`flutter pub outdated` (2026-09-26): direct `archive` 3.6.1 (4.3.0 exists,
held back by `excel` 4.0.6) and `pdf` 3.12.0 (3.13.1); transitive
`sqlite3` 3.5.2 → 3.6.0, `image` 4.3.0 → 4.10.1, `xml` 6.6.1 → 7.0.1 and
minor others. The bundled SQLite is 3.53.4 (July 2026). `archive`'s known
zip-slip class of bugs doesn't apply (the app never extracts to disk; S11
adds size limits). Not upgraded in this review (1.0.0 is released and
`web/sqlite3.wasm` must match the `sqlite3` package) — run
`flutter pub upgrade` + the full suite + a web build at the start of the
next feature cycle.

## S21 — Orphaned files (Info)

Account deletion removes the user's Storage files from the app before
calling `delete_my_account()` (SQL can't delete Storage objects). If that
step fails, the files stay. To find folders with no user:
`select distinct (storage.foldername(name))[1] from storage.objects o where bucket_id = 'attachments' and not exists (select 1 from auth.users u where u.id::text = (storage.foldername(o.name))[1]);`
— delete them in Dashboard → Storage.

## Testing

- `bash tool/sql_test.sh` — all migrations + the new one (run twice:
  idempotent) on a local Postgres, then 83 checks. Needs a local PostgreSQL
  server install; never touches Supabase. Supabase's real Storage API and
  auth internals are approximated, so the begin … rollback dry run on the
  project is still required.
- `flutter test` — new tests for S1 (`auth_redirect_url_test`), S10/S11
  (`export_writers_test`, `csv_import_test`), S13 (`file_type_sniffer_test`,
  `attachments_ui_test`), S6 in the fake server (`transfer_test`), messages
  (`sharing_model_test`).
- `NODE_PATH=$(npm root -g) node tool/web_csp_check.cjs` after
  `flutter build web --release --no-web-resources-cdn` — S15.
