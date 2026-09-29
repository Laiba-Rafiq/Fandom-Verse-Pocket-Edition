import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/app_user.dart';
import '../../services/event_reminder_service.dart';
import '../../services/push_service.dart';
import '../../widgets/floating_ai_button.dart';
import 'content/explore_screen.dart';
import 'events/events_screen.dart';
import 'fan_home_screen.dart';
import 'notifications/notification_opener.dart';
import 'profile/profile_screen.dart';
import 'store/merch_store_screen.dart';

class FanShell extends StatefulWidget {
  const FanShell({super.key, required this.user});

  final AppUser user;

  @override
  State<FanShell> createState() => _FanShellState();
}

class _FanShellState extends State<FanShell> {
  int _index = FanTabs.home;

  @override
  void initState() {
    super.initState();
    FanAssistant.show(widget.user.name);
    _startReminders();
    PushService.instance.pendingOpen.addListener(_handlePendingOpen);
    FanTabs.requested.addListener(_handleTabRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingOpen());
  }

  @override
  void didUpdateWidget(covariant FanShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name) {
      FanAssistant.show(widget.user.name);
    }
    EventReminderService.instance.updateFandoms(widget.user.selectedFandoms);
  }

  @override
  void dispose() {
    PushService.instance.pendingOpen.removeListener(_handlePendingOpen);
    FanTabs.requested.removeListener(_handleTabRequest);
    unawaited(EventReminderService.instance.stop());
    FanAssistant.hide();
    super.dispose();
  }

  void _startReminders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    EventReminderService.instance.start(
      uid: uid,
      fandoms: widget.user.selectedFandoms,
    );
  }

  void _handlePendingOpen() {
    if (!mounted) return;
    if (PushService.instance.pendingOpen.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notification = PushService.instance.takePending();
      if (notification == null) return;
      NotificationOpener.open(context, notification);
    });
  }

  void _handleTabRequest() {
    final tab = FanTabs.requested.value;
    if (tab == null || !mounted) return;
    _selectTab(tab);
  }

  void _selectTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      FanHomeScreen(user: widget.user, onSelectTab: _selectTab),
      const ExploreScreen(),
      const EventsScreen(),
      const MerchStoreScreen(),
      ProfileScreen(user: widget.user),
    ];

    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _FanNavBar(
        selectedIndex: _index,
        onSelected: _selectTab,
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _FanNavBar extends StatelessWidget {
  const _FanNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const List<_NavItem> _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    _NavItem(Icons.event_outlined, Icons.event_rounded, 'Events'),
    _NavItem(Icons.storefront_outlined, Icons.storefront_rounded, 'Store'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(
          top: BorderSide(color: Color(0x26A23CF0)),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x266C4DFF),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 10, 8, bottomInset + 10),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: _NavButton(
                item: _items[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: selected ? 54 : 44,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.buttonGradient : null,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x40F0357A),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 22,
                    color: selected ? Colors.white : colors.outline,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.pink : colors.outline,
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
