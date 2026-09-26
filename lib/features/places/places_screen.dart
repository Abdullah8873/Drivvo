import 'package:flutter/material.dart';

import 'places_list_tab.dart';
import 'places_map_tab.dart';

/// More → "My places": every place and gas station from the catalogs, as a
/// searchable list or on a map. Uses the general teal (it isn't tied to one
/// [RecordModule]), same as the other catalog screens.
class MyPlacesScreen extends StatefulWidget {
  const MyPlacesScreen({super.key});

  @override
  State<MyPlacesScreen> createState() => _MyPlacesScreenState();
}

class _MyPlacesScreenState extends State<MyPlacesScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My places'),
        bottom: TabBar(
          controller: _tabs,
          // Sits on the teal app bar: the default M3 label color is the
          // primary teal itself, which made the selected tab invisible.
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'LIST'),
            Tab(text: 'MAP'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [PlacesListTab(), PlacesMapTab()],
      ),
    );
  }
}
