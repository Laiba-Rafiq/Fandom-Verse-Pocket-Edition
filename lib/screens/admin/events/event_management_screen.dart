import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fan_event.dart';
import '../../../routes/app_navigator.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/event_service.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';
import 'event_form_screen.dart';

enum _EventFilter { upcoming, past, all }

extension on _EventFilter {
  String get label {
    switch (this) {
      case _EventFilter.upcoming:
        return 'Upcoming';
      case _EventFilter.past:
        return 'Past';
      case _EventFilter.all:
        return 'All';
    }
  }
}

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  late Stream<List<FanEvent>> _stream = EventService.instance.watchEvents();
  final _searchController = TextEditingController();
  String _query = '';
  _EventFilter _filter = _EventFilter.upcoming;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = EventService.instance.watchEvents());
  }

  void _openForm([FanEvent? event]) {
    AppNavigator.push(context, EventFormScreen(event: event));
  }

  Future<void> _delete(FanEvent event) async {
    final confirmed = await UiHelpers.confirm(
      context,
      title: 'Delete event?',
      message: '"${event.title}" will be removed for all fans. '
          'This cannot be undone.',
      confirmText: 'Delete',
    );
    if (!confirmed) return;
    try {
      await EventService.instance.deleteEvent(event.id);
      if (mounted) UiHelpers.showSnack(context, 'Event deleted.');
    } on EventException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not delete the event. Please try again.',
          isError: true,
        );
      }
    }
  }

  List<FanEvent> _apply(List<FanEvent> events) {
    final query = _query.trim().toLowerCase();
    Iterable<FanEvent> result = events;
    switch (_filter) {
      case _EventFilter.upcoming:
        result = result.where((event) => !event.isPast);
        break;
      case _EventFilter.past:
        result = result.where((event) => event.isPast);
        break;
      case _EventFilter.all:
        break;
    }
    if (query.isNotEmpty) {
      result = result.where((event) {
        return event.title.toLowerCase().contains(query) ||
            event.city.toLowerCase().contains(query) ||
            event.venue.toLowerCase().contains(query) ||
            event.fandom.toLowerCase().contains(query);
      });
    }
    final list = result.toList();
    if (_filter == _EventFilter.past) {
      list.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    } else {
      list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    }
    return list;
  }

  Widget _header({int? upcoming, int? total}) {
    return AdminPageHeader(
      title: 'Events',
      subtitle: 'Manage conventions, meetups and screenings for fans.',
      icon: Icons.event_rounded,
      chips: [
        if (upcoming != null && total != null) ...[
          AdminHeaderChip(
            icon: Icons.upcoming_rounded,
            label: '$upcoming upcoming',
            color: AppColors.primary,
          ),
          AdminHeaderChip(
            icon: Icons.event_note_rounded,
            label: '$total total',
            color: AppColors.pink,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FanEvent>>(
      stream: _stream,
      builder: (context, snapshot) {
        final fab = AdminGradientFab(
          label: 'Add event',
          icon: Icons.add_rounded,
          onPressed: () => _openForm(),
        );

        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: ErrorView(
              message: 'Could not load events.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            floatingActionButton: fab,
            body: const LoadingView(message: 'Loading events...'),
          );
        }

        final all = snapshot.data!;
        if (all.isEmpty) {
          return AdminPageScaffold(
            header: _header(upcoming: 0, total: 0),
            floatingActionButton: fab,
            body: EmptyStateView(
              icon: Icons.event_available_rounded,
              title: 'No events yet',
              message: 'Add conventions, meetups and screenings so fans '
                  'can find them by city and date.',
              actionLabel: 'Add first event',
              onAction: () => _openForm(),
            ),
          );
        }

        final upcoming = all.where((event) => !event.isPast).length;
        final cities = all.map((event) => event.cityKey).toSet().length;
        final visible = _apply(all);

        return AdminPageScaffold(
          header: _header(upcoming: upcoming, total: all.length),
          floatingActionButton: fab,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AdminStatBox(
                          label: 'Upcoming',
                          value: '$upcoming',
                          icon: Icons.upcoming_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Past',
                          value: '${all.length - upcoming}',
                          icon: Icons.history_rounded,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Cities',
                          value: '$cities',
                          icon: Icons.location_city_rounded,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminSearchField(
                    controller: _searchController,
                    hint: 'Search by title, city, venue or fandom',
                    query: _query,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in _EventFilter.values)
                        AdminFilterPill(
                          label: filter.label,
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: '${_filter.label} events',
                    trailing: _CountBadge(
                      text: '${visible.length} '
                          '${visible.length == 1 ? 'event' : 'events'}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    AdminEmptyNote(
                      icon: _query.isEmpty
                          ? Icons.event_busy_rounded
                          : Icons.search_off_rounded,
                      text: _query.isEmpty
                          ? 'No ${_filter.label.toLowerCase()} events.'
                          : 'No events match "$_query".',
                    )
                  else
                    for (final event in visible) ...[
                      _AdminEventCard(
                        event: event,
                        onEdit: () => _openForm(event),
                        onDelete: () => _delete(event),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminEventCard extends StatelessWidget {
  const _AdminEventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final FanEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: event.isPast ? 0.85 : 1,
      child: Container(
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EventThumb(event: event),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _InfoLine(
                              icon: Icons.schedule_rounded,
                              text: event.dateLabel,
                            ),
                            const SizedBox(height: 2),
                            _InfoLine(
                              icon: Icons.place_outlined,
                              text: '${event.city} • ${event.venue}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _Tag(
                                  text: event.fandom,
                                  background: AppColors.lavender,
                                  foreground: AppColors.purple,
                                ),
                                if (event.isPast)
                                  const _Tag(
                                    text: 'Past',
                                    background: Color(0x22F5A524),
                                    foreground: Color(0xFFB7791F),
                                  ),
                                if (event.hasLocation)
                                  const _Tag(
                                    text: 'Map',
                                    icon: Icons.map_outlined,
                                    background: Color(0x2200B8D9),
                                    foreground: Color(0xFF0086A0),
                                  ),
                                if (event.hasTicketLink)
                                  const _Tag(
                                    text: 'Tickets',
                                    icon: Icons.confirmation_number_outlined,
                                    background: Color(0x221FA971),
                                    foreground: AppColors.success,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: colors.outlineVariant),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _CardAction(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          tooltip: 'Edit event',
                          color: AppColors.primary,
                          onTap: onEdit,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CardAction(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          tooltip: 'Delete event',
                          color: AppColors.error,
                          onTap: onDelete,
                        ),
                      ),
                    ],
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

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventThumb extends StatelessWidget {
  const _EventThumb({required this.event});

  final FanEvent event;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 84,
        height: 84,
        child: event.hasImage && url != null
            ? Image.network(
                CloudinaryService.optimizedUrl(url, width: 240),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => _dateBadge(),
              )
            : _dateBadge(),
      ),
    );
  }

  Widget _dateBadge() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${event.startsAt.day}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            FanEvent.monthShort[event.startsAt.month - 1].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: colors.outline),
        ),
        const SizedBox(width: 4),
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

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
