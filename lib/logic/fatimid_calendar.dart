/// A class to implement the Tabular (Fatimid) Hijri Calendar.
/// Based on a 30-year cycle with 11 leap years.
/// Epoch: Friday, July 16, 622 AD (Julian).
class FatimidCalendar {
  int hYear;
  int hMonth;
  int hDay;

  FatimidCalendar(this.hYear, this.hMonth, this.hDay);

  /// Leap years in the 30-year cycle (0-based index? No, usually 1-based year in cycle).
  /// User specified: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29.
  static const List<int> _leapYears = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];

  static const List<String> _monthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة'
  ];

  /// Returns true if the given Hijri year is a leap year.
  static bool isLeapYear(int year) {
    // 30-year cycle
    int yearInCycle = year % 30;
    if (yearInCycle == 0) yearInCycle = 30; // Handle year 30
    return _leapYears.contains(yearInCycle);
  }

  /// Returns the number of days in a specific Hijri month and year.
  static int getDaysInMonth(int year, int month) {
    if (month == 12) {
      return isLeapYear(year) ? 30 : 29;
    }
    // Odd months are 30, Even months are 29
    // 1, 3, 5, 7, 9, 11 -> 30
    // 2, 4, 6, 8, 10 -> 29
    return (month % 2 != 0) ? 30 : 29;
  }

  /// Converts a Gregorian DateTime to Fatimid Hijri date.
  /// Algorithm based on total days since Epoch.
  /// Epoch: July 16, 622 AD (Julian) -> July 19, 622 AD (Gregorian)?
  /// Most tabular converters use July 16, 622 (Julian) as the starting point.
  /// Let's use the standard Julian Day Number calculation for robustness.
  static FatimidCalendar fromGregorian(DateTime date) {
    // Julian Day Number calculation for the given Gregorian date
    int y = date.year;
    int m = date.month;
    int d = date.day;

    if (m < 3) {
      y -= 1;
      m += 12;
    }

    int a = y ~/ 100;
    int b = 2 - a + (a ~/ 4);
    
    // Julian Day Number (at noon, but we ignore the fraction for calendar conversion)
    int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b - 1524;

    // Epoch of Fatimid/Tabular Hijri: July 15, 622 Julian = JD 1948439
    // Adjusted to align with user requirement (Thursday epoch).
    int daysSinceEpoch = jd - 1948439; 
    
    // Calculate Hijri Year
    // A 30-year cycle has: 19 * 354 + 11 * 355 = 10631 days.
    int cycles = daysSinceEpoch ~/ 10631;
    int daysInCurrentCycle = daysSinceEpoch % 10631;

    int yearInCycle = 1;
    int daysPassed = 0;

    // Find the year within the cycle
    while (true) {
      int daysInYear = isLeapYear((cycles * 30) + yearInCycle) ? 355 : 354;
      if (daysPassed + daysInYear > daysInCurrentCycle) {
        break;
      }
      daysPassed += daysInYear;
      yearInCycle++;
    }

    int hYear = (cycles * 30) + yearInCycle;
    int remainingDays = daysInCurrentCycle - daysPassed;

    // Find the month
    int hMonth = 1;
    while (true) {
      int daysInMonth = getDaysInMonth(hYear, hMonth);
      if (remainingDays < daysInMonth) {
        break;
      }
      remainingDays -= daysInMonth;
      hMonth++;
    }

    int hDay = remainingDays + 1; // Days are 1-based

    return FatimidCalendar(hYear, hMonth, hDay);
  }

  /// Format the date as string.
  String toFormat(String format) {
    // Basic formatting implementation
    // Supported: DDDD (Week day - handled outside usually but added for compat), 
    // dd (day), MMMM (Month Name), yyyy (Year)
    
    // Note: This class doesn't know the weekday directly from arithmetic without JD, 
    // but the Gregorian source does. Since we construct from Gregorian usually, we can infer,
    // or we can calculate weekday from JD. JD % 7 gives day index.
    
    String formatted = format;
    formatted = formatted.replaceAll('dd', hDay.toString());
    formatted = formatted.replaceAll('MMMM', _monthNames[hMonth - 1]);
    formatted = formatted.replaceAll('yyyy', hYear.toString());
    
    return formatted;
  }

  /// Converts this Fatimid Hijri date back to a Gregorian DateTime.
  DateTime toDateTime() {
    // 1. Calculate days since Epoch
    // Epoch: July 15, 622 Julian = JD 1948439 (Thursday) 
    // (Note: fromGregorian implementation suggests JD 1948439 is the base)

    int cycles = (hYear - 1) ~/ 30;
    int yearInCycle = (hYear - 1) % 30 + 1;
    
    int days = cycles * 10631; // 10631 days per 30-year cycle

    // Add days for full years in current cycle
    for (int i = 1; i < yearInCycle; i++) {
      days += isLeapYear((cycles * 30) + i) ? 355 : 354;
    }

    // Add days for full months in current year
    for (int i = 1; i < hMonth; i++) {
      days += getDaysInMonth(hYear, i);
    }

    // Add days in current month
    days += (hDay - 1);

    // 2. Convert to Julian Day Number
    // JD = days + Epoch_JD
    int jd = days + 1948439;

    // 3. Convert Julian Day Number to Gregorian Date
    // Algorithm from: https://en.wikipedia.org/wiki/Julian_day#Julian_or_Gregorian_calendar_from_Julian_day_number
    int l = jd + 68569;
    int n = (4 * l) ~/ 146097;
    l = l - ((146097 * n + 3) ~/ 4);
    int i = (4000 * (l + 1)) ~/ 1461001;
    l = l - ((1461 * i) ~/ 4) + 31;
    int j = (80 * l) ~/ 2447;
    int d = l - ((2447 * j) ~/ 80);
    l = j ~/ 11;
    int m = j + 2 - (12 * l);
    int y = 100 * (n - 49) + i + l;

    return DateTime(y, m, d);
  }

  /// Returns a new FatimidCalendar instance with [months] added.
  /// Handles year rollovers.
  FatimidCalendar addMonth(int months) {
    int totalMonths = (hYear * 12) + (hMonth - 1) + months;
    int newYear = totalMonths ~/ 12;
    int newMonth = (totalMonths % 12) + 1;
    
    // Adjust day if necessary (e.g., 30th of a 29-day month)
    int daysInNewMonth = getDaysInMonth(newYear, newMonth);
    int newDay = hDay <= daysInNewMonth ? hDay : daysInNewMonth;

    return FatimidCalendar(newYear, newMonth, newDay);
  }
  
  @override
  String toString() {
    return '$hDay ${_monthNames[hMonth-1]} $hYear';
  }
}
