import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'internet_service.dart';

enum ConnectionStateType {
  online,
  offline,
  checking,
}

class ConnectionController extends ChangeNotifier {
  ConnectionController({
    InternetService? internetService,
  }) : _internetService = internetService ?? InternetService();

  final Connectivity _connectivity = Connectivity();
  final InternetService _internetService;

  StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;

  Timer? _periodicCheckTimer;

  ConnectionStateType _state = ConnectionStateType.checking;

  List<ConnectivityResult> _connectionTypes = const [];

  bool _checking = false;

  ConnectionStateType get state => _state;

  bool get isOnline => _state == ConnectionStateType.online;

  bool get isOffline => _state == ConnectionStateType.offline;

  bool get isChecking => _state == ConnectionStateType.checking;

  List<ConnectivityResult> get connectionTypes => _connectionTypes;

  String get connectionLabel {
    if (isChecking) {
      return 'Checking connection...';
    }

    if (isOffline) {
      return 'No Internet';
    }

    if (_connectionTypes.contains(ConnectivityResult.wifi)) {
      return 'Online • Wi-Fi';
    }

    if (_connectionTypes.contains(ConnectivityResult.mobile)) {
      return 'Online • Mobile data';
    }

    if (_connectionTypes.contains(ConnectivityResult.ethernet)) {
      return 'Online • Ethernet';
    }

    return 'Online';
  }

  Future<void> initialize() async {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(
              (results) async {
            _connectionTypes = results;
            notifyListeners();

            await checkInternet();
          },
        );

    final currentConnections =
    await _connectivity.checkConnectivity();

    _connectionTypes = currentConnections;

    await checkInternet();

    // Safety net for situations where connectivity events are
    // delayed or do not accurately reflect Internet reachability.
    _periodicCheckTimer = Timer.periodic(
      const Duration(seconds: 20),
          (_) => checkInternet(),
    );
  }

  Future<void> checkInternet() async {
    if (_checking) {
      return;
    }

    _checking = true;

    if (_state != ConnectionStateType.checking) {
      _state = ConnectionStateType.checking;
      notifyListeners();
    }

    try {
      final connected = await _internetService.hasInternet();

      _state = connected
          ? ConnectionStateType.online
          : ConnectionStateType.offline;
    } catch (_) {
      _state = ConnectionStateType.offline;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicCheckTimer?.cancel();
    _internetService.dispose();

    super.dispose();
  }
}