import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:modern_flutter_app/data/hijri_data.dart';
import 'package:modern_flutter_app/logic/fatimid_calendar.dart';
import 'package:modern_flutter_app/logic/planetary_engine.dart';
import 'package:modern_flutter_app/pages/planetary_search_page.dart';
import 'package:modern_flutter_app/services/location_service.dart';
import 'package:modern_flutter_app/widgets/fatimid_grid_date_picker.dart';

class PlanetaryHoursPage extends StatefulWidget {
  final Coordinates? coordinates;
  final String locationLabel;

  const PlanetaryHoursPage({
    super.key,
    required this.coordinates,
    required this.locationLabel,
  });

  @override
  State<PlanetaryHoursPage> createState() => _PlanetaryHoursPageState();
}

class _PlanetaryHoursPageState extends State<PlanetaryHoursPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = _getEffectiveIslamicGregorianDate(now);
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

  Future<void> _pickDate() async {
    DateTime? picked;
    try {
      picked = await showModalBottomSheet<DateTime>(
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
          var temp = _selectedDate;

          return Material(
            color: Theme.of(context).colorScheme.surface,
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                final weekdayText = DateFormat('EEEE', 'ar').format(temp);
                final gregText = DateFormat('d MMMM yyyy', 'ar').format(temp);

                String hijriText;
                try {
                  hijriText = FatimidCalendar.fromGregorian(temp).toFormat('dd MMMM yyyy');
                } catch (_) {
                  hijriText = '';
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final rawMaxH = constraints.maxHeight;
                    final maxH = rawMaxH.isFinite ? rawMaxH : MediaQuery.of(context).size.height;
                    final height = (maxH * 0.85).clamp(320.0, maxH);

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
                                    'اختيار التاريخ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context, temp),
                                  icon: const Icon(Icons.check),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              hijriText.isEmpty ? weekdayText : '$weekdayText، $hijriText',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              gregText,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: FatimidGridDatePicker(
                                selectedDate: temp,
                                firstDate: DateTime(2000, 1, 1),
                                lastDate: DateTime(2100, 12, 31),
                                onChanged: (d) {
                                  setLocalState(() {
                                    temp = DateTime(d.year, d.month, d.day);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context, temp),
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
      picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000, 1, 1),
        lastDate: DateTime(2100, 12, 31),
        locale: const Locale('ar', 'SA'),
      );
    }

    if (!mounted) return;
    picked ??= await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      locale: const Locale('ar', 'SA'),
    );

    if (!mounted || picked == null) return;
    final pickedDate = picked;

    setState(() {
      _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    });
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

  Widget _buildHourTile(PlanetaryHour hour, {required bool isCurrent}) {
    final timeFormatter = DateFormat('HH:mm', 'ar');
    final title = 'الساعة الفلكية ${_arabicOrdinalHour(hour.hourIndex)} (${_planetNameArabic(hour.planetName)})';
    final range = 'من ${timeFormatter.format(hour.startTime)} إلى ${timeFormatter.format(hour.endTime)}';
    final description = PlanetaryEngine.getHourDescription(hour.dayOfWeek, hour.isDay, hour.hourIndex);

    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = hour.isDay ? colorScheme.surface : colorScheme.secondaryContainer;
    final onBaseColor = hour.isDay ? colorScheme.onSurface : colorScheme.onSecondaryContainer;
    final leadingIcon = hour.isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round;
    final labelText = hour.isDay ? 'نهار' : 'ليل';

    final borderSide = isCurrent ? BorderSide(color: colorScheme.primary, width: 2) : BorderSide.none;

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
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: Icon(leadingIcon, color: onBaseColor),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onBaseColor,
                      ),
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
                  labelStyle:
                      Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onPrimary),
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
    final gregorianText = DateFormat('d MMMM yyyy', 'ar').format(_selectedDate);
    final weekdayText = DateFormat('EEEE', 'ar').format(_selectedDate);
    final hijri = FatimidCalendar.fromGregorian(_selectedDate);

    final bool isNehusDay = HijriData.hasAnyNehus(hijri.hMonth, hijri.hDay);

    final hours = _getIslamicDayHours(_selectedDate);
    final now = DateTime.now();
    final allHours = [...hours.night, ...hours.day];
    final currentHour = allHours.where((h) => !now.isBefore(h.startTime) && now.isBefore(h.endTime)).toList();
    final currentHourKey = currentHour.isEmpty
        ? null
        : '${currentHour.first.dayOfWeek}-${currentHour.first.isDay}-${currentHour.first.hourIndex}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('الساعات الفلكية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث الساعات الفلكية',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlanetarySearchPage(
                    coordinates: widget.coordinates,
                    locationLabel: widget.locationLabel,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'اختيار يوم',
            onPressed: _pickDate,
          ),
        ],
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
                      '$weekdayText، ${hijri.toFormat("dd MMMM yyyy")}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      gregorianText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'الموقع: ${widget.locationLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Chip(
                          avatar: Icon(Icons.nightlight_round,
                              size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          label: const Text('12 ساعة ليلية'),
                          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.25),
                          ),
                        ),
                        Chip(
                          avatar: Icon(Icons.wb_sunny_outlined,
                              size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          label: const Text('12 ساعة نهارية'),
                          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.25),
                          ),
                        ),
                        Chip(
                          avatar: Icon(Icons.auto_awesome,
                              size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          label: const Text('اليوم الفلكي يبدأ من المغرب'),
                          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.25),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isNehusDay) _buildNehusBanner(hijri),
            if (isNehusDay) const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.nightlight_round, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'ساعات الليل',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hours.night.isEmpty)
              Text(
                'لا توجد بيانات لساعات الليل لهذا اليوم.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...hours.night.map(
                (h) => _buildHourTile(
                  h,
                  isCurrent:
                      currentHourKey == null ? false : '${h.dayOfWeek}-${h.isDay}-${h.hourIndex}' == currentHourKey,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'ساعات النهار',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hours.day.isEmpty)
              Text(
                'لا توجد بيانات لساعات النهار لهذا اليوم.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...hours.day.map(
                (h) => _buildHourTile(
                  h,
                  isCurrent:
                      currentHourKey == null ? false : '${h.dayOfWeek}-${h.isDay}-${h.hourIndex}' == currentHourKey,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDate,
        icon: const Icon(Icons.date_range),
        label: const Text('اختيار يوم'),
      ),
    );
  }
}
