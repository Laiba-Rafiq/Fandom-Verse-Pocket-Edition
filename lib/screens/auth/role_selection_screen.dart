import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user_role.dart';
import '../../routes/app_navigator.dart';
import '../../widgets/app_logo.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  static const String _logoPath = 'assets/images/fandom_verse_logo.png';
  static const String _fanImagePath = 'assets/images/fan_card_image.png';
  static const String _adminImagePath = 'assets/images/admin_card_image.png';

  static const Color _deepNavy = Color(0xFF120A2E);
  static const Color _deepViolet = Color(0xFF26104F);
  static const Color _plum = Color(0xFF3A0C47);
  static const Color _magenta = Color(0xFFF0357A);
  static const Color _violet = Color(0xFFA23CF0);
  static const Color _indigo = Color(0xFF6C4DFF);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _deepNavy,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _deepNavy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _PremiumBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final contentWidth = math.min(width - 48, 480.0);
                  final logoWidth = math.min(contentWidth * 0.86, 360.0);
                  final logoHeight = math.max(height * 0.25, 110.0);
                  final gapLarge = math.max(height * 0.045, 24.0);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: height),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: gapLarge * 0.6),
                              _Entrance(
                                delay: 0,
                                reduceMotion: reduceMotion,
                                slide: false,
                                child: _LogoBlock(
                                  path: _logoPath,
                                  maxWidth: logoWidth,
                                  maxHeight: logoHeight,
                                ),
                              ),
                              SizedBox(height: gapLarge),
                              _Entrance(
                                delay: 0.15,
                                reduceMotion: reduceMotion,
                                child: const Column(
                                  children: [
                                    Text(
                                      'Choose Your Experience',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'Explore the fandom universe or '
                                        'manage the community.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Color(0xB3FFFFFF),
                                          fontSize: 14.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: gapLarge),
                              _Entrance(
                                delay: 0.3,
                                reduceMotion: reduceMotion,
                                child: _RoleCard(
                                  imagePath: _fanImagePath,
                                  fallbackIcon: Icons.groups_rounded,
                                  accentStart: _magenta,
                                  accentEnd: const Color(0xFFFF6FB5),
                                  title: 'Continue as Fan',
                                  subtitle:
                                      'Discover fandoms, events, stories, '
                                      'merchandise and more.',
                                  onTap: () => AppNavigator.push(
                                    context,
                                    const LoginScreen(role: UserRole.fan),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _Entrance(
                                delay: 0.42,
                                reduceMotion: reduceMotion,
                                child: _RoleCard(
                                  imagePath: _adminImagePath,
                                  fallbackIcon:
                                      Icons.admin_panel_settings_rounded,
                                  accentStart: _violet,
                                  accentEnd: _indigo,
                                  title: 'Admin Portal',
                                  subtitle: 'Manage content, events, '
                                      'merchandise and users.',
                                  onTap: () => AppNavigator.push(
                                    context,
                                    const LoginScreen(role: UserRole.admin),
                                  ),
                                ),
                              ),
                              SizedBox(height: gapLarge),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final big = math.max(size.width, size.height);

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                RoleSelectionScreen._deepNavy,
                RoleSelectionScreen._deepViolet,
                RoleSelectionScreen._plum,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -big * 0.18,
          left: -big * 0.22,
          child: _Glow(
            size: big * 0.75,
            color: RoleSelectionScreen._magenta,
            opacity: 0.30,
          ),
        ),
        Positioned(
          bottom: -big * 0.22,
          right: -big * 0.25,
          child: _Glow(
            size: big * 0.8,
            color: RoleSelectionScreen._violet,
            opacity: 0.32,
          ),
        ),
        Positioned(
          top: size.height * 0.38,
          right: -big * 0.18,
          child: _Glow(
            size: big * 0.45,
            color: const Color(0xFF2BD2FF),
            opacity: 0.10,
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _StarsPainter()),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 46; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = 0.6 + random.nextDouble() * 1.2;
      paint.color = Colors.white.withValues(
        alpha: 0.08 + random.nextDouble() * 0.3,
      );
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      const arm = 4.0;
      canvas.drawLine(
        center.translate(-arm, 0),
        center.translate(arm, 0),
        sparkle,
      );
      canvas.drawLine(
        center.translate(0, -arm),
        center.translate(0, arm),
        sparkle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => false;
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({
    required this.path,
    required this.maxWidth,
    required this.maxHeight,
  });

  final String path;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final haloSize = maxWidth * 0.95;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: Transform.scale(
              scaleX: 1.55,
              scaleY: 1.0,
              child: Container(
                width: haloSize,
                height: haloSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xF2FFFFFF),
                      Color(0xD9F6EEFF),
                      Color(0x80E5D4FF),
                      Color(0x33A23CF0),
                      Color(0x00A23CF0),
                    ],
                    stops: [0.0, 0.32, 0.55, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Semantics(
              label: 'Fandom Verse Pocket Edition logo',
              image: true,
              child: Image.asset(
                path,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stack) =>
                    const AppLogo(size: 88, onDark: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.delay,
    required this.reduceMotion,
    required this.child,
    this.slide = true,
  });

  final double delay;
  final bool reduceMotion;
  final bool slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, child) {
        final offset = slide ? (1 - value) * 18 : 0.0;
        final scale = slide ? 1.0 : 0.94 + value * 0.06;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.imagePath,
    required this.fallbackIcon,
    required this.accentStart,
    required this.accentEnd,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imagePath;
  final IconData fallbackIcon;
  final Color accentStart;
  final Color accentEnd;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: widget.accentStart.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: Colors.white.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: BorderSide(
                    color: widget.accentStart.withValues(alpha: 0.35),
                  ),
                ),
                child: InkWell(
                  borderRadius: radius,
                  onTap: widget.onTap,
                  onTapDown: (_) => _setPressed(true),
                  onTapCancel: () => _setPressed(false),
                  onTapUp: (_) => _setPressed(false),
                  splashColor: widget.accentStart.withValues(alpha: 0.18),
                  highlightColor: Colors.white.withValues(alpha: 0.04),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        _CardImage(
                          path: widget.imagePath,
                          fallbackIcon: widget.fallbackIcon,
                          accentStart: widget.accentStart,
                          accentEnd: widget.accentEnd,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  color: Color(0xB3FFFFFF),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.path,
    required this.fallbackIcon,
    required this.accentStart,
    required this.accentEnd,
  });

  static const double _width = 86;
  static const double _height = 104;

  final String path;
  final IconData fallbackIcon;
  final Color accentStart;
  final Color accentEnd;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final radius = BorderRadius.circular(18);

    return Container(
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentStart.withValues(alpha: 0.9),
            accentEnd.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentStart.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.45),
          cacheWidth: (_width * dpr * 1.5).round(),
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stack) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accentStart, accentEnd],
              ),
            ),
            child: Center(
              child: Icon(fallbackIcon, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
