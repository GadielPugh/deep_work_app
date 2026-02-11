import 'package:flutter/cupertino.dart';
import 'package:deep_work/processSession.dart';
import 'package:deep_work/session_type.dart' as st;

class StartSessionPage extends StatefulWidget {
  const StartSessionPage({super.key});

  @override
  State<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends State<StartSessionPage> {
  st.SessionType _selectedType = st.SessionType.reading;
  final _goalController = TextEditingController();

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Start a Focus Session',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'What do you want to accomplish?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _goalController,
                placeholder: 'What do you want to accomplish?',
                padding: const EdgeInsets.all(16),
                maxLines: 4,
                minLines: 3,
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Session Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 12),
              _buildSessionTypeSelector(),
              const SizedBox(height: 32),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (context) => ProcessSessionPage(
                        sessionType: _selectedType,
                        goal: _goalController.text.trim().isEmpty ? null : _goalController.text.trim(),
                      ),
                    ),
                  );
                },
                child: const Text('Begin Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTypeSelector() {
    return Column(
      children: [


        Row(
          children: [
            Expanded(child: _sessionTypeButton(st.SessionType.reading, CupertinoIcons.book, 'Reading')),
            const SizedBox(width: 12),
            Expanded(child: _sessionTypeButton(st.SessionType.writing, CupertinoIcons.pencil, 'Writing')),
            const SizedBox(width: 12),
            Expanded(child: _sessionTypeButton(st.SessionType.coding, CupertinoIcons.chevron_left_slash_chevron_right, 'Coding')),
          ],
        ),



        const SizedBox(height: 10),


        Row(
          children: [
            Expanded(child: _sessionTypeButton(st.SessionType.review, CupertinoIcons.search, 'Review')),
            const SizedBox(width: 12),
            Expanded(child: _sessionTypeButton(st.SessionType.work, CupertinoIcons.hammer, 'Work')),
            const SizedBox(width: 12),
            Expanded(child: _sessionTypeButton(st.SessionType.other, CupertinoIcons.ellipsis, 'Other')),
          ],
        ),



      ],
    );
  }

  Widget _sessionTypeButton(st.SessionType type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.activeBlue.withOpacity(0.1)
              : CupertinoColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
