import 'package:flutter/cupertino.dart';

enum SessionType {
  reading,
  writing,
  coding,
  review,
  work,
  other,
}

extension SessionTypeExtension on SessionType {
  IconData get icon {
    switch (this) {
      case SessionType.reading:
        return CupertinoIcons.book;
      case SessionType.writing:
        return CupertinoIcons.pencil;
      case SessionType.coding:
        return CupertinoIcons.chevron_left_slash_chevron_right;
      case SessionType.review:
        return CupertinoIcons.search;
      case SessionType.work:
        return CupertinoIcons.hammer;
      case SessionType.other:
        return CupertinoIcons.ellipsis;
    }
  }
}
