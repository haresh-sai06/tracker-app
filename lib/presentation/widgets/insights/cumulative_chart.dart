import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';

class CumulativeSpendingChart extends StatefulWidget {
  final List<TimelinePoint> spentPoints;
  final List<TimelinePoint> earnedPoints;
  final TimelinePeriod selectedPeriod;
  final String currencySymbol;
  final ValueChanged<TimelinePeriod> onPeriodChanged;
  final CumulativeSummary summary;

  const CumulativeSpendingChart({
    super.key,
    required this.spentPoints,
    required this.earnedPoints,
    required this.selectedPeriod,
    required this.currencySymbol,
    required this.onPeriodChanged,
    required this.summary,
  });

  @override
  State<CumulativeSpendingChart> createState() => _CumulativeSpendingChartState();
}

class _CumulativeSpendingChartState extends State<CumulativeSpendingChart> {
  bool _showEarned = false;

  String _formatXAxisLabel(DateTime date, TimelinePeriod period) {
    switch (period) {
      case TimelinePeriod.last30Days:
      case TimelinePeriod.last90Days:
        return DateFormat('MMM d').format(date);
      case TimelinePeriod.last6Months:
        return DateFormat('MMM yy').format(date);
      case TimelinePeriod.thisYear:
        return DateFormat('MMM').format(date);
      case TimelinePeriod.allTime:
        return DateFormat('MMM yy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section Header and Period Selector on Right
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total spending over time',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPeriodSelector(),
              ],
            ),
            const SizedBox(height: 16),
            
            // Cumulative spending summary metrics
            _buildMetricsSummary(theme),
            const SizedBox(height: 16),
            
            // Toggle for Earned Line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildLegendDot(Colors.redAccent, 'Spent'),
                    if (_showEarned) ...[
                      const SizedBox(width: 16),
                      _buildLegendDot(Colors.teal, 'Earned'),
                    ],
                  ],
                ),
                ChoiceChip(
                  label: const Text('Show Earned Line', style: TextStyle(fontSize: 11)),
                  selected: _showEarned,
                  selectedColor: theme.colorScheme.primaryContainer,
                  onSelected: (val) {
                    setState(() {
                      _showEarned = val;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Chart or Empty State
            SizedBox(
              height: 220,
              child: widget.spentPoints.isEmpty
                  ? Center(
                      child: Text(
                        'No spending data for this period',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.outline),
                      ),
                    )
                  : _buildLineChart(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimelinePeriod.values.map((period) {
          final isSelected = widget.selectedPeriod == period;
          String label = '';
          switch (period) {
            case TimelinePeriod.last30Days:
              label = '30 days';
              break;
            case TimelinePeriod.last90Days:
              label = '90 days';
              break;
            case TimelinePeriod.last6Months:
              label = '6 months';
              break;
            case TimelinePeriod.thisYear:
              label = 'This year';
              break;
            case TimelinePeriod.allTime:
              label = 'All time';
              break;
          }
          return Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  widget.onPeriodChanged(period);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricsSummary(ThemeData theme) {
    final summary = widget.summary;
    final currency = widget.currencySymbol;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          _buildMetricCell('Total Spent', '$currency${summary.totalSpent.toStringAsFixed(2)}', theme.colorScheme.error),
          _buildMetricCell('Total Earned', '$currency${summary.totalEarned.toStringAsFixed(2)}', Colors.teal),
          _buildMetricCell(
            'Net Flow',
            '$currency${summary.netFlow.toStringAsFixed(2)}',
            summary.netFlow >= 0 ? Colors.teal : theme.colorScheme.error,
          ),
          _buildMetricCell('Avg Trans', '$currency${summary.averageTransactionAmount.toStringAsFixed(2)}', theme.colorScheme.onSurface),
          _buildMetricCell('Active Days', '${summary.activeDaysCount} days', theme.colorScheme.onSurface),
          _buildMetricCell('Top Category', summary.topSpendingCategory ?? 'None', theme.colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLineChart(ThemeData theme) {
    final currency = widget.currencySymbol;

    double maxVal = 0.0;
    for (final pt in widget.spentPoints) {
      if (pt.cumulative > maxVal) maxVal = pt.cumulative;
    }
    if (_showEarned) {
      for (final pt in widget.earnedPoints) {
        if (pt.cumulative > maxVal) maxVal = pt.cumulative;
      }
    }
    
    maxVal = maxVal * 1.15;
    if (maxVal == 0.0) maxVal = 100.0;

    final List<FlSpot> spentSpots = [];
    for (int i = 0; i < widget.spentPoints.length; i++) {
      spentSpots.add(FlSpot(i.toDouble(), widget.spentPoints[i].cumulative));
    }

    final List<FlSpot> earnedSpots = [];
    if (_showEarned) {
      for (int i = 0; i < widget.earnedPoints.length; i++) {
        if (i < widget.earnedPoints.length) {
          earnedSpots.add(FlSpot(i.toDouble(), widget.earnedPoints[i].cumulative));
        }
      }
    }

    final showXLabelsIdx = <int>{};
    final int pointsCount = widget.spentPoints.length;
    if (pointsCount > 0) {
      showXLabelsIdx.add(0);
      showXLabelsIdx.add(pointsCount - 1);
      if (pointsCount > 2) {
        showXLabelsIdx.add(pointsCount ~/ 2);
      }
      if (pointsCount > 6) {
        showXLabelsIdx.add(pointsCount ~/ 4);
        showXLabelsIdx.add((pointsCount * 3) ~/ 4);
      }
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxVal,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
            tooltipPadding: const EdgeInsets.all(8),
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final isSpentSpot = spot.barIndex == 0;
                
                final pointsList = isSpentSpot ? widget.spentPoints : widget.earnedPoints;
                if (idx < 0 || idx >= pointsList.length) return null;
                
                final point = pointsList[idx];
                final formattedDate = DateFormat('MMM d, yyyy').format(point.date);
                final typeText = isSpentSpot ? 'Cumulative Spent' : 'Cumulative Earned';
                final color = isSpentSpot ? Colors.redAccent : Colors.teal;
                
                return LineTooltipItem(
                  '$formattedDate\n($typeText)\nTotal: $currency${point.cumulative.toStringAsFixed(2)}\nDelta: $currency${point.delta.toStringAsFixed(2)}',
                  theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ) ?? const TextStyle(),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant.withAlpha(40),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                String formattedValue;
                if (value >= 1000) {
                  formattedValue = '${(value / 1000).toStringAsFixed(1)}k';
                } else {
                  formattedValue = value.toStringAsFixed(0);
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    '$currency$formattedValue',
                    style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (showXLabelsIdx.contains(idx) && idx >= 0 && idx < widget.spentPoints.length) {
                  final dt = widget.spentPoints[idx].date;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _formatXAxisLabel(dt, widget.selectedPeriod),
                      style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spentSpots,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.redAccent.withOpacity(0.15),
            ),
          ),
          if (_showEarned && earnedSpots.isNotEmpty)
            LineChartBarData(
              spots: earnedSpots,
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.teal.withOpacity(0.10),
              ),
            ),
        ],
      ),
    );
  }
}
