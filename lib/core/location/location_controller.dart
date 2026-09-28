import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationController extends ChangeNotifier {
  LocationController();

  Position? _position;
  String? _address;

  bool _isLoading = false;
  String? _error;

  LocationPermission _permission =
      LocationPermission.denied;

  LocationAccuracyStatus _accuracyStatus =
      LocationAccuracyStatus.reduced;

  Position? get position => _position;

  String? get address => _address;

  bool get isLoading => _isLoading;

  String? get error => _error;

  LocationPermission get permission => _permission;

  LocationAccuracyStatus get accuracyStatus =>
      _accuracyStatus;

  bool get hasLocation => _position != null;

  bool get hasPreciseLocation =>
      _accuracyStatus == LocationAccuracyStatus.precise;

  double? get latitude => _position?.latitude;

  double? get longitude => _position?.longitude;

  double? get accuracy => _position?.accuracy;

  String get accuracyText {
    final value = accuracy;

    if (value == null) {
      return 'Unknown';
    }

    return '${value.toStringAsFixed(1)} m';
  }

  Future<void> initialize() async {
    await getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const LocationException(
          'Location services are turned off.',
        );
      }

      _permission =
      await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        _permission =
        await Geolocator.requestPermission();
      }

      if (_permission == LocationPermission.denied) {
        throw const LocationException(
          'Location permission was denied.',
        );
      }

      if (_permission ==
          LocationPermission.deniedForever) {
        throw const LocationException(
          'Location permission is permanently denied.',
        );
      }

      _accuracyStatus =
      await Geolocator.getLocationAccuracy();

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      );

      _position = position;

      await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
    } on LocationException catch (e) {
      _error = e.message;
    } catch (e) {
      _error =
      'Unable to determine your current location: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reverseGeocode(
      double latitude,
      double longitude,
      ) async {
    try {
      final geocoding = Geocoding();

      final placemarks =
      await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        _address = 'Address unavailable';
        return;
      }

      final place = placemarks.first;

      final parts = <String>[];

      void addPart(String? value) {
        final cleaned = value?.trim();

        if (cleaned != null &&
            cleaned.isNotEmpty &&
            !parts.contains(cleaned)) {
          parts.add(cleaned);
        }
      }

      addPart(place.name);
      addPart(place.street);
      addPart(place.locality);
      addPart(place.subAdministrativeArea);
      addPart(place.administrativeArea);
      addPart(place.country);

      _address = parts.isEmpty
          ? 'Address unavailable'
          : parts.join(', ');
    } catch (_) {
      _address = 'Address unavailable';
    }
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}