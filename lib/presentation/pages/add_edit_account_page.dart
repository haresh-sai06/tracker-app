import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';

class AddEditAccountPage extends ConsumerStatefulWidget {
  final Account? initialAccount;

  const AddEditAccountPage({super.key, this.initialAccount});

  @override
  ConsumerState<AddEditAccountPage> createState() => _AddEditAccountPageState();
}

class _AddEditAccountPageState extends ConsumerState<AddEditAccountPage> {
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _nameController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _lastDigitsController;
  
  late AccountType _selectedType;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final account = widget.initialAccount;
    _nameController = TextEditingController(text: account?.name ?? '');
    _bankNameController = TextEditingController(text: account?.bankName ?? '');
    _lastDigitsController = TextEditingController(text: account?.lastFourDigits ?? '');
    _selectedType = account?.type ?? AccountType.bank;
    _isDefault = account?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _lastDigitsController.dispose();
    super.dispose();
  }

  void _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final bankName = _bankNameController.text.trim();
    final lastFourDigits = _lastDigitsController.text.trim();

    final activeWallet = ref.read(activeWalletProvider);

    final account = Account(
      id: widget.initialAccount?.id ?? const Uuid().v4(),
      name: name,
      type: _selectedType,
      bankName: bankName.isNotEmpty ? bankName : null,
      lastFourDigits: lastFourDigits.isNotEmpty ? lastFourDigits : null,
      isDefault: _isDefault,
      isDeleted: widget.initialAccount?.isDeleted ?? false,
      currencyCode: widget.initialAccount?.currencyCode ?? activeWallet.currencyCode,
    );

    try {
      if (widget.initialAccount == null) {
        await ref.read(accountsNotifierProvider.notifier).addAccount(account);
      } else {
        await ref.read(accountsNotifierProvider.notifier).updateAccount(account);
      }

      // If we set this newly saved/edited account as default, handle the toggle of other defaults
      if (_isDefault) {
        await ref.read(accountsNotifierProvider.notifier).setDefault(account.id);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialAccount == null 
                ? 'Account created successfully' 
                : 'Account updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving account: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialAccount != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Account' : 'Add Account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name *',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an account name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Dropdown List for AccountType
            DropdownButtonFormField<AccountType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Account Type *',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              items: AccountType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_toTypeLabel(type)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Bank Name Field (Optional, only show if applicable, e.g. bank or credit cards)
            TextFormField(
              controller: _bankNameController,
              decoration: const InputDecoration(
                labelText: 'Bank Name (Optional)',
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                hintText: 'e.g., Chase, Wells Fargo',
              ),
            ),
            const SizedBox(height: 20),

            // Last 4 Digits (Optional)
            TextFormField(
              controller: _lastDigitsController,
              decoration: const InputDecoration(
                labelText: 'Last 4 Digits (Optional)',
                prefixIcon: Icon(Icons.pin_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                hintText: 'e.g., 1234',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 20),

            // Default Checkbox/Switch
            SwitchListTile(
              title: const Text(
                'Set as Default Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Used automatically for new manual entries'),
              value: _isDefault,
              onChanged: (val) {
                setState(() {
                  _isDefault = val;
                });
              },
              secondary: Icon(
                _isDefault ? Icons.star : Icons.star_border,
                color: _isDefault ? Colors.amber : Colors.grey,
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _saveAccount,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEditing ? 'Save Changes' : 'Create Account',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _toTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.bank:
        return 'Bank Account';
      case AccountType.wallet:
        return 'Digital Wallet';
      case AccountType.cash:
        return 'Cash / Physical';
      case AccountType.credit:
        return 'Credit Card';
    }
  }
}
