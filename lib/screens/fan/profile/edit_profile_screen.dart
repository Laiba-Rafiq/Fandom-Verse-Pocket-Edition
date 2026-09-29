import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../models/app_user.dart';
import '../../../services/category_service.dart';
import '../../../services/user_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/chip_selector.dart';
import '../../../widgets/state_views.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.user.name);
  late final TextEditingController _bioController =
      TextEditingController(text: widget.user.bio);
  late final Future<List<String>> _categoriesFuture =
      CategoryService.instance.getCategoryNames();

  late List<String> _fandoms = List<String>.from(widget.user.selectedFandoms);
  late List<String> _badges = List<String>.from(widget.user.badges);
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_fandoms.isEmpty) {
      UiHelpers.showSnack(
        context,
        'Please keep at least one fandom interest.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        uid: widget.user.uid,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        selectedFandoms: _fandoms,
        badges: _badges,
      );
      if (!mounted) return;
      UiHelpers.showSnack(context, 'Profile updated!');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      UiHelpers.showSnack(
        context,
        'Could not update your profile. Please try again.',
        isError: true,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditHeader(user: widget.user),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCard(
                            title: 'About you',
                            icon: Icons.person_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppTextField(
                                  controller: _nameController,
                                  label: 'Full name',
                                  icon: Icons.person_outline,
                                  textCapitalization: TextCapitalization.words,
                                  validator: Validators.name,
                                  enabled: !_saving,
                                ),
                                const SizedBox(height: 16),
                                AppTextField(
                                  controller: _bioController,
                                  label: 'Bio',
                                  hint: 'Tell other fans about yourself',
                                  icon: Icons.notes_rounded,
                                  maxLines: 3,
                                  maxLength: 200,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  enabled: !_saving,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Fandom interests',
                            icon: Icons.favorite_rounded,
                            badge: '${_fandoms.length} selected',
                            subtitle: 'Keep at least one. Event reminders '
                                'follow these fandoms.',
                            child: FutureBuilder<List<String>>(
                              future: _categoriesFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: LoadingView(),
                                  );
                                }
                                final options = <String>{
                                  ...snapshot.data!,
                                  ..._fandoms,
                                }.toList();
                                return ChipSelector(
                                  options: options,
                                  selected: _fandoms,
                                  enabled: !_saving,
                                  onChanged: (list) =>
                                      setState(() => _fandoms = list),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SectionCard(
                            title: 'Badges',
                            icon: Icons.military_tech_rounded,
                            badge: '${_badges.length} selected',
                            subtitle: 'Pick the badges that describe you.',
                            child: ChipSelector(
                              options: AppConstants.profileBadges,
                              selected: _badges,
                              enabled: !_saving,
                              onChanged: (list) =>
                                  setState(() => _badges = list),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F6C4DFF),
                blurRadius: 18,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: AppButton(
                label: 'Save changes',
                icon: Icons.check_rounded,
                isLoading: _saving,
                onPressed: _save,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 8, 16, 20),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update your name, bio and interests',
                          style: TextStyle(
                            color: Color(0xE0FFFFFF),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.badge,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = subtitle;
    final chip = badge;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x126C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
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
              if (chip != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavender,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chip,
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
