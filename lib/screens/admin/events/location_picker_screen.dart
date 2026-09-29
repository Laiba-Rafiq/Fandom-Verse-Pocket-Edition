import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/app_button.dart';

class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.city,
    this.venue,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? city;
  final String? venue;
  final String? address;
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialQuery,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialQuery;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(30.3753, 69.3451);

  final MapController _mapController = MapController();
  late final TextEditingController _searchController;
  bool _mapReady = false;
  bool _searching = false;
  bool _locating = false;
  bool _lookingUp = false;
  int _lookupToken = 0;
  List<PlaceResult> _results = const [];
  String? _searchMessage;
  LatLng? _picked;
  PlaceResult? _place;
  String? _lookupMessage;

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialQuery?.trim() ?? '');
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null) _picked = LatLng(lat, lng);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point, double zoom) {
    if (_mapReady) _mapController.move(point, zoom);
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchMessage = null;
      _results = const [];
    });
    try {
      final results =
          await GeocodingService.instance.search(_searchController.text);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searchMessage = results.isEmpty
            ? 'No places found. Try adding the city, e.g. '
                '"Expo Centre Karachi".'
            : null;
      });
    } on GeocodingException catch (error) {
      if (mounted) setState(() => _searchMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _searchMessage = 'Search failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _choose(PlaceResult place) {
    final point = LatLng(place.latitude, place.longitude);
    _lookupToken++;
    setState(() {
      _picked = point;
      _place = place;
      _lookingUp = false;
      _lookupMessage = null;
      _results = const [];
      _searchMessage = null;
    });
    _moveTo(point, 16);
  }

  void _dropPin(LatLng point) {
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = point;
      _results = const [];
      _searchMessage = null;
    });
    _lookupAddress(point);
  }

  Future<void> _lookupAddress(LatLng point) async {
    final token = ++_lookupToken;
    setState(() {
      _lookingUp = true;
      _place = null;
      _lookupMessage = null;
    });
    String? message;
    PlaceResult? place;
    try {
      place = await GeocodingService.instance
          .reverse(point.latitude, point.longitude);
      if (place == null) {
        message = 'No address found here. You can type it yourself.';
      }
    } on GeocodingException catch (error) {
      message = error.message;
    } catch (_) {
      message = 'Could not find the address. You can type it yourself.';
    }
    if (!mounted || token != _lookupToken) return;
    setState(() {
      _lookingUp = false;
      _place = place;
      _lookupMessage = message;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final me = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      final point = LatLng(me.latitude, me.longitude);
      setState(() {
        _picked = point;
        _results = const [];
        _searchMessage = null;
      });
      _moveTo(point, 17);
      _lookupAddress(point);
    } on LocationException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not get your location. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double _round(double value) => double.parse(value.toStringAsFixed(6));

  void _confirm() {
    final point = _picked;
    if (point == null) return;
    final place = _place;
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _round(point.latitude),
        longitude: _round(point.longitude),
        city: place?.city,
        venue: place?.venue,
        address: place?.address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;

    return Scaffold(
      appBar: AppBar(title: const Text('Pick event location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: picked ?? _defaultCenter,
                    initialZoom: picked == null ? 5 : 16,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: () => _mapReady = true,
                    onTap: (tapPosition, point) => _dropPin(point),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.techwiz.fandom_verse',
                    ),
                    if (picked != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: picked,
                            width: 50,
                            height: 50,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              size: 50,
                              color: AppColors.pink,
                              shadows: [
                                Shadow(color: Color(0x55000000), blurRadius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchBar(
                        controller: _searchController,
                        searching: _searching,
                        onSearch: _search,
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ResultsList(results: _results, onChoose: _choose),
                      ] else if (_searchMessage != null) ...[
                        const SizedBox(height: 8),
                        _FloatingNote(
                          icon: Icons.info_outline_rounded,
                          text: _searchMessage!,
                        ),
                      ] else if (picked == null) ...[
                        const SizedBox(height: 8),
                        const _FloatingNote(
                          icon: Icons.touch_app_rounded,
                          text: 'Search for the venue, or tap on the map '
                              'to drop a pin.',
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: FloatingActionButton.small(
                    heroTag: 'picker_my_location',
                    tooltip: 'Use my current location',
                    onPressed: _locating ? null : _useMyLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.pink,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.pink,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
                const Positioned(
                  left: 8,
                  bottom: 4,
                  child: _Attribution(),
                ),
              ],
            ),
          ),
          _BottomPanel(
            picked: picked,
            place: _place,
            lookingUp: _lookingUp,
            lookupMessage: _lookupMessage,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searching,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool searching;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: const Color(0x406C4DFF),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                hintText: 'Search venue, e.g. Expo Centre Karachi',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : FilledButton(
                    onPressed: onSearch,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pink,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Search'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.onChoose});

  final List<PlaceResult> results;
  final ValueChanged<PlaceResult> onChoose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: const Color(0x406C4DFF),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: results.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: colors.outlineVariant),
          itemBuilder: (context, index) {
            final place = results[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.softPink,
                child: Icon(Icons.place_rounded, color: AppColors.pink),
              ),
              title: Text(
                place.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: place.subtitle.isEmpty
                  ? null
                  : Text(
                      place.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onChoose(place),
            );
          },
        ),
      ),
    );
  }
}

class _FloatingNote extends StatelessWidget {
  const _FloatingNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 10, color: Color(0xFF333333)),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.picked,
    required this.place,
    required this.lookingUp,
    required this.lookupMessage,
    required this.onConfirm,
  });

  final LatLng? picked;
  final PlaceResult? place;
  final bool lookingUp;
  final String? lookupMessage;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final point = picked;
    final found = place;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x226C4DFF),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.softPink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.push_pin_rounded,
                      color: AppColors.pink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point == null
                              ? 'No location selected yet'
                              : (found?.venue ?? 'Selected location'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        if (point == null)
                          Text(
                            'Tap the map or pick a search result.',
                            style: textTheme.bodySmall,
                          )
                        else ...[
                          if (lookingUp)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.pink,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Finding the address…',
                                  style: textTheme.bodySmall,
                                ),
                              ],
                            )
                          else if (found != null &&
                              (found.address != null || found.city != null))
                            Text(
                              [
                                if (found.address != null) found.address!,
                                if (found.city != null) found.city!,
                              ].join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else if (lookupMessage != null)
                            Text(
                              lookupMessage!,
                              style: textTheme.bodySmall,
                            ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat ${point.latitude.toStringAsFixed(6)}, '
                            'Lng ${point.longitude.toStringAsFixed(6)}',
                            style: textTheme.bodySmall
                                ?.copyWith(color: colors.outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Use this location',
                icon: Icons.check_rounded,
                onPressed: point == null || lookingUp ? null : onConfirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
