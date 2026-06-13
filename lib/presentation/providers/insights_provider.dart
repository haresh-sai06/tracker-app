import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/usecases/analytics/get_spending_by_category.dart';
import 'package:tracker_app/domain/usecases/analytics/get_monthly_trend.dart';
import 'package:tracker_app/domain/usecases/analytics/get_top_merchants.dart';
import 'package:tracker_app/domain/usecases/analytics/get_cumulative_spending.dart';
import 'package:tracker_app/domain/usecases/analytics/get_cumulative_spending_timeline.dart';
import 'package:tracker_app/presentation/providers/repository_providers.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';

part 'insights_provider.g.dart';

enum InsightsPeriod {
  thisMonth,
  last3Months,
  last6Months,
  thisYear,
}

class InsightsState {
  final List<CategorySpending> categorySpending;
  final List<MonthlyTrend> monthlyTrend;
  final List<TopMerchant> topMerchants;
  final List<DailySpending> dailySpending;
  final InsightsPeriod selectedPeriod;
  final DateTime startDate;
  final DateTime endDate;
  final CumulativeSummary cumulativeSummary;
  final CumulativeSummary allTimeSummary;
  final List<TimelinePoint> cumulativeTimeline;
  final List<TimelinePoint> cumulativeEarnedTimeline;
  final TimelinePeriod selectedTimelinePeriod;

  const InsightsState({
    required this.categorySpending,
    required this.monthlyTrend,
    required this.topMerchants,
    required this.dailySpending,
    required this.selectedPeriod,
    required this.startDate,
    required this.endDate,
    required this.cumulativeSummary,
    required this.allTimeSummary,
    required this.cumulativeTimeline,
    required this.cumulativeEarnedTimeline,
    required this.selectedTimelinePeriod,
  });

  InsightsState copyWith({
    List<CategorySpending>? categorySpending,
    List<MonthlyTrend>? monthlyTrend,
    List<TopMerchant>? topMerchants,
    List<DailySpending>? dailySpending,
    InsightsPeriod? selectedPeriod,
    DateTime? startDate,
    DateTime? endDate,
    CumulativeSummary? cumulativeSummary,
    CumulativeSummary? allTimeSummary,
    List<TimelinePoint>? cumulativeTimeline,
    List<TimelinePoint>? cumulativeEarnedTimeline,
    TimelinePeriod? selectedTimelinePeriod,
  }) {
    return InsightsState(
      categorySpending: categorySpending ?? this.categorySpending,
      monthlyTrend: monthlyTrend ?? this.monthlyTrend,
      topMerchants: topMerchants ?? this.topMerchants,
      dailySpending: dailySpending ?? this.dailySpending,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cumulativeSummary: cumulativeSummary ?? this.cumulativeSummary,
      allTimeSummary: allTimeSummary ?? this.allTimeSummary,
      cumulativeTimeline: cumulativeTimeline ?? this.cumulativeTimeline,
      cumulativeEarnedTimeline: cumulativeEarnedTimeline ?? this.cumulativeEarnedTimeline,
      selectedTimelinePeriod: selectedTimelinePeriod ?? this.selectedTimelinePeriod,
    );
  }
}

@riverpod
class InsightsNotifier extends _$InsightsNotifier {
  InsightsPeriod _selectedPeriod = InsightsPeriod.thisMonth;
  TimelinePeriod _selectedTimelinePeriod = TimelinePeriod.thisYear;

  @override
  FutureOr<InsightsState> build() async {
    // Watch transaction updates so that any changes to DB instantly recalculate insights values
    final transactions = ref.watch(transactionsNotifierProvider).valueOrNull ?? [];
    final activeWallet = ref.watch(activeWalletProvider);
    final targetCurrency = activeWallet.currencyCode;

    // Analytics Guard: Defensive check on input list of transactions
    final List<Transaction> safeTransactions = [];
    for (final tx in transactions) {
      if (tx.currencyCode != targetCurrency) {
        print("WARNING (Insights): Outlier or mismatched currency detected: ${tx.id} with currency ${tx.currencyCode} expected $targetCurrency. Excluding.");
      } else {
        safeTransactions.add(tx);
      }
    }
    
    final repository = ref.watch(transactionRepositoryProvider);
    final categoryRepository = ref.watch(categoryRepositoryProvider);
    final getSpending = GetSpendingByCategory(repository);
    final getTrend = GetMonthlyTrend(repository);
    final getMerchants = GetTopMerchants(repository);
    final getCumulative = GetCumulativeSpending(repository, categoryRepository);
    final getTimeline = GetCumulativeSpendingTimeline(repository);

    final now = DateTime.now();
    late DateTime start;
    late DateTime end;

    switch (_selectedPeriod) {
      case InsightsPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
        break;
      case InsightsPeriod.last3Months:
        start = DateTime(now.year, now.month - 2, 1);
        end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
        break;
      case InsightsPeriod.last6Months:
        start = DateTime(now.year, now.month - 5, 1);
        end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(microseconds: 1));
        break;
      case InsightsPeriod.thisYear:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1).subtract(const Duration(microseconds: 1));
        break;
    }

    // Spending by category use case
    final spendingResult = await getSpending.call(
      GetSpendingByCategoryParams(startDate: start, endDate: end, currencyCode: targetCurrency),
    );
    final spending = spendingResult.fold((f) => throw f, (s) => s);

    // Monthly Trend use case selection length
    int trendMonths = 3;
    if (_selectedPeriod == InsightsPeriod.last6Months) {
      trendMonths = 6;
    } else if (_selectedPeriod == InsightsPeriod.thisYear) {
      trendMonths = 12;
    } else if (_selectedPeriod == InsightsPeriod.last3Months) {
      trendMonths = 3;
    } else {
      trendMonths = 3;
    }

    final trendResult = await getTrend.call(
      GetMonthlyTrendParams(lastNMonths: trendMonths, currencyCode: targetCurrency),
    );
    final trend = trendResult.fold((f) => throw f, (t) => t);

    // Top merchants list
    final merchantsResult = await getMerchants.call(
      GetTopMerchantsParams(startDate: start, endDate: end, limit: 10, currencyCode: targetCurrency),
    );
    final merchants = merchantsResult.fold((f) => throw f, (m) => m);

    // Calculate daily spending points with downsampling if required for clean line chart bounds
    final List<DailySpending> dailyList = [];
    final today = DateTime.now();
    final limitDate = today.isBefore(end) ? today : end;

    final Map<String, double> tempMap = {};
    for (final tx in safeTransactions) {
      if (tx.isDeleted || tx.type != TransactionType.debit) continue;
      final d = tx.dateTime;
      if (!d.isBefore(start) && !d.isAfter(end)) {
        final key = "${d.year}-${d.month}-${d.day}";
        tempMap[key] = (tempMap[key] ?? 0.0) + tx.amount;
      }
    }

    int dayStep = 1;
    if (_selectedPeriod == InsightsPeriod.last3Months) {
      dayStep = 2;
    } else if (_selectedPeriod == InsightsPeriod.last6Months) {
      dayStep = 4;
    } else if (_selectedPeriod == InsightsPeriod.thisYear) {
      dayStep = 7;
    }

    var tempDate = DateTime(start.year, start.month, start.day);
    while (!tempDate.isAfter(limitDate)) {
      double sum = 0.0;
      for (int k = 0; k < dayStep; k++) {
        final d = tempDate.add(Duration(days: k));
        if (d.isAfter(limitDate)) break;
        final key = "${d.year}-${d.month}-${d.day}";
        sum += tempMap[key] ?? 0.0;
      }
      
      dailyList.add(DailySpending(
        date: tempDate,
        amount: sum,
      ));
      tempDate = tempDate.add(Duration(days: dayStep));
    }

    // Cumulative spending summary
    CumulativeGroup cumulativeGroup = CumulativeGroup.allTime;
    if (_selectedPeriod == InsightsPeriod.thisMonth) {
      cumulativeGroup = CumulativeGroup.thisMonth;
    } else if (_selectedPeriod == InsightsPeriod.thisYear) {
      cumulativeGroup = CumulativeGroup.thisYear;
    }

    final cumulativeResult = await getCumulative.call(
      GetCumulativeSpendingParams(
        currencyCode: targetCurrency,
        startDate: start,
        groupBy: cumulativeGroup,
      ),
    );
    final cumulativeSummary = cumulativeResult.fold((f) => throw f, (s) => s);

    final allTimeCumulativeResult = await getCumulative.call(
      GetCumulativeSpendingParams(
        currencyCode: targetCurrency,
        startDate: null,
        groupBy: CumulativeGroup.allTime,
      ),
    );
    final allTimeSummary = allTimeCumulativeResult.fold((f) => throw f, (s) => s);

    // Timeline Points (Debit & Credit)
    TimelineGroup timelineGroup = TimelineGroup.daily;
    if (_selectedTimelinePeriod == TimelinePeriod.last6Months) {
      timelineGroup = TimelineGroup.weekly;
    } else if (_selectedTimelinePeriod == TimelinePeriod.thisYear) {
      timelineGroup = TimelineGroup.weekly;
    } else if (_selectedTimelinePeriod == TimelinePeriod.allTime) {
      timelineGroup = TimelineGroup.monthly;
    } else if (_selectedTimelinePeriod == TimelinePeriod.last90Days) {
      timelineGroup = TimelineGroup.daily;
    }

    final timelineSpentResult = await getTimeline.call(
      GetCumulativeSpendingTimelineParams(
        currencyCode: targetCurrency,
        period: _selectedTimelinePeriod,
        groupBy: timelineGroup,
        isCredit: false,
      ),
    );
    final cumulativeTimeline = timelineSpentResult.fold((f) => throw f, (t) => t);

    final timelineEarnedResult = await getTimeline.call(
      GetCumulativeSpendingTimelineParams(
        currencyCode: targetCurrency,
        period: _selectedTimelinePeriod,
        groupBy: timelineGroup,
        isCredit: true,
      ),
    );
    final cumulativeEarnedTimeline = timelineEarnedResult.fold((f) => throw f, (t) => t);

    return InsightsState(
      categorySpending: spending,
      monthlyTrend: trend,
      topMerchants: merchants,
      dailySpending: dailyList,
      selectedPeriod: _selectedPeriod,
      startDate: start,
      endDate: end,
      cumulativeSummary: cumulativeSummary,
      allTimeSummary: allTimeSummary,
      cumulativeTimeline: cumulativeTimeline,
      cumulativeEarnedTimeline: cumulativeEarnedTimeline,
      selectedTimelinePeriod: _selectedTimelinePeriod,
    );
  }

  void changePeriod(InsightsPeriod period) {
    if (_selectedPeriod != period) {
      _selectedPeriod = period;
      ref.invalidateSelf();
    }
  }

  void changeTimelinePeriod(TimelinePeriod period) {
    if (_selectedTimelinePeriod != period) {
      _selectedTimelinePeriod = period;
      ref.invalidateSelf();
    }
  }
}
