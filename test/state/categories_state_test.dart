import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/state/categories_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CategoriesState.instance.resetForTesting();
  });

  test('loads legacy Cupertino icons without font package safely', () async {
    SharedPreferences.setMockInitialValues({
      'focus_categories_v1': jsonEncode([
        {
          'id': 'reading',
          'name': 'Reading',
          'iconCodePoint': CupertinoIcons.book.codePoint,
          'iconFontFamily': CupertinoIcons.iconFont,
        },
      ]),
    });

    await CategoriesState.instance.load();

    final category = CategoriesState.instance.categories.single;
    expect(category.iconKey, 'book');
    expect(category.icon, CupertinoIcons.book);
    expect(category.iconFontPackage, CupertinoIcons.iconFontPackage);

    final prefs = await SharedPreferences.getInstance();
    final persisted =
        jsonDecode(prefs.getString('focus_categories_v1')!) as List<dynamic>;
    final persistedCategory = persisted.single as Map<String, dynamic>;
    expect(persistedCategory['iconKey'], 'book');
    expect(
      persistedCategory['iconFontPackage'],
      CupertinoIcons.iconFontPackage,
    );
  });

  test('supports category add, edit, and delete', () async {
    SharedPreferences.setMockInitialValues({});

    await CategoriesState.instance.load();

    final category = FocusCategory(
      id: 'planning',
      name: 'Planning',
      iconKey: 'calendar',
      iconCodePoint: CupertinoIcons.calendar.codePoint,
      iconFontFamily: CupertinoIcons.iconFont,
      iconFontPackage: CupertinoIcons.iconFontPackage,
    );

    await CategoriesState.instance.addCategory(category);
    expect(CategoriesState.instance.byId('planning')?.name, 'Planning');

    await CategoriesState.instance.updateCategory(
      category.copyWith(name: 'Daily Planning'),
    );
    expect(CategoriesState.instance.byId('planning')?.name, 'Daily Planning');

    await CategoriesState.instance.deleteCategory('planning');
    expect(CategoriesState.instance.byId('planning'), isNull);
  });
}
