import 'package:flutter/cupertino.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Settings'),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                const [
                  _ProfileCard(
                    initial: 'G',
                    name: 'Gadiel',
                    email: 'gadiel@example.com',
                  ),
                  SizedBox(height: 16),
                  _SettingsGroupCard(
                    items: [
                      _SettingsItem(
                        icon: CupertinoIcons.bell,
                        iconBg: Color(0xFFEAF2FF),
                        iconColor: CupertinoColors.activeBlue,
                        title: 'Notifications',
                        subtitle: 'Manage your alerts',
                      ),
                      _SettingsItem(
                        icon: CupertinoIcons.moon,
                        iconBg: Color(0xFFEDEAFF),
                        iconColor: CupertinoColors.systemIndigo,
                        title: 'Appearance',
                        subtitle: 'Light mode',
                      ),
                      _SettingsItem(
                        icon: CupertinoIcons.question_circle,
                        iconBg: Color(0xFFE9F8EE),
                        iconColor: CupertinoColors.systemGreen,
                        title: 'Help & Support',
                        subtitle: 'FAQs and contact',
                      ),
                      _SettingsItem(
                        icon: CupertinoIcons.info_circle,
                        iconBg: Color(0xFFF0F0F3),
                        iconColor: CupertinoColors.systemGrey,
                        title: 'About',
                        subtitle: 'Version 1.0.0',
                      ),
                    ],
                  ),
                  SizedBox(height: 28),
                  Center(
                    child: Text(
                      'Made with focus and intention',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.tertiaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.initial,
    required this.name,
    required this.email,
  });

  final String initial;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Color(0xFF3D5AFE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: CupertinoColors.tertiaryLabel,
          ),
        ],
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.items});

  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SettingsRow(item: items[i]),
            if (i != items.length - 1)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 70),
                color: CupertinoColors.separator.withValues(alpha: 0.35),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.item});

  final _SettingsItem item;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onPressed: () {},
      color: CupertinoColors.white.withValues(alpha: 0.001),
      borderRadius: BorderRadius.zero,
      pressedOpacity: 0.92,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: CupertinoColors.tertiaryLabel,
          ),
        ],
      ),
    );
  }
}
