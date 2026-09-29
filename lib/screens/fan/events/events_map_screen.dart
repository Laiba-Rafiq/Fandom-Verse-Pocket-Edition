import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fan_event.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/event_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/state_views.dart';
import 'event_detail_screen.dart';

class EventsMapScreen extends StatefulWidget {
  const EventsMapScreen({super.key, this.city});

  final String? city;

  @override
  State<EventsMapScreen> createState() => _EventsMapScreenState();
}

class _EventsMapScreenState extends State<EventsMapScreen> {
  static const LatLng _defaultCenter = LatLng(30.3753, 69.3451);

  late Stream<List<FanEvent>> _stream = EventService.instance.watchEvents();
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _locating = false;
  UserLocation? _me;
  FanEvent? _selected;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = EventService.instance.watchEvents());
  }

  List<FanEvent> _visible(List<FanEvent> events) {
    final cityKey = widget.city?.trim().toLowerCase();
    return events.where((event) {
      if (event.isPast) return false;
      if (cityKey != null && cityKey.isNotEmpty && event.cityKey != cityKey) {
        return false;
      }
      return true;
    }).toList();
  }

  LatLng _pointOf(FanEvent event) => LatLng(event.latitude!, event.longitude!);

  double? _distanceTo(FanEvent event) {
    final me = _me;
    if (me == null || !event.hasLocation) return null;
    return LocationService.instance
        .distanceKm(me, event.latitude!, event.longitude!);
  }

  void _fitAll(List<FanEvent> mapped) {
    if (!_mapReady) return;
    final points = <LatLng>[
      for (final event in mapped) _pointOf(event),
      if (_me != null) LatLng(_me!.latitude, _me!.longitude),
    ];
    if (points.isEmpty) {
      _mapController.move(_defaultCenter, 5);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(60, 100, 60, 220),
        maxZoom: 15,
      ),
    );
  }

  Future<void> _nearMe(List<FanEvent> mapped) async {
    setState(() => _locating = true);
    try {
      final me = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;

      FanEvent? nearest;
      double? best;
      for (final event in mapped) {
        final km = LocationService.instance
            .distanceKm(me, event.latitude!, event.longitude!);
        if (best == null || km < best) {
          best = km;
          nearest = event;
        }
      }

      setState(() {
        _me = me;
        if (nearest != null) _selected = nearest;
      });

      if (_mapReady) {
        final points = <LatLng>[
          LatLng(me.latitude, me.longitude),
          if (nearest != null) _pointOf(nearest),
        ];
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(60, 100, 60, 240),
            maxZoom: 14,
          ),
        );
      }

      if (nearest != null && best != null) {
        UiHelpers.showSnack(
          context,
          'Nearest event: ${nearest.title} '
          '(${LocationService.formatDistance(best)})',
        );
      } else {
        UiHelpers.showSnack(
          context,
          'Showing your location. No upcoming events on the map yet.',
        );
      }
    } on LocationException catch (error) {
      if (mounted) _showLocationProblem(error);
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

  void _showLocationProblem(LocationException error) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_off_rounded, color: AppColors.pink),
        title: const Text('Location needed'),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          if (error.canOpenSettings)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                LocationService.instance.openSettingsFor(error.issue);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.pink),
              child: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  void _openDetails(FanEvent event) {
    AppNavigator.push(
      context,
      EventDetailScreen(event: event, distanceKm: _distanceTo(event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.city;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          city == null || city.isEmpty ? 'Events map' : 'Events in $city',
        ),
      ),
      body: StreamBuilder<List<FanEvent>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: 'Could not load events.\n${snapshot.error}',
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const LoadingView(message: 'Loading map...');
          }

          final visible = _visible(snapshot.data!);
          final mapped = visible.where((event) => event.hasLocation).toList();
          final missing = visible.length - mapped.length;
          final selected = _selected;
          final selectedStillVisible =
              selected != null && mapped.any((e) => e.id == selected.id);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 5,
                  initialCameraFit: mapped.isEmpty
                      ? null
                      : CameraFit.coordinates(
                          coordinates: [
                            for (final event in mapped) _pointOf(event),
                          ],
                          padding: const EdgeInsets.fromLTRB(60, 100, 60, 220),
                          maxZoom: 15,
                        ),
                  minZoom: 3,
                  maxZoom: 18,
                  onMapReady: () => _mapReady = true,
                  onTap: (tapPosition, point) =>
                      setState(() => _selected = null),
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
                  MarkerLayer(
                    markers: [
                      if (_me != null)
                        Marker(
                          point: LatLng(_me!.latitude, _me!.longitude),
                          width: 26,
                          height: 26,
                          child: const _MyLocationDot(),
                        ),
                      for (final event in mapped)
                        Marker(
                          point: _pointOf(event),
                          width: 48,
                          height: 48,
                          alignment: Alignment.topCenter,
                          child: _EventPin(
                            selected:
                                selectedStillVisible && selected.id == event.id,
                            onTap: () => setState(() => _selected = event),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 12,
                top: 12,
                right: 12,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MapChip(
                      icon: Icons.event_rounded,
                      text: '${mapped.length} on map',
                    ),
                    if (missing > 0)
                      _MapChip(
                        icon: Icons.location_off_outlined,
                        text: '$missing without location',
                      ),
                  ],
                ),
              ),
              const Positioned(
                left: 8,
                bottom: 4,
                child: _Attribution(),
              ),
              Positioned(
                right: 16,
                bottom: selectedStillVisible ? 190 : 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fit_all_events',
                      tooltip: 'Show all events',
                      onPressed: () => _fitAll(mapped),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.purple,
                      child: const Icon(Icons.fit_screen_rounded),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'near_me_events',
                      onPressed: _locating ? null : () => _nearMe(mapped),
                      backgroundColor: AppColors.pink,
                      foregroundColor: Colors.white,
                      icon: _locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location_rounded),
                      label: Text(_locating ? 'Locating...' : 'Near me'),
                    ),
                  ],
                ),
              ),
              if (selectedStillVisible)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: _SelectedEventCard(
                    event: selected,
                    distanceKm: _distanceTo(selected),
                    onOpen: () => _openDetails(selected),
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventPin extends StatelessWidget {
  const _EventPin({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Event location',
      child: GestureDetector(
        onTap: onTap,
        child: Icon(
          Icons.location_on_rounded,
          size: selected ? 48 : 40,
          color: selected ? AppColors.purple : AppColors.pink,
          shadows: const [
            Shadow(color: Color(0x55000000), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F80ED),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(color: Color(0x552F80ED), blurRadius: 10, spreadRadius: 4),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.pink),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
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

class _SelectedEventCard extends StatelessWidget {
  const _SelectedEventCard({
    required this.event,
    required this.onOpen,
    required this.onClose,
    this.distanceKm,
  });

  final FanEvent event;
  final double? distanceKm;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final url = event.imageUrl;
    final distance = distanceKm;

    return Material(
      color: colors.surface,
      elevation: 6,
      shadowColor: const Color(0x406C4DFF),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: event.hasImage && url != null
                      ? Image.network(
                          CloudinaryService.optimizedUrl(url, width: 240),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _dateBox(),
                        )
                      : _dateBox(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    Text(
                      '${event.venue}, ${event.city}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (distance != null)
                          Text(
                            LocationService.formatDistance(distance),
                            style: const TextStyle(
                              color: AppColors.pink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        const Spacer(),
                        const Text(
                          'Details',
                          style: TextStyle(
                            color: AppColors.purple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.purple,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateBox() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.buttonGradient),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${event.startsAt.day}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            FanEvent.monthShort[event.startsAt.month - 1].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
