import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:deep_work/session_type.dart';
import 'package:deep_work/sessionReflection.dart';

class ProcessSessionPage extends StatefulWidget {
  const ProcessSessionPage({
    super.key,
    required this.sessionType,
    this.goal,
  });

  final SessionType sessionType;
  final String? goal;

  @override
  State<ProcessSessionPage> createState() => _ProcessSessionPageState();
}

class _ProcessSessionPageState extends State<ProcessSessionPage> {
  int _elapsedSeconds = 0;
  bool _isPaused = true;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String get _formattedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _timer?.cancel();
      } else {
        _startTimer();
      }
    });
  }

  void _stopSession() {
    _timer?.cancel();
    final focusMinutes = _elapsedSeconds ~/ 60;
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => SessionReflectionPage(
          goal: widget.goal ?? 'No intention set',
          focusMinutes: focusMinutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Session type icon at top
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.activeBlue,
                    width: 2,
                  ),
                ),
                child: Icon(
                  widget.sessionType.icon,
                  size: 32,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(height: 48),
              // Stopwatch
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.tertiarySystemFill,
                    width: 8,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Text(
                    //   _isPaused ? 'Play' : 'Pause',
                    //   style: const TextStyle(
                    //     fontSize: 16,
                    //     color: CupertinoColors.secondaryLabel,
                    //     fontWeight: FontWeight.w300,
                    //   ),
                    // ),
                  ],
                ),
              ),
              if (widget.goal != null && widget.goal!.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  widget.goal!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: CupertinoColors.label,
                  ),
                ),
              ],
              const SizedBox(height: 48),
              // Pause and Stop buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _togglePause,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CupertinoColors.activeBlue,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isPaused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                        size: 28,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  GestureDetector(
                    onTap: _stopSession,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: CupertinoColors.systemRed,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        CupertinoIcons.stop_fill,
                        size: 28,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
