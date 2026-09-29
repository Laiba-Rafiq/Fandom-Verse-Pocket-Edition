import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/app_user.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/user_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/avatar_uploader.dart';
import '../../common/logout_helper.dart';
import '../info/about_us_screen.dart';
import '../info/contact_us_screen.dart';
import '../store/wishlist_screen.dart';
import 'bookmarks_screen.dart';
import 'edit_profile_screen.dart';
import 'purchase_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final AppUser user;

  Future<void> _saveAvatar(BuildContext context, String url) async {
    try {
      await UserService.instance.updateProfile(uid: user.uid, avatarUrl: url);
      if (context.mounted) {
        UiHelpers.showSnack(context, 'Profile picture updated!');
      }
    } catch (_) {
      if (context.mounted) {
        UiHelpers.showSnack(
          context,
          'Could not save your new picture. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _openEdit(BuildContext context) {
    AppNavigator.push(context, EditProfileScreen(user: user));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHero(
                user: user,
                onEdit: () => _openEdit(context),
                onAvatarUploaded: (url) => _saveAvatar(context, url),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SoftCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CardTitle(
                                title: 'Bio',
                                icon: Icons.format_quote_rounded,
                              ),
                              Text(
                                user.bio.isEmpty
                                    ? 'No bio yet. Tap the edit icon to add one.'
                                    : user.bio,
                                style: textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color:
                                      user.bio.isEmpty ? null : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ChipsCard(
                          title: 'Fandoms I like',
                          icon: Icons.favorite_rounded,
                          items: user.selectedFandoms,
                          emptyText: 'No fandoms selected yet.',
                          gradient: true,
                        ),
                        const SizedBox(height: 12),
                        _ChipsCard(
                          title: 'Badges',
                          icon: Icons.military_tech_rounded,
                          items: user.badges,
                          emptyText: 'No badges selected yet.',
                        ),
                        const SizedBox(height: 18),
                        const _GroupLabel(text: 'MY STUFF'),
                        const SizedBox(height: 8),
                        _SoftCard(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              _LinkTile(
                                icon: Icons.favorite_rounded,
                                color: AppColors.pink,
                                title: 'My Wishlist',
                                subtitle: 'Saved items & price drops',
                                onTap: () => AppNavigator.push(
                                  context,
                                  const WishlistScreen(),
                                ),
                              ),
                              const _TileDivider(),
                              _LinkTile(
                                icon: Icons.receipt_long_rounded,
                                color: const Color(0xFF3867D6),
                                title: 'Purchase history',
                                subtitle: 'Orders, bills & tracking',
                                onTap: () => AppNavigator.push(
                                  context,
                                  const PurchaseHistoryScreen(),
                                ),
                              ),
                              const _TileDivider(),
                              _LinkTile(
                                icon: Icons.bookmarks_rounded,
                                color: AppColors.purple,
                                title: 'Saved bookmarks',
                                subtitle: 'Posts you saved',
                                onTap: () => AppNavigator.push(
                                  context,
                                  const BookmarksScreen(),
                                ),
                              ),
                              const _TileDivider(),
                              _LinkTile(
                                icon: Icons.offline_pin_rounded,
                                color: AppColors.success,
                                title: 'Offline content',
                                subtitle: 'Read without internet',
                                onTap: () => AppNavigator.push(
                                  context,
                                  const BookmarksScreen(offlineView: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _GroupLabel(text: 'SUPPORT'),
                        const SizedBox(height: 8),
                        _SoftCard(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              _LinkTile(
                                icon: Icons.support_agent_rounded,
                                color: const Color(0xFF20BF6B),
                                title: 'Contact Us',
                                subtitle: 'Send us an enquiry',
                                onTap: () => AppNavigator.push(
                                  context,
                                  ContactUsScreen(user: user),
                                ),
                              ),
                              const _TileDivider(),
                              _LinkTile(
                                icon: Icons.groups_rounded,
                                color: const Color(0xFF4B6584),
                                title: 'About Us',
                                subtitle: 'The team behind the app',
                                onTap: () => AppNavigator.push(
                                  context,
                                  AboutUsScreen(user: user),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Log out',
                          icon: Icons.logout_rounded,
                          outlined: true,
                          onPressed: () => confirmLogout(context),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.onEdit,
    required this.onAvatarUploaded,
  });

  final AppUser user;
  final VoidCallback onEdit;
  final ValueChanged<String> onAvatarUploaded;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
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
            Positioned(
              top: -50,
              right: -40,
              child: _Bubble(size: 180, opacity: 0.10),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _Bubble(size: 160, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 22),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (canPop)
                          _GlassButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          )
                        else
                          const SizedBox(width: 48),
                        const Expanded(
                          child: Text(
                            'My Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _GlassButton(
                          icon: Icons.edit_rounded,
                          tooltip: 'Edit profile',
                          onTap: onEdit,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AvatarUploader(
                      initials: user.initials,
                      imageUrl: user.avatarUrl,
                      onUploaded: onAvatarUploaded,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the photo to change it',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite,
                          size: 14,
                          color: AppColors.pink,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.role.label,
                          style: const TextStyle(
                            color: AppColors.pink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          value: '${user.selectedFandoms.length}',
                          label: user.selectedFandoms.length == 1
                              ? 'Fandom'
                              : 'Fandoms',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatBox(
                          value: '${user.badges.length}',
                          label: user.badges.length == 1 ? 'Badge' : 'Badges',
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
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
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

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
        border: Border.all(color: const Color(0x1FA23CF0)),
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChipsCard extends StatelessWidget {
  const _ChipsCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    this.gradient = false,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final String emptyText;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title: title, icon: icon),
          if (items.isEmpty)
            Text(emptyText, style: Theme.of(context).textTheme.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: gradient ? AppColors.buttonGradient : null,
                      color: gradient ? null : AppColors.lavender,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          gradient
                              ? Icons.auto_awesome_rounded
                              : Icons.military_tech_rounded,
                          size: 14,
                          color: gradient ? Colors.white : AppColors.purple,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item,
                          style: TextStyle(
                            color: gradient ? Colors.white : AppColors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 70,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.lavender,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.purple,
        ),
      ),
      onTap: onTap,
    );
  }
}
