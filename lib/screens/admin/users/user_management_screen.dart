import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_user.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/user_admin_service.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/user_avatar.dart';
import '../widgets/admin_ui.dart';
import 'add_user_screen.dart';
import 'user_detail_screen.dart';

enum _UserFilter { all, fans, admins, blocked }

extension on _UserFilter {
  String get label {
    switch (this) {
      case _UserFilter.all:
        return 'All';
      case _UserFilter.fans:
        return 'Fans';
      case _UserFilter.admins:
        return 'Admins';
      case _UserFilter.blocked:
        return 'Blocked';
    }
  }
}

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Stream<List<AppUser>> _stream =
      UserAdminService.instance.watchAllUsers();
  final _searchController = TextEditingController();
  String _query = '';
  _UserFilter _filter = _UserFilter.all;

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = UserAdminService.instance.watchAllUsers());
  }

  String _joined(DateTime? date) {
    if (date == null) return 'Joined recently';
    return 'Joined ${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  List<AppUser> _apply(List<AppUser> users) {
    final query = _query.trim().toLowerCase();
    return users.where((user) {
      switch (_filter) {
        case _UserFilter.fans:
          if (!user.isFan) return false;
          break;
        case _UserFilter.admins:
          if (!user.isAdmin) return false;
          break;
        case _UserFilter.blocked:
          if (!user.isBlocked) return false;
          break;
        case _UserFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();
  }

  Widget _header({int? total, int? blocked}) {
    return AdminPageHeader(
      title: 'Users',
      subtitle: 'View, add, edit and block fan accounts.',
      icon: Icons.manage_accounts_rounded,
      chips: [
        if (total != null && blocked != null) ...[
          AdminHeaderChip(
            icon: Icons.groups_rounded,
            label: '$total ${total == 1 ? 'user' : 'users'}',
            color: AppColors.primary,
          ),
          if (blocked > 0)
            AdminHeaderChip(
              icon: Icons.block_rounded,
              label: '$blocked blocked',
              color: AppColors.error,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snapshot) {
        final fab = AdminGradientFab(
          label: 'Add fan',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: () => AppNavigator.push(context, const AddUserScreen()),
        );

        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: ErrorView(
              message: 'Could not load users.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: const LoadingView(message: 'Loading users...'),
          );
        }

        final all = snapshot.data!;
        final fans = all.where((user) => user.isFan).length;
        final admins = all.where((user) => user.isAdmin).length;
        final blocked = all.where((user) => user.isBlocked).length;
        final visible = _apply(all);

        return AdminPageScaffold(
          header: _header(total: all.length, blocked: blocked),
          floatingActionButton: fab,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AdminStatBox(
                          label: 'Fans',
                          value: '$fans',
                          icon: Icons.favorite_rounded,
                          color: AppColors.pink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Admins',
                          value: '$admins',
                          icon: Icons.admin_panel_settings_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Blocked',
                          value: '$blocked',
                          icon: Icons.block_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminSearchField(
                    controller: _searchController,
                    hint: 'Search by name or email',
                    query: _query,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in _UserFilter.values)
                        AdminFilterPill(
                          label: filter.label,
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: _filter == _UserFilter.all
                        ? 'All users'
                        : _filter.label,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${visible.length} '
                        '${visible.length == 1 ? 'user' : 'users'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    AdminEmptyNote(
                      icon: _query.isEmpty
                          ? Icons.person_off_rounded
                          : Icons.search_off_rounded,
                      text: _query.isEmpty
                          ? 'No ${_filter.label.toLowerCase()} users.'
                          : 'No users match "$_query".',
                    )
                  else
                    for (final user in visible) ...[
                      _UserCard(
                        user: user,
                        isMe: user.uid == myUid,
                        joinedLabel: _joined(user.createdAt),
                        onTap: () => AppNavigator.push(
                          context,
                          UserDetailScreen(uid: user.uid),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isMe,
    required this.joinedLabel,
    required this.onTap,
  });

  final AppUser user;
  final bool isMe;
  final String joinedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ringColor = user.isBlocked
        ? AppColors.error
        : (user.isAdmin ? AppColors.purple : AppColors.pink);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: user.isBlocked
              ? const Color(0x66E5484D)
              : const Color(0x26A23CF0),
          width: user.isBlocked ? 1.4 : 1,
        ),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                  child: UserAvatar(
                    initials: user.initials,
                    imageUrl: user.avatarUrl,
                    radius: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name.isEmpty ? 'No name' : user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Tag(
                            text: user.role.label,
                            background: user.isAdmin
                                ? AppColors.lavender
                                : AppColors.softPink,
                            foreground: user.isAdmin
                                ? AppColors.purple
                                : AppColors.pink,
                          ),
                          if (user.isBlocked)
                            const _Tag(
                              text: 'Blocked',
                              background: Color(0x22E5484D),
                              foreground: AppColors.error,
                            ),
                          if (isMe)
                            const _Tag(
                              text: 'You',
                              background: Color(0x226C4DFF),
                              foreground: AppColors.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: colors.outline,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              joinedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.purple,
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

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
