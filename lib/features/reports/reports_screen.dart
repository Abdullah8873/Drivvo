import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/files/file_sharer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/main_tab_app_bar.dart';
import 'report_pdf.dart';
import 'report_providers.dart';
import 'tabs/expense_report_tab.dart';
import 'tabs/general_report_tab.dart';
import 'tabs/income_report_tab.dart';
import 'tabs/reading_report_tab.dart';
import 'tabs/refueling_report_tab.dart';
import 'tabs/route_report_tab.dart';
import 'tabs/service_report_tab.dart';

/// What the Share sheet's two rows produce.
enum _ShareAs { image, pdf }

/// Reports tab: scrollable tabs (General, Refueling, Expense, …). Each tab
/// lives in its own file under `tabs/` and is built on `ReportTabScaffold`
/// (period card + stat cards + charts); the selected period is shared by
/// every tab via `reportPeriodProvider`.
///
/// A `ConsumerStatefulWidget` (rather than the plain `StatelessWidget` this
/// used to be) so it can own an explicit `TabController` — needed to know
/// which tab is on screen when Share is tapped — and a `RepaintBoundary` per
/// tab, so that tab's rendered content can be captured as a PNG.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = <(String, Widget)>[
    ('GENERAL', GeneralReportTab()),
    ('REFUELING', RefuelingReportTab()),
    ('EXPENSE', ExpenseReportTab()),
    ('INCOME', IncomeReportTab()),
    ('SERVICE', ServiceReportTab()),
    ('ROUTE', RouteReportTab()),
    ('READING', ReadingReportTab()),
  ];

  late final TabController _tabController;

  /// One capture boundary per tab, so sharing always grabs whichever tab is
  /// currently selected without rebuilding anything.
  final _boundaryKeys = [for (final _ in _tabs) GlobalKey()];

  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: MainTabAppBar(
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.share),
            onPressed: _sharing ? null : () => _showShareSheet(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: ColoredBox(
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primary,
              unselectedLabelColor: scheme.onSurfaceVariant,
              indicatorColor: AppTheme.primary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              tabs: [for (final (label, _) in _tabs) Tab(text: label)],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          for (final (i, (_, tab)) in _tabs.indexed)
            RepaintBoundary(key: _boundaryKeys[i], child: tab),
        ],
      ),
    );
  }

  Future<void> _showShareSheet(BuildContext context) async {
    final action = await showModalBottomSheet<_ShareAs>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Share as image'),
              onTap: () => Navigator.pop(ctx, _ShareAs.image),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Share as PDF'),
              onTap: () => Navigator.pop(ctx, _ShareAs.pdf),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    await _share(action);
  }

  /// Captures the current tab's `RepaintBoundary` as a PNG, then either
  /// shares it directly or embeds it in a one-page PDF.
  ///
  /// The boundary only rasterizes what's actually laid out on screen: the
  /// tab's content is a scrollable list that can be much taller than the
  /// viewport, so a long report is captured cropped to what's currently
  /// visible, not the full scrolled content. Rendering an offstage copy of
  /// the whole list to work around this is possible but adds real
  /// complexity (a second live provider subscription, chart libraries that
  /// assume a bounded size, …) for a "nice to have"; documenting the
  /// limitation here was judged the better trade for now.
  Future<void> _share(_ShareAs action) async {
    debugPrint('DBG _share start');
    final index = _tabController.index;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final boundary =
        _boundaryKeys[index].currentContext?.findRenderObject();
    debugPrint('DBG boundary=$boundary');
    if (boundary is! RenderRepaintBoundary) return;

    setState(() => _sharing = true);
    try {
      debugPrint('DBG calling toImage');
      final image = await boundary.toImage(pixelRatio: devicePixelRatio);
      debugPrint('DBG got image ${image.width}x${image.height}');
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      debugPrint('DBG got byteData ${byteData?.lengthInBytes}');
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final slug = _tabs[index].$1.toLowerCase();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final sharer = ref.read(fileSharerProvider);

      if (action == _ShareAs.image) {
        await sharer.shareBytes(
          filename: 'motolog-report-$slug-$dateStr.png',
          bytes: pngBytes,
          mimeType: 'image/png',
        );
        return;
      }

      final tabTitle = _titleCase(_tabs[index].$1);
      final periodLabel = ref.read(reportPeriodProvider).label;
      final pdfBytes = await buildReportImagePdf(
        pngBytes: pngBytes,
        title: 'MotoLog report — $tabTitle — $periodLabel',
      );
      await sharer.shareBytes(
        filename: 'motolog-report-$slug-$dateStr.pdf',
        bytes: pdfBytes,
        mimeType: 'application/pdf',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  static String _titleCase(String upper) =>
      '${upper[0]}${upper.substring(1).toLowerCase()}';
}
