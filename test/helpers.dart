import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:motolog/app.dart';
import 'package:motolog/core/db/app_database.dart';
import 'package:motolog/core/files/file_sharer.dart';
import 'package:motolog/core/geo/map_tile_provider.dart';
import 'package:motolog/core/providers.dart';

/// Fresh in-memory database (seeded with default catalogs) for tests.
///
/// `closeStreamsSynchronously` stops drift from scheduling a zero-length
/// timer when a watched query loses its last listener — otherwise every
/// widget test that watches the database fails with "A Timer is still
/// pending even after the widget tree was disposed".
AppDatabase testDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

/// The full app wired to [db] — pump this in widget tests.
///
/// Also swaps in [NoNetworkTileProvider] for any flutter_map `TileLayer`
/// (My places map, the location picker) so pumping a screen with a map never
/// makes a real HTTP request — see `map_tile_provider.dart`.
Widget testApp(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    mapTileProviderProvider.overrideWithValue(NoNetworkTileProvider()),
  ],
  child: const MotoLogApp(),
);

/// Inserts a vehicle and returns its id.
Future<String> addTestVehicle(AppDatabase db, {String name = 'Honda'}) async {
  final v = await db
      .into(db.vehicles)
      .insertReturning(
        VehiclesCompanion.insert(name: name, type: VehicleType.motorcycle),
      );
  return v.id;
}

/// Call at the end of widget tests that show database data: unmounts the app
/// and lets drift's stream-cleanup timers fire, avoiding
/// "A Timer is still pending even after the widget tree was disposed".
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

/// Records every share instead of touching a real share sheet/file system —
/// the interface `FileSharer` exists specifically so tests can swap this in.
class FakeFileSharer implements FileSharer {
  int callCount = 0;
  String? filename;
  Uint8List? bytes;
  String? mimeType;

  /// Set by [shareText] instead of the file fields above.
  int textCallCount = 0;
  String? sharedText;

  @override
  Future<void> shareBytes({
    required String filename,
    required Uint8List bytes,
    required String mimeType,
    String? subject,
  }) async {
    callCount++;
    this.filename = filename;
    this.bytes = bytes;
    this.mimeType = mimeType;
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    textCallCount++;
    sharedText = text;
  }
}

/// The full app wired to [db] with a fake share sheet — pump this in widget
/// tests that trigger export/backup/share flows.
Widget appWithFakeSharer(
  AppDatabase db,
  FakeFileSharer sharer, {
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    fileSharerProvider.overrideWithValue(sharer),
    ...overrides,
  ],
  child: const MotoLogApp(),
);
