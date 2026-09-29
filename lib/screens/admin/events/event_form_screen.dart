import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fan_event.dart';
import '../../../services/category_service.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/event_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';
import 'location_picker_screen.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final FanEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cityController;
  late final TextEditingController _venueController;
  late final TextEditingController _addressController;
  late final TextEditingController _ticketController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  List<String> _fandoms = [];
  bool _loadingFandoms = true;
  String? _fandom;
  String? _imageUrl;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _uploading = false;
  bool _saving = false;
  bool _showStartError = false;
  bool _showFandomError = false;
  String? _error;
  String? _autoCity;
  String? _autoVenue;
  String? _autoAddress;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController =
        TextEditingController(text: event?.description ?? '');
    _cityController = TextEditingController(text: event?.city ?? '');
    _venueController = TextEditingController(text: event?.venue ?? '');
    _addressController = TextEditingController(text: event?.address ?? '');
    _ticketController = TextEditingController(text: event?.ticketUrl ?? '');
    _latitudeController =
        TextEditingController(text: event?.latitude?.toString() ?? '');
    _longitudeController =
        TextEditingController(text: event?.longitude?.toString() ?? '');
    _latitudeController.addListener(_splitPastedCoordinates);
    _fandom = event?.fandom;
    _imageUrl = event?.imageUrl;
    _startsAt = event?.startsAt;
    _endsAt = event?.endsAt;
    _loadFandoms();
  }

  @override
  void dispose() {
    _latitudeController.removeListener(_splitPastedCoordinates);
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _ticketController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadFandoms() async {
    final names = await CategoryService.instance.getCategoryNames();
    if (!mounted) return;
    final list = <String>[...names];
    final current = _fandom;
    if (current != null && current.isNotEmpty && !list.contains(current)) {
      list.insert(0, current);
    }
    if (!list.contains('General')) list.add('General');
    setState(() {
      _fandoms = list;
      _loadingFandoms = false;
    });
  }

  void _splitPastedCoordinates() {
    final text = _latitudeController.text;
    if (!text.contains(',')) return;
    final parts = text.split(',');
    if (parts.length != 2) return;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return;
    _latitudeController.text = lat.toString();
    _longitudeController.text = lng.toString();
  }

  Future<void> _pickOnMap() async {
    FocusScope.of(context).unfocus();
    final query = [
      _venueController.text.trim(),
      _cityController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');

    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _parse(_latitudeController.text),
          initialLongitude: _parse(_longitudeController.text),
          initialQuery: query,
        ),
      ),
    );
    if (result == null || !mounted) return;

    _latitudeController.text = result.latitude.toString();
    _longitudeController.text = result.longitude.toString();

    final filled = <String>[];
    final city = EventService.cleanCity(result.city ?? '');
    if (_fillIfFree(_cityController, city, _autoCity)) {
      _autoCity = city;
      filled.add('city');
    }
    final venue = _trimTo(result.venue, 80);
    if (_fillIfFree(_venueController, venue, _autoVenue)) {
      _autoVenue = venue;
      filled.add('venue');
    }
    final address = _trimTo(result.address, 150);
    if (_fillIfFree(_addressController, address, _autoAddress)) {
      _autoAddress = address;
      filled.add('address');
    }

    setState(() {});
    UiHelpers.showSnack(
      context,
      filled.isEmpty
          ? 'Location added from the map.'
          : 'Location added. ${_joinWords(filled)} filled in, '
              'you can edit ${filled.length == 1 ? 'it' : 'them'}.',
    );
  }

  bool _fillIfFree(
    TextEditingController controller,
    String? value,
    String? lastAuto,
  ) {
    if (value == null || value.isEmpty) return false;
    final current = controller.text.trim();
    final untouched =
        current.isEmpty || (lastAuto != null && current == lastAuto);
    if (!untouched || current == value) return false;
    controller.text = value;
    return true;
  }

  String? _trimTo(String? value, int max) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length <= max) return text;
    return text.substring(0, max).trim();
  }

  String _joinWords(List<String> words) {
    final first = words.first[0].toUpperCase() + words.first.substring(1);
    final list = [first, ...words.skip(1)];
    if (list.length == 1) return list.first;
    return '${list.sublist(0, list.length - 1).join(', ')} and ${list.last}';
  }

  Future<void> _uploadImage() async {
    setState(() => _uploading = true);
    try {
      final result = await CloudinaryService.instance
          .pickAndUpload(folder: CloudinaryFolders.events);
      if (result != null && mounted) {
        setState(() => _imageUrl = result.secureUrl);
      }
    } on CloudinaryException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not upload the image. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<DateTime?> _pickDateTime(DateTime base) async {
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final base = _startsAt ?? DateTime(now.year, now.month, now.day, 18);
    final picked = await _pickDateTime(base);
    if (picked == null || !mounted) return;
    setState(() {
      _startsAt = picked;
      _showStartError = false;
      final end = _endsAt;
      if (end != null && !end.isAfter(picked)) _endsAt = null;
    });
  }

  Future<void> _pickEnd() async {
    final start = _startsAt;
    if (start == null) {
      UiHelpers.showSnack(context, 'Please choose the start date first.');
      return;
    }
    final picked =
        await _pickDateTime(_endsAt ?? start.add(const Duration(hours: 3)));
    if (picked == null || !mounted) return;
    if (!picked.isAfter(start)) {
      UiHelpers.showSnack(
        context,
        'The end time must be after the start time.',
        isError: true,
      );
      return;
    }
    setState(() => _endsAt = picked);
  }

  double? _parse(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  String? _validateTitle(String? value) {
    if ((value ?? '').trim().length < 3) {
      return 'Please enter the event title (min 3 characters).';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if ((value ?? '').trim().length < 10) {
      return 'Please enter a description (min 10 characters).';
    }
    return null;
  }

  String? _validateRequired(String? value, String message) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }

  String? _validateTicket(String? value) {
    final url = EventService.normalizeUrl(value);
    if (url == null) return null;
    if (!EventService.isValidUrl(url)) {
      return 'Please enter a valid link, e.g. https://tickets.pk';
    }
    return null;
  }

  String? _validateCoordinate(
    String? value, {
    required String otherText,
    required double limit,
    required String name,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      if (otherText.trim().isNotEmpty) return 'Enter $name too';
      return null;
    }
    final number = double.tryParse(text);
    if (number == null) return 'Enter a number';
    if (number < -limit || number > limit) {
      return 'Must be -${limit.toInt()} to ${limit.toInt()}';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _showStartError = _startsAt == null;
      _showFandomError = _fandom == null;
      _error = null;
    });
    final start = _startsAt;
    final fandom = _fandom;
    if (!formOk || start == null || fandom == null) return;
    if (_uploading) {
      UiHelpers.showSnack(
        context,
        'Please wait for the image to finish uploading.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = EventService.instance;
      final event = widget.event;
      if (event == null) {
        await service.addEvent(
          title: _titleController.text,
          description: _descriptionController.text,
          fandom: fandom,
          city: _cityController.text,
          venue: _venueController.text,
          startsAt: start,
          endsAt: _endsAt,
          address: _addressController.text,
          ticketUrl: _ticketController.text,
          imageUrl: _imageUrl,
          latitude: _parse(_latitudeController.text),
          longitude: _parse(_longitudeController.text),
        );
      } else {
        await service.updateEvent(
          id: event.id,
          title: _titleController.text,
          description: _descriptionController.text,
          fandom: fandom,
          city: _cityController.text,
          venue: _venueController.text,
          startsAt: start,
          endsAt: _endsAt,
          address: _addressController.text,
          ticketUrl: _ticketController.text,
          imageUrl: _imageUrl,
          latitude: _parse(_latitudeController.text),
          longitude: _parse(_longitudeController.text),
        );
      }
      if (!mounted) return;
      UiHelpers.showSnack(context, _isEdit ? 'Event updated.' : 'Event added.');
      Navigator.of(context).pop(true);
    } on EventException catch (error) {
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

    return AdminPageScaffold(
      header: AdminPageHeader(
        title: _isEdit ? 'Edit Event' : 'Add Event',
        subtitle: _isEdit
            ? 'Update the details, date or location of this event.'
            : 'Add a convention, meetup or screening for fans.',
        icon: _isEdit ? Icons.edit_calendar_rounded : Icons.event_rounded,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
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
                      title: 'Event banner',
                      icon: Icons.image_rounded,
                      subtitle: 'Optional cover image for the event card.',
                      children: [
                        _BannerPicker(
                          imageUrl: _imageUrl,
                          uploading: _uploading,
                          onUpload: _uploadImage,
                          onRemove: () => setState(() => _imageUrl = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Event details',
                      icon: Icons.event_note_rounded,
                      children: [
                        AppTextField(
                          controller: _titleController,
                          label: 'Event title',
                          hint: 'e.g. Karachi Comic Con 2026',
                          icon: Icons.event_rounded,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: _validateTitle,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hint: 'What will happen at this event?',
                          icon: Icons.notes_rounded,
                          maxLines: 4,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          validator: _validateDescription,
                        ),
                        const SizedBox(height: 12),
                        const _SubLabel('Fandom'),
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
                      title: 'Date & time',
                      icon: Icons.schedule_rounded,
                      children: [
                        _DateTile(
                          label: 'Starts',
                          placeholder: 'Choose start date & time',
                          icon: Icons.play_circle_outline_rounded,
                          value: _startsAt,
                          onTap: _pickStart,
                          errorText: _showStartError
                              ? 'Please choose the start date & time.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _DateTile(
                          label: 'Ends (optional)',
                          placeholder: 'Choose end date & time',
                          icon: Icons.stop_circle_outlined,
                          value: _endsAt,
                          onTap: _pickEnd,
                          onClear: _endsAt == null
                              ? null
                              : () => setState(() => _endsAt = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Location',
                      icon: Icons.place_rounded,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33F0357A),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _pickOnMap,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              icon: const Icon(Icons.add_location_alt_rounded),
                              label: const Text('Pick location on map'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g. Karachi',
                          icon: Icons.location_city_rounded,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _validateRequired(
                            value,
                            'Please enter the city.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _venueController,
                          label: 'Venue',
                          hint: 'e.g. Expo Centre',
                          icon: Icons.storefront_rounded,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: (value) => _validateRequired(
                            value,
                            'Please enter the venue.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _addressController,
                          label: 'Address (optional)',
                          hint: 'Street, area',
                          icon: Icons.place_outlined,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        const _SubLabel('Map coordinates'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _latitudeController,
                                label: 'Latitude',
                                hint: '24.8607',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) => _validateCoordinate(
                                  value,
                                  otherText: _longitudeController.text,
                                  limit: 90,
                                  name: 'latitude',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                controller: _longitudeController,
                                label: 'Longitude',
                                hint: '67.0011',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  signed: true,
                                  decimal: true,
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) => _validateCoordinate(
                                  value,
                                  otherText: _latitudeController.text,
                                  limit: 180,
                                  name: 'longitude',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const _TipBox(
                          text: 'Optional, but needed for the map and "Near '
                              'me". Tap "Pick location on map" to search the '
                              'venue or drop a pin. Empty City, Venue and '
                              'Address fields are filled in from the map, and '
                              'you can still edit them. You can also paste '
                              'coordinates from Google Maps (e.g. 24.8607, '
                              '67.0011) into Latitude.',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Tickets',
                      icon: Icons.confirmation_number_rounded,
                      children: [
                        AppTextField(
                          controller: _ticketController,
                          label: 'Ticket link (optional)',
                          hint: 'https://tickets.pk/your-event',
                          icon: Icons.confirmation_number_outlined,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          validator: _validateTicket,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: _isEdit ? 'Save changes' : 'Add event',
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

class _BannerPicker extends StatelessWidget {
  const _BannerPicker({
    required this.imageUrl,
    required this.uploading,
    required this.onUpload,
    required this.onRemove,
  });

  final String? imageUrl;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.softGradient),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    Image.network(
                      CloudinaryService.optimizedUrl(url, width: 900),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 40,
                          color: AppColors.purple,
                        ),
                      ),
                    )
                  else
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 44,
                          color: AppColors.purple,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add an event banner (optional)',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  if (uploading)
                    const ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploading ? null : onUpload,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  side: const BorderSide(color: AppColors.purple),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 44),
                ),
                icon: Icon(
                  hasImage ? Icons.refresh_rounded : Icons.upload_rounded,
                ),
                label: Text(hasImage ? 'Change image' : 'Upload image'),
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.onTap,
    this.value,
    this.onClear,
    this.errorText,
  });

  final String label;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final DateTime? value;
  final VoidCallback? onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final picked = value;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasError
                      ? colors.error
                      : (picked == null
                          ? const Color(0x33A23CF0)
                          : AppColors.purple.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.lavender,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          picked == null
                              ? placeholder
                              : '${FanEvent.formatDate(picked)} • '
                                  '${FanEvent.formatTime(picked)}',
                          style: picked == null
                              ? textTheme.bodyMedium
                                  ?.copyWith(color: colors.outline)
                              : textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: AppColors.pink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.text});

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
            Icons.info_outline_rounded,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
