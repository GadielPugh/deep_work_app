import 'package:flutter/cupertino.dart';

import 'package:deep_work/services/app_services.dart';
import 'package:deep_work/services/feedback/feedback_service.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/ui/categories/manage_categories_page.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage();
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _categories = CategoriesState.instance;

  @override
  void initState() {
    super.initState();
    _categories.addListener(_onStateChanged);
    if (!_categories.isLoaded) {
      _categories.load();
    }
  }

  @override
  void dispose() {
    _categories.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  void _openCategories() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const ManageCategoriesPage()));
  }

  void _openFeedback() {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (_) => const FeedbackPage()));
  }

  @override
  Widget build(BuildContext context) {
    final categoryCount = _categories.categories.length;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('Settings'),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SettingsSection(
                  title: 'Categories',
                  children: [
                    _SettingsRow(
                      icon: CupertinoIcons.tag,
                      iconBackground: const Color(0xFFEAF2FF),
                      iconColor: CupertinoColors.activeBlue,
                      title: 'Manage Categories',
                      subtitle: '$categoryCount categories',
                      onTap: _openCategories,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: 'Send Feedback',
                  children: [
                    _SettingsRow(
                      icon: CupertinoIcons.envelope,
                      iconBackground: const Color(0xFFE9F8EE),
                      iconColor: CupertinoColors.systemGreen,
                      title: 'Send Feedback',
                      subtitle: 'Write feedback in the app',
                      onTap: _openFeedback,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;
  bool _hasMessage = false;
  String? _validationMessage;
  String? _statusMessage;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _nameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    final hasMessage = _messageController.text.trim().isNotEmpty;
    if (hasMessage == _hasMessage) return;
    setState(() => _hasMessage = hasMessage);
  }

  Future<void> _sendFeedback() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        _validationMessage = 'Please enter feedback before sending.';
        _statusMessage = null;
        _sent = false;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _validationMessage = null;
      _statusMessage = null;
      _sent = false;
    });

    try {
      await AppServices.feedbackService.sendFeedback(
        FeedbackSubmission(
          name: _nameController.text,
          contact: _contactController.text,
          message: message,
        ),
      );
      if (!mounted) return;
      setState(() {
        _messageController.clear();
        _hasMessage = false;
        _statusMessage = 'Feedback sent. Thank you.';
        _sent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Feedback could not be sent. Please try again.';
        _sent = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasMessage && !_isSending;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Send Feedback'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FieldLabel('Name'),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'Optional',
                    textInputAction: TextInputAction.next,
                    padding: const EdgeInsets.all(14),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Contact'),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _contactController,
                    placeholder: 'Optional',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    padding: const EdgeInsets.all(14),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Feedback'),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    key: const ValueKey('feedback_message_field'),
                    controller: _messageController,
                    placeholder: 'What should be improved?',
                    minLines: 5,
                    maxLines: 7,
                    padding: const EdgeInsets.all(14),
                  ),
                  if (_validationMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _validationMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _sent
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.secondaryLabel,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  CupertinoButton.filled(
                    key: const ValueKey('feedback_send_button'),
                    onPressed: canSend ? _sendFeedback : null,
                    child: _isSending
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Text('Send Feedback'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: CupertinoColors.secondaryLabel,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: CupertinoColors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}
