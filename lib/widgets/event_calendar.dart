import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/fan_event.dart';

class EventCalendar extends StatelessWidget {
  const EventCalendar({
    super.key,
    required this.month,
    required this.events,
    required this.onDaySelected,
    required this.onMonthChanged,
    this.selectedDay,
  });

  final DateTime month;
  final List<FanEvent> events;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  static const List<String> _weekdayLetters = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  int _countOn(DateTime day) {
    return events.where((event) => event.isOnDay(day)).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    final rows = <Widget>[];
    for (var start = 0; start < totalCells; start += 7) {
      rows.add(
        Row(
          children: [
            for (var index = start; index < start + 7; index++)
              Expanded(
                child: _buildCell(
                  context,
                  index - leading + 1,
                  daysInMonth,
                  now,
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
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
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month - 1, 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${FanEvent.monthFull[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (!isCurrentMonth)
                TextButton(
                  onPressed: () {
                    onMonthChanged(DateTime(now.year, now.month, 1));
                    onDaySelected(DateTime(now.year, now.month, now.day));
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.pink,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Today'),
                ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () =>
                    onMonthChanged(DateTime(month.year, month.month + 1, 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final letter in _weekdayLetters)
                Expanded(
                  child: Text(
                    letter,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    int dayNumber,
    int daysInMonth,
    DateTime now,
  ) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }

    final colors = Theme.of(context).colorScheme;
    final day = DateTime(month.year, month.month, dayNumber);
    final count = _countOn(day);
    final selected =
        selectedDay != null && FanEvent.isSameDay(selectedDay!, day);
    final isToday = FanEvent.isSameDay(now, day);

    final Color textColor;
    if (selected) {
      textColor = Colors.white;
    } else if (count > 0) {
      textColor = AppColors.pink;
    } else {
      textColor = colors.onSurface;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: count == 0
          ? '$dayNumber'
          : '$dayNumber, $count ${count == 1 ? 'event' : 'events'}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onDaySelected(day),
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? AppColors.buttonGradient : null,
                  border: isToday && !selected
                      ? Border.all(color: AppColors.purple, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$dayNumber',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: count > 0 || selected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: count > 0 ? AppColors.pink : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
