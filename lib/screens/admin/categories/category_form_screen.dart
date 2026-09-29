import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fandom_category.dart';
import '../../../services/category_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/image_upload_box.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, this.category});

  final FandomCategory? category;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.category?.name ?? '');
  late String? _imageUrl = widget.category?.imageUrl;

  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter a category name';
    if (text.length < 2) return 'Name must be at least 2 characters';
    if (text.length > 30) return 'Name must be 30 characters or less';
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await CategoryService.instance.updateCategory(
          id: widget.category!.id,
          name: _nameController.text,
          imageUrl: _imageUrl,
        );
      } else {
        await CategoryService.instance.addCategory(
          name: _nameController.text,
          imageUrl: _imageUrl,
        );
      }
      if (!mounted) return;
      UiHelpers.showSnack(
        context,
        _isEditing ? 'Category updated!' : 'Category added!',
      );
      Navigator.of(context).pop();
    } on CategoryException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not save the category. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: AdminPageHeader(
        title: _isEditing ? 'Edit category' : 'Add category',
        subtitle: _isEditing
            ? 'Update the name or image of this category.'
            : 'Create a new fandom category for fans to follow.',
        icon: _isEditing ? Icons.edit_rounded : Icons.add_rounded,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    FormErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  _FormCard(
                    title: 'Details',
                    icon: Icons.label_rounded,
                    child: AppTextField(
                      controller: _nameController,
                      label: 'Category name',
                      hint: 'e.g. Anime & Manga',
                      icon: Icons.category_outlined,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      validator: _validateName,
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormCard(
                    title: 'Image',
                    icon: Icons.image_rounded,
                    child: ImageUploadBox(
                      label: 'Category image',
                      folder: CloudinaryFolders.categories,
                      imageUrl: _imageUrl,
                      enabled: !_saving,
                      onChanged: (url) => setState(() => _imageUrl = url),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _isEditing ? 'Save changes' : 'Add category',
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                    onPressed: _save,
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

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

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
          child,
        ],
      ),
    );
  }
}