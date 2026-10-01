import 'package:flutter/foundation.dart';

import '../data/emergency_record.dart';
import 'nearby_relay_service.dart';

class NearbyRelayController extends ChangeNotifier {
  NearbyRelayController({NearbyRelayService? service})
    : _service = service ?? NearbyRelayService();

  final NearbyRelayService _service;

  bool _starting = false;

  bool get isRunning => _service.isRunning;

  bool get isStarting => _starting;

  List<String> get connectedEndpoints => _service.connectedEndpoints;

  Future<bool> start(String deviceName) async {
    if (_starting) {
      return false;
    }

    if (_service.isRunning) {
      return true;
    }

    _starting = true;
    notifyListeners();

    try {
      final result = await _service.start(deviceName: deviceName);

      return result;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _service.stop();

    notifyListeners();
  }

  Future<void> sendEmergency(
    EmergencyRecord emergency, {
    required String installationId,
  }) async {
    await _service.sendEmergency(emergency, installationId: installationId);
  }

  @override
  void dispose() {
    _service.dispose();

    super.dispose();
  }
}
