import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_app/core/services/sms_parser_service.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';

class ParsedTransactionReviewPage extends ConsumerStatefulWidget {
  final ParsedTransaction? parsedTx;
  final List<ParsedTransaction>? parsedTxs;

  const ParsedTransactionReviewPage({
    super.key,
    this.parsedTx,
    this.parsedTxs,
  });

  @override
  ConsumerState<ParsedTransactionReviewPage> createState() => _ParsedTransactionReviewPageState();
}

class _ParsedTransactionReviewPageState extends ConsumerState<ParsedTransactionReviewPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late TransactionType _type;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isSaving = false;

  late List<ParsedTransaction> _txs;
  int _currentIndex = 0;

  ParsedTransaction get _currentTx => _txs[_currentIndex];

  @override
  void initState() {
    super.initState();
    _txs = widget.parsedTxs ?? (widget.parsedTx != null ? [widget.parsedTx!] : []);
    _currentIndex = 0;
    _amountController = TextEditingController();
    _merchantController = TextEditingController();
    _initializeCurrentTransaction();
  }

  void _initializeCurrentTransaction() {
    if (_txs.isEmpty || _currentIndex >= _txs.length) return;
    final currentTx = _currentTx;
    _amountController.text = currentTx.amount.toStringAsFixed(2);
    _merchantController.text = currentTx.merchantName;
    _type = currentTx.type;

    _selectedCategoryId = null;
    _selectedAccountId = null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate() || _txs.isEmpty) return;

    final accountsAsync = ref.read(accountsNotifierProvider);
    final settingsAsync = ref.read(settingsNotifierProvider);
    final categoriesAsync = ref.read(categoriesNotifierProvider);

    final accounts = accountsAsync.valueOrNull ?? [];
    final appSettings = settingsAsync.valueOrNull;
    final categories = categoriesAsync.valueOrNull ?? [];

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active accounts found to assign.')),
      );
      return;
    }

    final accountId = _selectedAccountId ?? appSettings?.defaultAccountId ?? accounts.first.id;
    final categoryId = _selectedCategoryId ?? categories.firstOrNull?.id ?? 'groceries';

    final parsedAmount = double.tryParse(_amountController.text) ?? _currentTx.amount;

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final newTx = Transaction(
      id: const Uuid().v4(),
      amount: parsedAmount,
      type: _type,
      category: categoryId,
      accountId: accountId,
      description: 'Parsed via Sync: ${_merchantController.text}',
      merchantName: _merchantController.text,
      source: TransactionSource.sms,
      rawSourceText: _currentTx.rawText, // Only save rawText if the user saves
      dateTime: now,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(transactionsNotifierProvider.notifier).add(newTx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Text('Transaction saved (${_currentIndex + 1}/${_txs.length})'),
              ],
            ),
          ),
        );

        setState(() {
          _isSaving = false;
          _currentIndex++;
        });

        if (_currentIndex < _txs.length) {
          _initializeCurrentTransaction();
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_txs.isEmpty || _currentIndex >= _txs.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Transaction')),
        body: const Center(child: Text('No transactions to review.')),
      );
    }

    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final accountsAsync = ref.watch(accountsNotifierProvider);

    final categories = categoriesAsync.valueOrNull ?? [];
    final accounts = accountsAsync.valueOrNull ?? [];

    if (categories.isNotEmpty && _selectedCategoryId == null) {
      final nameLower = _merchantController.text.toLowerCase();
      final matchedCategory = categories.firstWhere(
        (c) => nameLower.contains(c.name.toLowerCase()),
        orElse: () => categories.first,
      );
      _selectedCategoryId = matchedCategory.id;
    }

    if (accounts.isNotEmpty && _selectedAccountId == null) {
      final matchedAccount = accounts.firstWhere(
        (a) => _currentTx.accountLastFour != null && a.lastFourDigits != null && a.lastFourDigits!.contains(_currentTx.accountLastFour!),
        orElse: () => accounts.first,
      );
      _selectedAccountId = matchedAccount.id;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Transaction'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Highlight Warning on Local-First Privacy
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_person, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'On-device Parser: This message remains offline and is only stored in your database when you tap Save.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Original SMS Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.amber.withAlpha(100), width: 1.5),
                  ),
                  color: Colors.amber.withAlpha(15),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sms_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Text(
                              'ORIGINAL MESSAGE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.amber[800],
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (_currentTx.bankName != null) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _currentTx.bankName!,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '"${_currentTx.rawText}"',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Edit Fields Panel
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRE-FILLED TRANSACTION',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle Segmented Buttons Card
                        Center(
                          child: SegmentedButton<TransactionType>(
                            segments: const [
                              ButtonSegment<TransactionType>(
                                value: TransactionType.debit,
                                label: Text('Expense'),
                                icon: Icon(Icons.arrow_downward, color: Colors.redAccent),
                              ),
                              ButtonSegment<TransactionType>(
                                value: TransactionType.credit,
                                label: Text('Income'),
                                icon: Icon(Icons.arrow_upward, color: Colors.green),
                              ),
                            ],
                            selected: {_type},
                            onSelectionChanged: (val) {
                              setState(() {
                                _type = val.first;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Amount Field
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            icon: Icon(Icons.attach_money_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter amount';
                            if (double.tryParse(val) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Merchant / Description
                        TextFormField(
                          controller: _merchantController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant Name',
                            icon: Icon(Icons.store_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Enter merchant / source';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category Dropdown
                        if (categories.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              icon: Icon(Icons.category_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(cat.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Account Dropdown
                        if (accounts.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(
                              labelText: 'Account',
                              icon: Icon(Icons.account_balance_rounded),
                              border: OutlineInputBorder(),
                            ),
                            items: accounts.map((acc) {
                              return DropdownMenuItem<String>(
                                value: acc.id,
                                child: Text(acc.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAccountId = val;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save or Not transaction Buttons
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _onSave,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded),
                  label: const Text('Save Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dismissed parsed transaction (${_currentIndex + 1}/${_txs.length}).')),
                          );
                          setState(() {
                            _currentIndex++;
                          });
                          if (_currentIndex < _txs.length) {
                            _initializeCurrentTransaction();
                          } else {
                            context.pop();
                          }
                        },
                  icon: const Icon(Icons.not_interested_rounded),
                  label: const Text('Not a Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
