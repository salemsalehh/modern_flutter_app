import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemNavigator
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:adhan/adhan.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:modern_flutter_app/data/hijri_data.dart';
import 'package:modern_flutter_app/data/week_data.dart';
import 'package:modern_flutter_app/logic/fatimid_calendar.dart';
import 'package:modern_flutter_app/logic/planetary_engine.dart';
import 'package:modern_flutter_app/pages/calendar_page.dart';
import 'package:modern_flutter_app/pages/planetary_hours_page.dart';
import 'package:modern_flutter_app/pages/planetary_search_page.dart';
import 'package:modern_flutter_app/services/location_service.dart';
import 'package:modern_flutter_app/services/location_prefs.dart';
import 'package:modern_flutter_app/services/share_import_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);
  // Notifications disabled for web - uncomment for mobile:
  // await NotificationService().init();
  // await NotificationService().scheduleDailyNotificationsForWeek();
  
  runApp(const ModernApp());
}

class ModernApp extends StatelessWidget {
  const ModernApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Modern Flutter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.cairoTextTheme(), // Switch to Cairo for better Arabic support
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      // Arabic RTL Configuration
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const DashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PlanetaryHourCountdownPage extends StatefulWidget {
  final Coordinates? coordinates;
  final String locationLabel;

  const PlanetaryHourCountdownPage({
    super.key,
    required this.coordinates,
    required this.locationLabel,
  });

  @override
  State<PlanetaryHourCountdownPage> createState() => _PlanetaryHourCountdownPageState();
}

class _PlanetaryHourCountdownPageState extends State<PlanetaryHourCountdownPage> {
  Timer? _ticker;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (_getCurrentHour(now) != null) {
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  ({DateTime start, DateTime end, List<PlanetaryHour> hours}) _getMaghribCycle(DateTime now) {
    final coords = widget.coordinates ?? Coordinates(PlanetaryEngine.latitude, PlanetaryEngine.longitude);
    final params = CalculationMethod.umm_al_qura.getParameters();

    final today = _dateOnly(now);
    final todayPrayer = PrayerTimes(coords, DateComponents.from(today), params);
    final todayMaghrib = todayPrayer.maghrib;

    DateTime start;
    DateTime end;
    List<PlanetaryHour> cycleHours;

    if (now.isBefore(todayMaghrib)) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayPrayer = PrayerTimes(coords, DateComponents.from(yesterday), params);
      start = yesterdayPrayer.maghrib;
      end = todayMaghrib;

      final night = PlanetaryEngine.getPlanetaryHours(yesterday, userCoordinates: coords)
          .where((h) => !h.isDay)
          .toList();
      final day = PlanetaryEngine.getPlanetaryHours(today, userCoordinates: coords)
          .where((h) => h.isDay)
          .toList();
      cycleHours = [...night, ...day];
    } else {
      final tomorrow = today.add(const Duration(days: 1));
      final tomorrowPrayer = PrayerTimes(coords, DateComponents.from(tomorrow), params);
      start = todayMaghrib;
      end = tomorrowPrayer.maghrib;

      final night = PlanetaryEngine.getPlanetaryHours(today, userCoordinates: coords)
          .where((h) => !h.isDay)
          .toList();
      final day = PlanetaryEngine.getPlanetaryHours(tomorrow, userCoordinates: coords)
          .where((h) => h.isDay)
          .toList();
      cycleHours = [...night, ...day];
    }

    cycleHours.sort((a, b) => a.startTime.compareTo(b.startTime));
    final trimmed = cycleHours
        .where((h) => !h.startTime.isBefore(start) && !h.endTime.isAfter(end))
        .toList();

    return (start: start, end: end, hours: trimmed);
  }

  PlanetaryHour? _getCurrentHour(DateTime now) {
    final cycle = _getMaghribCycle(now);
    final list = cycle.hours;
    final current = list.where((h) => !now.isBefore(h.startTime) && now.isBefore(h.endTime)).toList();
    return current.isEmpty ? null : current.first;
  }

  String _arabicOrdinalHour(int hourIndex) {
    switch (hourIndex) {
      case 1:
        return 'الأولى';
      case 2:
        return 'الثانية';
      case 3:
        return 'الثالثة';
      case 4:
        return 'الرابعة';
      case 5:
        return 'الخامسة';
      case 6:
        return 'السادسة';
      case 7:
        return 'السابعة';
      case 8:
        return 'الثامنة';
      case 9:
        return 'التاسعة';
      case 10:
        return 'العاشرة';
      case 11:
        return 'الحادية عشرة';
      case 12:
        return 'الثانية عشرة';
      default:
        return hourIndex.toString();
    }
  }

  String _planetNameArabic(String planet) {
    switch (planet) {
      case 'Saturn':
        return 'زحل';
      case 'Jupiter':
        return 'المشتري';
      case 'Mars':
        return 'المريخ';
      case 'Sun':
        return 'الشمس';
      case 'Venus':
        return 'الزهرة';
      case 'Mercury':
        return 'عطارد';
      case 'Moon':
        return 'القمر';
      default:
        return planet;
    }
  }

  Widget _buildHourTile(
    PlanetaryHour hour, {
    required bool isCurrent,
    required bool emphasize,
  }) {
    final timeFormatter = DateFormat('h:mm a', 'ar');
    final title = 'الساعة الفلكية ${_arabicOrdinalHour(hour.hourIndex)} (${_planetNameArabic(hour.planetName)})';
    final range = 'من ${timeFormatter.format(hour.startTime)} إلى ${timeFormatter.format(hour.endTime)}';
    final description = PlanetaryEngine.getHourDescription(hour.dayOfWeek, hour.isDay, hour.hourIndex);

    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = hour.isDay ? colorScheme.surface : colorScheme.secondaryContainer;
    final onBaseColor = hour.isDay ? colorScheme.onSurface : colorScheme.onSecondaryContainer;
    final leadingIcon = hour.isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round;
    final labelText = hour.isDay ? 'نهار' : 'ليل';

    final borderSide = isCurrent ? BorderSide(color: colorScheme.primary, width: 2) : BorderSide.none;
    final titleStyle = emphasize
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: onBaseColor)
        : Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: onBaseColor);

    return Card(
      elevation: 0,
      color: baseColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: borderSide,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCurrent,
          iconColor: onBaseColor,
          collapsedIconColor: onBaseColor,
          textColor: onBaseColor,
          collapsedTextColor: onBaseColor,
          tilePadding: EdgeInsets.symmetric(horizontal: 12, vertical: emphasize ? 14 : 8),
          leading: Icon(leadingIcon, color: onBaseColor),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: titleStyle,
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(labelText),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: onBaseColor),
                side: BorderSide(color: onBaseColor.withOpacity(0.25)),
                backgroundColor: Colors.transparent,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('الآن'),
                  labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onPrimary),
                  backgroundColor: colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]
            ],
          ),
          subtitle: Text(
            range,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onBaseColor.withOpacity(0.85)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: onBaseColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cycle = _getMaghribCycle(now);
    final remaining = cycle.hours.where((h) => h.endTime.isAfter(now)).toList();
    final current = remaining.where((h) => !now.isBefore(h.startTime) && now.isBefore(h.endTime)).toList();
    final currentHour = current.isEmpty ? null : current.first;
    final upcoming = currentHour == null
        ? remaining
        : remaining.where((h) => h.startTime.isAfter(currentHour.startTime)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المتبقي من الساعات الفلكية'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'الموقع: ${widget.locationLabel}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'من ${DateFormat('h:mm a', 'ar').format(cycle.start)} إلى ${DateFormat('h:mm a', 'ar').format(cycle.end)}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (currentHour == null)
              const Center(child: Text('لا توجد ساعات فلكية متبقية الآن')),
            if (currentHour != null) ...[
              _buildHourTile(currentHour, isCurrent: true, emphasize: true),
              const SizedBox(height: 12),
            ],
            ...upcoming.map((h) => _buildHourTile(h, isCurrent: false, emphasize: false)),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late FatimidCalendar _hijriDate;
  late DateTime _gregorianDate;
  late String _weekdayNameArabic;  // For display

  LocationMode _locationMode = LocationMode.defaultLocation;
  List<SavedLocation> _savedLocations = const [];
  SavedLocation? _selectedSavedLocation;

  final ShareImportService _shareImportService = ShareImportService();
  StreamSubscription<String>? _shareSub;

  final Random _rand = Random();

  Timer? _uiTicker;

  LocationResult? _locationResult;
  String _locationModeLabel = 'نجران';

  @override
  void initState() {
    super.initState();
    _refreshDate();
    _loadLocationSettings();
    _initShareListener();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _uiTicker?.cancel();
    super.dispose();
  }

  void _setUiTickerEnabled(bool enabled) {
    if (!mounted) return;

    if (enabled) {
      if (_uiTicker != null) return;
      _uiTicker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
      return;
    }

    _uiTicker?.cancel();
    _uiTicker = null;
  }

  Future<void> _loadLocationSettings() async {
    final mode = await LocationPrefs.getMode();
    final saved = await LocationPrefs.getSavedLocations();
    final selected = await LocationPrefs.getSelectedLocation();
    if (!mounted) return;
    setState(() {
      _locationMode = mode;
      _savedLocations = saved;
      _selectedSavedLocation = selected;
    });
    await _refreshLocation(showMessageOnFallback: false);
  }

  Future<void> _setLocationMode(LocationMode mode, {String? selectedLocationId}) async {
    await LocationPrefs.setMode(mode);
    if (mode == LocationMode.custom) {
      await LocationPrefs.setSelectedLocationId(selectedLocationId);
    }
    if (!mounted) return;
    setState(() {
      _locationMode = mode;
      if (mode == LocationMode.custom) {
        _selectedSavedLocation = _findSavedLocationById(_savedLocations, selectedLocationId) ?? _selectedSavedLocation;
      }
    });
    await _loadLocationSettings();
  }

  SavedLocation? _findSavedLocationById(List<SavedLocation> list, String? id) {
    if (id == null || id.trim().isEmpty) return null;
    for (final l in list) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<void> _refreshLocation({required bool showMessageOnFallback}) async {
    final custom = _locationMode == LocationMode.custom
        ? _selectedSavedLocation
        : null;

    final customCoords = custom == null
        ? null
        : Coordinates(custom.latitude, custom.longitude);

    final result = await LocationService().getLocationResultByMode(
      mode: _locationMode,
      customCoordinates: customCoords,
    );
    if (!mounted) return;

    setState(() {
      _locationResult = result;
      if (_locationMode == LocationMode.custom && _selectedSavedLocation != null) {
        _locationModeLabel = _selectedSavedLocation!.name;
      } else if (_locationMode == LocationMode.gps) {
        _locationModeLabel = result.usedDefault ? 'نجران' : 'GPS';
      } else {
        _locationModeLabel = 'نجران';
      }
    });

    if (showMessageOnFallback && _locationMode == LocationMode.gps && result.usedDefault && result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message!),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openLocationOptions() async {
    var tempMode = _locationMode;
    var tempSaved = List<SavedLocation>.from(_savedLocations);
    var tempSelectedId = _selectedSavedLocation?.id;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final selectedLocation = _findSavedLocationById(tempSaved, tempSelectedId);

            return AlertDialog(
              title: const Text('إعدادات الموقع'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<LocationMode>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('نجران (افتراضي)'),
                    value: LocationMode.defaultLocation,
                    groupValue: tempMode,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() {
                        tempMode = v;
                      });
                    },
                  ),
                  RadioListTile<LocationMode>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('GPS'),
                    value: LocationMode.gps,
                    groupValue: tempMode,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() {
                        tempMode = v;
                      });
                    },
                  ),
                  RadioListTile<LocationMode>(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('موقع مخصص (مفضلة)'),
                    value: LocationMode.custom,
                    groupValue: tempMode,
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() {
                        tempMode = v;
                        if (tempSelectedId == null && tempSaved.isNotEmpty) {
                          tempSelectedId = tempSaved.last.id;
                        }
                      });
                    },
                  ),
                  if (tempMode == LocationMode.custom)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: tempSelectedId,
                          items: tempSaved
                              .map(
                                (l) => DropdownMenuItem(
                                  value: l.id,
                                  child: Text(l.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setLocalState(() {
                              tempSelectedId = v;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'اختر موقعًا محفوظًا',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('من خرائط Google اختر مشاركة ثم اختر هذا التطبيق لحفظ الموقع.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.share),
                                label: const Text('استيراد من مشاركة'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'حذف الموقع المختار',
                              onPressed: selectedLocation == null
                                  ? null
                                  : () async {
                                      await LocationPrefs.deleteLocation(selectedLocation.id);
                                      final updated = await LocationPrefs.getSavedLocations();
                                      final selected = await LocationPrefs.getSelectedLocation();
                                      setLocalState(() {
                                        tempSaved = updated;
                                        tempSelectedId = selected?.id;
                                      });
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  if (tempMode == LocationMode.gps && _locationResult?.usedDefault == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _locationResult?.message ?? 'تم استخدام موقع نجران الافتراضي.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setLocationMode(tempMode, selectedLocationId: tempSelectedId);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _initShareListener() {
    _shareSub = _shareImportService.textStream.listen((text) async {
      await _handleIncomingShare(text);
    });

    _shareImportService.initialText.then((text) async {
      if (text == null || text.trim().isEmpty) return;
      await _handleIncomingShare(text);
    });
  }

  Future<void> _handleIncomingShare(String rawText) async {
    if (!mounted) return;

    final coords = await _extractLatLngFromShare(rawText);
    if (!mounted) return;
    if (coords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم أستطع استخراج الإحداثيات من المشاركة. جرّب مشاركة رابط يحتوي على إحداثيات أو مشاركة نص الإحداثيات مباشرة.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حفظ موقع'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'اسم الموقع',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                Navigator.pop(context, name.isEmpty ? null : name);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (saved == null || saved.trim().isEmpty) return;

    final id = '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';
    final location = SavedLocation(
      id: id,
      name: saved.trim(),
      latitude: coords.$1,
      longitude: coords.$2,
    );

    await LocationPrefs.upsertLocation(location);
    await LocationPrefs.setSelectedLocationId(id);
    await LocationPrefs.setMode(LocationMode.custom);
    await _shareImportService.reset();

    if (!mounted) return;
    await _loadLocationSettings();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ الموقع: ${location.name}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<(double, double)?> _extractLatLngFromShare(String text) async {
    final direct = _tryExtractLatLng(text);
    if (direct != null) return direct;

    final url = _firstUrlFromText(text);
    if (url == null) return null;

    final resolved = await _resolveRedirects(url);
    final resolvedCoords = _tryExtractLatLng(resolved.toString());
    if (resolvedCoords != null) return resolvedCoords;

    return null;
  }

  Uri? _firstUrlFromText(String text) {
    final s = text.trim();
    final match = RegExp(r'(https?:\/\/\S+|\bmaps\.app\.goo\.gl\/\S+|\bgoo\.gl\/maps\/\S+|\bwww\.google\.com\/maps\S+)')
        .firstMatch(s);
    if (match == null) return null;

    var u = match.group(1) ?? '';
    u = u.replaceAll(RegExp(r'[\)\]>,\s]+$'), '');
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }

    return Uri.tryParse(u);
  }

  Future<Uri> _resolveRedirects(Uri uri) async {
    var current = uri;
    final client = http.Client();
    try {
      for (var i = 0; i < 6; i++) {
        final req = http.Request('GET', current)
          ..followRedirects = false
          ..maxRedirects = 0;
        final resp = await client.send(req);
        final loc = resp.headers['location'];
        if (resp.isRedirect && loc != null && loc.isNotEmpty) {
          current = current.resolve(loc);
          continue;
        }
        return current;
      }
      return current;
    } catch (_) {
      return current;
    } finally {
      client.close();
    }
  }

  (double, double)? _tryExtractLatLng(String text) {
    final s = text.trim();

    final direct = RegExp(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)');
    final directMatch = direct.firstMatch(s);
    if (directMatch != null) {
      final lat = double.tryParse(directMatch.group(1) ?? '');
      final lng = double.tryParse(directMatch.group(2) ?? '');
      if (lat != null && lng != null) return (lat, lng);
    }

    final at = RegExp(r'@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)');
    final atMatch = at.firstMatch(s);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1) ?? '');
      final lng = double.tryParse(atMatch.group(2) ?? '');
      if (lat != null && lng != null) return (lat, lng);
    }

    final query = RegExp(r'(?:query|q)=(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)');
    final queryMatch = query.firstMatch(s);
    if (queryMatch != null) {
      final lat = double.tryParse(queryMatch.group(1) ?? '');
      final lng = double.tryParse(queryMatch.group(2) ?? '');
      if (lat != null && lng != null) return (lat, lng);
    }

    final ll = RegExp(r'(?:ll|center)=(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)');
    final llMatch = ll.firstMatch(s);
    if (llMatch != null) {
      final lat = double.tryParse(llMatch.group(1) ?? '');
      final lng = double.tryParse(llMatch.group(2) ?? '');
      if (lat != null && lng != null) return (lat, lng);
    }

    final d3d4d = RegExp(r'!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)');
    final d3d4dMatch = d3d4d.firstMatch(s);
    if (d3d4dMatch != null) {
      final lat = double.tryParse(d3d4dMatch.group(1) ?? '');
      final lng = double.tryParse(d3d4dMatch.group(2) ?? '');
      if (lat != null && lng != null) return (lat, lng);
    }

    return null;
  }

  void _refreshDate() {
    _gregorianDate = DateTime.now();
    _hijriDate = FatimidCalendar.fromGregorian(_gregorianDate);
    _weekdayNameArabic = DateFormat('EEEE', 'ar').format(_gregorianDate);
    setState(() {});
  }

  bool _isNehus(int hMonth, int hDay) {
    return HijriData.hasAnyNehus(hMonth, hDay);
  }

  DateTime _getEffectiveIslamicGregorianDate(DateTime now) {
    final dateOnly = DateTime(now.year, now.month, now.day);
    final coordinates = _locationResult?.coordinates ??
        Coordinates(LocationService.defaultLatitude, LocationService.defaultLongitude);
    final params = CalculationMethod.umm_al_qura.getParameters();
    final prayerTimes = PrayerTimes(coordinates, DateComponents.from(dateOnly), params);
    final maghrib = prayerTimes.maghrib;

    if (!now.isBefore(maghrib)) {
      return dateOnly.add(const Duration(days: 1));
    }

    return dateOnly;
  }

  String _arabicOrdinalHour(int hourIndex) {
    switch (hourIndex) {
      case 1:
        return 'الأولى';
      case 2:
        return 'الثانية';
      case 3:
        return 'الثالثة';
      case 4:
        return 'الرابعة';
      case 5:
        return 'الخامسة';
      case 6:
        return 'السادسة';
      case 7:
        return 'السابعة';
      case 8:
        return 'الثامنة';
      case 9:
        return 'التاسعة';
      case 10:
        return 'العاشرة';
      case 11:
        return 'الحادية عشرة';
      case 12:
        return 'الثانية عشرة';
      default:
        return hourIndex.toString();
    }
  }

  String _planetNameArabic(String planetName) {
    switch (planetName) {
      case 'Saturn':
        return 'زحل';
      case 'Jupiter':
        return 'المشتري';
      case 'Mars':
        return 'المريخ';
      case 'Sun':
        return 'الشمس';
      case 'Venus':
        return 'الزهرة';
      case 'Mercury':
        return 'عطارد';
      case 'Moon':
        return 'القمر';
      default:
        return planetName;
    }
  }

  PlanetaryHour? _getCurrentPlanetaryHour(DateTime now) {
    final coordinates = _locationResult?.coordinates;
    final todayHours = PlanetaryEngine.getPlanetaryHours(now, userCoordinates: coordinates);
    final currentToday = todayHours.where((h) => !now.isBefore(h.startTime) && now.isBefore(h.endTime)).toList();
    if (currentToday.isNotEmpty) {
      return currentToday.first;
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayHours = PlanetaryEngine.getPlanetaryHours(yesterday, userCoordinates: coordinates);
    final currentYesterday = yesterdayHours.where((h) => !now.isBefore(h.startTime) && now.isBefore(h.endTime)).toList();
    if (currentYesterday.isNotEmpty) {
      return currentYesterday.first;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final effectiveIslamicDate = _getEffectiveIslamicGregorianDate(now);
    final effectiveHijriDate = FatimidCalendar.fromGregorian(effectiveIslamicDate);
    final effectiveWeekdayNameEnglish = DateFormat('EEEE', 'en').format(effectiveIslamicDate);
    final effectiveWeekdayNameArabic = DateFormat('EEEE', 'ar').format(effectiveIslamicDate);

    final bool isNehusDay = _isNehus(effectiveHijriDate.hMonth, effectiveHijriDate.hDay);
    final String? nehusTitleToday =
        HijriData.getDominantNehusTitle(effectiveHijriDate.hMonth, effectiveHijriDate.hDay);
    final String nehusDetailsToday =
        HijriData.getNehusMessages(effectiveHijriDate.hMonth, effectiveHijriDate.hDay).join('\n');

    final String weekProperty = WeekData.getProperty(effectiveWeekdayNameEnglish);
    final String hijriInfo = HijriData.getDayInfo(effectiveHijriDate.hMonth, effectiveHijriDate.hDay);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.power_settings_new, color: Colors.red),
          onPressed: () => SystemNavigator.pop(),
          tooltip: 'إغلاق التطبيق',
        ),
        title: const Text('نظرة اليوم'), // Daily Insight
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _locationMode == LocationMode.gps
                  ? Icons.gps_fixed
                  : (_locationMode == LocationMode.custom ? Icons.place : Icons.location_city),
            ),
            onPressed: _openLocationOptions,
            tooltip: 'إعدادات الموقع',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث الساعات الفلكية',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlanetarySearchPage(
                    coordinates: _locationResult?.coordinates,
                    locationLabel: _locationModeLabel,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'الساعات الفلكية',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlanetaryHoursPage(
                    coordinates: _locationResult?.coordinates,
                    locationLabel: _locationModeLabel,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDate,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Header Section
            _buildHeaderCard(),
            
            const SizedBox(height: 16),
            
            // Alert Section (Conditional)
            if (isNehusDay)
              _buildAlertCard(
                title: nehusTitleToday ?? 'تحذير: يوم نحس',
                details: nehusDetailsToday,
              ),
            if (isNehusDay) const SizedBox(height: 16),

            // Weekday Property Section
            if (!isNehusDay)
              _buildInfoCard(
                title: 'حكمة يوم الأسبوع ($effectiveWeekdayNameArabic)',
                content: weekProperty,
                icon: Icons.calendar_view_week,
                color: Theme.of(context).colorScheme.primaryContainer,
                onColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),

            // Hijri Property Section
            _buildInfoCard(
              title: 'نظرة اليوم الهجري (يوم ${effectiveHijriDate.hDay})',
              content: hijriInfo,
              icon: Icons.nights_stay,
              color: Theme.of(context).colorScheme.secondaryContainer,
              onColor: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            
            const SizedBox(height: 24),
            
            // Future Preview Section
            Text(
              'توقعات الأسبوع القادم',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildUpcomingForecast(effectiveIslamicDate),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingForecast(DateTime baseDate) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        // Calculate date for this item (starting from tomorrow: index + 1)
        final date = baseDate.add(Duration(days: index + 1));
        final fatimid = FatimidCalendar.fromGregorian(date);
        final weekday = DateFormat('EEEE', 'ar').format(date); // Full name e.g. Monday
        final weekdayEn = DateFormat('EEEE', 'en').format(date); // English for lookup
        final color = HijriData.getDayColor(fatimid.hMonth, fatimid.hDay);
        
        // Get property text
        final hijriDescription = HijriData.monthlyDescriptions[fatimid.hDay] ?? 'لا توجد بيانات';
        final weekProperty = WeekData.getProperty(weekdayEn);

        final isNehus = HijriData.hasAnyNehus(fatimid.hMonth, fatimid.hDay);
        final nehusTitle = HijriData.getDominantNehusTitle(fatimid.hMonth, fatimid.hDay);
        final categoryLabel = HijriData.getDayCategoryLabel(fatimid.hMonth, fatimid.hDay);

        return Card(
          elevation: 0,
          color: color.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date & Status Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weekday,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fatimid.hDay} ${fatimid.toFormat("MMMM")}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.circle, color: color, size: 16),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Description Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNehus)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                nehusTitle ?? 'تحذير: يوم نحس',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Weekday Property (e.g., Cupping, Building) - Only show if NOT Nehus
                      if (!isNehus)
                        Text(
                          weekProperty,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      if (!isNehus && categoryLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            categoryLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      if (!isNehus) const SizedBox(height: 4),
                      // Hijri Description
                      Text(
                        hijriDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard() {
    final now = DateTime.now();
    final currentHour = _getCurrentPlanetaryHour(now);
    final timeFormatter = DateFormat('h:mm a', 'ar');
    final currentHourDescription = currentHour == null
        ? null
        : PlanetaryEngine.getHourDescription(
            currentHour.dayOfWeek,
            currentHour.isDay,
            currentHour.hourIndex,
          );

    final Duration? total = currentHour?.endTime.difference(currentHour.startTime);
    final Duration? elapsed = currentHour == null ? null : now.difference(currentHour.startTime);
    final Duration? remaining = currentHour?.endTime.difference(now);
    final Duration? elapsedSafe = elapsed == null
        ? null
        : (elapsed.isNegative ? Duration.zero : elapsed);
    final double? progress = (currentHour == null || total == null || total.inMilliseconds <= 0)
        ? null
        : (elapsedSafe!.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final Duration? remainingSafe = remaining == null
        ? null
        : (remaining.isNegative ? Duration.zero : remaining);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setUiTickerEnabled(currentHour != null);
    });

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "$_weekdayNameArabic, ${_hijriDate.toFormat("dd MMMM yyyy")}", // Fatimid Date String
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('d MMMM yyyy', 'ar').format(_gregorianDate),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'الموقع: $_locationModeLabel',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (currentHour != null) const SizedBox(height: 12),
            if (currentHour != null)
              Text(
                'الساعة الفلكية ${_arabicOrdinalHour(currentHour.hourIndex)} (${_planetNameArabic(currentHour.planetName)})',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
            if (currentHour != null) const SizedBox(height: 4),
            if (currentHour != null)
              Text(
                'تبدأ من ${timeFormatter.format(currentHour.startTime)} وتنتهي إلى ${timeFormatter.format(currentHour.endTime)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            if (currentHour != null) const SizedBox(height: 12),
            if (currentHour != null && progress != null)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المنصرف ${_formatDuration(elapsedSafe!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        'المتبقي ${_formatDuration(remainingSafe!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            if (currentHourDescription != null) const SizedBox(height: 8),
            if (currentHourDescription != null)
              Text(
                currentHourDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
            if (currentHour != null) const SizedBox(height: 12),
            if (currentHour != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlanetaryHourCountdownPage(
                          coordinates: _locationResult?.coordinates,
                          locationLabel: _locationModeLabel,
                        ),
                      ),
                    );
                  },
                  child: const Text('عرض المتبقي من الساعات الفلكية'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours س $minutes د';
    }
    return '$minutes د';
  }

  Widget _buildAlertCard({required String title, required String details}) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required Color onColor,
  }) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: onColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: onColor,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
