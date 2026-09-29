import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/app_user.dart';
import '../../services/category_service.dart';
import '../../services/user_service.dart';
import '../common/logout_helper.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const Color _bgTop = Color(0xFF1B0B3E);
  static const Color _pink = Color(0xFFF0357A);
  static const Color _hotPink = Color(0xFFFF5FA8);
  static const Color _violet = Color(0xFFA23CF0);
  static const Color _indigo = Color(0xFF6C4DFF);

  late final Future<List<String>> _categoriesFuture =
      CategoryService.instance.getCategoryNames();

  List<String> _selectedFandoms = [];
  List<String> _selectedBadges = [];
  bool _saving = false;
  bool _showFandomError = false;

  Future<void> _save() async {
    if (_selectedFandoms.isEmpty) {
      setState(() => _showFandomError = true);
      UiHelpers.showSnack(
        context,
        'Please pick at least one fandom interest.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await UserService.instance.completeProfileSetup(
        uid: widget.user.uid,
        selectedFandoms: _selectedFandoms,
        badges: _selectedBadges,
      );
    } catch (_) {
      if (!mounted) return;
      UiHelpers.showSnack(
        context,
        'Could not save your profile. Please try again.',
        isError: true,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final bottomInset = media.padding.bottom;

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
            const _SetupBackground(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    topInset + 60,
                    20,
                    bottomInset + 28,
                  ),
                  children: [
                    Center(
                      child: _GlowAvatar(
                        initials: widget.user.initials,
                        colors: const [_pink, _violet],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hi ${widget.user.name}! 👋',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tell us what you love so we can personalise your '
                      'fandom universe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xBFFFFFFF),
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 26),
                    _GlassCard(
                      icon: Icons.favorite_rounded,
                      iconColor: _pink,
                      title: 'Your fandom interests',
                      isRequired: true,
                      subtitle: 'Pick at least one. You can change these '
                          'later in your profile.',
                      count: _selectedFandoms.length,
                      highlightError: _showFandomError,
                      child: FutureBuilder<List<String>>(
                        future: _categoriesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 22),
                              child: Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: _hotPink,
                                  ),
                                ),
                              ),
                            );
                          }
                          return _GlassChips(
                            options: snapshot.data!,
                            selected: _selectedFandoms,
                            enabled: !_saving,
                            colors: const [_pink, _violet],
                            onChanged: (list) => setState(() {
                              _selectedFandoms = list;
                              if (list.isNotEmpty) _showFandomError = false;
                            }),
                          );
                        },
                      ),
                    ),
                    if (_showFandomError)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, left: 6),
                        child: Text(
                          'Please pick at least one fandom interest.',
                          style: TextStyle(
                            color: Color(0xFFFF9EBB),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _GlassCard(
                      icon: Icons.military_tech_rounded,
                      iconColor: _violet,
                      title: 'Profile badges',
                      subtitle: 'Pick the badges that describe you best.',
                      count: _selectedBadges.length,
                      child: _GlassChips(
                        options: AppConstants.profileBadges,
                        selected: _selectedBadges,
                        enabled: !_saving,
                        colors: const [_violet, _indigo],
                        onChanged: (list) =>
                            setState(() => _selectedBadges = list),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _GradientButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      colors: const [_pink, _violet],
                      isLoading: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, topInset + 8, 12, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF51B0B3E), Color(0x001B0B3E)],
                    stops: [0.7, 1.0],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: _hotPink,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Set up your profile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                      onPressed: _saving ? null : () => confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Log out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowAvatar extends StatelessWidget {
  const _GlowAvatar({required this.initials, required this.colors});

  final String initials;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A2A8C), Color(0xFF2B0F58)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.child,
    this.isRequired = false,
    this.highlightError = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int count;
  final Widget child;
  final bool isRequired;
  final bool highlightError;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlightError
              ? const Color(0xFFFF7A9C)
              : Colors.white.withValues(alpha: 0.14),
          width: highlightError ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      if (isRequired)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Color(0xFFFF5FA8)),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _GlassChips extends StatelessWidget {
  const _GlassChips({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.colors,
    required this.onChanged,
  });

  final List<String> options;
  final List<String> selected;
  final bool enabled;
  final List<Color> colors;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String option) {
    final next = [...selected];
    if (next.contains(option)) {
      next.remove(option);
    } else {
      next.add(option);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final option in options)
          _GlassChip(
            label: option,
            selected: selected.contains(option),
            colors: colors,
            onTap: enabled ? () => _toggle(option) : null,
          ),
      ],
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);

    return Semantics(
      button: true,
      selected: selected,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: selected ? LinearGradient(colors: colors) : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.20),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupBackground extends StatelessWidget {
  const _SetupBackground();

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
          top: -big * 0.18,
          left: -big * 0.25,
          child: blob(big * 0.7, const Color(0xFFA23CF0), 0.30),
        ),
        Positioned(
          top: size.height * 0.30,
          right: -big * 0.32,
          child: blob(big * 0.6, const Color(0xFFF0357A), 0.22),
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
    final random = math.Random(37);
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
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(icon, color: Colors.white, size: 23),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
