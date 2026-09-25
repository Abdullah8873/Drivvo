import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/notifications/notification_providers.dart';
import '../../core/providers.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/max_width_body.dart';
import '../../core/widgets/select_list_screen.dart';
import 'backup_restore_section.dart';
import 'currencies.dart';
import 'settings_dialogs.dart';

/// More → Settings. Every row shows its current value as the subtitle and
/// opens a dialog / picker; changes are saved immediately (no SAVE button),
/// like Drivvo.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Date used to preview each date format (same sample Drivvo shows).
  static final _sampleDate = DateTime(1987, 11, 17);

  static const _themeOptions = [
    (ThemeMode.light, 'Light'),
    (ThemeMode.dark, 'Dark'),
    (ThemeMode.system, 'Use system default'),
  ];
  static const _languageOptions = [('en', 'English')];
  static const _volumeOptions = [
    (VolumeUnit.liter, 'Liter'),
    (VolumeUnit.gallonUs, 'Gallon US'),
    (VolumeUnit.gallonImp, 'Gallon Imperial'),
  ];
  static const _gasOptions = [(GasUnit.kg, 'kg'), (GasUnit.cubicMeter, 'm³')];
  static const _economyOptions = [
    (EconomyPosition.cycleStart, 'At the start of the cycle'),
    (EconomyPosition.cycleEnd, 'At the end of the cycle'),
  ];

  /// Looks up the label for [value] in an options list.
  static String _label<T>(List<(T, String)> options, T value) =>
      options.firstWhere((o) => o.$1 == value).$2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuilds whenever any setting changes (like a context consumer).
    final s = ref.watch(settingsProvider);
    final fmt = ref.watch(formattersProvider);

    // Every change goes through the notifier, which persists it to the db.
    void set(AppSettings Function(AppSettings s) change) =>
        ref.read(settingsProvider.notifier).update(change);

    /// Opens a radio dialog and applies the picked value via [apply].
    Future<void> pick<T>(
      String title,
      List<(T, String)> options,
      T selected,
      AppSettings Function(AppSettings s, T value) apply,
    ) async {
      final v = await showRadioDialog<T>(
        context: context,
        title: title,
        options: options,
        selected: selected,
      );
      if (v != null) set((s) => apply(s, v));
    }

    final dateOptions = [
      for (final p in AppSettings.datePatterns)
        (p, DateFormat(p).format(_sampleDate)),
    ];
    final efficiencyOptions = [
      for (final e in EfficiencyFormat.values) (e, e.label),
    ];
    final time =
        '${s.notificationHour.toString().padLeft(2, '0')}:'
        '${s.notificationMinute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _SectionHeader('Formats'),
            _SettingTile(
              icon: Icons.brightness_6,
              title: 'Theme',
              value: _label(_themeOptions, s.themeMode),
              onTap: () => pick(
                'Theme',
                _themeOptions,
                s.themeMode,
                (s, v) => s.copyWith(themeMode: v),
              ),
            ),
            _SettingTile(
              icon: Icons.translate,
              title: 'Language',
              value: _label(_languageOptions, s.languageCode),
              onTap: () => pick(
                'Language',
                _languageOptions,
                s.languageCode,
                (s, v) => s.copyWith(languageCode: v),
              ),
            ),
            _SettingTile(
              icon: Icons.calendar_month,
              title: 'Date format',
              value: DateFormat(s.datePattern).format(_sampleDate),
              onTap: () => pick(
                'Date format',
                dateOptions,
                s.datePattern,
                (s, v) => s.copyWith(datePattern: v),
              ),
            ),
            _SettingTile(
              icon: Icons.attach_money,
              title: 'Currency format',
              value: fmt.money(1000000),
              onTap: () => _pickCurrency(context, ref, set),
            ),
            _CheckTile(
              icon: Icons.onetwothree,
              title: 'Display decimal digits',
              subtitle: fmt.money(1470.13),
              value: s.showDecimals,
              onChanged: (v) => set((s) => s.copyWith(showDecimals: v)),
            ),
            _CheckTile(
              icon: Icons.water_drop,
              title: 'Show three decimal digits',
              subtitle: '42.357 L',
              value: s.threeDecimalVolumes,
              onChanged: (v) => set((s) => s.copyWith(threeDecimalVolumes: v)),
            ),
            const Divider(),
            const _SectionHeader('Units'),
            _SettingTile(
              icon: Icons.straighten,
              title: 'km / Mile / Time',
              value: 'Set per vehicle',
              onTap: () => _showDistanceInfo(context, ref),
            ),
            _SettingTile(
              icon: Icons.local_gas_station,
              title: 'Unit (liquids)',
              value: _label(_volumeOptions, s.volumeUnit),
              onTap: () => pick(
                'Unit',
                _volumeOptions,
                s.volumeUnit,
                (s, v) => s.copyWith(volumeUnit: v),
              ),
            ),
            _SettingTile(
              icon: Icons.propane_tank,
              title: 'Unit (gas)',
              value: _label(_gasOptions, s.gasUnit),
              onTap: () => pick(
                'Unit',
                _gasOptions,
                s.gasUnit,
                (s, v) => s.copyWith(gasUnit: v),
              ),
            ),
            _SettingTile(
              icon: Icons.eco,
              title: 'Fuel efficiency',
              value: s.efficiencyFormat.label,
              onTap: () => pick(
                'Fuel efficiency',
                efficiencyOptions,
                s.efficiencyFormat,
                (s, v) => s.copyWith(efficiencyFormat: v),
              ),
            ),
            _SettingTile(
              icon: Icons.linear_scale,
              title: 'Where to show fuel economy',
              value: _label(_economyOptions, s.economyPosition),
              onTap: () => pick(
                'Where to show fuel economy',
                _economyOptions,
                s.economyPosition,
                (s, v) => s.copyWith(economyPosition: v),
              ),
            ),
            const Divider(),
            const _SectionHeader('Reminders'),
            _SettingTile(
              icon: Icons.speed,
              title: 'Distance in advance',
              value:
                  'Show reminder ${s.reminderDistanceAhead} km/mi in advance '
                  "(in each vehicle's unit)",
              onTap: () async {
                final v = await showNumberDialog(
                  context: context,
                  title: 'Distance in advance',
                  initialValue: s.reminderDistanceAhead,
                  suffix: 'km/mi',
                );
                if (v != null) set((s) => s.copyWith(reminderDistanceAhead: v));
              },
            ),
            _SettingTile(
              icon: Icons.event_note,
              title: 'Number of days',
              value: 'Show reminder ${s.reminderDaysAhead} days in advance',
              onTap: () async {
                final v = await showNumberDialog(
                  context: context,
                  title: 'Number of days',
                  initialValue: s.reminderDaysAhead,
                  suffix: 'days',
                );
                if (v != null) set((s) => s.copyWith(reminderDaysAhead: v));
              },
            ),
            _SettingTile(
              icon: Icons.schedule,
              title: 'Best time for notifications',
              value: time,
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: s.notificationHour,
                    minute: s.notificationMinute,
                  ),
                );
                if (t != null) {
                  set(
                    (s) => s.copyWith(
                      notificationHour: t.hour,
                      notificationMinute: t.minute,
                    ),
                  );
                }
              },
            ),
            _CheckTile(
              icon: Icons.notifications_active,
              title: 'Refueling notifications',
              value: s.refuelingNotifications,
              onChanged: (v) =>
                  set((s) => s.copyWith(refuelingNotifications: v)),
            ),
            _CheckTile(
              icon: Icons.tire_repair,
              title: 'Tire pressure notifications',
              value: s.tirePressureNotifications,
              onChanged: (v) =>
                  set((s) => s.copyWith(tirePressureNotifications: v)),
            ),
            _CheckTile(
              icon: Icons.ev_station,
              title: 'Gas station notification',
              value: s.gasStationNotifications,
              onChanged: (v) =>
                  set((s) => s.copyWith(gasStationNotifications: v)),
            ),
            _CheckTile(
              icon: Icons.vibration,
              title: 'Vibrate when notifying',
              value: s.vibrate,
              onChanged: (v) => set((s) => s.copyWith(vibrate: v)),
            ),
            _SettingTile(
              icon: Icons.notifications,
              title: 'Send test notification',
              value: 'Check that notifications work on this device',
              onTap: () => _sendTestNotification(context, ref),
            ),
            const Divider(),
            const BackupRestoreSection(),
          ],
        ),
      ),
    );
  }

  /// Fires an immediate notification so the owner can verify delivery on
  /// their phone — there's no other way to see whether channel/permission
  /// setup actually works short of waiting for a real reminder to come due.
  Future<void> _sendTestNotification(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Notifications aren't available on the web version"),
        ),
      );
      return Future.value();
    }
    return ref
        .read(notificationSchedulerProvider)
        .showNow(
          title: 'MotoLog',
          body: 'Test notification — if you can see this, it works.',
        );
  }

  /// Full-screen searchable ISO 4217 list (reuses the app's Select screen).
  Future<void> _pickCurrency(
    BuildContext context,
    WidgetRef ref,
    void Function(AppSettings Function(AppSettings s)) set,
  ) async {
    final currentCode = ref.read(settingsProvider).currencyCode;
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => SelectListScreen(
          title: 'Currency format',
          items: [for (final (code, _) in currencies) currencyLabel(code)],
          selected: currencyLabel(currentCode),
        ),
      ),
    );
    final label = picked?.firstOrNull;
    if (label == null) return;
    // Labels look like "PKR - Pakistani Rupee"; the code is the first part.
    final code = label.split(' - ').first;
    set((s) => s.copyWith(currencyCode: code));
  }

  Future<void> _showDistanceInfo(BuildContext context, WidgetRef ref) {
    final vehicleId = ref.read(currentVehicleProvider).value?.id;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(
          'Distance unit is set per vehicle. '
          'Edit your vehicle to change it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (vehicleId != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/vehicles/$vehicleId');
              },
              child: const Text('EDIT VEHICLE'),
            ),
        ],
      ),
    );
  }
}

/// Small teal caps section title ("FORMATS").
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Row with grey icon, title and the current value underneath.
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(value),
      onTap: onTap,
    );
  }
}

/// On/off setting with the checkbox on the right, like Drivvo.
class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      secondary: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      controlAffinity: ListTileControlAffinity.trailing,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}
