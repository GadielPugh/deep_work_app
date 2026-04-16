import 'package:flutter/cupertino.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/ui/1_principal_function/processSession.dart';

class StartSessionPage extends StatefulWidget {
  const StartSessionPage({super.key});

  @override
  State<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends State<StartSessionPage> {
  final _categoriesState = CategoriesState.instance;
  String? _selectedCategoryId;
  final _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categoriesState.addListener(_onCategoriesChanged);
    if (!_categoriesState.isLoaded) {
      _categoriesState.load();
    } else if (_categoriesState.categories.isNotEmpty) {
      _selectedCategoryId = _categoriesState.categories.first.id;
    }
  }

  @override
  void dispose() {
    _categoriesState.removeListener(_onCategoriesChanged);
    _goalController.dispose();
    super.dispose();
  }

  void _onCategoriesChanged() {
    if (_selectedCategoryId == null && _categoriesState.categories.isNotEmpty) {
      _selectedCategoryId = _categoriesState.categories.first.id;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesState.categories;
    FocusCategory? selectedCategory;
    if (_selectedCategoryId != null) {
      for (final category in categories) {
        if (category.id == _selectedCategoryId) {
          selectedCategory = category;
          break;
        }
      }
    }
    selectedCategory ??= categories.isNotEmpty ? categories.first : null;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Start a Focus Session',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What do you want to accomplish?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _goalController,
                placeholder: 'What do you want to accomplish?',
                padding: const EdgeInsets.all(16),
                maxLines: 4,
                minLines: 3,
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Session Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              _buildSessionTypeSelector(),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: selectedCategory == null
                    ? null
                    : () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => ProcessSessionPage(
                        category: selectedCategory!,
                        goal: _goalController.text.trim().isEmpty ? null : _goalController.text.trim(),
                      ),
                    ),
                  );
                },
                child: const Text('Begin Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTypeSelector() {
    final categories = _categoriesState.categories;
    if (categories.isEmpty) {
      return const Text(
        'Create at least one category in Home to start.',
        style: TextStyle(color: CupertinoColors.secondaryLabel),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final category in categories)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 64) / 3,
            child: _categoryButton(category),
          ),
      ],
    );
  }

  Widget _categoryButton(FocusCategory category) {
    final isSelected = _selectedCategoryId == category.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = category.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue.withValues(alpha: 0.1)
              : CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
                    BoxShadow(
                      color: isSelected
                        ? const Color.fromARGB(255, 255, 255, 255)
                        : CupertinoColors.activeBlue,
                      //width: isSelected ? 5 : 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              category.icon,
              size: 28,
              color: isSelected
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
