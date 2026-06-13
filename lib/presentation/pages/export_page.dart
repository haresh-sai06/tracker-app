import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';

import 'package:tracker_app/domain/entities/account.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/domain/entities/transaction.dart';
import 'package:tracker_app/presentation/providers/accounts_provider.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';
import 'package:tracker_app/presentation/providers/transactions_provider.dart';
import 'package:tracker_app/presentation/providers/settings_provider.dart';
import 'package:tracker_app/presentation/providers/permissions_provider.dart';
import 'package:tracker_app/core/services/pdf_export_service.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  DateTimeRange? _selectedDateRange;
  String _selectedAccountFilter = 'all'; // 'all' or specific accountId
  String _selectedCategoryFilter = 'all'; // 'all' or specific categoryId
  bool _isGenerating = false;

  static const _pdfChannel = MethodChannel('com.yourapp.tracker/pdf');

  @override
  void initState() {
    super.initState();
    // Default to this month
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<int> _getAndroidSdkLevel() async {
    if (!Platform.isAndroid) return 30;
    try {
      final version = Platform.operatingSystemVersion;
      final sdkMatch = RegExp(r'(?:SDK|API)\s+(\d+)', caseSensitive: false).firstMatch(version);
      if (sdkMatch != null) {
        return int.parse(sdkMatch.group(1)!);
      }
    } catch (_) {}
    return 28; // fallback
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final theme = Theme.of(context);
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Force the end date to end-of-day for proper inclusive indexing
        _selectedDateRange = DateTimeRange(
          start: picked.start,
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  void _quickSelectPeriod(int days) {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: now.subtract(Duration(days: days)),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    });
  }

  void _quickSelectThisMonth() {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    });
  }

  Future<Uint8List?> _generatePdfBytes() async {
    final txsAsync = ref.read(transactionsNotifierProvider);
    final accountsAsync = ref.read(accountsNotifierProvider);
    final categoriesAsync = ref.read(categoriesNotifierProvider);
    final settings = ref.read(settingsNotifierProvider).valueOrNull;

    final allTxs = txsAsync.valueOrNull ?? [];
    final accounts = accountsAsync.valueOrNull ?? [];
    final categories = categoriesAsync.valueOrNull ?? [];

    final currencySymbol = settings?.defaultCurrencyCode == 'EUR' ? '€' : '\$';

    // 1. Filter Transactions based on UI criteria
    final filteredTransactions = allTxs.where((tx) {
      if (tx.isDeleted) return false;

      // Date Range Filter
      if (_selectedDateRange != null) {
        if (tx.dateTime.isBefore(_selectedDateRange!.start) ||
            tx.dateTime.isAfter(_selectedDateRange!.end)) {
          return false;
        }
      }

      // Account Filter
      if (_selectedAccountFilter != 'all' && tx.accountId != _selectedAccountFilter) {
        return false;
      }

      // Category Filter
      if (_selectedCategoryFilter != 'all' && tx.category != _selectedCategoryFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort transactions by date descending for standard financial listing
    filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Determine account name for display
    String accountName = 'All Accounts';
    if (_selectedAccountFilter != 'all') {
      final activeAcc = accounts.where((a) => a.id == _selectedAccountFilter).firstOrNull;
      if (activeAcc != null) {
        accountName = activeAcc.name;
      }
    }

    // Prepare Category mappings ID -> Name
    final Map<String, String> categoryNames = {
      for (final cat in categories) cat.id: cat.name
    };

    // Prepare Export Config
    final config = ExportConfig(
      title: _selectedCategoryFilter == 'all'
          ? 'Transaction Ledger Statement'
          : 'Transactions - ${categoryNames[_selectedCategoryFilter] ?? "Filtered"}',
      dateRange: _selectedDateRange,
      accountName: accountName,
      currencySymbol: currencySymbol,
    );

    try {
      final bytes = await PdfExportService.generatePdf(
        transactions: filteredTransactions,
        config: config,
        categoryNames: categoryNames,
      );
      return bytes;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handlePdfPreview() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final pdfBytes = await _generatePdfBytes();
      if (pdfBytes != null) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Tracker_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pdf Preview failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _handlePdfSaveToDevice() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // 1. Android Specific Permission check for APIs < 29
      final sdkLevel = await _getAndroidSdkLevel();
      if (sdkLevel < 29) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Storage permission is required on older devices to save files directly.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isGenerating = false;
          });
          return;
        }
      }

      // 2. Generate PDF bytes
      final pdfBytes = await _generatePdfBytes();
      if (pdfBytes == null) {
        setState(() {
          _isGenerating = false;
        });
        return;
      }

      // 3. Save PDF using local channels
      final fileName = 'Tracker_Statement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final resultMessage = await _pdfChannel.invokeMethod<String>(
        'savePdfToDownloads',
        {
          'bytes': pdfBytes,
          'fileName': fileName,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultMessage ?? 'File saved to Downloads successfully!'),
            backgroundColor: Colors.teal,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountsAsync = ref.watch(accountsNotifierProvider);
    final categoriesAsync = ref.watch(categoriesNotifierProvider);
    final permissionsAsync = ref.watch(permissionsNotifierProvider);

    final accounts = accountsAsync.valueOrNull ?? [];
    final activeAccounts = accounts.where((acc) => !acc.isDeleted).toList();

    final categories = categoriesAsync.valueOrNull ?? [];
    final activeCategories = categories.where((cat) => !cat.isDeleted).toList();

    final permissions = permissionsAsync.valueOrNull;
    bool isStoragePermissionMissing = false;
    if (permissions != null && !permissions.storageGranted) {
      isStoragePermissionMissing = true;
    }

    final displayDateStr = _selectedDateRange == null
        ? 'Select Date Range'
        : '${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export PDF Statement'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Card
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withAlpha(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.primary.withAlpha(40)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 36, color: theme.colorScheme.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local Financial Statement',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Create high-fidelity statements sorted by account, period, or category locally on-device.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 1: DATE RANGE SELECTOR
                _buildSectionHeader('1. Select Period'),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(40)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _selectDateRange(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.date_range_rounded, color: theme.colorScheme.primary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date Range Selection',
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        displayDateStr,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.edit_calendar_rounded, size: 20, color: theme.colorScheme.outline),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        // Quick Pre-sets
                        Text(
                          'Quick presets',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _quickSelectThisMonth,
                                child: const Text('This Month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _quickSelectPeriod(30),
                                child: const Text('Last 30 Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _quickSelectPeriod(90),
                                child: const Text('Last 90 Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // SECTION 2: ACCOUNT FILTER dropdown
                _buildSectionHeader('2. Account Filter'),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_rounded),
                    labelText: 'Select Account Source',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  value: _selectedAccountFilter,
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All Accounts (Unified)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...activeAccounts.map((acc) {
                      return DropdownMenuItem<String>(
                        value: acc.id,
                        child: Text(acc.name),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAccountFilter = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                // SECTION 3: CATEGORY FILTER optional dropdown
                _buildSectionHeader('3. Category Filter (Optional)'),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_rounded),
                    labelText: 'Select Transaction Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  value: _selectedCategoryFilter,
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...activeCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategoryFilter = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 36),

                // STORAGE PERMISSION ERROR
                if (isStoragePermissionMissing) ...[
                  Card(
                    color: theme.colorScheme.errorContainer,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.gpp_bad_rounded, color: theme.colorScheme.error, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Storage Permission Required',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Permission to save documents is required on older devices. PDF export and compiling features are disabled.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer.withOpacity(0.9),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () async {
                                    final status = await Permission.storage.request();
                                    if (status.isGranted) {
                                      ref.read(permissionsNotifierProvider.notifier).refresh();
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'GRANT PERMISSION',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.error,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 16, color: theme.colorScheme.error),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ACTIONS BUTTONS
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isGenerating || isStoragePermissionMissing) ? null : _handlePdfPreview,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text(
                    'Preview / Print Statement',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_isGenerating || isStoragePermissionMissing) ? null : _handlePdfSaveToDevice,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Save PDF to Downloads',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Generating Full Screen Overlay
          if (_isGenerating)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: Card(
                  elevation: 4,
                  margin: EdgeInsets.all(32),
                  child: Padding(
                    padding: EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          'Generating Financial PDF...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This may take a moment. Processing your data.',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          letterSpacing: 1.1,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
