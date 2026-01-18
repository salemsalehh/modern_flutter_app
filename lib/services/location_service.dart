import 'package:geolocator/geolocator.dart';
import 'package:adhan/adhan.dart';
import 'package:modern_flutter_app/services/location_prefs.dart';

class LocationResult {
  final Coordinates coordinates;
  final bool usedDefault;
  final String? message;

  const LocationResult({
    required this.coordinates,
    required this.usedDefault,
    this.message,
  });
}

class LocationService {
  // Najran Coordinates
  static const double defaultLatitude = 17.565;
  static const double defaultLongitude = 44.228;

  Future<Coordinates> getCurrentLocation() async {
    final result = await getCurrentLocationResult();
    return result.coordinates;
  }

  LocationResult getDefaultLocationResult() {
    return LocationResult(
      coordinates: Coordinates(defaultLatitude, defaultLongitude),
      usedDefault: true,
      message: 'تم استخدام موقع نجران الافتراضي.',
    );
  }

  Future<LocationResult> getLocationResult({required bool useGps}) async {
    return getLocationResultByMode(
      mode: useGps ? LocationMode.gps : LocationMode.defaultLocation,
      customCoordinates: null,
    );
  }

  Future<LocationResult> getLocationResultByMode({
    required LocationMode mode,
    required Coordinates? customCoordinates,
  }) async {
    if (mode == LocationMode.custom && customCoordinates != null) {
      return LocationResult(
        coordinates: customCoordinates,
        usedDefault: false,
      );
    }

    if (mode == LocationMode.gps) {
      return getCurrentLocationResult();
    }

    return getDefaultLocationResult();
  }

  Future<LocationResult> getCurrentLocationResult() async {
    LocationPermission permission;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult(
        coordinates: Coordinates(defaultLatitude, defaultLongitude),
        usedDefault: true,
        message: 'خدمات الموقع غير مفعّلة، تم استخدام موقع نجران الافتراضي.',
      );
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult(
          coordinates: Coordinates(defaultLatitude, defaultLongitude),
          usedDefault: true,
          message: 'تم رفض صلاحية الموقع، تم استخدام موقع نجران الافتراضي.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationResult(
        coordinates: Coordinates(defaultLatitude, defaultLongitude),
        usedDefault: true,
        message: 'صلاحية الموقع مرفوضة نهائيًا، تم استخدام موقع نجران الافتراضي.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition().timeout(
            const Duration(seconds: 10),
          );
      return LocationResult(
        coordinates: Coordinates(position.latitude, position.longitude),
        usedDefault: false,
      );
    } catch (e) {
      return LocationResult(
        coordinates: Coordinates(defaultLatitude, defaultLongitude),
        usedDefault: true,
        message: 'تعذّر تحديد الموقع عبر GPS، تم استخدام موقع نجران الافتراضي.',
      );
    }
  }
}
