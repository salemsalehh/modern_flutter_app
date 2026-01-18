import 'package:adhan/adhan.dart';
import 'package:modern_flutter_app/data/planetary_hour_descriptions.dart';

class PlanetaryEngine {
  static const double latitude = 17.565;
  static const double longitude = 44.228;

  // Planetary Sequence: Saturn, Jupiter, Mars, Sun, Venus, Mercury, Moon
  static const List<String> planetarySequence = [
    'Moon',    // 0
    'Mercury', // 1
    'Venus',   // 2
    'Sun',     // 3
    'Mars',    // 4
    'Jupiter', // 5
    'Saturn',  // 6
  ];

  // Mapping days to their first hour ruler (Sunrise ruler)
  // Saturday: Saturn
  // Sunday: Sun
  // Monday: Moon
  // Tuesday: Mars
  // Wednesday: Mercury
  // Thursday: Jupiter
  // Friday: Venus
  static const Map<int, String> dayRulers = {
    6: 'Saturn',  // Saturday (DateTime.saturday = 6)
    7: 'Sun',     // Sunday (DateTime.sunday = 7)
    1: 'Moon',    // Monday (DateTime.monday = 1)
    2: 'Mars',    // Tuesday (DateTime.tuesday = 2)
    3: 'Mercury', // Wednesday (DateTime.wednesday = 3)
    4: 'Jupiter', // Thursday (DateTime.thursday = 4)
    5: 'Venus',   // Friday (DateTime.friday = 5)
  };

  /// Returns the planetary hours for a given date.
  /// This returns a list of 24 PlanetaryHour objects.
  /// The list starts with the 12 Day Hours (Sunrise to Sunset)
  /// Followed by the 12 Night Hours (Sunset to next Sunrise).
  static List<PlanetaryHour> getPlanetaryHours(DateTime date, {Coordinates? userCoordinates}) {
    // Default to Najran if no coordinates provided
    final coordinates = userCoordinates ?? Coordinates(latitude, longitude);
    final params = CalculationMethod.umm_al_qura.getParameters();
    
    // Calculate prayer times for the current day to get Sunrise and Sunset
    final prayerTimes = PrayerTimes(coordinates, DateComponents.from(date), params);
    
    // Sunrise and Sunset for the current day
    final sunrise = prayerTimes.sunrise;
    final sunset = prayerTimes.maghrib; // Maghrib is sunset

    // Calculate prayer times for the next day to get next Sunrise
    final nextDay = date.add(const Duration(days: 1));
    final nextPrayerTimes = PrayerTimes(coordinates, DateComponents.from(nextDay), params);
    final nextSunrise = nextPrayerTimes.sunrise;

    List<PlanetaryHour> hours = [];
    
    // --- Day Hours Calculation (Sunrise to Sunset) ---
    final dayDuration = sunset.difference(sunrise);
    final dayHourLength = dayDuration.inMilliseconds / 12;

    // Determine the ruler of the first hour of the day
    String currentPlanet = dayRulers[date.weekday]!;
    int planetIndex = planetarySequence.indexOf(currentPlanet);

    for (int i = 0; i < 12; i++) {
      final start = sunrise.add(Duration(milliseconds: (dayHourLength * i).round()));
      final end = sunrise.add(Duration(milliseconds: (dayHourLength * (i + 1)).round()));
      
      hours.add(PlanetaryHour(
        startTime: start,
        endTime: end,
        planetName: planetarySequence[planetIndex],
        isDay: true,
        hourIndex: i + 1,
        dayOfWeek: date.weekday,
      ));

      // Move to next planet in sequence (Reverse Chaldean Order based on user examples)
      // User Example: Monday Night starts with Jupiter.
      // Monday (Moon, idx 6) -> 12 hours reverse -> Jupiter (idx 1).
      planetIndex = (planetIndex - 1 + planetarySequence.length) % planetarySequence.length;
    }

    // --- Night Hours Calculation (Sunset to Next Sunrise) ---
    // Note: In Islamic context, the night belongs to the next day, but in this 24h cycle function
    // we are calculating the night FOLLOWING the day hours we just calculated.
    // The prompt asks for "12 Night Hours (Sunset to next Sunrise)".
    
    final nightDuration = nextSunrise.difference(sunset);
    final nightHourLength = nightDuration.inMilliseconds / 12;

    for (int i = 0; i < 12; i++) {
      final start = sunset.add(Duration(milliseconds: (nightHourLength * i).round()));
      final end = sunset.add(Duration(milliseconds: (nightHourLength * (i + 1)).round()));
      
      hours.add(PlanetaryHour(
        startTime: start,
        endTime: end,
        planetName: planetarySequence[planetIndex],
        isDay: false,
        hourIndex: i + 1,
        dayOfWeek: nextDay.weekday,
      ));

      planetIndex = (planetIndex - 1 + planetarySequence.length) % planetarySequence.length;
    }

    return hours;
  }

  /// Get the specific description for a given hour.
  /// This structure allows you to easily fill in the 168 descriptions.
  static String getHourDescription(int weekday, bool isDay, int hourIndex) {
    // Map key: "Weekday-IsDay-HourIndex"
    // Weekday: 1 (Mon) to 7 (Sun)
    // IsDay: true/false
    // HourIndex: 1 to 12
    
    // Example key format: "1-true-1" (Monday, Day, 1st Hour)
    final key = "$weekday-$isDay-$hourIndex";
    
    return hourDescriptions[key] ?? "No description available";
  }

  // Placeholder for the 168 descriptions
  // Format keys as: "${weekday}-${isDay}-${hourIndex}"
  static const Map<String, String> hourDescriptions = planetaryHourDescriptions;
}

class PlanetaryHour {
  final DateTime startTime;
  final DateTime endTime;
  final String planetName;
  final bool isDay;
  final int hourIndex; // 1-12
  final int dayOfWeek;

  PlanetaryHour({
    required this.startTime,
    required this.endTime,
    required this.planetName,
    required this.isDay,
    required this.hourIndex,
    required this.dayOfWeek,
  });

  @override
  String toString() {
    return 'Hour $hourIndex (${isDay ? "Day" : "Night"}): $planetName | ${startTime.hour}:${startTime.minute} - ${endTime.hour}:${endTime.minute}';
  }
}
