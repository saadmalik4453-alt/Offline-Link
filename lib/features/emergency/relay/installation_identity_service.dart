import 'dart:convert';
import 'dart:math';

import '../data/emergency_database.dart';

class InstallationIdentity {
  const InstallationIdentity({
    required this.installationId,
    required this.deviceSecret,
  });

  final String installationId;
  final String deviceSecret;
}

class InstallationIdentityService {
  InstallationIdentityService({
    EmergencyDatabase? database,
  }) : _database =
      database ?? EmergencyDatabase.instance;

  final EmergencyDatabase _database;

  static const String _installationIdKey =
      'installation_id';

  static const String _deviceSecretKey =
      'device_secret';

  Future<InstallationIdentity> getOrCreate() async {
    var installationId =
    await _database.getSetting(
      _installationIdKey,
    );

    var deviceSecret =
    await _database.getSetting(
      _deviceSecretKey,
    );

    if (installationId == null ||
        installationId.trim().isEmpty) {
      installationId =
          _generateToken(24);

      await _database.setSetting(
        _installationIdKey,
        installationId,
      );
    }

    if (deviceSecret == null ||
        deviceSecret.trim().isEmpty) {
      deviceSecret =
          _generateToken(48);

      await _database.setSetting(
        _deviceSecretKey,
        deviceSecret,
      );
    }

    return InstallationIdentity(
      installationId: installationId,
      deviceSecret: deviceSecret,
    );
  }

  String _generateToken(int byteCount) {
    final random = Random.secure();

    final bytes = List<int>.generate(
      byteCount,
          (_) => random.nextInt(256),
    );

    return base64UrlEncode(bytes)
        .replaceAll('=', '');
  }
}