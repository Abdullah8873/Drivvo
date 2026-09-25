import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/calc/flex_math.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/record_module.dart';
import '../../core/widgets/module_form_scaffold.dart' show FieldRow;
import '../reports/widgets/chart_style.dart';

/// Cyan used for the "gasoline" bar/banner (Drivvo's flex-calculator color
/// for gasoline; ethanol reuses [RecordModule.refueling]'s orange).
const _gasolineColor = Color(0xFF00BCD4);

/// More → "Flex calculator": tells a flex-fuel owner whether ethanol or
/// gasoline is the cheaper choice right now. A flex engine gets fewer km per
/// liter on ethanol than on gasoline — "autonomy difference" is how much
/// less (e.g. 70% means a liter of ethanol only goes 70% as far), so
/// ethanol is only worth it when its price is below that same percentage of
/// the gas price. Pure math lives in `core/calc/flex_math.dart`.
class FlexCalculatorScreen extends StatefulWidget {
  const FlexCalculatorScreen({super.key});

  @override
  State<FlexCalculatorScreen> createState() => _FlexCalculatorScreenState();
}

class _FlexCalculatorScreenState extends State<FlexCalculatorScreen> {
  static const _minAutonomy = 50.0;
  static const _maxAutonomy = 100.0;

  double _autonomy = 70;
  late final _autonomyController = TextEditingController(text: '70');
  final _gasController = TextEditingController();
  final _ethanolController = TextEditingController();

  String? _gasError;
  String? _ethanolError;
  FlexResult? _result;

  @override
  void dispose() {
    _autonomyController.dispose();
    _gasController.dispose();
    _ethanolController.dispose();
    super.dispose();
  }

  void _onSlider(double v) {
    setState(() {
      _autonomy = v.roundToDouble();
      _autonomyController.text = _autonomy.round().toString();
    });
  }

  void _onAutonomyField(String text) {
    final v = double.tryParse(text);
    if (v == null) return;
    setState(() => _autonomy = v.clamp(_minAutonomy, _maxAutonomy));
  }

  double? _parsePrice(String text) => double.tryParse(text.trim());

  void _calculate() {
    final gas = _parsePrice(_gasController.text);
    final ethanol = _parsePrice(_ethanolController.text);
    setState(() {
      _gasError = (gas == null || gas <= 0) ? 'Enter a price' : null;
      _ethanolError = (ethanol == null || ethanol <= 0)
          ? 'Enter a price'
          : null;
      _result = _gasError == null && _ethanolError == null
          ? FlexMath.calculate(
              gasPrice: gas!,
              ethanolPrice: ethanol!,
              autonomyPercent: _autonomy,
            )
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flex calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
        children: [
          FieldRow(
            icon: Icons.speed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autonomy difference',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        key: const Key('flexAutonomySlider'),
                        value: _autonomy,
                        min: _minAutonomy,
                        max: _maxAutonomy,
                        divisions: (_maxAutonomy - _minAutonomy).round(),
                        label: '${_autonomy.round()}%',
                        onChanged: _onSlider,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: TextField(
                        key: const Key('flexAutonomyField'),
                        controller: _autonomyController,
                        textAlign: TextAlign.end,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(suffixText: '%'),
                        onChanged: _onAutonomyField,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FieldRow(
            icon: Icons.attach_money,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('flexGasPrice'),
                    controller: _gasController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Gas price',
                      errorText: _gasError,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    key: const Key('flexEthanolPrice'),
                    controller: _ethanolController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Ethanol price',
                      errorText: _ethanolError,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilledButton(
              key: const Key('flexCalculateButton'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              onPressed: _calculate,
              child: const Text(
                'CALCULATE',
                style: TextStyle(letterSpacing: 1),
              ),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _RecommendationBanner(result: _result!),
            const SizedBox(height: 20),
            _FlexBarChart(result: _result!),
          ],
        ],
      ),
    );
  }
}

/// Full-width banner: orange "use ethanol" or cyan "use gasoline".
class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({required this.result});

  final FlexResult result;

  @override
  Widget build(BuildContext context) {
    final ethanol = result.recommendation == FlexFuel.ethanol;
    final color = ethanol ? RecordModule.refueling.color : _gasolineColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        ethanol ? 'We recommend using ethanol' : 'We recommend using gasoline',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }
}

/// Two-bar comparison (Gasoline pinned at 100%, Ethanol at its price ratio),
/// 0–100% axis on both sides. The percentage above each bar is a plain
/// `Text` (not fl_chart's touch-only tooltip) so it's always visible and
/// so widget tests can find it directly.
class _FlexBarChart extends StatelessWidget {
  const _FlexBarChart({required this.result});

  final FlexResult result;

  @override
  Widget build(BuildContext context) {
    final style = ChartStyle.of(context);
    final ethanolValue = result.ethanolToGasRatio.clamp(0, 100).toDouble();
    const gasValue = 100.0;

    BarChartGroupData bar(int x, double value, Color color) =>
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: value,
              color: color,
              width: 40,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        );

    Widget label(String text, Color color) => Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            label('${gasValue.toStringAsFixed(1)} %', _gasolineColor),
            label(
              '${result.ethanolToGasRatio.toStringAsFixed(1)} %',
              RecordModule.refueling.color,
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                bar(0, gasValue, _gasolineColor),
                bar(1, ethanolValue, RecordModule.refueling.color),
              ],
              barTouchData: const BarTouchData(enabled: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: style.gridLine,
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(bottom: BorderSide(color: style.grid)),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 20,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${value.toInt()}', style: style.axis),
                    ),
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 20,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${value.toInt()}', style: style.axis),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value.toInt() == 0 ? 'Gasoline' : 'Ethanol',
                        style: style.axis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
