import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fan_event.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/event_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/event_calendar.dart';
import '../../../widgets/state_views.dart';
import 'event_detail_screen.dart';
import 'events_map_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Stream<List<FanEvent>> _stream = EventService.instance.watchEvents();
  final _searchController = TextEditingController();

  bool _calendarMode = false;
  String _query = '';
  String? _cityKey;
  String? _cityLabel;
  bool _showPast = false;
  bool _nearMe = false;
  bool _locating = false;
  UserLocation? _me;
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = EventService.instance.watchEvents());
  }

  bool _matches(FanEvent event) {
    if (_cityKey != null && event.cityKey != _cityKey) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return event.title.toLowerCase().contains(query) ||
        event.fandom.toLowerCase().contains(query) ||
        event.venue.toLowerCase().contains(query) ||
        event.city.toLowerCase().contains(query);
  }

  double? _distanceTo(FanEvent event) {
    final me = _me;
    if (me == null || !event.hasLocation) return null;
    return LocationService.instance
        .distanceKm(me, event.latitude!, event.longitude!);
  }

  void _selectCity(String? key, String? label) {
    setState(() {
      _cityKey = key;
      _cityLabel = label;
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _cityKey = null;
      _cityLabel = null;
    });
  }

  void _openDetails(FanEvent event) {
    AppNavigator.push(
      context,
      EventDetailScreen(event: event, distanceKm: _distanceTo(event)),
    );
  }

  void _openMap() {
    AppNavigator.push(context, EventsMapScreen(city: _cityLabel));
  }

  Future<void> _toggleNearMe() async {
    if (_nearMe) {
      setState(() => _nearMe = false);
      return;
    }
    setState(() => _locating = true);
    try {
      final me = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _me = me;
        _nearMe = true;
      });
      UiHelpers.showSnack(context, 'Showing the closest events first.');
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

  List<MapEntry<String, String>> _cities(List<FanEvent> events) {
    final map = <String, String>{};
    for (final event in events) {
      if (_calendarMode || !event.isPast) {
        map.putIfAbsent(event.cityKey, () => event.city);
      }
    }
    if (_cityKey != null && _cityLabel != null) {
      map.putIfAbsent(_cityKey!, () => _cityLabel!);
    }
    final list = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list;
  }

  List<FanEvent> _upcoming(List<FanEvent> events) {
    final list = events.where((e) => !e.isPast && _matches(e)).toList();
    if (_nearMe && _me != null) {
      list.sort((a, b) {
        final da = _distanceTo(a);
        final db = _distanceTo(b);
        if (da == null && db == null) return a.startsAt.compareTo(b.startsAt);
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    } else {
      list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }
    return list;
  }

  List<FanEvent> _past(List<FanEvent> events) {
    return events.where((e) => e.isPast && _matches(e)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  Widget _stateBody(Widget child) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _EventsHero(onMap: _openMap),
        SizedBox(height: 320, child: child),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: StreamBuilder<List<FanEvent>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _stateBody(
                ErrorView(
                  message: 'Could not load events.\n${snapshot.error}',
                  onRetry: _retry,
                ),
              );
            }
            if (!snapshot.hasData) {
              return _stateBody(
                const LoadingView(message: 'Loading events...'),
              );
            }

            final all = snapshot.data!;
            if (all.isEmpty) {
              return _stateBody(
                const EmptyStateView(
                  icon: Icons.event_rounded,
                  title: 'No events yet',
                  message: 'Conventions, meetups and screenings will appear '
                      'here soon. Check back later!',
                ),
              );
            }

            final upcomingCount = all.where((e) => !e.isPast).length;
            final cityCount = {
              for (final e in all)
                if (!e.isPast) e.cityKey,
            }.length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _EventsHero(
                  onMap: _openMap,
                  upcomingCount: upcomingCount,
                  cityCount: cityCount,
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SearchBox(
                            controller: _searchController,
                            query: _query,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            onClear: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _ModeToggle(
                                  calendarMode: _calendarMode,
                                  onChanged: (value) =>
                                      setState(() => _calendarMode = value),
                                ),
                              ),
                              if (!_calendarMode) ...[
                                const SizedBox(width: 10),
                                _NearMeButton(
                                  active: _nearMe,
                                  loading: _locating,
                                  onTap: _toggleNearMe,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _PillChip(
                                  label: 'All cities',
                                  selected: _cityKey == null,
                                  onTap: () => _selectCity(null, null),
                                ),
                                for (final city in _cities(all)) ...[
                                  const SizedBox(width: 8),
                                  _PillChip(
                                    label: city.value,
                                    selected: _cityKey == city.key,
                                    onTap: () =>
                                        _selectCity(city.key, city.value),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_calendarMode)
                            ..._buildCalendar(all)
                          else
                            ..._buildList(all),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCalendar(List<FanEvent> all) {
    final filtered = all.where(_matches).toList();
    final onDay = filtered.where((e) => e.isOnDay(_selectedDay)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final textTheme = Theme.of(context).textTheme;

    return [
      EventCalendar(
        month: _month,
        events: filtered,
        selectedDay: _selectedDay,
        onDaySelected: (day) => setState(() {
          _selectedDay = day;
          _month = DateTime(day.year, day.month, 1);
        }),
        onMonthChanged: (month) => setState(() => _month = month),
      ),
      const SizedBox(height: 20),
      _SectionTitle(
        title: FanEvent.formatDate(_selectedDay),
        subtitle: '${onDay.length} '
            '${onDay.length == 1 ? 'event' : 'events'} on this day',
        textTheme: textTheme,
      ),
      const SizedBox(height: 12),
      if (onDay.isEmpty)
        const _SoftNote(
          icon: Icons.event_busy_rounded,
          text: 'No events on this day. Tap a date with a pink dot.',
        )
      else
        for (final event in onDay) ...[
          _FanEventCard(
            event: event,
            distanceKm: _distanceTo(event),
            onTap: () => _openDetails(event),
          ),
          const SizedBox(height: 14),
        ],
    ];
  }

  List<Widget> _buildList(List<FanEvent> all) {
    final upcoming = _upcoming(all);
    final past = _past(all);
    final textTheme = Theme.of(context).textTheme;
    final hasFilters = _query.trim().isNotEmpty || _cityKey != null;

    return [
      _SectionTitle(
        title:
            _cityLabel == null ? 'Upcoming events' : 'Upcoming in $_cityLabel',
        subtitle: '${upcoming.length} '
            '${upcoming.length == 1 ? 'event' : 'events'}'
            '${_nearMe ? ' • closest first' : ''}',
        textTheme: textTheme,
      ),
      const SizedBox(height: 12),
      if (upcoming.isEmpty)
        _SoftNote(
          icon: Icons.search_off_rounded,
          text: hasFilters
              ? 'No upcoming events match your filters.'
              : 'No upcoming events right now. Check back soon!',
          actionLabel: hasFilters ? 'Clear filters' : null,
          onAction: hasFilters ? _clearFilters : null,
        )
      else
        for (final event in upcoming) ...[
          _FanEventCard(
            event: event,
            distanceKm: _distanceTo(event),
            onTap: () => _openDetails(event),
          ),
          const SizedBox(height: 14),
        ],
      if (past.isNotEmpty) ...[
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _showPast = !_showPast),
            style: TextButton.styleFrom(foregroundColor: AppColors.purple),
            icon: Icon(
              _showPast ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            label: Text(
              _showPast
                  ? 'Hide past events'
                  : 'Show past events (${past.length})',
            ),
          ),
        ),
        if (_showPast)
          for (final event in past) ...[
            const SizedBox(height: 8),
            _FanEventCard(
              event: event,
              distanceKm: _distanceTo(event),
              onTap: () => _openDetails(event),
            ),
            const SizedBox(height: 6),
          ],
      ],
    ];
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A6C4DFF),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search events, fandoms or venues',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.purple),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: Color(0x33A23CF0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.calendarMode, required this.onChanged});

  final bool calendarMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegment(
              label: 'List',
              icon: Icons.view_agenda_rounded,
              selected: !calendarMode,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeSegment(
              label: 'Calendar',
              icon: Icons.calendar_month_rounded,
              selected: calendarMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.buttonGradient : null,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.purple,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearMeButton extends StatelessWidget {
  const _NearMeButton({
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final bool active;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: 'Near me',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: active ? AppColors.buttonGradient : null,
          color: active ? null : AppColors.softPink,
          shadows: active
              ? const [
                  BoxShadow(
                    color: Color(0x40F0357A),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onTap,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: active ? Colors.white : AppColors.pink,
                        ),
                      )
                    else
                      Icon(
                        active
                            ? Icons.check_rounded
                            : Icons.my_location_rounded,
                        size: 18,
                        color: active ? Colors.white : AppColors.pink,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      'Near me',
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.pink,
                        fontWeight: FontWeight.w700,
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

class _PillChip extends StatelessWidget {
  const _PillChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: ShapeDecoration(
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? Colors.transparent : colors.outlineVariant,
            ),
          ),
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : colors.surface,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    const Icon(
                      Icons.location_city_rounded,
                      size: 15,
                      color: AppColors.purple,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : colors.onSurface,
                      fontWeight: FontWeight.w700,
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

class _FanEventCard extends StatelessWidget {
  const _FanEventCard({
    required this.event,
    required this.onTap,
    this.distanceKm,
  });

  final FanEvent event;
  final double? distanceKm;
  final VoidCallback onTap;

  static String? _countdown(FanEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = event.startsAt;
    final day = DateTime(start.year, start.month, start.day);
    final days = day.difference(today).inDays;
    if (days < 0) return 'Happening now';
    if (days == 0) return start.isAfter(now) ? 'Today' : 'Happening now';
    if (days == 1) return 'Tomorrow';
    if (days <= 30) return 'In $days days';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final url = event.imageUrl;
    final distance = distanceKm;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (event.hasImage && url != null)
                      Image.network(
                        CloudinaryService.optimizedUrl(url, width: 800),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.softGradient,
                          ),
                        ),
                      )
                    else
                      const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.softGradient),
                        child: Center(
                          child: Icon(
                            Icons.celebration_rounded,
                            size: 48,
                            color: AppColors.purple,
                          ),
                        ),
                      ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x661F1147)],
                            stops: [0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: _DateBadge(date: event.startsAt),
                    ),
                    if (!event.isPast && _countdown(event) != null)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.buttonGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40F0357A),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _countdown(event)!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (event.isPast)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC1F1147),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Ended',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lavender,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event.fandom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.purple,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (distance != null)
                          Text(
                            LocationService.formatDistance(distance),
                            style: const TextStyle(
                              color: AppColors.pink,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        if (event.hasTicketLink && !event.isPast) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.confirmation_number_rounded,
                            size: 18,
                            color: AppColors.pink,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Line(icon: Icons.schedule_rounded, text: event.dateLabel),
                    const SizedBox(height: 2),
                    _Line(
                      icon: Icons.place_outlined,
                      text: event.venue.isEmpty
                          ? event.city
                          : '${event.venue}, ${event.city}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(
              color: AppColors.pink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          Text(
            FanEvent.monthShort[date.month - 1].toUpperCase(),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: AppColors.purple),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _SoftNote extends StatelessWidget {
  const _SoftNote({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.purple),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.pink),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.textTheme,
  });

  final String title;
  final String subtitle;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventsHero extends StatelessWidget {
  const _EventsHero({
    required this.onMap,
    this.upcomingCount,
    this.cityCount,
  });

  final VoidCallback onMap;
  final int? upcomingCount;
  final int? cityCount;

  static const String _art = 'assets/images/categories/cat_events.png';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final artSize = media.size.width < 360 ? 104.0 : 124.0;
    final canPop = Navigator.of(context).canPop();
    final upcoming = upcomingCount;
    final cities = cityCount;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            const Positioned(
              top: -40,
              right: -30,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            const Positioned(
              bottom: -50,
              left: -40,
              child: _Bubble(size: 150, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (canPop)
                          _GlassButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          )
                        else
                          const SizedBox(width: 8),
                        const Spacer(),
                        _GlassButton(
                          icon: Icons.map_rounded,
                          tooltip: 'Events map',
                          label: 'Map',
                          onTap: onMap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Events',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Conventions, meetups and screenings '
                                'near you',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              if (upcoming != null) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HeroStat(
                                      icon: Icons.event_available_rounded,
                                      label: '$upcoming upcoming',
                                    ),
                                    if ((cities ?? 0) > 0)
                                      _HeroStat(
                                        icon: Icons.location_city_rounded,
                                        label: '$cities '
                                            '${cities == 1 ? 'city' : 'cities'}',
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: artSize,
                          height: artSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                _art,
                                width: artSize,
                                height: artSize,
                                fit: BoxFit.contain,
                                semanticLabel: 'Events',
                                errorBuilder: (context, error, stack) =>
                                    CircleAvatar(
                                  radius: artSize / 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.event_rounded,
                                    color: Colors.white,
                                    size: artSize / 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: text == null ? 10 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  if (text != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.pink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
