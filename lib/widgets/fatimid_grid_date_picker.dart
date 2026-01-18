import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:modern_flutter_app/logic/fatimid_calendar.dart';

class FatimidGridDatePicker extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;

  const FatimidGridDatePicker({
    super.key,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
  });

  @override
  State<FatimidGridDatePicker> createState() => _FatimidGridDatePickerState();
}

class _FatimidGridDatePickerState extends State<FatimidGridDatePicker> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
  }

  @override
  void didUpdateWidget(covariant FatimidGridDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    if (newMonth.year != _displayedMonth.year || newMonth.month != _displayedMonth.month) {
      _displayedMonth = newMonth;
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _addMonths(DateTime monthStart, int offset) {
    return DateTime(monthStart.year, monthStart.month + offset, 1);
  }

  bool _monthStartBeforeOrEqual(DateTime a, DateTime b) {
    if (a.year != b.year) return a.year < b.year;
    return a.month <= b.month;
  }

  bool _monthStartAfterOrEqual(DateTime a, DateTime b) {
    if (a.year != b.year) return a.year > b.year;
    return a.month >= b.month;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthTitle = intl.DateFormat('MMMM yyyy', 'ar').format(_displayedMonth);

    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month, 1);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month, 1);

    final prevMonth = _addMonths(_displayedMonth, -1);
    final nextMonth = _addMonths(_displayedMonth, 1);

    final canGoPrev = _monthStartAfterOrEqual(_displayedMonth, firstMonth) &&
        !_isSameDate(_displayedMonth, firstMonth) &&
        _monthStartAfterOrEqual(prevMonth, firstMonth);
    final canGoNext = _monthStartBeforeOrEqual(_displayedMonth, lastMonth) &&
        !_isSameDate(_displayedMonth, lastMonth) &&
        _monthStartBeforeOrEqual(nextMonth, lastMonth);

    final firstDay = _displayedMonth;
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;

    final startOffset = (firstDay.weekday + 1) % 7;
    final totalCells = startOffset + daysInMonth;

    const weekdays = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: canGoNext
                    ? () {
                        setState(() {
                          _displayedMonth = nextMonth;
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Text(
                  monthTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: canGoPrev
                    ? () {
                        setState(() {
                          _displayedMonth = prevMonth;
                        });
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final w in weekdays)
                Expanded(
                  child: Text(
                    w,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < startOffset) {
                  return const SizedBox.shrink();
                }

                final dayNum = index - startOffset + 1;
                final gregDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);

                final isDisabled = gregDate.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) ||
                    gregDate.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

                final isSelected = _isSameDate(gregDate, widget.selectedDate);
                final isToday = _isSameDate(gregDate, DateTime.now());

                int hijriDay;
                try {
                  hijriDay = FatimidCalendar.fromGregorian(gregDate).hDay;
                } catch (_) {
                  hijriDay = dayNum;
                }

                final bg = isSelected
                    ? colorScheme.primary.withOpacity(0.18)
                    : Colors.transparent;

                final border = isSelected
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : (isToday ? Border.all(color: colorScheme.secondary, width: 1.5) : null);

                final textColor = isDisabled
                    ? colorScheme.onSurface.withOpacity(0.35)
                    : (isSelected ? colorScheme.primary : colorScheme.onSurface);

                return InkWell(
                  onTap: isDisabled
                      ? null
                      : () {
                          widget.onChanged(gregDate);
                        },
                  customBorder: const CircleBorder(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bg,
                      border: border,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$hijriDay',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
