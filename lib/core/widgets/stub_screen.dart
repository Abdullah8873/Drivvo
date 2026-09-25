import 'package:flutter/material.dart';

/// Temporary screen for routes whose real UI is still being built.
class StubScreen extends StatelessWidget {
  const StubScreen({super.key, required this.title, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: color),
      body: Center(
        child: Text(
          '$title — under construction',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
