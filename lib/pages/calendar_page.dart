import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:modern_flutter_app/data/hijri_data.dart';
import 'package:modern_flutter_app/data/week_data.dart';
import 'package:modern_flutter_app/logic/fatimid_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // Navigation State
  late PageController _pageController;
  late FatimidCalendar _initialFatimid; // The month we started with
  late FatimidCalendar _displayedMonth; // The month currently visible

  // Selection State
  late DateTime _selectedGregorian;
  late FatimidCalendar _selectedFatimid;

  static const int _initialPage = 1000;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _initialFatimid = FatimidCalendar.fromGregorian(now);
    _displayedMonth = _initialFatimid;
    
    // Initialize selection to today
    _selectedGregorian = now;
    _selectedFatimid = _initialFatimid;
    
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  Widget build(BuildContext context) {
    // Format Month Name
    final monthName = _displayedMonth.toFormat("MMMM yyyy");

    return Scaffold(
      appBar: AppBar(
        title: Text(monthName),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Grid Section
              Text(
                'نظرة الشهر',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Swipeable Calendar Container
              SizedBox(
                height: 380, // Fixed height for the calendar card
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      final monthOffset = index - _initialPage;
                      _displayedMonth = _initialFatimid.addMonth(monthOffset);
                    });
                  },
                  itemBuilder: (context, index) {
                    final monthOffset = index - _initialPage;
                    final monthToDisplay = _initialFatimid.addMonth(monthOffset);
                    return _buildMonthGrid(monthToDisplay);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Selected Day Details Section
              _buildSelectedDayDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayDetails() {
    final weekdayNameEn = DateFormat('EEEE', 'en').format(_selectedGregorian);
    final weekdayNameAr = DateFormat('EEEE', 'ar').format(_selectedGregorian);
    final weekProperty = WeekData.getProperty(weekdayNameEn);
    final hijriInfo = HijriData.getDayInfo(_selectedFatimid.hMonth, _selectedFatimid.hDay);
    final color = HijriData.getDayColor(_selectedFatimid.hMonth, _selectedFatimid.hDay);
    
    final isNehus = HijriData.hasAnyNehus(_selectedFatimid.hMonth, _selectedFatimid.hDay);
    final nehusTitle = HijriData.getDominantNehusTitle(_selectedFatimid.hMonth, _selectedFatimid.hDay);

    return Card(
      elevation: 2,
      color: color.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isNehus ? Icons.warning_amber_rounded : Icons.info_outline, 
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  isNehus ? (nehusTitle ?? 'تحذير: يوم نحس') : 'تفاصيل اليوم المحدد',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedFatimid.hDay} ${_selectedFatimid.toFormat("MMMM")}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color, 
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Weekday Wisdom (Only if not Nehus)
            if (!isNehus)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$weekdayNameAr: $weekProperty',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            
            // Hijri Insight
            Text(
              hijriInfo,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(FatimidCalendar month) {
    // Weekday headers (Mon -> Sun)
    final weekdays = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    
    // Calculate Grid Data for this specific month
    // 1. Get the Fatimid date for the 1st of this month
    final startOfMonthFatimid = FatimidCalendar(month.hYear, month.hMonth, 1);
    
    // 2. Get the Gregorian date for the 1st of this month
    final startOfMonthGregorian = startOfMonthFatimid.toDateTime();
    
    // 3. Get weekday (1=Mon ... 7=Sun)
    final startWeekday = startOfMonthGregorian.weekday;
    
    // 4. Get total days
    final daysInMonth = FatimidCalendar.getDaysInMonth(month.hYear, month.hMonth);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 4), // Add margin for page spacing look
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekdays.map((w) => SizedBox(
                width: 30,
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
            const Divider(),
            // Grid
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: (startWeekday - 1) + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < startWeekday - 1) {
                    return const SizedBox();
                  }

                  final dayNum = index - (startWeekday - 1) + 1;
                  final color = HijriData.getDayColor(month.hMonth, dayNum);
                  
                  // Highlight today (if displayed month is current month)
                  final isToday = dayNum == _initialFatimid.hDay && 
                                  month.hMonth == _initialFatimid.hMonth &&
                                  month.hYear == _initialFatimid.hYear;

                  // Highlight selected
                  final isSelected = _selectedFatimid.hDay == dayNum && 
                                     _selectedFatimid.hMonth == month.hMonth &&
                                     _selectedFatimid.hYear == month.hYear;

                  return InkWell(
                    onTap: () {
                      final targetDate = startOfMonthGregorian.add(Duration(days: dayNum - 1));
                      setState(() {
                        _selectedGregorian = targetDate;
                        _selectedFatimid = FatimidCalendar(
                          month.hYear,
                          month.hMonth,
                          dayNum,
                        );
                      });
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.4) : color.withOpacity(0.2),
                        border: isSelected 
                            ? Border.all(color: color, width: 3) 
                            : (isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          color: color.withOpacity(1.0),
                          fontWeight: FontWeight.bold,
                          fontSize: isSelected ? 16 : 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
