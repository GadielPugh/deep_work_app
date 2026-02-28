import 'package:flutter/cupertino.dart';
import 'package:deep_work/database/session_repository.dart';
import 'package:deep_work/sessionReflection.dart';
import 'package:deep_work/session_model.dart';
import 'package:deep_work/session_type.dart';

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key});

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  final _searchController = TextEditingController();
  SessionType? _filterSessionType;
  CompletionStatus? _filterCompletion;
  List<Session> _allSessions = [];
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSessions);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final list = await SessionRepository.getAll();
    if (!mounted) return;
    setState(() => _allSessions = list);
    _filterSessions();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSessions);
    _searchController.dispose();
    super.dispose();
  }

  void _filterSessions() {
    setState(() {
      _sessions = _allSessions.where((s) {
        final matchesSearch = _searchController.text.isEmpty ||
            s.intention.toLowerCase().contains(_searchController.text.toLowerCase());
        final matchesType = _filterSessionType == null || s.sessionType == _filterSessionType;
        final matchesCompletion = _filterCompletion == null || s.outcome == _filterCompletion;
        return matchesSearch && matchesType && matchesCompletion;
      }).toList();
    });
  }

  void _setSessionTypeFilter(SessionType? type) {
    _filterSessionType = type;
    _filterSessions();
  }

  void _setCompletionFilter(CompletionStatus? status) {
    _filterCompletion = status;
    _filterSessions();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sessions', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadSessions,
          child: const Icon(CupertinoIcons.refresh),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search sessions...',
                    style: const TextStyle(color: CupertinoColors.label),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: _filterSessionType == null,
                          onTap: () => _setSessionTypeFilter(null),
                        ),
                        const SizedBox(width: 8),
                        ...SessionType.values.map((type) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _FilterChip(
                                label: _sessionTypeLabel(type),
                                icon: type.icon,
                                isSelected: _filterSessionType == type,
                                onTap: () => _setSessionTypeFilter(type),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _SmallFilterChip(
                          label: 'All',
                          isSelected: _filterCompletion == null,
                          onTap: () => _setCompletionFilter(null),
                        ),
                        const SizedBox(width: 8),
                        _SmallFilterChip(
                          label: 'Done',
                          color: CupertinoColors.systemGreen,
                          isSelected: _filterCompletion == CompletionStatus.yes,
                          onTap: () => _setCompletionFilter(CompletionStatus.yes),
                        ),
                        const SizedBox(width: 8),
                        _SmallFilterChip(
                          label: 'Partial',
                          color: const Color(0xFFE7992D),
                          isSelected: _filterCompletion == CompletionStatus.partially,
                          onTap: () => _setCompletionFilter(CompletionStatus.partially),
                        ),
                        const SizedBox(width: 8),
                        _SmallFilterChip(
                          label: 'No',
                          color: CupertinoColors.systemRed,
                          isSelected: _filterCompletion == CompletionStatus.no,
                          onTap: () => _setCompletionFilter(CompletionStatus.no),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _SessionCard(session: _sessions[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sessionTypeLabel(SessionType type) {
    switch (type) {
      case SessionType.reading:
        return 'Reading';
      case SessionType.writing:
        return 'Writing';
      case SessionType.coding:
        return 'Coding';
      case SessionType.review:
        return 'Review';
      case SessionType.work:
        return 'Work';
      case SessionType.other:
        return 'Other';
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? CupertinoColors.white : CupertinoColors.secondaryLabel,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? CupertinoColors.white : CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallFilterChip extends StatelessWidget {
  const _SmallFilterChip({
    required this.label,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? CupertinoColors.activeBlue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : CupertinoColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? CupertinoColors.white : CupertinoColors.label,
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final outcomeIcon = _outcomeIcon(session.outcome);
    final outcomeColor = _outcomeColor(session.outcome);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              session.sessionType.icon,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.intention,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 12, color: CupertinoColors.secondaryLabel),
                    const SizedBox(width: 4),
                    Text(
                      '${session.durationMinutes}m',
                      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                    ),
                    Text(' · ', style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
                    Text(
                      _formatDate(session.dateTime),
                      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                    ),
                    Text(' · ', style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
                    Text(
                      _formatTime(session.dateTime),
                      style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: outcomeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(outcomeIcon, size: 16, color: outcomeColor),
          ),
        ],
      ),
    );
  }

  IconData _outcomeIcon(CompletionStatus status) {
    switch (status) {
      case CompletionStatus.yes:
        return CupertinoIcons.checkmark_circle;
      case CompletionStatus.partially:
        return CupertinoIcons.minus_circle;
      case CompletionStatus.no:
        return CupertinoIcons.xmark_circle;
    }
  }

  Color _outcomeColor(CompletionStatus status) {
    switch (status) {
      case CompletionStatus.yes:
        return CupertinoColors.systemGreen;
      case CompletionStatus.partially:
        return const Color(0xFFE7992D);
      case CompletionStatus.no:
        return CupertinoColors.systemRed;
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
}
