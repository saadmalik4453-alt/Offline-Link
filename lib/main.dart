import 'package:flutter/material.dart';

import 'core/network/connection_controller.dart';
import 'features/emergency/relay/nearby_relay_controller.dart';
import 'features/emergency/services/emergency_sync_controller.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const OfflineLinkApp());
}

class OfflineLinkApp extends StatefulWidget {
  const OfflineLinkApp({super.key});

  @override
  State<OfflineLinkApp> createState() => _OfflineLinkAppState();
}

class _OfflineLinkAppState extends State<OfflineLinkApp> {
  late final ConnectionController _connectionController;

  late final EmergencySyncController _emergencySyncController;
  late final NearbyRelayController _nearbyRelayController;

  @override
  void initState() {
    super.initState();

    _connectionController = ConnectionController();

    _connectionController.initialize();

    _emergencySyncController = EmergencySyncController(
      connectionController: _connectionController,
    );
    _nearbyRelayController = NearbyRelayController();
    _emergencySyncController.initialize();

  }

  @override
  void dispose() {
    _emergencySyncController.dispose();
    _connectionController.dispose();
    _nearbyRelayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OfflineLink',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B3B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
      connectionController:
      _connectionController,
      emergencySyncController:
      _emergencySyncController, nearbyRelayController: _nearbyRelayController,
    ),
    );
  }
}
