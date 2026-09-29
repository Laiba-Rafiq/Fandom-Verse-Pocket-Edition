import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/app_notification.dart';
import '../../../models/fan_event.dart';
import '../../../models/fandom_post.dart';
import '../content/post_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../store/wishlist_screen.dart';

class NotificationOpener {
  NotificationOpener._();

  static bool _busy = false;

  static IconData iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.event:
        return Icons.event_rounded;
      case NotificationType.post:
        return Icons.auto_awesome_rounded;
      case NotificationType.order:
        return Icons.local_shipping_rounded;
      case NotificationType.inquiry:
        return Icons.mark_email_read_rounded;
      case NotificationType.price:
        return Icons.trending_down_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  static Future<void> open(
    BuildContext context,
    AppNotification notification,
  ) async {
    if (_busy) return;
    _busy = true;
    try {
      switch (notification.type) {
        case NotificationType.event:
          await _openEvent(context, notification);
          break;
        case NotificationType.post:
          await _openPost(context, notification);
          break;
        case NotificationType.price:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WishlistScreen()),
          );
          break;
        case NotificationType.order:
        case NotificationType.inquiry:
        case NotificationType.general:
          await _showMessage(context, notification);
          break;
      }
    } finally {
      _busy = false;
    }
  }

  static Future<void> _openEvent(
    BuildContext context,
    AppNotification notification,
  ) async {
    final id = notification.targetId;
    if (id == null) {
      await _showMessage(context, notification);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 12));
      if (!context.mounted) return;
      if (!doc.exists) {
        UiHelpers.showSnack(
          context,
          'This event is no longer available.',
          isError: true,
        );
        return;
      }
      final event = FanEvent.fromDoc(doc);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventDetailScreen(event: event),
        ),
      );
    } catch (_) {
      if (context.mounted) _showOpenError(context);
    }
  }

  static Future<void> _openPost(
    BuildContext context,
    AppNotification notification,
  ) async {
    final id = notification.targetId;
    if (id == null) {
      await _showMessage(context, notification);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(id)
          .get()
          .timeout(const Duration(seconds: 12));
      if (!context.mounted) return;
      if (!doc.exists) {
        UiHelpers.showSnack(
          context,
          'This post is no longer available.',
          isError: true,
        );
        return;
      }
      final post = FandomPost.fromDoc(doc);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(post: post),
        ),
      );
    } catch (_) {
      if (context.mounted) _showOpenError(context);
    }
  }

  static void _showOpenError(BuildContext context) {
    UiHelpers.showSnack(
      context,
      "Couldn't open this right now. Please check your internet and try again.",
      isError: true,
    );
  }

  static Future<void> _showMessage(
    BuildContext context,
    AppNotification notification,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        iconFor(notification.type),
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        notification.title.isEmpty
                            ? 'Fandom Verse'
                            : notification.title,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    notification.body,
                    style: textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  notification.timeAgo,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
