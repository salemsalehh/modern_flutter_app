import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum LocationMode {
  defaultLocation,
  gps,
  custom,
}

class SavedLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  static SavedLocation fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LocationPrefs {
  static const String _prefUseGpsKey = 'use_gps_location';
  static const String _prefLocationModeKey = 'location_mode';
  static const String _prefSavedLocationsKey = 'saved_locations';
  static const String _prefSelectedLocationIdKey = 'selected_location_id';

  static String _modeToString(LocationMode mode) {
    switch (mode) {
      case LocationMode.defaultLocation:
        return 'default';
      case LocationMode.gps:
        return 'gps';
      case LocationMode.custom:
        return 'custom';
    }
  }

  static LocationMode _modeFromString(String? value) {
    switch (value) {
      case 'gps':
        return LocationMode.gps;
      case 'custom':
        return LocationMode.custom;
      case 'default':
      default:
        return LocationMode.defaultLocation;
    }
  }

  static Future<LocationMode> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_prefLocationModeKey);
    if (modeStr != null) {
      return _modeFromString(modeStr);
    }

    final legacyUseGps = prefs.getBool(_prefUseGpsKey) ?? false;
    return legacyUseGps ? LocationMode.gps : LocationMode.defaultLocation;
  }

  static Future<void> setMode(LocationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLocationModeKey, _modeToString(mode));
    await prefs.setBool(_prefUseGpsKey, mode == LocationMode.gps);
  }

  static Future<List<SavedLocation>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefSavedLocationsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => SavedLocation.fromJson(Map<String, dynamic>.from(m)))
          .where((l) => l.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _setSavedLocations(List<SavedLocation> locations) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(locations.map((l) => l.toJson()).toList());
    await prefs.setString(_prefSavedLocationsKey, encoded);
  }

  static Future<String?> getSelectedLocationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSelectedLocationIdKey);
  }

  static Future<void> setSelectedLocationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.trim().isEmpty) {
      await prefs.remove(_prefSelectedLocationIdKey);
      return;
    }
    await prefs.setString(_prefSelectedLocationIdKey, id);
  }

  static Future<SavedLocation?> getSelectedLocation() async {
    final id = await getSelectedLocationId();
    if (id == null || id.trim().isEmpty) return null;

    final locations = await getSavedLocations();
    for (final l in locations) {
      if (l.id == id) return l;
    }

    return null;
  }

  static Future<void> upsertLocation(SavedLocation location) async {
    final locations = await getSavedLocations();
    final idx = locations.indexWhere((l) => l.id == location.id);
    if (idx >= 0) {
      locations[idx] = location;
    } else {
      locations.add(location);
    }
    await _setSavedLocations(locations);
  }

  static Future<void> deleteLocation(String id) async {
    final locations = await getSavedLocations();
    final filtered = locations.where((l) => l.id != id).toList();
    await _setSavedLocations(filtered);

    final selected = await getSelectedLocationId();
    if (selected == id) {
      await setSelectedLocationId(null);
    }
  }
}
