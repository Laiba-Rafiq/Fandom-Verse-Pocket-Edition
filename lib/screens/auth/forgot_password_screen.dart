import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/validators.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail = '',
    this.isAdmin = false,
  });

  final String initialEmail;
  final bool isAdmin;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _bgTop = Color(0xFF1B0B3E);
  static const Color _pink = Color(0xFFF0357A);
  static const Color _violet = Color(0xFFA23CF0);
  static const Color _indigo = Color(0xFF6C4DFF);
  static const int _cooldownSeconds = 30;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail.trim());

  bool _sending = false;
  String? _error;
  String? _sentTo;
  int _cooldown = 0;
  Timer? _timer;

  Color get _accentStart => widget.isAdmin ? _violet : _pink;
  Color get _accentEnd => widget.isAdmin ? _indigo : _violet;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email)
          .timeout(const Duration(seconds: 15));
      _onSent(email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _onSent(email);
          break;
        case 'invalid-email':
          _showError('Please enter a valid email address.');
          break;
        case 'too-many-requests':
          _showError(
            'Too many attempts. Please wait a few minutes and try again.',
          );
          break;
        case 'network-request-failed':
          _showError('No internet connection. Please try again.');
          break;
        default:
          _showError('Could not send the reset link. Please try again.');
      }
    } on TimeoutException {
      _showError('No internet connection. Please try again.');
    } catch (_) {
      _showError('Could not send the reset link. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onSent(String email) {
    if (!mounted) return;
    setState(() => _sentTo = email);
    _startCooldown();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  void _useDifferentEmail() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _cooldown = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _bgTop,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bgTop,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _ResetBackground(glow: _accentStart),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _sentTo == null
                          ? _buildForm(context)
                          : _buildSent(context, _sentTo!),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + 6,
              left: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.28),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _ResetArt(
            glow: _accentStart,
            fallbackIcon: Icons.lock_reset_rounded,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Forgot password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter the email you use for Fandom Verse and we'll send you a "
          'link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xBFFFFFFF),
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 26),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enabled: !_sending,
                validator: Validators.email,
                onFieldSubmitted: (_) => _send(),
                cursorColor: _accentStart,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: _fieldDecoration(),
              ),
              const SizedBox(height: 20),
              _GradientButton(
                label: 'Send reset link',
                icon: Icons.send_rounded,
                colors: [_accentStart, _accentEnd],
                isLoading: _sending,
                onPressed: _send,
              ),
              const SizedBox(height: 14),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.8),
                ),
                onPressed:
                    _sending ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSent(BuildContext context, String email) {
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: _ResetArt(
            glow: _accentStart,
            fallbackIcon: Icons.mark_email_read_rounded,
            widthFactor: 0.5,
            maxWidth: 200,
            showCheck: true,
            checkColors: [_accentStart, _accentEnd],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'If an account exists for $email, a password reset link is on its '
          'way. Open it, choose a new password, then log in again.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Can't find it? Check your spam or junk folder.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _GradientButton(
          label: 'Back to login',
          icon: Icons.login_rounded,
          colors: [_accentStart, _accentEnd],
          isLoading: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          onPressed: _cooldown > 0 || _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.refresh_rounded),
          label: Text(
            _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend link',
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.75),
          ),
          onPressed: _sending ? null : _useDifferentEmail,
          child: const Text('Use a different email'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(message: _error!),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration() {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    const errorColor = Color(0xFFFF7A9C);

    return InputDecoration(
      hintText: 'Email',
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 16,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 10),
        child: Icon(
          Icons.mail_outline_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: 23,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 50, minHeight: 48),
      errorStyle: const TextStyle(color: Color(0xFFFF9EBB), fontSize: 12.5),
      errorMaxLines: 2,
      border: border(Colors.white.withValues(alpha: 0.18)),
      enabledBorder: border(Colors.white.withValues(alpha: 0.18)),
      disabledBorder: border(Colors.white.withValues(alpha: 0.10)),
      focusedBorder: border(_accentStart.withValues(alpha: 0.9), 1.6),
      errorBorder: border(errorColor),
      focusedErrorBorder: border(errorColor, 1.6),
    );
  }
}

class _ResetBackground extends StatelessWidget {
  const _ResetBackground({required this.glow});

  final Color glow;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final big = math.max(size.width, size.height);

    Widget blob(double diameter, Color color, double opacity) {
      return IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
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

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1B0B3E),
                Color(0xFF2B0F58),
                Color(0xFF3D0F5C),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -big * 0.15,
          left: -big * 0.25,
          child: blob(big * 0.7, const Color(0xFFA23CF0), 0.30),
        ),
        Positioned(
          top: size.height * 0.35,
          right: -big * 0.3,
          child: blob(big * 0.6, glow, 0.22),
        ),
        Positioned(
          bottom: -big * 0.25,
          left: -big * 0.2,
          child: blob(big * 0.7, const Color(0xFFF0357A), 0.18),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _SparklePainter()),
          ),
        ),
      ],
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(23);
    final dot = Paint();
    for (var i = 0; i < 40; i++) {
      dot.color = Colors.white.withValues(
        alpha: 0.08 + random.nextDouble() * 0.3,
      );
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.6 + random.nextDouble() * 1.2,
        dot,
      );
    }
    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final arm = 3.0 + random.nextDouble() * 3;
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
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => false;
}

class _ResetArt extends StatefulWidget {
  const _ResetArt({
    required this.glow,
    required this.fallbackIcon,
    this.widthFactor = 0.64,
    this.maxWidth = 260,
    this.showCheck = false,
    this.checkColors = const [Color(0xFFF0357A), Color(0xFFA23CF0)],
  });

  static const String path = 'assets/images/reset_password_art.png';
  static const double aspect = 534 / 720;

  final Color glow;
  final IconData fallbackIcon;
  final double widthFactor;
  final double maxWidth;
  final bool showCheck;
  final List<Color> checkColors;

  @override
  State<_ResetArt> createState() => _ResetArtState();
}

class _ResetArtState extends State<_ResetArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width =
        math.min(media.size.width * widget.widthFactor, widget.maxWidth);
    final height = width * _ResetArt.aspect;
    final cacheWidth = (width * media.devicePixelRatio).round();

    final art = Image.asset(
      _ResetArt.path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      semanticLabel: widget.showCheck
          ? 'Reset link sent to your email'
          : 'Secure password reset email',
      errorBuilder: (context, error, stack) => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: _Badge(icon: widget.fallbackIcon, glow: widget.glow),
        ),
      ),
    );

    return SizedBox(
      width: width * 1.2,
      height: height + 24,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            child: Container(
              width: width * 1.2,
              height: width * 1.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.glow.withValues(alpha: 0.42),
                    const Color(0xFFA23CF0).withValues(alpha: 0.16),
                    widget.glow.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                width: width * 0.6,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glow.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              return Transform.translate(
                offset: Offset(0, 6 - 12 * t),
                child: child,
              );
            },
            child: art,
          ),
          if (widget.showCheck)
            Positioned(
              right: width * 0.08,
              bottom: 0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: widget.checkColors),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: widget.checkColors.first.withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.glow});

  final IconData icon;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5A2A8C).withValues(alpha: 0.95),
            const Color(0xFF3A1766).withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.5),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 38),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x33FF4D6D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x80FF7A9C)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFFFB3C6),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    final enabled = onPressed != null && !isLoading;

    return Opacity(
      opacity: onPressed == null && !isLoading ? 0.6 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
