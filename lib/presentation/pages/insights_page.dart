  import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/insights_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/transaction_filter_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/widgets/insights/cumulative_chart.dart';
import 'package:tracker_app/presentation/widgets/insights/cumulative_stats_card.dart';
import 'package:tracker_app/presentation/widgets/insights/contextual_callout.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});

  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insightsAsync = ref.watch(insightsNotifierProvider);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;

    final currencySymbol = NumberFormat.simpleCurrency(name: settings?.defaultCurrencyCode ?? 'USD').currencySymbol;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Financial Insights',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: insightsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to generate analytics',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    err.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          data: (insightsState) {
            final categories = categoriesAsync.valueOrNull ?? [];

            if (insightsState.allTimeSummary.transactionCount < 5) {
              return _buildEmptyState(
                context,
                Icons.analytics_outlined,
                'Start Tracking',
                'Add a few more transactions to see your spending story.',
              );
            }

            return NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CumulativeStatsCard(
                          allTimeSummary: insightsState.allTimeSummary,
                          currencySymbol: currencySymbol,
                        ),
                        ContextualCallout(
                          transactions: ref.watch(transactionsNotifierProvider).valueOrNull ?? [],
                          allTimeSummary: insightsState.allTimeSummary,
                          currencySymbol: currencySymbol,
                        ),
                        CumulativeSpendingChart(
                          spentPoints: insightsState.cumulativeTimeline,
                          earnedPoints: insightsState.cumulativeEarnedTimeline,
                          selectedPeriod: insightsState.selectedTimelinePeriod,
                          currencySymbol: currencySymbol,
                          onPeriodChanged: (period) {
                            ref.read(insightsNotifierProvider.notifier).changeTimelinePeriod(period);
                          },
                          summary: insightsState.cumulativeSummary,
                        ),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      height: 140.0,
                      child: Material(
                        elevation: 0.5,
                        color: theme.colorScheme.surface,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TabBar(
                              labelColor: theme.colorScheme.primary,
                              unselectedLabelColor: theme.colorScheme.outline,
                              indicatorColor: theme.colorScheme.primary,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              tabs: const [
                                Tab(
                                  icon: Icon(Icons.pie_chart_rounded, size: 20),
                                  text: 'Overview',
                                ),
                                Tab(
                                  icon: Icon(Icons.analytics_rounded, size: 20),
                                  text: 'Trends',
                                ),
                                Tab(
                                  icon: Icon(Icons.store_rounded, size: 20),
                                  text: 'Merchants',
                                ),
                              ],
                            ),
                            _buildPeriodSelector(context, insightsState.selectedPeriod),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildOverviewTab(context, insightsState, categories, currencySymbol),
                  _buildTrendsTab(context, insightsState, currencySymbol),
                  _buildMerchantsTab(context, insightsState, currencySymbol),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, InsightsPeriod currentPeriod) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Center(
        child: SegmentedButton<InsightsPeriod>(
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: theme.colorScheme.primaryContainer,
            selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
          ),
          segments: const [
            ButtonSegment(
              value: InsightsPeriod.thisMonth,
              label: Text('This Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              icon: Icon(Icons.calendar_today_rounded, size: 14),
            ),
            ButtonSegment(
              value: InsightsPeriod.last3Months,
              label: Text('3 Months', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              icon: Icon(Icons.history_rounded, size: 14),
            ),
            ButtonSegment(
              value: InsightsPeriod.last6Months,
              label: Text('6 Months', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              icon: Icon(Icons.manage_history_rounded, size: 14),
            ),
            ButtonSegment(
              value: InsightsPeriod.thisYear,
              label: Text('This Year', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              icon: Icon(Icons.calendar_month_rounded, size: 14),
            ),
          ],
          selected: {currentPeriod},
          onSelectionChanged: (Set<InsightsPeriod> selectedSet) {
            if (selectedSet.isNotEmpty) {
              ref.read(insightsNotifierProvider.notifier).changePeriod(selectedSet.first);
            }
          },
          showSelectedIcon: false,
        ),
      ),
    );
  }

  // ==================== TAB 1: OVERVIEW ====================

  Widget _buildOverviewTab(
    BuildContext context,
    InsightsState state,
    List<Category> categories,
    String currencySymbol,
  ) {
    if (state.categorySpending.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.donut_large_rounded,
        'No Category Spending Data',
        'We couldn\'t find any active debit transactions in this period. Add transactions to see category allocations.',
      );
    }

    final overallTotal = state.categorySpending.fold<double>(
      0.0,
      (sum, item) => sum + item.total,
    );

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Elegant Donut Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'TOTAL EXPENSES',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$currencySymbol${overallTotal.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  RepaintBoundary(
                    child: SizedBox(
                      height: 180,
                      child: Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      _touchedPieIndex = -1;
                                      return;
                                    }
                                    _touchedPieIndex = pieTouchResponse
                                        .touchedSection!.touchedSectionIndex;
  
                                    // Check if they physically clicked a slice, navigate
                                    if (event is FlTapUpEvent) {
                                      final index = _touchedPieIndex;
                                      if (index >= 0 && index < state.categorySpending.length) {
                                        final tappedItem = state.categorySpending[index];
                                        _navigateToCategoryFilter(tappedItem.categoryId);
                                      }
                                    }
                                  });
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 4,
                              centerSpaceRadius: 55,
                              sections: List.generate(state.categorySpending.length, (i) {
                                final item = state.categorySpending[i];
                                final isTouched = i == _touchedPieIndex;
                                final radius = isTouched ? 48.0 : 40.0;
                                final details = _getCategoryDetails(item.categoryId, categories);
  
                                return PieChartSectionData(
                                  color: details.color,
                                  value: item.total,
                                  title: '${item.percentage.toStringAsFixed(0)}%',
                                  radius: radius,
                                  showTitle: item.percentage >= 5, // skip tiny titles
                                  titleStyle: TextStyle(
                                    fontSize: isTouched ? 14.0 : 11.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(color: Colors.black54, blurRadius: 2)
                                    ],
                                  ),
                                );
                              }),
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                          ),
                          // Centered Info Badge
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wallet_rounded,
                                  color: theme.colorScheme.outline.withAlpha(200),
                                  size: 24,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${state.categorySpending.length} Categories',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'TIP: Tap a slice or legend item to filter transactions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Spending Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // Scrollable List of Category Legends
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.categorySpending.length,
            itemBuilder: (context, index) {
              final item = state.categorySpending[index];
              final details = _getCategoryDetails(item.categoryId, categories);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(40)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _navigateToCategoryFilter(item.categoryId),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Category Icon Badge
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: details.color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            details.icon,
                            color: details.color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Category Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                details.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.percentage.toStringAsFixed(1)}% of total',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                        // Category Amount Spent
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-$currencySymbol${item.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.error,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: theme.colorScheme.outline.withAlpha(150),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: TRENDS ====================

  Widget _buildTrendsTab(BuildContext context, InsightsState state, String currencySymbol) {
    final theme = Theme.of(context);

    // Filter non-zero items to do calculation safely
    final nonDeletedTrend = state.monthlyTrend;

    if (nonDeletedTrend.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.bubble_chart_rounded,
        'No Monthly Trend Data',
        'Add transactions over multiple months to enable credits vs debits trend bar charts.',
      );
    }

    // Calculations for summary stats
    double overallSpend = 0.0;
    MonthlyTrend? highestSpendMonth;

    for (final t in nonDeletedTrend) {
      overallSpend += t.totalDebits;
      if (highestSpendMonth == null || t.totalDebits > highestSpendMonth.totalDebits) {
        highestSpendMonth = t;
      }
    }

    final avgSpend = nonDeletedTrend.isEmpty ? 0.0 : overallSpend / nonDeletedTrend.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Credit vs Debit Bar Chart
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Credit vs Debit',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      // Legend Indicators
                      Row(
                        children: [
                          _buildChartLegendIndicator('In', Colors.green),
                          const SizedBox(width: 12),
                          _buildChartLegendIndicator('Out', theme.colorScheme.error),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  RepaintBoundary(
                    child: SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceEvenly,
                          maxY: _calculateMaxBarY(nonDeletedTrend),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => theme.colorScheme.surfaceContainerHigh,
                              tooltipPadding: const EdgeInsets.all(8),
                              tooltipMargin: 8,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final isCredit = rodIndex == 0;
                                return BarTooltipItem(
                                  '${isCredit ? "Income" : "Expense"}\n$currencySymbol${rod.toY.toStringAsFixed(2)}',
                                  TextStyle(
                                    color: isCredit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 42,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) return const SizedBox.shrink();
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 4,
                                    child: Text(
                                      _formatAxisNumber(value, currencySymbol),
                                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey),
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
                                  if (idx >= 0 && idx < nonDeletedTrend.length) {
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      space: 4,
                                      child: Text(
                                        nonDeletedTrend[idx].month,
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (val) => FlLine(
                              color: theme.colorScheme.outlineVariant.withAlpha(40),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(nonDeletedTrend.length, (index) {
                            final trend = nonDeletedTrend[index];
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: trend.totalCredits,
                                  color: Colors.green.shade500,
                                  width: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                BarChartRodData(
                                  toY: trend.totalDebits,
                                  color: theme.colorScheme.error,
                                  width: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }),
                        ),
                        duration: const Duration(milliseconds: 300),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Summary stats block
          Row(
            children: [
              Expanded(
                child: _buildTrendStatCard(
                  context,
                  'Average Spend',
                  Icons.trending_neutral_rounded,
                  '$currencySymbol${avgSpend.toStringAsFixed(0)}',
                  theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTrendStatCard(
                  context,
                  'Highest Spend',
                  Icons.trending_up_rounded,
                  highestSpendMonth == null || highestSpendMonth.totalDebits == 0
                      ? 'No Spend'
                      : '$currencySymbol${highestSpendMonth.totalDebits.toStringAsFixed(0)}',
                  theme.colorScheme.error,
                  subtitle: highestSpendMonth != null && highestSpendMonth.totalDebits > 0
                      ? 'In ${highestSpendMonth.month}'
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3. Line Chart - Daily Spending
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
            ),
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Spend Timeline',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Debit transactions tracking',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 24),
                  if (state.dailySpending.isEmpty) ...[
                    const SizedBox(
                      height: 160,
                      child: Center(
                        child: Text(
                          'No daily debits inside this range.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                  ] else ...[
                    RepaintBoundary(
                      child: SizedBox(
                        height: 160,
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
                                tooltipPadding: const EdgeInsets.all(8),
                                tooltipRoundedRadius: 8,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final idx = spot.x.toInt();
                                    if (idx >= 0 && idx < state.dailySpending.length) {
                                      final date = state.dailySpending[idx].date;
                                      final formattedDate = DateFormat('MM/dd').format(date);
                                      return LineTooltipItem(
                                        '$formattedDate\n$currencySymbol${spot.y.toStringAsFixed(2)}',
                                        TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      );
                                    }
                                    return null;
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: theme.colorScheme.outlineVariant.withAlpha(30),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 38,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const SizedBox.shrink();
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      space: 4,
                                      child: Text(
                                        _formatAxisNumber(value, currencySymbol),
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
                                    if (idx >= 0 && idx < state.dailySpending.length) {
                                      final totalPoints = state.dailySpending.length;
                                      // Plot max 4 label ticks on horizontal timeline to stay extremely neat
                                      final isTick = idx == 0 ||
                                          idx == totalPoints - 1 ||
                                          (totalPoints > 4 && idx == (totalPoints / 2).round()) ||
                                          (totalPoints > 10 && idx == (totalPoints / 4).round()) ||
                                          (totalPoints > 10 && idx == ((totalPoints * 3) / 4).round());
                                      if (!isTick) return const SizedBox.shrink();
  
                                      final date = state.dailySpending[idx].date;
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(
                                          DateFormat('Md').format(date),
                                          style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(state.dailySpending.length, (index) {
                                  return FlSpot(index.toDouble(), state.dailySpending[index].amount);
                                }),
                                isCurved: true,
                                color: theme.colorScheme.primary,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: theme.colorScheme.primary.withOpacity(0.12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildChartLegendIndicator(String name, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTrendStatCard(
    BuildContext context,
    String label,
    IconData icon,
    String value,
    Color color, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(50)),
      ),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== TAB 3: MERCHANTS ====================

  Widget _buildMerchantsTab(BuildContext context, InsightsState state, String currencySymbol) {
    final theme = Theme.of(context);

    if (state.topMerchants.isEmpty) {
      return _buildEmptyState(
        context,
        Icons.store_rounded,
        'No Merchant Spend Recorded',
        'Add transactions containing merchant names to display a progress breakdown of spending by storefront.',
      );
    }

    final maxSpend = state.topMerchants.isNotEmpty ? state.topMerchants[0].total : 1.0;

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: state.topMerchants.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Section header info
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Merchants',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Your top outbound business expenditures, on-device.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          );
        }

        final item = state.topMerchants[index - 1];
        final relativeFraction = maxSpend > 0 ? (item.total / maxSpend) : 0.0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(40)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _navigateToMerchantFilter(item.merchantName),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Rank Index Badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: index == 1
                              ? theme.colorScheme.primary
                              : index == 2
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$index',
                            style: TextStyle(
                              color: index <= 2
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Merchant details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.merchantName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.count} transaction${item.count > 1 ? "s" : ""}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      // Total Spent
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currencySymbol${item.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Filtered logs',
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: theme.colorScheme.outline.withAlpha(150),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Relative Spend scale progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: LinearProgressIndicator(
                        value: relativeFraction,
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                        color: index == 1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==================== NAVIGATION AND REUSE HELPERS ====================

  void _navigateToCategoryFilter(String categoryId) {
    ref.read(transactionFilterNotifierProvider.notifier).clearAll();
    ref.read(transactionFilterNotifierProvider.notifier).toggleCategory(categoryId);
    context.go('/transactions');
  }

  void _navigateToMerchantFilter(String merchantName) {
    ref.read(transactionFilterNotifierProvider.notifier).clearAll();
    ref.read(transactionFilterNotifierProvider.notifier).setSearch(merchantName);
    context.go('/transactions');
  }

  _CategoryDetails _getCategoryDetails(String id, List<Category> categories) {
    final cat = categories.where((c) => c.id == id).firstOrNull;
    if (cat != null) {
      return _CategoryDetails(
        name: cat.name,
        color: Color(cat.colorValue),
        icon: IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
      );
    }
    return _CategoryDetails(
      name: 'Uncategorized',
      color: Colors.grey,
      icon: Icons.category_rounded,
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxBarY(List<MonthlyTrend> list) {
    double maxVal = 100.0;
    for (final t in list) {
      if (t.totalCredits > maxVal) maxVal = t.totalCredits;
      if (t.totalDebits > maxVal) maxVal = t.totalDebits;
    }
    // padd by 15% to make the bars fit beautifully
    return maxVal * 1.15;
  }

  String _formatAxisNumber(double value, String currencyAndSymbol) {
    if (value >= 1000) {
      return '$currencyAndSymbol${(value / 1000).toStringAsFixed(1)}k';
    }
    return '$currencyAndSymbol${value.toInt()}';
  }
}

class _CategoryDetails {
  final String name;
  final Color color;
  final IconData icon;

  _CategoryDetails({
    required this.name,
    required this.color,
    required this.icon,
  });
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SliverAppBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
