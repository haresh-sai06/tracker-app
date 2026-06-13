import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';

class ContextualCallout extends StatefulWidget {
  final List<Transaction> transactions;
  final CumulativeSummary allTimeSummary;
  final String currencySymbol;

  const ContextualCallout({
    super.key,
    required this.transactions,
    required this.allTimeSummary,
    required this.currencySymbol,
  });

  @override
  State<ContextualCallout> createState() => _ContextualCalloutState();
}

class _ContextualCalloutState extends State<ContextualCallout> {
  late final int _insightIndex;

  @override
  void initState() {
    super.initState();
    // Deterministically rotate through the insights when the widget initializes
    _insightIndex = Random().nextInt(3);
  }

  String _getBusiestDayInsight() {
    final debits = widget.transactions
        .where((tx) => !tx.isDeleted && tx.type == TransactionType.debit)
        .toList();
    if (debits.isEmpty) return "No transactions found to determine busiest day.";

    final Map<int, int> weekdayCounts = {};
    for (final tx in debits) {
      weekdayCounts[tx.dateTime.weekday] = (weekdayCounts[tx.dateTime.weekday] ?? 0) + 1;
    }

    if (weekdayCounts.isEmpty) return "No transactions found to determine busiest day.";

    var busiestDay = 1;
    var maxCount = 0;
    weekdayCounts.forEach((day, count) {
      if (count > maxCount) {
        maxCount = count;
        busiestDay = day;
      }
    });

    final double percentage = (maxCount / debits.length) * 100;

    final weekdays = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };

    final dayName = weekdays[busiestDay] ?? 'Unspecified Day';
    return "Your busiest spending day was $dayName (${percentage.toStringAsFixed(0)}% of transactions).";
  }

  String _getTopCategoryInsight() {
    final topCategory = widget.allTimeSummary.topSpendingCategory;
    if (topCategory == null || topCategory.isEmpty) {
      return "Track categories like Food or Bills to see breakout spending category insights.";
    }

    final debits = widget.transactions
        .where((tx) => !tx.isDeleted && tx.type == TransactionType.debit)
        .toList();

    final Map<String, double> catSpend = {};
    for (final tx in debits) {
      if (tx.category.isNotEmpty) {
        catSpend[tx.category] = (catSpend[tx.category] ?? 0.0) + tx.amount;
      }
    }

    if (catSpend.isEmpty) {
      return "Categorize your transactions to surface insights on your largest category.";
    }

    var topCatId = '';
    var maxSpend = 0.0;
    catSpend.forEach((catId, amount) {
      if (amount > maxSpend) {
        maxSpend = amount;
        topCatId = catId;
      }
    });

    return "You've spent ${widget.currencySymbol}${maxSpend.toStringAsFixed(2)} on $topCategory — your biggest category.";
  }

  String _getTrackingDaysInsight() {
    final activeDays = widget.allTimeSummary.activeDaysCount;
    return "You've been tracking transactions for $activeDays active day${activeDays > 1 ? "s" : ""}.";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Prepare insights
    final List<String> insights = [
      _getTopCategoryInsight(),
      _getBusiestDayInsight(),
      _getTrackingDaysInsight(),
    ];

    // Read index safely
    final String calloutText = insights[_insightIndex];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: theme.colorScheme.primary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              calloutText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
