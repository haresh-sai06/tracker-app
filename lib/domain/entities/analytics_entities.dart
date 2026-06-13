import 'package:tracker_app/domain/entities/transaction.dart';

class CategorySpending {
  final String categoryId;
  final double total;
  final double percentage;

  const CategorySpending({
    required this.categoryId,
    required this.total,
    required this.percentage,
  });
}

class MonthlyTrend {
  final String month; // e.g., "Jan" or "May 2026"
  final DateTime date; // first day of that month, useful for sorting or precision
  final double totalCredits;
  final double totalDebits;

  const MonthlyTrend({
    required this.month,
    required this.date,
    required this.totalCredits,
    required this.totalDebits,
  });
}

class TopMerchant {
  final String merchantName;
  final double total;
  final int count;

  const TopMerchant({
    required this.merchantName,
    required this.total,
    required this.count,
  });
}

class DailySpending {
  final DateTime date;
  final double amount;

  const DailySpending({
    required this.date,
    required this.amount,
  });
}

enum CumulativeGroup { allTime, thisYear, thisMonth }
enum TimelinePeriod { last30Days, last90Days, last6Months, thisYear, allTime }
enum TimelineGroup { daily, weekly, monthly }

class CumulativeSummary {
  final double totalSpent;           // sum of all debits
  final double totalEarned;          // sum of all credits
  final double netFlow;              // totalEarned - totalSpent
  final int transactionCount;
  final double averageTransactionAmount;
  final Transaction? biggestSingleExpense;
  final String? topSpendingCategory;  // category name with highest spend
  final int activeDaysCount;          // days with at least one transaction

  const CumulativeSummary({
    required this.totalSpent,
    required this.totalEarned,
    required this.netFlow,
    required this.transactionCount,
    required this.averageTransactionAmount,
    this.biggestSingleExpense,
    this.topSpendingCategory,
    required this.activeDaysCount,
  });
}

class TimelinePoint {
  final DateTime date;
  final double cumulative;
  final double delta;

  const TimelinePoint({
    required this.date,
    required this.cumulative,
    required this.delta,
  });
}

