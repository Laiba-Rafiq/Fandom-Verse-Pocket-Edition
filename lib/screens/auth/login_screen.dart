import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/validators.dart';
import '../../models/user_role.dart';
import '../../routes/app_navigator.dart';
import '../../services/auth_service.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final UserRole role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _fanBannerPath = 'assets/images/fan_login_banner.jpg';
  static const String _adminBannerPath = 'assets/images/admin_login_banner.jpg';

  static const double _fanFormHeight = 510;
  static const double _adminFormHeight = 430;

  static const Color _bgTop = Color(0xFF1B0B3E);
  static const Color _pink = Color(0xFFF0357A);
  static const Color _hotPink = Color(0xFFFF5FA8);
  static const Color _violet = Color(0xFFA23CF0);
  static const Color _indigo = Color(0xFF6C4DFF);
  static const Color _lightViolet = Color(0xFFC9A7FF);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  String? _error;

  bool get _isAdmin => widget.role == UserRole.admin;
  bool get _busy => _loading || _googleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(
        email: _emailController.text,
        password: _passwordController.text,
        expectedRole: widget.role,
      );
      if (mounted) AppNavigator.backToRoot(context);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _googleLoading = true;
    });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) AppNavigator.backToRoot(context);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _openForgotPassword() {
    FocusScope.of(context).unfocus();
    AppNavigator.push(
      context,
      ForgotPasswordScreen(
        initialEmail: _emailController.text.trim(),
        isAdmin: _isAdmin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentStart = _isAdmin ? _violet : _pink;
    final accentEnd = _isAdmin ? _indigo : _violet;
    final linkColor = _isAdmin ? _lightViolet : _hotPink;
    final canPop = Navigator.of(context).canPop();

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;

    final formHeight = _isAdmin ? _adminFormHeight : _fanFormHeight;
    final heroMin = 160.0 + topInset;
    final heroMax = math.max(screenWidth * 0.95 + topInset, heroMin);
    final heroHeight = math.min(
      math.max(screenHeight - bottomInset - formHeight, heroMin),
      heroMax,
    );

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
            const _LoginBackground(),
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: bottomInset + 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroBanner(
                    path: _isAdmin ? _adminBannerPath : _fanBannerPath,
                    semanticLabel: _isAdmin
                        ? 'Admin working on the Fandom Verse dashboard'
                        : 'Fans celebrating at a fandom concert',
                    alignment: _isAdmin
                        ? const Alignment(0.05, 0.1)
                        : const Alignment(0, 0.1),
                    height: heroHeight,
                    badge: _HeaderBadge(
                      icon: _isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : Icons.favorite_rounded,
                      glow: accentStart,
                    ),
                  ),
                  const SizedBox(height: _HeroBanner.badgeOverlap + 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isAdmin ? 'Admin Login' : 'Welcome back, Fan!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isAdmin
                                  ? 'Sign in to the management console'
                                  : 'Log in to continue your fandom journey',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xBFFFFFFF),
                                fontSize: 14.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_error != null) ...[
                                    _ErrorBanner(message: _error!),
                                    const SizedBox(height: 12),
                                  ],
                                  _GlassField(
                                    controller: _emailController,
                                    hint: 'Email',
                                    icon: Icons.mail_outline_rounded,
                                    accent: accentStart,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: Validators.email,
                                    enabled: !_busy,
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassField(
                                    controller: _passwordController,
                                    hint: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    accent: accentStart,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    validator: Validators.password,
                                    onFieldSubmitted: (_) => _login(),
                                    enabled: !_busy,
                                    suffix: Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: linkColor,
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed:
                                          _busy ? null : _openForgotPassword,
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _GradientButton(
                                    label: 'Log in',
                                    icon: Icons.login_rounded,
                                    colors: [accentStart, accentEnd],
                                    isLoading: _loading,
                                    onPressed: _googleLoading ? null : _login,
                                  ),
                                  if (!_isAdmin) ...[
                                    const SizedBox(height: 12),
                                    const _OrDivider(),
                                    const SizedBox(height: 12),
                                    _GoogleButton(
                                      borderColor: _hotPink,
                                      isLoading: _googleLoading,
                                      onPressed:
                                          _loading ? null : _loginWithGoogle,
                                    ),
                                  ],
                                  SizedBox(height: _isAdmin ? 16 : 6),
                                  if (_isAdmin)
                                    Text(
                                      'Admin accounts are pre-configured '
                                      'by the app team.\n'
                                      'Admins do not need to sign up.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12.5,
                                        height: 1.45,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account?",
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 14.5,
                                          ),
                                        ),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: _hotPink,
                                            minimumSize: const Size(0, 36),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () => AppNavigator.replace(
                                                    context,
                                                    const SignupScreen(),
                                                  ),
                                          child: const Text(
                                            'Sign up',
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (canPop)
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
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.path,
    required this.semanticLabel,
    required this.alignment,
    required this.height,
    required this.badge,
  });

  static const double badgeOverlap = 28;

  final String path;
  final String semanticLabel;
  final Alignment alignment;
  final double height;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final cacheWidth = (media.size.width * media.devicePixelRatio).round();

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Semantics(
            label: semanticLabel,
            image: true,
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              alignment: alignment,
              cacheWidth: cacheWidth,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6C2BD9), Color(0xFFF0357A)],
                  ),
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x80120A2E),
                    Color(0x00120A2E),
                    Color(0x001B0B3E),
                    Color(0xB31B0B3E),
                    Color(0xFF1B0B3E),
                  ],
                  stops: [0.0, 0.22, 0.55, 0.88, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -badgeOverlap,
            child: Center(child: badge),
          ),
        ],
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

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
                Color(0xFF1B0B3E),
                Color(0xFF2B0F58),
                Color(0xFF3D0F5C),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.42,
          right: -big * 0.32,
          child: _Glow(
            size: big * 0.6,
            color: const Color(0xFFF0357A),
            opacity: 0.24,
          ),
        ),
        Positioned(
          bottom: -big * 0.25,
          left: -big * 0.2,
          child: _Glow(
            size: big * 0.75,
            color: const Color(0xFFF0357A),
            opacity: 0.22,
          ),
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

class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.glow});

  final IconData icon;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
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
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 27),
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

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accent,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color accent;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    const errorColor = Color(0xFFFF7A9C);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      enabled: enabled,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      cursorColor: accent,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 16,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.85),
            size: 23,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 50,
          minHeight: 48,
        ),
        suffixIcon: suffix,
        errorStyle: const TextStyle(color: Color(0xFFFF9EBB), fontSize: 12.5),
        errorMaxLines: 2,
        border: border(Colors.white.withValues(alpha: 0.18)),
        enabledBorder: border(Colors.white.withValues(alpha: 0.18)),
        disabledBorder: border(Colors.white.withValues(alpha: 0.10)),
        focusedBorder: border(accent.withValues(alpha: 0.9), 1.6),
        errorBorder: border(errorColor),
        focusedErrorBorder: border(errorColor, 1.6),
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
                        Icon(icon, color: Colors.white, size: 23),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17.5,
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

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.borderColor,
    required this.isLoading,
    required this.onPressed,
  });

  final Color borderColor;
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
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.85),
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: borderColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.g_mobiledata,
                            color: Color(0xFF4285F4),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.25);
    return Row(
      children: [
        Expanded(child: Divider(color: color, thickness: 1, height: 18)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Divider(color: color, thickness: 1, height: 18)),
      ],
    );
  }
}
