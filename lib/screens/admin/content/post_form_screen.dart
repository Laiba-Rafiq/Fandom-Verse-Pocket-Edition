import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fandom_post.dart';
import '../../../services/category_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/post_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/multi_image_upload_box.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';

class PostFormScreen extends StatefulWidget {
  const PostFormScreen({super.key, this.post, this.initialType});

  final FandomPost? post;
  final ContentType? initialType;

  @override
  State<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends State<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final TextEditingController _bodyController;
  late final TextEditingController _mediaController;
  late final TextEditingController _sourceController;
  late final TextEditingController _tagsController;

  late ContentType _type;
  List<String> _images = [];
  List<String> _fandoms = [];
  bool _loadingFandoms = true;
  String? _fandom;
  bool _featured = false;
  bool _saving = false;
  bool _showFandomError = false;
  bool _showImageError = false;
  String? _error;

  bool get _isEdit => widget.post != null;

  @override
  void initState() {
    super.initState();
    final post = widget.post;
    _type = post?.type ?? widget.initialType ?? ContentType.news;
    _titleController = TextEditingController(text: post?.title ?? '');
    _summaryController = TextEditingController(text: post?.summary ?? '');
    _bodyController = TextEditingController(text: post?.body ?? '');
    _mediaController = TextEditingController(text: post?.mediaUrl ?? '');
    _sourceController = TextEditingController(text: post?.sourceUrl ?? '');
    _tagsController =
        TextEditingController(text: post == null ? '' : post.tags.join(', '));
    _images = List<String>.from(post?.images ?? const <String>[]);
    _fandom = post?.fandom;
    _featured = post?.isFeatured ?? false;
    _loadFandoms();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _bodyController.dispose();
    _mediaController.dispose();
    _sourceController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadFandoms() async {
    final names = await CategoryService.instance.getCategoryNames();
    if (!mounted) return;
    final list = <String>[...names];
    if (!list.contains('General')) list.add('General');
    final current = _fandom;
    if (current != null && current.isNotEmpty && !list.contains(current)) {
      list.insert(0, current);
    }
    setState(() {
      _fandoms = list;
      _loadingFandoms = false;
    });
  }

  void _selectSection(ContentSection section) {
    if (_type.section == section) return;
    setState(() {
      _type = section.types.first;
      _showImageError = false;
    });
  }

  void _selectType(ContentType type) {
    setState(() {
      _type = type;
      _showImageError = false;
    });
  }

  String get _titleLabel => _type.isGlossary ? 'Term' : 'Title';

  String get _titleHint {
    switch (_type) {
      case ContentType.glossary:
        return 'e.g. Canon';
      case ContentType.profile:
        return 'e.g. The Chosen One: a classic hero';
      case ContentType.interview:
        return 'e.g. Interview: building armour from foam';
      default:
        return 'e.g. Cosplay contest registrations are open';
    }
  }

  String get _summaryLabel => _type.isGlossary ? 'Meaning' : 'Short summary';

  String get _bodyLabel {
    if (_type.isGlossary) return 'Example (optional)';
    if (_type == ContentType.interview) {
      return 'Interview (questions & answers)';
    }
    if (PostService.minBodyLength(_type) == 0) return 'Description (optional)';
    return 'Full content';
  }

  String get _mediaLabel => _type == ContentType.video
      ? 'Video link (e.g. YouTube)'
      : 'Podcast link (e.g. Spotify)';

  String? _validateTitle(String? value) {
    if ((value ?? '').trim().length < 2) {
      return _type.isGlossary
          ? 'Please enter the term.'
          : 'Please enter a title (min 2 characters).';
    }
    return null;
  }

  String? _validateSummary(String? value) {
    final min = PostService.minSummaryLength(_type);
    if ((value ?? '').trim().length < min) {
      return _type.isGlossary
          ? 'Please enter the meaning (min $min characters).'
          : 'Please enter a short summary (min $min characters).';
    }
    return null;
  }

  String? _validateBody(String? value) {
    final min = PostService.minBodyLength(_type);
    if (min == 0) return null;
    if ((value ?? '').trim().length < min) {
      return 'Please write the full content (min $min characters).';
    }
    return null;
  }

  String? _validateMedia(String? value) {
    if (!_type.needsMediaLink) return null;
    final url = PostService.normalizeUrl(value);
    if (url == null) {
      return 'Please add the ${_type.label.toLowerCase()} link.';
    }
    if (!PostService.isValidUrl(url)) return 'Please enter a valid link.';
    return null;
  }

  String? _validateSource(String? value) {
    final url = PostService.normalizeUrl(value);
    if (url == null) return null;
    if (!PostService.isValidUrl(url)) return 'Please enter a valid link.';
    return null;
  }

  String? _validateTags(String? value) {
    final tags = PostService.parseTags(value ?? '');
    if (tags.length > PostService.maxTags) {
      return 'You can add up to ${PostService.maxTags} tags.';
    }
    if (tags.any((tag) => tag.length > 24)) {
      return 'Each tag can be up to 24 characters.';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _showFandomError = _fandom == null;
      _showImageError = _type.needsImages && _images.isEmpty;
      _error = null;
    });
    final fandom = _fandom;
    if (!formOk || fandom == null || _showImageError) return;

    setState(() => _saving = true);
    try {
      final service = PostService.instance;
      final tags = PostService.parseTags(_tagsController.text);
      final media = _type.needsMediaLink ? _mediaController.text : null;
      final post = widget.post;
      if (post == null) {
        await service.addPost(
          title: _titleController.text,
          type: _type,
          fandom: fandom,
          summary: _summaryController.text,
          body: _bodyController.text,
          images: _images,
          tags: tags,
          mediaUrl: media,
          sourceUrl: _sourceController.text,
          isFeatured: _featured,
        );
      } else {
        await service.updatePost(
          id: post.id,
          title: _titleController.text,
          type: _type,
          fandom: fandom,
          summary: _summaryController.text,
          body: _bodyController.text,
          images: _images,
          tags: tags,
          mediaUrl: media,
          sourceUrl: _sourceController.text,
          isFeatured: _featured,
        );
      }
      if (!mounted) return;
      UiHelpers.showSnack(
          context, _isEdit ? 'Post updated.' : 'Post published.');
      Navigator.of(context).pop(true);
    } on PostException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyOptional = PostService.minBodyLength(_type) == 0;

    return AdminPageScaffold(
      header: AdminPageHeader(
        title: _isEdit ? 'Edit Post' : 'Add Post',
        subtitle: _isEdit
            ? 'Update this post. Changes show for fans right away.'
            : 'Publish news, profiles, stories, trivia and more.',
        icon: _isEdit ? Icons.edit_note_rounded : Icons.post_add_rounded,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      FormErrorBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    _FormCard(
                      title: 'Where should it appear?',
                      icon: Icons.dashboard_customize_rounded,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final section in ContentSection.values)
                              _Pill(
                                label: section.label,
                                icon: section.icon,
                                selected: _type.section == section,
                                onTap: () => _selectSection(section),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _SubLabel('Type'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in _type.section.types)
                              _Pill(
                                label: type.label,
                                icon: type.icon,
                                selected: _type == type,
                                onTap: () => _selectType(type),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.lavender.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.purple,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _type.section.description,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Content',
                      icon: Icons.article_rounded,
                      children: [
                        AppTextField(
                          controller: _titleController,
                          label: _titleLabel,
                          hint: _titleHint,
                          icon: _type.icon,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          validator: _validateTitle,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _summaryController,
                          label: _summaryLabel,
                          hint: _type.isGlossary
                              ? 'What does this word mean?'
                              : 'One or two lines shown on the card',
                          icon: Icons.short_text_rounded,
                          maxLines: 2,
                          maxLength: 240,
                          textCapitalization: TextCapitalization.sentences,
                          validator: _validateSummary,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _bodyController,
                          label: _bodyLabel,
                          hint: bodyOptional
                              ? 'Optional extra details'
                              : 'Write the full article, story or lore here...',
                          icon: Icons.notes_rounded,
                          maxLines: _type.isGlossary ? 3 : 10,
                          maxLength: 10000,
                          textCapitalization: TextCapitalization.sentences,
                          validator: _validateBody,
                        ),
                        if (_type.needsMediaLink) ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _mediaController,
                            label: _mediaLabel,
                            hint: 'https://...',
                            icon: _type == ContentType.video
                                ? Icons.smart_display_rounded
                                : Icons.podcasts_rounded,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            validator: _validateMedia,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Fandom',
                      icon: Icons.favorite_rounded,
                      subtitle: 'Which fandom is this post about?',
                      children: [
                        if (_loadingFandoms)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              color: AppColors.pink,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final name in _fandoms)
                                _Pill(
                                  label: name,
                                  selected: _fandom == name,
                                  onTap: () => setState(() {
                                    _fandom = name;
                                    _showFandomError = false;
                                  }),
                                ),
                            ],
                          ),
                        if (_showFandomError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              'Please choose a fandom.',
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Images',
                      icon: Icons.photo_library_rounded,
                      children: [
                        MultiImageUploadBox(
                          images: _images,
                          folder: CloudinaryFolders.posts,
                          maxImages: PostService.maxImages,
                          label: _type.needsImages
                              ? 'Gallery images (at least 1)'
                              : 'Images (optional, first one is the cover)',
                          enabled: !_saving,
                          errorText: _showImageError
                              ? 'A gallery needs at least one image.'
                              : null,
                          onChanged: (images) => setState(() {
                            _images = images;
                            if (images.isNotEmpty) _showImageError = false;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Extra details',
                      icon: Icons.tune_rounded,
                      children: [
                        AppTextField(
                          controller: _sourceController,
                          label: 'Source link (optional)',
                          hint: 'Where did this information come from?',
                          icon: Icons.link_rounded,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          validator: _validateSource,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _tagsController,
                          label: 'Tags (optional)',
                          hint: 'cosplay, beginner, lore',
                          icon: Icons.sell_outlined,
                          textInputAction: TextInputAction.done,
                          validator: _validateTags,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: _featured
                                ? const LinearGradient(
                                    colors: [
                                      Color(0x26F5A524),
                                      Color(0x14F0357A),
                                    ],
                                  )
                                : null,
                            color: _featured ? null : AppColors.lavender,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _featured
                                  ? AppColors.warning.withValues(alpha: 0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: SwitchListTile(
                            value: _featured,
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _featured = value),
                            activeThumbColor: AppColors.pink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            secondary: const Icon(
                              Icons.star_rounded,
                              color: AppColors.warning,
                            ),
                            title: const Text(
                              'Feature in Trending',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text(
                              'Show this post in the trending carousel on Home.',
                              style: TextStyle(color: AppColors.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: _isEdit ? 'Save changes' : 'Publish post',
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
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: textTheme.bodySmall),
                  ],
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

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.purple,
            ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Container(
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0x33A23CF0),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x33F0357A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected)
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  else if (icon != null)
                    Icon(icon, size: 16, color: AppColors.purple),
                  if (selected || icon != null) const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
