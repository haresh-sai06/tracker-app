class MonthlySummary {
  final double totalCredits;
  final double totalDebits;
  final double netChange;
  final int transactionCount;

  const MonthlySummary({
    required this.totalCredits,
    required this.totalDebits,
    required this.netChange,
    required this.transactionCount,
  });

  factory MonthlySummary.zero() {
    return const MonthlySummary(
      totalCredits: 0.0,
      totalDebits: 0.0,
      netChange: 0.0,
      transactionCount: 0,
    );
  }
}
