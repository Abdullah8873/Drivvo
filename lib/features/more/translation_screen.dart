import 'package:flutter/material.dart';

import '../../core/widgets/max_width_body.dart';

/// More → Translation: only English exists today. A real language picker
/// (like Settings → Language) would be misleading with one option, so this
/// just confirms the current choice and sets expectations for more later.
class TranslationScreen extends StatelessWidget {
  const TranslationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: MaxWidthBody(
        child: ListView(
          children: [
            // A single, fixed choice: no `onChanged` needed, so this
            // `RadioGroup` never actually changes its value.
            RadioGroup<String>(
              groupValue: 'en',
              onChanged: (_) {},
              child: const RadioListTile<String>(
                value: 'en',
                title: Text('English'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'More languages are coming.',
                style: TextStyle(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
