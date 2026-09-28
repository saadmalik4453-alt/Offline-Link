import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.district,
    this.province,
    this.country,
  });

  final double latitude;
  final double longitude;

  final String? address;
  final String? city;
  final String? district;
  final String? province;
  final String? country;

  String get displayName {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (district != null &&
          district!.isNotEmpty &&
          district != city)
        district!,
      if (province != null && province!.isNotEmpty)
        province!,
      if (country != null && country!.isNotEmpty)
        country!,
    ];

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    return '${latitude.toStringAsFixed(5)}, '
        '${longitude.toStringAsFixed(5)}';
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'district': district,
      'province': province,
      'country': country,
    };
  }

  factory DeviceLocation.fromJson(
      Map<String, dynamic> json,
      ) {
    return DeviceLocation(
      latitude:
      (json['latitude'] as num).toDouble(),
      longitude:
      (json['longitude'] as num).toDouble(),
      address:
      json['address']?.toString(),
      city:
      json['city']?.toString(),
      district:
      json['district']?.toString(),
      province:
      json['province']?.toString(),
      country:
      json['country']?.toString(),
    );
  }
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.observedAt,
  });

  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final DateTime observedAt;

  String get condition {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';

      case 1:
      case 2:
      case 3:
        return 'Cloudy';

      case 45:
      case 48:
        return 'Fog';

      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return 'Drizzle';

      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'Rain';

      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snow';

      case 80:
      case 81:
      case 82:
        return 'Rain showers';

      case 85:
      case 86:
        return 'Snow showers';

      case 95:
        return 'Thunderstorm';

      case 96:
      case 99:
        return 'Thunderstorm with hail';

      default:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'apparentTemperature':
      apparentTemperature,
      'humidity': humidity,
      'precipitation': precipitation,
      'windSpeed': windSpeed,
      'weatherCode': weatherCode,
      'isDay': isDay,
      'observedAt':
      observedAt.toUtc().toIso8601String(),
    };
  }

  factory WeatherSnapshot.fromJson(
      Map<String, dynamic> json,
      ) {
    return WeatherSnapshot(
      temperature:
      (json['temperature'] as num)
          .toDouble(),
      apparentTemperature:
      (json['apparentTemperature'] as num)
          .toDouble(),
      humidity:
      (json['humidity'] as num)
          .toDouble(),
      precipitation:
      (json['precipitation'] as num)
          .toDouble(),
      windSpeed:
      (json['windSpeed'] as num)
          .toDouble(),
      weatherCode:
      (json['weatherCode'] as num)
          .toInt(),
      isDay:
      json['isDay'] == true,
      observedAt:
      DateTime.parse(
        json['observedAt'].toString(),
      ),
    );
  }
}

class NearbyPlace {
  const NearbyPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.phone,
    this.website,
    this.address,
  });

  final String id;
  final String name;
  final String category;

  final double latitude;
  final double longitude;

  final double distanceMeters;

  final String? phone;
  final String? website;
  final String? address;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }

    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'phone': phone,
      'website': website,
      'address': address,
    };
  }

  factory NearbyPlace.fromJson(
      Map<String, dynamic> json,
      ) {
    return NearbyPlace(
      id: json['id'].toString(),
      name: json['name'].toString(),
      category:
      json['category'].toString(),
      latitude:
      (json['latitude'] as num)
          .toDouble(),
      longitude:
      (json['longitude'] as num)
          .toDouble(),
      distanceMeters:
      (json['distanceMeters'] as num)
          .toDouble(),
      phone:
      json['phone']?.toString(),
      website:
      json['website']?.toString(),
      address:
      json['address']?.toString(),
    );
  }
}

class EarthquakeSnapshot {
  const EarthquakeSnapshot({
    required this.magnitude,
    required this.place,
    required this.occurredAt,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.url,
  });

  final double magnitude;
  final String place;
  final DateTime occurredAt;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? url;

  Map<String, dynamic> toJson() {
    return {
      'magnitude': magnitude,
      'place': place,
      'occurredAt':
      occurredAt.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'distanceKm': distanceKm,
      'url': url,
    };
  }

  factory EarthquakeSnapshot.fromJson(
      Map<String, dynamic> json,
      ) {
    return EarthquakeSnapshot(
      magnitude:
      (json['magnitude'] as num)
          .toDouble(),
      place:
      json['place'].toString(),
      occurredAt:
      DateTime.parse(
        json['occurredAt'].toString(),
      ),
      latitude:
      (json['latitude'] as num)
          .toDouble(),
      longitude:
      (json['longitude'] as num)
          .toDouble(),
      distanceKm:
      (json['distanceKm'] as num)
          .toDouble(),
      url:
      json['url']?.toString(),
    );
  }
}

class OfficialAlert {
  const OfficialAlert({
    required this.title,
    required this.url,
    required this.source,
  });

  final String title;
  final String url;
  final String source;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'source': source,
    };
  }

  factory OfficialAlert.fromJson(
      Map<String, dynamic> json,
      ) {
    return OfficialAlert(
      title: json['title'].toString(),
      url: json['url'].toString(),
      source: json['source'].toString(),
    );
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.number,
    required this.source,
    required this.sourceUrl,
  });

  final String name;
  final String number;
  final String source;
  final String sourceUrl;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'source': source,
      'sourceUrl': sourceUrl,
    };
  }

  factory EmergencyContact.fromJson(
      Map<String, dynamic> json,
      ) {
    return EmergencyContact(
      name: json['name'].toString(),
      number: json['number'].toString(),
      source: json['source'].toString(),
      sourceUrl: json['sourceUrl'].toString(),
    );
  }
}

class LiveEmergencySnapshot {
  const LiveEmergencySnapshot({
    required this.location,
    required this.weather,
    required this.nearbyPlaces,
    required this.earthquakes,
    required this.contacts,
    required this.alerts,
    required this.fetchedAt,
    required this.fromCache,
  });

  final DeviceLocation location;
  final WeatherSnapshot? weather;

  final List<NearbyPlace> nearbyPlaces;
  final List<EarthquakeSnapshot> earthquakes;

  final List<EmergencyContact> contacts;
  final List<OfficialAlert> alerts;

  final DateTime fetchedAt;
  final bool fromCache;

  Map<String, dynamic> toJson() {
    return {
      'location': location.toJson(),
      'weather': weather?.toJson(),
      'nearbyPlaces':
      nearbyPlaces
          .map((e) => e.toJson())
          .toList(),
      'earthquakes':
      earthquakes
          .map((e) => e.toJson())
          .toList(),
      'contacts':
      contacts
          .map((e) => e.toJson())
          .toList(),
      'alerts':
      alerts
          .map((e) => e.toJson())
          .toList(),
      'fetchedAt':
      fetchedAt.toUtc().toIso8601String(),
    };
  }

  factory LiveEmergencySnapshot.fromJson(
      Map<String, dynamic> json,
      ) {
    final location =
    DeviceLocation.fromJson(
      Map<String, dynamic>.from(
        json['location'] as Map,
      ),
    );

    final weatherJson = json['weather'];

    final nearbyJson =
    (json['nearbyPlaces'] as List? ?? []);

    final earthquakeJson =
    (json['earthquakes'] as List? ?? []);

    final contactsJson =
    (json['contacts'] as List? ?? []);

    final alertsJson =
    (json['alerts'] as List? ?? []);

    return LiveEmergencySnapshot(
      location: location,
      weather: weatherJson == null
          ? null
          : WeatherSnapshot.fromJson(
        Map<String, dynamic>.from(
          weatherJson as Map,
        ),
      ),
      nearbyPlaces:
      nearbyJson
          .map(
            (item) =>
            NearbyPlace.fromJson(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList(),
      earthquakes:
      earthquakeJson
          .map(
            (item) =>
            EarthquakeSnapshot.fromJson(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList(),
      contacts:
      contactsJson
          .map(
              (item) =>
              EmergencyContact.fromJson(
                Map<String, dynamic>.from(
                  item as Map,
                ),
              )
      )
          .toList(),
      alerts:
      alertsJson
          .map(
            (item) =>
            OfficialAlert.fromJson(
              Map<String, dynamic>.from(
                item as Map,
              ),
            ),
      )
          .toList(),
      fetchedAt:
      DateTime.parse(
        json['fetchedAt'].toString(),
      ),
      fromCache: true,
    );
  }
}

class DeviceLocationService {
  Future<DeviceLocation>
  getCurrentLocation() async {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationUnavailableException(
        'Location services are disabled. '
            'Turn on Location/GPS and try again.',
      );
    }

    var permission =
    await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw const LocationUnavailableException(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw const LocationUnavailableException(
        'Location permission is permanently denied. '
            'Enable it from Android app settings.',
      );
    }

    final position =
    await Geolocator.getCurrentPosition(
      locationSettings:
      const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit:
        Duration(seconds: 15),
      ),
    );

    String? address;
    String? city;
    String? district;
    String? province;
    String? country;

    try {
      final geocoding =
      Geocoding();

      final placemarks =
      await geocoding
          .placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        address = [
          if (p.street != null &&
              p.street!.isNotEmpty)
            p.street!,
          if (p.subLocality != null &&
              p.subLocality!.isNotEmpty)
            p.subLocality!,
          if (p.locality != null &&
              p.locality!.isNotEmpty)
            p.locality!,
          if (p.administrativeArea != null &&
              p.administrativeArea!.isNotEmpty)
            p.administrativeArea!,
          if (p.country != null &&
              p.country!.isNotEmpty)
            p.country!,
        ].join(', ');

        city = p.locality;
        district = p.subAdministrativeArea;
        province = p.administrativeArea;
        country = p.country;
      }
    } catch (_) {
      // GPS coordinates are still valid even when
      // reverse geocoding is unavailable.
    }

    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
      city: city,
      district: district,
      province: province,
      country: country,
    );
  }
}

class LiveDataApi {
  LiveDataApi()
      : _dio = Dio(
    BaseOptions(
      connectTimeout:
      const Duration(seconds: 10),
      receiveTimeout:
      const Duration(seconds: 20),
      sendTimeout:
      const Duration(seconds: 20),
      headers: {
        'User-Agent':
        'OfflineLink/1.0 '
            '(Emergency offline application)',
      },
    ),
  );

  final Dio _dio;

  Future<WeatherSnapshot?>
  getWeather(
      DeviceLocation location,
      ) async {
    try {
      final response =
      await _dio.get<dynamic>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude':
          location.latitude,
          'longitude':
          location.longitude,
          'current':
          'temperature_2m,'
              'relative_humidity_2m,'
              'apparent_temperature,'
              'precipitation,'
              'wind_speed_10m,'
              'weather_code,'
              'is_day',
          'timezone': 'auto',
        },
      );

      final data =
      Map<String, dynamic>.from(
        response.data as Map,
      );

      final current =
      Map<String, dynamic>.from(
        data['current'] as Map,
      );

      return WeatherSnapshot(
        temperature:
        (current['temperature_2m']
        as num)
            .toDouble(),
        apparentTemperature:
        (current[
        'apparent_temperature']
        as num)
            .toDouble(),
        humidity:
        (current[
        'relative_humidity_2m']
        as num)
            .toDouble(),
        precipitation:
        (current['precipitation']
        as num)
            .toDouble(),
        windSpeed:
        (current['wind_speed_10m']
        as num)
            .toDouble(),
        weatherCode:
        (current['weather_code']
        as num)
            .toInt(),
        isDay:
        (current['is_day'] as num)
            .toInt() ==
            1,
        observedAt:
        DateTime.parse(
          current['time'].toString(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<NearbyPlace>>
  getNearbyPlaces(
      DeviceLocation location,
      ) async {
    try {
      final lat =
      location.latitude.toStringAsFixed(
        6,
      );

      final lon =
      location.longitude.toStringAsFixed(
        6,
      );

      const radius = 5000;

      final query = '''
[out:json][timeout:30];
(
  nwr["amenity"~"hospital|clinic|pharmacy|police|fire_station|ambulance_station|shelter"](around:$radius,$lat,$lon);
  nwr["healthcare"~"hospital|clinic"](around:$radius,$lat,$lon);
);
out center tags;
''';

      final response =
      await _dio.post<dynamic>(
        'https://overpass-api.de/api/interpreter',
        data: {
          'data': query,
        },
        options: Options(
          contentType:
          Headers.formUrlEncodedContentType,
        ),
      );

      final data =
      Map<String, dynamic>.from(
        response.data as Map,
      );

      final elements =
      data['elements'];

      if (elements is! List) {
        return const [];
      }

      final results =
      <NearbyPlace>[];

      final seen =
      <String>{};

      for (final raw in elements) {
        if (raw is! Map) {
          continue;
        }

        final element =
        Map<String, dynamic>.from(raw);

        final id =
            '${element['type']}-${element['id']}';

        if (!seen.add(id)) {
          continue;
        }

        final tags =
        element['tags'] is Map
            ? Map<String, dynamic>.from(
          element['tags'] as Map,
        )
            : <String, dynamic>{};

        final name =
        tags['name']?.toString().trim();

        if (name == null || name.isEmpty) {
          continue;
        }

        double? latitude =
        (element['lat'] as num?)
            ?.toDouble();

        double? longitude =
        (element['lon'] as num?)
            ?.toDouble();

        final center =
        element['center'];

        if ((latitude == null ||
            longitude == null) &&
            center is Map) {
          latitude =
              (center['lat'] as num?)
                  ?.toDouble();

          longitude =
              (center['lon'] as num?)
                  ?.toDouble();
        }

        if (latitude == null ||
            longitude == null) {
          continue;
        }

        final distance =
        Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          latitude,
          longitude,
        );

        final category =
        _placeCategory(tags);

        final phone =
            tags['phone']?.toString() ??
                tags['contact:phone']
                    ?.toString();

        final website =
            tags['website']?.toString() ??
                tags['contact:website']
                    ?.toString();

        final address =
            tags['addr:full']?.toString() ??
                _buildOsmAddress(tags);

        results.add(
          NearbyPlace(
            id: id,
            name: name,
            category: category,
            latitude: latitude,
            longitude: longitude,
            distanceMeters: distance,
            phone: phone,
            website: website,
            address:
            address.isEmpty
                ? null
                : address,
          ),
        );
      }

      results.sort(
            (a, b) =>
            a.distanceMeters
                .compareTo(
              b.distanceMeters,
            ),
      );

      return results
          .take(50)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _placeCategory(
      Map<String, dynamic> tags,
      ) {
    final amenity =
    tags['amenity']
        ?.toString();

    final healthcare =
    tags['healthcare']
        ?.toString();

    switch (amenity) {
      case 'hospital':
        return 'Hospital';

      case 'clinic':
        return 'Clinic';

      case 'pharmacy':
        return 'Pharmacy';

      case 'police':
        return 'Police';

      case 'fire_station':
        return 'Fire Station';

      case 'ambulance_station':
        return 'Ambulance';

      case 'shelter':
        return 'Shelter';
    }

    switch (healthcare) {
      case 'hospital':
        return 'Hospital';

      case 'clinic':
        return 'Clinic';
    }

    return 'Emergency Service';
  }

  String _buildOsmAddress(
      Map<String, dynamic> tags,
      ) {
    return [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:suburb'],
      tags['addr:city'],
    ]
        .whereType<String>()
        .where(
          (value) => value.trim().isNotEmpty,
    )
        .join(', ');
  }

  Future<List<EarthquakeSnapshot>>
  getRecentEarthquakes(
      DeviceLocation location,
      ) async {
    try {
      final response =
      await _dio.get<dynamic>(
        'https://earthquake.usgs.gov/'
            'earthquakes/feed/v1.0/summary/'
            'all_day.geojson',
      );

      final data =
      Map<String, dynamic>.from(
        response.data as Map,
      );

      final features =
      data['features'];

      if (features is! List) {
        return const [];
      }

      final results =
      <EarthquakeSnapshot>[];

      for (final rawFeature in features) {
        if (rawFeature is! Map) {
          continue;
        }

        final feature =
        Map<String, dynamic>.from(
          rawFeature,
        );

        final propertiesRaw =
        feature['properties'];

        final geometryRaw =
        feature['geometry'];

        if (propertiesRaw is! Map ||
            geometryRaw is! Map) {
          continue;
        }

        final properties =
        Map<String, dynamic>.from(
          propertiesRaw,
        );

        final geometry =
        Map<String, dynamic>.from(
          geometryRaw,
        );

        final coordinates =
        geometry['coordinates'];

        if (coordinates is! List ||
            coordinates.length < 2) {
          continue;
        }

        final longitude =
        (coordinates[0] as num)
            .toDouble();

        final latitude =
        (coordinates[1] as num)
            .toDouble();

        final magnitudeRaw =
        properties['mag'];

        final timestampRaw =
        properties['time'];

        if (magnitudeRaw == null ||
            timestampRaw == null) {
          continue;
        }

        final magnitude =
        (magnitudeRaw as num).toDouble();

        final timestamp =
        (timestampRaw as num).toInt();

        final distanceKm =
        _distanceKm(
          location.latitude,
          location.longitude,
          latitude,
          longitude,
        );

        // Keep earthquakes within 1000 km.
        if (distanceKm > 1000) {
          continue;
        }

        results.add(
          EarthquakeSnapshot(
            magnitude: magnitude,
            place:
            properties['place']
                ?.toString() ??
                'Unknown location',
            occurredAt:
            DateTime.fromMillisecondsSinceEpoch(
              timestamp,
              isUtc: true,
            ),
            latitude: latitude,
            longitude: longitude,
            distanceKm: distanceKm,
            url:
            properties['url']
                ?.toString(),
          ),
        );
      }

      results.sort(
            (a, b) => b.magnitude
            .compareTo(a.magnitude),
      );

      return results.take(20).toList();
    } catch (_) {
      return const [];
    }
  }

  double _distanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const earthRadiusKm =
    6371.0;

    final dLat =
    _degreesToRadians(
      lat2 - lat1,
    );

    final dLon =
    _degreesToRadians(
      lon2 - lon1,
    );

    final a =
        math.sin(dLat / 2) *
            math.sin(dLat / 2) +
            math.cos(
              _degreesToRadians(lat1),
            ) *
                math.cos(
                  _degreesToRadians(lat2),
                ) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);

    final c =
        2 *
            math.atan2(
              math.sqrt(a),
              math.sqrt(1 - a),
            );

    return earthRadiusKm * c;
  }

  double _degreesToRadians(
      double value,
      ) {
    return value * math.pi / 180;
  }

  Future<List<EmergencyContact>>
  getOfficialEmergencyContacts(
      DeviceLocation location,
      ) async {
    final province =
    (location.province ?? '')
        .toLowerCase();

    final country =
    (location.country ?? '')
        .toLowerCase();

    /*
     * For now we have direct official live
     * directory integration for Pakistan/KP.
     *
     * More provincial official directories can
     * be added without changing the rest of
     * OfflineLink.
     */
    final isPakistan =
    country.contains('pakistan');

    final isKp =
        province.contains(
          'khyber',
        ) ||
            province.contains(
              'kp',
            );

    if (!isPakistan || !isKp) {
      return const [];
    }

    try {
      final response =
      await _dio.get<String>(
        'https://www.kppolice.gov.pk/'
            'phone-directory.php',
        options: Options(
          responseType:
          ResponseType.plain,
        ),
      );

      final body =
          html_parser
              .parse(
            response.data ?? '',
          )
              .body
              ?.text ??
              '';

      final contacts =
      <EmergencyContact>[];

      _addParsedContact(
        contacts,
        body,
        label: 'Police Emergency',
        source:
        'Khyber Pakhtunkhwa Police',
        sourceUrl:
        'https://www.kppolice.gov.pk/'
            'phone-directory.php',
      );

      _addParsedContact(
        contacts,
        body,
        label: 'Fire Brigade',
        source:
        'Khyber Pakhtunkhwa Police',
        sourceUrl:
        'https://www.kppolice.gov.pk/'
            'phone-directory.php',
      );

      _addParsedContact(
        contacts,
        body,
        label: 'Edhi',
        source:
        'Khyber Pakhtunkhwa Police',
        sourceUrl:
        'https://www.kppolice.gov.pk/'
            'phone-directory.php',
      );

      _addParsedContact(
        contacts,
        body,
        label: 'Chhipa',
        source:
        'Khyber Pakhtunkhwa Police',
        sourceUrl:
        'https://www.kppolice.gov.pk/'
            'phone-directory.php',
      );

      _addParsedContact(
        contacts,
        body,
        label: 'Rescue Service',
        source:
        'Khyber Pakhtunkhwa Police',
        sourceUrl:
        'https://www.kppolice.gov.pk/'
            'phone-directory.php',
      );

      return contacts;
    } catch (_) {
      return const [];
    }
  }

  void _addParsedContact(
      List<EmergencyContact> output,
      String body, {
        required String label,
        required String source,
        required String sourceUrl,
      }) {
    /*
     * HTML text is whitespace-normalized.
     * We intentionally look for a number directly
     * after the service label.
     */
    final escaped =
    RegExp.escape(label);

    final pattern = RegExp(
      '$escaped'
      r'\s*\(?\s*'
      r'([0-9]{3,15})',
      caseSensitive: false,
    );

    final match =
    pattern.firstMatch(body);

    if (match == null) {
      return;
    }

    final number =
    match.group(1);

    if (number == null ||
        number.isEmpty) {
      return;
    }

    final exists = output.any(
          (item) =>
      item.name == label &&
          item.number == number,
    );

    if (!exists) {
      output.add(
        EmergencyContact(
          name: label,
          number: number,
          source: source,
          sourceUrl: sourceUrl,
        ),
      );
    }
  }

  Future<List<OfficialAlert>>
  getNdmaAlerts(
      DeviceLocation location,
      ) async {
    try {
      final pages = [
        (
        url:
        'https://ndma.gov.pk/ew',
        source:
        'NDMA Pakistan — Early Warning',
        ),
        (
        url:
        'https://ndma.gov.pk/public/advisories',
        source:
        'NDMA Pakistan — Advisories',
        ),
      ];

      final results =
      <OfficialAlert>[];

      final seenUrls =
      <String>{};

      for (final page in pages) {
        try {
          final response =
          await _dio.get<String>(
            page.url,
            options: Options(
              responseType:
              ResponseType.plain,
            ),
          );

          final document =
          html_parser.parse(
            response.data ?? '',
          );

          final links =
          document.querySelectorAll(
            'a',
          );

          for (final link in links) {
            final title =
            link.text
                .replaceAll(
              RegExp(r'\s+'),
              ' ',
            )
                .trim();

            final href =
            link.attributes['href'];

            if (href == null ||
                title.length < 8) {
              continue;
            }

            final lower =
            title.toLowerCase();

            final looksRelevant =
                lower.contains('alert') ||
                    lower.contains(
                      'advisory',
                    ) ||
                    lower.contains(
                      'flood',
                    ) ||
                    lower.contains(
                      'rain',
                    ) ||
                    lower.contains(
                      'earthquake',
                    ) ||
                    lower.contains(
                      'heatwave',
                    ) ||
                    lower.contains(
                      'glof',
                    ) ||
                    lower.contains(
                      'disaster',
                    );

            if (!looksRelevant) {
              continue;
            }

            final absoluteUrl =
            _absoluteUrl(
              href,
            );

            if (!seenUrls.add(
              absoluteUrl,
            )) {
              continue;
            }

            results.add(
              OfficialAlert(
                title: title,
                url: absoluteUrl,
                source: page.source,
              ),
            );

            if (results.length >=
                12) {
              break;
            }
          }
        } catch (_) {
          continue;
        }

        if (results.length >= 12) {
          break;
        }
      }

      return results;
    } catch (_) {
      return const [];
    }
  }

  String _absoluteUrl(
      String href,
      ) {
    if (href.startsWith('http://') ||
        href.startsWith('https://')) {
      return href;
    }

    if (href.startsWith('/')) {
      return 'https://ndma.gov.pk$href';
    }

    return 'https://ndma.gov.pk/$href';
  }

  void dispose() {
    _dio.close(force: true);
  }
}

class LiveEmergencyCache {
  static const String _fileName =
      'offline_link_live_cache.json';

  Future<File> _getFile() async {
    final directory =
    await getApplicationDocumentsDirectory();

    return File(
      '${directory.path}/$_fileName',
    );
  }

  Future<void> save(
      LiveEmergencySnapshot snapshot,
      ) async {
    final file =
    await _getFile();

    await file.writeAsString(
      jsonEncode(snapshot.toJson()),
      flush: true,
    );
  }

  Future<LiveEmergencySnapshot?>
  load() async {
    try {
      final file =
      await _getFile();

      if (!await file.exists()) {
        return null;
      }

      final raw =
      await file.readAsString();

      if (raw.trim().isEmpty) {
        return null;
      }

      final decoded =
      jsonDecode(raw);

      if (decoded is! Map) {
        return null;
      }

      return LiveEmergencySnapshot.fromJson(
        Map<String, dynamic>.from(
          decoded,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final file =
    await _getFile();

    if (await file.exists()) {
      await file.delete();
    }
  }
}

class LiveEmergencyRepository {
  LiveEmergencyRepository({
    DeviceLocationService?
    locationService,
    LiveDataApi? api,
    LiveEmergencyCache? cache,
  })  : _locationService =
      locationService ??
          DeviceLocationService(),
        _api = api ?? LiveDataApi(),
        _cache =
            cache ?? LiveEmergencyCache();

  final DeviceLocationService
  _locationService;

  final LiveDataApi _api;
  final LiveEmergencyCache _cache;

  Future<LiveEmergencySnapshot>
  loadOffline() async {
    final cached =
    await _cache.load();

    if (cached == null) {
      throw const NoOfflineDataException();
    }

    return LiveEmergencySnapshot(
      location: cached.location,
      weather: cached.weather,
      nearbyPlaces:
      cached.nearbyPlaces,
      earthquakes:
      cached.earthquakes,
      contacts:
      cached.contacts,
      alerts:
      cached.alerts,
      fetchedAt: cached.fetchedAt,
      fromCache: true,
    );
  }

  Future<LiveEmergencySnapshot>
  refresh() async {
    final location =
    await _locationService
        .getCurrentLocation();

    final results =
    await Future.wait([
      _api.getWeather(location),
      _api.getNearbyPlaces(location),
      _api.getRecentEarthquakes(location),
      _api.getOfficialEmergencyContacts(
        location,
      ),
      _api.getNdmaAlerts(location),
    ]);

    final snapshot =
    LiveEmergencySnapshot(
      location: location,
      weather:
      results[0]
      as WeatherSnapshot?,
      nearbyPlaces:
      results[1]
      as List<NearbyPlace>,
      earthquakes:
      results[2]
      as List<EarthquakeSnapshot>,
      contacts:
      results[3]
      as List<EmergencyContact>,
      alerts:
      results[4]
      as List<OfficialAlert>,
      fetchedAt: DateTime.now(),
      fromCache: false,
    );

    await _cache.save(snapshot);

    return snapshot;
  }

  Future<LiveEmergencySnapshot>
  getBestAvailable() async {
    try {
      return await refresh();
    } catch (_) {
      return loadOffline();
    }
  }

  Future<void> clearCache() {
    return _cache.clear();
  }

  void dispose() {
    _api.dispose();
  }
}

class LocationUnavailableException
    implements Exception {
  const LocationUnavailableException(
      this.message,
      );

  final String message;

  @override
  String toString() => message;
}

class NoOfflineDataException
    implements Exception {
  const NoOfflineDataException();

  @override
  String toString() =>
      'No live data has been downloaded yet. '
          'Connect to the Internet once to create '
          'your first OfflineLink cache.';
}