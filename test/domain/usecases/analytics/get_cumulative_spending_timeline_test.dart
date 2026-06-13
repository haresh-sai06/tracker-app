import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/usecases/analytics/get_cumulative_spending_timeline.dart';

class FakeTransactionRepository implements TransactionRepository {
  final List<Transaction> transactions;

  FakeTransactionRepository(this.transactions);

  @override
  Future<Either<Failure, List<Transaction>>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? accountId,
    TransactionType? type,
    String? searchQuery,
    String? currencyCode,
  }) async {
    final filtered = transactions.where((tx) {
      if (startDate != null && tx.dateTime.isBefore(startDate)) return false;
      if (endDate != null && tx.dateTime.isAfter(endDate)) return false;
      if (currencyCode != null && tx.currencyCode != currencyCode) return false;
      if (type != null && tx.type != type) return false;
      return true;
    }).toList();
    return Right(filtered);
  }

  @override
  Future<Either<Failure, Transaction>> getTransaction(String id) async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> addTransaction(Transaction transaction) async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> updateTransaction(Transaction transaction) async => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteTransaction(String id) async => throw UnimplementedError();

  @override
  Future<Either<Failure, List<Transaction>>> getTransactionsByCurrency(String currencyCode) async => Right(transactions);
}

void main() {
  group('GetCumulativeSpendingTimeline Unit Tests', () {
    test('Verify cumulative sum increases and behaves correctly on daily timeline with debit transactions', () async {
      final now = DateTime.now();
      
      final txs = [
        Transaction(
          id: '1',
          amount: 50.0,
          currencyCode: 'USD',
          type: TransactionType.debit,
          category: 'food',
          accountId: 'acc1',
          description: 'Burgers',
          source: TransactionSource.manual,
          dateTime: now.subtract(const Duration(days: 4)),
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        Transaction(
          id: '2',
          amount: 120.0,
          currencyCode: 'USD',
          type: TransactionType.debit,
          category: 'bills',
          accountId: 'acc1',
          description: 'Electric bill',
          source: TransactionSource.manual,
          dateTime: now.subtract(const Duration(days: 3)),
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        Transaction(
          id: '3',
          amount: 30.0,
          currencyCode: 'USD',
          type: TransactionType.debit,
          category: 'entertainment',
          accountId: 'acc1',
          description: 'Cinema',
          source: TransactionSource.manual,
          dateTime: now.subtract(const Duration(days: 1)),
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final repository = FakeTransactionRepository(txs);
      final useCase = GetCumulativeSpendingTimeline(repository);

      final result = await useCase.call(const GetCumulativeSpendingTimelineParams(
        currencyCode: 'USD',
        period: TimelinePeriod.last30Days,
        groupBy: TimelineGroup.daily,
        isCredit: false,
      ));

      expect(result.isRight, true);
      final points = result.fold((_) => <TimelinePoint>[], (r) => r);

      expect(points.isNotEmpty, true);

      // Verify each point increases or remains same (each point cumulative >= previous point)
      for (int i = 1; i < points.length; i++) {
        expect(points[i].cumulative, greaterThanOrEqualTo(points[i - 1].cumulative));
      }

      // Check final cumulative matches total tx sum
      final finalCumulative = points.last.cumulative;
      expect(finalCumulative, equals(200.0));
    });
  });
}
