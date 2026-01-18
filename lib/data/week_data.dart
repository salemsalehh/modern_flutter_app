/// A class to hold the properties for each day of the week.
/// This data is structured to be easily editable.
class WeekData {
  /// Maps each day name to its specific property description.
  static const Map<String, String> properties = {
    'Saturday': 'للصيد',
    'Sunday': 'البناء',
    'Monday': 'السفر والرجوع بالنجاح و بالثراء',
    'Tuesday': 'حجامة',
    'Wednesday': 'شرب الدواء',
    'Thursday': 'قضاء حوائج',
    'Friday': 'التزويج فيه ولذات الرجال مع النساء',
  };

  /// Helper method to get property by day name
  static String getProperty(String dayName) {
    return properties[dayName] ?? 'No property found';
  }
}
