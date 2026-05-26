import 'package:flutter/material.dart';
import '../services/socket_service.dart';

/// Animates in when the socket is disconnected and out when reconnected.
class ConnectionBanner extends StatelessWidget {
  final SocketService socket;

  const ConnectionBanner({super.key, required this.socket});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: socket.connected,
      builder: (_, connected, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: connected ? 0 : 32,
          color: const Color(0xFF2A2A2A),
          child: connected
              ? const SizedBox.shrink()
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: Colors.white60,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Connecting…',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
