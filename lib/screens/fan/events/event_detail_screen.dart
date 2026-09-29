import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/fan_event.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/event_reminder_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/app_button.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event, this.distanceKm});

  final FanEvent event;
  final double? distanceKm;

  String get _status {
    if (event.isPast) return 'Ended';
    if (event.isOnDay(DateTime.now())) return 'Happening today';
    return 'Upcoming';
  }

  Color get _statusColor {
    if (event.isPast) return AppColors.warning;
    if (event.isOnDay(DateTime.now())) return AppColors.pink;
    return AppColors.success;
  }

  void _openMap(BuildContext context) {
    LinkLauncher.openMap(
      context,
      latitude: event.latitude,
      longitude: event.longitude,
      place: event.locationLabel,
    );
  }

  void _openDirections(BuildContext context) {
    LinkLauncher.openDirections(
      context,
      latitude: event.latitude,
      longitude: event.longitude,
      place: event.locationLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final distance = distanceKm;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 240,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.purple,
            flexibleSpace: FlexibleSpaceBar(
              background: _Banner(event: event),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(
                            text: event.fandom,
                            background: AppColors.lavender,
                            foreground: AppColors.purple,
                          ),
                          _Pill(
                            text: _status,
                            background: _statusColor.withValues(alpha: 0.14),
                            foreground: _statusColor,
                          ),
                          if (distance != null)
                            _Pill(
                              text: LocationService.formatDistance(distance),
                              icon: Icons.near_me_rounded,
                              background: AppColors.softPink,
                              foreground: AppColors.pink,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        event.title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _InfoCard(
                        icon: Icons.calendar_month_rounded,
                        title: 'Date & time',
                        value: event.dateLabel,
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        icon: Icons.place_rounded,
                        title: event.venue.isEmpty ? event.city : event.venue,
                        value: [
                          if (event.address != null) event.address!,
                          event.city,
                        ].join(', '),
                        actionLabel: 'Open map',
                        onAction: () => _openMap(context),
                      ),
                      if (!event.isPast) ...[
                        const SizedBox(height: 12),
                        _ReminderCard(event: event),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'About this event',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.description.isEmpty
                            ? 'More details will be shared soon.'
                            : event.description,
                        style: textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                      if (event.hasLocation) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Location',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        _MapPreview(
                          latitude: event.latitude!,
                          longitude: event.longitude!,
                          onTap: () => _openMap(context),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (event.isPast)
                        const _NoteBox(
                          icon: Icons.history_rounded,
                          text: 'This event has ended. Keep an eye on the '
                              'Events tab for the next one!',
                        )
                      else if (event.hasTicketLink)
                        AppButton(
                          label: 'Buy tickets',
                          icon: Icons.confirmation_number_rounded,
                          onPressed: () => LinkLauncher.openWebsite(
                            context,
                            event.ticketUrl!,
                          ),
                        )
                      else
                        const _NoteBox(
                          icon: Icons.info_outline_rounded,
                          text: 'No online tickets for this event. Entry '
                              'details are available at the venue.',
                        ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Get directions',
                        icon: Icons.directions_rounded,
                        outlined: true,
                        onPressed: () => _openDirections(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatefulWidget {
  const _ReminderCard({required this.event});

  final FanEvent event;

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  late final Stream<bool> _reminded =
      EventReminderService.instance.watchIsReminded(widget.event.id);
  bool _saving = false;

  Future<void> _toggle(bool isReminded) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final nowOn = await EventReminderService.instance.toggle(
        widget.event.id,
        isReminded: isReminded,
      );
      if (mounted) {
        UiHelpers.showSnack(
          context,
          nowOn
              ? "Reminder set! We'll remind you 2 days, 1 day and 2 hours "
                  'before.'
              : 'Reminder removed.',
        );
      }
    } on ReminderException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update the reminder. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final automatic = EventReminderService.instance.isInterested(widget.event);

    return StreamBuilder<bool>(
      stream: _reminded,
      builder: (context, snapshot) {
        final chosen = snapshot.data ?? false;
        final on = automatic || chosen;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on
                  ? AppColors.pink.withValues(alpha: 0.45)
                  : colors.outlineVariant,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x146C4DFF),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: on ? AppColors.buttonGradient : null,
                  color: on ? null : AppColors.softPink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  on
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: on ? Colors.white : AppColors.pink,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      automatic
                          ? 'Reminders are on'
                          : (chosen ? 'Reminder is on' : 'Remind me'),
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      automatic
                          ? "This event is in your fandoms, so we'll remind "
                              'you automatically.'
                          : '2 days, 1 day and 2 hours before it starts.',
                      style: textTheme.bodySmall?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              if (!automatic)
                Semantics(
                  label: 'Remind me about this event',
                  toggled: chosen,
                  child: Switch(
                    value: chosen,
                    activeThumbColor: AppColors.pink,
                    onChanged: _saving ? null : (_) => _toggle(chosen),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.event});

  final FanEvent event;

  @override
  Widget build(BuildContext context) {
    final url = event.imageUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (event.hasImage && url != null)
          Image.network(
            CloudinaryService.optimizedUrl(url, width: 1200),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholder(),
          )
        else
          _placeholder(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0x55000000)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.buttonGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${event.startsAt.day}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${FanEvent.monthFull[event.startsAt.month - 1]} '
              '${event.startsAt.year}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softPink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.pink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(value, style: textTheme.bodyMedium),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: AppColors.pink),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  final double latitude;
  final double longitude;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.techwiz.fandom_verse',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.pink,
                        size: 44,
                      ),
                    ),
                  ],
                ),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                ),
              ],
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 6),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 14, color: AppColors.pink),
                    SizedBox(width: 4),
                    Text(
                      'Open in Maps',
                      style: TextStyle(
                        color: AppColors.pink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.purple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
