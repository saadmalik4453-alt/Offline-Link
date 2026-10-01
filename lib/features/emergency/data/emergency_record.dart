enum EmergencyType {
  sos,
  medical,
  fire,
  accident,
  crime,
  disaster,
  other,
}

extension EmergencyTypeExtension on EmergencyType {
  String get label {
    switch (this) {
      case EmergencyType.sos:
        return 'General SOS';

      case EmergencyType.medical:
        return 'Medical';

      case EmergencyType.fire:
        return 'Fire';

      case EmergencyType.accident:
        return 'Accident';

      case EmergencyType.crime:
        return 'Crime';

      case EmergencyType.disaster:
        return 'Disaster';

      case EmergencyType.other:
        return 'Other';
    }
  }
}

enum EmergencySyncState {
  pending,
  synced,
}

enum EmergencyLocationSource {
  current,
  lastKnown,
  unavailable,
}

class EmergencyRecord {
  const EmergencyRecord({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.syncState,
    this.note,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.locationTimestamp,
    this.address,
    this.locationSource =
        EmergencyLocationSource.unavailable,
  });

  final String id;

  final EmergencyType type;

  final DateTime createdAt;

  final EmergencySyncState syncState;

  final String? note;

  final double? latitude;

  final double? longitude;

  final double? accuracyMeters;

  final DateTime? locationTimestamp;

  final String? address;

  final EmergencyLocationSource locationSource;

  bool get hasLocation =>
      latitude != null &&
          longitude != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'location_timestamp':
      locationTimestamp
          ?.toUtc()
          .millisecondsSinceEpoch,
      'address': address,
      'location_source':
      locationSource.name,
      'created_at':
      createdAt
          .toUtc()
          .millisecondsSinceEpoch,
      'sync_state': syncState.name,
    };
  }

  factory EmergencyRecord.fromMap(
      Map<String, dynamic> map,
      ) {
    return EmergencyRecord(
      id: map['id'] as String,

      type: EmergencyType.values.firstWhere(
            (value) =>
        value.name == map['type'],
        orElse: () =>
        EmergencyType.other,
      ),

      note: map['note'] as String?,

      latitude:
      (map['latitude'] as num?)
          ?.toDouble(),

      longitude:
      (map['longitude'] as num?)
          ?.toDouble(),

      accuracyMeters:
      (map['accuracy_meters'] as num?)
          ?.toDouble(),

      locationTimestamp:
      map['location_timestamp'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
        map['location_timestamp'] as int,
        isUtc: true,
      ),

      address:
      map['address'] as String?,

      locationSource:
      EmergencyLocationSource.values
          .firstWhere(
            (value) =>
        value.name ==
            map['location_source'],
        orElse: () =>
        EmergencyLocationSource
            .unavailable,
      ),

      createdAt:
      DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ),

      syncState:
      EmergencySyncState.values
          .firstWhere(
            (value) =>
        value.name ==
            map['sync_state'],
        orElse: () =>
        EmergencySyncState.pending,
      ),
    );
  }
}