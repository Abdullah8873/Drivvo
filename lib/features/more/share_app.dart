import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/files/file_sharer.dart';

/// More → Share app: shares a one-line pitch (plus [AppInfo.shareUrl] once
/// there's a store listing to link) through the platform share sheet.
Future<void> shareApp(ProviderContainer container) async {
  final text = [
    'MotoLog — track fuel, expenses, services and reminders for your '
        'vehicles.',
    if (AppInfo.shareUrl.isNotEmpty) AppInfo.shareUrl,
  ].join('\n');
  await container.read(fileSharerProvider).shareText(text);
}
