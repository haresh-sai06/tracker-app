import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetCumulativeSpendingTimelineParams {
  final String currencyCode;
  final TimelinePeriod period;
  final TimelineGroup groupBy;
  final bool isCredit;

  const GetCumulativeSpendingTimelineParams({
    required this.currencyCode,
    required this.period,
    required this.groupBy,
    this.isCredit = false,
  });
}

class GetCumulativeSpendingTimeline implements UseCase<List<TimelinePoint>, GetCumulativeSpendingTimelineParams> {
  final TransactionRepository repository;

  GetCumulativeSpendingTimeline(this.repository);

  @override
  Future<Either<Failure, List<TimelinePoint>>> call(GetCumulativeSpendingTimelineParams params) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime? startDate;
    switch (params.period) {
      case TimelinePeriod.last30Days:
        startDate = today.subtract(const Duration(days: 30));
        break;
      case TimelinePeriod.last90Days:
        startDate = today.subtract(const Duration(days: 90));
        break;
      case TimelinePeriod.last6Months:
        startDate = today.subtract(const Duration(days: 180));
        break;
      case TimelinePeriod.thisYear:
        startDate = DateTime(today.year, 1, 1);
        break;
      case TimelinePeriod.allTime:
        startDate = null;
        break;
    }

    final result = await repository.getTransactions(
      startDate: startDate,
      currencyCode: params.currencyCode,
    );

    return result.fold(
      (failure) => Left(failure),
      (transactions) {
        final activeTransactions = transactions.where((tx) => !tx.isDeleted).toList();

        // Sort by dateTime ascending
        activeTransactions.sort((a, b) => a.dateTime.compareTo(b.dateTime));

        DateTime resolvedStartDate;
        if (params.period == TimelinePeriod.allTime) {
          if (activeTransactions.isNotEmpty) {
            final earliestTx = activeTransactions.first;
            resolvedStartDate = DateTime(earliestTx.dateTime.year, earliestTx.dateTime.month, earliestTx.dateTime.day);
          } else {
            resolvedStartDate = today.subtract(const Duration(days: 30));
          }
        } else {
          resolvedStartDate = startDate!;
        }

        final List<DateTime> buckets = [];
        DateTime current = resolvedStartDate;
        final DateTime endDate = today;

        if (params.groupBy == TimelineGroup.daily) {
          while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
            buckets.add(current);
            current = current.add(const Duration(days: 1));
          }
        } else if (params.groupBy == TimelineGroup.weekly) {
          while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
            buckets.add(current);
            current = current.add(const Duration(days: 7));
          }
        } else if (params.groupBy == TimelineGroup.monthly) {
          DateTime startMonth = DateTime(resolvedStartDate.year, resolvedStartDate.month, 1);
          DateTime endMonth = DateTime(endDate.year, endDate.month, 1);
          while (startMonth.isBefore(endMonth) || startMonth.isAtSameMomentAs(endMonth)) {
            buckets.add(startMonth);
            startMonth = DateTime(startMonth.year, startMonth.month + 1, 1);
          }
        }

        final List<TimelinePoint> points = [];
        double runningTotal = 0.0;

        for (final bucket in buckets) {
          double delta = 0.0;

          for (final tx in activeTransactions) {
            final txDate = DateTime(tx.dateTime.year, tx.dateTime.month, tx.dateTime.day);

            bool matches = false;
            if (params.groupBy == TimelineGroup.daily) {
              matches = txDate == bucket;
            } else if (params.groupBy == TimelineGroup.weekly) {
              matches = !txDate.isBefore(bucket) && txDate.isBefore(bucket.add(const Duration(days: 7)));
            } else if (params.groupBy == TimelineGroup.monthly) {
              matches = txDate.year == bucket.year && txDate.month == bucket.month;
            }

            if (matches) {
              final isMatchingType = (params.isCredit && tx.type == TransactionType.credit) ||
                                     (!params.isCredit && tx.type == TransactionType.debit);
              if (isMatchingType) {
                delta += tx.amount;
              }
            }
          }

          runningTotal += delta;
          points.add(TimelinePoint(
            date: bucket,
            cumulative: runningTotal,
            delta: delta,
          ));
        }

        return Right(points);
      },
    );
  }
}
