import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Animated circular progress ring that visualises Dhikr completion.
///
/// Renders two arcs:
///   - A static background track ([AppColors.ringBackground]).
///   - A foreground arc that sweeps from 0° to 360° as [progress] goes 0→1.
///
/// The [pulseTrigger] flag causes a brief scale bounce on each increment,
/// providing immediate visual feedback without rebuilding the entire screen.
class CounterRing extends StatefulWidget {
  const CounterRing({
    super.key,
    required this.progress,
    required this.pulseTrigger,
    required this.child,
    this.size = 280,
    this.strokeWidth = 14,
  });

  /// Completion fraction in [0.0, 1.0].
  final double progress;

  /// Set to true externally to trigger the pulse animation.
  final bool pulseTrigger;

  /// Widget rendered at the center of the ring (usually the counter text).
  final Widget child;

  final double size;
  final double strokeWidth;

  @override
  State<CounterRing> createState() => _CounterRingState();
}

class _CounterRingState extends State<CounterRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(CounterRing old) {
    super.didUpdateWidget(old);
    if (widget.pulseTrigger && !old.pulseTrigger) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: widget.progress,
            strokeWidth: widget.strokeWidth,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // top of circle

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.ringBackground
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Foreground arc with gradient sweep
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [Color(0xFF2ECC71), Color(0xFF1ABC9C), Color(0xFFF1C40F)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
