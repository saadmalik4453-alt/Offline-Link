import 'package:flutter/material.dart';

import '../../core/network/connection_controller.dart';

class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({
    super.key,
    required this.controller,
  });

  final ConnectionController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final isOnline = controller.isOnline;
        final isChecking = controller.isChecking;

        final backgroundColor = isChecking
            ? const Color(0xFF242424)
            : isOnline
            ? const Color(0xFF17321F)
            : const Color(0xFF381818);

        final borderColor = isChecking
            ? const Color(0xFF555555)
            : isOnline
            ? const Color(0xFF2E8B57)
            : const Color(0xFFFF3B3B);

        final icon = isChecking
            ? Icons.sync
            : isOnline
            ? Icons.wifi
            : Icons.wifi_off;

        final title = isChecking
            ? 'Checking Internet...'
            : isOnline
            ? 'Internet Available'
            : 'No Internet Connection';

        final subtitle = isChecking
            ? 'Verifying real Internet access'
            : isOnline
            ? controller.connectionLabel
            : 'Offline mode is ready';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isOnline
                      ? Colors.greenAccent
                      : isChecking
                      ? Colors.orangeAccent
                      : Colors.redAccent,
                  size: 26,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isChecking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}