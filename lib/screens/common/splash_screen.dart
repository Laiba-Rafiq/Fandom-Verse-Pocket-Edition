import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _imagePath = 'assets/images/fandom_verse_splash.png';
  static const Duration _stay = Duration(seconds: 3);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    precacheImage(const AssetImage(_imagePath), context).catchError((_) {});
    if (!MediaQuery.of(context).disableAnimations) {
      _spin.repeat();
    }
    _timer = Timer(_stay, _goNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _spin.dispose();
    super.dispose();
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthGate(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomSpace = media.padding.bottom + media.size.height * 0.07;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                _imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.pink,
                        AppColors.purple,
                        AppColors.primary,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomSpace,
              child: Center(
                child: Semantics(
                  label: 'Loading',
                  child: _NeonLoader(animation: _spin),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeonLoader extends StatelessWidget {
  const _NeonLoader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: animation,
      child: const SizedBox(
        width: 42,
        height: 42,
        child: CustomPaint(painter: _NeonRingPainter()),
      ),
    );
  }
}

class _NeonRingPainter extends CustomPainter {
  const _NeonRingPainter();

  static const Color _neonPink = Color(0xFFFF3CAC);
  static const Color _neonPurple = Color(0xFFA23CF0);
  static const Color _neonBlue = Color(0xFF2BD2FF);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.6;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0x33FFFFFF);
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    final shader = const SweepGradient(
      colors: [
        Color(0x00FF3CAC),
        _neonBlue,
        _neonPurple,
        _neonPink,
      ],
      stops: [0.0, 0.45, 0.75, 1.0],
    ).createShader(rect);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 4
      ..strokeCap = StrokeCap.round
      ..shader = shader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawArc(arcRect, 0, math.pi * 1.6, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = shader;
    canvas.drawArc(arcRect, 0, math.pi * 1.6, false, arc);

    final dot = Paint()..color = Colors.white;
    final radius = arcRect.width / 2;
    final angle = math.pi * 1.6;
    final center = arcRect.center +
        Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    canvas.drawCircle(center, stroke * 0.7, dot);
  }

  @override
  bool shouldRepaint(covariant _NeonRingPainter oldDelegate) => false;
}
