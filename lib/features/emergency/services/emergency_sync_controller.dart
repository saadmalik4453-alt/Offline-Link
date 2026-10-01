import 'package:flutter/foundation.dart';

import '../../../core/network/connection_controller.dart';
import 'emergency_sync_service.dart';

class EmergencySyncController extends ChangeNotifier {
  EmergencySyncController({
    required ConnectionController connectionController,
    EmergencySyncService? syncService,
  }) : _connectionController = connectionController,
       _syncService =
           syncService ??
           EmergencySyncService(connectionController: connectionController);

  final ConnectionController _connectionController;

  final EmergencySyncService _syncService;

  bool _syncing = false;

  bool get isSyncing => _syncing;

  void initialize() {
    _connectionController.addListener(_connectionChanged);

    if (_connectionController.isOnline) {
      syncNow();
    }
  }

  void _connectionChanged() {
    if (_connectionController.isOnline) {
      syncNow();
    }
  }

  Future<void> syncNow() async {
    if (_syncing || !_connectionController.isOnline) {
      return;
    }

    _syncing = true;
    notifyListeners();

    try {
      await _syncService.syncPending();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectionController.removeListener(_connectionChanged);

    _syncService.dispose();

    super.dispose();
  }
}
