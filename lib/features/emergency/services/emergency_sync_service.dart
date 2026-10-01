import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/connection_controller.dart';
import '../data/emergency_database.dart';
import '../data/emergency_record.dart';

class EmergencySyncService {
  EmergencySyncService({
    required ConnectionController connectionController,
    EmergencyDatabase? database,
    Dio? dio,
  }) : _connectionController = connectionController,
       _database = database ?? EmergencyDatabase.instance,
       _dio = dio ?? Dio();

  final ConnectionController _connectionController;
  final EmergencyDatabase _database;
  final Dio _dio;

  /*
   * This will become your real OfflineLink backend.
   *
   * Example:
   *
   * https://api.offlinelink.app
   *
   * Do NOT put a Firebase URL here.
   */
  static const String baseUrl = 'https://api.offlinelink.example';

  static const String emergencyEndpoint = '/api/v1/emergencies';

  bool _syncing = false;

  Future<void> syncPending() async {
    if (_syncing) {
      return;
    }

    if (!_connectionController.isOnline) {
      return;
    }

    _syncing = true;

    try {
      final pending = await _database.getPendingSync();

      for (final emergency in pending) {
        await _syncOne(emergency);
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncOne(EmergencyRecord emergency) async {
    try {
      final response = await _dio.post(
        '$baseUrl$emergencyEndpoint',
        data: _toPayload(emergency),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        await _database.markSynced(emergency.id);
      }
    } on DioException {
      /*
       * Keep the record pending.
       *
       * The next synchronization attempt
       * will try again.
       */
      return;
    } catch (_) {
      return;
    }
  }

  Map<String, dynamic> _toPayload(EmergencyRecord emergency) {
    return {
      'id': emergency.id,
      'type': emergency.type.name,
      'note': emergency.note,
      'location': {
        'latitude': emergency.latitude,
        'longitude': emergency.longitude,
        'accuracyMeters': emergency.accuracyMeters,
        'timestamp': emergency.locationTimestamp?.toUtc().toIso8601String(),
        'address': emergency.address,
        'source': emergency.locationSource.name,
      },
      'createdAt': emergency.createdAt.toUtc().toIso8601String(),
    };
  }

  void dispose() {
    _dio.close(force: true);
  }
}
