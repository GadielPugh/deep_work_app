import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/models/focus_category.dart';

class CategoriesState extends ChangeNotifier {
  CategoriesState._();

  static final CategoriesState instance = CategoriesState._();

  static const _keyCategories = 'focus_categories_v1';

  List<FocusCategory> _categories = const [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<FocusCategory> get categories => List.unmodifiable(_categories);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyCategories);
    if (raw == null || raw.isEmpty) {
      _categories = _defaultCategories;
      _isLoaded = true;
      notifyListeners();
      await _persist();
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _categories = decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .where((e) => e.name.trim().isNotEmpty)
          .toList();
      if (_categories.isEmpty) {
        _categories = _defaultCategories;
      }
    } catch (_) {
      _categories = _defaultCategories;
    }

    _isLoaded = true;
    notifyListeners();
  }

  FocusCategory? byId(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> addCategory(FocusCategory category) async {
    _categories = [..._categories, category];
    notifyListeners();
    await _persist();
  }

  Future<void> updateCategory(FocusCategory category) async {
    _categories = _categories.map((c) => c.id == category.id ? category : c).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteCategory(String id) async {
    _categories = _categories.where((c) => c.id != id).toList();
    if (_categories.isEmpty) {
      _categories = _defaultCategories;
    }
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_categories.map(_toJson).toList());
    await prefs.setString(_keyCategories, payload);
  }

  static Map<String, dynamic> _toJson(FocusCategory c) {
    return {
      'id': c.id,
      'name': c.name,
      'iconCodePoint': c.iconCodePoint,
      'iconFontFamily': c.iconFontFamily,
      'iconFontPackage': c.iconFontPackage,
    };
  }

  static FocusCategory _fromJson(Map<String, dynamic> json) {
    return FocusCategory(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ?? CupertinoIcons.square.codePoint,
      iconFontFamily: json['iconFontFamily']?.toString(),
      iconFontPackage: json['iconFontPackage']?.toString(),
    );
  }

  static final List<FocusCategory> _defaultCategories = [
    FocusCategory(
      id: 'reading',
      name: 'Reading',
      iconCodePoint: CupertinoIcons.book.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
    FocusCategory(
      id: 'writing',
      name: 'Writing',
      iconCodePoint: CupertinoIcons.pencil.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
    FocusCategory(
      id: 'coding',
      name: 'Coding',
      iconCodePoint: CupertinoIcons.chevron_left_slash_chevron_right.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
    FocusCategory(
      id: 'review',
      name: 'Review',
      iconCodePoint: CupertinoIcons.search.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
    FocusCategory(
      id: 'work',
      name: 'Work',
      iconCodePoint: CupertinoIcons.hammer.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
    FocusCategory(
      id: 'other',
      name: 'Other',
      iconCodePoint: CupertinoIcons.ellipsis.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    ),
  ];
}
