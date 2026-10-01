import 'package:permission_handler/permission_handler.dart';

class NearbyPermissionService {
  Future<bool> requestPermissions() async {
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.nearbyWifiDevices,
    ];

    final result = await permissions.request();

    for (final permission in permissions) {
      final status = result[permission];

      if (status == null) {
        continue;
      }

      if (status.isPermanentlyDenied || status.isRestricted) {
        return false;
      }

      if (!status.isGranted && !status.isLimited) {
        return false;
      }
    }

    return true;
  }

  Future<void> openSettings() {
    return openAppSettings();
  }
}
