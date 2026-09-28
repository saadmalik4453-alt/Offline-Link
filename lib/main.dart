import 'package:flutter/material.dart';

import 'core/network/connection_controller.dart';
import 'features/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const OfflineLinkApp());
}

class OfflineLinkApp extends StatefulWidget {
  const OfflineLinkApp({super.key});

  @override
  State<OfflineLinkApp> createState() =>
      _OfflineLinkAppState();
}

class _OfflineLinkAppState extends State<OfflineLinkApp> {
  late final ConnectionController
  _connectionController;

  @override
  void initState() {
    super.initState();

    _connectionController =
        ConnectionController();

    _connectionController.initialize();
  }

  @override
  void dispose() {
    _connectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OfflineLink',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
        const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3B3B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        connectionController:
        _connectionController,
      ),
    );
  }
}