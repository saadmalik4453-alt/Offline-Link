import 'dart:convert';

import '../data/emergency_record.dart';

class RelayPacket {
  const RelayPacket({
    required this.packetId,
    required this.originEmergencyId,
    required this.originInstallationId,
    required this.type,
    required this.createdAt,
    required this.expiresAt,
    required this.hopCount,
    required this.maxHops,
    this.note,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.locationTimestamp,
    this.address,
    required this.locationSource,
  });

  final String packetId;

  final String originEmergencyId;

  final String originInstallationId;

  final EmergencyType type;

  final DateTime createdAt;

  final DateTime expiresAt;

  final int hopCount;

  final int maxHops;

  final String? note;

  final double? latitude;

  final double? longitude;

  final double? accuracyMeters;

  final DateTime? locationTimestamp;

  final String? address;

  final EmergencyLocationSource locationSource;

  bool get isExpired {
    return DateTime.now().toUtc().isAfter(expiresAt);
  }

  bool get canRelay {
    return !isExpired && hopCount < maxHops;
  }

  RelayPacket nextHop() {
    return RelayPacket(
      packetId: packetId,
      originEmergencyId: originEmergencyId,
      originInstallationId: originInstallationId,
      type: type,
      createdAt: createdAt,
      expiresAt: expiresAt,
      hopCount: hopCount + 1,
      maxHops: maxHops,
      note: note,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      locationTimestamp: locationTimestamp,
      address: address,
      locationSource: locationSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': 1,
      'packetId': packetId,
      'originEmergencyId': originEmergencyId,
      'originInstallationId': originInstallationId,
      'type': type.name,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'hopCount': hopCount,
      'maxHops': maxHops,
      'note': note,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'locationTimestamp': locationTimestamp?.toUtc().toIso8601String(),
      'address': address,
      'locationSource': locationSource.name,
    };
  }

  String encode() {
    return jsonEncode(toMap());
  }

  List<int> encodeBytes() {
    return utf8.encode(encode());
  }

  factory RelayPacket.fromMap(Map<String, dynamic> map) {
    final version = map['version'];

    if (version != 1) {
      throw const FormatException('Unsupported relay packet version.');
    }

    return RelayPacket(
      packetId: map['packetId'] as String,

      originEmergencyId: map['originEmergencyId'] as String,

      originInstallationId: map['originInstallationId'] as String,

      type: EmergencyType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => EmergencyType.other,
      ),

      createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),

      expiresAt: DateTime.parse(map['expiresAt'] as String).toUtc(),

      hopCount: (map['hopCount'] as num).toInt(),

      maxHops: (map['maxHops'] as num).toInt(),

      note: map['note'] as String?,

      latitude: (map['latitude'] as num?)?.toDouble(),

      longitude: (map['longitude'] as num?)?.toDouble(),

      accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble(),

      locationTimestamp: map['locationTimestamp'] == null
          ? null
          : DateTime.parse(map['locationTimestamp'] as String).toUtc(),

      address: map['address'] as String?,

      locationSource: EmergencyLocationSource.values.firstWhere(
        (value) => value.name == map['locationSource'],
        orElse: () => EmergencyLocationSource.unavailable,
      ),
    );
  }

  factory RelayPacket.decode(List<int> bytes) {
    final json = utf8.decode(bytes);

    final decoded = jsonDecode(json);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid relay packet.');
    }

    return RelayPacket.fromMap(decoded);
  }

  factory RelayPacket.fromEmergency({
    required EmergencyRecord emergency,
    required String installationId,
  }) {
    final now = DateTime.now().toUtc();

    return RelayPacket(
      packetId: '${emergency.id}:0',

      originEmergencyId: emergency.id,

      originInstallationId: installationId,

      type: emergency.type,

      createdAt: emergency.createdAt,

      expiresAt: now.add(const Duration(hours: 24)),

      hopCount: 0,

      maxHops: 6,

      note: emergency.note,

      latitude: emergency.latitude,

      longitude: emergency.longitude,

      accuracyMeters: emergency.accuracyMeters,

      locationTimestamp: emergency.locationTimestamp,

      address: emergency.address,

      locationSource: emergency.locationSource,
    );
  }
}
