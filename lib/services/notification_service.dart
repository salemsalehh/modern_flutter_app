import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../data/hijri_data.dart';
import '../logic/fatimid_calendar.dart';
import 'location_service.dart';
import 'location_prefs.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    // Request permissions for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleDailyNotificationsForWeek() async {
    // Cancel existing notifications to avoid duplicates
    await flutterLocalNotificationsPlugin.cancelAll();

    final now = DateTime.now();
    
    // Get User Location
    final mode = await LocationPrefs.getMode();
    final selected = await LocationPrefs.getSelectedLocation();
    final customCoords = selected == null ? null : Coordinates(selected.latitude, selected.longitude);

    final locationResult = await LocationService().getLocationResultByMode(
      mode: mode,
      customCoordinates: customCoords,
    );
    final coordinates = locationResult.coordinates;
    final params = CalculationMethod.umm_al_qura.getParameters();

    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      
      // Calculate data for this date
      final fatimid = FatimidCalendar.fromGregorian(date);
      final hijriDateStr = '${fatimid.hDay} ${fatimid.toFormat("MMMM")}';
      
      // Get property
      final description = HijriData.monthlyDescriptions[fatimid.hDay] ?? 'لا توجد بيانات';
      // Truncate description if too long
      final shortDescription = description.length > 50 
          ? '${description.substring(0, 50)}...' 
          : description;

      // Calculate Sunrise for this specific date and location
      final dateComponents = DateComponents.from(date);
      final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
      final sunrise = prayerTimes.sunrise;

      // Convert Sunrise DateTime to TZDateTime
      // Note: prayerTimes.sunrise is in local time of the device if coordinates match timezone, 
      // but strictly it returns a DateTime. We assume device timezone match.
      var scheduledDate = tz.TZDateTime.from(sunrise, tz.local);

      if (scheduledDate.isBefore(now)) {
        // If sunrise has passed for today, skip scheduling for today
        if (i == 0) continue; 
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        i, // ID
        'تذكير التقويم الفاطمي: $hijriDateStr',
        shortDescription,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_insight_channel', // channelId
            'Daily Insights',        // channelName
            channelDescription: 'Daily Fatimid Calendar Insights',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
