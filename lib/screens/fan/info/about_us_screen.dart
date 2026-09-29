import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/contact_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../routes/app_navigator.dart';
import '../../../widgets/app_button.dart';
import 'contact_us_screen.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key, required this.user});

  final AppUser user;

  static const String appVersion = '1.0.0';

  static const List<_Feature> _features = [
    _Feature(
      icon: Icons.school_rounded,
      title: 'Beginner Fan Hub',
      text: 'Character profiles, stories and a glossary to start any fandom.',
      color: AppColors.primary,
    ),
    _Feature(
      icon: Icons.auto_stories_rounded,
      title: 'Resources',
      text: 'News, galleries, videos and podcasts in one place.',
      color: AppColors.secondary,
    ),
    _Feature(
      icon: Icons.event_rounded,
      title: 'Events',
      text: 'Conventions and meetups on a map and calendar near you.',
      color: AppColors.warning,
    ),
    _Feature(
      icon: Icons.storefront_rounded,
      title: 'Merch Store',
      text: 'Apparel, collectibles and digital assets for true fans.',
      color: AppColors.pink,
    ),
    _Feature(
      icon: Icons.notifications_active_rounded,
      title: 'Price Alerts',
      text: 'Save items to your wishlist and hear when prices drop.',
      color: AppColors.success,
    ),
    _Feature(
      icon: Icons.smart_toy_rounded,
      title: 'AI Fan Helper',
      text: 'Ask questions about lore, characters and trivia anytime.',
      color: AppColors.purple,
    ),
  ];

  static const List<String> _values = [
    'Every fan is welcome',
    'Spoiler-safe',
    'Respect & kindness',
    'Learn together',
    'Works offline',
  ];

  static const String _teamName = 'Team NN2_CrossWave';
  static const String _teamCampus = 'Aptech North Nazimabad II';

  static const List<_Member> _members = [
    _Member(name: 'Laiba Rafiq', studentId: '1729813'),
    _Member(name: 'Hafsa Saleem', studentId: '1728973'),
    _Member(name: 'Hammas Ahmed', studentId: '1728871'),
    _Member(name: 'Muhammad Huzaifah Shahid', studentId: '1727480'),
    _Member(name: 'M Usman Ahsan Khokar', studentId: '1700475'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AboutHero(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 22, 16, 32 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _GroupLabel(text: 'OUR STORY'),
                        const SizedBox(height: 10),
                        const _SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CardTitle(
                                icon: Icons.flag_rounded,
                                title: 'Our mission',
                              ),
                              Text(
                                'Fandom Verse Pocket Edition brings every '
                                'fandom into your pocket. Whether you just '
                                'watched your first anime or you have '
                                'followed a saga for years, we help you '
                                'learn the lore, find events near you, '
                                'collect merchandise and connect with fans '
                                'who love the same worlds you do.',
                                style: TextStyle(height: 1.55, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _GroupLabel(text: 'EXPLORE'),
                        const SizedBox(height: 10),
                        _SoftCard(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle(
                                icon: Icons.auto_awesome_rounded,
                                title: 'What you can do',
                              ),
                              for (var i = 0; i < _features.length; i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    indent: 52,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                _FeatureRow(feature: _features[i]),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _GroupLabel(text: 'COMMUNITY'),
                        const SizedBox(height: 10),
                        _SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle(
                                icon: Icons.favorite_rounded,
                                title: 'What we believe',
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final value in _values)
                                    _ValuePill(text: value),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle(
                                icon: Icons.groups_rounded,
                                title: 'The team',
                              ),
                              const Text(
                                'Built for TechWiz 7',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Fandom Verse is a student project in the '
                                'Multi-Platform App Computing category, made '
                                'with Flutter, Firebase and Cloudinary by '
                                'fans, for fans.',
                                style: TextStyle(height: 1.5),
                              ),
                              const SizedBox(height: 14),
                              const _TeamBanner(
                                name: _teamName,
                                campus: _teamCampus,
                              ),
                              const SizedBox(height: 10),
                              for (final member in _members)
                                _MemberRow(member: member),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _GroupLabel(text: 'GET IN TOUCH'),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Contact us',
                          icon: Icons.support_agent_rounded,
                          onPressed: () => AppNavigator.push(
                            context,
                            ContactUsScreen(user: user),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            '${ContactInfo.organization} • Version $appVersion',
                            style: textTheme.bodySmall,
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
      ),
    );
  }
}

class _Feature {
  const _Feature({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;
}

class _Member {
  const _Member({required this.name, required this.studentId});

  final String name;
  final String studentId;

  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  static const String _art = 'assets/images/categories/cat_about_us.png';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final artSize = media.size.width < 360 ? 100.0 : 120.0;
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            const Positioned(
              top: -40,
              right: -30,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            const Positioned(
              bottom: -50,
              left: -40,
              child: _Bubble(size: 150, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (canPop)
                          _GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'About Us',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Fandom Verse • Pocket Edition',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Fandom Trivia on the Go',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HeroStat(
                                    icon: Icons.emoji_events_rounded,
                                    label: 'Built for TechWiz 7',
                                  ),
                                  _HeroStat(
                                    icon: Icons.verified_rounded,
                                    label:
                                        'Version ${AboutUsScreen.appVersion}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: artSize,
                          height: artSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                _art,
                                width: artSize,
                                height: artSize,
                                fit: BoxFit.contain,
                                semanticLabel: 'About Us',
                                errorBuilder: (context, error, stack) =>
                                    CircleAvatar(
                                  radius: artSize / 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: artSize / 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.pink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(feature.icon, size: 20, color: feature.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.text,
                  style: textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 15, color: AppColors.purple),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.purple,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamBanner extends StatelessWidget {
  const _TeamBanner({required this.name, required this.campus});

  final String name;
  final String campus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26A23CF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  campus,
                  style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final _Member member;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppColors.buttonGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33F0357A),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              member.initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Student ID ${member.studentId}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
