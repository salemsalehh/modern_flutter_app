import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:modern_flutter_app/data/hijri_data.dart';
import 'package:modern_flutter_app/logic/fatimid_calendar.dart';
import 'package:modern_flutter_app/logic/planetary_engine.dart';
import 'package:modern_flutter_app/services/location_service.dart';
import 'package:modern_flutter_app/widgets/fatimid_grid_date_picker.dart';

class PlanetarySearchPage extends StatefulWidget {
  final Coordinates? coordinates;
  final String locationLabel;

  const PlanetarySearchPage({
    super.key,
    required this.coordinates,
    required this.locationLabel,
  });

  @override
  State<PlanetarySearchPage> createState() => _PlanetarySearchPageState();
}

class _SearchMatch {
  final DateTime islamicCivilDate;
  final PlanetaryHour hour;
  final String description;

  const _SearchMatch({
    required this.islamicCivilDate,
    required this.hour,
    required this.description,
  });
}

class _PlanetarySearchPageState extends State<PlanetarySearchPage> {
  final _queryController = TextEditingController();

  late DateTimeRange _range;
  bool _isSearching = false;
  String? _error;
  List<_SearchMatch> _matches = const [];

  static const Map<String, List<String>> _synonyms = {
    'زواج': ['زواج', 'تزويج', 'تزوج', 'نكاح', 'عرس', 'العرس', 'الزواج'],
    'سفر': ['سفر', 'السفر', 'رحلة', 'الرحلة', 'ترحال', 'الترحال', 'ارتحال', 'الارتحال'],
    'شرب الدواء': [
      'شرب الدواء',
      'شرب دواء',
      'تناول الدواء',
      'تناول دواء',
      'دواء',
      'الدواء',
      'تداوي',
      'التداوي',
      'علاج',
      'العلاج',
    ],
    'الجماع': ['الجماع', 'مجامعة', 'الوطء', 'وطء'],
    'قضاء الحوائج': ['قضاء الحوائج', 'قضاء الحاجات', 'قضاء الحاجة', 'حوائج', 'حاجات'],
    'البيع': ['البيع', 'بيع', 'مبايعة', 'مبايعه', 'تجارة', 'التجاره', 'متاجرة', 'متاجره'],
    'الشراء': ['الشراء', 'شراء', 'اقتناء', 'ابتياع', 'اشتراء'],
    'بناء': ['بناء', 'البناء', 'عماره', 'العماره', 'تعمير', 'التعمير', 'تشيد', 'التشيد', 'انشاء', 'الانشاء'],
    'الأعمال': [
      'الاعمال',
      'العمل',
      'عمل',
      'اعمال',
      'شغل',
      'اشغال',
      'الصناعه',
      'صناعه',
      'حرفه',
      'الوظيفه',
      'وظيفه',
      'كسب',
      'رزق',
    ],
    'غرس الشجر': [
      'غرس',
      'الغرس',
      'غرس الشجر',
      'غرس شجر',
      'غرس الاشجار',
      'غرس الاشجار',
      'زرع',
      'الزرع',
      'زراعه',
      'الزراعه',
      'الشجر',
      'الاشجار',
    ],
    'الملوك والأمراء': [
      'ملك',
      'الملك',
      'ملوك',
      'الملوك',
      'امير',
      'الامير',
      'امراء',
      'الامراء',
      'عظيم',
      'العظماء',
      'عظماء',
      'سلطان',
      'السلاطين',
      'رؤساء',
      'الرؤساء',
      'كبار',
      'الكبراء',
    ],
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final effective = _getEffectiveIslamicGregorianDate(now);
    final start = effective.subtract(const Duration(days: 14));
    _range = DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(effective.year, effective.month, effective.day),
    );
  }

  Widget _buildNehusBanner(FatimidCalendar hijri) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = HijriData.getDominantNehusTitle(hijri.hMonth, hijri.hDay) ?? 'تنبيه: يوم نحس';
    final isYearly = HijriData.isYearlyNehus(hijri.hMonth, hijri.hDay);
    final isMonthly = HijriData.isMonthlyNehus(hijri.hDay);
    final details = HijriData.getNehusMessages(hijri.hMonth, hijri.hDay).join('\n');
    final dayInfo = HijriData.monthlyDescriptions[hijri.hDay] ?? 'لا توجد بيانات لهذا اليوم';

    return Card(
      elevation: 0,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ملاحظة: إذا وافق هذا اليوم نحساً (يومي/شهري/سنوي)، فقد يكون تأثيره أقوى من صلاحية بعض الساعات.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onErrorContainer, height: 1.4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isMonthly)
                  Chip(
                    label: const Text('نحس الشهر'),
                    labelStyle:
                        Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onErrorContainer),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: colorScheme.onErrorContainer.withOpacity(0.25)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (isYearly)
                  Chip(
                    label: const Text('نحس السنة'),
                    labelStyle:
                        Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onErrorContainer),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(color: colorScheme.onErrorContainer.withOpacity(0.25)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                details,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colorScheme.onErrorContainer, height: 1.5),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'وصف هذا اليوم: $dayInfo',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onErrorContainer, height: 1.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  DateTime _getEffectiveIslamicGregorianDate(DateTime now) {
    final dateOnly = DateTime(now.year, now.month, now.day);
    final coordinates = widget.coordinates ??
        Coordinates(LocationService.defaultLatitude, LocationService.defaultLongitude);
    final params = CalculationMethod.umm_al_qura.getParameters();
    final prayerTimes = PrayerTimes(coordinates, DateComponents.from(dateOnly), params);
    final maghrib = prayerTimes.maghrib;

    if (!now.isBefore(maghrib)) {
      return dateOnly.add(const Duration(days: 1));
    }

    return dateOnly;
  }

  String _normalizeArabic(String input) {
    final lowered = input.toLowerCase();
    final withoutTashkeel = lowered.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
    final normalized = withoutTashkeel
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    return normalized.trim();
  }

  List<String> _expandQueryToTerms(String rawQuery) {
    final q = _normalizeArabic(rawQuery);
    if (q.isEmpty) return const [];

    // Direct hit on a preset key
    for (final entry in _synonyms.entries) {
      final keyNorm = _normalizeArabic(entry.key);
      if (q == keyNorm) {
        return entry.value.map(_normalizeArabic).toSet().toList();
      }
    }

    // Reverse hit on any synonym term
    for (final entry in _synonyms.entries) {
      for (final term in entry.value) {
        if (q == _normalizeArabic(term)) {
          return entry.value.map(_normalizeArabic).toSet().toList();
        }
      }
    }

    // If user entered multiple keywords separated by common delimiters, treat as OR.
    final parts = rawQuery
        .split(RegExp(r'[\n,،;؛\|]+'))
        .map(_normalizeArabic)
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length > 1) return parts.toSet().toList();

    return [q];
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

  ({List<PlanetaryHour> night, List<PlanetaryHour> day}) _getIslamicDayHours(DateTime date) {
    final prev = date.subtract(const Duration(days: 1));

    final prevHours = PlanetaryEngine.getPlanetaryHours(prev, userCoordinates: widget.coordinates);
    final nightHours = prevHours.where((h) => !h.isDay && h.dayOfWeek == date.weekday).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final todayHours = PlanetaryEngine.getPlanetaryHours(date, userCoordinates: widget.coordinates);
    final dayHours = todayHours.where((h) => h.isDay).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return (night: nightHours, day: dayHours);
  }

  Future<void> _pickRange() async {
    DateTimeRange? picked;
    try {
      picked = await showModalBottomSheet<DateTimeRange>(
        context: context,
        useRootNavigator: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) {
          var tempStart = _range.start;
          var tempEnd = _range.end;
          var editingStart = true;

          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

                final startGreg = DateFormat('d MMMM yyyy', 'ar').format(tempStart);
                final endGreg = DateFormat('d MMMM yyyy', 'ar').format(tempEnd);

                String startHijriText;
                String endHijriText;
                try {
                  startHijriText = FatimidCalendar.fromGregorian(tempStart).toFormat('dd MMMM yyyy');
                } catch (_) {
                  startHijriText = '';
                }
                try {
                  endHijriText = FatimidCalendar.fromGregorian(tempEnd).toFormat('dd MMMM yyyy');
                } catch (_) {
                  endHijriText = '';
                }

                final activeDate = editingStart ? tempStart : tempEnd;
                String activeHijri;
                try {
                  activeHijri = FatimidCalendar.fromGregorian(activeDate).toFormat('dd MMMM yyyy');
                } catch (_) {
                  activeHijri = '';
                }
                final activeGreg = DateFormat('d MMMM yyyy', 'ar').format(activeDate);

                final summary = startHijriText.isEmpty || endHijriText.isEmpty
                    ? 'من: $startGreg\nإلى: $endGreg'
                    : 'من: $startHijriText ($startGreg)\nإلى: $endHijriText ($endGreg)';

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final rawMaxH = constraints.maxHeight;
                    final maxH = rawMaxH.isFinite ? rawMaxH : MediaQuery.of(context).size.height;
                    final height = (maxH * 0.9).clamp(420.0, maxH);

                    return SizedBox(
                      height: height,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                ),
                                const Expanded(
                                  child: Text(
                                    'اختيار النطاق',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      DateTimeRange(
                                        start: normalize(tempStart),
                                        end: normalize(tempEnd),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.check),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('من'),
                                    selected: editingStart,
                                    onSelected: (_) {
                                      setLocalState(() {
                                        editingStart = true;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('إلى'),
                                    selected: !editingStart,
                                    onSelected: (_) {
                                      setLocalState(() {
                                        editingStart = false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              editingStart ? 'بداية النطاق' : 'نهاية النطاق',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              activeHijri.isEmpty ? activeGreg : '$activeHijri\n$activeGreg',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: FatimidGridDatePicker(
                                selectedDate: activeDate,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                                onChanged: (d) {
                                  setLocalState(() {
                                    final nd = normalize(d);
                                    if (editingStart) {
                                      tempStart = nd;
                                      if (tempStart.isAfter(tempEnd)) {
                                        tempEnd = tempStart;
                                      }
                                    } else {
                                      tempEnd = nd;
                                      if (tempEnd.isBefore(tempStart)) {
                                        tempStart = tempEnd;
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                summary,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(
                                    context,
                                    DateTimeRange(
                                      start: normalize(tempStart),
                                      end: normalize(tempEnd),
                                    ),
                                  );
                                },
                                child: const Text('حفظ'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ).onError((_, __) => null);
    } catch (_) {
      if (!mounted) return;
      picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000, 1, 1),
        lastDate: DateTime(2100, 12, 31),
        initialDateRange: _range,
        locale: const Locale('ar', 'SA'),
      );
    }

    if (!mounted) return;
    picked ??= await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _range,
      locale: const Locale('ar', 'SA'),
    );

    if (!mounted || picked == null) return;
    final pickedRange = picked;

    setState(() {
      _range = DateTimeRange(
        start: DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day),
        end: DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day),
      );
    });
  }

  Future<void> _search() async {
    final terms = _expandQueryToTerms(_queryController.text);
    if (terms.isEmpty) {
      setState(() {
        _error = 'اكتب كلمة البحث أولاً.';
        _matches = const [];
      });
      return;
    }

    final totalDays = _range.end.difference(_range.start).inDays + 1;
    if (totalDays > 366) {
      setState(() {
        _error = 'نطاق البحث كبير جداً. اختر مدة أقل (حتى 366 يوم).';
        _matches = const [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
      _matches = const [];
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 16));

      final List<_SearchMatch> matches = [];
      final normalizedTerms = terms.map(_normalizeArabic).toSet().toList();

      for (int i = 0; i < totalDays; i++) {
        if (i % 7 == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        final date = _range.start.add(Duration(days: i));
        final hours = _getIslamicDayHours(date);
        final all = [...hours.night, ...hours.day];

        for (final hour in all) {
          final desc = PlanetaryEngine.getHourDescription(hour.dayOfWeek, hour.isDay, hour.hourIndex);
          final normalizedDesc = _normalizeArabic(desc);
          final hasMatch = normalizedTerms.any((t) => t.isNotEmpty && normalizedDesc.contains(t));
          if (hasMatch) {
            matches.add(_SearchMatch(islamicCivilDate: date, hour: hour, description: desc));
          }
        }
      }

      matches.sort((a, b) {
        final d = a.islamicCivilDate.compareTo(b.islamicCivilDate);
        if (d != 0) return d;
        return a.hour.startTime.compareTo(b.hour.startTime);
      });

      if (!mounted) return;
      setState(() {
        _matches = matches;
        if (matches.isEmpty) {
          _error = 'لا توجد نتائج ضمن هذا النطاق.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'حدث خطأ أثناء البحث. حاول مرة أخرى.';
        _matches = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  String _rangeLabel() {
    final gregFmt = DateFormat('d MMM yyyy', 'ar');
    final hijriStart = FatimidCalendar.fromGregorian(_range.start);
    final hijriEnd = FatimidCalendar.fromGregorian(_range.end);

    final hijriText = '${hijriStart.toFormat("dd MMMM yyyy")} - ${hijriEnd.toFormat("dd MMMM yyyy")}';
    final gregText = '${gregFmt.format(_range.start)} - ${gregFmt.format(_range.end)}';

    return '$hijriText\n$gregText';
  }

  Widget _buildQuickChip(String text) {
    return ActionChip(
      label: Text(text),
      onPressed: () {
        _queryController.text = text;
        _search();
      },
    );
  }

  Widget _buildMatchTile(_SearchMatch match) {
    final timeFormatter = DateFormat('HH:mm', 'ar');
    final hour = match.hour;
    final title =
        'الساعة ${_arabicOrdinalHour(hour.hourIndex)} (${_planetNameArabic(hour.planetName)})';
    final range =
        'من ${timeFormatter.format(hour.startTime)} إلى ${timeFormatter.format(hour.endTime)}';

    final isDay = hour.isDay;
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = isDay ? colorScheme.surface : colorScheme.secondaryContainer;
    final onBaseColor = isDay ? colorScheme.onSurface : colorScheme.onSecondaryContainer;
    final icon = isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round;

    return Card(
      elevation: 0,
      color: baseColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: onBaseColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onBaseColor,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              range,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: onBaseColor.withOpacity(0.85)),
            ),
            const SizedBox(height: 10),
            Text(
              match.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6, color: onBaseColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gregFmt = DateFormat('d MMMM yyyy', 'ar');
    final hijriStart = FatimidCalendar.fromGregorian(_range.start);
    final hijriEnd = FatimidCalendar.fromGregorian(_range.end);
    final headerHijri = '${hijriStart.toFormat("dd MMMM yyyy")} - ${hijriEnd.toFormat("dd MMMM yyyy")}';
    final headerGreg = '${gregFmt.format(_range.start)} - ${gregFmt.format(_range.end)}';

    final Map<String, List<_SearchMatch>> grouped = {};
    for (final m in _matches) {
      final key = DateFormat('yyyy-MM-dd').format(m.islamicCivilDate);
      grouped.putIfAbsent(key, () => []).add(m);
    }

    final keys = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث الساعات الفلكية'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموقع: ${widget.locationLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نطاق البحث',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$headerHijri\n$headerGreg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _queryController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'اكتب كلمة مثل: زواج، سفر، دواء...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickChip('زواج'),
                        _buildQuickChip('سفر'),
                        _buildQuickChip('شرب الدواء'),
                        _buildQuickChip('الجماع'),
                        _buildQuickChip('قضاء الحوائج'),
                        _buildQuickChip('البيع'),
                        _buildQuickChip('الشراء'),
                        _buildQuickChip('بناء'),
                        _buildQuickChip('الأعمال'),
                        _buildQuickChip('غرس الشجر'),
                        _buildQuickChip('الملوك والأمراء'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _rangeLabel(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isSearching ? null : _search,
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.manage_search),
                          label: Text(_isSearching ? 'جاري البحث' : 'بحث'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
            if (_matches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'عدد النتائج: ${_matches.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            for (final k in keys) ...[
              Builder(
                builder: (context) {
                  final date = DateTime.parse('${k}T00:00:00');
                  final weekdayText = DateFormat('EEEE', 'ar').format(date);
                  final gregorianText = DateFormat('d MMMM yyyy', 'ar').format(date);
                  final hijri = FatimidCalendar.fromGregorian(date);
                  final bool isNehusDay = HijriData.hasAnyNehus(hijri.hMonth, hijri.hDay);

                  return Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$weekdayText، ${hijri.toFormat("dd MMMM yyyy")} - $gregorianText',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (isNehusDay) ...[
                          const SizedBox(height: 8),
                          _buildNehusBanner(hijri),
                        ],
                      ],
                    ),
                  );
                },
              ),
              ...grouped[k]!.map(_buildMatchTile),
            ],
              ],
            ),
            if (_isSearching)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.15),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
