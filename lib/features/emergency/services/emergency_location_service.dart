import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../data/emergency_record.dart';

class EmergencyLocationResult {
  const EmergencyLocationResult({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.timestamp,
    this.address,
    required this.source,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? timestamp;
  final String? address;

  final EmergencyLocationSource source;

  bool get hasLocation =>
      latitude != null &&
          longitude != null;
}

class EmergencyLocationService {
  final Geocoding _geocoding = Geocoding();

  Future<EmergencyLocationResult>
  getCurrentLocation() async {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return const EmergencyLocationResult(
        source: EmergencyLocationSource.unavailable,
      );
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return _getLastKnownLocation();
    }

    try {
      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit:
          Duration(seconds: 10),
        ),
      );

      final address =
      await _getAddress(
        position.latitude,
        position.longitude,
      );

      return EmergencyLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
        address: address,
        source: EmergencyLocationSource.current,
      );
    } catch (_) {
      return _getLastKnownLocation();
    }
  }

  Future<EmergencyLocationResult>
  _getLastKnownLocation() async {
    try {
      final position =
      await Geolocator.getLastKnownPosition();

      if (position == null) {
        return const EmergencyLocationResult(
          source:
          EmergencyLocationSource.unavailable,
        );
      }

      final address =
      await _getAddress(
        position.latitude,
        position.longitude,
      );

      return EmergencyLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
        address: address,
        source:
        EmergencyLocationSource.lastKnown,
      );
    } catch (_) {
      return const EmergencyLocationResult(
        source:
        EmergencyLocationSource.unavailable,
      );
    }
  }

  Future<String?> _getAddress(
      double latitude,
      double longitude,
      ) async {
    try {
      final placemarks =
      await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return null;
      }

      final place = placemarks.first;

      final parts = <String>[
        if ((place.street ?? '').trim().isNotEmpty)
          place.street!.trim(),

        if ((place.subLocality ?? '').trim().isNotEmpty)
          place.subLocality!.trim(),

        if ((place.locality ?? '').trim().isNotEmpty)
          place.locality!.trim(),

        if ((place.administrativeArea ?? '')
            .trim()
            .isNotEmpty)
          place.administrativeArea!.trim(),
      ];

      if (parts.isEmpty) {
        return null;
      }

      return parts.join(', ');
    } catch (_) {
      // GPS coordinates remain usable even when
      // reverse geocoding fails.
      return null;
    }
  }
}