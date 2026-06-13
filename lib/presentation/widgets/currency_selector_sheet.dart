import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/domain/entities/currency_wallet.dart';
import 'package:tracker_app/presentation/providers/wallets_provider.dart';
import 'package:tracker_app/core/utils/currency_utils.dart';

class CurrencySelectorSheet extends ConsumerStatefulWidget {
  const CurrencySelectorSheet({super.key});

  @override
  ConsumerState<CurrencySelectorSheet> createState() => _CurrencySelectorSheetState();
}

class _CurrencySelectorSheetState extends ConsumerState<CurrencySelectorSheet> {
  bool _isAdding = false;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _labelController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletListProvider);
    final activeWallet = ref.watch(activeWalletProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: SafeArea(
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isAdding ? 'Add New Currency' : 'Select Currency Wallet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!_isAdding)
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            setState(() {
                              _isAdding = true;
                            });
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            setState(() {
                              _isAdding = false;
                              _codeController.clear();
                              _labelController.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
                
                const Divider(),
                
                // Body content
                Expanded(
                  child: _isAdding
                      ? _buildAddWalletForm()
                      : walletsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Center(child: Text('Error: $err')),
                          data: (wallets) => ListView.builder(
                            key: const ValueKey('wallet_list'),
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: wallets.length,
                            itemBuilder: (context, index) {
                              final wallet = wallets[index];
                              final isActive = wallet.currencyCode == activeWallet.currencyCode;
                              final flag = CurrencyUtils.flagEmojiFor(wallet.currencyCode);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  color: isActive
                                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                                      : null,
                                  elevation: isActive ? 2 : 0,
                                  shape: RoundedRectangleBorder(
                                    side: BorderSide(
                                      color: isActive
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.outlineVariant,
                                      width: isActive ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    key: ValueKey('wallet_tile_${wallet.currencyCode}'),
                                    leading: CircleAvatar(
                                      backgroundColor: isActive
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.secondaryContainer,
                                      child: Text(
                                        flag,
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    title: Text(
                                      wallet.label,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      wallet.currencyCode,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                    trailing: isActive
                                        ? Opacity(
                                            opacity: 1,
                                            child: Icon(
                                              Icons.check_circle,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          )
                                        : null,
                                    onTap: () async {
                                      await ref.read(walletListProvider.notifier).switchWallet(wallet);
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddWalletForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'ISO Currency Code',
              hintText: 'e.g., USD, EUR, GBP',
              prefixIcon: Icon(Icons.currency_exchange),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            validator: (value) {
              if (value == null || value.trim().length != 3) {
                return 'Please enter a valid 3-letter ISO Code';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Wallet Label / Name',
              hintText: 'e.g., US Dollar Wallet',
              prefixIcon: Icon(Icons.label),
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a wallet label';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                final code = _codeController.text.toUpperCase().trim();
                final label = _labelController.text.trim();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Adding and initializing wallet...')),
                );

                await ref.read(walletListProvider.notifier).addWallet(code, label);
                
                // Clear state
                setState(() {
                  _isAdding = false;
                  _codeController.clear();
                  _labelController.clear();
                });
                
                // Refresh list
                ref.invalidate(walletListProvider);
              }
            },
            child: const Text('Add Currency Wallet'),
          ),
        ],
      ),
    );
  }
}

/// Helper method to present this selector
void showCurrencySelector(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const CurrencySelectorSheet(),
  );
}
