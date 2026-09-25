import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_info.dart';
import '../../core/files/file_sharer.dart';

/// More → Contact: a small action sheet, like the attachment source picker.
/// "Email us" only appears once [AppInfo.contactEmail] is filled in; "Send
/// feedback" always works (it just shares the same text through whatever
/// app the user picks, no email account required).
///
/// Takes a [ProviderContainer] rather than a `WidgetRef` so the caller (a
/// plain `StatelessWidget` menu) doesn't need to become a `ConsumerWidget`
/// just for this one row.
Future<void> showContactSheet(
  BuildContext context,
  ProviderContainer container,
) async {
  final hasEmail = AppInfo.contactEmail.isNotEmpty;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasEmail)
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email us'),
              subtitle: Text(AppInfo.contactEmail),
              onTap: () async {
                Navigator.pop(ctx);
                await _emailUs(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('Send feedback'),
            onTap: () async {
              Navigator.pop(ctx);
              await _sendFeedback(container);
            },
          ),
        ],
      ),
    ),
  );
}

Future<String> _feedbackSubject() async {
  final info = await PackageInfo.fromPlatform();
  return 'MotoLog feedback (v${info.version})';
}

Future<void> _emailUs(BuildContext context) async {
  final subject = await _feedbackSubject();
  final uri = Uri(
    scheme: 'mailto',
    path: AppInfo.contactEmail,
    query: 'subject=${Uri.encodeComponent(subject)}',
  );
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No email app available')));
  }
}

Future<void> _sendFeedback(ProviderContainer container) async {
  final subject = await _feedbackSubject();
  await container.read(fileSharerProvider).shareText(subject, subject: subject);
}
