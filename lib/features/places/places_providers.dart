import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/providers.dart';
import '../catalog/catalog_queries.dart';

/// Places and gas stations together, for the My places list/map — see
/// `AppDatabase.watchPlacesAndStations`.
final myPlacesProvider = StreamProvider<List<CatalogItem>>(
  (ref) => ref.watch(databaseProvider).watchPlacesAndStations(),
);
