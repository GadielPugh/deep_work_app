import 'package:flutter/cupertino.dart';

class FocusCategory {
  const FocusCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    this.iconFontFamily,
    this.iconFontPackage,
  });

  final String id;
  final String name;
  final int iconCodePoint;
  final String? iconFontFamily;
  final String? iconFontPackage;

  IconData get icon => IconData(
        iconCodePoint,
        fontFamily: iconFontFamily ?? CupertinoIcons.iconFont,
        fontPackage: iconFontPackage,
      );

  FocusCategory copyWith({
    String? id,
    String? name,
    int? iconCodePoint,
    String? iconFontFamily,
    String? iconFontPackage,
  }) {
    return FocusCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      iconFontPackage: iconFontPackage ?? this.iconFontPackage,
    );
  }
}
