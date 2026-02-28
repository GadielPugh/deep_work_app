import 'package:flutter/cupertino.dart';

import 'package:deep_work/database/session_repository.dart';
import 'package:deep_work/session_type.dart';

enum CompletionStatus {
  yes,
  partially,
  no,
}

class SessionReflectionPage extends StatefulWidget {
  const SessionReflectionPage({
    super.key,
    required this.goal,
    required this.focusMinutes,
    required this.sessionType,
    required this.startedAt,
    required this.stoppedAt,
  });

  final String goal;
  final int focusMinutes;
  final SessionType sessionType;
  final DateTime startedAt;
  final DateTime stoppedAt;

  @override
  State<SessionReflectionPage> createState() => _SessionReflectionPageState();
}

class _SessionReflectionPageState extends State<SessionReflectionPage> {
  CompletionStatus? _selectedStatus;
  final _reflectionController = TextEditingController();

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _finishSession() async {
    final status = _selectedStatus;
    if (status == null) return;
    final reflection = _reflectionController.text.trim();
    final durationSeconds = widget.focusMinutes * 60;
    await SessionRepository.insert(
      intention: widget.goal,
      category: widget.sessionType.name,
      startedAt: widget.startedAt,
      stoppedAt: widget.stoppedAt,
      durationSeconds: durationSeconds,
      outcome: status.name,
      reflection: reflection.isEmpty ? null : reflection,
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: Text(
          'Session Reflection',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You focused for ${widget.focusMinutes} minutes',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your intention was:',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.goal,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Did you complete your intention?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _CompletionButton(
                      label: 'Yes',
                      icon: CupertinoIcons.checkmark_circle,
                      color: CupertinoColors.systemGreen,
                      isSelected: _selectedStatus == CompletionStatus.yes,
                      onTap: () => setState(() => _selectedStatus = CompletionStatus.yes),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CompletionButton(
                      label: 'Partially',
                      icon: CupertinoIcons.minus_circle,
                      color: const Color.fromARGB(255, 231, 153, 45),
                      isSelected: _selectedStatus == CompletionStatus.partially,
                      onTap: () => setState(() => _selectedStatus = CompletionStatus.partially),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CompletionButton(
                      label: 'No',
                      icon: CupertinoIcons.xmark_circle,
                      color: CupertinoColors.systemRed,
                      isSelected: _selectedStatus == CompletionStatus.no,
                      onTap: () => setState(() => _selectedStatus = CompletionStatus.no),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'What helped or distracted you?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _reflectionController,
                placeholder: 'E.g., Found a quiet space, but phone notifications were distracting',
                padding: const EdgeInsets.all(16),
                maxLines: 4,
                minLines: 3,
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: _selectedStatus == null ? null : _finishSession,
                child: const Text('Finish Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  const _CompletionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : CupertinoColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : CupertinoColors.separator,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? color : CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
