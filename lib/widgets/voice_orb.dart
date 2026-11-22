import 'dart:math' as math;
import 'package:flutter/material.dart';

enum OrbState {
  idle,
  listening,
  thinking,
  speaking,
}

class VoiceOrb extends StatefulWidget {
  final OrbState state;
  final double soundLevel;
  final VoidCallback onTap;

  const VoiceOrb({
    super.key,
    required this.state,
    this.soundLevel = 0.0,
    required this.onTap,
  });

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _OrbPainter(
              progress: _controller.value,
              state: widget.state,
              soundLevel: widget.soundLevel,
            ),
            child: SizedBox(
              width: 140,
              height: 140,
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _getInnerColors(),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getGlowColor().withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getIcon(),
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Color> _getInnerColors() {
    switch (widget.state) {
      case OrbState.listening:
        return const [Color(0xFF00F2FE), Color(0xFF4FACFE)];
      case OrbState.thinking:
        return const [Color(0xFFF355DA), Color(0xFF7000FF)];
      case OrbState.speaking:
        return const [Color(0xFF10B981), Color(0xFF059669)];
      case OrbState.idle:
        return const [Color(0xFF6366F1), Color(0xFF3B82F6)];
    }
  }

  Color _getGlowColor() {
    switch (widget.state) {
      case OrbState.listening:
        return const Color(0xFF00F2FE);
      case OrbState.thinking:
        return const Color(0xFFE040FB);
      case OrbState.speaking:
        return const Color(0xFF10B981);
      case OrbState.idle:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getIcon() {
    switch (widget.state) {
      case OrbState.listening:
        return Icons.mic_rounded;
      case OrbState.thinking:
        return Icons.auto_awesome_rounded;
      case OrbState.speaking:
        return Icons.volume_up_rounded;
      case OrbState.idle:
        return Icons.mic_none_rounded;
    }
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final OrbState state;
  final double soundLevel;

  _OrbPainter({
    required this.progress,
    required this.state,
    required this.soundLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    Color auraColor;
    double pulseFactor;

    switch (state) {
      case OrbState.listening:
        auraColor = const Color(0xFF00F2FE);
        pulseFactor = (soundLevel * 3).clamp(0.0, 1.0);
        break;
      case OrbState.thinking:
        auraColor = const Color(0xFFD946EF);
        pulseFactor = 0.5 + 0.5 * math.sin(progress * 2 * math.pi * 3);
        break;
      case OrbState.speaking:
        auraColor = const Color(0xFF10B981);
        pulseFactor = 0.6 + 0.4 * math.sin(progress * 2 * math.pi * 2);
        break;
      case OrbState.idle:
        auraColor = const Color(0xFF6366F1);
        pulseFactor = 0.2 + 0.15 * math.sin(progress * 2 * math.pi);
        break;
    }

    // Dibujar ondas externas difusas
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 38.0 + (maxRadius - 38.0) * waveProgress * (1.0 + pulseFactor * 0.4);
      final alpha = ((1.0 - waveProgress) * (0.35 + pulseFactor * 0.3)).clamp(0.0, 0.7);

      final paint = Paint()
        ..color = auraColor.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }

    // Si está pensando, dibujamos un anillo orbital giratorio
    if (state == OrbState.thinking) {
      final orbitPaint = Paint()
        ..color = const Color(0xFFF43F5E)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5;

      final rect = Rect.fromCircle(center: center, radius: 46);
      canvas.drawArc(rect, progress * 2 * math.pi, math.pi * 1.2, false, orbitPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        oldDelegate.soundLevel != soundLevel;
  }
}
