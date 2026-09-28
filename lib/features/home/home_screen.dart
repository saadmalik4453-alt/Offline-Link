import 'package:flutter/material.dart';

import '../../core/network/connection_controller.dart';
import '../../shared/widgets/connection_status_card.dart';
import '../offline_vault/offline_vault_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.connectionController,
  });

  final ConnectionController connectionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'OfflineLink',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Check connection',
            onPressed: connectionController.checkInternet,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: connectionController,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                30,
              ),
              children: [
                ConnectionStatusCard(
                  controller: connectionController,
                ),
                const SizedBox(height: 22),
                _heroCard(),
                const SizedBox(height: 24),
                const Text(
                  'Emergency Capsule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Information stored on your phone can still be '
                      'used when the Internet disappears.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _featureCard(
                  context: context,
                  icon: Icons.menu_book_rounded,
                  title: 'Offline Guides',
                  subtitle:
                  'Emergency information available without Internet.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfflineVaultScreen(
                          connectionController: connectionController,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _featureCard(
                  context: context,
                  icon: Icons.map_rounded,
                  title: 'Offline Maps',
                  subtitle:
                  'Maps will be downloadable for emergency use.',
                  onTap: () {
                    _showComingSoon(context, 'Offline Maps');
                  },
                ),
                const SizedBox(height: 12),
                _featureCard(
                  context: context,
                  icon: Icons.sos_rounded,
                  title: 'Emergency SOS',
                  subtitle:
                  'Messages will be queued when there is no Internet.',
                  onTap: () {
                    _showComingSoon(context, 'Emergency SOS');
                  },
                ),
                const SizedBox(height: 12),
                _featureCard(
                  context: context,
                  icon: Icons.devices_other_rounded,
                  title: 'Nearby Relay',
                  subtitle:
                  'Phone-to-phone emergency communication will come later.',
                  onTap: () {
                    _showComingSoon(context, 'Nearby Relay');
                  },
                ),
                const SizedBox(height: 24),
                _storageCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF261111),
            Color(0xFF151515),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFF3B3B).withValues(alpha: 0.35),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_rounded,
            color: Color(0xFFFF3B3B),
            size: 38,
          ),
          SizedBox(height: 16),
          Text(
            'Prepared for the moment\nInternet disappears.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'OfflineLink keeps important information '
                'available locally and prepares your device '
                'for future offline communication.',
            style: TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B3B)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFF5A5A),
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF929292),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF666666),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storageCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2B2B2B),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.storage_rounded,
            color: Color(0xFFF4B73C),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Capsule',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'V1 demo data is bundled directly inside the app.',
                  style: TextStyle(
                    color: Color(0xFF858585),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(
      BuildContext context,
      String feature,
      ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature is part of the next development stage.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}