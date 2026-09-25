import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';

/// More → About: app icon, name, version/build (from `package_info_plus`)
/// and the required "Open-source licenses" entry — the same info every app
/// store listing's "About" screen shows.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Icon(Icons.two_wheeler, size: 72, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              AppInfo.appName,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final text = info == null
                    ? ' '
                    : 'Version ${info.version} (${info.buildNumber})';
                return Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Personal vehicle expense & maintenance tracker',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Free, no ads, works offline; optional cloud sync',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 24),
            const Divider(),
            ListTile(
              leading: Icon(Icons.description_outlined, color: muted),
              title: const Text('Open-source licenses'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppInfo.appName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
