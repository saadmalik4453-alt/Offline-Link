import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_link/features/emergency/services/emergency_location_service.dart';

import 'data/emergency_database.dart';
import 'data/emergency_record.dart';

class EmergencyRepository {
  EmergencyRepository({
    EmergencyDatabase? database,
    EmergencyLocationService? locationService,
  }) : _database = database ?? EmergencyDatabase.instance,
       _locationService = locationService ?? EmergencyLocationService();

  final EmergencyDatabase _database;
  final EmergencyLocationService _locationService;

  // ---------------------------------------------------------------------------
  // SMS RECIPIENT
  // ---------------------------------------------------------------------------

  static const String _smsRecipientKey = 'emergency_sms_recipient';

  Future<String?> getSmsRecipient() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_smsRecipientKey);
  }

  Future<void> saveSmsRecipient(String number) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_smsRecipientKey, number.trim());
  }

  // ---------------------------------------------------------------------------
  // CREATE EMERGENCY
  // ---------------------------------------------------------------------------

  Future<EmergencyRecord> createEmergency({
    EmergencyType type = EmergencyType.sos,
    String? note,
  }) async {
    final location = await _locationService.getCurrentLocation();

    final record = EmergencyRecord(
      id: _generateId(),
      type: type,
      note: note,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyMeters: location.accuracyMeters,
      locationTimestamp: location.timestamp,
      address: location.address,
      locationSource: location.source,
      createdAt: DateTime.now().toUtc(),
      syncState: EmergencySyncState.pending,
    );

    // IMPORTANT:
    // Always save the SOS locally FIRST.
    await _database.insert(record);

    return record;
  }

  // ---------------------------------------------------------------------------
  // EMERGENCY HISTORY
  // ---------------------------------------------------------------------------

  Future<List<EmergencyRecord>> getRecentEmergencies() {
    return _database.getRecent();
  }

  Future<int> getPendingCount() {
    return _database.pendingCount();
  }

  // ---------------------------------------------------------------------------
  // ID
  // ---------------------------------------------------------------------------

  String _generateId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;

    final random = Random.secure().nextInt(999999);

    return '$now-$random';
  }
}
