import 'package:flutter/material.dart';

import 'nearby_relay_controller.dart';

class NearbyRelayScreen extends StatefulWidget {
  const NearbyRelayScreen({super.key, required this.controller});

  final NearbyRelayController controller;

  @override
  State<NearbyRelayScreen> createState() => _NearbyRelayScreenState();
}

class _NearbyRelayScreenState extends State<NearbyRelayScreen> {
  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _start() async {
    final name = 'OfflineLink';

    final started = await widget.controller.start(name);

    if (!mounted) {
      return;
    }

    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nearby communication permissions are required.'),
        ),
      );
    }
  }

  Future<void> _stop() async {
    await widget.controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.controller.isRunning;

    final starting = widget.controller.isStarting;

    final connected = widget.controller.connectedEndpoints;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text(
          'Nearby Relay',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: running
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFF303030),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF241010),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    size: 45,
                    color: Color(0xFFFF3B3B),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  running ? 'Relay is active' : 'Relay is offline',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  running
                      ? 'OfflineLink is discovering nearby phones and can exchange emergency packets without Internet.'
                      : 'Start Nearby Relay to allow OfflineLink phones around you to exchange emergency packets.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8A8A8A), height: 1.5),
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: starting
                        ? null
                        : running
                        ? _stop
                        : _start,
                    style: FilledButton.styleFrom(
                      backgroundColor: running
                          ? const Color(0xFF303030)
                          : const Color(0xFFFF3B3B),
                    ),
                    icon: starting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            running ? Icons.stop_rounded : Icons.hub_rounded,
                          ),
                    label: Text(
                      starting
                          ? 'Starting...'
                          : running
                          ? 'Stop Relay'
                          : 'Start Nearby Relay',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Text(
            'Nearby phones',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 12),

          if (connected.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.devices_other_rounded,
                    size: 38,
                    color: Color(0xFF666666),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No connected OfflineLink phones',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Nearby devices appear here when a relay connection is established.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF707070), fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...connected.map(
              (endpointId) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.smartphone_rounded,
                      color: Color(0xFF7EE787),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nearby OfflineLink phone',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.link_rounded, color: Color(0xFF7EE787)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFF18140A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFF4B73C).withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFFF4B73C)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nearby Relay uses the phone-to-phone Nearby Connections layer. It does not require Internet, but Bluetooth, Wi-Fi and the required device permissions must be available.',
                    style: TextStyle(
                      color: Color(0xFFB7B7B7),
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);

    super.dispose();
  }
}
