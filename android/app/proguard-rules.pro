# R8/ProGuard keep rules for the release build (minifyEnabled + shrinkResources,
# see app/build.gradle.kts). Checked every plugin's own docs/consumer rules
# before adding anything here — most need nothing extra:
#
# - flutter_local_notifications >= 19 (we're on 22.x) bundles its own Gson
#   consumer ProGuard rules, so the manual Gson keep rules its README
#   describes are for v18 and below only — not needed here.
# - AGP automatically keeps any class referenced from the merged
#   AndroidManifest.xml (activities, receivers, services), which covers
#   flutter_local_notifications' ScheduledNotificationReceiver /
#   ScheduledNotificationBootReceiver.
# - drift/sqlite3 talk to native SQLite through dart:ffi, not JNI reflection,
#   so nothing to keep on the Kotlin/Java side.
# - Supabase (auth/sync) is a pure-Dart client — no Android-side reflection.
# - geolocator, image_picker, file_picker, share_plus and google_sign_in all
#   ship their own AndroidX consumer-rules.pro, merged automatically by AGP.
#
# Kept here as a safety net in case a future dependency needs one — see
# https://developer.android.com/studio/build/shrink-code#keep-code before
# adding a rule "just in case"; an unverified guess is worse than no rule.
