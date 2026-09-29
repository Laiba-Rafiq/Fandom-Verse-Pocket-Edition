import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/app_notification.dart';
import '../../../services/notification_service.dart';
import 'notification_opener.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  StreamSubscription<NotificationFeed>? _sub;
  NotificationFeed? _feed;
  DateTime? _highlightSince;
  bool _captured = false;
  bool _failed = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _listen();
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    _sub?.cancel();
    _sub = NotificationService.instance.watchFeed(uid).listen(
      (feed) {
        if (!_captured) {
          _captured = true;
          _highlightSince = feed.seenAt;
          unawaited(NotificationService.instance.markAllSeen(uid));
        }
        if (mounted) {
          setState(() {
            _feed = feed;
            _failed = false;
          });
        }
      },
      onError: (Object _) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  void _retry() {
    setState(() {
      _failed = false;
      _feed = null;
    });
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    final uid = _uid;
    if (uid != null && _captured) {
      unawaited(NotificationService.instance.markAllSeen(uid));
    }
    super.dispose();
  }

  bool _isNew(AppNotification notification) =>
      notification.isUnread(_highlightSince);

  @override
  Widget build(BuildContext context) {
    final feed = _feed;
    final total = feed?.items.length;
    final newCount = feed?.items.where(_isNew).length ?? 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NotificationsHeader(total: total, newCount: newCount),
            Expanded(
              child: SafeArea(top: false, child: _buildBody(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_uid == null) {
      return const _MessageState(
        icon: Icons.lock_outline_rounded,
        title: 'Please log in',
        message: 'Log in to see your notifications.',
      );
    }
    if (_failed && _feed == null) {
      return _MessageState(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load notifications",
        message: 'Please check your internet connection and try again.',
        actionLabel: 'Try again',
        onAction: _retry,
      );
    }
    final feed = _feed;
    if (feed == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.pink),
      );
    }
    if (feed.items.isEmpty) {
      return const _MessageState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        message: 'New events, trending posts and updates about your orders '
            'and enquiries will show up here.',
      );
    }

    final fresh = feed.items.where(_isNew).toList();
    final earlier = feed.items.where((item) => !_isNew(item)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            _StatusStrip(newCount: fresh.length),
            const SizedBox(height: 18),
            if (fresh.isNotEmpty) ...[
              _SectionTitle(title: 'New', count: fresh.length),
              const SizedBox(height: 10),
              for (final notification in fresh) ...[
                _NotificationCard(
                  notification: notification,
                  isNew: true,
                  onTap: () => NotificationOpener.open(context, notification),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
            ],
            if (earlier.isNotEmpty) ...[
              _SectionTitle(title: 'Earlier', count: earlier.length),
              const SizedBox(height: 10),
              for (final notification in earlier) ...[
                _NotificationCard(
                  notification: notification,
                  isNew: false,
                  onTap: () => NotificationOpener.open(context, notification),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({required this.total, required this.newCount});

  final int? total;
  final int newCount;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final count = total;

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
            Positioned(
              top: -50,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
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
                                'Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Events, trending posts, orders and replies '
                                'in one place.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              if (count != null) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _HeaderChip(
                                      icon: Icons.fiber_new_rounded,
                                      label: '$newCount new',
                                      color: AppColors.pink,
                                    ),
                                    _HeaderChip(
                                      icon: Icons.inbox_rounded,
                                      label: '$count total',
                                      color: AppColors.purple,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                              width: 2,
                            ),
                          ),
                          child: Badge(
                            isLabelVisible: newCount > 0,
                            backgroundColor: AppColors.pink,
                            offset: const Offset(-14, 14),
                            label: Text(newCount > 9 ? '9+' : '$newCount'),
                            child: const Center(
                              child: Icon(
                                Icons.notifications_active_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
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
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

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
          Icon(icon, size: 15, color: color),
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

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.newCount});

  final int newCount;

  @override
  Widget build(BuildContext context) {
    final caughtUp = newCount == 0;
    final accent = caughtUp ? AppColors.success : AppColors.pink;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: caughtUp ? null : AppColors.buttonGradient,
              color: caughtUp ? AppColors.success : null,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              caughtUp
                  ? Icons.done_all_rounded
                  : Icons.notifications_active_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caughtUp
                      ? "You're all caught up"
                      : '$newCount new notification${newCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caughtUp
                      ? 'Nothing new since your last visit.'
                      : 'Tap a notification to open it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isNew,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(22);

    return Semantics(
      button: true,
      label: '${isNew ? 'New. ' : ''}${notification.title}. '
          '${notification.body}. ${notification.timeAgo}',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isNew
                ? AppColors.pink.withValues(alpha: 0.5)
                : const Color(0x26A23CF0),
            width: isNew ? 1.4 : 1,
          ),
        ),
        elevation: isNew ? 3 : 1,
        shadowColor: isNew
            ? AppColors.pink.withValues(alpha: 0.30)
            : const Color(0x336C4DFF),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: isNew ? AppColors.buttonGradient : null,
                    color: isNew ? null : AppColors.lavender,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    NotificationOpener.iconFor(notification.type),
                    color: isNew ? Colors.white : AppColors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title.isEmpty
                            ? 'Fandom Verse'
                            : notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: isNew ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            height: 1.35,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: colors.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                notification.timeAgo,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                          if (notification.personal)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softPink,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'For you',
                                style: TextStyle(
                                  color: AppColors.pink,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    if (isNew)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.pink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (notification.hasTarget)
                      Padding(
                        padding: EdgeInsets.only(top: isNew ? 16 : 14),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: colors.outline,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                gradient: AppColors.softGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.pink),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}