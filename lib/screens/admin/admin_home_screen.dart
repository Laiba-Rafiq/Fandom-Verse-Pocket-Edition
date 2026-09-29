import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/app_user.dart';
import '../../routes/app_navigator.dart';
import '../../widgets/user_avatar.dart';
import '../common/logout_helper.dart';
import 'categories/category_management_screen.dart';
import 'content/post_management_screen.dart';
import 'events/event_management_screen.dart';
import 'inquiries/inquiry_management_screen.dart';
import 'merchandise/merchandise_management_screen.dart';
import 'orders/order_management_screen.dart';
import 'users/user_management_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.user});

  final AppUser user;

  static const String _groupContent = 'Content & Community';
  static const String _groupStore = 'Store & Orders';
  static const String _groupPeople = 'Fans & Support';

  void _open(BuildContext context, _AdminItem item) {
    final screen = item.screen;
    if (screen != null) {
      AppNavigator.push(context, screen);
    } else {
      UiHelpers.showSnack(
        context,
        '${item.title} management is coming next.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_AdminItem>[
      const _AdminItem(
        icon: Icons.article_rounded,
        title: 'Fandom Content',
        subtitle: 'News, profiles, stories, glossary, trivia and more',
        color: AppColors.primary,
        group: _groupContent,
        screen: PostManagementScreen(),
      ),
      const _AdminItem(
        icon: Icons.event_rounded,
        title: 'Events',
        subtitle: 'Add, edit or remove event listings',
        color: AppColors.warning,
        group: _groupContent,
        screen: EventManagementScreen(),
      ),
      const _AdminItem(
        icon: Icons.category_rounded,
        title: 'Categories',
        subtitle: 'Add, edit or remove categories',
        color: AppColors.success,
        group: _groupContent,
        screen: CategoryManagementScreen(),
      ),
      const _AdminItem(
        icon: Icons.storefront_rounded,
        title: 'Merchandise',
        subtitle: 'Add, edit or remove merchandise products',
        color: AppColors.accent,
        group: _groupStore,
        screen: MerchandiseManagementScreen(),
      ),
      const _AdminItem(
        icon: Icons.receipt_long_rounded,
        title: 'Orders',
        subtitle: 'View fans\' simulated orders and bills',
        color: Color(0xFF3867D6),
        group: _groupStore,
        screen: OrderManagementScreen(),
      ),
      const _AdminItem(
        icon: Icons.mark_email_unread_rounded,
        title: 'Enquiries',
        subtitle: 'Read and reply to Contact Us messages',
        color: AppColors.pink,
        group: _groupPeople,
        screen: InquiryManagementScreen(),
      ),
      const _AdminItem(
        icon: Icons.manage_accounts_rounded,
        title: 'Users',
        subtitle: 'View, add, edit and block fan accounts',
        color: AppColors.secondary,
        group: _groupPeople,
        screen: UserManagementScreen(),
      ),
    ];

    const groups = [_groupContent, _groupStore, _groupPeople];
    const groupIcons = {
      _groupContent: Icons.auto_stories_rounded,
      _groupStore: Icons.shopping_bag_rounded,
      _groupPeople: Icons.groups_rounded,
    };

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
              _AdminHeader(
                user: user,
                moduleCount: items.length,
                onLogout: () => confirmLogout(context),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final group in groups) ...[
                          _GroupTitle(
                            title: group,
                            icon: groupIcons[group]!,
                            count: items
                                .where((item) => item.group == group)
                                .length,
                          ),
                          const SizedBox(height: 12),
                          _TileGrid(
                            items: items
                                .where((item) => item.group == group)
                                .toList(),
                            onTap: (item) => _open(context, item),
                          ),
                          const SizedBox(height: 22),
                        ],
                        const _FooterNote(),
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

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.user,
    required this.moduleCount,
    required this.onLogout,
  });

  final AppUser user;
  final int moduleCount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.adminGradient,
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
              top: -60,
              right: -40,
              child: IgnorePointer(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -30,
              child: IgnorePointer(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 12, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Admin Console',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: IconButton(
                          tooltip: 'Log out',
                          onPressed: onLogout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: UserAvatar(
                          initials: user.initials,
                          imageUrl: user.avatarUrl,
                          radius: 28,
                          onDark: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello,',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _HeroChip(
                        icon: Icons.verified_user_rounded,
                        label: 'Administrator',
                        color: AppColors.purple,
                      ),
                      _HeroChip(
                        icon: Icons.dashboard_customize_rounded,
                        label: '$moduleCount modules',
                        color: AppColors.pink,
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1F1147),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({
    required this.title,
    required this.icon,
    required this.count,
  });

  final String title;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: AppColors.purple),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.items, required this.onTap});

  final List<_AdminItem> items;
  final ValueChanged<_AdminItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 3 : (width >= 330 ? 2 : 1);
        final rows = <Widget>[];
        for (var start = 0; start < items.length; start += columns) {
          final rowItems = items.skip(start).take(columns).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: i < rowItems.length
                          ? _AdminTile(
                              item: rowItems[i],
                              onTap: () => onTap(rowItems[i]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (start + columns < items.length) {
            rows.add(const SizedBox(height: 12));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({required this.item, required this.onTap});

  final _AdminItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${item.title}. ${item.subtitle}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  top: -26,
                  right: -26,
                  child: IgnorePointer(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  item.color,
                                  Color.lerp(
                                      item.color, AppColors.purple, 0.35)!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: item.color.withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(item.icon, color: Colors.white),
                          ),
                          const Spacer(),
                          if (item.screen == null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Soon',
                                style: TextStyle(
                                  color: colors.outline,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.lavender,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 17,
                                color: AppColors.purple,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Changes you make here appear in the fan app right away.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminItem {
  const _AdminItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.group,
    this.screen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String group;
  final Widget? screen;
}
