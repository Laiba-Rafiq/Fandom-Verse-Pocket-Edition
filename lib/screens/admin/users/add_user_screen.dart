import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../services/user_admin_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final email = _emailController.text.trim();
      await UserAdminService.instance.createFan(
        name: _nameController.text,
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      UiHelpers.showSnack(context, 'Fan account created for $email.');
      Navigator.of(context).pop(true);
    } on UserAdminException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not create the account. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: const AdminPageHeader(
        title: 'Add Fan',
        subtitle: 'Create a new fan account with email and password.',
        icon: Icons.person_add_alt_1_rounded,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _InfoCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Create a fan account',
                      text: 'The fan can log in with this email and password. '
                          'They will choose their fandoms and badges on '
                          'their first login.',
                    ),
                    const SizedBox(height: 18),
                    if (_error != null) ...[
                      FormErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    _FormCard(
                      title: 'Fan details',
                      icon: Icons.badge_rounded,
                      children: [
                        AppTextField(
                          controller: _nameController,
                          label: 'Full name',
                          hint: 'e.g. Ali Khan',
                          icon: Icons.person_outline_rounded,
                          maxLength: UserAdminService.maxNameLength,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: Validators.name,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'fan@example.com',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Password',
                      icon: Icons.lock_rounded,
                      children: [
                        AppTextField(
                          controller: _passwordController,
                          label: 'Temporary password',
                          hint: 'At least 6 characters',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          textInputAction: TextInputAction.next,
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _confirmController,
                          label: 'Confirm password',
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _create(),
                          validator: Validators.confirmPassword(
                            () => _passwordController.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _NoteBox(
                          text: 'Share the password with the fan privately and '
                              'ask them to keep it safe. Only fan accounts can '
                              'be created here. Admin accounts are set up in '
                              'the Firebase console.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Create fan account',
                      icon: Icons.check_rounded,
                      isLoading: _saving,
                      onPressed: _create,
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

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33F0357A),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: AppColors.ink, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: AppColors.purple,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}