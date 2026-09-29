import 'package:geolocator/geolocator.dart';

enum LocationIssue { serviceDisabled, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.issue, this.message);

  final LocationIssue issue;
  final String message;

  bool get canOpenSettings =>
      issue == LocationIssue.serviceDisabled ||
      issue == LocationIssue.deniedForever;

  @override
  String toString() => message;
}

class UserLocation {
  const UserLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  Future<UserLocation> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw const LocationException(
        LocationIssue.serviceDisabled,
        'Location (GPS) is turned off. Please turn it on and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        LocationIssue.denied,
        'Location permission was denied. "Near me" needs it to find '
        'events close to you.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationIssue.deniedForever,
        'Location permission is blocked. Please allow it from the app '
        'settings to use "Near me".',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      final last = await _lastKnown();
      if (last != null) return last;
      throw const LocationException(
        LocationIssue.unavailable,
        'Could not get your location right now. Please check GPS and '
        'try again.',
      );
    }
  }

  Future<UserLocation?> _lastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> openSettingsFor(LocationIssue issue) async {
    try {
      if (issue == LocationIssue.serviceDisabled) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {}
  }

  double distanceKm(UserLocation from, double latitude, double longitude) {
    final meters = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      latitude,
      longitude,
    );
    return meters / 1000;
  }

  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    if (km < 10) return '${km.toStringAsFixed(1)} km away';
    return '${km.round()} km away';
  }
}
