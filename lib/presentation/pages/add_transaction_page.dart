import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final Transaction? initialTransaction;

  const AddTransactionPage({
    super.key,
    this.initialTransaction,
  });

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _merchantController = TextEditingController();

  TransactionType _selectedType = TransactionType.debit;
  Category? _selectedCategory;
  Account? _selectedAccount;
  DateTime _selectedDateTime = DateTime.now();

  // Inline errors
  String? _amountError;
  String? _categoryError;
  String? _accountError;

  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final tx = widget.initialTransaction;
      if (tx != null) {
        if (tx.id.isNotEmpty) {
          _amountController.text = tx.amount.toString();
          _descriptionController.text = tx.description;
          _merchantController.text = tx.merchantName ?? '';
        }
        _selectedType = tx.type;
        _selectedDateTime = tx.dateTime;
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final time = TimeOfDay.fromDateTime(_selectedDateTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _showCategoryBottomSheet(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Text(
                    'Select Category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: categories.isEmpty
                      ? const Center(child: Text('No categories found. Add one first.'))
                      : GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = _selectedCategory?.id == cat.id;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                  _categoryError = null;
                                });
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(cat.colorValue).withAlpha(30)
                                      : Theme.of(context).colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? Color(cat.colorValue)
                                        : Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Color(cat.colorValue).withAlpha(40),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
                                        color: Color(cat.colorValue),
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      cat.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _validateAndSubmit() async {
    bool hasErr = false;

    // Amount validation
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    setState(() {
      if (amountText.isEmpty) {
        _amountError = 'Amount is required';
        hasErr = true;
      } else if (amount == null || amount <= 0) {
        _amountError = 'Amount must be greater than 0';
        hasErr = true;
      } else {
        _amountError = null;
      }

      // Category validation
      if (_selectedCategory == null) {
        _categoryError = 'Please select a category';
        hasErr = true;
      } else {
        _categoryError = null;
      }

      // Account validation
      if (_selectedAccount == null) {
        _accountError = 'Please select an account';
        hasErr = true;
      } else {
        _accountError = null;
      }
    });

    if (hasErr) return;

    final navigator = Navigator.of(context);
    final isEdit = widget.initialTransaction != null && widget.initialTransaction!.id.isNotEmpty;
    final activeWallet = ref.read(activeWalletProvider);

    final tx = Transaction(
      id: isEdit ? widget.initialTransaction!.id : const Uuid().v4(),
      amount: amount!,
      type: _selectedType,
      category: _selectedCategory!.id,
      accountId: _selectedAccount!.id,
      description: _descriptionController.text.trim(),
      merchantName: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
      source: TransactionSource.manual,
      rawSourceText: null,
      dateTime: _selectedDateTime,
      isDeleted: false,
      createdAt: isEdit ? widget.initialTransaction!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
      currencyCode: isEdit ? widget.initialTransaction!.currencyCode : activeWallet.currencyCode,
    );

    if (isEdit) {
      await ref.read(transactionsNotifierProvider.notifier).updateTx(tx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction successfully updated.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } else {
      await ref.read(transactionsNotifierProvider.notifier).add(tx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction successfully added.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final accountsAsync = ref.watch(accountsNotifierProvider);
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final activeWallet = ref.watch(activeWalletProvider);

    final categories = categoriesAsync.valueOrNull ?? [];
    final rawAccounts = accountsAsync.valueOrNull ?? [];
    final appSettings = settingsAsync.valueOrNull;

    final isEdit = widget.initialTransaction != null && widget.initialTransaction!.id.isNotEmpty;
    final walletCurrency = activeWallet.currencyCode;
    final currencySymbol = CurrencyUtils.symbolFor(walletCurrency);

    // Filter accounts matching the active wallet's currencyCode
    final accounts = rawAccounts.where((a) => a.currencyCode == walletCurrency).toList();

    // Auto-select initial Category & Account if lists are loaded and match IDs
    if (_selectedCategory == null && categories.isNotEmpty) {
      final targetId = isEdit ? widget.initialTransaction!.category : 'groceries';
      _selectedCategory = categories.firstWhere(
        (c) => c.id == targetId,
        orElse: () => categories.first,
      );
    }

    if (_selectedAccount == null && accounts.isNotEmpty) {
      final targetId = isEdit ? widget.initialTransaction!.accountId : (appSettings?.defaultAccountId ?? 'primary_bank');
      _selectedAccount = accounts.firstWhere(
        (a) => a.id == targetId,
        orElse: () => accounts.first,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaction' : 'Add Transaction'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Numeric Amount Field ---
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() {
                          _amountError = null;
                        });
                      }
                    },
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: -1,
                    ),
                    decoration: InputDecoration(
                      prefixText: currencySymbol,
                      prefixStyle: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary.withAlpha(150),
                      ),
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              if (_amountError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _amountError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 24),

              // --- Type Selection Segments ---
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = TransactionType.debit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedType == TransactionType.debit
                                ? Colors.redAccent.withAlpha(25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedType == TransactionType.debit
                                  ? Colors.redAccent
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  color: _selectedType == TransactionType.debit ? Colors.redAccent : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Debit (Expense)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedType == TransactionType.debit ? Colors.redAccent : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = TransactionType.credit),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedType == TransactionType.credit
                                ? Colors.green.withAlpha(25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedType == TransactionType.credit
                                  ? Colors.green
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: _selectedType == TransactionType.credit ? Colors.green : Colors.grey,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Credit (Income)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedType == TransactionType.credit ? Colors.green : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- Category Selector ---
              Text(
                'Category',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showCategoryBottomSheet(categories),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _categoryError != null
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_selectedCategory != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(_selectedCategory!.colorValue).withAlpha(40),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconData(_selectedCategory!.iconCodePoint, fontFamily: 'MaterialIcons'),
                            color: Color(_selectedCategory!.colorValue),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _selectedCategory!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ] else ...[
                        const Icon(Icons.category_outlined, color: Colors.grey),
                        const SizedBox(width: 16),
                        const Text(
                          'Choose category...',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              if (_categoryError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4),
                  child: Text(
                    _categoryError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),

              // --- Account Selector Dropdown ---
              Text(
                'Account',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accountError != null
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Account>(
                    value: _selectedAccount,
                    isExpanded: true,
                    hint: const Text('Select Account', style: TextStyle(color: Colors.grey)),
                    onChanged: (Account? newVal) {
                      setState(() {
                        _selectedAccount = newVal;
                        _accountError = null;
                      });
                    },
                    items: accounts.map((act) {
                      return DropdownMenuItem<Account>(
                        value: act,
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance, size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 12),
                            Text(act.name, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_accountError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, left: 4),
                  child: Text(
                    _accountError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 20),

              // --- Short Description Box ---
              Text(
                'Description (Optional)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Weekly grocery stock',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Merchant Name ---
              Text(
                'Merchant Name (Optional)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Walmart Inc.',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- DateTime Picks ---
              Text(
                'Date & Time',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('MMM d, yyyy').format(_selectedDateTime),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled, size: 20, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('hh:mm a').format(_selectedDateTime),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // --- Action Submit Button ---
              ElevatedButton(
                onPressed: _validateAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  isEdit ? 'Save Changes' : 'Add Entry',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
