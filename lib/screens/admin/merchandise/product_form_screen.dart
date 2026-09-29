import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/product.dart';
import '../../../services/category_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/product_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/chip_selector.dart';
import '../../../widgets/multi_image_upload_box.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController =
      TextEditingController(text: widget.product?.name ?? '');
  late final TextEditingController _priceController =
      TextEditingController(text: _initialPrice());
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.product?.description ?? '');
  late final TextEditingController _characterController =
      TextEditingController(text: widget.product?.characterSubject ?? '');
  late final Future<List<String>> _fandomsFuture =
      CategoryService.instance.getCategoryNames();

  late String _category = widget.product?.category ?? Product.categories.first;
  late String? _fandom = widget.product?.fandom;
  late List<String> _images = List<String>.from(widget.product?.images ?? []);
  late List<String> _sizes = List<String>.from(widget.product?.sizes ?? []);
  late String? _collectibleType = widget.product?.collectibleType;
  late String? _edition = widget.product?.edition;
  late String? _digitalAssetType = widget.product?.digitalAssetType;

  bool _saving = false;
  String? _error;
  String? _imagesError;
  String? _sizesError;
  String? _typeError;

  bool get _isEditing => widget.product != null;

  String _initialPrice() {
    final price = widget.product?.price;
    if (price == null) return '';
    return price % 1 == 0 ? price.toStringAsFixed(0) : price.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter a product name';
    if (text.length < 2) return 'Name must be at least 2 characters';
    if (text.length > 60) return 'Name must be 60 characters or less';
    return null;
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter a price';
    final price = double.tryParse(text);
    if (price == null) return 'Please enter a valid number';
    if (price <= 0) return 'Price must be greater than 0';
    if (price > 10000000) return 'Price is too high';
    return null;
  }

  void _selectCategory(String category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _sizes = [];
      _collectibleType = null;
      _edition = null;
      _digitalAssetType = null;
      _characterController.clear();
      _sizesError = null;
      _typeError = null;
    });
  }

  bool _validateExtras() {
    String? imagesError;
    String? sizesError;
    String? typeError;

    if (_images.isEmpty) {
      imagesError = 'Please add at least one product image.';
    }
    if (_category == Product.apparel && _sizes.isEmpty) {
      sizesError = 'Please select at least one size.';
    }
    if (_category == Product.collectibles && _collectibleType == null) {
      typeError = 'Please select a collectible type.';
    }
    if (_category == Product.digitalAssets && _digitalAssetType == null) {
      typeError = 'Please select a digital asset type.';
    }

    setState(() {
      _imagesError = imagesError;
      _sizesError = sizesError;
      _typeError = typeError;
    });

    final firstError = imagesError ?? sizesError ?? typeError;
    if (firstError != null) {
      UiHelpers.showSnack(context, firstError, isError: true);
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final formOk = _formKey.currentState!.validate();
    final extrasOk = _validateExtras();
    if (!formOk || !extrasOk) return;

    final price = double.parse(_priceController.text.trim());

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await ProductService.instance.updateProduct(
          id: widget.product!.id,
          name: _nameController.text,
          price: price,
          category: _category,
          images: _images,
          description: _descriptionController.text,
          fandom: _fandom,
          sizes: _sizes,
          collectibleType: _collectibleType,
          edition: _edition,
          digitalAssetType: _digitalAssetType,
          characterSubject: _characterController.text,
        );
      } else {
        await ProductService.instance.addProduct(
          name: _nameController.text,
          price: price,
          category: _category,
          images: _images,
          description: _descriptionController.text,
          fandom: _fandom,
          sizes: _sizes,
          collectibleType: _collectibleType,
          edition: _edition,
          digitalAssetType: _digitalAssetType,
          characterSubject: _characterController.text,
        );
      }
      if (!mounted) return;
      UiHelpers.showSnack(
        context,
        _isEditing ? 'Product updated!' : 'Product added!',
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not save the product. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) {
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

  Widget _fieldError(String? message) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _singleChoice({
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _ChoicePill(
            label: option,
            selected: selected == option,
            onTap: _saving
                ? null
                : () => onChanged(selected == option ? null : option),
          ),
      ],
    );
  }

  List<Widget> _categoryFields() {
    if (_category == Product.apparel) {
      return [
        _label('Available Sizes *'),
        ChipSelector(
          options: Product.apparelSizes,
          selected: _sizes,
          enabled: !_saving,
          onChanged: (list) => setState(() {
            _sizes = list;
            if (list.isNotEmpty) _sizesError = null;
          }),
        ),
        _fieldError(_sizesError),
      ];
    }

    if (_category == Product.collectibles) {
      return [
        _label('Collectible Type *'),
        _singleChoice(
          options: Product.collectibleTypes,
          selected: _collectibleType,
          onChanged: (value) => setState(() {
            _collectibleType = value;
            if (value != null) _typeError = null;
          }),
        ),
        _fieldError(_typeError),
        const SizedBox(height: 20),
        _label('Edition (optional)'),
        _singleChoice(
          options: Product.editions,
          selected: _edition,
          onChanged: (value) => setState(() => _edition = value),
        ),
      ];
    }

    return [
      _label('Digital Asset Type *'),
      _singleChoice(
        options: Product.digitalAssetTypes,
        selected: _digitalAssetType,
        onChanged: (value) => setState(() {
          _digitalAssetType = value;
          if (value != null) _typeError = null;
        }),
      ),
      _fieldError(_typeError),
      const SizedBox(height: 20),
      AppTextField(
        controller: _characterController,
        label: 'Character / Subject (optional)',
        hint: 'e.g. Gojo Satoru',
        icon: Icons.face_outlined,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        enabled: !_saving,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      header: AdminPageHeader(
        title: _isEditing ? 'Edit product' : 'Add product',
        subtitle: _isEditing
            ? 'Update the price, images or details of this product.'
            : 'Add apparel, collectibles or digital assets to the store.',
        icon: _isEditing ? Icons.edit_rounded : Icons.add_business_rounded,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
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
                    title: 'Product images',
                    icon: Icons.photo_library_rounded,
                    subtitle: 'At least one image. The first one is the cover.',
                    children: [
                      MultiImageUploadBox(
                        label: 'Product images *',
                        folder: CloudinaryFolders.products,
                        images: _images,
                        maxImages: Product.maxImages,
                        enabled: !_saving,
                        errorText: _imagesError,
                        onChanged: (list) => setState(() {
                          _images = list;
                          if (list.isNotEmpty) _imagesError = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormCard(
                    title: 'Basic details',
                    icon: Icons.shopping_bag_rounded,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: 'Product name',
                        hint: 'e.g. Naruto Hoodie',
                        icon: Icons.shopping_bag_outlined,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _priceController,
                        label: 'Price (${Product.currencySymbol})',
                        hint: 'e.g. 2500',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _validatePrice,
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (optional)',
                        hint: 'Material, size, edition...',
                        icon: Icons.notes_rounded,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !_saving,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormCard(
                    title: 'Category & fandom',
                    icon: Icons.category_rounded,
                    children: [
                      _label('Category *'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in Product.categories)
                            _ChoicePill(
                              label: category,
                              selected: _category == category,
                              onTap: _saving
                                  ? null
                                  : () => _selectCategory(category),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _label('Fandom (optional)'),
                      FutureBuilder<List<String>>(
                        future: _fandomsFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: LoadingView(),
                            );
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final fandom in snapshot.data!)
                                _ChoicePill(
                                  label: fandom,
                                  selected: _fandom == fandom,
                                  onTap: _saving
                                      ? null
                                      : () => setState(
                                            () => _fandom = _fandom == fandom
                                                ? null
                                                : fandom,
                                          ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormCard(
                    title: '$_category options',
                    icon: _category == Product.apparel
                        ? Icons.checkroom_rounded
                        : (_category == Product.collectibles
                            ? Icons.auto_awesome_rounded
                            : Icons.cloud_download_rounded),
                    children: _categoryFields(),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: _isEditing ? 'Save changes' : 'Add product',
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

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
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
