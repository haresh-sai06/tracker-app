import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';

class CumulativeStatsCard extends StatelessWidget {
  final CumulativeSummary allTimeSummary;
  final String currencySymbol;

  const CumulativeStatsCard({
    super.key,
    required this.allTimeSummary,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define rich subtle colors for chips matching stat types
    final Color spentBg = isDark ? Colors.red.withOpacity(0.12) : Colors.red.shade50.withOpacity(0.8);
    final Color spentColor = isDark ? Colors.redAccent.shade100 : Colors.red.shade700;

    final Color earnedBg = isDark ? Colors.green.withOpacity(0.12) : Colors.green.shade50.withOpacity(0.8);
    final Color earnedColor = isDark ? Colors.greenAccent.shade400 : Colors.green.shade700;

    final double netFlow = allTimeSummary.netFlow;
    final bool isPositiveFlow = netFlow >= 0;
    final Color flowBg = isPositiveFlow 
        ? (isDark ? Colors.teal.withOpacity(0.12) : Colors.teal.shade50.withOpacity(0.8))
        : (isDark ? Colors.orange.withOpacity(0.12) : Colors.orange.shade50.withOpacity(0.8));
    final Color flowColor = isPositiveFlow
        ? (isDark ? Colors.tealAccent.shade400 : Colors.teal.shade700)
        : (isDark ? Colors.orangeAccent.shade400 : Colors.orange.shade700);

    final Color txBg = isDark ? Colors.deepPurple.withOpacity(0.12) : Colors.purple.shade50.withOpacity(0.8);
    final Color txColor = isDark ? Colors.purpleAccent.shade100 : Colors.purple.shade700;

    final Color daysBg = isDark ? Colors.blue.withOpacity(0.12) : Colors.blue.shade50.withOpacity(0.8);
    final Color daysColor = isDark ? Colors.blueAccent.shade100 : Colors.blue.shade700;

    final Color avgBg = isDark ? Colors.cyan.withOpacity(0.12) : Colors.cyan.shade50.withOpacity(0.8);
    final Color avgColor = isDark ? Colors.cyan.shade700 : Colors.cyan.shade900;

    final Color biggestBg = isDark ? Colors.amber.withOpacity(0.12) : Colors.amber.shade50.withOpacity(0.8);
    final Color biggestColor = isDark ? Colors.amber.shade300 : Colors.amber.shade900;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // 1. Total spent
          _buildStatChip(
            context: context,
            value: '$currencySymbol${allTimeSummary.totalSpent.toStringAsFixed(2)}',
            label: 'Total spent',
            bgColor: spentBg,
            textColor: spentColor,
            testTag: 'insights_stat_spent',
          ),
          const SizedBox(width: 10),

          // 2. Total earned
          _buildStatChip(
            context: context,
            value: '$currencySymbol${allTimeSummary.totalEarned.toStringAsFixed(2)}',
            label: 'Total earned',
            bgColor: earnedBg,
            textColor: earnedColor,
            testTag: 'insights_stat_earned',
          ),
          const SizedBox(width: 10),

          // 3. Net Flow
          _buildStatChip(
            context: context,
            value: '${isPositiveFlow ? "+" : ""}$currencySymbol${netFlow.toStringAsFixed(2)}',
            label: 'Net flow',
            bgColor: flowBg,
            textColor: flowColor,
            testTag: 'insights_stat_netflow',
          ),
          const SizedBox(width: 10),

          // 4. Transactions
          _buildStatChip(
            context: context,
            value: '${allTimeSummary.transactionCount}',
            label: 'Transactions',
            bgColor: txBg,
            textColor: txColor,
            testTag: 'insights_stat_txcount',
          ),
          const SizedBox(width: 10),

          // 5. Active days
          _buildStatChip(
            context: context,
            value: '${allTimeSummary.activeDaysCount} d',
            label: 'Active days',
            bgColor: daysBg,
            textColor: daysColor,
            testTag: 'insights_stat_activedays',
          ),
          const SizedBox(width: 10),

          // 6. Avg per transaction
          _buildStatChip(
            context: context,
            value: '$currencySymbol${allTimeSummary.averageTransactionAmount.toStringAsFixed(2)}',
            label: 'Avg per transaction',
            bgColor: avgBg,
            textColor: avgColor,
            testTag: 'insights_stat_avg',
          ),
          const SizedBox(width: 10),

          // 7. Biggest expense (Tappable)
          _buildStatChip(
            context: context,
            value: allTimeSummary.biggestSingleExpense != null
                ? '$currencySymbol${allTimeSummary.biggestSingleExpense!.amount.toStringAsFixed(2)}'
                : '${currencySymbol}0.00',
            label: 'Biggest expense',
            bgColor: biggestBg,
            textColor: biggestColor,
            testTag: 'insights_stat_biggest_expense',
            isTappable: allTimeSummary.biggestSingleExpense != null,
            onTap: () {
              final tx = allTimeSummary.biggestSingleExpense;
              if (tx != null) {
                // Navigate to the transaction details page
                context.push('/transactions/${tx.id}');
              }
            },
            subtitleWidget: allTimeSummary.biggestSingleExpense != null
                ? Text(
                    allTimeSummary.biggestSingleExpense!.description,
                    style: TextStyle(
                      fontSize: 10,
                      color: biggestColor.withOpacity(0.7),
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required BuildContext context,
    required String value,
    required String label,
    required Color bgColor,
    required Color textColor,
    required String testTag,
    bool isTappable = false,
    VoidCallback? onTap,
    Widget? subtitleWidget,
  }) {
    final theme = Theme.of(context);
    final borderCol = textColor.withOpacity(0.15);

    Widget cardContent = Container(
      key: ValueKey(testTag),
      width: 145,
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 2),
                  subtitleWidget,
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isTappable)
                Icon(
                  Icons.arrow_circle_right_rounded,
                  size: 14,
                  color: textColor,
                ),
            ],
          ),
        ],
      ),
    );

    if (isTappable && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: textColor.withOpacity(0.12),
          highlightColor: textColor.withOpacity(0.06),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
