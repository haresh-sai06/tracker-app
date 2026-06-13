import 'package:tracker_app/core/errors/either.dart';
import 'package:tracker_app/domain/entities/analytics_entities.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/failures/failure.dart';
import 'package:tracker_app/domain/repositories/transaction_repository.dart';
import 'package:tracker_app/domain/repositories/category_repository.dart';
import 'package:tracker_app/domain/usecases/usecase.dart';

class GetCumulativeSpendingParams {
  final String currencyCode;
  final DateTime? startDate;
  final CumulativeGroup groupBy;

  const GetCumulativeSpendingParams({
    required this.currencyCode,
    this.startDate,
    required this.groupBy,
  });
}

class GetCumulativeSpending implements UseCase<CumulativeSummary, GetCumulativeSpendingParams> {
  final TransactionRepository transactionRepository;
  final CategoryRepository categoryRepository;

  GetCumulativeSpending(this.transactionRepository, this.categoryRepository);

  @override
  Future<Either<Failure, CumulativeSummary>> call(GetCumulativeSpendingParams params) async {
    DateTime? resolvedStartDate = params.startDate;
    final now = DateTime.now();
    if (resolvedStartDate == null) {
      if (params.groupBy == CumulativeGroup.thisYear) {
        resolvedStartDate = DateTime(now.year, 1, 1);
      } else if (params.groupBy == CumulativeGroup.thisMonth) {
        resolvedStartDate = DateTime(now.year, now.month, 1);
      }
    }

    final txResult = await transactionRepository.getTransactions(
      startDate: resolvedStartDate,
      currencyCode: params.currencyCode,
    );

    final categoriesResult = await categoryRepository.getCategories();
    final Map<String, String> categoryNames = {};
    categoriesResult.fold(
      (_) {},
      (categories) {
        for (final cat in categories) {
          categoryNames[cat.id] = cat.name;
        }
      },
    );

    return txResult.fold(
      (failure) => Left(failure),
      (transactions) {
        double totalSpent = 0.0;
        double totalEarned = 0.0;
        int transactionCount = 0;
        Transaction? biggestSingleExpense;
        final Map<String, double> categorySpend = {};
        final Set<String> activeDays = {};

        for (final tx in transactions) {
          if (tx.isDeleted) continue;

          transactionCount++;
          final dateKey = "${tx.dateTime.year}-${tx.dateTime.month}-${tx.dateTime.day}";
          activeDays.add(dateKey);

          if (tx.type == TransactionType.debit) {
            totalSpent += tx.amount;
            if (biggestSingleExpense == null || tx.amount > biggestSingleExpense.amount) {
              biggestSingleExpense = tx;
            }
            if (tx.category.isNotEmpty) {
              categorySpend[tx.category] = (categorySpend[tx.category] ?? 0.0) + tx.amount;
            }
          } else if (tx.type == TransactionType.credit) {
            totalEarned += tx.amount;
          }
        }

        double averageTxAmount = 0.0;
        if (transactionCount > 0) {
          averageTxAmount = (totalSpent + totalEarned) / transactionCount;
        }

        String? topCategory;
        double maxCategorySpend = -1.0;
        categorySpend.forEach((catId, amount) {
          if (amount > maxCategorySpend) {
            maxCategorySpend = amount;
            topCategory = categoryNames[catId] ?? catId;
          }
        });

        final summary = CumulativeSummary(
          totalSpent: totalSpent,
          totalEarned: totalEarned,
          netFlow: totalEarned - totalSpent,
          transactionCount: transactionCount,
          averageTransactionAmount: averageTxAmount,
          biggestSingleExpense: biggestSingleExpense,
          topSpendingCategory: topCategory,
          activeDaysCount: activeDays.length,
        );

        return Right(summary);
      },
    );
  }
}
