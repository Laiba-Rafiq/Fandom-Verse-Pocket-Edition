import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/app_user.dart';
import '../../../services/user_admin_service.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/state_views.dart';
import '../../../widgets/user_avatar.dart';
import '../widgets/admin_ui.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.uid});

  final String uid;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late Stream<AppUser?> _stream =
      UserAdminService.instance.watchUser(widget.uid);
  bool _busy = false;

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

  bool get _isMe => FirebaseAuth.instance.currentUser?.uid == widget.uid;

  void _retry() {
    setState(() => _stream = UserAdminService.instance.watchUser(widget.uid));
  }

  String _date(DateTime? value) {
    if (value == null) return 'Unknown';
    return '${value.day} ${_months[value.month - 1]} ${value.year}';
  }

  Future<void> _toggleBlock(AppUser user) async {
    final block = !user.isBlocked;
    final confirmed = await UiHelpers.confirm(
      context,
      title: block ? 'Block ${user.name}?' : 'Unblock ${user.name}?',
      message: block
          ? 'This fan will not be able to use the app until you unblock '
              'them. Their data stays safe.'
          : 'This fan will be able to use the app again.',
      confirmText: block ? 'Block' : 'Unblock',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await UserAdminService.instance.setBlocked(user, block);
      if (mounted) {
        UiHelpers.showSnack(
          context,
          block
              ? '${user.name} has been blocked.'
              : '${user.name} is active again.',
        );
      }
    } on UserAdminException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update this user. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(AppUser user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditUserDialog(user: user),
    );
    if (saved == true && mounted) {
      UiHelpers.showSnack(context, 'User updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const header = AdminPageHeader(
      title: 'User details',
      subtitle: 'Profile, account status and actions for this user.',
      icon: Icons.person_search_rounded,
    );

    return StreamBuilder<AppUser?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: header,
            body: ErrorView(
              message: 'Could not load this user.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AdminPageScaffold(
            header: header,
            body: LoadingView(message: 'Loading user...'),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const AdminPageScaffold(
            header: header,
            body: EmptyStateView(
              icon: Icons.person_off_outlined,
              title: 'User not found',
              message: 'This user profile no longer exists.',
            ),
          );
        }

        return AdminPageScaffold(
          header: header,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  _HeaderCard(user: user, isMe: _isMe),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Account',
                    icon: Icons.manage_accounts_rounded,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: 'Joined',
                          value: _date(user.createdAt),
                        ),
                        _InfoRow(
                          icon: Icons.task_alt_rounded,
                          label: 'Profile setup',
                          value: user.profileCompleted
                              ? 'Completed'
                              : 'Not completed yet',
                        ),
                        if (user.isBlocked)
                          _InfoRow(
                            icon: Icons.block_rounded,
                            label: 'Blocked since',
                            value: _date(user.blockedAt),
                            color: AppColors.error,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Bio',
                    icon: Icons.notes_rounded,
                    child: Text(
                      user.bio.isEmpty ? 'No bio yet.' : user.bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                            color: AppColors.ink,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Fandoms',
                    icon: Icons.favorite_rounded,
                    child: _Chips(
                      items: user.selectedFandoms,
                      empty: 'No fandoms selected.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'Badges',
                    icon: Icons.military_tech_rounded,
                    child: _Chips(
                      items: user.badges,
                      empty: 'No badges selected.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _edit(user),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: const StadiumBorder(),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'Edit name & bio',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (user.isAdmin)
                    const _AdminNote()
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _toggleBlock(user),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: const StadiumBorder(),
                        backgroundColor: user.isBlocked
                            ? AppColors.success
                            : AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              user.isBlocked
                                  ? Icons.lock_open_rounded
                                  : Icons.block_rounded,
                            ),
                      label: Text(
                        user.isBlocked ? 'Unblock user' : 'Block user',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.user, required this.isMe});

  final AppUser user;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ringColor = user.isBlocked
        ? AppColors.error
        : (user.isAdmin ? AppColors.purple : AppColors.pink);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ringColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: UserAvatar(
              initials: user.initials,
              imageUrl: user.avatarUrl,
              radius: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name.isEmpty ? 'No name' : user.name,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(
                text: user.role.label,
                icon: user.isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.favorite_rounded,
                background: user.isAdmin ? AppColors.primary : AppColors.pink,
                foreground: Colors.white,
              ),
              _Tag(
                text: user.isBlocked ? 'Blocked' : 'Active',
                icon: user.isBlocked
                    ? Icons.block_rounded
                    : Icons.check_circle_rounded,
                background: user.isBlocked
                    ? const Color(0x22E5484D)
                    : const Color(0x221FA971),
                foreground:
                    user.isBlocked ? AppColors.error : AppColors.success,
              ),
              if (isMe)
                const _Tag(
                  text: 'You',
                  icon: Icons.person_rounded,
                  background: Colors.white,
                  foreground: AppColors.purple,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.purple),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.purple),
          const SizedBox(width: 10),
          Text(label, style: textTheme.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color ?? AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.items, required this.empty});

  final List<String> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(empty, style: Theme.of(context).textTheme.bodyMedium);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x26A23CF0)),
            ),
            child: Text(
              item,
              style: const TextStyle(
                color: AppColors.purple,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdminNote extends StatelessWidget {
  const _AdminNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.purple),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Admin accounts cannot be blocked from the app. Manage them in '
              'the Firebase console.',
              style: TextStyle(color: AppColors.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  const _EditUserDialog({required this.user});

  final AppUser user;

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.user.name);
  late final TextEditingController _bioController =
      TextEditingController(text: widget.user.bio);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserAdminService.instance.updateUser(
        uid: widget.user.uid,
        name: _nameController.text,
        bio: _bioController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on UserAdminException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.edit_rounded, color: AppColors.purple),
          SizedBox(width: 8),
          Text(
            'Edit user',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  FormErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                AppTextField(
                  controller: _nameController,
                  label: 'Name',
                  icon: Icons.person_outline_rounded,
                  maxLength: UserAdminService.maxNameLength,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'Please enter a name (min 2 characters).'
                      : null,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _bioController,
                  label: 'Bio',
                  icon: Icons.notes_rounded,
                  maxLines: 3,
                  maxLength: UserAdminService.maxBioLength,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}