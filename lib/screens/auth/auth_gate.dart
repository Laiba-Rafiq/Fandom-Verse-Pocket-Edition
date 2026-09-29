import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/contact_info.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/link_launcher.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/state_views.dart';
import '../admin/admin_home_screen.dart';
import '../fan/fan_shell.dart';
import 'profile_setup_screen.dart';
import 'role_selection_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<User?> _authStream =
      AuthService.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GateLoading();
        }
        final user = snapshot.data;
        if (user == null) {
          return const RoleSelectionScreen();
        }
        return _ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.uid});

  final String uid;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Stream<AppUser?> _profileStream =
      UserService.instance.watchUser(widget.uid);

  void _retry() {
    setState(() {
      _profileStream = UserService.instance.watchUser(widget.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _GateMessage(
            child: ErrorView(
              message: 'We could not load your profile.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }

        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const _GateLoading(message: 'Loading your profile...');
        }

        final profile = snapshot.data;
        if (profile == null) {
          return const _GateMessage(
            child: EmptyStateView(
              icon: Icons.person_search_outlined,
              title: 'Setting up your account...',
              message: 'If this screen does not change, your profile is '
                  'missing. Please log out and contact the app team.',
            ),
          );
        }

        if (profile.isAdmin) {
          return AdminHomeScreen(user: profile);
        }
        if (profile.isBlocked) {
          return _BlockedScreen(user: profile);
        }
        if (!profile.profileCompleted) {
          return ProfileSetupScreen(user: profile);
        }
        return FanShell(user: profile);
      },
    );
  }
}

class _GateLoading extends StatefulWidget {
  const _GateLoading({this.message});

  final String? message;

  @override
  State<_GateLoading> createState() => _GateLoadingState();
}

class _GateLoadingState extends State<_GateLoading>
    with SingleTickerProviderStateMixin {
  static const String _iconPath = 'assets/images/fv_launcher_icon.png';
  static const Color _night = Color(0xFF140A33);
  static const Color _neonPink = Color(0xFFFF3CAC);
  static const Color _neonPurple = Color(0xFFA23CF0);
  static const Color _neonBlue = Color(0xFF2BD2FF);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _spin.stop();
      _spin.value = 0.25;
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message ?? 'Getting things ready...';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _night,
      ),
      child: Scaffold(
        backgroundColor: _night,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.2),
              radius: 1.1,
              colors: [
                Color(0xFF3A1670),
                Color(0xFF1C0D45),
                _night,
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Semantics(
                liveRegion: true,
                label: message,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 164,
                      height: 164,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _spin,
                            child: Container(
                              width: 164,
                              height: 164,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Color(0x00FF3CAC),
                                    _neonPink,
                                    _neonPurple,
                                    _neonBlue,
                                  ],
                                  stops: [0.0, 0.45, 0.75, 1.0],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 150,
                            height: 150,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: _night,
                            ),
                          ),
                          Container(
                            width: 122,
                            height: 122,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _neonPink.withValues(alpha: 0.45),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                _iconPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) =>
                                    const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.buttonGradient,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 48,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [_neonPink, _neonPurple, _neonBlue],
                      ).createShader(bounds),
                      child: const Text(
                        'Fandom Verse',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fandom Trivia on the Go',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
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

class _GateMessage extends StatelessWidget {
  const _GateMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: child),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton.icon(
                onPressed: () => AuthService.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  const _BlockedScreen({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                    decoration: BoxDecoration(
                      gradient: AppColors.softGradient,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.error,
                          child: Icon(
                            Icons.block_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Account suspended',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Hi ${user.name.isEmpty ? 'there' : user.name}, an '
                          'admin has suspended this account, so you cannot '
                          'use Fandom Verse right now. If you think this is '
                          'a mistake, please contact our support team.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.ink,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.email,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => LinkLauncher.openEmail(
                        context,
                        ContactInfo.email,
                        subject: 'Suspended account: ${user.email}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.pink,
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.mail_rounded),
                      label: const Text('Email support'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => AuthService.instance.signOut(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.pink,
                        side: const BorderSide(color: AppColors.pink),
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log out'),
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