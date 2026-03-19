import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/launch_provider.dart';

class SingleInstanceService {
  static const int _port = 61425; // Random high port for local sync
  static ServerSocket? _server;

  /// Initializes the single instance check.
  /// If an instance is already running, sends [args] to it and returns true (indicating this instance should exit).
  static Future<bool> check(
    List<String> args,
    ProviderContainer container,
  ) async {
    try {
      // Try to bind - if this works, we are the primary instance
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, _port);

      _server!.listen((client) {
        client.cast<List<int>>().transform(utf8.decoder).listen((data) {
          debugPrint('Received data from secondary instance: $data');
          _handleReceivedData(data, container);
        });
      });

      return false; // Primary instance
    } catch (e) {
      // Bind failed - an instance is likely already running
      debugPrint('Another instance is running, sending args...');
      try {
        final client = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _port,
        );
        // Send the protocol URL if it exists in args
        client.write(args.join(' '));
        await client.flush();
        await client.close();
      } catch (sendError) {
        debugPrint('Failed to send args to primary instance: $sendError');
      }
      return true; // Secondary instance should exit
    }
  }

  static void _handleReceivedData(String data, ProviderContainer container) {
    // Look for our protocol in the received string
    if (data.contains('moderndownloader://')) {
      final parts = data.split(' ');
      final protocolUrl = parts.firstWhere(
        (p) => p.contains('moderndownloader://'),
        orElse: () => '',
      );

      if (protocolUrl.isNotEmpty) {
        // Extract URL and update provider
        final uri = Uri.parse(protocolUrl);
        String? finalUrl;
        if (uri.queryParameters.containsKey('url')) {
          finalUrl = uri.queryParameters['url'];
        } else if (uri.host == 'open' &&
            uri.queryParameters.containsKey('url')) {
          finalUrl = uri.queryParameters['url'];
        }

        if (finalUrl != null) {
          container.read(launchDataProvider.notifier).state = LaunchData.dialog(
            finalUrl,
          );

          // Re-focus original window
          try {
            windowManager.show();
            windowManager.focus();
          } catch (e) {
            debugPrint('Failed to focus window: $e');
          }
        }
      }
    } else {
      // Just focus the window anyway if someone tries to launch
      windowManager.show();
      windowManager.focus();
    }
  }
}
