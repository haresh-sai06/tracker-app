import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tracker_app/domain/entities/category.dart';
import 'package:tracker_app/presentation/providers/categories_provider.dart';

class AddCategoryPage extends ConsumerStatefulWidget {
  final Category? initialCategory;

  const AddCategoryPage({
    super.key,
    this.initialCategory,
  });

  @override
  ConsumerState<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends ConsumerState<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late int _selectedColor;
  late IconData _selectedIcon;
  bool _isDefault = false;

  bool _isInit = true;

  final List<int> _colorsList = const [
    0xFF4CAF50, // Emerald Green
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFFE91E63, // Rose Pink
    0xFF9C27B0, // Violet Purple
    0xFF3F51B5, // Deep Indigo
    0xFFF44336, // Crimson Red
    0xFF009688, // Teal Mint
    0xFFFFC107, // Amber Yellow
    0xFF795548, // Mocha Brown
    0xFF00BCD4, // Cyan Sky
    0xFF607D8B, // Slate Blue Grey
  ];

  final List<IconData> _curatedIcons = const [
    Icons.shopping_cart,
    Icons.restaurant,
    Icons.fastfood,
    Icons.local_cafe,
    Icons.shopping_bag,
    Icons.directions_car,
    Icons.flight,
    Icons.train,
    Icons.pedal_bike,
    Icons.commute,
    Icons.home,
    Icons.electric_bolt,
    Icons.water_drop,
    Icons.wifi,
    Icons.phone_android,
    Icons.receipt,
    Icons.credit_card,
    Icons.sports_esports,
    Icons.movie,
    Icons.music_note,
    Icons.palette,
    Icons.liquor,
    Icons.medical_services,
    Icons.fitness_center,
    Icons.spa,
    Icons.pets,
    Icons.healing,
    Icons.savings,
    Icons.work,
    Icons.school,
    Icons.trending_up,
    Icons.paid,
    Icons.wallet,
    Icons.account_balance,
    Icons.star,
    Icons.emoji_events,
    Icons.build,
    Icons.card_giftcard,
    Icons.camera_alt,
    Icons.beach_access,
    Icons.brush,
    Icons.flight_takeoff,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = _colorsList[0];
    _selectedIcon = _curatedIcons[0];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final cat = widget.initialCategory;
      if (cat != null) {
        _nameController.text = cat.name;
        _isDefault = cat.isDefault;
        _selectedColor = cat.colorValue;
        
        // Find matching IconData if present in curated
        _selectedIcon = _curatedIcons.firstWhere(
          (i) => i.codePoint == cat.iconCodePoint,
          orElse: () => IconData(cat.iconCodePoint, fontFamily: 'MaterialIcons'),
        );
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final scaffoldMsg = ScaffoldMessenger.of(context);

    final isEdit = widget.initialCategory != null;
    final catId = isEdit ? widget.initialCategory!.id : _nameController.text.trim().toLowerCase().replaceAll(' ', '_');

    final cat = Category(
      id: isEdit ? widget.initialCategory!.id : catId,
      name: _nameController.text.trim(),
      iconCodePoint: _selectedIcon.codePoint,
      colorValue: _selectedColor,
      isDefault: _isDefault,
      isDeleted: false,
    );

    if (isEdit) {
      await ref.read(categoriesNotifierProvider.notifier).updateCat(cat);
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Text('Category successfully updated.'),
          backgroundColor: Colors.teal,
        ),
      );
    } else {
      await ref.read(categoriesNotifierProvider.notifier).add(cat);
      scaffoldMsg.showSnackBar(
        const SnackBar(
          content: Text('Category successfully created.'),
          backgroundColor: Colors.green,
        ),
      );
    }

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialCategory != null;
    final disableDefaultToggle = widget.initialCategory?.isDefault ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Category Preview Card ---
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(_selectedColor).withAlpha(15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Color(_selectedColor).withAlpha(80), width: 1.5),
                  ),
                  child: Icon(
                    _selectedIcon,
                    color: Color(_selectedColor),
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Name Field ---
              Text(
                'Category Name',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Subscriptions',
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
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // --- Color Picker ---
              Text(
                'Theme Color',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorsList.length,
                  separatorBuilder: (context, _) => const SizedBox(width: 10),
                  itemBuilder: (context, idx) {
                    final colVal = _colorsList[idx];
                    final isSelected = _selectedColor == colVal;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = colVal;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(colVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: Color(colVal).withAlpha(100),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- Icon Picker Grid ---
              Text(
                'Select Icon',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80)),
                ),
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _curatedIcons.length,
                  itemBuilder: (context, idx) {
                    final icon = _curatedIcons[idx];
                    final isSelected = _selectedIcon == icon;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColor).withAlpha(35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Color(_selectedColor) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Color(_selectedColor) : Theme.of(context).colorScheme.onSurface,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- System Default Toggle ---
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: SwitchListTile(
                  title: const Text('Mark as System Default'),
                  subtitle: const Text('Default categories are pinned at the top'),
                  value: _isDefault,
                  onChanged: disableDefaultToggle
                      ? null // disabled for default categories
                      : (bool val) {
                          setState(() {
                            _isDefault = val;
                          });
                        },
                ),
              ),
              const SizedBox(height: 40),

              // --- Action Save ---
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  isEdit ? 'Save Changes' : 'Create Category',
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
