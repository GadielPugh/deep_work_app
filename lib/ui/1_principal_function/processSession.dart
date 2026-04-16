import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:deep_work/models/focus_category.dart';
import 'package:deep_work/ui/1_principal_function/sessionReflection.dart';

class ProcessSessionPage extends StatefulWidget {
  ProcessSessionPage({
    super.key,
    required this.category,
    this.goal,
    DateTime? sessionStartedAt,
  }) : startedAt = sessionStartedAt ?? DateTime.now();

  final FocusCategory category;
  final String? goal;
  /// When this focus session was started (for DB and ML).
  final DateTime startedAt;

  @override
  State<ProcessSessionPage> createState() => _ProcessSessionPageState();
}

class _ProcessSessionPageState extends State<ProcessSessionPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isPaused = false;
  late final AnimationController _ringController;
  int _accumulatedMilliseconds = 0;
  DateTime _runningStartedAt = DateTime.now();

  static const _ringStroke = 10.0;
  static const _ringSize = 220.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ringController = AnimationController(
      vsync: this,
      // Long loop to avoid visible hitch from frequent animation resets.
      duration: const Duration(hours: 1),
    )..repeat();
    _runningStartedAt = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringController.dispose();
    super.dispose();
  }

  int get _elapsedMilliseconds {
    if (_isPaused) return _accumulatedMilliseconds;
    final now = DateTime.now();
    return _accumulatedMilliseconds +
        now.difference(_runningStartedAt).inMilliseconds;
  }

  int get _elapsedSeconds => _elapsedMilliseconds ~/ 1000;

  double get _secondsIntoMinute =>
      (_elapsedMilliseconds % 60000) / 1000.0;

  String get _formattedTime {
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Rebuild when returning so UI immediately reflects wall-clock elapsed time.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      if (!_isPaused && !_ringController.isAnimating) {
        _ringController.repeat();
      }
    }
  }


  void _togglePause() {
    setState(() {
      if (!_isPaused) {
        // Capture running time before switching to paused state.
        _accumulatedMilliseconds = _elapsedMilliseconds;
        _isPaused = true;
        _ringController.stop();
      } else {
        _isPaused = false;
        _runningStartedAt = DateTime.now();
        if (!_ringController.isAnimating) {
          _ringController.repeat();
        }
      }
    });
  }

  void _stopSession() {
    _ringController.stop();
    final focusMinutes = _elapsedSeconds ~/ 60;
    final stoppedAt = DateTime.now();
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => SessionReflectionPage(
          goal: widget.goal ?? 'No intention set',
          focusMinutes: focusMinutes,
          category: widget.category,
          startedAt: widget.startedAt,
          stoppedAt: stoppedAt,
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
                  widget.category.icon,
                  size: 32,
                  color: CupertinoColors.activeBlue,
                ),
              ),
              const SizedBox(height: 48),
              // Stopwatch + minimal animated ring (countdown within each minute)
              SizedBox(
                width: _ringSize,
                height: _ringSize,
                child: AnimatedBuilder(
                  animation: _ringController,
                  builder: (context, _) {
                    final remainingFraction =
                        ((60.0 - _secondsIntoMinute) / 60.0).clamp(0.0, 1.0);

                    return CustomPaint(
                      painter: _CountdownRingPainter(
                        fraction: remainingFraction,
                        backgroundColor: CupertinoColors.tertiarySystemFill,
                        foregroundColor: CupertinoColors.activeBlue,
                        strokeWidth: _ringStroke,
                      ),
                      child: Center(
                        child: Text(
                          _formattedTime,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ),
                    );
                  },
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

class _CountdownRingPainter extends CustomPainter {
  const _CountdownRingPainter({
    required this.fraction,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color backgroundColor;
  final Color foregroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = backgroundColor;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = foregroundColor;

    canvas.drawArc(rect, 0, math.pi * 2, false, bg);

    final sweep = (math.pi * 2) * fraction;
    final start = -math.pi / 2;
    canvas.drawArc(rect, start, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
