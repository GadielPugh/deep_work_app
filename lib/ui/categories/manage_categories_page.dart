import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/ui/categories/category_icon_catalog.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final _state = CategoriesState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    if (!_state.isLoaded) {
      _state.load();
    }
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  Future<void> _openForm({FocusCategory? editing}) async {
    final result = await Navigator.of(context).push<FocusCategory>(
      CupertinoPageRoute(
        builder: (_) => _CategoryFormPage(editing: editing),
      ),
    );
    if (result == null) return;
    if (editing == null) {
      await _state.addCategory(result);
    } else {
      await _state.updateCategory(result);
    }
  }

  Future<void> _confirmDelete(FocusCategory category) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete category?'),
        content: Text('This removes "${category.name}" from your list.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              await _state.deleteCategory(category.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _state.categories;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Categories'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openForm(),
          child: const Icon(CupertinoIcons.add_circled),
        ),
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = categories[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(c.icon, color: CupertinoColors.activeBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 28,
                    onPressed: () => _openForm(editing: c),
                    child: const Icon(CupertinoIcons.pencil, size: 20),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 28,
                    onPressed: categories.length <= 1 ? null : () => _confirmDelete(c),
                    child: const Icon(
                      CupertinoIcons.delete,
                      size: 20,
                      color: CupertinoColors.systemRed,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryFormPage extends StatefulWidget {
  const _CategoryFormPage({this.editing});

  final FocusCategory? editing;

  @override
  State<_CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<_CategoryFormPage> {
  late final TextEditingController _nameController;
  late IconData _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _selectedIcon = widget.editing?.icon ?? CupertinoIcons.square_grid_2x2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _normalizedId(String name) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return normalized.isEmpty ? 'category_${DateTime.now().millisecondsSinceEpoch}' : normalized;
  }

  String _uniqueIdFromName(String name) {
    final base = _normalizedId(name);
    final existingIds = CategoriesState.instance.categories.map((c) => c.id).toSet();
    if (!existingIds.contains(base)) return base;
    var i = 2;
    while (existingIds.contains('${base}_$i')) {
      i++;
    }
    return '${base}_$i';
  }

  Future<void> _pickIcon() async {
    final icon = await Navigator.of(context).push<IconData>(
      CupertinoPageRoute(builder: (_) => const _IconPickerPage()),
    );
    if (icon == null) return;
    setState(() => _selectedIcon = icon);
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final editing = widget.editing;
    final category = FocusCategory(
      id: editing?.id ?? _uniqueIdFromName(name),
      name: name,
      iconCodePoint: _selectedIcon.codePoint,
      iconFontFamily: _selectedIcon.fontFamily,
      iconFontPackage: _selectedIcon.fontPackage,
    );
    Navigator.of(context).pop(category);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.editing == null ? 'New Category' : 'Edit Category'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Category name',
                style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'Ex: Planning',
                padding: const EdgeInsets.all(14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Icon',
                style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickIcon,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(_selectedIcon, size: 24, color: CupertinoColors.activeBlue),
                      const SizedBox(width: 12),
                      const Text('Choose icon'),
                      const Spacer(),
                      const Icon(CupertinoIcons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: _save,
                child: const Text('Save category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPickerPage extends StatefulWidget {
  const _IconPickerPage();

  @override
  State<_IconPickerPage> createState() => _IconPickerPageState();
}

class _IconPickerPageState extends State<_IconPickerPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = categoryIconOptions.where((option) {
      if (_query.isEmpty) return true;
      return option.label.contains(_query) || option.key.contains(_query);
    }).toList();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Pick Icon'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search icon name',
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(item.icon),
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: CupertinoColors.activeBlue),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
