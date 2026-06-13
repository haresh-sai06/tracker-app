class AccountBalance {
  final double totalCredits;
  final double totalDebits;
  final double netBalance;

  const AccountBalance({
    required this.totalCredits,
    required this.totalDebits,
    required this.netBalance,
  });

  factory AccountBalance.zero() {
    return const AccountBalance(
      totalCredits: 0.0,
      totalDebits: 0.0,
      netBalance: 0.0,
    );
  }
}
