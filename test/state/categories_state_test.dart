import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/state/categories_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads default categories with expected stable icon keys', () async {
    await CategoriesState.instance.load();

    final categories = CategoriesState.instance.categories;
    expect(categories.firstWhere((c) => c.id == 'coding').iconKey, 'code');
    expect(
      categories.firstWhere((c) => c.id == 'coding').icon,
      CupertinoIcons.chevron_left_slash_chevron_right,
    );
    expect(categories.firstWhere((c) => c.id == 'other').iconKey, 'ellipsis');
  });

  test('migrates legacy stored icon code points to icon keys', () async {
    SharedPreferences.setMockInitialValues({
      'focus_categories_v1':
          '''
        [
          {"id":"coding","name":"Coding","iconCodePoint":${CupertinoIcons.chevron_left_slash_chevron_right.codePoint}},
          {"id":"writing","name":"Writing","iconCodePoint":${CupertinoIcons.pencil.codePoint}}
        ]
      ''',
    });

    await CategoriesState.instance.load();

    final categories = CategoriesState.instance.categories;
    expect(categories.firstWhere((c) => c.id == 'coding').iconKey, 'code');
    expect(categories.firstWhere((c) => c.id == 'writing').iconKey, 'pencil');
  });
}
