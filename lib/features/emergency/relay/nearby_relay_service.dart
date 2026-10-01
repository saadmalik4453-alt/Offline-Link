import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../data/emergency_database.dart';
import '../data/emergency_record.dart';
import 'nearby_permission_service.dart';
import 'relay_packet.dart';

class NearbyRelayService {
  NearbyRelayService({
    EmergencyDatabase? database,
    NearbyPermissionService? permissionService,
  }) : _database = database ?? EmergencyDatabase.instance,
       _permissionService = permissionService ?? NearbyPermissionService();

  final EmergencyDatabase _database;

  final NearbyPermissionService _permissionService;

  final Nearby _nearby = Nearby();

  final Set<String> _connectedEndpoints = {};

  final Map<String, String> _endpointNames = {};

  StreamSubscription<dynamic>? _notUsed;

  bool _running = false;

  bool get isRunning => _running;

  List<String> get connectedEndpoints {
    return List.unmodifiable(_connectedEndpoints);
  }

  Future<bool> start({required String deviceName}) async {
    if (_running) {
      return true;
    }

    final permissions = await _permissionService.requestPermissions();

    if (!permissions) {
      return false;
    }

    try {
      await _nearby.stopAdvertising();
    } catch (_) {}

    try {
      await _nearby.stopDiscovery();
    } catch (_) {}

    final advertising = await _nearby.startAdvertising(
      deviceName,
      Strategy.P2P_CLUSTER,
      serviceId: 'com.example.memeswar',
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );

    final discovery = await _nearby.startDiscovery(
      deviceName,
      Strategy.P2P_CLUSTER,
      serviceId: 'com.example.memeswar',
      onEndpointFound: _onEndpointFound,
      onEndpointLost: _onEndpointLost,
    );

    _running = advertising || discovery;

    return _running;
  }

  Future<void> stop() async {
    if (!_running) {
      return;
    }

    try {
      await _nearby.stopAdvertising();
    } catch (_) {}

    try {
      await _nearby.stopDiscovery();
    } catch (_) {}

    try {
      await _nearby.stopAllEndpoints();
    } catch (_) {}

    _connectedEndpoints.clear();
    _endpointNames.clear();

    _running = false;
  }

  Future<void> _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) async {
    if (!_running) {
      return;
    }

    if (serviceId != 'com.example.memeswar') {
      return;
    }

    if (_connectedEndpoints.contains(endpointId)) {
      return;
    }

    _endpointNames[endpointId] = endpointName;

    try {
      await _nearby.requestConnection(
        _safeDeviceName(endpointName),
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (_) {
      // Nearby can reject repeated
      // connection requests while
      // its connection state changes.
    }
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId == null) {
      return;
    }

    _endpointNames.remove(endpointId);
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    try {
      /*
       * Nearby Connections provides an
       * authentication token for the
       * connection.
       *
       * For this first relay layer,
       * OfflineLink accepts the connection
       * automatically so emergency packets
       * can propagate without requiring the
       * user to approve every nearby phone.
       *
       * A later trust layer will add signed
       * packets / verified identities.
       */

      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: _onPayloadReceived,
      );
    } catch (_) {
      try {
        await _nearby.rejectConnection(endpointId);
      } catch (_) {}
    }
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints.add(endpointId);

      unawaited(_sendStoredPackets(endpointId));
    } else {
      _connectedEndpoints.remove(endpointId);
    }
  }

  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);

    _endpointNames.remove(endpointId);
  }

  Future<void> _onPayloadReceived(String endpointId, Payload payload) async {
    if (payload.type != PayloadType.BYTES) {
      return;
    }

    final bytes = payload.bytes;

    if (bytes == null || bytes.isEmpty) {
      return;
    }

    try {
      final packet = RelayPacket.decode(bytes);

      await _receivePacket(packet, endpointId);
    } catch (_) {
      // Ignore malformed payloads.
    }
  }

  Future<void> _receivePacket(RelayPacket packet, String sourceEndpoint) async {
    if (packet.isExpired) {
      return;
    }

    final exists = await _database.relayPacketExists(packet.packetId);

    if (exists) {
      return;
    }

    await _database.saveRelayPacket(packet);

    if (!packet.canRelay) {
      return;
    }

    final nextPacket = packet.nextHop();

    await _broadcastPacket(nextPacket, exceptEndpoint: sourceEndpoint);

    await _database.markRelayForwarded(packet.packetId);
  }

  Future<void> sendEmergency(
    EmergencyRecord emergency, {
    required String installationId,
  }) async {
    if (!_running) {
      return;
    }

    final packet = RelayPacket.fromEmergency(
      emergency: emergency,
      installationId: installationId,
    );

    await _broadcastPacket(packet);
  }

  Future<void> _sendStoredPackets(String endpointId) async {
    final packets = await _database.getUnexpiredRelayPackets();

    for (final packet in packets) {
      try {
        await _sendPacket(endpointId, packet);

        await _database.markRelayForwarded(packet.packetId);
      } catch (_) {
        // Keep moving to the next packet.
      }
    }
  }

  Future<void> _broadcastPacket(
    RelayPacket packet, {
    String? exceptEndpoint,
  }) async {
    if (packet.isExpired) {
      return;
    }

    final bytes = Uint8List.fromList(packet.encodeBytes());

    final endpoints = List<String>.from(_connectedEndpoints);

    for (final endpointId in endpoints) {
      if (endpointId == exceptEndpoint) {
        continue;
      }

      try {
        await _nearby.sendBytesPayload(endpointId, bytes);
      } catch (_) {
        // Connection may have disappeared.
      }
    }
  }

  Future<void> _sendPacket(String endpointId, RelayPacket packet) async {
    final bytes = Uint8List.fromList(packet.encodeBytes());

    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  String _safeDeviceName(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      return 'OfflineLink';
    }

    if (cleaned.length <= 32) {
      return cleaned;
    }

    return cleaned.substring(0, 32);
  }

  Future<void> dispose() async {
    await stop();
    await _notUsed?.cancel();
  }
}
