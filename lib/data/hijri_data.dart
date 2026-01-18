import 'package:flutter/material.dart';

/// A class to hold detailed Hijri date properties and Nehus data.
class HijriData {
  /// Maps each Hijri day (1-30) to its specific property description.
  static const Map<int, String> monthlyDescriptions = {
    1: 'يوم يصلح فيه لقاء الملوك والأمراء',
    2: 'يوم يصلح للبيع والشراء وكل أمر',
    3: 'يوم ردي في كل الامور وللأشغال',
    4: 'يوم صالح لجميع الأشغال والأعمال',
    5: 'يوم ردي جدا لا يبتداء فيه عمل',
    6: 'يوم صالح لكل أمر وحاجة',
    7: 'يوم صالح في كل الامور والحوائج',
    8: 'يوم صالح لقاء الحوائج والتقرر',
    9: 'يوم صالح لسائر الأعمال',
    10: 'يوم جيد لجميع المهمات',
    11: 'يوم صالح لطلب الحوائج وغيرها',
    12: 'يوم صالح للقاء الملوك والأمراء',
    13: 'يوم مذموم يحذر فيه لقاء الملوك',
    14: 'يوم صالح لكل عمل وحاجة',
    15: 'يوم صالح وقيل ممتزج الحال',
    16: 'يوم ردي لسائر الأعمال',
    17: 'يوم جيد لكافة الأعمال',
    18: 'يوم جيد لعمل الولائم والأفراح',
    19: 'يوم صالح للمهمات في الأمور',
    20: 'يوم صالح يحمد فيه سائر الأعمال',
    21: 'يوم ممتزج متوسط في أحواله',
    22: 'يوم صالح لقضاء الحوائج',
    23: 'يوم متوسط الحال',
    24: 'يوم ردي لا يبتداء فيه بأمر',
    25: 'يوم ردي مذموم لسائر الأعمال',
    26: 'يوم صالح لسائر الأعمال',
    27: 'يوم جيد لابتداء الأعمال',
    28: 'يوم صالح لسائر الأعمال',
    29: 'يوم متوسط الحال',
    30: 'يوم صالح لطلب الحوائج والسفر',
  };

  /// Monthly Nehus (Alert Days).
  static const List<int> monthlyNehusDays = [3, 5, 13, 16, 21, 24, 25];

  /// Alert message for Monthly Nehus.
  static const String monthlyNehusAlert =
      'نحس الشهر: لا بيع ولا سفر ولا لبس ثوب جديد ولا زواج ولا غرس شجر ولا حفر بئر ولا شراء بيت والحذر من  قرب السلطان';

  static const List<int> monthlyMixedDays = [4, 8, 10, 14, 15, 19, 26, 28, 29];

  static const List<int> monthlySelectedGoodDays =
      [1, 2, 6, 7, 9, 11, 12, 17, 18, 20, 22, 23, 27, 30];

  static bool isYearlyNehus(int month, int day) {
    return yearlyNehus.containsKey(month) && yearlyNehus[month]!.contains(day);
  }

  static bool isMonthlyNehus(int day) {
    return monthlyNehusDays.contains(day);
  }

  static List<String> getNehusMessages(int month, int day) {
    final parts = <String>[];
    if (isYearlyNehus(month, day)) {
      parts.add('تحذير: نحس السنة (غير صالح)');
    }
    if (isMonthlyNehus(day)) {
      parts.add(monthlyNehusAlert);
    }
    return parts;
  }

  static bool _isPositiveDescription(String description) {
    return description.contains('صالح') || description.contains('جيد');
  }

  static bool hasAnyNehus(int month, int day) {
    return isYearlyNehus(month, day) || isMonthlyNehus(day);
  }

  static bool isMixedDay(int day) {
    return monthlyMixedDays.contains(day);
  }

  static bool isSelectedGoodDay(int day) {
    return monthlySelectedGoodDays.contains(day);
  }

  static String? getDayCategoryLabel(int month, int day) {
    if (hasAnyNehus(month, day)) return null;
    if (isMixedDay(day)) return 'اليوم ممتزج (متوسط الحال)';
    if (isSelectedGoodDay(day)) return 'اليوم من الأيام المختارة (جيد)';
    return null;
  }

  static String? getDominantNehusTitle(int month, int day) {
    final yearly = isYearlyNehus(month, day);
    final monthly = isMonthlyNehus(day);

    if (yearly && monthly) return 'تحذير: نحس السنة والشهر';
    if (yearly) return 'تحذير: نحس السنة';
    if (monthly) return 'تحذير: نحس الشهر';
    return null;
  }

  /// Yearly Special Nehus.
  /// Maps Month Index (1-12) to the list of Days that are considered Nehus.
  static const Map<int, List<int>> yearlyNehus = {
    2: [12, 20], // Safar
    3: [4, 28], // Rabi' I
    5: [4, 28], // Jumada I
    6: [12],    // Jumada II
    7: [12],    // Rajab
    8: [26],    // Sha'ban
    9: [24],    // Ramadan
    10: [8],    // Shawwal
    11: [28],   // Dhu al-Qi'dah
    12: [8],    // Dhu al-Hijjah
  };

  /// Returns the detailed info for a specific Hijri day.
  /// [month] is 1-12, [day] is 1-30.
  static String getDayInfo(int month, int day) {
    List<String> infoParts = [];

    final nehusMessages = getNehusMessages(month, day);
    infoParts.addAll(nehusMessages);

    final categoryLabel = getDayCategoryLabel(month, day);
    if (categoryLabel != null) {
      infoParts.add(categoryLabel);
    }

    final description = monthlyDescriptions[day] ?? 'لا توجد بيانات لهذا اليوم';

    if (nehusMessages.isEmpty) {
      infoParts.add(description);
    } else {
      if (!_isPositiveDescription(description)) {
        infoParts.add(description);
      }
    }

    return infoParts.join('\n\n');
  }

  /// Returns the color code for a specific Hijri day.
  static Color getDayColor(int month, int day) {
    // 1. Check Yearly Special Nehus & Monthly Nehus (Red)
    if ((yearlyNehus.containsKey(month) && yearlyNehus[month]!.contains(day)) ||
        monthlyNehusDays.contains(day)) {
      return Colors.red;
    }

    if (isMixedDay(day)) {
      return Colors.amber;
    }

    if (isSelectedGoodDay(day)) {
      return Colors.green;
    }

    final description = monthlyDescriptions[day] ?? '';

    // 2. Check Green keywords
    if (description.contains('صالح') || description.contains('جيد')) {
      return Colors.green;
    }

    // 3. Check Yellow/Amber keywords
    if (description.contains('متوسط') || description.contains('ممتزج')) {
      return Colors.amber;
    }

    // 4. Check Grey keywords
    if (description.contains('ردي') || description.contains('مذموم')) {
      return Colors.grey;
    }

    // Default
    return Colors.blueGrey;
  }
}
