import 'package:flutter/cupertino.dart';

import 'package:deep_work/ui/categories/category_icon_catalog.dart';

class FocusCategory {
  const FocusCategory({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String iconKey;

  IconData get icon => categoryIconOptionForKey(iconKey).icon;

  FocusCategory copyWith({String? id, String? name, String? iconKey}) {
    return FocusCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}
