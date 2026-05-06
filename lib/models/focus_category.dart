import 'package:flutter/cupertino.dart';

import 'package:deep_work/models/category_icon_catalog.dart';

class FocusCategory {
  const FocusCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    this.iconKey,
    this.iconFontFamily,
    this.iconFontPackage,
  });

  final String id;
  final String name;
  final int iconCodePoint;
  final String? iconKey;
  final String? iconFontFamily;
  final String? iconFontPackage;

  IconData get icon {
    final key =
        iconKey ??
        categoryIconKeyForStoredIcon(
          codePoint: iconCodePoint,
          fontFamily: iconFontFamily,
          fontPackage: iconFontPackage,
        );
    if (key != null) return categoryIconForKey(key);
    return fallbackCategoryIcon;
  }

  FocusCategory copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? iconKey,
    String? iconFontFamily,
    String? iconFontPackage,
  }) {
    return FocusCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconKey: iconKey ?? this.iconKey,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
    );
  }
}
