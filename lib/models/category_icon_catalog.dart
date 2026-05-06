import 'package:flutter/cupertino.dart';

class CategoryIconOption {
  const CategoryIconOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const fallbackCategoryIconKey = 'other';
const fallbackCategoryIcon = CupertinoIcons.square_grid_2x2;

const categoryIconOptions = <CategoryIconOption>[
  CategoryIconOption(key: 'book', label: 'book', icon: CupertinoIcons.book),
  CategoryIconOption(
    key: 'pencil',
    label: 'pencil',
    icon: CupertinoIcons.pencil,
  ),
  CategoryIconOption(
    key: 'code',
    label: 'code',
    icon: CupertinoIcons.chevron_left_slash_chevron_right,
  ),
  CategoryIconOption(
    key: 'search',
    label: 'search',
    icon: CupertinoIcons.search,
  ),
  CategoryIconOption(
    key: 'hammer',
    label: 'hammer',
    icon: CupertinoIcons.hammer,
  ),
  CategoryIconOption(
    key: 'ellipsis',
    label: 'ellipsis',
    icon: CupertinoIcons.ellipsis,
  ),
  CategoryIconOption(
    key: 'lightbulb',
    label: 'lightbulb',
    icon: CupertinoIcons.lightbulb,
  ),
  CategoryIconOption(
    key: 'briefcase',
    label: 'briefcase',
    icon: CupertinoIcons.briefcase,
  ),
  CategoryIconOption(
    key: 'desktopcomputer',
    label: 'desktop computer',
    icon: CupertinoIcons.desktopcomputer,
  ),
  CategoryIconOption(
    key: 'laptopcomputer',
    label: 'laptop computer',
    icon: CupertinoIcons.device_laptop,
  ),
  CategoryIconOption(
    key: 'paintbrush',
    label: 'paintbrush',
    icon: CupertinoIcons.paintbrush,
  ),
  CategoryIconOption(
    key: 'music_note',
    label: 'music',
    icon: CupertinoIcons.music_note,
  ),
  CategoryIconOption(
    key: 'headphones',
    label: 'headphones',
    icon: CupertinoIcons.headphones,
  ),
  CategoryIconOption(
    key: 'sportscourt',
    label: 'sports',
    icon: CupertinoIcons.sportscourt,
  ),
  CategoryIconOption(key: 'heart', label: 'heart', icon: CupertinoIcons.heart),
  CategoryIconOption(
    key: 'leaf',
    label: 'leaf',
    icon: CupertinoIcons.leaf_arrow_circlepath,
  ),
  CategoryIconOption(key: 'flame', label: 'flame', icon: CupertinoIcons.flame),
  CategoryIconOption(
    key: 'rocket',
    label: 'rocket',
    icon: CupertinoIcons.rocket,
  ),
  CategoryIconOption(
    key: 'folder',
    label: 'folder',
    icon: CupertinoIcons.folder,
  ),
  CategoryIconOption(
    key: 'doc_text',
    label: 'document',
    icon: CupertinoIcons.doc_text,
  ),
  CategoryIconOption(
    key: 'calendar',
    label: 'calendar',
    icon: CupertinoIcons.calendar,
  ),
  CategoryIconOption(key: 'clock', label: 'clock', icon: CupertinoIcons.clock),
  CategoryIconOption(
    key: 'chart',
    label: 'chart',
    icon: CupertinoIcons.chart_bar,
  ),
  CategoryIconOption(
    key: 'graph_circle',
    label: 'graph',
    icon: CupertinoIcons.graph_circle,
  ),
  CategoryIconOption(
    key: 'camera',
    label: 'camera',
    icon: CupertinoIcons.camera,
  ),
  CategoryIconOption(
    key: 'video',
    label: 'video',
    icon: CupertinoIcons.videocam,
  ),
  CategoryIconOption(key: 'mic', label: 'microphone', icon: CupertinoIcons.mic),
  CategoryIconOption(key: 'globe', label: 'globe', icon: CupertinoIcons.globe),
  CategoryIconOption(
    key: 'book_fill',
    label: 'book fill',
    icon: CupertinoIcons.book_fill,
  ),
  CategoryIconOption(
    key: 'person',
    label: 'person',
    icon: CupertinoIcons.person,
  ),
  CategoryIconOption(
    key: 'person_2',
    label: 'team',
    icon: CupertinoIcons.person_2,
  ),
  CategoryIconOption(
    key: 'chat_bubble',
    label: 'chat',
    icon: CupertinoIcons.chat_bubble,
  ),
  CategoryIconOption(key: 'bell', label: 'bell', icon: CupertinoIcons.bell),
  CategoryIconOption(key: 'star', label: 'star', icon: CupertinoIcons.star),
  CategoryIconOption(key: 'tag', label: 'tag', icon: CupertinoIcons.tag),
  CategoryIconOption(key: 'tray', label: 'tray', icon: CupertinoIcons.tray),
  CategoryIconOption(
    key: 'paperplane',
    label: 'paperplane',
    icon: CupertinoIcons.paperplane,
  ),
  CategoryIconOption(
    key: 'game_controller',
    label: 'game',
    icon: CupertinoIcons.game_controller,
  ),
  CategoryIconOption(
    key: 'wrench',
    label: 'wrench',
    icon: CupertinoIcons.wrench,
  ),
  CategoryIconOption(
    key: fallbackCategoryIconKey,
    label: 'other',
    icon: fallbackCategoryIcon,
  ),
];

IconData categoryIconForKey(String? key) {
  final normalized = normalizeCategoryIconKey(key);
  if (normalized == null) return fallbackCategoryIcon;
  return categoryIconOptions
      .firstWhere((option) => option.key == normalized)
      .icon;
}

String? normalizeCategoryIconKey(String? key) {
  final normalized = _cleanString(key);
  if (normalized == null) return null;
  for (final option in categoryIconOptions) {
    if (option.key == normalized) return normalized;
  }
  return null;
}

String categoryIconKeyForIconData(IconData icon) {
  final option = categoryIconOptions.where((option) {
    final candidate = option.icon;
    return candidate.codePoint == icon.codePoint &&
        candidate.fontFamily == icon.fontFamily &&
        candidate.fontPackage == icon.fontPackage;
  }).firstOrNull;
  return option?.key ?? fallbackCategoryIconKey;
}

String? categoryIconKeyForStoredIcon({
  required int codePoint,
  String? fontFamily,
  String? fontPackage,
}) {
  final normalizedFamily = _cleanString(fontFamily) ?? CupertinoIcons.iconFont;
  final normalizedPackage = _cleanString(fontPackage);

  for (final option in categoryIconOptions) {
    final icon = option.icon;
    final packageMatches =
        normalizedPackage == null ||
        normalizedPackage == icon.fontPackage ||
        normalizedPackage == 'packages/${icon.fontPackage}';
    if (icon.codePoint == codePoint &&
        icon.fontFamily == normalizedFamily &&
        packageMatches) {
      return option.key;
    }
  }
  return null;
}

String? _cleanString(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed.toLowerCase() == 'null') {
    return null;
  }
  return trimmed;
}
